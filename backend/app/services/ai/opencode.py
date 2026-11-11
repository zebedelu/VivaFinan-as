"""Adaptador do OpenCode Go (Chat Completions compatível com OpenAI).

Chama ``{JEV_AI_BASE_URL}/chat/completions`` com ``Authorization: Bearer
<JEV_AI_API_KEY>``, ``x-opencode-session`` estável e ``User-Agent`` próprio.
``classify``/``suggest`` pedem ``response_format={"type": "json_object"}`` e
fazem parse tolerante (cerca ```json, chaves alternativas). Qualquer falha de
rede, HTTP, timeout ou JSON vira :class:`AIUnavailable` para o
:class:`ResilientAIAdapter` cair no fallback; a chave nunca aparece em
mensagem/log.
"""

from __future__ import annotations

import json
import re
import uuid
from typing import Any, Mapping, Sequence

import httpx

from .base import (
    AIContext,
    AISuggestion,
    AIUnavailable,
    normalize_categories,
    normalize_text,
    normalize_tipo,
    resolve_category,
)
from .fallback import FallbackLLMAdapter

DEFAULT_MODEL = "deepseek-v4.1-flash"
DEFAULT_TIMEOUT = 75.0
USER_AGENT = "vivafinancas/1.0"

_CONNECT_TIMEOUT = 10.0
_CLASSIFY_TOKENS = 200
_SUGGEST_TOKENS = 900
_CHAT_TOKENS = 600
_MAX_MESSAGES = 12
_MAX_MESSAGE_CHARS = 2000

# Mesmas chaves que o adaptador legado (jev.py) já tolera.
_SUGGESTION_KEYS = ("sugestoes", "suggestions", "items")
_INNER_KEYS = ("data", "resultado", "result", "response")

_FENCE_RE = re.compile(r"```(?:json)?\s*(.+?)\s*```", re.DOTALL)

_CLASSIFY_SYSTEM = (
    "Você classifica lançamentos financeiros de uma família brasileira. "
    "Escolha UMA categoria da lista recebida e responda apenas com JSON: "
    '{"categoria": "<nome exato da lista>", "categoria_id": "<id ou null>"}. '
    "Nunca invente categoria fora da lista; sem correspondência, use null nos dois campos."
)

_SUGGEST_SYSTEM = (
    "Você é a Jev, assistente financeira de uma família brasileira. "
    "Gere de 1 a 4 sugestões práticas usando apenas os números do contexto. "
    "Responda apenas com JSON no formato "
    '{"sugestoes": [{"tipo": "...", "titulo": "...", "o_que": "...", "por_que": "...", '
    '"quanto": "..."}]}. '
    'Todos os cinco campos são obrigatórios; "quanto" em reais ("R$ 1.234,56") '
    'ou "não é possível estimar". Não invente valor fora do contexto e não use markdown.'
)

_CHAT_SYSTEM = (
    "Você é a Jev, assistente financeira de uma família brasileira. "
    "Responda em até três frases, em português do Brasil, usando apenas os números "
    "do contexto. Se faltar dado, diga que não é possível estimar. "
    "Sem markdown e sem prometer decisão pronta."
)


# -- helpers de parse ------------------------------------------------------


def _strip_fences(text: str) -> str:
    """Remove a cerca ```json ... ``` que alguns modelos colocam em volta."""
    match = _FENCE_RE.search(text)
    return match.group(1).strip() if match else text.strip()


def _slice_braces(text: str) -> str:
    start = text.find("{")
    end = text.rfind("}")
    return text[start : end + 1] if -1 < start < end else ""


def _load_json(text: str) -> Any:
    """JSON da ``content``, tolerando cerca e texto em volta."""
    candidate = _strip_fences(text)
    for attempt in (candidate, _slice_braces(candidate)):
        if not attempt:
            continue
        try:
            return json.loads(attempt)
        except ValueError:
            continue
    raise AIUnavailable("OpenCode Go devolveu JSON inválido")


