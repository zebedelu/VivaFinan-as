"""Dashboard, resumo pessoal e alertas (shapes do contrato)."""

from __future__ import annotations

from datetime import datetime, timezone

from conftest import FAMILY_ID, PROFILE, body_of, profile_route

MES = "2026-11-01"
NOW = datetime.now(timezone.utc).isoformat()


def _dashboard_routes(fake, *, since_recent: bool = True):
    profile_route(fake)
    fake.add(
        "POST",
        "/rest/v1/rpc/family_totals",
        [{"receitas": 12000, "despesas": 7800}],
    )
    fake.add(
        "POST",
        "/rest/v1/rpc/family_monthly_totals",
        [
            {"mes": "2026-06-01", "receitas": 11000, "despesas": 8200},
            {"mes": "2026-07-01", "receitas": 11200, "despesas": 7900},
            {"mes": "2026-11-01", "receitas": 12000, "despesas": 7800},
        ],
    )
    fake.add(
        "POST",
        "/rest/v1/rpc/family_category_totals",
        [{"category_id": "c-moradia", "categoria": "Moradia", "total": 3200}],
    )
    fake.add(
        "GET",
        "/rest/v1/categories",
        [{"id": "c-moradia", "nome": "Moradia"}],
    )
    fake.add("GET", "/rest/v1/transactions", [])
    fake.add(
        "POST",
        "/rest/v1/rpc/family_member_directory",
        [{"member_id": "u-ana", "nome": "Ana Souza", "papel": "admin"}],
    )
    fake.add("GET", "/rest/v1/goals", [])
    fake.add("GET", "/rest/v1/recurring_rules", [])
    fake.add("GET", "/rest/v1/recurring_occurrences", [])
    suggestions = (
        [
            {
                "id": "s1",
                "family_id": FAMILY_ID,
                "member_id": None,
                "tipo": "assinatura",
                "titulo": "Revise as assinaturas",
                "o_que": "Cancele o streaming parado.",
                "por_que": "É o gasto que mais cresceu.",
                "quanto": "R$ 80 por mês",
                "lida": False,
                "criado_em": NOW,
            }
        ]
        if since_recent
        else []
    )
    fake.add("GET", "/rest/v1/ai_suggestions", suggestions)
    fake.add("GET", "/rest/v1/bank_connections", [{"id": "bc1", "status": "ativa"}])
    fake.add("GET", "/rest/v1/bank_transactions", [{"id": "bt1"}, {"id": "bt2"}])


def test_dashboard_shape(client, fake, auth_headers):
    _dashboard_routes(fake)
    response = client.get(f"/api/dashboard?mes={MES}", headers=auth_headers)
    assert response.status_code == 200, response.get_json()
    data = response.get_json()
    for key in (
        "mes",
        "totais",
        "acumulado",
        "categorias",
        "serie",
        "membros",
        "metas",
        "sugestoes",
        "alertas",
        "recorrentes_pendentes",
        "banco",
    ):
        assert key in data
    assert data["mes"] == MES
    assert data["totais"]["receitas"] == 12000
    assert data["totais"]["despesas"] == 7800
    assert data["totais"]["saldo"] == 4200
    assert data["acumulado"] == {"receitas": 34200, "despesas": 23900}
    assert data["categorias"] == [{"category_id": "c-moradia", "categoria": "Moradia", "total": 3200}]
    assert data["serie"][0] == {"mes": "2026-06-01", "receitas": 11000, "despesas": 8200}
    assert data["membros"][0]["member_id"] == "u-ana"
    assert data["banco"] == {"conexoes_ativas": 1, "pendentes": 2}
    assert data["recorrentes_pendentes"] == []
    assert data["sugestoes"][0]["titulo"] == "Revise as assinaturas"
    assert data["mode"] == "fallback"


def test_dashboard_rejects_invalid_month(client, fake, auth_headers):
    profile_route(fake)
    response = client.get("/api/dashboard?mes=2026-11-05", headers=auth_headers)
    assert response.status_code == 422
    assert response.get_json()["error"]["code"] == "validation_error"
    assert not fake.calls("POST", "/rest/v1/rpc/family_totals")


def test_dashboard_materializes_pending_and_builds_alerts(client, fake, auth_headers):
    _dashboard_routes(fake)
    fake.add("GET", "/rest/v1/recurring_rules", handler=lambda request: [
        {
            "id": "r1",
            "tipo": "despesa",
            "escopo": "familia",
            "valor": 2500,
            "descricao": "Aluguel",
            "category_id": "c-moradia",
            "dia_vencimento": 6,
            "ativo": True,
        }
    ])
    fake.add("POST", "/rest/v1/recurring_occurrences", [])
    fake.add(
        "GET",
        "/rest/v1/recurring_occurrences",
        [
            {
                "id": "occ-1",
                "rule_id": "r1",
                "mes_referencia": MES,
                "status": "pendente",
            }
        ],
    )
    response = client.get(f"/api/dashboard?mes={MES}", headers=auth_headers)
    assert response.status_code == 200
    data = response.get_json()
    assert data["recorrentes_pendentes"][0]["occurrence_id"] == "occ-1"
    assert data["recorrentes_pendentes"][0]["categoria"] == "Moradia"
    assert data["alertas"]
    assert data["alertas"][0]["tipo"] in ("conta_a_vencer", "conta_atrasada")
    # A materialização aconteceu antes da releitura.
    calls = fake.summary()
    assert calls.index("POST /rest/v1/recurring_occurrences") < calls.index(
        "GET /rest/v1/recurring_occurrences"
    )


