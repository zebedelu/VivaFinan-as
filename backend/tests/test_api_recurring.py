"""Recorrência: regras, materialização pendente, confirm e ignore."""

from __future__ import annotations

from conftest import body_of, profile_route

from app.utils import days_until, parse_date

MES = "2026-11-01"
RULE = {
    "id": "r1",
    "family_id": "fam-1",
    "criado_por": "u-ana",
    "tipo": "despesa",
    "escopo": "familia",
    "valor": 2500,
    "descricao": "Aluguel",
    "category_id": "c-moradia",
    "dia_vencimento": 6,
    "ativo": True,
    "criado_em": "2026-10-01T12:00:00Z",
}


def test_pending_materializes_then_rereads(client, fake, auth_headers):
    profile_route(fake)
    fake.add("GET", "/rest/v1/recurring_rules", [RULE])
    fake.add("POST", "/rest/v1/recurring_occurrences", [])
    fake.add(
        "GET",
        "/rest/v1/recurring_occurrences",
        [{"id": "occ-1", "rule_id": "r1", "mes_referencia": MES, "status": "pendente"}],
    )
    fake.add("GET", "/rest/v1/categories", [{"id": "c-moradia", "nome": "Moradia"}])

    response = client.get(f"/api/recurring/pending?mes={MES}", headers=auth_headers)
    assert response.status_code == 200, response.get_json()
    items = response.get_json()["items"]
    assert items == [
        {
            "occurrence_id": "occ-1",
            "rule_id": "r1",
            "tipo": "despesa",
            "escopo": "familia",
            "valor": 2500,
            "descricao": "Aluguel",
            "category_id": "c-moradia",
            "categoria": "Moradia",
            "data_vencimento": "2026-11-06",
            "dias_para_vencimento": days_until(parse_date("2026-11-06")),
        }
    ]
    insert = fake.last("POST", "/rest/v1/recurring_occurrences")
    assert insert.url.params.get("on_conflict") == "rule_id,mes_referencia"
    assert "resolution=ignore-duplicates" in insert.headers.get("prefer", "")
    assert body_of(insert) == [
        {"rule_id": "r1", "mes_referencia": MES, "status": "pendente"}
    ]
    calls = fake.summary()
    assert calls.index("POST /rest/v1/recurring_occurrences") < calls.index(
        "GET /rest/v1/recurring_occurrences"
    )


def test_confirm_uses_atomic_rpc(client, fake, auth_headers):
    profile_route(fake)
    fake.add("POST", "/rest/v1/rpc/confirm_occurrence", "tx-1")
    response = client.post(
        "/api/recurring/occurrences/occ-1/confirm",
        headers=auth_headers,
        json={"valor": 2600},
    )
    assert response.status_code == 200
    assert response.get_json() == {"ok": True, "transaction_id": "tx-1"}
    assert body_of(fake.last("POST", "/rest/v1/rpc/confirm_occurrence")) == {
        "p_occurrence_id": "occ-1",
        "p_valor": 2600.0,
    }


def test_confirm_already_decided_is_409(client, fake, auth_headers):
    profile_route(fake)
    fake.add(
        "POST",
        "/rest/v1/rpc/confirm_occurrence",
        {"code": "42501", "message": "occurrence not pending"},
        status=403,
    )
    response = client.post(
        "/api/recurring/occurrences/occ-1/confirm",
        headers=auth_headers,
        json={},
    )
    assert response.status_code == 409
    assert response.get_json()["error"]["code"] == "conflict"


def test_ignore_sets_status_only_when_pending(client, fake, auth_headers):
    profile_route(fake)
    fake.add(
        "PATCH",
        "/rest/v1/recurring_occurrences",
        [{"id": "occ-1", "status": "ignorado"}],
    )
    response = client.post(
        "/api/recurring/occurrences/occ-1/ignore",
        headers=auth_headers,
    )
    assert response.status_code == 200
    request = fake.last("PATCH", "/rest/v1/recurring_occurrences")
    assert body_of(request) == {"status": "ignorado"}
    assert request.url.params.get("status") == "eq.pendente"


def test_rules_crud(client, fake, auth_headers):
    profile_route(fake)
    fake.add("GET", "/rest/v1/categories", [{"id": "c-moradia", "nome": "Moradia"}])
    fake.add("GET", "/rest/v1/recurring_rules", [RULE])
    fake.add("POST", "/rest/v1/recurring_rules", [RULE])
    fake.add("PATCH", "/rest/v1/recurring_rules", [{**RULE, "ativo": False}])

    listed = client.get("/api/recurring/rules", headers=auth_headers)
    assert listed.status_code == 200
    assert listed.get_json()["rules"][0]["categoria"] == "Moradia"

    created = client.post(
        "/api/recurring/rules",
        headers=auth_headers,
        json={
            "tipo": "despesa",
            "escopo": "familia",
            "valor": 2500,
            "descricao": "Aluguel",
            "category_id": "c-moradia",
            "dia_vencimento": 6,
            "ativo": True,
        },
    )
    assert created.status_code == 201
    sent = body_of(fake.last("POST", "/rest/v1/recurring_rules"))
    assert sent["family_id"] == "fam-1"
    assert sent["criado_por"] == "u-ana"

    updated = client.patch(
        "/api/recurring/rules/r1",
        headers=auth_headers,
        json={"ativo": False},
    )
    assert updated.status_code == 200
    assert updated.get_json()["rule"]["ativo"] is False
    assert body_of(fake.last("PATCH", "/rest/v1/recurring_rules")) == {"ativo": False}