def _inner_dicts(data: Mapping[str, Any]) -> list[Mapping[str, Any]]:
    found: list[Mapping[str, Any]] = []
    for key in _INNER_KEYS:
        value = data.get(key)
        if isinstance(value, Mapping):
            found.append(value)
    return found


def _text_field(item: Mapping[str, Any], *keys: str) -> str | None:
    for key in keys:
        value = item.get(key)
        if isinstance(value, bool) or value is None:
            continue
        if isinstance(value, (str, int, float)):
            text = str(value).strip()
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


def _completion_content(data: Mapping[str, Any]) -> str:
    choices = data.get("choices")
    if isinstance(choices, (list, tuple)) and choices:
        first = choices[0]
        if isinstance(first, Mapping):
            message = first.get("message")
            if isinstance(message, Mapping):
                content = message.get("content")
                if isinstance(content, str) and content.strip():
                    return content.strip()
    raise AIUnavailable("OpenCode Go não devolveu conteúdo")


def _timeout_of(value: Any) -> httpx.Timeout:
    if isinstance(value, httpx.Timeout):
        return value
    try:
        seconds = float(value)
    except (TypeError, ValueError):
        seconds = DEFAULT_TIMEOUT
    if seconds <= 0:
        seconds = DEFAULT_TIMEOUT
    return httpx.Timeout(seconds, connect=min(_CONNECT_TIMEOUT, seconds))


def _new_session() -> str:
    return f"vivafinancas-{uuid.uuid4().hex[:16]}"


