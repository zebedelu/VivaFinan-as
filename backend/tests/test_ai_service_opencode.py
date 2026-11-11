"""Testes do adaptador OpenCode Go (Chat Completions) e da seleção na factory."""

from __future__ import annotations

import json

import httpx
import pytest

from app.services.ai import (
    AIAdapter,
    AIContext,
    AIUnavailable,
    FallbackLLMAdapter,
    JevAIAdapter,
    OpenCodeGoAdapter,
    ResilientAIAdapter,
    get_ai_service,
)
from app.services.ai.opencode import DEFAULT_MODEL

BASE = "https://opencode.test/inference/go/openai/v1"
KEY = "secret-key"

CATEGORIAS = [
    {"id": "c-alimentacao", "nome": "Alimentação", "tipo": "despesa"},
    {"id": "c-outros", "nome": "Outros", "tipo": "despesa"},
]


def _ctx() -> AIContext:
    return AIContext(
        escopo="pessoal",
        member_id="u-1",
        totais={"receitas": 5000, "despesas": 4000, "saldo": 1000},
        categorias=[{"categoria": "Alimentação", "total": 900, "tipo": "despesa"}],
        media_3m={"Alimentação": 800},
        banco_pendentes=1,
    )


def _completion(content: str) -> dict:
    return {
        "id": "chatcmpl-teste",
        "object": "chat.completion",
        "choices": [{"index": 0, "message": {"role": "assistant", "content": content}}],
    }


def _adapter(handler) -> OpenCodeGoAdapter:
    return OpenCodeGoAdapter(
        BASE,
        KEY,
        model="modelo-teste",
        session="sessao-fixa",
        transport=httpx.MockTransport(handler),
    )


def test_payload_e_headers_da_classificacao():
    seen: dict[str, object] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        seen["request"] = request
        seen["body"] = json.loads(request.content.decode("utf-8"))
        return httpx.Response(
            200,
            json=_completion('{"categoria": "Alimentação", "categoria_id": "c-alimentacao"}'),
        )

    adapter = _adapter(handler)
    assert isinstance(adapter, AIAdapter)
    resultado = adapter.classify("Mercado", "despesa", CATEGORIAS)

    assert resultado == {"categoria_id": "c-alimentacao", "categoria": "Alimentação"}

    request = seen["request"]
    body = seen["body"]
    assert request.method == "POST"
    assert str(request.url) == f"{BASE}/chat/completions"
    assert request.url.path.endswith("/chat/completions")
    assert request.headers["authorization"] == f"Bearer {KEY}"
    assert request.headers["content-type"].startswith("application/json")
    assert request.headers["x-opencode-session"] == "sessao-fixa"
    assert request.headers["user-agent"].startswith("vivafinancas/")
    assert body["model"] == "modelo-teste"
    assert body["response_format"] == {"type": "json_object"}
    assert body["temperature"] == 0
    assert body["messages"][0]["role"] == "system"
    assert "Alimentação" in body["messages"][1]["content"]
    assert KEY not in json.dumps(body)


@pytest.mark.parametrize(
    "content",
    [
        '{"categoria": "Alimentação"}',
        '```json\n{"categoria": "Alimentação"}\n```',
        'Claro! ```json\n{"categoria": "alimentacao"}\n```',
        'Segue a resposta: {"categoria": "ALIMENTAÇÃO"}',
    ],
)
def test_classify_aceita_json_tolerante(content: str):
    adapter = _adapter(lambda request: httpx.Response(200, json=_completion(content)))

    resultado = adapter.classify("Mercado", "despesa", CATEGORIAS)

    assert resultado == {"categoria_id": "c-alimentacao", "categoria": "Alimentação"}


def test_classify_rejeita_categoria_fora_do_contexto():
    adapter = _adapter(
        lambda request: httpx.Response(200, json=_completion('{"categoria": "Cripto"}'))
    )

    with pytest.raises(AIUnavailable):
        adapter.classify("Mercado", "despesa", CATEGORIAS)


