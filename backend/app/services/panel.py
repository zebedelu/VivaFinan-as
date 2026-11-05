"""Montagem do painel familiar e do resumo pessoal."""

from __future__ import annotations

from typing import Any, Mapping

from ..models.common import member_names
from ..models.goals import list_goals
from ..models.banking import list_connections
from ..utils import add_months, month_start, num
from .ai_data import generate_suggestions
from .alerts import build_alerts
from .analytics import category_breakdown, category_names, media_by_category, totals
from .recurring import materialize


def _range(field: str, start: str, end: str) -> dict[str, str]:
    return {"and": f"({field}.gte.{start},{field}.lt.{end})"}


def _bank_counts(rest: Any) -> tuple[list[dict[str, Any]], int]:
    connections = list_connections(rest)
    pending = rest.get(
        "/rest/v1/bank_transactions",
        {"select": "id", "status": "eq.pendente_importacao"},
    ) or []
    return connections, len(pending)


def dashboard(
    rest: Any,
    profile: Mapping[str, Any],
    user_id: str,
    ai: Any,
    mes: Any = None,
) -> dict[str, Any]:
    month = month_start(mes)
    month_iso = month.isoformat()
    next_iso = add_months(month, 1).isoformat()
    family_id = profile["family_id"]

    totals_rows = rest.rpc("family_totals", {"p_family_id": family_id, "p_mes": month_iso}) or []
    totals_row = totals_rows[0] if totals_rows else {}
    receitas = num(totals_row.get("receitas"))
    despesas = num(totals_row.get("despesas"))

    monthly = rest.rpc(
        "family_monthly_totals",
        {"p_family_id": family_id, "p_mes_fim": month_iso},
    ) or []
    serie = [
        {
            "mes": row.get("mes"),
            "receitas": num(row.get("receitas")),
            "despesas": num(row.get("despesas")),
        }
        for row in monthly
        if isinstance(row, Mapping)
    ]
    acumulado = {
        "receitas": round(sum(row["receitas"] for row in serie), 2),
        "despesas": round(sum(row["despesas"] for row in serie), 2),
    }

    categories = rest.rpc(
        "family_category_totals",
        {"p_family_id": family_id, "p_mes": month_iso},
    ) or []
    categorias = [
        {
            "category_id": item.get("category_id"),
            "categoria": item.get("categoria"),
            "total": num(item.get("total")),
        }
        for item in categories
        if isinstance(item, Mapping)
    ]

    media_rows = rest.get(
        "/rest/v1/transactions",
        {
            "select": "tipo,valor,category_id,data",
            "tipo": "eq.despesa",
            **_range("data", add_months(month, -3).isoformat(), month_iso),
        },
    ) or []
    media = media_by_category(media_rows, category_names(rest), months=3)
    categorias_media = [
        {**item, "media_3m": media.get(item["categoria"] or "", 0), "escopo": "familia"}
        for item in categorias
    ]

    members = rest.rpc("family_member_directory", {"p_family_id": family_id}) or []
    member_map = member_names(members)
    metas = list_goals(rest, "familia", user_id, member_map)

    pending = materialize(rest, month)
    suggestions, mode = generate_suggestions(rest, profile, user_id, "familia", ai, month)
    connections, pendentes = _bank_counts(rest)
    alertas = build_alerts(
        pending=pending,
        categorias=categorias_media,
        metas=metas,
        connections=connections,
        escopo="familia",
    )
    return {
        "mes": month_iso,
        "mode": mode,
        "totais": {
            "receitas": round(receitas, 2),
            "despesas": round(despesas, 2),
            "saldo": round(receitas - despesas, 2),
        },
        "acumulado": acumulado,
        "categorias": categorias,
        "serie": serie,
        "membros": [
            {"member_id": item.get("member_id"), "nome": item.get("nome"), "papel": item.get("papel")}
            for item in members
            if isinstance(item, Mapping)
        ],
        "metas": metas,
        "sugestoes": suggestions,
        "alertas": alertas,
        "recorrentes_pendentes": [item for item in pending if item["dias_para_vencimento"] <= 3],
        "banco": {
            "conexoes_ativas": sum(1 for item in connections if item.get("status") == "ativa"),
            "pendentes": pendentes,
        },
    }


