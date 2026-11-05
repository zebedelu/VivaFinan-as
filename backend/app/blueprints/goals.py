"""Metas e contribuições."""

from __future__ import annotations

from flask import Blueprint, g, jsonify, request

from ..auth import require_profile, rest
from ..models.common import member_directory, member_names
from ..models.goals import (
    create_contribution,
    create_goal,
    delete_goal,
    list_contributions,
    list_goals,
    update_goal,
)
from ..schemas.goals import validate_contribution, validate_create, validate_patch
from ..utils import body, one_of

bp = Blueprint("goals", __name__, url_prefix="/api")


def _members() -> dict[str, str]:
    return member_names(member_directory(rest(), g.profile))


@bp.get("/goals")
@require_profile
def get_goals():
    escopo = one_of(request.args.get("escopo") or "familia", ("familia", "pessoal"), "escopo")
    return jsonify({"goals": list_goals(rest(), escopo, str(g.user["id"]), _members())})


@bp.post("/goals")
@require_profile
def post_goal():
    row = create_goal(rest(), g.profile, str(g.user["id"]), validate_create(body()))
    return jsonify({"goal": row}), 201


@bp.patch("/goals/<goal_id>")
@require_profile
def patch_goal(goal_id: str):
    row = update_goal(rest(), goal_id, validate_patch(body()), _members())
    return jsonify({"goal": row})


@bp.delete("/goals/<goal_id>")
@require_profile
def remove_goal(goal_id: str):
    delete_goal(rest(), goal_id)
    return jsonify({"ok": True})


@bp.get("/goals/<goal_id>/contributions")
@require_profile
def get_contributions(goal_id: str):
    return jsonify({"contributions": list_contributions(rest(), goal_id, _members())})


@bp.post("/goals/<goal_id>/contributions")
@require_profile
def post_contribution(goal_id: str):
    row = create_contribution(
        rest(),
        goal_id,
        str(g.user["id"]),
        validate_contribution(body()),
    )
    return jsonify({"contribution": row}), 201
