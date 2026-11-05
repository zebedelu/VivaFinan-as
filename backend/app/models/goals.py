"""Metas e contribuições."""

from __future__ import annotations

from typing import Any, Mapping

from ..errors import not_found, validation
from ..utils import clean_text, money, one_of, parse_date, safe_id, today_sp
from .common import goal_payload


def list_goals(
    rest: Any,
    escopo: str,
    user_id: str,
    members: Mapping[str, str],
) -> list[dict[str, Any]]:
    params: dict[str, Any] = {
        "select": "*,goal_contributions(id,member_id,valor,data)",
        "order": "criado_em.desc",
    }
    if escopo == "pessoal":
        params["member_id"] = f"eq.{user_id}"
    else:
        params["member_id"] = "is.null"
    rows = rest.get("/rest/v1/goals", params) or []
    return [goal_payload(row, members) for row in rows if isinstance(row, Mapping)]


def create_goal(
    rest: Any,
    profile: Mapping[str, Any],
    user_id: str,
    data: Mapping[str, Any],
) -> dict[str, Any]:
    member_id = data.get("member_id") or None
    if member_id and str(member_id) != user_id:
        raise validation("member_id precisa ser o usuário autenticado.")
    prazo = data.get("prazo")
    payload = {
        "family_id": profile["family_id"],
        "member_id": member_id,
        "criado_por": user_id,
        "titulo": clean_text(data.get("titulo"), "titulo", required=True, max_len=120),
        "valor_alvo": money(data.get("valor_alvo"), "valor_alvo"),
        "prazo": parse_date(prazo, "prazo").isoformat() if prazo else None,
        "descricao": clean_text(data.get("descricao"), "descricao", max_len=2000),
        "status": "em_andamento",
    }
    rows = rest.post("/rest/v1/goals", payload)
    row = (rows or [{}])[0]
    row["goal_contributions"] = []
    members = {str(user_id): profile.get("nome") or ""}
    return goal_payload(row, members)


def update_goal(rest: Any, goal_id: str, data: Mapping[str, Any], members: Mapping[str, str]) -> dict[str, Any]:
    goal_id = safe_id(goal_id, "goal_id")
    payload: dict[str, Any] = {}
    if "titulo" in data:
        payload["titulo"] = clean_text(data.get("titulo"), "titulo", required=True, max_len=120)
    if "valor_alvo" in data:
        payload["valor_alvo"] = money(data.get("valor_alvo"), "valor_alvo")
    if "prazo" in data:
        payload["prazo"] = (
            parse_date(data.get("prazo"), "prazo").isoformat() if data.get("prazo") else None
        )
    if "descricao" in data:
        payload["descricao"] = clean_text(data.get("descricao"), "descricao", max_len=2000)
    if "status" in data:
        payload["status"] = one_of(
            data.get("status"),
            ("em_andamento", "concluida", "cancelada"),
            "status",
        )
    if "member_id" in data:
        raise validation("member_id é imutável.")
    if not payload:
        raise validation("Nenhum campo editável informado.")
    rest.patch(f"/rest/v1/goals?id=eq.{goal_id}", payload)
    return goal_payload(_full_goal(rest, goal_id), members)


def _full_goal(rest: Any, goal_id: str) -> Mapping[str, Any]:
    goal_id = safe_id(goal_id, "goal_id")
    rows = rest.get(
        "/rest/v1/goals",
        {
            "id": f"eq.{goal_id}",
            "select": "*,goal_contributions(id,member_id,valor,data)",
            "limit": "1",
        },
    )
    if not rows:
        raise not_found("Meta não encontrada.")
    return rows[0]


def delete_goal(rest: Any, goal_id: str) -> None:
    goal_id = safe_id(goal_id, "goal_id")
    rest.delete(f"/rest/v1/goals?id=eq.{goal_id}")


def _goal(rest: Any, goal_id: str) -> Mapping[str, Any]:
    goal_id = safe_id(goal_id, "goal_id")
    rows = rest.get(
        "/rest/v1/goals",
        {"id": f"eq.{goal_id}", "select": "*", "limit": "1"},
    )
    if not rows:
        raise not_found("Meta não encontrada.")
    return rows[0]


def list_contributions(
    rest: Any,
    goal_id: str,
    members: Mapping[str, str],
) -> list[dict[str, Any]]:
    _goal(rest, goal_id)
    rows = rest.get(
        "/rest/v1/goal_contributions",
        {
            "goal_id": f"eq.{goal_id}",
            "select": "id,member_id,valor,data",
            "order": "data.asc",
        },
    ) or []
    return [
        {
            "id": item.get("id"),
            "member_id": item.get("member_id"),
            "member_nome": members.get(str(item.get("member_id"))),
            "valor": item.get("valor"),
            "data": item.get("data"),
        }
        for item in rows
        if isinstance(item, Mapping)
    ]


def create_contribution(
    rest: Any,
    goal_id: str,
    user_id: str,
    data: Mapping[str, Any],
) -> dict[str, Any]:
    _goal(rest, goal_id)
    payload = {
        "goal_id": goal_id,
        "member_id": user_id,
        "valor": money(data.get("valor")),
        "data": parse_date(data.get("data") or today_sp(), "data").isoformat(),
    }
    rows = rest.post("/rest/v1/goal_contributions", payload)
    return (rows or [{}])[0]


__all__ = [
    "create_contribution",
    "create_goal",
    "delete_goal",
    "list_contributions",
    "list_goals",
    "update_goal",
]
