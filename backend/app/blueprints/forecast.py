"""Previsão familiar (RPC) e pessoal (backend)."""

from __future__ import annotations

from flask import Blueprint, g, jsonify, request

from ..auth import require_profile, rest
from ..services.forecast import forecast
from ..utils import one_of, parse_int

bp = Blueprint("forecast", __name__, url_prefix="/api")


@bp.get("/forecast")
@require_profile
def get_forecast():
    escopo = one_of(request.args.get("escopo") or "familia", ("familia", "pessoal"), "escopo")
    meses = parse_int(request.args.get("meses"), "meses", default=12, minimum=1, maximum=12)
    return jsonify(forecast(rest(), g.profile, escopo, meses))