def me_summary(
    rest: Any,
    profile: Mapping[str, Any],
    user_id: str,
    ai: Any,
    mes: Any = None,
) -> dict[str, Any]:
    month = month_start(mes)
    month_iso = month.isoformat()
    next_iso = add_months(month, 1).isoformat()

    personal = rest.get(
        "/rest/v1/transactions",
        {
            "select": "id,tipo,valor,descricao,data,category_id,origem",
            "member_id": f"eq.{user_id}",
            "escopo": "eq.pessoal",
            **_range("data", month_iso, next_iso),
        },
    ) or []
    names = category_names(rest)
    categorias = category_breakdown(personal, names, tipo="despesa")
    media_rows = rest.get(
        "/rest/v1/transactions",
        {
            "select": "tipo,valor,category_id,data",
            "member_id": f"eq.{user_id}",
            "escopo": "eq.pessoal",
            "tipo": "eq.despesa",
            **_range("data", add_months(month, -3).isoformat(), month_iso),
        },
    ) or []
    media = media_by_category(media_rows, names, months=3)
    categorias_media = [
        {**item, "media_3m": media.get(item["categoria"] or "", 0), "escopo": "pessoal"}
        for item in categorias
    ]

    members = rest.rpc("family_member_directory", {"p_family_id": profile["family_id"]}) or []
    member_map = member_names(members)
    metas = list_goals(rest, "pessoal", user_id, member_map)

    pending_all = materialize(rest, month)
    pending = [item for item in pending_all if item.get("escopo") == "pessoal"]
    suggestions, mode = generate_suggestions(rest, profile, user_id, "pessoal", ai, month)
    connections, pendentes = _bank_counts(rest)
    ultima = max(
        (item.get("ultima_sync_em") for item in connections if item.get("ultima_sync_em")),
        default=None,
    )
    alertas = build_alerts(
        pending=pending,
        categorias=categorias_media,
        metas=metas,
        connections=connections,
        escopo="pessoal",
        member_id=user_id,
    )
    totais = totals(personal)
    return {
        "mes": month_iso,
        "mode": mode,
        "totais": totais,
        "categorias": categorias,
        "metas": metas,
        "recorrentes_pendentes": pending,
        "sugestoes": suggestions,
        "alertas": alertas,
        "banco": {
            "conexoes": sum(1 for item in connections if item.get("status") == "ativa"),
            "pendentes": pendentes,
            "ultima_sync": ultima,
        },
    }


def personal_alerts(
    rest: Any,
    profile: Mapping[str, Any],
    user_id: str,
    mes: Any = None,
) -> list[dict[str, Any]]:
    month = month_start(mes)
    month_iso = month.isoformat()
    next_iso = add_months(month, 1).isoformat()
    personal = rest.get(
        "/rest/v1/transactions",
        {
            "select": "tipo,valor,category_id",
            "member_id": f"eq.{user_id}",
            "escopo": "eq.pessoal",
            **_range("data", month_iso, next_iso),
        },
    ) or []
    names = category_names(rest)
    categorias = category_breakdown(personal, names, tipo="despesa")
    media_rows = rest.get(
        "/rest/v1/transactions",
        {
            "select": "tipo,valor,category_id",
            "member_id": f"eq.{user_id}",
            "escopo": "eq.pessoal",
            "tipo": "eq.despesa",
            **_range("data", add_months(month, -3).isoformat(), month_iso),
        },
    ) or []
    media = media_by_category(media_rows, names, months=3)
    categorias_media = [
        {**item, "media_3m": media.get(item["categoria"] or "", 0), "escopo": "pessoal"}
        for item in categorias
    ]
    members = rest.rpc("family_member_directory", {"p_family_id": profile["family_id"]}) or []
    metas = list_goals(rest, "pessoal", user_id, member_names(members))
    pending = [item for item in materialize(rest, month) if item.get("escopo") == "pessoal"]
    connections, _ = _bank_counts(rest)
    return build_alerts(
        pending=pending,
        categorias=categorias_media,
        metas=metas,
        connections=connections,
        escopo="pessoal",
        member_id=user_id,
    )
