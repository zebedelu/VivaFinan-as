"""Identidade, onboarding e convites do usuário."""

from __future__ import annotations

import uuid

from flask import Blueprint, g, jsonify

from ..auth import require_auth, require_profile, rest
from ..errors import validation
from ..models.profiles import me_payload, update_profile
from ..utils import body, clean_text, reject_keys

bp = Blueprint("me", __name__, url_prefix="/api")

INVITE_SELECT = (
    "id,family_id,family_nome,email,nome,papel,status,token,criado_por,criado_em,aceito_em"
)


@bp.get("/me")
@require_auth
def get_me():
    return jsonify(me_payload(rest(), g.user))


@bp.patch("/me")
@require_profile
def patch_me():
    data = body()
    reject_keys(data, ("id", "family_id", "member_id", "papel", "status"))
    row = update_profile(rest(), str(g.profile["id"]), data)
    return jsonify({"profile": row})


@bp.post("/onboarding")
@require_auth
def onboarding():
    data = body()
    nome_familia = clean_text(
        data.get("nome_familia"),
        "nome_familia",
        required=True,
        max_len=80,
    )
    nome = clean_text(data.get("nome"), "nome", required=True, max_len=80)
    rest().rpc("onboard_family", {"p_nome_familia": nome_familia, "p_nome": nome})
    return jsonify(me_payload(rest(), g.user))


@bp.get("/invites/mine")
@require_auth
def invite_mine():
    email = g.user.get("email")
    if not email:
        return jsonify(None)
    rows = rest().get(
        "/rest/v1/invites",
        {
            "select": INVITE_SELECT,
            "email": f"eq.{email}",
            "status": "eq.pendente",
            "order": "criado_em.desc",
            "limit": "1",
        },
    )
    if not rows:
        return jsonify(None)
    row = dict(rows[0])
    row["invite_id"] = row.get("id")
    return jsonify(row)


@bp.post("/invites/accept")
@require_auth
def accept_invite():
    data = body()
    raw_token = clean_text(data.get("token"), "token", required=True, max_len=64)
    try:
        token = str(uuid.UUID(str(raw_token)))
    except (ValueError, AttributeError, TypeError) as exc:
        raise validation("token inválido.") from exc
    nome = clean_text(data.get("nome"), "nome", max_len=80)
    rest().rpc("accept_invite", {"p_token": token, "p_nome": nome})
    return jsonify(me_payload(rest(), g.user))
