"""Importação, reconciliação e ignore/unignore de transações bancárias."""

from __future__ import annotations

import httpx

from conftest import body_of, profile_route

BANK_TX = {
    "id": "bt1",
    "bank_connection_id": "bc1",
    "bank_account_id": "ba1",
    "pluggy_transaction_id": "plug-1",
    "data": "2026-11-01",
    "valor": 45.9,
    "descricao": "Padaria",
    "tipo": "debito",
    "categoria_bancaria": "Alimentação",
    "status": "pendente_importacao",
    "transaction_id": None,
    "is_demo_sync": True,
}


def test_import_creates_pluggy_transaction_with_auth_uid(client, fake, auth_headers):
    profile_route(fake)
    fake.add("GET", "/rest/v1/bank_transactions", [BANK_TX])
    fake.add(
        "POST",
        "/rest/v1/transactions",
        [
            {
                "id": "t-new",
                "tipo": "despesa",
                "escopo": "pessoal",
                "valor": 45.9,
                "origem": "pluggy",
                "bank_transaction_id": "bt1",
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
            "valor": 45.9,
            "data": "2026-11-01",
            "descricao": "Padaria",
        },
    )
    assert response.status_code == 201, response.get_json()
    sent = body_of(fake.last("POST", "/rest/v1/transactions"))
    assert sent["origem"] == "pluggy"
    assert sent["bank_transaction_id"] == "bt1"
    assert sent["member_id"] == "u-ana"
    assert sent["criado_por"] == "u-ana"
    assert sent["family_id"] == "fam-1"
    assert sent["tipo"] == "despesa"
    assert sent["valor"] == 45.9


def test_import_rejects_transaction_already_decided(client, fake, auth_headers):
    profile_route(fake)
    fake.add("GET", "/rest/v1/bank_transactions", [{**BANK_TX, "status": "importada"}])
    response = client.post(
        "/api/banking/import",
        headers=auth_headers,
        json={"bank_transaction_id": "bt1", "category_id": "c1", "escopo": "pessoal"},
    )
    assert response.status_code == 409
    assert not fake.calls("POST", "/rest/v1/transactions")


def test_reconcile_links_existing_transaction(client, fake, auth_headers):
    profile_route(fake)
    fake.add("GET", "/rest/v1/bank_transactions", [BANK_TX])
    fake.add(
        "GET",
        "/rest/v1/transactions",
        [{"id": "t1", "valor": 45.9, "data": "2026-11-01", "bank_transaction_id": None}],
    )
    fake.add(
        "PATCH",
        "/rest/v1/transactions",
        [{"id": "t1", "bank_transaction_id": "bt1", "valor": 45.9}],
    )
    response = client.post(
        "/api/banking/reconcile",
        headers=auth_headers,
        json={"bank_transaction_id": "bt1", "transaction_id": "t1"},
    )
    assert response.status_code == 200, response.get_json()
    request = fake.last("PATCH", "/rest/v1/transactions")
    assert body_of(request) == {"bank_transaction_id": "bt1"}
    assert request.url.params.get("id") == "eq.t1"


def test_reconcile_candidates_use_tolerance_and_enrich_category(client, fake, auth_headers):
    profile_route(fake)
    fake.add("GET", "/rest/v1/bank_transactions", [BANK_TX])
    fake.add(
        "GET",
        "/rest/v1/transactions",
        [
            {
                "id": "t1",
                "valor": 45.9,
                "data": "2026-11-01",
                "descricao": "Padaria",
                "category_id": "c-alim",
            }
        ],
    )
    fake.add("GET", "/rest/v1/categories", [{"id": "c-alim", "nome": "Alimentação"}])
    response = client.get(
        "/api/banking/reconcile-candidates?bank_transaction_id=bt1",
        headers=auth_headers,
    )
    assert response.status_code == 200
    candidate = response.get_json()["candidates"][0]
    assert candidate == {
        "transaction_id": "t1",
        "valor": 45.9,
        "data": "2026-11-01",
        "descricao": "Padaria",
        "categoria": "Alimentação",
        "categoria_id": "c-alim",
    }
    request = fake.calls("GET", "/rest/v1/transactions")[-1]
    assert "valor.gte.45.89" in request.url.params.get("and", "")
    assert "data.lte.2026-11-02" in request.url.params.get("and", "")


def test_ignore_and_unignore_only_change_status(client, fake, auth_headers):
    profile_route(fake)
    fake.add("GET", "/rest/v1/bank_transactions", [BANK_TX])
    fake.add(
        "PATCH",
        "/rest/v1/bank_transactions",
        [{**BANK_TX, "status": "ignorada"}],
    )
    response = client.post("/api/banking/ignore", headers=auth_headers, json={"bank_transaction_id": "bt1"})
    assert response.status_code == 200
    request = fake.last("PATCH", "/rest/v1/bank_transactions")
    assert body_of(request) == {"status": "ignorada"}
    assert request.url.params.get("status") == "eq.pendente_importacao"

    fake.add("GET", "/rest/v1/bank_transactions", [{**BANK_TX, "status": "ignorada"}])
    fake.add(
        "PATCH",
        "/rest/v1/bank_transactions",
        [{**BANK_TX, "status": "pendente_importacao"}],
    )
    response = client.post(
        "/api/banking/unignore",
        headers=auth_headers,
        json={"bank_transaction_id": "bt1"},
    )
    assert response.status_code == 200
    assert body_of(fake.last("PATCH", "/rest/v1/bank_transactions")) == {
        "status": "pendente_importacao"
    }


def test_ignore_imported_transaction_is_409(client, fake, auth_headers):
    profile_route(fake)
    fake.add("GET", "/rest/v1/bank_transactions", [{**BANK_TX, "status": "importada"}])
    response = client.post("/api/banking/ignore", headers=auth_headers, json={"bank_transaction_id": "bt1"})
    assert response.status_code == 409
    assert not fake.calls("PATCH", "/rest/v1/bank_transactions")


CONNECTION_ROW = {
    "id": "bc1",
    "pluggy_connection_id": "conn-1",
    "institution_name": "Banco Demo",
    "status": "ativa",
    "is_demo_sync": False,
}


class FakePluggy:
    def __init__(self, item=None, error=None):
        self.item = item or {}
        self.error = error
        self.items: list[str] = []

    def get_item(self, item_id):
        self.items.append(item_id)
        if self.error is not None:
            raise self.error
        return self.item


def test_create_connection_without_pluggy_key_is_503(client, fake, auth_headers):
    profile_route(fake)
    response = client.post(
        "/api/banking/connections",
        headers=auth_headers,
        json={"pluggy_connection_id": "conn-1", "institution_name": "Banco Demo"},
    )
    assert response.status_code == 503
    assert response.get_json()["error"]["code"] == "unavailable"
    assert not fake.calls("POST", "/rest/v1/bank_connections")


def test_create_connection_derives_member_and_family(make_client, fake, auth_headers, monkeypatch):
    client = make_client(PLUGGY_API_KEY="pluggy-key")
    adapter = FakePluggy({"id": "conn-1", "clientUserId": "u-ana"})
    monkeypatch.setattr("app.blueprints.banking.build_adapter", lambda config: adapter)
    profile_route(fake)
    fake.add("POST", "/rest/v1/bank_connections", [CONNECTION_ROW])

    response = client.post(
        "/api/banking/connections",
        headers=auth_headers,
        json={
            "pluggy_connection_id": "conn-1",
            "institution_name": "Banco Demo",
            "account_type": "corrente",
        },
    )
    assert response.status_code == 201, response.get_json()
    assert adapter.items == ["conn-1"]
    sent = body_of(fake.last("POST", "/rest/v1/bank_connections"))
    assert sent["family_id"] == "fam-1"
    assert sent["member_id"] == "u-ana"
    assert sent["is_demo_sync"] is False

    blocked = client.post(
        "/api/banking/connections",
        headers=auth_headers,
        json={
            "pluggy_connection_id": "conn-2",
            "institution_name": "Outro",
            "member_id": "u-carlos",
        },
    )
    assert blocked.status_code == 422


def test_create_connection_rejects_item_from_another_user(make_client, fake, auth_headers, monkeypatch):
    client = make_client(PLUGGY_API_KEY="pluggy-key")
    adapter = FakePluggy({"id": "conn-1", "clientUserId": "u-carlos"})
    monkeypatch.setattr("app.blueprints.banking.build_adapter", lambda config: adapter)
    profile_route(fake)

    response = client.post(
        "/api/banking/connections",
        headers=auth_headers,
        json={"pluggy_connection_id": "conn-1", "institution_name": "Banco Demo"},
    )
    assert response.status_code == 403
    assert response.get_json()["error"]["code"] == "forbidden"
    assert not fake.calls("POST", "/rest/v1/bank_connections")


def test_create_connection_item_without_owner_is_403(make_client, fake, auth_headers, monkeypatch):
    client = make_client(PLUGGY_API_KEY="pluggy-key")
    monkeypatch.setattr(
        "app.blueprints.banking.build_adapter",
        lambda config: FakePluggy({"id": "conn-1"}),
    )
    profile_route(fake)

    response = client.post(
        "/api/banking/connections",
        headers=auth_headers,
        json={"pluggy_connection_id": "conn-1", "institution_name": "Banco Demo"},
    )
    assert response.status_code == 403
    assert not fake.calls("POST", "/rest/v1/bank_connections")


def test_create_connection_propagates_pluggy_failure(make_client, fake, auth_headers, monkeypatch):
    from app.errors import ApiError

    client = make_client(PLUGGY_API_KEY="pluggy-key")
    monkeypatch.setattr(
        "app.blueprints.banking.build_adapter",
        lambda config: FakePluggy(error=ApiError(502, "pluggy_error", "A Pluggy recusou a operação.")),
    )
    profile_route(fake)

    response = client.post(
        "/api/banking/connections",
        headers=auth_headers,
        json={"pluggy_connection_id": "conn-1", "institution_name": "Banco Demo"},
    )
    assert response.status_code == 502
    assert not fake.calls("POST", "/rest/v1/bank_connections")


def test_bank_accounts_and_transactions_lists(client, fake, auth_headers):
    profile_route(fake)
    fake.add(
        "GET",
        "/rest/v1/bank_accounts",
        [
            {
                "id": "ba1",
                "connection_id": "bc1",
                "pluggy_account_id": "acc-1",
                "nome": "Conta",
                "tipo": "corrente",
                "currency": "BRL",
                "balance": 3200.5,
                "updated_at": "2026-11-01T10:00:00Z",
            }
        ],
    )

    def bank_tx(request):
        if request.url.params.get("select") == "id":
            return [{"id": "bt1"}]
        return [BANK_TX]

    fake.add("GET", "/rest/v1/bank_transactions", handler=bank_tx)
    accounts = client.get("/api/banking/accounts?connection_id=bc1", headers=auth_headers)
    assert accounts.status_code == 200
    assert accounts.get_json()["accounts"][0]["balance"] == 3200.5

    transactions = client.get(
        "/api/banking/transactions?connection_id=bc1&status=pendente_importacao&mes=2026-11-01",
        headers=auth_headers,
    )
    assert transactions.status_code == 200
    assert transactions.get_json()["total"] == 1
    assert transactions.get_json()["items"][0]["id"] == "bt1"


def test_bank_transactions_total_uses_content_range_header(client, fake, auth_headers):
    profile_route(fake)

    def handler(request):
        return httpx.Response(200, json=[BANK_TX], headers={"Content-Range": "0-1/1500"})

    fake.add("GET", "/rest/v1/bank_transactions", handler=handler)
    response = client.get("/api/banking/transactions?limit=2", headers=auth_headers)
    assert response.status_code == 200, response.get_json()
    assert response.get_json()["total"] == 1500
    calls = fake.calls("GET", "/rest/v1/bank_transactions")
    assert len(calls) == 1
    assert "count=exact" in calls[0].headers.get("prefer", "")


def test_sync_demo_is_noop_without_keys(client, fake, auth_headers):
    profile_route(fake)
    fake.add(
        "GET",
        "/rest/v1/bank_connections",
        [{"id": "bc1", "is_demo_sync": True, "pluggy_connection_id": "conn-1"}],
    )
    response = client.post("/api/banking/sync", headers=auth_headers, json={"connection_id": "bc1"})
    assert response.status_code == 200
    assert response.get_json()["demo"] is True
    assert not fake.calls("POST", "/rest/v1/bank_transactions")


def test_sync_real_without_pluggy_key_is_503(client, fake, auth_headers):
    profile_route(fake)
    fake.add(
        "GET",
        "/rest/v1/bank_connections",
        [{"id": "bc1", "is_demo_sync": False, "pluggy_connection_id": "conn-1"}],
    )
    response = client.post("/api/banking/sync", headers=auth_headers, json={"connection_id": "bc1"})
    assert response.status_code == 503
    assert response.get_json()["error"]["code"] == "unavailable"


class FakeConnectPluggy:
    def __init__(self):
        self.users: list[str] = []

    def create_connect_token(self, user_id):
        self.users.append(user_id)
        return "tok-1"


def test_connect_token_without_credentials_is_503(client, fake, auth_headers):
    profile_route(fake)
    response = client.post("/api/banking/connect_token", headers=auth_headers, json={})
    assert response.status_code == 503
    assert response.get_json()["error"]["code"] == "pluggy_not_configured"


def test_connect_token_uses_profile_user_not_body(make_client, fake, auth_headers, monkeypatch):
    client = make_client(PLUGGY_CLIENT_ID="cid", PLUGGY_CLIENT_SECRET="secret")
    adapter = FakeConnectPluggy()
    monkeypatch.setattr("app.blueprints.banking.build_adapter", lambda config: adapter)
    profile_route(fake)

    response = client.post("/api/banking/connect_token", headers=auth_headers, json={})
    assert response.status_code == 200, response.get_json()
    assert response.get_json() == {"accessToken": "tok-1", "clientUserId": "u-ana"}
    assert adapter.users == ["u-ana"]

    blocked = client.post(
        "/api/banking/connect_token",
        headers=auth_headers,
        json={"clientUserId": "u-carlos"},
    )
    assert blocked.status_code == 422
    assert adapter.users == ["u-ana"]


def test_sync_v2_uses_date_window_and_maps_cartao(make_client, fake, auth_headers, monkeypatch):
    client = make_client(
        PLUGGY_CLIENT_ID="cid",
        PLUGGY_CLIENT_SECRET="secret",
        SUPABASE_SERVICE_ROLE_KEY="service-key",
    )

    class FakeSyncPluggy:
        def __init__(self):
            self.calls: list[tuple[str, str | None]] = []

        def list_accounts(self, item_id):
            return [
                {
                    "id": "acc-1",
                    "name": "Cartão",
                    "type": "CREDIT_CARD",
                    "subtype": "CREDIT_CARD",
                    "balance": -120.0,
                }
            ]

        def list_transactions(self, account_id, *, date_from=None):
            self.calls.append((account_id, date_from))
            return [
                {
                    "id": "tx-1",
                    "date": "2026-11-01",
                    "amount": -45.9,
                    "description": "Padaria",
                }
            ]

    adapter = FakeSyncPluggy()
    monkeypatch.setattr("app.services.pluggy.sync.build_adapter", lambda config: adapter)
    profile_route(fake)
    fake.add(
        "GET",
        "/rest/v1/bank_connections",
        [
            {
                "id": "bc1",
                "pluggy_connection_id": "item-1",
                "is_demo_sync": False,
                "ultima_sync_em": "2026-11-04T12:00:00+00:00",
            }
        ],
    )
    fake.add("POST", "/rest/v1/bank_accounts", [{"id": "ba1", "pluggy_account_id": "acc-1"}])
    fake.add("POST", "/rest/v1/bank_transactions", [{"id": "bt1"}])
    fake.add("PATCH", "/rest/v1/bank_connections", [{"id": "bc1"}])

    response = client.post("/api/banking/sync", headers=auth_headers, json={"connection_id": "bc1"})
    assert response.status_code == 200, response.get_json()
    assert response.get_json()["accounts"] == 1
    assert adapter.calls == [("acc-1", "2026-10-28")]
    sent_accounts = body_of(fake.last("POST", "/rest/v1/bank_accounts"))
    assert sent_accounts[0]["tipo"] == "cartao"
    sent_transactions = body_of(fake.last("POST", "/rest/v1/bank_transactions"))
    assert sent_transactions[0]["pluggy_transaction_id"] == "tx-1"
    assert sent_transactions[0]["tipo"] == "debito"
