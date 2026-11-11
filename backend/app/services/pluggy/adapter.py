"""Adaptador Pluggy (real e mock determinístico).

O real autentica com ``clientId``/``clientSecret`` em ``/auth`` e guarda o
``apiKey`` no processo por ~2h, renovando uma vez em 401. ``PLUGGY_API_KEY``
continua aceito e tem precedência (compatibilidade).
"""

from __future__ import annotations

import hashlib
import threading
import time
from datetime import timedelta
from typing import Any, Mapping
from urllib.parse import parse_qs, urlparse

import httpx

from ...errors import ApiError
from ...utils import today_sp

AUTH_TTL_SECONDS = 2 * 60 * 60
MAX_TRANSACTION_PAGES = 50

_AUTH_CACHE: dict[tuple[str, str], tuple[str, float]] = {}
_AUTH_LOCK = threading.Lock()

ACCOUNT_TYPES = {
    "CHECKING_ACCOUNT": "corrente",
    "SAVINGS_ACCOUNT": "poupanca",
    "CREDIT_CARD": "cartao",
}


def account_tipo(account: Mapping[str, Any]) -> str:
    """Tipo local da conta a partir de ``subtype``/``type``; cartão vira ``cartao``."""
    for field in ("subtype", "type"):
        mapped = ACCOUNT_TYPES.get(str(account.get(field) or "").strip().upper())
        if mapped:
            return mapped
    payment = account.get("paymentData")
    method = payment.get("paymentMethod") if isinstance(payment, Mapping) else None
    if "CREDIT" in str(method or "").upper():
        return "cartao"
    return "corrente"


def pluggy_configured(config: Any) -> bool:
    """Há apiKey legado ou par clientId/clientSecret para falar com a Pluggy."""
    key = str(config.get("PLUGGY_API_KEY") or "").strip()
    client_id = str(config.get("PLUGGY_CLIENT_ID") or "").strip()
    secret = str(config.get("PLUGGY_CLIENT_SECRET") or "").strip()
    return bool(key or (client_id and secret))


def _cursor(value: Any) -> str:
    """O ``next`` da Pluggy pode ser um cursor puro ou uma URL com ``after``."""
    text = str(value or "").strip()
    if text.startswith("http"):
        query = parse_qs(urlparse(text).query)
        return str((query.get("after") or [""])[0])
    return text


