"""Helpers de leitura compartilhados pelos modelos."""

from __future__ import annotations

from typing import Any, Iterable, Mapping

from ..utils import num


def category_map(rest: Any) -> dict[str, str]:
    rows = rest.get("/rest/v1/categories", {"select": "id,nome", "order": "nome.asc"})
    return {
        str(item["id"]): item.get("nome") or ""
        for item in (rows or [])
        if isinstance(item, Mapping) and item.get("id")
    }


def member_directory(rest: Any, profile: Mapping[str, Any]) -> list[dict[str, Any]]:
    rows = rest.rpc(
        "family_member_directory",
        {"p_family_id": profile["family_id"]},
    )
    return [dict(item) for item in (rows or []) if isinstance(item, Mapping)]


def member_names(members: Iterable[Mapping[str, Any]]) -> dict[str, str]:
    return {
        str(item["member_id"]): item.get("nome") or ""
        for item in members
        if item.get("member_id")
    }


def transaction_payload(
    row: Mapping[str, Any],
    names: Mapping[str, str],
    members: Mapping[str, str],
) -> dict[str, Any]:
    return {
        "id": row.get("id"),
        "tipo": row.get("tipo"),
        "escopo": row.get("escopo"),
        "valor": row.get("valor"),
        "descricao": row.get("descricao"),
        "category_id": row.get("category_id"),
        "categoria": names.get(str(row.get("category_id"))),
        "data": row.get("data"),
        "pago_por": row.get("pago_por"),
        "pago_por_nome": members.get(str(row.get("pago_por"))) if row.get("pago_por") else None,
        "recurring_rule_id": row.get("recurring_rule_id"),
        "mes_referencia": row.get("mes_referencia"),
        "origem": row.get("origem"),
        "bank_transaction_id": row.get("bank_transaction_id"),
        "criado_por": row.get("criado_por"),
        "criado_em": row.get("criado_em"),
    }


def goal_payload(
    row: Mapping[str, Any],
    members: Mapping[str, str],
) -> dict[str, Any]:
    contributions = row.get("goal_contributions")
    if not isinstance(contributions, list):
        contributions = []
    contributions = sorted(
        [
            {
                "id": item.get("id"),
                "member_id": item.get("member_id"),
                "member_nome": members.get(str(item.get("member_id"))),
                "valor": item.get("valor"),
                "data": item.get("data"),
            }
            for item in contributions
            if isinstance(item, Mapping)
        ],
        key=lambda item: (str(item.get("data") or ""), str(item.get("id") or "")),
    )
    total = sum(num(item.get("valor")) for item in contributions)
    target = num(row.get("valor_alvo"))
    progresso = round((total / target) * 100, 2) if target > 0 else 0
    member_id = row.get("member_id")
    return {
        "id": row.get("id"),
        "titulo": row.get("titulo"),
        "valor_alvo": row.get("valor_alvo"),
        "prazo": row.get("prazo"),
        "status": row.get("status"),
        "descricao": row.get("descricao"),
        "member_id": member_id,
        "member_nome": members.get(str(member_id)) if member_id else None,
        "criado_por": row.get("criado_por"),
        "criado_por_nome": members.get(str(row.get("criado_por"))),
        "progresso": progresso,
        "contribuicoes": contributions,
    }
