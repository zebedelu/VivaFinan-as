"""Validação de regras recorrentes."""

from __future__ import annotations

from typing import Any, Mapping

from .common import reject

FORBIDDEN_CREATE = ("family_id", "criado_por")


def validate_create(data: Mapping[str, Any]) -> Mapping[str, Any]:
    reject(data, FORBIDDEN_CREATE, "A família e o criador vêm do perfil autenticado.")
    return data


def validate_patch(data: Mapping[str, Any]) -> Mapping[str, Any]:
    reject(data, ("family_id", "criado_por"), "A família e o criador são imutáveis.")
    return data
