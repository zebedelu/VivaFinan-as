"""Sync Pluggy: valida o dono pelo JWT, escreve com service role, nunca cria lançamentos."""

from __future__ import annotations

import math
from datetime import datetime, timedelta
from typing import Any, Mapping

from ...errors import ApiError
from ...supabase import ServiceRest
from ...utils import now_sp, today_sp
from .adapter import account_tipo, build_adapter, pluggy_configured

SYNC_WINDOW_DAYS = 90
SYNC_OVERLAP_DAYS = 7


def _date_from(connection: Mapping[str, Any]) -> str:
    """Janela do ``dateFrom``: retoma da última sync com sobreposição de 7 dias."""
    last = str(connection.get("ultima_sync_em") or "").strip()
    if last:
        try:
            return (
                datetime.fromisoformat(last.replace("Z", "+00:00")).date()
                - timedelta(days=SYNC_OVERLAP_DAYS)
            ).isoformat()
        except ValueError:
            pass
    return (today_sp() - timedelta(days=SYNC_WINDOW_DAYS)).isoformat()


def sync_connection(
    rest: Any,
    config: Mapping[str, Any],
    connection: Mapping[str, Any],
) -> dict[str, Any]:
    if connection.get("is_demo_sync"):
        return {
            "ok": True,
            "demo": True,
            "accounts": 0,
            "transactions": 0,
            "message": "Conexão demo: nenhuma chamada externa.",
        }

    adapter = build_adapter(config)
    if not pluggy_configured(config):
        raise ApiError(
            503,
            "unavailable",
            "Sincronização indisponível: configure PLUGGY_CLIENT_ID/PLUGGY_CLIENT_SECRET no servidor.",
        )
    service = ServiceRest.from_config(config)

    accounts = adapter.list_accounts(str(connection["pluggy_connection_id"]))
    account_rows = [
        {
            "connection_id": connection["id"],
            "pluggy_account_id": str(account.get("id")),
            "nome": account.get("name") or "Conta",
            "tipo": account_tipo(account),
            "currency": "BRL",
            "balance": account.get("balance") or 0,
        }
        for account in accounts
        if account.get("id")
    ]
    saved_accounts: dict[str, str] = {}
    if account_rows:
        inserted = service.post(
            "/rest/v1/bank_accounts",
            account_rows,
            {"on_conflict": "connection_id,pluggy_account_id", "select": "id,pluggy_account_id"},
            prefer_extra="resolution=merge-duplicates",
            allow_empty=True,
        ) or []
        saved_accounts = {
            str(row.get("pluggy_account_id")): str(row.get("id"))
            for row in inserted
            if row.get("pluggy_account_id") and row.get("id")
        }

    transactions = 0
    date_from = _date_from(connection)
    for account in accounts:
        account_id = str(account.get("id") or "")
        db_account_id = saved_accounts.get(account_id)
        if not db_account_id:
            continue
        rows = []
        for item in adapter.list_transactions(account_id, date_from=date_from):
            amount = item.get("amount")
            if amount is None:
                continue
            try:
                value = float(amount)
            except (TypeError, ValueError):
                continue
            if not math.isfinite(value):
                continue
            tipo = "credito" if value >= 0 else "debito"
            rows.append(
                {
                    "bank_connection_id": connection["id"],
                    "bank_account_id": db_account_id,
                    "pluggy_transaction_id": str(item.get("id")),
                    "data": str(item.get("date"))[:10],
                    "valor": abs(round(value, 2)),
                    "descricao": item.get("description") or "Transação",
                    "tipo": tipo,
                    "categoria_bancaria": item.get("category"),
                    "status": "pendente_importacao",
                }
            )
        if not rows:
            continue
        inserted = service.post(
            "/rest/v1/bank_transactions",
            rows,
            {
                "on_conflict": "bank_connection_id,pluggy_transaction_id",
                "select": "id",
            },
            prefer_extra="resolution=ignore-duplicates",
            allow_empty=True,
        ) or []
        transactions += len(inserted)

    rest.patch(
        "/rest/v1/bank_connections",
        {"ultima_sync_em": now_sp().isoformat()},
        {"id": f"eq.{connection['id']}"},
    )
    return {
        "ok": True,
        "demo": False,
        "accounts": len(account_rows),
        "transactions": transactions,
    }
