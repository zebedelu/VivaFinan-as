"""Restauração da família demo."""

from __future__ import annotations

from flask import Blueprint, current_app, g, jsonify

from ..auth import require_profile
from ..errors import forbidden
from ..services.demo_restore import restore

bp = Blueprint("demo", __name__, url_prefix="/api")


@bp.post("/demo/restore")
@require_profile
def restore_demo():
    demo_family = str(current_app.config.get("DEMO_FAMILY_ID") or "")
    if not demo_family or str(g.profile.get("family_id")) != demo_family:
        raise forbidden("Somente membros da família de demonstração podem restaurar.")
    return jsonify(restore(current_app.config))
