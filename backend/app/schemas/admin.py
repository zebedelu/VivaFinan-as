"""Validação de admin, convites e categorias."""

from __future__ import annotations

from typing import Any, Mapping

from .common import reject


def validate_member_patch(data: Mapping[str, Any]) -> Mapping[str, Any]:
    reject(data, ("id", "family_id", "papel"), "Campo não editável.")
    return data


def validate_invite(data: Mapping[str, Any]) -> Mapping[str, Any]:
    reject(
        data,
        ("id", "family_id", "papel", "status", "auth_user_id"),
        "O convite é sempre de membro pendente.",
    )
    return data


def validate_category(data: Mapping[str, Any]) -> Mapping[str, Any]:
    reject(data, ("family_id", "criado_por", "personalizada"), "Campo não editável.")
    return data
