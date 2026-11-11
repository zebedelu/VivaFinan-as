"""Validação de conexões, importação e reconciliação bancária."""

from __future__ import annotations

from typing import Any, Mapping

from .common import reject


def validate_connection_create(data: Mapping[str, Any]) -> Mapping[str, Any]:
    reject(
        data,
        ("family_id", "member_id", "is_demo_sync", "status"),
        "A conexão é sempre pessoal e criada pelo usuário autenticado.",
    )
    return data


def validate_connect_token(data: Mapping[str, Any]) -> Mapping[str, Any]:
    reject(
        data,
        ("family_id", "member_id", "clientUserId", "client_user_id"),
        "O connect token usa sempre o usuário autenticado.",
    )
    return data


def validate_import(data: Mapping[str, Any]) -> Mapping[str, Any]:
    reject(data, ("family_id", "member_id", "origem"), "Importação deriva dono e origem.")
    return data


def validate_reconcile(data: Mapping[str, Any]) -> Mapping[str, Any]:
    reject(data, ("family_id", "member_id"), "O vínculo é validado pelo dono da conexão.")
    return data
