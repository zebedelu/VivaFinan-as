"""Fixtures de teste: app Flask + Supabase falso via httpx.MockTransport."""

from __future__ import annotations

import json
from typing import Any, Callable

import httpx
import pytest

from app import create_app

USER_ID = "u-ana"
FAMILY_ID = "fam-1"
PROFILE = {
    "id": USER_ID,
    "family_id": FAMILY_ID,
    "nome": "Ana Souza",
    "papel": "admin",
    "status": "ativo",
    "tema": "claro",
    "criado_em": "2026-01-01T12:00:00Z",
}
FAMILY = {"id": FAMILY_ID, "nome": "Família Souza", "is_demo": False}
USER = {"id": USER_ID, "email": "ana@demo.vivafinancas.app"}
ANON_KEY = "anon-key"
USER_JWT = "user-token"
SERVICE_KEY = "service-role-key"


class FakeSupabase:
    """Roteador HTTP determinístico; registra cada request recebido."""

    def __init__(self) -> None:
        self.requests: list[httpx.Request] = []
        self.routes: dict[tuple[str, str], Any] = {}
        self.user = dict(USER)
        self.auth_status = 200

    # -- configuração ---------------------------------------------------
    def add(
        self,
        method: str,
        path: str,
        payload: Any = None,
        *,
        status: int = 200,
        headers: dict[str, str] | None = None,
        handler: Callable[[httpx.Request], Any] | None = None,
    ) -> None:
        self.routes[(method.upper(), path)] = {
            "payload": payload,
            "status": status,
            "headers": headers or {},
            "handler": handler,
        }

    def transport(self) -> httpx.MockTransport:
        return httpx.MockTransport(self._handle)

    # -- inspeção -------------------------------------------------------
    def calls(self, method: str, path: str) -> list[httpx.Request]:
        return [
            request
            for request in self.requests
            if request.method == method.upper() and request.url.path == path
        ]

    def last(self, method: str, path: str) -> httpx.Request:
        calls = self.calls(method, path)
        assert calls, f"nenhuma chamada {method} {path}; recebidas: {self.summary()}"
        return calls[-1]

    def summary(self) -> list[str]:
        return [f"{request.method} {request.url.path}" for request in self.requests]

    # -- roteamento -----------------------------------------------------
    def _handle(self, request: httpx.Request) -> httpx.Response:
        self.requests.append(request)
        path = request.url.path
        if path == "/auth/v1/user":
            if self.auth_status != 200:
                return httpx.Response(self.auth_status, json={"message": "invalid JWT"})
            return httpx.Response(200, json=self.user)
        route = self.routes.get((request.method.upper(), path))
        if route is None:
            return httpx.Response(
                404,
                json={"code": "PGRST116", "message": f"sem rota fake: {request.method} {path}"},
            )
        if route["handler"] is not None:
            result = route["handler"](request)
            if isinstance(result, httpx.Response):
                return result
            if isinstance(result, tuple):
                status, payload, *rest = result
                headers = rest[0] if rest else route["headers"]
                return httpx.Response(status, json=payload, headers=headers)
            return httpx.Response(route["status"], json=result, headers=route["headers"])
        return httpx.Response(route["status"], json=route["payload"], headers=route["headers"])


@pytest.fixture()
def fake() -> FakeSupabase:
    return FakeSupabase()


@pytest.fixture()
def client(fake: FakeSupabase):
    app = create_app(
        {
            "TESTING": True,
            "SUPABASE_URL": "https://fake.supabase.co",
            "SUPABASE_ANON_KEY": ANON_KEY,
            "SUPABASE_SERVICE_ROLE_KEY": "",
            "SUPABASE_DB_URL": "",
            "PLUGGY_API_KEY": "",
            "HTTP_TRANSPORT": fake.transport(),
            "DEMO_FAMILY_ID": "eeeeeeee-0000-4000-8000-000000000001",
            "JEV_AI_BASE_URL": "",
            "JEV_AI_API_KEY": "",
        }
    )
    return app.test_client()


@pytest.fixture()
def auth_headers() -> dict[str, str]:
    return {"Authorization": f"Bearer {USER_JWT}"}


@pytest.fixture()
def make_client(fake: FakeSupabase):
    def build(**overrides: Any):
        config = {
            "TESTING": True,
            "SUPABASE_URL": "https://fake.supabase.co",
            "SUPABASE_ANON_KEY": ANON_KEY,
            "SUPABASE_SERVICE_ROLE_KEY": "",
            "SUPABASE_DB_URL": "",
            "PLUGGY_API_KEY": "",
            "HTTP_TRANSPORT": fake.transport(),
            "DEMO_FAMILY_ID": "eeeeeeee-0000-4000-8000-000000000001",
            "JEV_AI_BASE_URL": "",
            "JEV_AI_API_KEY": "",
        }
        config.update(overrides)
        return create_app(config).test_client()

    return build


def profile_route(fake: FakeSupabase, profile: dict[str, Any] | None = None) -> None:
    fake.add("GET", "/rest/v1/profiles", [profile or PROFILE])


def body_of(request: httpx.Request) -> Any:
    return json.loads(request.content.decode("utf-8")) if request.content else None


def all_headers(request: httpx.Request) -> str:
    return " ".join(f"{key}:{value}" for key, value in request.headers.items())