class PluggyAdapter:
    def __init__(
        self,
        api_key: str = "",
        base_url: str = "https://api.pluggy.ai",
        *,
        client_id: str = "",
        client_secret: str = "",
        transport: httpx.BaseTransport | None = None,
        timeout: float = 10.0,
    ) -> None:
        self.api_key = (api_key or "").strip()
        self.client_id = (client_id or "").strip()
        self.client_secret = (client_secret or "").strip()
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self._client = httpx.Client(transport=transport, timeout=timeout)

    # -- autenticação ----------------------------------------------------
    def _cache_key(self) -> tuple[str, str]:
        return (self.base_url, self.client_id)

    def _forget_key(self) -> None:
        with _AUTH_LOCK:
            _AUTH_CACHE.pop(self._cache_key(), None)

    def _authenticate(self) -> str:
        if not (self.client_id and self.client_secret):
            raise ApiError(
                503,
                "pluggy_not_configured",
                "Pluggy indisponível: configure PLUGGY_CLIENT_ID/PLUGGY_CLIENT_SECRET.",
            )
        response = self._send(
            "POST",
            "/auth",
            payload={"clientId": self.client_id, "clientSecret": self.client_secret},
        )
        if response.status_code >= 400:
            raise ApiError(502, "pluggy_error", "A Pluggy recusou a autenticação.")
        try:
            payload = response.json() if response.content else None
        except ValueError as exc:
            raise ApiError(502, "pluggy_error", "A Pluggy recusou a autenticação.") from exc
        key = str((payload or {}).get("apiKey") or "").strip() if isinstance(payload, Mapping) else ""
        if not key:
            raise ApiError(502, "pluggy_error", "A Pluggy não devolveu a apiKey.")
        with _AUTH_LOCK:
            _AUTH_CACHE[self._cache_key()] = (key, time.monotonic() + AUTH_TTL_SECONDS)
        return key

    def _api_key(self) -> str:
        if self.api_key:
            return self.api_key
        with _AUTH_LOCK:
            cached = _AUTH_CACHE.get(self._cache_key())
            if cached and cached[1] > time.monotonic():
                return cached[0]
        return self._authenticate()

    # -- HTTP ------------------------------------------------------------
    def _send(
        self,
        method: str,
        path: str,
        *,
        params: dict[str, Any] | None = None,
        payload: Any = None,
        headers: dict[str, str] | None = None,
    ) -> httpx.Response:
        try:
            return self._client.request(
                method,
                f"{self.base_url}{path}",
                params=params or {},
                json=payload,
                headers=headers,
            )
        except httpx.HTTPError as exc:
            raise ApiError(503, "upstream_unavailable", "A Pluggy não respondeu.") from exc

    def _request(
        self,
        method: str,
        path: str,
        *,
        params: dict[str, Any] | None = None,
        payload: Any = None,
    ) -> Any:
        key = self._api_key()
        response = self._send(
            method,
            path,
            params=params,
            payload=payload,
            headers={"X-API-KEY": key, "Accept": "application/json"},
        )
        if response.status_code == 401 and not self.api_key:
            # apiKey expirada: renova uma única vez e repete a operação.
            self._forget_key()
            response = self._send(
                method,
                path,
                params=params,
                payload=payload,
                headers={"X-API-KEY": self._api_key(), "Accept": "application/json"},
            )
        if response.status_code >= 400:
            raise ApiError(502, "pluggy_error", "A Pluggy recusou a operação.")
        if not response.content:
            return None
        try:
            return response.json()
        except ValueError:
            return None

    # -- recursos --------------------------------------------------------
    def create_connect_token(self, client_user_id: str) -> str:
        """Token do widget com ``options.clientUserId`` sempre do JWT."""
        payload = self._request(
            "POST",
            "/connect_token",
            payload={"options": {"clientUserId": str(client_user_id)}},
        )
        token = payload.get("accessToken") if isinstance(payload, Mapping) else None
        if not token:
            raise ApiError(502, "pluggy_error", "A Pluggy não devolveu o connect token.")
        return str(token)

    def get_item(self, item_id: str) -> dict[str, Any]:
        """Item da Pluggy: o ``clientUserId`` prova de quem é a conexão."""
        payload = self._request("GET", f"/items/{item_id}")
        return dict(payload) if isinstance(payload, Mapping) else {}

    def list_accounts(self, item_id: str) -> list[dict[str, Any]]:
        payload = self._request("GET", "/accounts", params={"itemId": item_id})
        return list((payload or {}).get("results") or []) if isinstance(payload, dict) else []

    def list_transactions(
        self,
        account_id: str,
        *,
        date_from: str | None = None,
    ) -> list[dict[str, Any]]:
        """Pagina ``/v2/transactions`` enquanto houver ``next``."""
        results: list[dict[str, Any]] = []
        params: dict[str, Any] = {"accountId": account_id}
        if date_from:
            params["dateFrom"] = date_from
        for _ in range(MAX_TRANSACTION_PAGES):
            payload = self._request("GET", "/v2/transactions", params=params)
            if not isinstance(payload, Mapping):
                break
            results.extend(
                dict(item)
                for item in (payload.get("results") or [])
                if isinstance(item, Mapping)
            )
            cursor = _cursor(payload.get("next"))
            if not cursor:
                break
            params = {"accountId": account_id, "after": cursor}
            if date_from:
                params["dateFrom"] = date_from
        return results

    def delete_connection(self, item_id: str) -> None:
        self._request("DELETE", f"/items/{item_id}")


class MockPluggyAdapter:
    """Determinístico: mesmos ids/valores por conexão. Nunca chama a rede."""

    mode = "mock"

    def _seed(self, item_id: str) -> int:
        digest = hashlib.sha256(str(item_id).encode("utf-8")).hexdigest()
        return int(digest[:8], 16)

    def create_connect_token(self, client_user_id: str) -> str:
        return f"mock-connect-{self._seed(client_user_id) % 100000}"

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

    def list_transactions(
        self,
        account_id: str,
        *,
        date_from: str | None = None,
    ) -> list[dict[str, Any]]:
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
    if not pluggy_configured(config):
        return MockPluggyAdapter()
    return PluggyAdapter(
        str(config.get("PLUGGY_API_KEY") or ""),
        str(config.get("PLUGGY_BASE_URL") or "https://api.pluggy.ai"),
        client_id=str(config.get("PLUGGY_CLIENT_ID") or ""),
        client_secret=str(config.get("PLUGGY_CLIENT_SECRET") or ""),
        transport=config.get("HTTP_TRANSPORT"),
        timeout=float(config.get("HTTP_TIMEOUT", 10.0)),
    )
