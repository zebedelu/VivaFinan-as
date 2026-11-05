"""Endpoints da Jev AI (contexto montado pelo backend e fallback visível)."""

from __future__ import annotations

import logging
from typing import Any, Mapping

from flask import Blueprint, current_app, g, jsonify, request

from ..auth import require_profile, rest
from ..models.ai import mark_read
from ..services.ai import FallbackLLMAdapter, get_ai_service
from ..services.ai.base import normalize_text
from ..services.ai_data import (
    add_message,
    build_context,
    generate_suggestions,
    list_messages,
    list_suggestions,
)
from ..schemas.ai import validate_message, validate_read
from ..utils import body, clean_text, one_of

bp = Blueprint("ai", __name__, url_prefix="/api")
logger = logging.getLogger(__name__)


def ai_service() -> Any:
    configured = current_app.config.get("AI_SERVICE")
    if configured is not None:
        return configured
    cached = current_app.extensions.get("ai_service")
    if cached is not None:
        return cached
    env = {
        "JEV_AI_BASE_URL": current_app.config.get("JEV_AI_BASE_URL") or "",
        "JEV_AI_API_KEY": current_app.config.get("JEV_AI_API_KEY") or "",
    }
    service = get_ai_service(env, transport=current_app.config.get("AI_TRANSPORT"))
    current_app.extensions["ai_service"] = service
    return service


def _escopo(default: str = "familia") -> str:
    return one_of(request.args.get("escopo") or default, ("familia", "pessoal"), "escopo")


def _fallback() -> FallbackLLMAdapter:
    return FallbackLLMAdapter()


@bp.get("/ai/messages")
@require_profile
def get_messages():
    escopo = _escopo()
    return jsonify(
        {
            "messages": list_messages(rest(), escopo, str(g.user["id"])),
            "mode": getattr(ai_service(), "mode", "fallback"),
        }
    )


@bp.post("/ai/messages")
@require_profile
def post_message():
    data = validate_message(body())
    content = clean_text(data.get("content"), "content", required=True, max_len=4000)
    escopo = one_of(data.get("escopo") or "familia", ("familia", "pessoal"), "escopo")
    user_id = str(g.user["id"])
    client = rest()
    service = ai_service()
    fallback = _fallback()
    mode = getattr(service, "mode", "fallback")

    add_message(client, g.profile, user_id, escopo, "user", content)
    messages = list_messages(client, escopo, user_id)
    history = [
        {"role": item.get("role"), "content": item.get("content")}
        for item in messages
        if item.get("role") and item.get("content")
    ]
    try:
        context = build_context(client, g.profile, user_id, escopo)
    except Exception:
        logger.warning("Contexto de IA indisponível; usando fallback.", exc_info=True)
        context = None
    if context is None:
        answer = "Não consegui ler seus números agora. Tente de novo em instantes."
        mode = "degraded"
    else:
        try:
            answer = service.chat(history, context)
            mode = getattr(service, "mode", mode)
        except Exception:
            logger.warning("Jev AI falhou; caindo para o fallback.", exc_info=True)
            answer = fallback.chat(history, context)
            mode = "degraded"
    add_message(client, g.profile, user_id, escopo, "assistant", answer)
    suggestions, suggestion_mode = generate_suggestions(
        client,
        g.profile,
        user_id,
        escopo,
        service,
        force=True,
    )
    if suggestion_mode == "degraded":
        mode = "degraded"
    return jsonify(
        {
            "messages": list_messages(client, escopo, user_id),
            "suggestions": suggestions,
            "mode": mode,
        }
    )


@bp.get("/ai/suggestions")
@require_profile
def get_suggestions():
    escopo = _escopo()
    return jsonify(
        {
            "suggestions": list_suggestions(rest(), escopo, str(g.user["id"])),
            "mode": getattr(ai_service(), "mode", "fallback"),
        }
    )


@bp.patch("/ai/suggestions/<suggestion_id>/read")
@require_profile
def read_suggestion(suggestion_id: str):
    validate_read(body())
    row = mark_read(rest(), suggestion_id)
    return jsonify({"suggestion": row})


@bp.post("/ai/classify")
@require_profile
def classify():
    data = body()
    descricao = clean_text(data.get("descricao"), "descricao", required=True, max_len=500)
    tipo = one_of(data.get("tipo"), ("receita", "despesa"), "tipo")
    categories = rest().get(
        "/rest/v1/categories",
        {"select": "id,nome,tipo", "oculta": "eq.false", "order": "nome.asc"},
    ) or []
    service = ai_service()
    try:
        result = service.classify(descricao, tipo, categories)
        mode = getattr(service, "mode", "fallback")
    except Exception:
        logger.warning("Classificação externa falhou; usando fallback.", exc_info=True)
        result = _fallback().classify(descricao, tipo, categories)
        mode = "degraded"
    result = result if isinstance(result, Mapping) else {}
    category_id = result.get("categoria_id")
    categoria = result.get("categoria")
    valid_ids = {str(item.get("id")) for item in categories if isinstance(item, Mapping)}
    if category_id is not None and str(category_id) in valid_ids:
        category_id = str(category_id)
    else:
        category_id = None
        target = normalize_text(categoria)
        if target:
            for item in categories:
                if (
                    isinstance(item, Mapping)
                    and item.get("tipo") == tipo
                    and normalize_text(item.get("nome")) == target
                ):
                    category_id = str(item.get("id"))
                    categoria = item.get("nome")
                    break
    return jsonify(
        {
            "categoria_id": category_id,
            "categoria": categoria,
            "mode": mode,
        }
    )
