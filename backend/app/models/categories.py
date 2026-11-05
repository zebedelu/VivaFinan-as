"""Categorias padrão e personalizadas."""

from __future__ import annotations

from typing import Any, Mapping

from ..errors import not_found, validation
from ..utils import TIPOS, clean_text, one_of, safe_id


def list_categories(rest: Any) -> list[dict[str, Any]]:
    rows = rest.get(
        "/rest/v1/categories",
        {
            "select": "id,family_id,nome,tipo,personalizada,oculta,criado_por,criado_em",
            "order": "tipo.asc,nome.asc",
        },
    )
    return list(rows or [])


def create_category(
    rest: Any,
    profile: Mapping[str, Any],
    user_id: str,
    data: Mapping[str, Any],
) -> dict[str, Any]:
    payload = {
        "family_id": profile["family_id"],
        "nome": clean_text(data.get("nome"), "nome", required=True, max_len=60),
        "tipo": one_of(data.get("tipo"), TIPOS, "tipo"),
        "personalizada": True,
        "oculta": bool(data.get("oculta", False)),
        "criado_por": user_id,
    }
    rows = rest.post("/rest/v1/categories", payload)
    return (rows or [{}])[0]


def update_category(rest: Any, category_id: str, data: Mapping[str, Any]) -> dict[str, Any]:
    category_id = safe_id(category_id, "category_id")
    current = rest.get(
        "/rest/v1/categories",
        {"id": f"eq.{category_id}", "select": "*", "limit": "1"},
    )
    if not current:
        raise not_found("Categoria não encontrada.")
    row = current[0]
    payload: dict[str, Any] = {}
    for field in ("nome", "tipo"):
        if field in data and not row.get("personalizada"):
            raise validation("Categoria padrão só pode ser ocultada.")
    if "nome" in data:
        payload["nome"] = clean_text(data.get("nome"), "nome", required=True, max_len=60)
    if "tipo" in data:
        payload["tipo"] = one_of(data.get("tipo"), TIPOS, "tipo")
    if "oculta" in data:
        payload["oculta"] = bool(data.get("oculta"))
    if not payload:
        raise validation("Nenhum campo editável informado.")
    rows = rest.patch(f"/rest/v1/categories?id=eq.{category_id}", payload)
    return (rows or [{}])[0]


def delete_category(rest: Any, category_id: str) -> None:
    category_id = safe_id(category_id, "category_id")
    rest.delete(f"/rest/v1/categories?id=eq.{category_id}")
