"""API da Jev AI: classify, mensagens, sugestões e fallback."""

from __future__ import annotations

from datetime import datetime, timezone

from conftest import FAMILY_ID, body_of, profile_route

from app.services.ai import AISuggestion, FallbackLLMAdapter

CATEGORIES = [
    {"id": "c-alim", "nome": "Alimentação", "tipo": "despesa"},
    {"id": "c-moradia", "nome": "Moradia", "tipo": "despesa"},
    {"id": "c-salario", "nome": "Salário", "tipo": "receita"},
]


class StubAI:
    mode = "fallback"

    def classify(self, descricao, tipo, categorias=None):
        return {"categoria_id": "c-alim", "categoria": "Alimentação"}

    def suggest(self, context):
        return [
            AISuggestion(
                tipo="assinatura",
                titulo="Revise as assinaturas",
                o_que="Cancele o streaming parado.",
                por_que="É o gasto que mais cresceu.",
                quanto="R$ 80 por mês",
            )
        ]

    def chat(self, messages, context):
        return "Seu mês está sob controle; acompanhe as assinaturas."


def test_classify_uses_family_categories_and_fallback(client, fake, auth_headers):
    profile_route(fake)
    fake.add("GET", "/rest/v1/categories", CATEGORIES)
    response = client.post(
        "/api/ai/classify",
        headers=auth_headers,
        json={"descricao": "Padaria do bairro", "tipo": "despesa"},
    )
    assert response.status_code == 200, response.get_json()
    payload = response.get_json()
    assert payload["categoria_id"] == "c-alim"
    assert payload["categoria"] == "Alimentação"
    assert payload["mode"] == "fallback"


def test_classify_without_match_returns_null_id(client, fake, auth_headers):
    profile_route(fake)
    fake.add(
        "GET",
        "/rest/v1/categories",
        [
            {"id": "c-moradia", "nome": "Moradia", "tipo": "despesa"},
            {"id": "c-outros", "nome": "Outros", "tipo": "despesa"},
        ],
    )
    response = client.post(
        "/api/ai/classify",
        headers=auth_headers,
        json={"descricao": "xyz sem palavra conhecida", "tipo": "despesa"},
    )
    assert response.status_code == 200
    assert response.get_json()["categoria_id"] is None
    assert response.get_json()["categoria"] is None


def test_messages_and_suggestions_shapes(client, fake, auth_headers):
    profile_route(fake)
    fake.add(
        "GET",
        "/rest/v1/ai_messages",
        [
            {
                "id": "m1",
                "family_id": FAMILY_ID,
                "member_id": None,
                "role": "user",
                "content": "Como está o mês?",
                "criado_em": "2026-11-01T12:00:00Z",
            }
        ],
    )
    fake.add(
        "GET",
        "/rest/v1/ai_suggestions",
        [
            {
                "id": "s1",
                "tipo": "assinatura",
                "titulo": "Revise",
                "o_que": "Cancele",
                "por_que": "Cresceu",
                "quanto": "R$ 80",
                "lida": False,
                "criado_em": datetime.now(timezone.utc).isoformat(),
            }
        ],
    )
    messages = client.get("/api/ai/messages?escopo=familia", headers=auth_headers)
    assert messages.status_code == 200
    assert messages.get_json()["messages"][0]["role"] == "user"
    assert messages.get_json()["mode"] == "fallback"

    suggestions = client.get("/api/ai/suggestions?escopo=familia", headers=auth_headers)
    assert suggestions.status_code == 200
    assert suggestions.get_json()["suggestions"][0]["id"] == "s1"
    assert suggestions.get_json()["mode"] == "fallback"


def test_mark_suggestion_read(client, fake, auth_headers):
    profile_route(fake)
    fake.add(
        "PATCH",
        "/rest/v1/ai_suggestions",
        [{"id": "s1", "lida": True}],
    )
    blocked = client.patch(
        "/api/ai/suggestions/s1/read",
        headers=auth_headers,
        json={"lida": False},
    )
    assert blocked.status_code == 422
    response = client.patch(
        "/api/ai/suggestions/s1/read",
        headers=auth_headers,
        json={"lida": True},
    )
    assert response.status_code == 200
    assert body_of(fake.last("PATCH", "/rest/v1/ai_suggestions")) == {"lida": True}


def test_post_message_persists_and_returns_suggestions(make_client, fake, auth_headers):
    client = make_client(AI_SERVICE=StubAI())
    profile_route(fake)
    fake.add("POST", "/rest/v1/ai_messages", [{"id": "m-new"}])
    fake.add(
        "GET",
        "/rest/v1/ai_messages",
        [
            {
                "id": "m1",
                "role": "user",
                "content": "Como está o mês?",
                "criado_em": "2026-11-01T12:00:00Z",
            }
        ],
    )
    fake.add("GET", "/rest/v1/categories", CATEGORIES)
    fake.add("GET", "/rest/v1/bank_transactions", [])
    fake.add("POST", "/rest/v1/rpc/family_totals", [{"receitas": 12000, "despesas": 7800}])
    fake.add(
        "POST",
        "/rest/v1/rpc/family_category_totals",
        [{"category_id": "c-alim", "categoria": "Alimentação", "total": 100}],
    )
    fake.add("GET", "/rest/v1/transactions", [])
    fake.add("GET", "/rest/v1/goals", [])
    fake.add(
        "POST",
        "/rest/v1/ai_suggestions",
        [{"id": "s-new", "titulo": "Revise as assinaturas"}],
    )
    fake.add(
        "GET",
        "/rest/v1/ai_suggestions",
        [
            {
                "id": "s-new",
                "tipo": "assinatura",
                "titulo": "Revise as assinaturas",
                "o_que": "Cancele o streaming parado.",
                "por_que": "É o gasto que mais cresceu.",
                "quanto": "R$ 80 por mês",
                "lida": False,
                "criado_em": datetime.now(timezone.utc).isoformat(),
            }
        ],
    )
    response = client.post(
        "/api/ai/messages",
        headers=auth_headers,
        json={"content": "Como está o mês?", "escopo": "familia"},
    )
    assert response.status_code == 200, response.get_json()
    data = response.get_json()
    assert data["mode"] == "fallback"
    assert data["suggestions"][0]["id"] == "s-new"
    inserts = fake.calls("POST", "/rest/v1/ai_messages")
    assert len(inserts) == 2
    assert body_of(inserts[0])["role"] == "user"
    assert body_of(inserts[0])["member_id"] is None
    assert body_of(inserts[1])["role"] == "assistant"
    assert body_of(inserts[1])["content"].startswith("Seu mês está sob controle")


def test_ai_defaults_to_fallback_without_keys(client, fake, auth_headers):
    profile_route(fake)
    fake.add("GET", "/rest/v1/categories", CATEGORIES)
    response = client.post(
        "/api/ai/classify",
        headers=auth_headers,
        json={"descricao": "Uber para o trabalho", "tipo": "despesa"},
    )
    assert response.status_code == 200
    assert response.get_json()["mode"] == "fallback"
