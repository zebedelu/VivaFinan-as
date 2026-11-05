"""Autenticação Flask: Bearer validado no Supabase Auth e perfil via RLS."""

from __future__ import annotations

from functools import wraps
from typing import Any, Callable, TypeVar

from flask import current_app, g, request

from .errors import ApiError
from .supabase import SupabaseAuth, SupabaseRest

F = TypeVar("F", bound=Callable[..., Any])


def _auth_client() -> SupabaseAuth:
    client = getattr(g, "_auth_client", None)
    if client is None:
        client = SupabaseAuth(
            current_app.config.get("SUPABASE_URL", ""),
            current_app.config.get("SUPABASE_ANON_KEY", ""),
            transport=current_app.config.get("HTTP_TRANSPORT"),
            timeout=float(current_app.config.get("HTTP_TIMEOUT", 10.0)),
        )
        g._auth_client = client
    return client


def authenticate() -> dict[str, Any]:
    """Valida o Bearer uma vez por request e guarda usuário/JWT em ``g``."""
    if getattr(g, "user", None) is not None:
        return g.user
    header = request.headers.get("Authorization", "")
    if not header.lower().startswith("bearer "):
        raise ApiError(401, "unauthorized", "Informe o token de acesso.")
    token = header.split(" ", 1)[1].strip()
    if not token:
        raise ApiError(401, "unauthorized", "Token de acesso vazio.")
    user = _auth_client().get_user(token)
    g.user = user
    g.jwt = token
    return user


def rest() -> SupabaseRest:
    """PostgREST com o JWT do usuário autenticado."""
    authenticate()
    client = getattr(g, "_rest_client", None)
    if client is None:
        client = SupabaseRest(
            current_app.config.get("SUPABASE_URL", ""),
            current_app.config.get("SUPABASE_ANON_KEY", ""),
            getattr(g, "jwt", None),
            transport=current_app.config.get("HTTP_TRANSPORT"),
            timeout=float(current_app.config.get("HTTP_TIMEOUT", 10.0)),
        )
        g._rest_client = client
    return client


def load_profile() -> dict[str, Any] | None:
    if hasattr(g, "profile"):
        return g.profile
    user = authenticate()
    rows = rest().get(
        "/rest/v1/profiles",
        {
            "id": f"eq.{user['id']}",
            "select": "id,family_id,nome,papel,status,tema,criado_em",
            "limit": "1",
        },
    )
    g.profile = rows[0] if isinstance(rows, list) and rows else None
    return g.profile


def require_auth(view: F) -> F:
    @wraps(view)
    def wrapped(*args: Any, **kwargs: Any):
        authenticate()
        return view(*args, **kwargs)

    return wrapped  # type: ignore[return-value]


def require_profile(view: F) -> F:
    @wraps(view)
    def wrapped(*args: Any, **kwargs: Any):
        authenticate()
        profile = load_profile()
        if not profile:
            raise ApiError(403, "no_profile", "Conclua o onboarding para continuar.")
        if profile.get("status") != "ativo":
            raise ApiError(403, "inactive_profile", "Conta desativada.")
        g.profile = profile
        return view(*args, **kwargs)

    return wrapped  # type: ignore[return-value]


def require_admin(view: F) -> F:
    @wraps(view)
    def wrapped(*args: Any, **kwargs: Any):
        authenticate()
        profile = load_profile()
        if not profile or profile.get("status") != "ativo":
            raise ApiError(403, "no_profile", "Conclua o onboarding para continuar.")
        if profile.get("papel") != "admin":
            raise ApiError(403, "forbidden", "Somente administradores da família.")
        g.profile = profile
        return view(*args, **kwargs)

    return wrapped  # type: ignore[return-value]


def user_id() -> str:
    return str(authenticate()["id"])


def user_email() -> str | None:
    email = authenticate().get("email")
    return str(email) if email else None
