"""Painel familiar, resumo pessoal e alertas."""

from __future__ import annotations

from flask import Blueprint, g, jsonify, request

from ..auth import require_profile, rest
from ..services.panel import dashboard as build_dashboard
from ..services.panel import me_summary, personal_alerts
from ..utils import month_start
from .ai import ai_service

bp = Blueprint("family", __name__, url_prefix="/api")


@bp.get("/dashboard")
@require_profile
def dashboard():
    mes = month_start(request.args.get("mes"))
    return jsonify(
        build_dashboard(
            rest(),
            g.profile,
            str(g.user["id"]),
            ai_service(),
            mes,
        )
    )


@bp.get("/me/summary")
@require_profile
def summary():
    mes = month_start(request.args.get("mes"))
    return jsonify(
        me_summary(
            rest(),
            g.profile,
            str(g.user["id"]),
            ai_service(),
            mes,
        )
    )


@bp.get("/alerts")
@require_profile
def alerts():
    mes = month_start(request.args.get("mes"))
    return jsonify(
        {
            "alertas": personal_alerts(
                rest(),
                g.profile,
                str(g.user["id"]),
                mes,
            )
        }
    )