def test_suggest_retorna_campos_obrigatorios():
    conteudo = json.dumps(
        {
            "sugestoes": [
                {
                    "tipo": "categoria",
                    "titulo": "Revisar Alimentação",
                    "o_que": "Reveja os gastos de mercado.",
                    "por_que": "Subiu em relação à média.",
                    "quanto": "R$ 100,00",
                },
                {
                    "tipo": "orcamento",
                    "titulo": "Direcionar a sobra",
                    "o_que": "Separar a sobra para uma meta.",
                    "por_que": "Sobraram R$ 1.000,00 no mês.",
                    "quanto": "R$ 1.000,00",
                },
            ]
        }
    )
    adapter = _adapter(lambda request: httpx.Response(200, json=_completion(conteudo)))

    sugestoes = adapter.suggest(_ctx())

    assert len(sugestoes) == 2
    assert all(s.is_valid() for s in sugestoes)
    assert sugestoes[0].titulo == "Revisar Alimentação"
    assert sugestoes[0].quanto == "R$ 100,00"
    assert sugestoes[1].tipo == "orcamento"


def test_suggest_parse_tolerante_completa_campos():
    def handler(request: httpx.Request) -> httpx.Response:
        body = json.loads(request.content.decode("utf-8"))
        assert body["response_format"] == {"type": "json_object"}
        assert "contexto" in body["messages"][1]["content"]
        return httpx.Response(
            200,
            json=_completion('```json\n{"suggestions": [{"title": "Revisar lazer"}]}\n```'),
        )

    adapter = _adapter(handler)
    sugestoes = adapter.suggest(_ctx())

    assert len(sugestoes) == 1
    assert sugestoes[0].titulo == "Revisar lazer"
    assert sugestoes[0].is_valid()
    assert sugestoes[0].o_que.strip()
    assert sugestoes[0].por_que.strip()
    assert sugestoes[0].quanto.strip()


def test_chat_devolve_texto_e_envia_contexto():
    seen: list[dict] = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(json.loads(request.content.decode("utf-8")))
        return httpx.Response(200, json=_completion("Resposta da Jev."))

    adapter = _adapter(handler)
    resposta = adapter.chat([{"role": "user", "content": "Quanto posso economizar?"}], _ctx())

    assert resposta == "Resposta da Jev."
    body = seen[0]
    assert "response_format" not in body
    assert "receitas" in body["messages"][0]["content"]
    assert body["messages"][-1]["content"] == "Quanto posso economizar?"


def test_sessao_gerada_e_estavel_quando_nao_configurada():
    sessions: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        sessions.append(request.headers["x-opencode-session"])
        return httpx.Response(200, json=_completion("ok"))

    adapter = OpenCodeGoAdapter(BASE, KEY, transport=httpx.MockTransport(handler))
    adapter.chat([{"role": "user", "content": "Oi"}], _ctx())
    adapter.chat([{"role": "user", "content": "Oi"}], _ctx())

    assert len(sessions) == 2
    assert sessions[0] == sessions[1]
    assert sessions[0].startswith("vivafinancas-")


@pytest.mark.parametrize("falha", ["timeout", "http_500", "corpo_invalido", "json_invalido"])
def test_falhas_viram_aiunavailable(falha: str):
    def handler(request: httpx.Request) -> httpx.Response:
        if falha == "timeout":
            raise httpx.ConnectTimeout("timeout de teste")
        if falha == "http_500":
            return httpx.Response(500, json={"error": "boom"})
        if falha == "corpo_invalido":
            return httpx.Response(200, content=b"nao-e-json")
        return httpx.Response(200, json=_completion("nao-e-json"))

    adapter = _adapter(handler)

    with pytest.raises(AIUnavailable) as excinfo:
        adapter.classify("Mercado", "despesa", CATEGORIAS)
    assert KEY not in str(excinfo.value)


def test_timeout_no_chat_levanta_aiunavailable():
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ReadTimeout("timeout de teste")

    adapter = _adapter(handler)
    with pytest.raises(AIUnavailable):
        adapter.chat([{"role": "user", "content": "Oi"}], _ctx())


# -- factory ---------------------------------------------------------------


