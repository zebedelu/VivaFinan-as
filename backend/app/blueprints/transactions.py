"""Lançamentos manuais (importação Pluggy só em /banking/import)."""

from __future__ import annotations

from flask import Blueprint, g, jsonify, request

from ..auth import require_profile, rest
from ..models.common import category_map, member_directory, member_names, transaction_payload
from ..models.transactions import (
    create_transaction,
    delete_transaction,
    list_transactions,
    update_transaction,
)
from ..schemas.transactions import validate_create, validate_patch
from ..utils import body, parse_int

bp = Blueprint("transactions", __name__, url_prefix="/api")


def _decorated(row):
    current = rest()
    names = category_map(current)
    members = member_names(member_directory(current, g.profile))
    return transaction_payload(row, names, members)


@bp.get("/transactions")
@require_profile
def list_items():
    rows, total = list_transactions(
        rest(),
        {
            "mes": request.args.get("mes"),
            "tipo": request.args.get("tipo"),
            "escopo": request.args.get("escopo"),
            "categoria": request.args.get("categoria"),
            "origem": request.args.get("origem"),
            "limit": parse_int(request.args.get("limit"), "limit", default=100, minimum=1, maximum=500),
            "offset": parse_int(request.args.get("offset"), "offset", default=0, minimum=0, maximum=100000),
        },
    )
    names = category_map(rest())
    members = member_names(member_directory(rest(), g.profile))
    return jsonify(
        {
            "items": [transaction_payload(row, names, members) for row in rows],
            "total": total,
        }
    )


@bp.post("/transactions")
@require_profile
def create_item():
    data = validate_create(body())
    row = create_transaction(rest(), g.profile, str(g.user["id"]), data)
    return jsonify({"transaction": _decorated(row)}), 201


@bp.patch("/transactions/<transaction_id>")
@require_profile
def patch_item(transaction_id: str):
    data = validate_patch(body())
    row = update_transaction(rest(), transaction_id, data)
    return jsonify({"transaction": _decorated(row)})


@bp.delete("/transactions/<transaction_id>")
@require_profile
def remove_item(transaction_id: str):
    delete_transaction(rest(), transaction_id)
    return jsonify({"ok": True})
