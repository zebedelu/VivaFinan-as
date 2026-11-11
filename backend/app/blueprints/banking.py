"""Extrato bancário, importação, reconciliação e sync Pluggy."""

from __future__ import annotations

from flask import Blueprint, current_app, g, jsonify, request

from ..auth import require_profile, rest
from ..errors import ApiError
from ..models.banking import (
    create_connection,
    deactivate_connection,
    get_connection,
    list_accounts,
    list_bank_transactions,
    list_connections,
    pagination,
)
from ..services.pluggy import (
    build_adapter,
    candidates,
    import_bank_transaction,
    pluggy_configured,
    reconcile,
    set_status,
    sync_connection,
)
from ..schemas.banking import (
    validate_connection_create,
    validate_connect_token,
    validate_import,
    validate_reconcile,
)
from ..utils import body, clean_text, safe_id

bp = Blueprint("banking", __name__, url_prefix="/api")


@bp.get("/banking/connections")
@require_profile
def get_connections():
    return jsonify({"connections": list_connections(rest())})


@bp.post("/banking/connections")
@require_profile
def post_connection():
    data = validate_connection_create(body())
    if not pluggy_configured(current_app.config):
        raise ApiError(
            503,
            "unavailable",
            "Conexão bancária indisponível: configure PLUGGY_CLIENT_ID/PLUGGY_CLIENT_SECRET.",
        )
    item_id = safe_id(data.get("pluggy_connection_id"), "pluggy_connection_id", max_len=200)
    item = build_adapter(current_app.config).get_item(item_id)
    owner = str((item or {}).get("clientUserId") or "").strip()
    if owner != str(g.user["id"]):
        raise ApiError(403, "forbidden", "Esta conexão Pluggy pertence a outro usuário.")
    row = create_connection(rest(), g.profile, str(g.user["id"]), data, item)
    return jsonify({"connection": row}), 201


@bp.post("/banking/connect_token")
@require_profile
def post_connect_token():
    """Token do widget Pluggy; o ``clientUserId`` sai do JWT, nunca do body."""
    validate_connect_token(body())
    if not pluggy_configured(current_app.config):
        raise ApiError(
            503,
            "pluggy_not_configured",
            "Pluggy indisponível: configure PLUGGY_CLIENT_ID/PLUGGY_CLIENT_SECRET.",
        )
    user_id = str(g.user["id"])
    token = build_adapter(current_app.config).create_connect_token(user_id)
    return jsonify({"accessToken": token, "clientUserId": user_id})


@bp.delete("/banking/connections/<connection_id>")
@require_profile
def remove_connection(connection_id: str):
    client = rest()
    connection = get_connection(client, connection_id)
    if connection.get("is_demo_sync"):
        raise ApiError(
            403,
            "forbidden",
            "Conexão de demonstração é somente leitura e não pode ser desconectada.",
        )
    if pluggy_configured(current_app.config):
        adapter = build_adapter(current_app.config)
        adapter.delete_connection(str(connection["pluggy_connection_id"]))
    row = deactivate_connection(client, connection_id)
    return jsonify({"ok": True, "connection": row})


@bp.get("/banking/accounts")
@require_profile
def get_accounts():
    connection_id = clean_text(request.args.get("connection_id"), "connection_id", max_len=64)
    return jsonify({"accounts": list_accounts(rest(), connection_id)})


@bp.get("/banking/transactions")
@require_profile
def get_bank_transactions():
    rows, total = list_bank_transactions(
        rest(),
        connection_id=clean_text(request.args.get("connection_id"), "connection_id", max_len=64),
        status=request.args.get("status"),
        mes=request.args.get("mes"),
        limit=pagination(request.args.get("limit"), "limit", 100),
        offset=pagination(request.args.get("offset"), "offset", 0, maximum=100000),
    )
    return jsonify({"items": rows, "total": total})


@bp.post("/banking/sync")
@require_profile
def sync():
    connection_id = clean_text(body().get("connection_id"), "connection_id", required=True, max_len=64)
    connection = get_connection(rest(), connection_id)
    return jsonify(sync_connection(rest(), current_app.config, connection))


@bp.post("/banking/import")
@require_profile
def import_transaction():
    row = import_bank_transaction(
        rest(),
        g.profile,
        str(g.user["id"]),
        validate_import(body()),
    )
    return jsonify({"transaction": row}), 201


@bp.get("/banking/reconcile-candidates")
@require_profile
def reconcile_candidates():
    bank_transaction_id = clean_text(
        request.args.get("bank_transaction_id"),
        "bank_transaction_id",
        required=True,
        max_len=64,
    )
    return jsonify({"candidates": candidates(rest(), bank_transaction_id)})


@bp.post("/banking/reconcile")
@require_profile
def reconcile_transaction():
    row = reconcile(rest(), validate_reconcile(body()))
    return jsonify({"transaction": row})


def _status(body_data, target: str):
    bank_transaction_id = clean_text(
        body_data.get("bank_transaction_id"),
        "bank_transaction_id",
        required=True,
        max_len=64,
    )
    row = set_status(rest(), bank_transaction_id, target)
    return jsonify({"ok": True, "bank_transaction": row})


@bp.post("/banking/ignore")
@require_profile
def ignore_transaction():
    return _status(body(), "ignorada")


@bp.post("/banking/unignore")
@require_profile
def unignore_transaction():
    return _status(body(), "pendente_importacao")
