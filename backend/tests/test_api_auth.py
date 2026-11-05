"""Auth, /me, onboarding e convites."""

from __future__ import annotations

from conftest import (
    ANON_KEY,
    FAMILY,
    PROFILE,
    SERVICE_KEY,
    USER_JWT,
    body_of,
    profile_route,
)

INVITE = {
    "id": "inv-1",
    "family_id": "fam-1",
    "family_nome": "Família Souza",
    "email": "ana@demo.vivafinancas.app",
    "nome": "Ana",
    "papel": "membro",
    "status": "pendente",
    "token": "11111111-1111-4111-8111-111111111111",
    "criado_por": "u-ana",
    "criado_em": "2026-11-01T12:00:00Z",
    "aceito_em": None,
}


def test_health_is_public(client):
    response = client.get("/api/health")
    assert response.status_code == 200
    assert response.get_json() == {"ok": True}


def test_missing_token_is_401(client):
    response = client.get("/api/me")
    assert response.status_code == 401
    assert response.get_json()["error"]["code"] == "unauthorized"


def test_invalid_token_is_401(client, fake, auth_headers):
    fake.auth_status = 401
    response = client.get("/api/me", headers=auth_headers)
    assert response.status_code == 401


def test_me_without_profile_returns_null(client, fake, auth_headers):
    fake.add("GET", "/rest/v1/profiles", [])
    response = client.get("/api/me", headers=auth_headers)
    assert response.status_code == 200
    payload = response.get_json()
    assert payload["user"] == {"id": "u-ana", "email": "ana@demo.vivafinancas.app"}
    assert payload["profile"] is None
    assert payload["family"] is None


def test_me_returns_profile_and_family(client, fake, auth_headers):
    profile_route(fake)
    fake.add("GET", "/rest/v1/families", [FAMILY])
    response = client.get("/api/me", headers=auth_headers)
    assert response.status_code == 200
    payload = response.get_json()
    assert payload["profile"]["id"] == "u-ana"
    assert payload["family"] == FAMILY


def test_inactive_profile_hides_family(client, fake, auth_headers):
    profile_route(fake, {**PROFILE, "status": "inativo"})
    response = client.get("/api/me", headers=auth_headers)
    assert response.status_code == 200
    payload = response.get_json()
    assert payload["profile"]["status"] == "inativo"
    assert payload["family"] is None
    assert not fake.calls("GET", "/rest/v1/families")


def test_patch_me_only_editable_fields(client, fake, auth_headers):
    profile_route(fake)
    fake.add(
        "PATCH",
        "/rest/v1/profiles",
        [{**PROFILE, "nome": "Ana Lima", "tema": "escuro"}],
    )
    response = client.patch(
        "/api/me",
        headers=auth_headers,
        json={"nome": "Ana Lima", "tema": "escuro"},
    )
    assert response.status_code == 200
    assert response.get_json()["profile"]["nome"] == "Ana Lima"
    sent = body_of(fake.last("PATCH", "/rest/v1/profiles"))
    assert sent == {"nome": "Ana Lima", "tema": "escuro"}

    blocked = client.patch(
        "/api/me",
        headers=auth_headers,
        json={"papel": "admin"},
    )
    assert blocked.status_code == 422


def test_onboarding_calls_rpc_and_returns_me(client, fake, auth_headers):
    profile_route(fake)
    fake.add("GET", "/rest/v1/families", [FAMILY])
    fake.add("POST", "/rest/v1/rpc/onboard_family", [{"family_id": "fam-1", "profile_id": "u-ana"}])
    response = client.post(
        "/api/onboarding",
        headers=auth_headers,
        json={"nome_familia": "Família Souza", "nome": "Ana"},
    )
    assert response.status_code == 200
    assert response.get_json()["profile"]["family_id"] == "fam-1"
    sent = body_of(fake.last("POST", "/rest/v1/rpc/onboard_family"))
    assert sent == {"p_nome_familia": "Família Souza", "p_nome": "Ana"}


def test_onboarding_rejects_empty_names(client, fake, auth_headers):
    response = client.post(
        "/api/onboarding",
        headers=auth_headers,
        json={"nome_familia": "  ", "nome": "Ana"},
    )
    assert response.status_code == 422
    assert not fake.calls("POST", "/rest/v1/rpc/onboard_family")


def test_invites_mine_filters_by_authenticated_email(client, fake, auth_headers):
    def invites(request):
        if request.url.params.get("email") == "eq.ana@demo.vivafinancas.app":
            return [INVITE]
        return []

    fake.add("GET", "/rest/v1/invites", handler=invites)
    response = client.get("/api/invites/mine", headers=auth_headers)
    assert response.status_code == 200
    payload = response.get_json()
    assert payload["invite_id"] == "inv-1"
    assert payload["family_nome"] == "Família Souza"
    assert fake.last("GET", "/rest/v1/invites").url.params.get("email") == (
        "eq.ana@demo.vivafinancas.app"
    )


def test_invites_mine_hides_invite_from_another_email(client, fake, auth_headers):
    def invites(request):
        # Simula a RLS/filtro: só devolve o convite do e-mail autenticado.
        if request.url.params.get("email") == "eq.ana@demo.vivafinancas.app":
            return [INVITE]
        return []

    fake.add("GET", "/rest/v1/invites", handler=invites)
    fake.user = {"id": "u-beto", "email": "beto@example.com"}
    response = client.get("/api/invites/mine", headers=auth_headers)
    assert response.status_code == 200
    assert response.get_json() is None
    assert fake.last("GET", "/rest/v1/invites").url.params.get("email") == (
        "eq.beto@example.com"
    )


def test_accept_invite_calls_rpc(client, fake, auth_headers):
    profile_route(fake, {**PROFILE, "papel": "membro"})
    fake.add("GET", "/rest/v1/families", [FAMILY])
    fake.add(
        "POST",
        "/rest/v1/rpc/accept_invite",
        [{"profile_id": "u-ana", "family_id": "fam-1"}],
    )
    response = client.post(
        "/api/invites/accept",
        headers=auth_headers,
        json={"token": INVITE["token"], "nome": "Ana"},
    )
    assert response.status_code == 200
    sent = body_of(fake.last("POST", "/rest/v1/rpc/accept_invite"))
    assert sent == {"p_token": INVITE["token"], "p_nome": "Ana"}


def test_accept_invite_invalid_token_is_422(client, fake, auth_headers):
    response = client.post(
        "/api/invites/accept",
        headers=auth_headers,
        json={"token": "nope"},
    )
    assert response.status_code == 422
    assert not fake.calls("POST", "/rest/v1/rpc/accept_invite")


def test_normal_requests_never_use_service_role(client, fake, auth_headers):
    profile_route(fake)
    fake.add("GET", "/rest/v1/families", [FAMILY])
    client.get("/api/me", headers=auth_headers)
    assert fake.requests
    for request in fake.requests:
        assert request.headers.get("apikey") == ANON_KEY
        assert request.headers.get("authorization") == f"Bearer {USER_JWT}"
        assert SERVICE_KEY not in " ".join(request.headers.values())
