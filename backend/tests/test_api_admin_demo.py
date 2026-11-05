"""Admin, convites e restauração da demo."""

from __future__ import annotations

from contextlib import contextmanager

from conftest import (
    FAMILY,
    PROFILE,
    SERVICE_KEY,
    USER_JWT,
    body_of,
    profile_route,
)

DEMO_FAMILY = "eeeeeeee-0000-4000-8000-000000000001"


def test_admin_invite_without_service_role_is_503(client, fake, auth_headers):
    profile_route(fake)
    response = client.post(
        "/api/admin/invites",
        headers=auth_headers,
        json={"email": "novo@example.com", "nome": "Novo"},
    )
    assert response.status_code == 503
    assert response.get_json()["error"]["code"] == "unavailable"
    assert not fake.calls("POST", "/auth/v1/invite")


def test_admin_members_requires_admin(client, fake, auth_headers):
    profile_route(fake, {**PROFILE, "papel": "membro"})
    response = client.get("/api/admin/members", headers=auth_headers)
    assert response.status_code == 403


def test_admin_invite_uses_service_role_only_for_admin_api(make_client, fake, auth_headers):
    client = make_client(SUPABASE_SERVICE_ROLE_KEY=SERVICE_KEY)
    profile_route(fake)
    fake.add("GET", "/rest/v1/families", [FAMILY])
    fake.add("POST", "/auth/v1/invite", {"id": "invited-1", "email": "novo@example.com"})
    fake.add(
        "POST",
        "/rest/v1/invites",
        [
            {
                "id": "inv-1",
                "token": "22222222-2222-4222-8222-222222222222",
                "email": "novo@example.com",
            }
        ],
    )
    response = client.post(
        "/api/admin/invites",
        headers=auth_headers,
        json={"email": "Novo@Example.com", "nome": "Novo"},
    )
    assert response.status_code == 201, response.get_json()
    assert response.get_json() == {
        "invite_id": "inv-1",
        "token": "22222222-2222-4222-8222-222222222222",
        "email": "novo@example.com",
    }
    admin_call = fake.last("POST", "/auth/v1/invite")
    assert admin_call.headers.get("apikey") == SERVICE_KEY
    row_call = fake.last("POST", "/rest/v1/invites")
    assert row_call.headers.get("apikey") == "anon-key"
    assert row_call.headers.get("authorization") == f"Bearer {USER_JWT}"
    sent = body_of(row_call)
    assert sent["family_id"] == "fam-1"
    assert sent["family_nome"] == "Família Souza"
    assert sent["criado_por"] == "u-ana"
    assert sent["papel"] == "membro"
    assert sent["auth_user_id"] == "invited-1"


def test_admin_invite_rejects_client_auth_user_id(client, fake, auth_headers):
    profile_route(fake)
    response = client.post(
        "/api/admin/invites",
        headers=auth_headers,
        json={"email": "novo@example.com", "auth_user_id": "u-invadido"},
    )
    assert response.status_code == 422
    assert not fake.calls("POST", "/auth/v1/invite")


def test_admin_invite_compensates_when_row_fails(make_client, fake, auth_headers):
    client = make_client(SUPABASE_SERVICE_ROLE_KEY=SERVICE_KEY)
    profile_route(fake)
    fake.add("GET", "/rest/v1/families", [FAMILY])
    fake.add("POST", "/auth/v1/invite", {"id": "invited-1"})
    fake.add(
        "POST",
        "/rest/v1/invites",
        {"code": "23505", "message": "duplicate key"},
        status=409,
    )
    fake.add("DELETE", "/auth/v1/admin/users/invited-1", None)
    response = client.post(
        "/api/admin/invites",
        headers=auth_headers,
        json={"email": "novo@example.com"},
    )
    assert response.status_code == 409
    assert response.get_json()["error"]["code"] == "conflict"
    assert fake.calls("DELETE", "/auth/v1/admin/users/invited-1")