class OpenCodeGoAdapter:
    """Cliente fino do OpenCode Go; sem retry e sem log de credencial."""

    mode = "opencode"

    def __init__(
        self,
        base_url: str,
        api_key: str,
        *,
        model: str | None = None,
        session: str | None = None,
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
        self._model = str(model or DEFAULT_MODEL).strip() or DEFAULT_MODEL
        self._session = str(session or "").strip() or _new_session()
        if client is not None:
            self._client = client
        else:
            self._client = httpx.Client(
                timeout=_timeout_of(timeout),
                transport=transport,
            )
        self._fallback = FallbackLLMAdapter()

    def close(self) -> None:
        self._client.close()

    def __enter__(self) -> "OpenCodeGoAdapter":
        return self

    def __exit__(self, *args: Any) -> None:
        self.close()

    def _headers(self) -> dict[str, str]:
        return {
            "Authorization": f"Bearer {self._api_key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": USER_AGENT,
            "x-opencode-session": self._session,
        }

    # -- transporte --------------------------------------------------------

    def _complete(
        self,
        messages: Sequence[Mapping[str, str]],
        *,
        max_tokens: int,
        json_mode: bool,
    ) -> str:
        payload: dict[str, Any] = {
            "model": self._model,
            "messages": list(messages),
            "temperature": 0,
            "max_tokens": max_tokens,
        }
        if json_mode:
            payload["response_format"] = {"type": "json_object"}
        try:
            response = self._client.post(
                f"{self._base_url}/chat/completions",
                json=payload,
                headers=self._headers(),
            )
        except httpx.HTTPError as exc:
            # Só o tipo do erro: nada de corpo, URL ou credencial.
            raise AIUnavailable(f"OpenCode Go indisponível ({type(exc).__name__})") from None
        if response.status_code >= 400:
            raise AIUnavailable(f"OpenCode Go respondeu HTTP {response.status_code}")
        try:
            data = response.json()
        except ValueError:
            raise AIUnavailable("OpenCode Go devolveu resposta inválida") from None
        if not isinstance(data, Mapping):
            raise AIUnavailable("OpenCode Go devolveu resposta inválida")
        return _completion_content(data)

    # -- classificação -----------------------------------------------------

    def classify(
        self,
        descricao: str,
        tipo: str,
        categorias: Sequence[Mapping[str, Any] | str] | None = None,
    ) -> dict[str, Any]:
        cats = normalize_categories(categorias)
        pedido = {
            "descricao": str(descricao or "")[:500],
            "tipo": normalize_tipo(tipo) or str(tipo or ""),
            "categorias": [
                {"nome": item["nome"], "id": item.get("id"), "tipo": item.get("tipo")}
                for item in cats
            ],
        }
        content = self._complete(
            [
                {"role": "system", "content": _CLASSIFY_SYSTEM},
                {"role": "user", "content": json.dumps(pedido, ensure_ascii=False)},
            ],
            max_tokens=_CLASSIFY_TOKENS,
            json_mode=True,
        )
        data = _load_json(content)
        if not isinstance(data, Mapping):
            raise AIUnavailable("OpenCode Go devolveu classificação inválida")

        nome = _text_field(data, "categoria", "category", "nome", "classificacao")
        if nome is None:
            category_id = _text_field(data, "categoria_id", "category_id", "id")
            for item in cats:
                if str(item.get("id")) == str(category_id):
                    nome = item["nome"]
                    break
        if not nome:
            raise AIUnavailable("OpenCode Go não devolveu categoria")
        if cats:
            known = {normalize_text(item["nome"]) for item in cats}
            if normalize_text(nome) not in known:
                raise AIUnavailable("OpenCode Go devolveu categoria fora do contexto")
        return resolve_category(nome, tipo, categorias)

    # -- sugestões ---------------------------------------------------------

    def suggest(self, context: AIContext) -> list[AISuggestion]:
        content = self._complete(
            [
                {"role": "system", "content": _SUGGEST_SYSTEM},
                {
                    "role": "user",
                    "content": json.dumps(
                        {"contexto": context.to_payload()}, ensure_ascii=False
                    ),
                },
            ],
            max_tokens=_SUGGEST_TOKENS,
            json_mode=True,
        )
        raw = _extract_list(_load_json(content))
        if raw is None:
            raise AIUnavailable("OpenCode Go não devolveu sugestões")

        fallback = self._fallback.suggest(context)
        suggestions: list[AISuggestion] = []
        for index, item in enumerate(raw[:4]):
            if not isinstance(item, Mapping):
                continue
            base = fallback[index] if index < len(fallback) else fallback[0]
            suggestion = AISuggestion(
                tipo=_text_field(item, "tipo", "type") or base.tipo,
                titulo=_text_field(item, "titulo", "title") or base.titulo,
                o_que=_text_field(item, "o_que", "oque", "oQue", "action") or base.o_que,
                por_que=_text_field(item, "por_que", "porque", "porQue", "reason") or base.por_que,
                quanto=_text_field(item, "quanto", "amount", "estimativa") or base.quanto,
            )
            if suggestion.is_valid():
                suggestions.append(suggestion)

        if not suggestions:
            return fallback
        return suggestions

    # -- chat --------------------------------------------------------------

    def chat(self, messages: Sequence[Mapping[str, Any]], context: AIContext) -> str:
        safe_messages: list[Mapping[str, str]] = [
            {
                "role": "system",
                "content": f"{_CHAT_SYSTEM}\nContexto financeiro (JSON): "
                f"{json.dumps(context.to_payload(), ensure_ascii=False)}",
            }
        ]
        for message in list(messages or [])[-_MAX_MESSAGES:]:
            if not isinstance(message, Mapping):
                continue
            content = message.get("content")
            if isinstance(content, str) and content.strip():
                role = str(message.get("role", "user")).strip().lower()
                safe_messages.append(
                    {
                        "role": role if role in ("user", "assistant", "system") else "user",
                        "content": content.strip()[:_MAX_MESSAGE_CHARS],
                    }
                )
        if len(safe_messages) == 1:
            raise AIUnavailable("OpenCode Go não recebeu mensagem")

        content = self._complete(
            safe_messages,
            max_tokens=_CHAT_TOKENS,
            json_mode=False,
        )
        return content
