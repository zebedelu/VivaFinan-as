"""Adaptador Pluggy (real e mock determinístico)."""

from __future__ import annotations

import hashlib
from datetime import timedelta
from typing import Any, Mapping

import httpx

from ...errors import ApiError
from ...utils import today_sp


class PluggyAdapter:
    def __init__(
        self,
        api_key: str,
        base_url: str = "https://api.pluggy.ai",
        *,
        transport: httpx.BaseTransport | None = None,
        timeout: float = 10.0,
    ) -> None:
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self._client = httpx.Client(transport=transport, timeout=timeout)

    def _request(self, method: str, path: str, params: dict[str, Any] | None = None) -> Any:
        if not self.api_key:
            raise ApiError(503, "unavailable", "Pluggy indisponível: configure PLUGGY_API_KEY.")
        try:
            response = self._client.request(
                method,
                f"{self.base_url}{path}",
                params=params or {},
                headers={"X-API-KEY": self.api_key, "Accept": "application/json"},
            )
        except httpx.HTTPError as exc:
            raise ApiError(503, "upstream_unavailable", "A Pluggy não respondeu.") from exc
        if response.status_code >= 400:
            raise ApiError(502, "pluggy_error", "A Pluggy recusou a operação.")
        if not response.content:
            return None
        try:
            return response.json()
        except ValueError:
            return None

    def get_item(self, item_id: str) -> dict[str, Any]:
        """Item da Pluggy: o ``clientUserId`` prova de quem é a conexão."""
        payload = self._request("GET", f"/items/{item_id}")
        return dict(payload) if isinstance(payload, Mapping) else {}

    def list_accounts(self, item_id: str) -> list[dict[str, Any]]:
        payload = self._request("GET", "/accounts", {"itemId": item_id})
        return list((payload or {}).get("results") or []) if isinstance(payload, dict) else []

    def list_transactions(self, account_id: str) -> list[dict[str, Any]]:
        payload = self._request("GET", "/transactions", {"accountId": account_id})
        return list((payload or {}).get("results") or []) if isinstance(payload, dict) else []

    def delete_connection(self, item_id: str) -> None:
        self._request("DELETE", f"/connections/{item_id}")


class MockPluggyAdapter:
    """Determinístico: mesmos ids/valores por conexão. Nunca chama a rede."""

    mode = "mock"

    def _seed(self, item_id: str) -> int:
        digest = hashlib.sha256(str(item_id).encode("utf-8")).hexdigest()
        return int(digest[:8], 16)

    def list_accounts(self, item_id: str) -> list[dict[str, Any]]:
        seed = self._seed(item_id)
        return [
            {
                "id": f"mock-account-{seed % 100000}",
                "name": "Conta demo",
                "type": "CHECKING_ACCOUNT",
                "balance": 3200.5,
            }
        ]

    def list_transactions(self, account_id: str) -> list[dict[str, Any]]:
        seed = self._seed(account_id)
        today = today_sp()
        return [
            {
                "id": f"mock-tx-{seed % 100000}-{offset}",
                "date": (today - timedelta(days=offset)).isoformat(),
                "amount": -round(20 + (seed % 50) + offset, 2),
                "description": ["Padaria", "Farmácia", "Uber"][offset],
                "type": "DEBIT",
                "category": ["Alimentação", "Saúde", "Transporte"][offset],
            }
            for offset in range(3)
        ]

    def delete_connection(self, item_id: str) -> None:
        return None


def build_adapter(config: Any) -> Any:
    key = (config.get("PLUGGY_API_KEY") or "").strip()
    if not key:
        return MockPluggyAdapter()
    return PluggyAdapter(
        key,
        config.get("PLUGGY_BASE_URL") or "https://api.pluggy.ai",
        transport=config.get("HTTP_TRANSPORT"),
        timeout=float(config.get("HTTP_TIMEOUT", 10.0)),
    )
