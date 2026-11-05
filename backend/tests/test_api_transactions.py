"""Lançamentos: lista, criação manual, patch e delete."""

from __future__ import annotations

import httpx

from conftest import ANON_KEY, PROFILE, SERVICE_KEY, USER_JWT, body_of, profile_route

ROW = {
    "id": "t1",
    "tipo": "despesa",
    "escopo": "familia",
    "valor": 210.5,
    "descricao": "Mercado",
    "category_id": "c1",
    "data": "2026-11-02",
    "pago_por": "u-carlos",
    "recurring_rule_id": None,
    "mes_referencia": None,
    "origem": "manual",
    "bank_transaction_id": None,
    "criado_por": "u-ana",
    "criado_em": "2026-11-02T12:00:00Z",
}


def _enrichment_routes(fake):
    fake.add("GET", "/rest/v1/categories", [{"id": "c1", "nome": "Mercado"}])
    fake.add(
        "POST",
        "/rest/v1/rpc/family_member_directory",
        [
            {"member_id": "u-ana", "nome": "Ana Souza", "papel": "admin"},
            {"member_id": "u-carlos", "nome": "Carlos Souza", "papel": "membro"},
        ],
    )


def test_transactions_list_shape(client, fake, auth_headers):
    profile_route(fake)

    def handler(request):
        if request.url.params.get("select") == "id":
            return [{"id": "t1"}, {"id": "t2"}]
        return [ROW]

    fake.add("GET", "/rest/v1/transactions", handler=handler)
    _enrichment_routes(fake)

    response = client.get(
        "/api/transactions?mes=2026-11-01&tipo=despesa&limit=50&offset=0",
        headers=auth_headers,
    )
    assert response.status_code == 200, response.get_json()
    data = response.get_json()
    assert data["total"] == 2
    item = data["items"][0]
    assert item["categoria"] == "Mercado"
    assert item["pago_por_nome"] == "Carlos Souza"
    assert item["origem"] == "manual"
    assert item["bank_transaction_id"] is None

    first = fake.calls("GET", "/rest/v1/transactions")[0]
    assert first.url.params.get("tipo") == "eq.despesa"
    assert "data.gte.2026-11-01" in first.url.params.get("and", "")


def test_create_transaction_derives_family_and_member(client, fake, auth_headers):
    profile_route(fake)
    fake.add("POST", "/rest/v1/transactions", [ROW])
    _enrichment_routes(fake)

    response = client.post(
        "/api/transactions",
        headers=auth_headers,
        json={
            "tipo": "despesa",
            "escopo": "familia",
            "valor": "210,50",
            "descricao": "Mercado",
            "category_id": "c1",
            "data": "2026-11-02",
            "pago_por": "u-carlos",
        },
    )
    assert response.status_code == 201, response.get_json()
    assert response.get_json()["transaction"]["id"] == "t1"
    sent = body_of(fake.last("POST", "/rest/v1/transactions"))
    assert sent["family_id"] == "fam-1"
    assert sent["member_id"] == "u-ana"
    assert sent["criado_por"] == "u-ana"
    assert sent["origem"] == "manual"
    assert sent["valor"] == 210.5
    for request in fake.requests:
        assert request.headers.get("apikey") == ANON_KEY
        assert request.headers.get("authorization") == f"Bearer {USER_JWT}"
        assert SERVICE_KEY not in " ".join(request.headers.values())


def test_create_transaction_rejects_import_fields(client, fake, auth_headers):
    profile_route(fake)
    response = client.post(
        "/api/transactions",
        headers=auth_headers,
        json={
            "tipo": "despesa",
            "escopo": "pessoal",
            "valor": 10,
            "category_id": "c1",
            "data": "2026-11-02",
            "recurring_rule_id": "r1",
        },
    )
    assert response.status_code == 422
    assert not fake.calls("POST", "/rest/v1/transactions")


def test_create_transaction_rejects_client_family_id(client, fake, auth_headers):
    profile_route(fake)
    response = client.post(
        "/api/transactions",
        headers=auth_headers,
        json={
            "tipo": "despesa",
            "escopo": "pessoal",
            "valor": 10,
            "category_id": "c1",
            "data": "2026-11-02",
            "family_id": "outra-familia",
        },
    )
    assert response.status_code == 422


def test_patch_transaction_allows_only_editable_fields(client, fake, auth_headers):
    profile_route(fake)
    fake.add("PATCH", "/rest/v1/transactions", [{**ROW, "valor": 300}])
    _enrichment_routes(fake)

    blocked = client.patch(
        "/api/transactions/t1",
        headers=auth_headers,
        json={"escopo": "pessoal"},
    )
    assert blocked.status_code == 422
    assert not fake.calls("PATCH", "/rest/v1/transactions")

    response = client.patch(
        "/api/transactions/t1",
        headers=auth_headers,
        json={"valor": 300, "descricao": "Mercado grande"},
    )
    assert response.status_code == 200
    sent = body_of(fake.last("PATCH", "/rest/v1/transactions"))
    assert sent == {"valor": 300, "descricao": "Mercado grande"}


def test_delete_transaction_zero_rows_is_404(client, fake, auth_headers):
    profile_route(fake)
    fake.add("DELETE", "/rest/v1/transactions", [])
    response = client.delete("/api/transactions/t1", headers=auth_headers)
    assert response.status_code == 404
    assert response.get_json()["error"]["code"] == "not_found"


def test_transactions_total_uses_content_range_header(client, fake, auth_headers):
    profile_route(fake)

    def handler(request):
        return httpx.Response(200, json=[ROW], headers={"Content-Range": "0-1/1500"})

    fake.add("GET", "/rest/v1/transactions", handler=handler)
    _enrichment_routes(fake)

    response = client.get("/api/transactions?limit=2&offset=0", headers=auth_headers)
    assert response.status_code == 200, response.get_json()
    assert response.get_json()["total"] == 1500
    calls = fake.calls("GET", "/rest/v1/transactions")
    assert len(calls) == 1
    assert "count=exact" in calls[0].headers.get("prefer", "")


def test_transactions_total_falls_back_when_header_is_missing(client, fake, auth_headers):
    profile_route(fake)

    def handler(request):
        if request.url.params.get("select") == "id":
            return [{"id": "t1"}, {"id": "t2"}, {"id": "t3"}]
        return [ROW]

    fake.add("GET", "/rest/v1/transactions", handler=handler)
    _enrichment_routes(fake)

    response = client.get("/api/transactions?limit=1", headers=auth_headers)
    assert response.status_code == 200
    assert response.get_json()["total"] == 3
    assert len(fake.calls("GET", "/rest/v1/transactions")) == 2