def _opencode_handler(request: httpx.Request) -> httpx.Response:
    if request.url.path.endswith("/chat/completions"):
        return httpx.Response(200, json=_completion('{"categoria": "Alimentação"}'))
    return httpx.Response(404, json={"error": "rota desconhecida"})


def _jev_handler(request: httpx.Request) -> httpx.Response:
    if request.url.path.endswith("/classify"):
        return httpx.Response(200, json={"categoria": "Alimentação"})
    return httpx.Response(404, json={"error": "rota desconhecida"})


def test_factory_com_provider_opencode():
    seen: list[dict] = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(json.loads(request.content.decode("utf-8")))
        return _opencode_handler(request)

    service = get_ai_service(
        env={
            "JEV_AI_BASE_URL": BASE,
            "JEV_AI_API_KEY": KEY,
            "JEV_AI_PROVIDER": "OpenCode",
            "JEV_AI_MODEL": "outro-modelo",
            "JEV_AI_SESSION": "sessao-do-ambiente",
            "JEV_AI_TIMEOUT": "30",
        },
        transport=httpx.MockTransport(handler),
    )

    assert isinstance(service, ResilientAIAdapter)
    assert service.mode == "opencode"
    assert service.classify("Mercado", "despesa", CATEGORIAS)["categoria"] == "Alimentação"
    assert service.mode == "opencode"
    assert seen[0]["model"] == "outro-modelo"


def test_factory_base_opencode_sem_provider():
    service = get_ai_service(
        env={"JEV_AI_BASE_URL": BASE, "JEV_AI_API_KEY": KEY},
        transport=httpx.MockTransport(_opencode_handler),
    )

    assert service.mode == "opencode"


def test_factory_provider_jev_mantem_adaptador_legado():
    service = get_ai_service(
        env={"JEV_AI_BASE_URL": BASE, "JEV_AI_API_KEY": KEY, "JEV_AI_PROVIDER": "jev"},
        transport=httpx.MockTransport(_jev_handler),
    )

    assert isinstance(service, ResilientAIAdapter)
    assert service._primary.__class__ is JevAIAdapter
    assert service.mode == "jev"
    assert service.classify("Mercado", "despesa", CATEGORIAS)["categoria"] == "Alimentação"
    assert service.mode == "jev"


def test_factory_base_sem_opencode_mantem_jev():
    service = get_ai_service(
        env={"JEV_AI_BASE_URL": "https://jev.test", "JEV_AI_API_KEY": KEY},
        transport=httpx.MockTransport(_jev_handler),
    )

    assert service.mode == "jev"


def test_factory_sem_chave_ou_base_usa_fallback():
    assert get_ai_service(env={}).mode == "fallback"
    assert isinstance(get_ai_service(env={}), FallbackLLMAdapter)
    assert get_ai_service(env={"JEV_AI_BASE_URL": BASE}).mode == "fallback"
    assert (
        get_ai_service(env={"JEV_AI_API_KEY": KEY, "JEV_AI_PROVIDER": "opencode"}).mode
        == "fallback"
    )


def test_factory_usa_modelo_default_sem_jev_ai_model():
    seen: list[dict] = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(json.loads(request.content.decode("utf-8")))
        return _opencode_handler(request)

    service = get_ai_service(
        env={"JEV_AI_BASE_URL": BASE, "JEV_AI_API_KEY": KEY},
        transport=httpx.MockTransport(handler),
    )
    service.classify("Mercado", "despesa", CATEGORIAS)

    assert seen[0]["model"] == DEFAULT_MODEL


def test_factory_falha_500_vira_degraded_com_fallback():
    service = get_ai_service(
        env={"JEV_AI_BASE_URL": BASE, "JEV_AI_API_KEY": KEY, "JEV_AI_PROVIDER": "opencode"},
        transport=httpx.MockTransport(lambda request: httpx.Response(500, json={"error": "boom"})),
    )

    sugestoes = service.suggest(_ctx())

    assert 1 <= len(sugestoes) <= 4
    assert all(item.is_valid() for item in sugestoes)
    assert service.mode == "degraded"
    assert "500" in (service.last_error or "")
