"""Importação, reconciliação e ignore de transações bancárias."""

from __future__ import annotations

from typing import Any, Mapping

from ...errors import ApiError, not_found
from ...utils import clean_text, money, num, one_of, opt_money, parse_date, safe_id, ESCOPOS
from ..analytics import category_names


def _bank_tx(rest: Any, bank_transaction_id: str) -> Mapping[str, Any]:
    bank_transaction_id = safe_id(bank_transaction_id, "bank_transaction_id")
    rows = rest.get(
        "/rest/v1/bank_transactions",
        {"id": f"eq.{bank_transaction_id}", "select": "*", "limit": "1"},
    )
    if not rows:
        raise not_found("Transação bancária não encontrada.")
    return rows[0]


def _transaction(rest: Any, transaction_id: str) -> Mapping[str, Any]:
    transaction_id = safe_id(transaction_id, "transaction_id")
    rows = rest.get(
        "/rest/v1/transactions",
        {"id": f"eq.{transaction_id}", "select": "*", "limit": "1"},
    )
    if not rows:
        raise not_found("Lançamento não encontrado.")
    return rows[0]


def _required_id(payload: Mapping[str, Any], field: str) -> str:
    return safe_id(payload.get(field), field)


def import_bank_transaction(
    rest: Any,
    profile: Mapping[str, Any],
    user_id: str,
    payload: Mapping[str, Any],
) -> dict[str, Any]:
    bank_transaction_id = _required_id(payload, "bank_transaction_id")
    bank_tx = _bank_tx(rest, bank_transaction_id)
    if bank_tx.get("status") != "pendente_importacao":
        raise ApiError(409, "conflict", "Esta transação já foi importada, reconciliada ou ignorada.")

    tipo = "despesa" if bank_tx.get("tipo") == "debito" else "receita"
    escopo = one_of(payload.get("escopo") or "pessoal", ESCOPOS, "escopo")
    category_id = _required_id(payload, "category_id")
    valor = opt_money(payload.get("valor")) or money(bank_tx.get("valor"))
    data = parse_date(payload.get("data") or bank_tx.get("data"))
    descricao = clean_text(payload.get("descricao"), "descricao", max_len=500) or bank_tx.get("descricao")

    rows = rest.post(
        "/rest/v1/transactions",
        {
            "family_id": profile["family_id"],
            "member_id": user_id,
            "tipo": tipo,
            "escopo": escopo,
            "valor": valor,
            "descricao": descricao,
            "category_id": category_id,
            "data": data.isoformat(),
            "criado_por": user_id,
            "origem": "pluggy",
            "bank_transaction_id": bank_transaction_id,
        },
    )
    return (rows or [{}])[0]


def reconcile(
    rest: Any,
    payload: Mapping[str, Any],
) -> dict[str, Any]:
    bank_transaction_id = _required_id(payload, "bank_transaction_id")
    transaction_id = _required_id(payload, "transaction_id")
    bank_tx = _bank_tx(rest, bank_transaction_id)
    if bank_tx.get("status") in ("importada", "reconciliada"):
        raise ApiError(409, "conflict", "Esta transação bancária já tem vínculo.")
    transaction = _transaction(rest, transaction_id)
    if transaction.get("bank_transaction_id"):
        raise ApiError(409, "conflict", "Este lançamento já está vinculado a outra transação.")
    rows = rest.patch(
        f"/rest/v1/transactions?id=eq.{transaction_id}",
        {"bank_transaction_id": bank_transaction_id},
    )
    return (rows or [transaction])[0]


def candidates(rest: Any, bank_transaction_id: str) -> list[dict[str, Any]]:
    bank_tx = _bank_tx(rest, bank_transaction_id)
    valor = num(bank_tx.get("valor"))
    data = parse_date(bank_tx.get("data"))
    from datetime import timedelta

    low = (data - timedelta(days=1)).isoformat()
    high = (data + timedelta(days=1)).isoformat()
    rows = rest.get(
        "/rest/v1/transactions",
        {
            "select": "id,valor,data,descricao,category_id",
            "origem": "eq.manual",
            "bank_transaction_id": "is.null",
            "and": (
                f"(valor.gte.{valor - 0.011:.2f},valor.lte.{valor + 0.011:.2f},"
                f"data.gte.{low},data.lte.{high})"
            ),
            "order": "data.desc",
        },
    )
    names = category_names(rest)
    return [
        {
            "transaction_id": item.get("id"),
            "valor": item.get("valor"),
            "data": item.get("data"),
            "descricao": item.get("descricao"),
            "categoria": names.get(str(item.get("category_id"))),
            "categoria_id": item.get("category_id"),
        }
        for item in (rows or [])
        if isinstance(item, Mapping)
    ]


def set_status(rest: Any, bank_transaction_id: str, status: str) -> dict[str, Any]:
    bank_tx = _bank_tx(rest, bank_transaction_id)
    current = bank_tx.get("status")
    if current in ("importada", "reconciliada"):
        raise ApiError(409, "conflict", "Transações importadas ou reconciliadas não mudam de status.")
    if status == "pendente_importacao" and current != "ignorada":
        raise ApiError(409, "conflict", "Só uma transação ignorada volta para a fila.")
    if status == "ignorada" and current != "pendente_importacao":
        raise ApiError(409, "conflict", "Só uma transação pendente pode ser ignorada.")
    rows = rest.patch(
        "/rest/v1/bank_transactions",
        {"status": status},
        {"id": f"eq.{bank_transaction_id}", "status": f"eq.{current}"},
    )
    return (rows or [bank_tx])[0]
