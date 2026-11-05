"""Agregações simples usadas por alertas, resumo e contexto da IA."""

from __future__ import annotations

from collections import defaultdict
from typing import Any, Iterable, Mapping

from ..utils import num


def category_names(rest: Any) -> dict[str, str]:
    rows = rest.get("/rest/v1/categories", {"select": "id,nome", "order": "nome.asc"})
    return {
        str(item["id"]): item.get("nome") or ""
        for item in (rows or [])
        if isinstance(item, Mapping) and item.get("id")
    }


def category_breakdown(
    transactions: Iterable[Mapping[str, Any]],
    names: Mapping[str, str],
    *,
    tipo: str | None = "despesa",
    escopo: str | None = None,
) -> list[dict[str, Any]]:
    totals: dict[str, float] = defaultdict(float)
    for item in transactions:
        if tipo and item.get("tipo") != tipo:
            continue
        if escopo and item.get("escopo") != escopo:
            continue
        key = str(item.get("category_id") or "")
        totals[key] += num(item.get("valor"))
    result = [
        {
            "category_id": key or None,
            "categoria": names.get(key, "Outros"),
            "total": round(total, 2),
        }
        for key, total in totals.items()
    ]
    result.sort(key=lambda item: item["total"], reverse=True)
    return result


def media_by_category(
    transactions: Iterable[Mapping[str, Any]],
    names: Mapping[str, str],
    months: int = 3,
    *,
    tipo: str = "despesa",
) -> dict[str, float]:
    totals: dict[str, float] = defaultdict(float)
    for item in transactions:
        if item.get("tipo") != tipo:
            continue
        key = str(item.get("category_id") or "")
        totals[key] += num(item.get("valor"))
    divisor = max(months, 1)
    result: dict[str, float] = {}
    for key, total in totals.items():
        label = names.get(key)
        if label:
            result[label] = round(total / divisor, 2)
    return result


def totals(transactions: Iterable[Mapping[str, Any]]) -> dict[str, float]:
    receitas = sum(num(item.get("valor")) for item in transactions if item.get("tipo") == "receita")
    despesas = sum(num(item.get("valor")) for item in transactions if item.get("tipo") == "despesa")
    return {
        "receitas": round(receitas, 2),
        "despesas": round(despesas, 2),
        "saldo": round(receitas - despesas, 2),
    }