def test_dashboard_generates_and_persists_fallback_suggestions(client, fake, auth_headers):
    _dashboard_routes(fake, since_recent=False)
    fake.add(
        "POST",
        "/rest/v1/ai_suggestions",
        [{"id": "s-new"}],
    )
    suggestion_reads = {"count": 0}

    def suggestions(request):
        suggestion_reads["count"] += 1
        if suggestion_reads["count"] == 1:
            return []
        return [
            {
                "id": "s-new",
                "tipo": "categoria",
                "titulo": "Olhe Alimentação",
                "o_que": "Reduza o gasto da categoria.",
                "por_que": "Está acima do padrão.",
                "quanto": "R$ 100 por mês",
                "lida": False,
                "criado_em": NOW,
            }
        ]

    fake.add("GET", "/rest/v1/ai_suggestions", handler=suggestions)
    response = client.get(f"/api/dashboard?mes={MES}", headers=auth_headers)
    assert response.status_code == 200, response.get_json()
    data = response.get_json()
    assert data["sugestoes"][0]["id"] == "s-new"
    sent = body_of(fake.last("POST", "/rest/v1/ai_suggestions"))
    assert sent["o_que"]
    assert sent["por_que"]
    assert sent["quanto"]


def test_me_summary_shape(client, fake, auth_headers):
    profile_route(fake)
    fake.add("GET", "/rest/v1/categories", [{"id": "c1", "nome": "Mercado"}])
    personal = [
        {"id": "t1", "tipo": "despesa", "valor": 100, "descricao": "Mercado", "data": "2026-11-02", "category_id": "c1", "origem": "manual"},
        {"id": "t2", "tipo": "receita", "valor": 50, "descricao": "Pix", "data": "2026-11-03", "category_id": "c-salario", "origem": "manual"},
    ]

    def transactions(request):
        if request.url.params.get("tipo") == "eq.despesa":
            return [{"tipo": "despesa", "valor": 300, "category_id": "c1", "data": "2026-10-02"}]
        return personal

    fake.add("GET", "/rest/v1/transactions", handler=transactions)
    fake.add(
        "POST",
        "/rest/v1/rpc/family_member_directory",
        [{"member_id": "u-ana", "nome": "Ana Souza", "papel": "admin"}],
    )
    fake.add("GET", "/rest/v1/goals", [])
    fake.add("GET", "/rest/v1/recurring_rules", [])
    fake.add("GET", "/rest/v1/recurring_occurrences", [])
    fake.add("GET", "/rest/v1/ai_suggestions", [])
    fake.add(
        "GET",
        "/rest/v1/bank_connections",
        [
            {"id": "bc1", "status": "ativa", "ultima_sync_em": "2026-11-01T10:00:00Z"},
            {"id": "bc2", "status": "inativa", "ultima_sync_em": None},
        ],
    )
    fake.add("GET", "/rest/v1/bank_transactions", [{"id": "bt1"}])

    response = client.get(f"/api/me/summary?mes={MES}", headers=auth_headers)
    assert response.status_code == 200, response.get_json()
    data = response.get_json()
    assert data["mes"] == MES
    assert data["totais"]["receitas"] == 50
    assert data["totais"]["despesas"] == 100
    assert data["totais"]["saldo"] == -50
    assert data["categorias"] == [{"category_id": "c1", "categoria": "Mercado", "total": 100}]
    assert data["banco"] == {
        "conexoes": 1,
        "pendentes": 1,
        "ultima_sync": "2026-11-01T10:00:00Z",
    }
    assert data["recorrentes_pendentes"] == []


def test_alerts_shape(client, fake, auth_headers):
    profile_route(fake)
    fake.add("GET", "/rest/v1/categories", [{"id": "c1", "nome": "Mercado"}])
    fake.add("GET", "/rest/v1/transactions", [])
    fake.add("POST", "/rest/v1/rpc/family_member_directory", [])
    fake.add("GET", "/rest/v1/goals", [])
    fake.add("GET", "/rest/v1/recurring_rules", [])
    fake.add("GET", "/rest/v1/recurring_occurrences", [])
    fake.add("GET", "/rest/v1/bank_connections", [])
    fake.add("GET", "/rest/v1/bank_transactions", [])
    response = client.get(f"/api/alerts?mes={MES}", headers=auth_headers)
    assert response.status_code == 200
    assert response.get_json() == {"alertas": []}
