"""Metas, contribuições e previsão."""

from __future__ import annotations

from datetime import date

from conftest import body_of, profile_route

from app.utils import add_months, current_month


def test_goals_shape_comes_from_schema_and_contributions(client, fake, auth_headers):
    profile_route(fake)
    fake.add(
        "POST",
        "/rest/v1/rpc/family_member_directory",
        [
            {"member_id": "u-ana", "nome": "Ana Souza", "papel": "admin"},
            {"member_id": "u-carlos", "nome": "Carlos Souza", "papel": "membro"},
        ],
    )
    fake.add(
        "GET",
        "/rest/v1/goals",
        [
            {
                "id": "g1",
                "titulo": "Reserva",
                "valor_alvo": 6000,
                "prazo": "2027-06-01",
                "status": "em_andamento",
                "descricao": "Seis meses",
                "member_id": None,
                "criado_por": "u-ana",
                "goal_contributions": [
                    {"id": "k1", "member_id": "u-ana", "valor": 1200, "data": "2026-10-10"}
                ],
            }
        ],
    )
    response = client.get("/api/goals?escopo=familia", headers=auth_headers)
    assert response.status_code == 200, response.get_json()
    goal = response.get_json()["goals"][0]
    assert goal["progresso"] == 20.0
    assert goal["member_nome"] is None
    assert goal["criado_por_nome"] == "Ana Souza"
    assert goal["contribuicoes"] == [
        {
            "id": "k1",
            "member_id": "u-ana",
            "member_nome": "Ana Souza",
            "valor": 1200,
            "data": "2026-10-10",
        }
    ]
    assert fake.last("GET", "/rest/v1/goals").url.params.get("member_id") == "is.null"


def test_create_goal_uses_auth_uid_for_personal(client, fake, auth_headers):
    profile_route(fake)
    fake.add(
        "POST",
        "/rest/v1/rpc/family_member_directory",
        [{"member_id": "u-ana", "nome": "Ana Souza", "papel": "admin"}],
    )
    fake.add(
        "POST",
        "/rest/v1/goals",
        [
            {
                "id": "g1",
                "titulo": "Viagem",
                "valor_alvo": 4000,
                "prazo": None,
                "status": "em_andamento",
                "descricao": None,
                "member_id": "u-ana",
                "criado_por": "u-ana",
            }
        ],
    )
    response = client.post(
        "/api/goals",
        headers=auth_headers,
        json={"titulo": "Viagem", "valor_alvo": 4000, "member_id": "u-ana"},
    )
    assert response.status_code == 201
    sent = body_of(fake.last("POST", "/rest/v1/goals"))
    assert sent["family_id"] == "fam-1"
    assert sent["member_id"] == "u-ana"
    assert sent["criado_por"] == "u-ana"

    blocked = client.post(
        "/api/goals",
        headers=auth_headers,
        json={"titulo": "Alheia", "valor_alvo": 10, "member_id": "u-carlos"},
    )
    assert blocked.status_code == 422


def test_contribution_uses_auth_uid(client, fake, auth_headers):
    profile_route(fake)
    fake.add("GET", "/rest/v1/goals", [{"id": "g1", "valor_alvo": 1000}])
    fake.add(
        "POST",
        "/rest/v1/goal_contributions",
        [{"id": "k1", "goal_id": "g1", "member_id": "u-ana", "valor": 100, "data": "2026-11-04"}],
    )
    response = client.post(
        "/api/goals/g1/contributions",
        headers=auth_headers,
        json={"valor": 100, "data": "2026-11-04"},
    )
    assert response.status_code == 201
    sent = body_of(fake.last("POST", "/rest/v1/goal_contributions"))
    assert sent == {
        "goal_id": "g1",
        "member_id": "u-ana",
        "valor": 100.0,
        "data": "2026-11-04",
    }


def test_family_forecast_uses_rpc_for_next_month(client, fake, auth_headers):
    profile_route(fake)
    rows = [
        {
            "mes": add_months(current_month(), 1 + index).isoformat(),
            "receitas": 12000,
            "despesas": 7600,
            "recorrentes_receitas": 9000,
            "recorrentes_despesas": 5000,
            "variavel_receitas": 3000,
            "variavel_despesas": 2600,
        }
        for index in range(12)
    ]
    fake.add("POST", "/rest/v1/rpc/family_forecast", rows)
    response = client.get("/api/forecast?meses=12&escopo=familia", headers=auth_headers)
    assert response.status_code == 200, response.get_json()
    data = response.get_json()
    assert len(data["meses"]) == 12
    assert data["meses"][0]["saldo"] == 4400
    assert data["anual"] == {"receitas": 144000, "despesas": 91200, "saldo": 52800}
    sent = body_of(fake.last("POST", "/rest/v1/rpc/family_forecast"))
    assert sent == {
        "p_family_id": "fam-1",
        "p_mes_inicio": add_months(current_month(), 1).isoformat(),
    }
    assert "member_id" not in rows[0]
    assert "descricao" not in rows[0]


def test_personal_forecast_is_computed_by_backend(client, fake, auth_headers):
    profile_route(fake)
    fake.add(
        "GET",
        "/rest/v1/recurring_rules",
        [
            {
                "id": "r1",
                "tipo": "despesa",
                "escopo": "pessoal",
                "valor": 100,
                "descricao": "Academia",
                "ativo": True,
                "criado_por": "u-ana",
            }
        ],
    )
    fake.add(
        "GET",
        "/rest/v1/recurring_occurrences",
        [
            {
                "id": "occ-1",
                "rule_id": "r1",
                "mes_referencia": add_months(current_month(), -1).isoformat(),
                "status": "confirmado",
                "valor_confirmado": 120,
                "confirmado_em": "2026-10-05T10:00:00Z",
            }
        ],
    )
    fake.add(
        "GET",
        "/rest/v1/transactions",
        [{"tipo": "despesa", "valor": 300, "category_id": "c1"}],
    )
    fake.add("GET", "/rest/v1/categories", [{"id": "c1", "nome": "Mercado"}])
    response = client.get("/api/forecast?meses=12&escopo=pessoal", headers=auth_headers)
    assert response.status_code == 200, response.get_json()
    data = response.get_json()
    assert len(data["meses"]) == 12
    first = data["meses"][0]
    assert first["recorrentes_despesas"] == 120
    assert first["variavel_despesas"] == 100
    assert first["despesas"] == 220
    assert first["detalhes"]
    assert any(item["descricao"] == "Mercado" for item in first["detalhes"])
    rules_request = fake.last("GET", "/rest/v1/recurring_rules")
    assert rules_request.url.params.get("escopo") == "eq.pessoal"
    tx_request = fake.last("GET", "/rest/v1/transactions")
    assert tx_request.url.params.get("escopo") == "eq.pessoal"
