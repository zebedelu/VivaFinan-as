"""Validação de payloads da Jev AI."""

from __future__ import annotations

from typing import Any, Mapping

from ..errors import validation


def validate_read(data: Mapping[str, Any]) -> Mapping[str, Any]:
    if data.get("lida") is not True:
        raise validation("Envie {lida: true}.")
    return data


def validate_message(data: Mapping[str, Any]) -> Mapping[str, Any]:
    if "member_id" in data:
        raise validation("member_id vem do usuário autenticado.")
    return data