def test_admin_patch_member_blocks_papel(client, fake, auth_headers):
    profile_route(fake)
    blocked = client.patch(
        "/api/admin/members/u-carlos",
        headers=auth_headers,
        json={"papel": "admin"},
    )
    assert blocked.status_code == 422
    fake.add(
        "PATCH",
        "/rest/v1/profiles",
        [{"id": "u-carlos", "nome": "Carlos", "papel": "membro", "status": "inativo", "tema": "claro"}],
    )
    response = client.patch(
        "/api/admin/members/u-carlos",
        headers=auth_headers,
        json={"nome": "Carlos", "status": "inativo"},
    )
    assert response.status_code == 200
    assert fake.last("PATCH", "/rest/v1/profiles").url.params.get("id") == "eq.u-carlos"


def test_demo_restore_without_db_url_is_503(client, fake, auth_headers):
    profile_route(fake, {**PROFILE, "family_id": DEMO_FAMILY})
    response = client.post("/api/demo/restore", headers=auth_headers, json={})
    assert response.status_code == 503
    assert response.get_json()["error"]["code"] == "unavailable"


def test_demo_restore_rejects_non_demo_member(client, fake, auth_headers):
    profile_route(fake)
    response = client.post("/api/demo/restore", headers=auth_headers, json={})
    assert response.status_code == 403


def test_admin_invites_list_and_cancel_deletes_auth_user(make_client, fake, auth_headers):
    client = make_client(SUPABASE_SERVICE_ROLE_KEY=SERVICE_KEY)
    profile_route(fake)
    fake.add(
        "GET",
        "/rest/v1/invites",
        [
            {
                "id": "inv-1",
                "family_id": "fam-1",
                "email": "novo@example.com",
                "nome": "Novo",
                "status": "pendente",
                "token": "33333333-3333-4333-8333-333333333333",
                "auth_user_id": "invited-1",
            }
        ],
    )
    fake.add("DELETE", "/auth/v1/admin/users/invited-1", None)
    fake.add(
        "PATCH",
        "/rest/v1/invites",
        [{"id": "inv-1", "status": "cancelado", "auth_user_id": "invited-1"}],
    )
    listed = client.get("/api/admin/invites", headers=auth_headers)
    assert listed.status_code == 200
    assert listed.get_json()["invites"][0]["token"]

    cancelled = client.delete("/api/admin/invites/inv-1", headers=auth_headers)
    assert cancelled.status_code == 200, cancelled.get_json()
    request = fake.last("PATCH", "/rest/v1/invites")
    assert body_of(request) == {"status": "cancelado"}
    assert request.url.params.get("status") == "eq.pendente"
    calls = fake.summary()
    assert calls.index("PATCH /rest/v1/invites") < calls.index(
        "DELETE /auth/v1/admin/users/invited-1"
    )
    delete_call = fake.last("DELETE", "/auth/v1/admin/users/invited-1")
    assert delete_call.headers.get("apikey") == SERVICE_KEY


def test_cancel_invite_tolera_usuario_auth_ja_apagado(make_client, fake, auth_headers):
    client = make_client(SUPABASE_SERVICE_ROLE_KEY=SERVICE_KEY)
    profile_route(fake)
    fake.add(
        "GET",
        "/rest/v1/invites",
        [{"id": "inv-1", "status": "pendente", "auth_user_id": "invited-1"}],
    )
    fake.add(
        "DELETE",
        "/auth/v1/admin/users/invited-1",
        {"message": "User not found"},
        status=404,
    )
    fake.add("PATCH", "/rest/v1/invites", [{"id": "inv-1", "status": "cancelado", "auth_user_id": "invited-1"}])
    response = client.delete("/api/admin/invites/inv-1", headers=auth_headers)
    assert response.status_code == 200, response.get_json()
    assert fake.calls("PATCH", "/rest/v1/invites")


def test_cancel_invite_sem_pendente_e_404(make_client, fake, auth_headers):
    client = make_client(SUPABASE_SERVICE_ROLE_KEY=SERVICE_KEY)
    profile_route(fake)
    fake.add("PATCH", "/rest/v1/invites", [])
    response = client.delete("/api/admin/invites/inv-1", headers=auth_headers)
    assert response.status_code == 404
    assert fake.calls("PATCH", "/rest/v1/invites")
    assert not fake.calls("DELETE", "/auth/v1/admin/users/invited-1")


