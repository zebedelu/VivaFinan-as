"""Regras e ocorrências recorrentes."""

from __future__ import annotations

from flask import Blueprint, g, jsonify, request

from ..auth import require_profile, rest
from ..errors import ApiError, validation
from ..models.recurring import create_rule, ignore_occurrence, list_rules, update_rule
from ..schemas.recurring import validate_create, validate_patch
from ..services.recurring import materialize
from ..utils import body, month_start, opt_money

bp = Blueprint("recurring", __name__, url_prefix="/api")


@bp.get("/recurring/rules")
@require_profile
def get_rules():
    return jsonify({"rules": list_rules(rest(), request.args.get("escopo"))})


@bp.post("/recurring/rules")
@require_profile
def post_rule():
    row = create_rule(rest(), g.profile, str(g.user["id"]), validate_create(body()))
    return jsonify({"rule": row}), 201


@bp.patch("/recurring/rules/<rule_id>")
@require_profile
def patch_rule(rule_id: str):
    row = update_rule(rest(), rule_id, validate_patch(body()))
    return jsonify({"rule": row})


@bp.get("/recurring/pending")
@require_profile
def pending():
    mes = month_start(request.args.get("mes"))
    return jsonify({"items": materialize(rest(), mes)})


@bp.post("/recurring/occurrences/<occurrence_id>/confirm")
@require_profile
def confirm(occurrence_id: str):
    data = body()
    valor = opt_money(data.get("valor"))
    try:
        transaction_id = rest().rpc(
            "confirm_occurrence",
            {"p_occurrence_id": occurrence_id, "p_valor": valor},
        )
    except ApiError as exc:
        if exc.upstream_code == "42501" or exc.status == 403:
            raise ApiError(
                409,
                "conflict",
                "A ocorrência já foi decidida ou não está mais pendente.",
            ) from exc
        raise
    return jsonify({"ok": True, "transaction_id": transaction_id})


@bp.post("/recurring/occurrences/<occurrence_id>/ignore")
@require_profile
def ignore(occurrence_id: str):
    try:
        row = ignore_occurrence(rest(), occurrence_id)
    except ApiError as exc:
        if exc.status == 404:
            raise validation("Ocorrência pendente não encontrada.") from exc
        raise
    return jsonify({"ok": True, "occurrence": row})
