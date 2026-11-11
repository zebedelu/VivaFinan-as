"""Admin da família, convites e categorias."""

from __future__ import annotations

import re
import uuid

from flask import Blueprint, current_app, g, jsonify

from ..auth import require_admin, require_profile, rest
from ..errors import validation
from ..models.categories import (
    create_category,
    delete_category,
    list_categories,
    update_category,
)
from ..models.profiles import get_family, list_members, update_member
from ..schemas.admin import validate_category, validate_invite, validate_member_patch
from ..supabase import AdminClient
from ..utils import body, clean_text, safe_id

bp = Blueprint("admin", __name__, url_prefix="/api")

EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
INVITE_SELECT = (
    "id,family_id,family_nome,email,nome,papel,status,token,criado_por,criado_em,aceito_em"
)


@bp.get("/admin/members")
@require_admin
def members():
    return jsonify({"members": list_members(rest(), g.profile)})


@bp.patch("/admin/members/<member_id>")
@require_admin
def patch_member(member_id: str):
    data = validate_member_patch(body())
    row = update_member(rest(), str(g.user["id"]), safe_id(member_id, "member_id"), data)
    return jsonify({"member": row})


@bp.get("/admin/invites")
@require_admin
def invites():
    rows = rest().get(
        "/rest/v1/invites",
        {
            "select": INVITE_SELECT,
            "family_id": f"eq.{g.profile['family_id']}",
            "status": "eq.pendente",
            "order": "criado_em.desc",
        },
    )
    return jsonify({"invites": rows or []})


@bp.post("/admin/invites")
@require_admin
def create_invite():
    data = validate_invite(body())
    email = clean_text(data.get("email"), "email", required=True, max_len=254)
    email = str(email).lower()
    if not EMAIL_RE.match(email):
        raise validation("E-mail inválido.")
    nome = clean_text(data.get("nome"), "nome", max_len=80) or email.split("@", 1)[0][:80]
    admin = AdminClient.from_config(current_app.config)
    client = rest()
    family = get_family(client, str(g.profile["family_id"])) or {}
    # O token nasce antes do convite para o e-mail já apontar para /invite/<token>.
    token = str(uuid.uuid4())
    redirect_to = f"{current_app.config['PUBLIC_SITE_URL']}/invite/{token}"
    invited = admin.invite_user(email, {"nome": nome}, redirect_to=redirect_to)
    payload = {
        "family_id": g.profile["family_id"],
        "family_nome": family.get("nome") or "Família",
        "email": email,
        "nome": nome,
        "papel": "membro",
        "status": "pendente",
        "token": token,
        "criado_por": g.user["id"],
        "auth_user_id": invited.get("id"),
    }
    try:
        rows = client.post("/rest/v1/invites", payload)
    except Exception:
        invited_id = invited.get("id")
        if invited_id:
            try:
                admin.delete_user(str(invited_id))
            except Exception:
                pass
        raise
    row = (rows or [{}])[0]
    return jsonify(
        {
            "invite_id": row.get("id"),
            "token": row.get("token"),
            "email": row.get("email", email),
        }
    ), 201


@bp.delete("/admin/invites/<invite_id>")
@require_admin
def cancel_invite(invite_id: str):
    invite_id = safe_id(invite_id, "invite_id")
    client = rest()
    cancelled = client.patch(
        "/rest/v1/invites",
        {"status": "cancelado"},
        {
            "id": f"eq.{invite_id}",
            "family_id": f"eq.{g.profile['family_id']}",
            "status": "eq.pendente",
            "select": f"{INVITE_SELECT},auth_user_id",
        },
    )
    row = (cancelled or [{}])[0]
    auth_user_id = row.get("auth_user_id")
    if auth_user_id:
        try:
            AdminClient.from_config(current_app.config).delete_user(str(auth_user_id))
        except Exception:
            current_app.logger.warning(
                "Convite %s cancelado, mas o usuário Auth %s não foi apagado.",
                invite_id,
                auth_user_id,
            )
    return jsonify({"ok": True, "invite": row})


@bp.get("/categories")
@require_profile
def get_categories():
    return jsonify({"categories": list_categories(rest())})


@bp.post("/categories")
@require_profile
def post_category():
    data = validate_category(body())
    row = create_category(rest(), g.profile, str(g.user["id"]), data)
    return jsonify({"category": row}), 201


@bp.patch("/categories/<category_id>")
@require_profile
def patch_category(category_id: str):
    row = update_category(rest(), category_id, validate_category(body()))
    return jsonify({"category": row})


@bp.delete("/categories/<category_id>")
@require_profile
def remove_category(category_id: str):
    delete_category(rest(), category_id)
    return jsonify({"ok": True})