def test_reinvite_after_cancel_uses_new_auth_user(make_client, fake, auth_headers):
    client = make_client(SUPABASE_SERVICE_ROLE_KEY=SERVICE_KEY)
    profile_route(fake)
    fake.add("GET", "/rest/v1/families", [FAMILY])
    fake.add(
        "GET",
        "/rest/v1/invites",
        [{"id": "inv-1", "status": "pendente", "auth_user_id": "invited-1"}],
    )
    fake.add("DELETE", "/auth/v1/admin/users/invited-1", None)
    fake.add("PATCH", "/rest/v1/invites", [{"id": "inv-1", "status": "cancelado", "auth_user_id": "invited-1"}])
    fake.add("POST", "/auth/v1/invite", {"id": "invited-2"})
    fake.add(
        "POST",
        "/rest/v1/invites",
        [{"id": "inv-2", "email": "novo@example.com", "token": "44444444-4444-4444-8444-444444444444"}],
    )

    first = client.delete("/api/admin/invites/inv-1", headers=auth_headers)
    assert first.status_code == 200
    again = client.post(
        "/api/admin/invites",
        headers=auth_headers,
        json={"email": "novo@example.com", "nome": "Novo"},
    )
    assert again.status_code == 201, again.get_json()
    assert again.get_json()["invite_id"] == "inv-2"
    assert body_of(fake.last("POST", "/rest/v1/invites"))["auth_user_id"] == "invited-2"


def test_categories_crud(client, fake, auth_headers):
    profile_route(fake)
    category = {
        "id": "c-pets",
        "family_id": "fam-1",
        "nome": "Pets",
        "tipo": "despesa",
        "personalizada": True,
        "oculta": False,
        "criado_por": "u-ana",
        "criado_em": "2026-11-01T12:00:00Z",
    }
    fake.add("GET", "/rest/v1/categories", [category])
    fake.add("POST", "/rest/v1/categories", [category])
    fake.add("PATCH", "/rest/v1/categories", [{**category, "oculta": True}])
    fake.add("DELETE", "/rest/v1/categories", [category])

    listed = client.get("/api/categories", headers=auth_headers)
    assert listed.status_code == 200
    assert listed.get_json()["categories"][0]["nome"] == "Pets"

    created = client.post(
        "/api/categories",
        headers=auth_headers,
        json={"nome": "Pets", "tipo": "despesa"},
    )
    assert created.status_code == 201
    sent = body_of(fake.last("POST", "/rest/v1/categories"))
    assert sent["family_id"] == "fam-1"
    assert sent["personalizada"] is True
    assert sent["criado_por"] == "u-ana"

    patched = client.patch(
        "/api/categories/c-pets",
        headers=auth_headers,
        json={"oculta": True},
    )
    assert patched.status_code == 200
    assert patched.get_json()["category"]["oculta"] is True

    removed = client.delete("/api/categories/c-pets", headers=auth_headers)
    assert removed.status_code == 200


def test_demo_restore_runs_seeds_in_one_transaction(make_client, fake, auth_headers, tmp_path, monkeypatch):
    executed: list[str] = []

    class FakeCursor:
        def execute(self, sql: str) -> None:
            executed.append(sql)

    class FakeConnection:
        def __enter__(self):
            return self

        def __exit__(self, *args):
            return False

        @contextmanager
        def transaction(self):
            yield

        @contextmanager
        def cursor(self):
            yield FakeCursor()

    import psycopg

    monkeypatch.setattr(psycopg, "connect", lambda *args, **kwargs: FakeConnection())
    for prefix in ("010", "020", "030", "040"):
        (tmp_path / f"{prefix}_demo.sql").write_text(f"-- seed {prefix}", encoding="utf-8")

    client = make_client(
        SUPABASE_DB_URL="postgresql://user:pass@host:6543/postgres",
        SEED_DIR=str(tmp_path),
        DEMO_FAMILY_ID=DEMO_FAMILY,
    )
    profile_route(fake, {**PROFILE, "family_id": DEMO_FAMILY})
    response = client.post("/api/demo/restore", headers=auth_headers, json={})
    assert response.status_code == 200, response.get_json()
    assert response.get_json() == {"ok": True, "seeds": 4}
    assert executed == ["-- seed 010", "-- seed 020", "-- seed 030", "-- seed 040"]
