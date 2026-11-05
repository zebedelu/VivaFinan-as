"""NaN/Inf nunca passam por num/money/opt_money (gate 1b, I2)."""

from __future__ import annotations

import math

import pytest

from conftest import profile_route

from app.utils import money, num, opt_money

NAO_FINITOS = ["nan", "inf", "-inf", 1e309, float("nan"), float("inf"), float("-inf")]


@pytest.mark.parametrize("valor", NAO_FINITOS)
def test_utils_rejeitam_nao_finitos(valor):
    assert num(valor) == 0.0
    with pytest.raises(Exception) as exc:
        money(valor)
    assert getattr(exc.value, "status", None) == 422
    with pytest.raises(Exception) as exc:
        opt_money(valor)
    assert getattr(exc.value, "status", None) == 422


@pytest.mark.parametrize("valor", NAO_FINITOS)
def test_transactions_rejeita_nao_finito(client, fake, auth_headers, valor):
    profile_route(fake)
    response = client.post(
        "/api/transactions",
        headers=auth_headers,
        json={
            "tipo": "despesa",
            "escopo": "pessoal",
            "valor": valor,
            "category_id": "c1",
            "data": "2026-11-02",
        },
    )
    assert response.status_code == 422, response.get_json()
    assert not fake.calls("POST", "/rest/v1/transactions")


@pytest.mark.parametrize("valor", NAO_FINITOS)
def test_goals_rejeita_nao_finito(client, fake, auth_headers, valor):
    profile_route(fake)
    response = client.post(
        "/api/goals",
        headers=auth_headers,
        json={"titulo": "Viagem", "valor_alvo": valor},
    )
    assert response.status_code == 422, response.get_json()
    assert not fake.calls("POST", "/rest/v1/goals")


@pytest.mark.parametrize("valor", NAO_FINITOS)
def test_goals_contribuicao_rejeita_nao_finito(client, fake, auth_headers, valor):
    profile_route(fake)
    fake.add("GET", "/rest/v1/goals", [{"id": "g1", "valor_alvo": 1000}])
    response = client.post(
        "/api/goals/g1/contributions",
        headers=auth_headers,
        json={"valor": valor, "data": "2026-11-04"},
    )
    assert response.status_code == 422, response.get_json()
    assert not fake.calls("POST", "/rest/v1/goal_contributions")


@pytest.mark.parametrize("valor", NAO_FINITOS)
def test_recurring_rejeita_nao_finito(client, fake, auth_headers, valor):
    profile_route(fake)
    response = client.post(
        "/api/recurring/rules",
        headers=auth_headers,
        json={
            "tipo": "despesa",
            "escopo": "familia",
            "valor": valor,
            "descricao": "Aluguel",
            "category_id": "c-moradia",
            "dia_vencimento": 6,
        },
    )
    assert response.status_code == 422, response.get_json()
    assert not fake.calls("POST", "/rest/v1/recurring_rules")


@pytest.mark.parametrize("valor", NAO_FINITOS)
def test_recurring_confirm_rejeita_nao_finito(client, fake, auth_headers, valor):
    profile_route(fake)
    response = client.post(
        "/api/recurring/occurrences/occ-1/confirm",
        headers=auth_headers,
        json={"valor": valor},
    )
    assert response.status_code == 422, response.get_json()
    assert not fake.calls("POST", "/rest/v1/rpc/confirm_occurrence")


@pytest.mark.parametrize("valor", NAO_FINITOS)
def test_import_rejeita_nao_finito(client, fake, auth_headers, valor):
    profile_route(fake)
    fake.add(
        "GET",
        "/rest/v1/bank_transactions",
        [
            {
                "id": "bt1",
                "bank_connection_id": "bc1",
                "bank_account_id": "ba1",
                "data": "2026-11-01",
                "valor": 45.9,
                "descricao": "Padaria",
                "tipo": "debito",
                "status": "pendente_importacao",
            }
        ],
    )
    response = client.post(
        "/api/banking/import",
        headers=auth_headers,
        json={
            "bank_transaction_id": "bt1",
            "category_id": "c-alim",
            "escopo": "pessoal",
            "valor": valor,
        },
    )
    assert response.status_code == 422, response.get_json()
    assert not fake.calls("POST", "/rest/v1/transactions")


def test_import_rejeita_valor_nao_finito_do_banco(client, fake, auth_headers):
    profile_route(fake)
    fake.add(
        "GET",
        "/rest/v1/bank_transactions",
        [
            {
                "id": "bt1",
                "bank_connection_id": "bc1",
                "bank_account_id": "ba1",
                "data": "2026-11-01",
                "valor": "NaN",
                "descricao": "Padaria",
                "tipo": "debito",
                "status": "pendente_importacao",
            }
        ],
    )
    response = client.post(
        "/api/banking/import",
        headers=auth_headers,
        json={"bank_transaction_id": "bt1", "category_id": "c-alim", "escopo": "pessoal"},
    )
    assert response.status_code == 422, response.get_json()
    assert not fake.calls("POST", "/rest/v1/transactions")


def test_num_aceita_numero_normal_e_rejeita_bool():
    assert num("210,50") == 210.5
    assert num("R$ 1.234,56") == 1234.56
    assert num(True) == 0.0
    assert math.isfinite(num("10"))
