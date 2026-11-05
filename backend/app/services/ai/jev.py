"""Adaptador HTTP da Jev AI.

Chama ``JEV_AI_BASE_URL`` com ``Authorization: Bearer <JEV_AI_API_KEY>``,
timeout curto e parse tolerante. Qualquer falha vira :class:`AIUnavailable`
para o chamador usar o fallback; a chave nunca aparece em mensagem/log.
"""

from __future__ import annotations

from typing import Any, Mapping, Sequence

import httpx

from .base import (
    AIUnavailable,
    AIContext,
    AISuggestion,
    normalize_categories,
    resolve_category,
)
from .fallback import FallbackLLMAdapter

_CONNECT_TIMEOUT = 8.0
_READ_TIMEOUT = 15.0

_SUGGESTION_KEYS = ("sugestoes", "suggestions", "items")
_CHAT_KEYS = ("resposta", "response", "content", "message", "text")
_INNER_KEYS = ("data", "resultado", "result", "response")


def _inner_dicts(data: Mapping[str, Any]) -> list[Mapping[str, Any]]:
    found: list[Mapping[str, Any]] = []
    for key in _INNER_KEYS:
        value = data.get(key)
        if isinstance(value, Mapping):
            found.append(value)
    return found


def _first_text(data: Mapping[str, Any], keys: Sequence[str]) -> str | None:
    for key in keys:
        value = data.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return None


def _extract_text(data: Mapping[str, Any], keys: Sequence[str]) -> str | None:
    text = _first_text(data, keys)
    if text:
        return text
    for inner in _inner_dicts(data):
        text = _first_text(inner, keys)
        if text:
            return text
    return None


def _extract_list(data: Any) -> list[Any] | None:
    if isinstance(data, list):
        return data
    if not isinstance(data, Mapping):
        return None
    for key in _SUGGESTION_KEYS:
        value = data.get(key)
        if isinstance(value, list):
            return value
    for inner in _inner_dicts(data):
        for key in _SUGGESTION_KEYS:
            value = inner.get(key)
            if isinstance(value, list):
                return value
    return None


def _text_field(item: Mapping[str, Any], *keys: str) -> str | None:
    for key in keys:
        value = item.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return None


class JevAIAdapter:
    """Cliente fino da Jev AI; sem retry e sem log de credencial."""

    mode = "jev"

    def __init__(
        self,
        base_url: str,
        api_key: str,
        *,
        timeout: httpx.Timeout | float | None = None,
        transport: httpx.BaseTransport | None = None,
        client: httpx.Client | None = None,
    ) -> None:
        if not base_url or not str(base_url).strip():
            raise ValueError("JEV_AI_BASE_URL é obrigatório")
        if not api_key or not str(api_key).strip():
            raise ValueError("JEV_AI_API_KEY é obrigatório")
        self._base_url = str(base_url).strip().rstrip("/")
        self._api_key = str(api_key).strip()
        if client is not None:
            self._client = client
        else:
            self._client = httpx.Client(
                timeout=timeout or httpx.Timeout(_READ_TIMEOUT, connect=_CONNECT_TIMEOUT),
                transport=transport,
            )
        self._fallback = FallbackLLMAdapter()

    def close(self) -> None:
        self._client.close()

    def __enter__(self) -> "JevAIAdapter":
        return self

    def __exit__(self, *args: Any) -> None:
        self.close()

    def _headers(self) -> dict[str, str]:
        return {
            "Authorization": f"Bearer {self._api_key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        }

    def _post(self, path: str, payload: Mapping[str, Any]) -> Any:
        try:
            response = self._client.post(
                f"{self._base_url}{path}",
                json=payload,
                headers=self._headers(),
            )
        except httpx.HTTPError as exc:
            # Só o tipo do erro: nada de corpo, URL com query ou credencial.
            raise AIUnavailable(f"Jev AI indisponível ({type(exc).__name__})") from None
        if response.status_code >= 400:
            raise AIUnavailable(f"Jev AI respondeu HTTP {response.status_code}")
        try:
            return response.json()
        except ValueError:
            raise AIUnavailable("Jev AI devolveu resposta inválida") from None

    # -- classificação -----------------------------------------------------

    def classify(
        self,
        descricao: str,
        tipo: str,
        categorias: Sequence[Mapping[str, Any] | str] | None = None,
    ) -> dict[str, Any]:
        names = [item["nome"] for item in normalize_categories(categorias)]
        payload = {"descricao": descricao, "tipo": tipo, "categorias": names}
        data = self._post("/classify", payload)
        if not isinstance(data, Mapping):
            raise AIUnavailable("Jev AI devolveu classificação inválida")
        nome = _extract_text(data, ("categoria", "category", "nome", "classificacao"))
        if not nome:
            raise AIUnavailable("Jev AI não devolveu categoria")
        return resolve_category(nome, tipo, categorias)

    # -- sugestões ---------------------------------------------------------

    def suggest(self, context: AIContext) -> list[AISuggestion]:
        data = self._post("/suggest", {"contexto": context.to_payload()})
        raw = _extract_list(data)
        if raw is None:
            raise AIUnavailable("Jev AI não devolveu sugestões")

        fallback = self._fallback.suggest(context)
        suggestions: list[AISuggestion] = []
        for index, item in enumerate(raw[:4]):
            if not isinstance(item, Mapping):
                continue
            base = fallback[index] if index < len(fallback) else fallback[0]
            suggestion = AISuggestion(
                tipo=_text_field(item, "tipo", "type") or base.tipo,
                titulo=_text_field(item, "titulo", "title") or base.titulo,
                o_que=_text_field(item, "o_que", "oque", "action", "oQue") or base.o_que,
                por_que=_text_field(item, "por_que", "porque", "reason", "porQue") or base.por_que,
                quanto=_text_field(item, "quanto", "amount", "estimativa") or base.quanto,
            )
            if suggestion.is_valid():
                suggestions.append(suggestion)

        if not suggestions:
            return fallback
        return suggestions

    # -- chat --------------------------------------------------------------

    def chat(self, messages: Sequence[Mapping[str, Any]], context: AIContext) -> str:
        safe_messages = [
            {
                "role": str(message.get("role", "user")),
                "content": str(message.get("content", "")),
            }
            for message in messages or []
            if isinstance(message, Mapping)
        ]
        data = self._post("/chat", {"messages": safe_messages, "contexto": context.to_payload()})
        if not isinstance(data, Mapping):
            raise AIUnavailable("Jev AI devolveu resposta inválida")
        text = _extract_text(data, _CHAT_KEYS)
        if not text:
            raise AIUnavailable("Jev AI não devolveu resposta")
        return text
