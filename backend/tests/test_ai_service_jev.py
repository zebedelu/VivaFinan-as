"""Testes do adaptador Jev AI, da resiliência e da factory."""

from __future__ import annotations

import httpx
import pytest

from app.services.ai import (
    AIContext,
    AIUnavailable,
    FallbackLLMAdapter,
    JevAIAdapter,
    ResilientAIAdapter,
    get_ai_service,
)

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


def _ok_handler(request: httpx.Request) -> httpx.Response:
    path = request.url.path
    if path.endswith("/classify"):
        return httpx.Response(200, json={"categoria": "Alimentação"})
    if path.endswith("/suggest"):
        return httpx.Response(
            200,
            json={
                "sugestoes": [
                    {
                        "tipo": "categoria",
                        "titulo": "Revisar Alimentação",
                        "o_que": "Reveja os gastos.",
                        "por_que": "Subiu no mês.",
                        "quanto": "R$ 100,00",
                    }
                ]
            },
        )
    if path.endswith("/chat"):
        return httpx.Response(200, json={"resposta": "Resposta da Jev."})
    return httpx.Response(404, json={"error": "rota desconhecida"})


def _adapter(handler) -> JevAIAdapter:
    return JevAIAdapter(
        "https://jev.test/",
        "secret-key",
        transport=httpx.MockTransport(handler),
    )


def test_classify_suggest_chat_sucesso():
    requests: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        requests.append(request)
        return _ok_handler(request)

    adapter = _adapter(handler)

    classificacao = adapter.classify("Mercado", "despesa", CATEGORIAS)
    assert classificacao == {"categoria_id": "c-alimentacao", "categoria": "Alimentação"}

    sugestoes = adapter.suggest(_ctx())
    assert len(sugestoes) == 1
    assert sugestoes[0].is_valid()
    assert sugestoes[0].quanto == "R$ 100,00"

    resposta = adapter.chat([{"role": "user", "content": "Oi"}], _ctx())
    assert resposta == "Resposta da Jev."

    assert len(requests) == 3
    for request in requests:
        assert request.headers["authorization"] == "Bearer secret-key"
        assert request.headers["content-type"].startswith("application/json")


def test_suggest_parse_tolerante_completa_campos():
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"sugestoes": [{"titulo": "Revisar lazer"}]})

    adapter = _adapter(handler)
    sugestoes = adapter.suggest(_ctx())

    assert len(sugestoes) == 1
    assert sugestoes[0].titulo == "Revisar lazer"
    assert sugestoes[0].is_valid()
    assert sugestoes[0].o_que.strip()
    assert sugestoes[0].por_que.strip()
    assert sugestoes[0].quanto.strip()


def test_suggest_sem_lista_levanta_aiunavailable():
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"ok": True})

    adapter = _adapter(handler)
    with pytest.raises(AIUnavailable):
        adapter.suggest(_ctx())


def test_http_500_levanta_aiunavailable():
    adapter = _adapter(lambda request: httpx.Response(500, json={"error": "boom"}))
    with pytest.raises(AIUnavailable):
        adapter.suggest(_ctx())


def test_timeout_levanta_aiunavailable():
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectTimeout("timeout de teste")

    adapter = _adapter(handler)
    with pytest.raises(AIUnavailable):
        adapter.chat([{"role": "user", "content": "Oi"}], _ctx())


def test_json_invalido_levanta_aiunavailable():
    adapter = _adapter(lambda request: httpx.Response(200, content=b"nao-e-json"))
    with pytest.raises(AIUnavailable):
        adapter.classify("Mercado", "despesa", CATEGORIAS)


def test_factory_sem_chave_usa_fallback():
    service = get_ai_service(env={})
    assert isinstance(service, FallbackLLMAdapter)
    assert service.mode == "fallback"


def test_factory_com_chave_usa_jev():
    service = get_ai_service(
        env={"JEV_AI_BASE_URL": "https://jev.test", "JEV_AI_API_KEY": "secret-key"},
        transport=httpx.MockTransport(_ok_handler),
    )
    assert isinstance(service, ResilientAIAdapter)
    assert service.mode == "jev"
    assert service.classify("Mercado", "despesa", CATEGORIAS)["categoria"] == "Alimentação"
    assert service.mode == "jev"


def test_factory_chave_incompleta_usa_fallback():
    service = get_ai_service(env={"JEV_AI_API_KEY": "secret-key"})
    assert isinstance(service, FallbackLLMAdapter)
    assert service.mode == "fallback"


def test_falha_500_vira_degraded_com_fallback():
    service = get_ai_service(
        env={"JEV_AI_BASE_URL": "https://jev.test", "JEV_AI_API_KEY": "secret-key"},
        transport=httpx.MockTransport(lambda request: httpx.Response(500, json={"error": "boom"})),
    )

    sugestoes = service.suggest(_ctx())

    assert 1 <= len(sugestoes) <= 4
    assert all(s.is_valid() for s in sugestoes)
    assert service.mode == "degraded"
    assert "500" in (service.last_error or "")


def test_timeout_no_chat_vira_degraded_com_fallback():
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectTimeout("timeout de teste")

    service = get_ai_service(
        env={"JEV_AI_BASE_URL": "https://jev.test", "JEV_AI_API_KEY": "secret-key"},
        transport=httpx.MockTransport(handler),
    )

    resposta = service.chat([{"role": "user", "content": "Quanto posso economizar?"}], _ctx())

    assert resposta.strip()
    assert "apoio" in resposta.lower()
    assert service.mode == "degraded"


def test_contexto_vazio_nao_chama_rede_e_fica_degraded():
    def handler(request: httpx.Request) -> httpx.Response:
        raise AssertionError("não deveria chamar a rede com contexto vazio")

    service = get_ai_service(
        env={"JEV_AI_BASE_URL": "https://jev.test", "JEV_AI_API_KEY": "secret-key"},
        transport=httpx.MockTransport(handler),
    )

    resposta = service.chat([{"role": "user", "content": "Quanto posso economizar?"}], AIContext())

    assert "não é possível estimar" in resposta
    assert "R$" not in resposta
    assert service.mode == "degraded"


def test_contexto_vazio_suggest_nao_chama_rede():
    def handler(request: httpx.Request) -> httpx.Response:
        raise AssertionError("não deveria chamar a rede com contexto vazio")

    service = get_ai_service(
        env={"JEV_AI_BASE_URL": "https://jev.test", "JEV_AI_API_KEY": "secret-key"},
        transport=httpx.MockTransport(handler),
    )

    sugestoes = service.suggest(AIContext())

    assert len(sugestoes) == 1
    assert sugestoes[0].is_valid()
    assert service.mode == "degraded"
