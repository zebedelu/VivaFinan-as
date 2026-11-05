"""Previsão: RPC familiar e cálculo pessoal no backend."""

from __future__ import annotations

from collections import defaultdict
from typing import Any, Mapping

from ..utils import add_months, current_month, num
from .analytics import category_names


def _saldo(row: Mapping[str, Any]) -> dict[str, Any]:
    receitas = num(row.get("receitas"))
    despesas = num(row.get("despesas"))
    return {
        "mes": row.get("mes"),
        "receitas": round(receitas, 2),
        "despesas": round(despesas, 2),
        "saldo": round(receitas - despesas, 2),
        "recorrentes_receitas": round(num(row.get("recorrentes_receitas")), 2),
        "recorrentes_despesas": round(num(row.get("recorrentes_despesas")), 2),
        "variavel_receitas": round(num(row.get("variavel_receitas")), 2),
        "variavel_despesas": round(num(row.get("variavel_despesas")), 2),
    }


def _annual(months: list[Mapping[str, Any]]) -> dict[str, float]:
    return {
        "receitas": round(sum(num(row.get("receitas")) for row in months), 2),
        "despesas": round(sum(num(row.get("despesas")) for row in months), 2),
        "saldo": round(sum(num(row.get("saldo")) for row in months), 2),
    }


def family_forecast(rest: Any, family_id: str, meses: int = 12) -> dict[str, Any]:
    inicio = add_months(current_month(), 1)
    rows = rest.rpc(
        "family_forecast",
        {"p_family_id": family_id, "p_mes_inicio": inicio.isoformat()},
    )
    months = [_saldo(row) for row in (rows or [])][:meses]
    return {"meses": months, "anual": _annual(months)}


def _range(field: str, start: str, end: str) -> dict[str, str]:
    return {"and": f"({field}.gte.{start},{field}.lt.{end})"}


def personal_forecast(rest: Any, member_id: str, meses: int = 12) -> dict[str, Any]:
    inicio = add_months(current_month(), 1)
    inicio_iso = inicio.isoformat()
    window_start = add_months(inicio, -6).isoformat()
    var_start = add_months(inicio, -4).isoformat()
    var_end = add_months(inicio, -1).isoformat()

    rules = rest.get(
        "/rest/v1/recurring_rules",
        {
            "select": "*",
            "ativo": "eq.true",
            "escopo": "eq.pessoal",
            "criado_por": f"eq.{member_id}",
        },
    )
    rules = [rule for rule in (rules or []) if isinstance(rule, Mapping)]
    rule_ids = [str(rule["id"]) for rule in rules if rule.get("id")]

    occurrences: list[Mapping[str, Any]] = []
    if rule_ids:
        occurrences = rest.get(
            "/rest/v1/recurring_occurrences",
            {
                "select": "*",
                "rule_id": f"in.({','.join(rule_ids)})",
                "status": "eq.confirmado",
                ** _range("mes_referencia", window_start, inicio_iso),
            },
        ) or []

    last_value: dict[str, tuple[float, str, str]] = {}
    confirmed: set[str] = set()
    for occurrence in occurrences:
        rule_id = str(occurrence.get("rule_id") or "")
        if not rule_id:
            continue
        confirmed.add(rule_id)
        value = occurrence.get("valor_confirmado")
        if value is None:
            continue
        key = (
            str(occurrence.get("mes_referencia") or ""),
            str(occurrence.get("confirmado_em") or ""),
        )
        current = last_value.get(rule_id)
        if current is None or key > (current[1], current[2]):
            last_value[rule_id] = (num(value), key[0], key[1])

    projected_rules: list[dict[str, Any]] = []
    recurring_receitas = 0.0
    recurring_despesas = 0.0
    for rule in rules:
        rule_id = str(rule.get("id"))
        if rule_id not in confirmed:
            continue
        value = last_value.get(rule_id, (num(rule.get("valor")), "", ""))[0]
        tipo = rule.get("tipo")
        if tipo == "receita":
            recurring_receitas += value
        else:
            recurring_despesas += value
        projected_rules.append(
            {
                "tipo": tipo,
                "descricao": rule.get("descricao"),
                "valor": round(value, 2),
                "origem": "recorrente",
            }
        )

    variable_rows = rest.get(
        "/rest/v1/transactions",
        {
            "select": "tipo,valor,category_id",
            "member_id": f"eq.{member_id}",
            "escopo": "eq.pessoal",
            "recurring_rule_id": "is.null",
            ** _range("data", var_start, var_end),
        },
    ) or []
    variavel_receitas = 0.0
    variavel_despesas = 0.0
    variable_by_category: dict[tuple[str, str], float] = defaultdict(float)
    for item in variable_rows:
        if item.get("tipo") == "receita":
            variavel_receitas += num(item.get("valor"))
        elif item.get("tipo") == "despesa":
            variavel_despesas += num(item.get("valor"))
        else:
            continue
        variable_by_category[(str(item.get("tipo")), str(item.get("category_id") or ""))] += num(
            item.get("valor")
        )
    variavel_receitas = round(variavel_receitas / 3.0, 2)
    variavel_despesas = round(variavel_despesas / 3.0, 2)

    detalhes = list(projected_rules)
    names = category_names(rest)
    for (tipo, category_id), total in variable_by_category.items():
        detalhes.append(
            {
                "tipo": tipo,
                "descricao": names.get(category_id, "Outros"),
                "valor": round(total / 3.0, 2),
                "origem": "media_3m",
            }
        )

    months: list[dict[str, Any]] = []
    for offset in range(12):
        mes = add_months(inicio, offset)
        receitas = recurring_receitas + variavel_receitas
        despesas = recurring_despesas + variavel_despesas
        months.append(
            {
                "mes": mes.isoformat(),
                "receitas": round(receitas, 2),
                "despesas": round(despesas, 2),
                "saldo": round(receitas - despesas, 2),
                "recorrentes_receitas": round(recurring_receitas, 2),
                "recorrentes_despesas": round(recurring_despesas, 2),
                "variavel_receitas": variavel_receitas,
                "variavel_despesas": variavel_despesas,
                "detalhes": detalhes,
            }
        )
    months = months[:meses]
    return {"meses": months, "anual": _annual(months)}


def forecast(rest: Any, profile: Mapping[str, Any], escopo: str, meses: int = 12) -> dict[str, Any]:
    if escopo == "pessoal":
        return personal_forecast(rest, str(profile["id"]), meses)
    return family_forecast(rest, str(profile["family_id"]), meses)


__all__ = ["family_forecast", "personal_forecast", "forecast"]
