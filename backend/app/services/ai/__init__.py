"""Serviço de IA do VivaFinanças.

Ponto de entrada: ``get_ai_service()``.

- ``JEV_AI_BASE_URL`` + ``JEV_AI_API_KEY`` com ``JEV_AI_PROVIDER=opencode``
  (ou base contendo ``opencode``) -> ``OpenCodeGoAdapter`` (modo ``opencode``).
- Caso contrário, a mesma dupla -> ``JevAIAdapter`` (modo ``jev``).
- Os dois adaptadores reais são embrulhados em :class:`ResilientAIAdapter`.
- Sem chave/base -> ``FallbackLLMAdapter`` (modo ``fallback``).
- Falha/timeout/HTTP >= 400 ou contexto vazio -> fallback no mesmo request e
  ``mode == "degraded"``.
"""

from __future__ import annotations

import os
from typing import Any, Mapping, Sequence

from .base import (
    AIAdapter,
    AIContext,
    AISuggestion,
    AIUnavailable,
    ESCOPO_FAMILIA,
    ESCOPO_PESSOAL,
    SEM_ESTIMATIVA,
)
from .fallback import FallbackLLMAdapter
from .jev import JevAIAdapter
from .opencode import DEFAULT_MODEL, DEFAULT_TIMEOUT, OpenCodeGoAdapter

__all__ = [
    "AIAdapter",
    "AIContext",
    "AISuggestion",
    "AIUnavailable",
    "ESCOPO_FAMILIA",
    "ESCOPO_PESSOAL",
    "SEM_ESTIMATIVA",
    "FallbackLLMAdapter",
    "JevAIAdapter",
    "OpenCodeGoAdapter",
    "ResilientAIAdapter",
    "get_ai_service",
]


class ResilientAIAdapter:
    """Usa a Jev AI e cai para o fallback sem derrubar o endpoint."""

    def __init__(
        self,
        primary: AIAdapter,
        fallback: FallbackLLMAdapter | None = None,
    ) -> None:
        self._primary = primary
        self._fallback = fallback or FallbackLLMAdapter()
        self._degraded = False
        self.last_error: str | None = None

    @property
    def mode(self) -> str:
        return "degraded" if self._degraded else getattr(self._primary, "mode", "jev")

    def _use_fallback(self, error: str | None = None) -> None:
        self._degraded = True
        self.last_error = error

    def _succeed(self) -> None:
        self._degraded = False
        self.last_error = None

    def classify(
        self,
        descricao: str,
        tipo: str,
        categorias: Sequence[Mapping[str, Any] | str] | None = None,
    ) -> dict[str, Any]:
        try:
            result = self._primary.classify(descricao, tipo, categorias)
        except AIUnavailable as exc:
            self._use_fallback(str(exc))
            return self._fallback.classify(descricao, tipo, categorias)
        self._succeed()
        return result

    def suggest(self, context: AIContext) -> list[AISuggestion]:
        ctx = context if isinstance(context, AIContext) else AIContext()
        if ctx.is_empty():
            self._use_fallback("contexto vazio")
            return self._fallback.suggest(ctx)
        try:
            result = self._primary.suggest(ctx)
        except AIUnavailable as exc:
            self._use_fallback(str(exc))
            return self._fallback.suggest(ctx)
        if not result:
            self._use_fallback("Jev AI devolveu lista vazia")
            return self._fallback.suggest(ctx)
        self._succeed()
        return result

    def chat(self, messages: Sequence[Mapping[str, Any]], context: AIContext) -> str:
        ctx = context if isinstance(context, AIContext) else AIContext()
        if ctx.is_empty():
            self._use_fallback("contexto vazio")
            return self._fallback.chat(messages, ctx)
        try:
            result = self._primary.chat(messages, ctx)
        except AIUnavailable as exc:
            self._use_fallback(str(exc))
            return self._fallback.chat(messages, ctx)
        if not isinstance(result, str) or not result.strip():
            self._use_fallback("Jev AI devolveu resposta vazia")
            return self._fallback.chat(messages, ctx)
        self._succeed()
        return result


def _text(source: Mapping[str, Any], key: str) -> str:
    value = source.get(key)
    return "" if value is None else str(value).strip()


def _seconds(source: Mapping[str, Any], key: str, default: float) -> float:
    value = source.get(key)
    if value is None or value == "":
        return default
    try:
        seconds = float(value)
    except (TypeError, ValueError):
        return default
    return seconds if seconds > 0 else default


def _uses_opencode(provider: str, base_url: str) -> bool:
    """``JEV_AI_PROVIDER`` manda; sem ele, a base contendo ``opencode`` decide."""
    normalized = (provider or "").strip().lower()
    if normalized == "opencode":
        return True
    if normalized:
        return False
    return "opencode" in (base_url or "").lower()


def get_ai_service(
    env: Mapping[str, str] | None = None,
    *,
    transport: Any = None,
) -> AIAdapter:
    """Monta o adaptador conforme o ambiente.

    ``transport`` existe para testes (``httpx.MockTransport``); em produção é
    omitido e o cliente usa a rede.
    """
    source = os.environ if env is None else env
    base_url = _text(source, "JEV_AI_BASE_URL")
    api_key = _text(source, "JEV_AI_API_KEY")

    if not base_url or not api_key:
        return FallbackLLMAdapter()

    if _uses_opencode(_text(source, "JEV_AI_PROVIDER"), base_url):
        primary: AIAdapter = OpenCodeGoAdapter(
            base_url,
            api_key,
            model=_text(source, "JEV_AI_MODEL") or DEFAULT_MODEL,
            session=_text(source, "JEV_AI_SESSION"),
            timeout=_seconds(source, "JEV_AI_TIMEOUT", DEFAULT_TIMEOUT),
            transport=transport,
        )
    else:
        primary = JevAIAdapter(base_url, api_key, transport=transport)
    return ResilientAIAdapter(primary, FallbackLLMAdapter())
