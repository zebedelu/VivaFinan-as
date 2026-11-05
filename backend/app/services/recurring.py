"""Materialização e leitura de ocorrências recorrentes pendentes."""

from __future__ import annotations

from typing import Any, Mapping

from ..utils import clamp_day, days_until, month_start

ESCOPO_FAMILIA = "familia"
ESCOPO_PESSOAL = "pessoal"


def _rule_map(rules: list[Mapping[str, Any]]) -> dict[str, Mapping[str, Any]]:
    return {str(rule["id"]): rule for rule in rules if rule.get("id")}


def materialize(rest: Any, mes: Any) -> list[dict[str, Any]]:
    """Cria (idempotente) e RELÊ as ocorrências pendentes do mês.

    Não confia no retorno do insert: só a releitura define a fila. Regras que
    já decidiram o mês não voltam; a unique ``(rule_id, mes_referencia)`` e o
    ``resolution=ignore-duplicates`` garantem a idempotência sem sobrescrever
    uma decisão anterior.
    """
    month = month_start(mes)
    rules = rest.get(
        "/rest/v1/recurring_rules",
        {"select": "*", "ativo": "eq.true", "order": "criado_em.asc"},
    )
    rules = rules if isinstance(rules, list) else []
    if rules:
        payload = [
            {
                "rule_id": rule["id"],
                "mes_referencia": month.isoformat(),
                "status": "pendente",
            }
            for rule in rules
            if rule.get("id")
        ]
        if payload:
            rest.post(
                "/rest/v1/recurring_occurrences",
                payload,
                {"on_conflict": "rule_id,mes_referencia", "select": "id"},
                prefer_extra="resolution=ignore-duplicates",
                allow_empty=True,
            )

    occurrences = rest.get(
        "/rest/v1/recurring_occurrences",
        {
            "mes_referencia": f"eq.{month.isoformat()}",
            "status": "eq.pendente",
            "select": "*",
        },
    )
    occurrences = occurrences if isinstance(occurrences, list) else []
    rules_by_id = _rule_map(rules)

    categories = rest.get(
        "/rest/v1/categories",
        {"select": "id,nome", "order": "nome.asc"},
    )
    category_names = {
        str(item["id"]): item.get("nome")
        for item in (categories or [])
        if isinstance(item, Mapping) and item.get("id")
    }

    items: list[dict[str, Any]] = []
    for occurrence in occurrences:
        rule = rules_by_id.get(str(occurrence.get("rule_id")))
        if not rule:
            continue
        due = clamp_day(
            month.year,
            month.month,
            int(rule.get("dia_vencimento") or 1),
        )
        items.append(
            {
                "occurrence_id": occurrence.get("id"),
                "rule_id": rule.get("id"),
                "tipo": rule.get("tipo"),
                "escopo": rule.get("escopo"),
                "valor": rule.get("valor"),
                "descricao": rule.get("descricao"),
                "category_id": rule.get("category_id"),
                "categoria": category_names.get(str(rule.get("category_id"))),
                "data_vencimento": due.isoformat(),
                "dias_para_vencimento": days_until(due),
            }
        )
    items.sort(key=lambda item: (item["data_vencimento"], item["descricao"] or ""))
    return items


def filter_scope(items: list[Mapping[str, Any]], escopo: str | None) -> list[Mapping[str, Any]]:
    if escopo not in (ESCOPO_FAMILIA, ESCOPO_PESSOAL):
        return list(items)
    return [item for item in items if item.get("escopo") == escopo]
