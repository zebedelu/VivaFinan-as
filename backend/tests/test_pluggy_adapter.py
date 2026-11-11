"""Adaptador Pluggy: auth com cache, connect token, paginação e DELETE do item."""

from __future__ import annotations

import json

import httpx
import pytest

from app.errors import ApiError
from app.services.pluggy import build_adapter
from app.services.pluggy.adapter import (
    MockPluggyAdapter,
    PluggyAdapter,
    account_tipo,
)


def _adapter(handler, base_url: str = "https://pluggy.test", **kwargs) -> PluggyAdapter:
    return PluggyAdapter(
        base_url=base_url,
        transport=httpx.MockTransport(handler),
        **kwargs,
    )


def _body(request: httpx.Request) -> dict:
    return json.loads(request.content.decode("utf-8")) if request.content else {}


def test_auth_key_is_cached_between_uses():
    calls: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(request)
        if request.url.path == "/auth":
            assert _body(request) == {"clientId": "cid", "clientSecret": "secret"}
            assert "X-API-KEY" not in request.headers
            return httpx.Response(200, json={"apiKey": "key-1"})
        assert request.headers["X-API-KEY"] == "key-1"
        return httpx.Response(200, json={"id": "item-1"})

    adapter = _adapter(
        handler,
        base_url="https://cache.pluggy.test",
        client_id="cid",
        client_secret="secret",
    )
    assert adapter.get_item("item-1") == {"id": "item-1"}
    assert adapter.get_item("item-2") == {"id": "item-1"}
    assert [call.url.path for call in calls].count("/auth") == 1


def test_401_renews_the_key_once():
    keys = iter(["key-1", "key-2"])
    seen: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path == "/auth":
            return httpx.Response(200, json={"apiKey": next(keys)})
        key = request.headers["X-API-KEY"]
        seen.append(key)
        if key == "key-1":
            return httpx.Response(401, json={"message": "expired"})
        return httpx.Response(200, json={"id": "item-1"})

    adapter = _adapter(
        handler,
        base_url="https://refresh.pluggy.test",
        client_id="cid",
        client_secret="secret",
    )
    assert adapter.get_item("item-1") == {"id": "item-1"}
    assert seen == ["key-1", "key-2"]


def test_connect_token_sends_options_client_user_id():
    calls: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(request)
        assert request.method == "POST"
        assert request.url.path == "/connect_token"
        assert request.headers["X-API-KEY"] == "legacy-key"
        return httpx.Response(200, json={"accessToken": "tok-1"})

    adapter = _adapter(handler, api_key="legacy-key")
    assert adapter.create_connect_token("u-ana") == "tok-1"
    assert _body(calls[0]) == {"options": {"clientUserId": "u-ana"}}
    assert [call.url.path for call in calls] == ["/connect_token"]


def test_transactions_paginate_with_after_and_date_from():
    pages = [
        {"results": [{"id": "t1", "amount": -10}], "next": "cursor-2"},
        {"results": [{"id": "t2", "amount": 5}], "next": None},
    ]
    seen: list[dict] = []

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/v2/transactions"
        seen.append(dict(request.url.params))
        return httpx.Response(200, json=pages[len(seen) - 1])

    adapter = _adapter(handler, api_key="legacy-key")
    rows = adapter.list_transactions("acc-1", date_from="2026-08-01")
    assert [row["id"] for row in rows] == ["t1", "t2"]
    assert seen[0] == {"accountId": "acc-1", "dateFrom": "2026-08-01"}
    assert seen[1] == {
        "accountId": "acc-1",
        "after": "cursor-2",
        "dateFrom": "2026-08-01",
    }


def test_transactions_accept_next_as_full_url():
    pages = iter(
        [
            {
                "results": [{"id": "t1"}],
                "next": "https://api.pluggy.ai/v2/transactions?accountId=acc-1&after=cursor-9",
            },
            {"results": [{"id": "t2"}], "next": None},
        ]
    )
    seen: list[dict] = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(dict(request.url.params))
        return httpx.Response(200, json=next(pages))

    adapter = _adapter(handler, api_key="legacy-key")
    assert [row["id"] for row in adapter.list_transactions("acc-1")] == ["t1", "t2"]
    assert seen[1] == {"accountId": "acc-1", "after": "cursor-9"}


def test_credit_card_subtype_maps_to_cartao():
    assert account_tipo({"type": "CREDIT_CARD", "subtype": "CREDIT_CARD"}) == "cartao"
    assert account_tipo({"subtype": "CREDIT_CARD"}) == "cartao"
    assert account_tipo({"paymentData": {"paymentMethod": "CREDIT_CARD"}}) == "cartao"
    assert account_tipo({"type": "CHECKING_ACCOUNT"}) == "corrente"
    assert account_tipo({"type": "SAVINGS_ACCOUNT"}) == "poupanca"
    assert account_tipo({}) == "corrente"


def test_delete_connection_calls_items_endpoint():
    seen: list[tuple[str, str]] = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append((request.method, request.url.path))
        return httpx.Response(204)

    adapter = _adapter(handler, api_key="legacy-key")
    adapter.delete_connection("item-1")
    assert seen == [("DELETE", "/items/item-1")]


def test_adapter_without_any_credential_is_503():
    adapter = _adapter(lambda request: httpx.Response(200, json={}))
    with pytest.raises(ApiError) as excinfo:
        adapter.get_item("item-1")
    assert excinfo.value.status == 503
    assert excinfo.value.code == "pluggy_not_configured"


def test_build_adapter_uses_mock_only_without_credentials():
    assert isinstance(build_adapter({}), MockPluggyAdapter)
    assert isinstance(
        build_adapter({"PLUGGY_CLIENT_ID": "cid", "PLUGGY_CLIENT_SECRET": "secret"}),
        PluggyAdapter,
    )
    assert isinstance(build_adapter({"PLUGGY_API_KEY": "key"}), PluggyAdapter)
