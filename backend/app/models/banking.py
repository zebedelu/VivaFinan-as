"""Conexões, contas e transações bancárias."""

from __future__ import annotations

from typing import Any, Mapping

from ..errors import not_found
from ..utils import clean_text, month_end_exclusive, month_start, parse_int, safe_id
from ..utils import one_of


def list_connections(rest: Any) -> list[dict[str, Any]]:
    rows = rest.get(
        "/rest/v1/bank_connections",
        {
            "select": (
                "id,family_id,member_id,pluggy_connection_id,institution_name,"
                "institution_logo_url,account_name,account_type,account_number_masked,"
                "status,consentido_em,ultima_sync_em,criada_em,atualizada_em,is_demo_sync"
            ),
            "order": "criada_em.desc",
        },
    )
    return list(rows or [])


def get_connection(rest: Any, connection_id: str) -> Mapping[str, Any]:
    connection_id = safe_id(connection_id, "connection_id")
    rows = rest.get(
        "/rest/v1/bank_connections",
        {"id": f"eq.{connection_id}", "select": "*", "limit": "1"},
    )
    if not rows:
        raise not_found("Conexão bancária não encontrada.")
    return rows[0]


def create_connection(
    rest: Any,
    profile: Mapping[str, Any],
    user_id: str,
    data: Mapping[str, Any],
) -> dict[str, Any]:
    account_type = data.get("account_type") or None
    if account_type is not None:
        account_type = one_of(account_type, ("corrente", "poupanca"), "account_type")
    payload = {
        "family_id": profile["family_id"],
        "member_id": user_id,
        "pluggy_connection_id": safe_id(
            data.get("pluggy_connection_id"),
            "pluggy_connection_id",
            max_len=200,
        ),
        "institution_name": clean_text(
            data.get("institution_name"),
            "institution_name",
            required=True,
            max_len=120,
        ),
        "institution_logo_url": clean_text(data.get("institution_logo_url"), "institution_logo_url", max_len=500),
        "account_name": clean_text(data.get("account_name"), "account_name", max_len=120),
        "account_type": account_type,
        "account_number_masked": clean_text(
            data.get("account_number_masked"),
            "account_number_masked",
            max_len=40,
        ),
        "is_demo_sync": False,
    }
    rows = rest.post("/rest/v1/bank_connections", payload)
    return (rows or [{}])[0]


def deactivate_connection(rest: Any, connection_id: str) -> dict[str, Any]:
    connection_id = safe_id(connection_id, "connection_id")
    rows = rest.patch(
        "/rest/v1/bank_connections",
        {"status": "inativa"},
        {"id": f"eq.{connection_id}"},
    )
    return (rows or [{}])[0]


def list_accounts(rest: Any, connection_id: str | None = None) -> list[dict[str, Any]]:
    params: dict[str, Any] = {
        "select": "id,connection_id,pluggy_account_id,nome,tipo,currency,balance,updated_at",
        "order": "nome.asc",
    }
    if connection_id:
        params["connection_id"] = f"eq.{safe_id(connection_id, 'connection_id')}"
    rows = rest.get("/rest/v1/bank_accounts", params)
    return list(rows or [])


def list_bank_transactions(
    rest: Any,
    *,
    connection_id: str | None = None,
    status: str | None = None,
    mes: Any = None,
    limit: int = 100,
    offset: int = 0,
) -> tuple[list[dict[str, Any]], int]:
    filters: dict[str, Any] = {
        "select": (
            "id,bank_connection_id,bank_account_id,pluggy_transaction_id,data,valor,"
            "descricao,tipo,categoria_bancaria,status,transaction_id,"
            "sincronizado_em,is_demo_sync"
        ),
        "order": "data.desc,sincronizado_em.desc",
        "limit": str(limit),
        "offset": str(offset),
    }
    if connection_id:
        filters["bank_connection_id"] = f"eq.{safe_id(connection_id, 'connection_id')}"
    if status:
        filters["status"] = f"eq.{one_of(status, ('pendente_importacao', 'importada', 'ignorada', 'reconciliada'), 'status')}"
    if mes:
        start = month_start(mes)
        end = month_end_exclusive(start)
        filters["and"] = f"(data.gte.{start.isoformat()},data.lt.{end.isoformat()})"
    rows, total = rest.get("/rest/v1/bank_transactions", filters, count=True)
    if total is None:
        count_filters = {
            key: value for key, value in filters.items() if key not in ("select", "order", "limit", "offset")
        }
        count_filters["select"] = "id"
        count_rows = rest.get("/rest/v1/bank_transactions", count_filters) or []
        total = len(count_rows)
    return list(rows or []), total


def pagination(value: Any, field: str, default: int, maximum: int = 500) -> int:
    return parse_int(value, field, default=default, minimum=0, maximum=maximum)
