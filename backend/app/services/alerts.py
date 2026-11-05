"""Alertas calculados em memória (sem persistência)."""

from __future__ import annotations

from typing import Any, Iterable, Mapping

from ..utils import num

JANELA_DIAS = 3
LIMITE_CATEGORIA = 0.20


def _conta_a_vencer(pending: Iterable[Mapping[str, Any]]) -> list[dict[str, Any]]:
    alerts: list[dict[str, Any]] = []
    for item in pending:
        dias = int(item.get("dias_para_vencimento") or 0)
        if dias > JANELA_DIAS:
            continue
        descricao = item.get("descricao") or "Conta recorrente"
        if dias < 0:
            atraso = abs(dias)
            alerts.append(
                {
                    "tipo": "conta_atrasada",
                    "titulo": f"{descricao} está {atraso} dia{'s' if atraso != 1 else ''} atrasada",
                    "detalhe": "Confirme ou ignore para fechar o mês.",
                    "escopo": item.get("escopo") or "familia",
                }
            )
        elif dias == 0:
            alerts.append(
                {
                    "tipo": "conta_a_vencer",
                    "titulo": f"{descricao} vence hoje",
                    "detalhe": "Confirme para entrar no mês.",
                    "escopo": item.get("escopo") or "familia",
                }
            )
        else:
            alerts.append(
                {
                    "tipo": "conta_a_vencer",
                    "titulo": f"{descricao} vence em {dias} dia{'s' if dias != 1 else ''}",
                    "detalhe": "Confirme para entrar no mês.",
                    "escopo": item.get("escopo") or "familia",
                }
            )
    return alerts


def _categorias(fora_da_media: Iterable[Mapping[str, Any]]) -> list[dict[str, Any]]:
    alerts: list[dict[str, Any]] = []
    for item in fora_da_media:
        nome = item.get("categoria") or "Categoria"
        media = num(item.get("media_3m"))
        total = num(item.get("total"))
        if media <= 0 or total <= media * (1 + LIMITE_CATEGORIA):
            continue
        pct = int(round((total / media - 1) * 100))
        alerts.append(
            {
                "tipo": "categoria_acima_da_media",
                "titulo": f"{nome} está {pct}% acima da média",
                "detalhe": "Compare com os três meses anteriores antes de cortar.",
                "escopo": item.get("escopo") or "familia",
            }
        )
    return alerts


def _metas(goals: Iterable[Mapping[str, Any]]) -> list[dict[str, Any]]:
    alerts: list[dict[str, Any]] = []
    for goal in goals:
        progresso = num(goal.get("progresso"))
        if goal.get("status") == "concluida" or progresso >= 100:
            alerts.append(
                {
                    "tipo": "meta_atingida",
                    "titulo": f"Meta {goal.get('titulo')} atingida",
                    "detalhe": "Vocês chegaram ao valor-alvo. Celebrem e escolham a próxima.",
                    "escopo": "pessoal" if goal.get("member_id") else "familia",
                }
            )
    return alerts


def _sync(connections: Iterable[Mapping[str, Any]]) -> list[dict[str, Any]]:
    alerts: list[dict[str, Any]] = []
    for connection in connections:
        if connection.get("status") == "erro_sincronizacao":
            alerts.append(
                {
                    "tipo": "sync_com_erro",
                    "titulo": "Uma conexão bancária precisa de atenção",
                    "detalhe": "A última sincronização falhou. Reconecte quando puder.",
                    "escopo": "pessoal",
                }
            )
        elif connection.get("status") == "expirada":
            alerts.append(
                {
                    "tipo": "conexao_expirada",
                    "titulo": "Conexão bancária expirada",
                    "detalhe": "Autorize o banco de novo para voltar a ver o extrato.",
                    "escopo": "pessoal",
                }
            )
    return alerts


def build_alerts(
    *,
    pending: Iterable[Mapping[str, Any]] = (),
    categorias: Iterable[Mapping[str, Any]] = (),
    metas: Iterable[Mapping[str, Any]] = (),
    connections: Iterable[Mapping[str, Any]] = (),
    escopo: str = "familia",
    member_id: str | None = None,
) -> list[dict[str, Any]]:
    alerts = (
        _conta_a_vencer(pending)
        + _categorias(categorias)
        + _metas(metas)
        + _sync(connections)
    )
    if escopo == "pessoal" and member_id:
        for alert in alerts:
            alert["escopo"] = "pessoal"
            alert["member_id"] = member_id
    else:
        for alert in alerts:
            alert["escopo"] = "familia"
    return alerts
