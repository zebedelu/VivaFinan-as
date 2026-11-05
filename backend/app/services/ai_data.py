"""Contexto e persistência da Jev AI (dados montados pelo backend)."""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any, Iterable, Mapping

from ..errors import ApiError
from ..utils import add_months, current_month, days_until, num, parse_date, today_sp
from .analytics import category_breakdown, category_names, media_by_category, totals
from .ai import AIContext, AISuggestion
from .ai.base import normalize_escopo

ESCOPO_FAMILIA = "familia"
ESCOPO_PESSOAL = "pessoal"
JANELA_RECENTE_HORAS = 24

logger = logging.getLogger(__name__)


def member_scope(escopo: str, user_id: str) -> str | None:
    return None if normalize_escopo(escopo) == ESCOPO_FAMILIA else user_id


def _member_filter(member_id: str | None) -> dict[str, str]:
    return {"member_id": "is.null" if member_id is None else f"eq.{member_id}"}


def _range(field: str, start: str, end: str) -> dict[str, str]:
    return {"and": f"({field}.gte.{start},{field}.lt.{end})"}


def _is_recent(value: Any) -> bool:
    if not value:
        return False
    try:
        parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return False
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return (datetime.now(timezone.utc) - parsed).total_seconds() < JANELA_RECENTE_HORAS * 3600


def list_suggestions(rest: Any, escopo: str, user_id: str) -> list[dict[str, Any]]:
    rows = rest.get(
        "/rest/v1/ai_suggestions",
        {
            "select": "id,family_id,member_id,tipo,titulo,o_que,por_que,quanto,lida,criado_em",
            **_member_filter(member_scope(escopo, user_id)),
            "order": "criado_em.desc",
            "limit": "8",
        },
    )
    return list(rows or [])


def list_messages(rest: Any, escopo: str, user_id: str) -> list[dict[str, Any]]:
    rows = rest.get(
        "/rest/v1/ai_messages",
        {
            "select": "id,family_id,member_id,role,content,criado_em",
            **_member_filter(member_scope(escopo, user_id)),
            "order": "criado_em.asc",
            "limit": "200",
        },
    )
    return list(rows or [])


def add_message(
    rest: Any,
    profile: Mapping[str, Any],
    user_id: str,
    escopo: str,
    role: str,
    content: str,
) -> dict[str, Any]:
    rows = rest.post(
        "/rest/v1/ai_messages",
        {
            "family_id": profile["family_id"],
            "member_id": member_scope(escopo, user_id),
            "role": role,
            "content": content,
        },
    )
    return (rows or [{}])[0]


def _goals(rest: Any, profile: Mapping[str, Any], escopo: str, user_id: str) -> list[dict[str, Any]]:
    params: dict[str, str] = {"select": "id,member_id,titulo,valor_alvo,status,prazo"}
    if normalize_escopo(escopo) == ESCOPO_PESSOAL:
        params["member_id"] = f"eq.{user_id}"
    else:
        params["member_id"] = "is.null"
    rows = rest.get("/rest/v1/goals", params) or []
    hoje = today_sp()
    result: list[dict[str, Any]] = []
    for goal in rows:
        if not isinstance(goal, Mapping):
            continue
        prazo = goal.get("prazo")
        try:
            dias = days_until(parse_date(prazo, "prazo"), hoje) if prazo else None
        except ApiError:
            dias = None
        result.append(
            {
                "id": goal.get("id"),
                "titulo": goal.get("titulo"),
                "valor_alvo": goal.get("valor_alvo"),
                "status": goal.get("status"),
                "prazo": prazo,
                "dias_para_prazo": dias,
            }
        )
    return result


def _banco_pendentes(rest: Any) -> int:
    rows = rest.get(
        "/rest/v1/bank_transactions",
        {"select": "id", "status": "eq.pendente_importacao"},
    )
    return len(rows or [])


