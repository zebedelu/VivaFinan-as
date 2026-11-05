"""Validação de metas e contribuições."""

from __future__ import annotations

from typing import Any, Mapping

from .common import reject


def validate_create(data: Mapping[str, Any]) -> Mapping[str, Any]:
    reject(data, ("family_id", "criado_por", "status"), "Família e criador vêm do perfil.")
    return data


def validate_patch(data: Mapping[str, Any]) -> Mapping[str, Any]:
    reject(data, ("family_id", "criado_por", "member_id"), "Identidade da meta é imutável.")
    return data


def validate_contribution(data: Mapping[str, Any]) -> Mapping[str, Any]:
    reject(
        data,
        ("family_id", "member_id", "goal_id"),
        "A contribuição é sempre do usuário autenticado para a meta da rota.",
    )
    return data
