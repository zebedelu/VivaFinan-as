"""Regras e ocorrências recorrentes."""

from __future__ import annotations

from typing import Any, Mapping

from ..errors import validation
from ..utils import ESCOPOS, TIPOS, clean_text, money, one_of, parse_int, safe_id
from .common import category_map


def _enrich(rows: list[Mapping[str, Any]], names: Mapping[str, str]) -> list[dict[str, Any]]:
    return [
        {**dict(row), "categoria": names.get(str(row.get("category_id")))}
        for row in rows
        if isinstance(row, Mapping)
    ]


def list_rules(rest: Any, escopo: str | None = None) -> list[dict[str, Any]]:
    params: dict[str, Any] = {"select": "*", "order": "criado_em.desc"}
    if escopo:
        params["escopo"] = f"eq.{one_of(escopo, ESCOPOS, 'escopo')}"
    rows = rest.get("/rest/v1/recurring_rules", params) or []
    return _enrich(rows, category_map(rest))


def create_rule(
    rest: Any,
    profile: Mapping[str, Any],
    user_id: str,
    data: Mapping[str, Any],
) -> dict[str, Any]:
    payload = {
        "family_id": profile["family_id"],
        "criado_por": user_id,
        "tipo": one_of(data.get("tipo"), TIPOS, "tipo"),
        "escopo": one_of(data.get("escopo"), ESCOPOS, "escopo"),
        "valor": money(data.get("valor")),
        "descricao": clean_text(data.get("descricao"), "descricao", required=True, max_len=200),
        "category_id": clean_text(data.get("category_id"), "category_id", required=True, max_len=64),
        "dia_vencimento": parse_int(
            data.get("dia_vencimento"),
            "dia_vencimento",
            minimum=1,
            maximum=31,
        ),
        "ativo": bool(data.get("ativo", True)),
    }
    rows = rest.post("/rest/v1/recurring_rules", payload)
    row = (rows or [{}])[0]
    return {**row, "categoria": category_map(rest).get(str(row.get("category_id")))}


def update_rule(rest: Any, rule_id: str, data: Mapping[str, Any]) -> dict[str, Any]:
    rule_id = safe_id(rule_id, "rule_id")
    payload: dict[str, Any] = {}
    if "tipo" in data:
        payload["tipo"] = one_of(data.get("tipo"), TIPOS, "tipo")
    if "valor" in data:
        payload["valor"] = money(data.get("valor"))
    if "descricao" in data:
        payload["descricao"] = clean_text(data.get("descricao"), "descricao", required=True, max_len=200)
    if "category_id" in data:
        payload["category_id"] = clean_text(data.get("category_id"), "category_id", required=True, max_len=64)
    if "dia_vencimento" in data:
        payload["dia_vencimento"] = parse_int(
            data.get("dia_vencimento"),
            "dia_vencimento",
            minimum=1,
            maximum=31,
        )
    if "ativo" in data:
        if not isinstance(data.get("ativo"), bool):
            raise validation("ativo precisa ser booleano.")
        payload["ativo"] = data["ativo"]
    if "escopo" in data:
        current = rest.get(
            "/rest/v1/recurring_rules",
            {"id": f"eq.{rule_id}", "select": "escopo", "limit": "1"},
        )
        if not current:
            raise validation("Regra não encontrada.")
        if data.get("escopo") != current[0].get("escopo"):
            raise validation("O escopo da regra é imutável.")
    if not payload:
        raise validation("Nenhum campo editável informado.")
    rows = rest.patch(f"/rest/v1/recurring_rules?id=eq.{rule_id}", payload)
    row = (rows or [{}])[0]
    return {**row, "categoria": category_map(rest).get(str(row.get("category_id")))}


def get_occurrence(rest: Any, occurrence_id: str) -> dict[str, Any] | None:
    occurrence_id = safe_id(occurrence_id, "occurrence_id")
    rows = rest.get(
        "/rest/v1/recurring_occurrences",
        {"id": f"eq.{occurrence_id}", "select": "*", "limit": "1"},
    )
    return rows[0] if rows else None


def ignore_occurrence(rest: Any, occurrence_id: str) -> dict[str, Any]:
    occurrence_id = safe_id(occurrence_id, "occurrence_id")
    rows = rest.patch(
        "/rest/v1/recurring_occurrences",
        {"status": "ignorado"},
        {"id": f"eq.{occurrence_id}", "status": "eq.pendente"},
    )
    return (rows or [{}])[0]
