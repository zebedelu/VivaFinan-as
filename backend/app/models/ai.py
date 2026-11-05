"""Persistência de sugestões (mensagens ficam no serviço de contexto)."""

from __future__ import annotations

from typing import Any

from ..utils import safe_id


def mark_read(rest: Any, suggestion_id: str) -> dict[str, Any]:
    suggestion_id = safe_id(suggestion_id, "suggestion_id")
    rows = rest.patch(
        "/rest/v1/ai_suggestions",
        {"lida": True},
        {"id": f"eq.{suggestion_id}"},
    )
    return (rows or [{}])[0]
