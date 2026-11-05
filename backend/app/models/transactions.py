"""Repositório de lançamentos (RLS decide o que existe)."""

from __future__ import annotations

from typing import Any, Mapping

from ..errors import validation
from ..utils import (
    ESCOPOS,
    TIPOS,
    clean_text,
    money,
    month_end_exclusive,
    month_start,
    one_of,
    parse_date,
    safe_id,
)


def list_transactions(rest: Any, params: Mapping[str, Any]) -> tuple[list[dict[str, Any]], int]:
    mes = params.get("mes")
    filters: dict[str, Any] = {
        "select": (
            "id,tipo,escopo,valor,descricao,category_id,data,pago_por,"
            "recurring_rule_id,mes_referencia,origem,bank_transaction_id,criado_por,criado_em"
        ),
        "order": "data.desc,criado_em.desc",
        "limit": str(params.get("limit") or 100),
        "offset": str(params.get("offset") or 0),
    }
    if mes:
        start = month_start(mes)
        end = month_end_exclusive(start)
        filters["and"] = f"(data.gte.{start.isoformat()},data.lt.{end.isoformat()})"
    if params.get("tipo"):
        filters["tipo"] = f"eq.{one_of(params['tipo'], TIPOS, 'tipo')}"
    if params.get("escopo"):
        filters["escopo"] = f"eq.{one_of(params['escopo'], ESCOPOS, 'escopo')}"
    if params.get("categoria"):
        filters["category_id"] = f"eq.{safe_id(params['categoria'], 'categoria')}"
    if params.get("origem"):
        filters["origem"] = f"eq.{one_of(params['origem'], ('manual', 'pluggy'), 'origem')}"

    rows, total = rest.get("/rest/v1/transactions", filters, count=True)
    if total is None:
        count_filters = {key: value for key, value in filters.items() if key not in ("select", "order", "limit", "offset")}
        count_filters["select"] = "id"
        count_rows = rest.get("/rest/v1/transactions", count_filters) or []
        total = len(count_rows)
    return list(rows or []), total


def create_transaction(
    rest: Any,
    profile: Mapping[str, Any],
    user_id: str,
    data: Mapping[str, Any],
) -> dict[str, Any]:
    tipo = one_of(data.get("tipo"), TIPOS, "tipo")
    escopo = one_of(data.get("escopo"), ESCOPOS, "escopo")
    valor = money(data.get("valor"))
    category_id = clean_text(data.get("category_id"), "category_id", required=True, max_len=64)
    parsed_date = parse_date(data.get("data"))
    descricao = clean_text(data.get("descricao"), "descricao", max_len=500)
    pago_por = clean_text(data.get("pago_por"), "pago_por", max_len=64)
    if pago_por and escopo != "familia":
        raise validation("pago_por só existe no escopo família.")

    payload = {
        "family_id": profile["family_id"],
        "member_id": user_id,
        "tipo": tipo,
        "escopo": escopo,
        "valor": valor,
        "descricao": descricao,
        "category_id": category_id,
        "data": parsed_date.isoformat(),
        "pago_por": pago_por,
        "criado_por": user_id,
        "origem": "manual",
    }
    rows = rest.post("/rest/v1/transactions", payload)
    return (rows or [{}])[0]


EDITABLE = ("tipo", "valor", "descricao", "category_id", "data", "pago_por")


def update_transaction(rest: Any, transaction_id: str, data: Mapping[str, Any]) -> dict[str, Any]:
    transaction_id = safe_id(transaction_id, "transaction_id")
    payload: dict[str, Any] = {}
    if "tipo" in data:
        payload["tipo"] = one_of(data.get("tipo"), TIPOS, "tipo")
    if "valor" in data:
        payload["valor"] = money(data.get("valor"))
    if "descricao" in data:
        payload["descricao"] = clean_text(data.get("descricao"), "descricao", max_len=500)
    if "category_id" in data:
        payload["category_id"] = clean_text(data.get("category_id"), "category_id", required=True, max_len=64)
    if "data" in data:
        payload["data"] = parse_date(data.get("data")).isoformat()
    if "pago_por" in data:
        payload["pago_por"] = clean_text(data.get("pago_por"), "pago_por", max_len=64)
    if not payload:
        raise validation("Nenhum campo editável informado.")
    rows = rest.patch(f"/rest/v1/transactions?id=eq.{transaction_id}", payload)
    return (rows or [{}])[0]


def delete_transaction(rest: Any, transaction_id: str) -> None:
    transaction_id = safe_id(transaction_id, "transaction_id")
    rest.delete(f"/rest/v1/transactions?id=eq.{transaction_id}")