def build_context(
    rest: Any,
    profile: Mapping[str, Any],
    user_id: str,
    escopo: str,
    mes: Any = None,
) -> AIContext:
    escopo = normalize_escopo(escopo)
    month = current_month() if mes is None else mes
    month_iso = month.isoformat()
    next_iso = add_months(month, 1).isoformat()
    media_start = add_months(month, -3).isoformat()
    names = category_names(rest)
    banco = _banco_pendentes(rest)

    if escopo == ESCOPO_FAMILIA:
        family_id = profile["family_id"]
        family_totals = rest.rpc(
            "family_totals",
            {"p_family_id": family_id, "p_mes": month_iso},
        )
        row = (family_totals or [{}])[0] if isinstance(family_totals, list) else {}
        totais = {
            "receitas": num(row.get("receitas")),
            "despesas": num(row.get("despesas")),
        }
        totais["saldo"] = round(totais["receitas"] - totais["despesas"], 2)

        family_categories = rest.rpc(
            "family_category_totals",
            {"p_family_id": family_id, "p_mes": month_iso},
        ) or []
        categorias = [
            {
                "category_id": item.get("category_id"),
                "categoria": item.get("categoria"),
                "total": num(item.get("total")),
                "tipo": "despesa",
            }
            for item in family_categories
            if isinstance(item, Mapping)
        ]

        media_rows = rest.get(
            "/rest/v1/transactions",
            {
                "select": "tipo,valor,category_id,data",
                "tipo": "eq.despesa",
                **_range("data", media_start, month_iso),
            },
        ) or []
        media = media_by_category(media_rows, names, months=3)
        return AIContext(
            escopo=escopo,
            totais=totais,
            categorias=categorias,
            media_3m=media,
            metas=_goals(rest, profile, escopo, user_id),
            transacoes=[],
            banco_pendentes=banco,
        )

    personal_rows = rest.get(
        "/rest/v1/transactions",
        {
            "select": "id,tipo,valor,descricao,data,category_id,origem",
            "member_id": f"eq.{user_id}",
            "escopo": "eq.pessoal",
            **_range("data", month_iso, next_iso),
        },
    ) or []
    totais = totals(personal_rows)
    categorias = category_breakdown(personal_rows, names, tipo="despesa")
    for item in categorias:
        item["tipo"] = "despesa"
    media_rows = rest.get(
        "/rest/v1/transactions",
        {
            "select": "tipo,valor,category_id,data",
            "member_id": f"eq.{user_id}",
            "escopo": "eq.pessoal",
            "tipo": "eq.despesa",
            **_range("data", media_start, month_iso),
        },
    ) or []
    media = media_by_category(media_rows, names, months=3)
    recent = rest.get(
        "/rest/v1/transactions",
        {
            "select": "member_id,tipo,valor,descricao,data,category_id,origem",
            "member_id": f"eq.{user_id}",
            "escopo": "eq.pessoal",
            "order": "data.desc",
            "limit": "40",
        },
    ) or []
    transactions = [
        {
            "member_id": item.get("member_id"),
            "tipo": item.get("tipo"),
            "valor": num(item.get("valor")),
            "descricao": item.get("descricao"),
            "data": item.get("data"),
            "categoria": names.get(str(item.get("category_id"))),
            "origem": item.get("origem"),
        }
        for item in recent
        if isinstance(item, Mapping)
    ]
    return AIContext(
        escopo=escopo,
        totais=totais,
        categorias=categorias,
        media_3m=media,
        metas=_goals(rest, profile, escopo, user_id),
        transacoes=transactions,
        banco_pendentes=banco,
        member_id=user_id,
    )


def persist_suggestions(
    rest: Any,
    profile: Mapping[str, Any],
    user_id: str,
    escopo: str,
    suggestions: Iterable[AISuggestion],
) -> int:
    created = 0
    for suggestion in suggestions:
        if not suggestion.is_valid():
            continue
        try:
            rest.post(
                "/rest/v1/ai_suggestions",
                {
                    "family_id": profile["family_id"],
                    "member_id": member_scope(escopo, user_id),
                    "tipo": suggestion.tipo,
                    "titulo": suggestion.titulo,
                    "o_que": suggestion.o_que,
                    "por_que": suggestion.por_que,
                    "quanto": suggestion.quanto,
                },
            )
            created += 1
        except ApiError as exc:
            if exc.status == 409:
                continue
            logger.warning("Falha ao persistir sugestão de IA: %s", exc.code)
    return created


def generate_suggestions(
    rest: Any,
    profile: Mapping[str, Any],
    user_id: str,
    escopo: str,
    ai: Any,
    mes: Any = None,
    *,
    force: bool = False,
) -> tuple[list[dict[str, Any]], str]:
    existing = list_suggestions(rest, escopo, user_id)
    if not force and any(_is_recent(item.get("criado_em")) for item in existing):
        return existing, getattr(ai, "mode", "fallback")
    try:
        context = build_context(rest, profile, user_id, escopo, mes)
        suggestions = ai.suggest(context)
    except ApiError:
        logger.warning("Contexto de IA indisponível; mantendo sugestões existentes.")
        return existing, getattr(ai, "mode", "fallback")
    except Exception:  # pragma: no cover - adaptador externo imprevisível
        logger.exception("Falha inesperada ao gerar sugestões.")
        return existing, getattr(ai, "mode", "fallback")
    persist_suggestions(rest, profile, user_id, escopo, suggestions)
    return list_suggestions(rest, escopo, user_id), getattr(ai, "mode", "fallback")
