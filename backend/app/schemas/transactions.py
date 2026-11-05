"""Validação de lançamentos manuais."""

from __future__ import annotations

from typing import Any, Mapping

from .common import reject

FORBIDDEN_CREATE = (
    "family_id",
    "member_id",
    "recurring_rule_id",
    "mes_referencia",
    "origem",
    "bank_transaction_id",
)
IMMUTABLE_PATCH = (
    "family_id",
    "member_id",
    "criado_por",
    "origem",
    "escopo",
    "recurring_rule_id",
    "mes_referencia",
    "bank_transaction_id",
)


def validate_create(data: Mapping[str, Any]) -> Mapping[str, Any]:
    reject(
        data,
        FORBIDDEN_CREATE,
        "Lançamentos manuais não aceitam recorrência, origem ou vínculo bancário.",
    )
    return data


def validate_patch(data: Mapping[str, Any]) -> Mapping[str, Any]:
    reject(
        data,
        IMMUTABLE_PATCH,
        "Estes campos são imutáveis; o vínculo bancário usa /banking/reconcile.",
    )
    return data
