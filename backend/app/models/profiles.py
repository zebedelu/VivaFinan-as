"""Perfis, família e diretório de membros."""

from __future__ import annotations

from typing import Any, Mapping

from ..errors import validation
from ..utils import clean_text, one_of, safe_id, TEMAS
from .common import member_directory


def get_profile(rest: Any, user_id: str) -> dict[str, Any] | None:
    rows = rest.get(
        "/rest/v1/profiles",
        {
            "id": f"eq.{user_id}",
            "select": "id,family_id,nome,papel,status,tema",
            "limit": "1",
        },
    )
    return rows[0] if rows else None


def get_family(rest: Any, family_id: str) -> dict[str, Any] | None:
    rows = rest.get(
        "/rest/v1/families",
        {
            "id": f"eq.{family_id}",
            "select": "id,nome,is_demo",
            "limit": "1",
        },
    )
    return rows[0] if rows else None


def me_payload(rest: Any, user: Mapping[str, Any]) -> dict[str, Any]:
    profile = get_profile(rest, str(user["id"]))
    family = None
    if profile and profile.get("status") == "ativo":
        family = get_family(rest, str(profile["family_id"]))
    return {
        "user": {"id": user.get("id"), "email": user.get("email")},
        "profile": profile,
        "family": family,
    }


def update_profile(rest: Any, user_id: str, data: Mapping[str, Any]) -> dict[str, Any]:
    payload: dict[str, Any] = {}
    if "nome" in data:
        payload["nome"] = clean_text(data.get("nome"), "nome", required=True, max_len=80)
    if "tema" in data:
        payload["tema"] = one_of(data.get("tema"), TEMAS, "tema")
    if not payload:
        raise validation("Informe nome ou tema para atualizar.")
    rows = rest.patch(
        "/rest/v1/profiles",
        payload,
        {"id": f"eq.{user_id}", "select": "id,family_id,nome,papel,status,tema"},
    )
    return (rows or [{}])[0]


def list_members(rest: Any, profile: Mapping[str, Any]) -> list[dict[str, Any]]:
    rows = rest.get(
        "/rest/v1/profiles",
        {
            "family_id": f"eq.{profile['family_id']}",
            "select": "id,nome,papel,status,tema,criado_em",
            "order": "nome.asc",
        },
    )
    return list(rows or [])


def update_member(
    rest: Any,
    actor_id: str,
    member_id: str,
    data: Mapping[str, Any],
) -> dict[str, Any]:
    member_id = safe_id(member_id, "member_id")
    payload: dict[str, Any] = {}
    if "nome" in data:
        payload["nome"] = clean_text(data.get("nome"), "nome", required=True, max_len=80)
    if "status" in data:
        payload["status"] = one_of(data.get("status"), ("ativo", "inativo"), "status")
    if "tema" in data:
        if member_id != actor_id:
            raise validation("O tema só pode ser alterado pelo próprio membro.")
        payload["tema"] = one_of(data.get("tema"), TEMAS, "tema")
    if "papel" in data:
        raise validation("O papel não pode ser alterado por aqui.")
    if not payload:
        raise validation("Informe nome, status ou tema.")
    rows = rest.patch(
        "/rest/v1/profiles",
        payload,
        {"id": f"eq.{member_id}", "select": "id,nome,papel,status,tema,criado_em"},
    )
    return (rows or [{}])[0]


def directory(rest: Any, profile: Mapping[str, Any]) -> list[dict[str, Any]]:
    return member_directory(rest, profile)
