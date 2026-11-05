"""Fallback determinístico da Jev AI.

Sem rede e sem chave. Classifica por palavra-chave respeitando o tipo e monta
sugestões apenas com números que estão no :class:`AIContext`.
"""

from __future__ import annotations

import re
from typing import Any, Mapping, Sequence

from .base import (
    AIContext,
    AISuggestion,
    SEM_ESTIMATIVA,
    brl,
    default_categories,
    find_category,
    media_for,
    normalize_categories,
    normalize_text,
    normalize_tipo,
    to_float,
)

# Palavras já normalizadas (sem acento, minúsculas). Frases usam substring;
# palavras soltas usam token exato para evitar "bar" casar com "barbeiro".
_KEYWORDS: tuple[tuple[str, tuple[str, ...]], ...] = (
    (
        "Alimentação",
        (
            "supermercado",
            "mercado",
            "padaria",
            "restaurante",
            "ifood",
            "feira",
            "hortifruti",
            "acougue",
            "lanchonete",
            "cafe",
            "cafeteria",
        ),
    ),
    (
        "Moradia",
        ("aluguel", "condominio", "energia", "luz", "agua", "gas", "internet", "iptu", "faxina"),
    ),
    (
        "Transporte",
        (
            "uber",
            "99",
            "onibus",
            "combustivel",
            "gasolina",
            "etanol",
            "metro",
            "estacionamento",
            "pedagio",
            "passagem",
            "taxi",
        ),
    ),
    (
        "Saúde",
        (
            "farmacia",
            "medico",
            "consulta",
            "exame",
            "dentista",
            "plano de saude",
            "hospital",
            "terapia",
        ),
    ),
    ("Educação", ("escola", "curso", "faculdade", "livro", "mensalidade escolar", "material escolar")),
    ("Lazer", ("cinema", "show", "viagem", "jogo", "parque", "bar", "festa", "passeio")),
    (
        "Assinaturas",
        (
            "streaming",
            "assinatura",
            "netflix",
            "spotify",
            "disney",
            "prime video",
            "youtube premium",
            "academia",
            "icloud",
        ),
    ),
    ("Salário", ("salario", "holerite", "provento", "pagamento de salario")),
    ("Freelance", ("freelance", "freela", "pix recebido", "servico prestado")),
    (
        "Investimentos",
        ("investimento", "dividendo", "rendimento", "cdb", "tesouro", "acao", "fundo"),
    ),
)

_STATUS_ENCERRADOS = {"concluida", "concluido", "cancelada", "cancelado", "encerrada", "encerrado"}

_SAVINGS_WORDS = (
    "economizar",
    "economia",
    "poupar",
    "poupanca",
    "guardar",
    "sobra",
    "reserva",
    "investir",
)


def _tokens(text: str) -> set[str]:
    return set(re.findall(r"[a-z0-9]+", text))


def _keyword_match(text: str, tokens: set[str], keyword: str) -> bool:
    if " " in keyword:
        return keyword in text
    # Plural simples: dividendo/dividendos, assinatura/assinaturas.
    return any(
        token in (keyword, f"{keyword}s", f"{keyword}es") for token in tokens
    )


def _coerce_context(context: Any) -> AIContext:
    if isinstance(context, AIContext):
        return context
    if isinstance(context, Mapping):
        return AIContext(**context)
    return AIContext()


def _present(mapping: Mapping[str, Any], key: str) -> bool:
    return key in mapping and mapping[key] is not None


def _progress_pct(meta: Mapping[str, Any]) -> float | None:
    alvo = to_float(meta.get("valor_alvo"))
    atual = meta.get("valor_atual", meta.get("contribuido"))
    if atual is not None and alvo > 0:
        return max(0.0, min(100.0, to_float(atual) / alvo * 100.0))
    progresso = meta.get("progresso")
    if progresso is None:
        return None
    pct = to_float(progresso)
    if 0 < pct <= 1:
        pct *= 100.0
    return max(0.0, min(100.0, pct))


def _gap(meta: Mapping[str, Any]) -> float | None:
    alvo = to_float(meta.get("valor_alvo"))
    if alvo <= 0:
        return None
    atual = meta.get("valor_atual", meta.get("contribuido"))
    if atual is not None:
        return max(0.0, alvo - to_float(atual))
    pct = _progress_pct(meta)
    if pct is None:
        return None
    return max(0.0, alvo * (1.0 - pct / 100.0))


def _dias(meta: Mapping[str, Any]) -> float | None:
    value = meta.get("dias_para_prazo")
    if value is None:
        return None
    return to_float(value)


def _despesa_categories(context: AIContext) -> list[dict[str, Any]]:
    result = []
    for item in context.categorias:
        tipo = normalize_tipo(item.get("tipo"))
        total = to_float(item.get("total"))
        name = item.get("categoria", item.get("nome"))
        if not name or total <= 0:
            continue
        if tipo not in (None, "despesa"):
            continue
        result.append({"categoria": str(name), "total": total, "tipo": tipo})
    return result


class FallbackLLMAdapter:
    """Adaptador local, determinístico e sem rede."""

    mode = "fallback"

    # -- classificação -----------------------------------------------------

    def classify(
        self,
        descricao: str,
        tipo: str,
        categorias: Sequence[Mapping[str, Any] | str] | None = None,
    ) -> dict[str, Any]:
        tipo_norm = normalize_tipo(tipo)
        cats = normalize_categories(categorias) or default_categories()
        if tipo_norm:
            cats = [item for item in cats if item["tipo"] in (None, tipo_norm)]

        text = normalize_text(descricao)
        tokens = _tokens(text)
        for nome, keywords in _KEYWORDS:
            if any(_keyword_match(text, tokens, keyword) for keyword in keywords):
                found = find_category(cats, nome)
                if found is not None:
                    return {"categoria_id": found.get("id"), "categoria": found.get("nome")}

        # Sem palavra-chave o contrato manda categoria nula; não inventa "Outros".
        return {"categoria_id": None, "categoria": None}

    # -- sugestões ---------------------------------------------------------

    def suggest(self, context: AIContext) -> list[AISuggestion]:
        ctx = _coerce_context(context)
        suggestions: list[AISuggestion] = []

        goal = self._goal_suggestion(ctx)
        if goal is not None:
            suggestions.append(goal)
        subscription = self._subscription_suggestion(ctx)
        if subscription is not None:
            suggestions.append(subscription)
        category = self._category_suggestion(ctx)
        if category is not None:
            suggestions.append(category)
        bank = self._bank_suggestion(ctx)
        if bank is not None:
            suggestions.append(bank)

        if not suggestions:
            budget = self._budget_suggestion(ctx)
            if budget is not None:
                suggestions.append(budget)

        if not suggestions:
            suggestions.append(self._empty_suggestion(ctx))

        return suggestions[:4]

    def _goal_suggestion(self, context: AIContext) -> AISuggestion | None:
        candidates: list[tuple[float, dict[str, Any], float]] = []
        for meta in context.metas:
            status = normalize_text(meta.get("status"))
            if status in _STATUS_ENCERRADOS:
                continue
            pct = _progress_pct(meta)
            dias = _dias(meta)
            if pct is None or pct >= 50 or dias is None or dias > 45:
                continue
            candidates.append((dias, meta, pct))
        if not candidates:
            return None

        dias, meta, pct = min(candidates, key=lambda item: item[0])
        titulo_meta = str(meta.get("titulo") or "meta")
        gap = _gap(meta)
        quanto = brl(gap) if gap is not None and gap > 0 else SEM_ESTIMATIVA
        if dias < 0:
            prazo = f"O prazo venceu há {abs(int(dias))} dia(s) e a meta está em {pct:.0f}%."
        elif dias == 0:
            prazo = f"O prazo vence hoje e a meta está em {pct:.0f}%."
        else:
            prazo = f"A meta está em {pct:.0f}% e o prazo vence em {int(dias)} dia(s)."
        return AISuggestion(
            tipo="meta",
            titulo=f'Aporte na meta "{titulo_meta}"',
            o_que=f'Separar um valor para a meta "{titulo_meta}" antes do prazo.',
            por_que=prazo,
            quanto=quanto,
        )

    def _subscription_suggestion(self, context: AIContext) -> AISuggestion | None:
        assinaturas = next(
            (item for item in _despesa_categories(context) if normalize_text(item["categoria"]) == "assinaturas"),
            None,
        )
        if assinaturas is None:
            return None
        total = assinaturas["total"]
        media = media_for(context.media_3m, "Assinaturas")
        detail = f"As assinaturas somam {brl(total)} neste mês"
        if media is not None and media > 0 and total > media:
            detail += f", acima da média de {brl(media)} dos últimos 3 meses"
        detail += "."
        return AISuggestion(
            tipo="assinaturas",
            titulo="Revisar assinaturas",
            o_que="Revisar as assinaturas ativas e cancelar o que não usa.",
            por_que=detail,
            quanto=brl(total),
        )

    def _category_suggestion(self, context: AIContext) -> AISuggestion | None:
        candidates = [
            item
            for item in _despesa_categories(context)
            if normalize_text(item["categoria"]) != "assinaturas"
        ]
        if not candidates:
            return None
        biggest = max(candidates, key=lambda item: item["total"])
        nome = biggest["categoria"]
        total = biggest["total"]
        media = media_for(context.media_3m, nome)

        if media is not None and media > 0 and total > media:
            diff = total - media
            por_que = (
                f"É a maior despesa do mês: {brl(total)}, "
                f"{brl(diff)} acima da média de {brl(media)} dos últimos 3 meses."
            )
            quanto = brl(diff)
        elif media is not None and media > 0:
            por_que = (
                f"É a maior despesa do mês: {brl(total)}. "
                f"A média dos últimos 3 meses é {brl(media)}."
            )
            quanto = SEM_ESTIMATIVA
        else:
            por_que = f"É a maior despesa do mês: {brl(total)}."
            quanto = SEM_ESTIMATIVA

        return AISuggestion(
            tipo="categoria",
            titulo=f"Revisar {nome}",
            o_que=f"Revisar os gastos de {nome} e definir um teto para o mês.",
            por_que=por_que,
            quanto=quanto,
        )

    def _bank_suggestion(self, context: AIContext) -> AISuggestion | None:
        if context.banco_pendentes <= 0:
            return None
        n = context.banco_pendentes
        return AISuggestion(
            tipo="banco",
            titulo="Revisar pendências do banco",
            o_que="Importar ou conciliar as transações bancárias pendentes.",
            por_que=f"Há {n} transação(ões) aguardando decisão.",
            quanto=SEM_ESTIMATIVA,
        )

    def _budget_suggestion(self, context: AIContext) -> AISuggestion | None:
        totais = context.totais
        if _present(totais, "receitas") and _present(totais, "despesas"):
            receitas = to_float(totais.get("receitas"))
            despesas = to_float(totais.get("despesas"))
            if despesas > receitas:
                excesso = despesas - receitas
                return AISuggestion(
                    tipo="orcamento",
                    titulo="Rever o orçamento do mês",
                    o_que="Cortar ou adiar despesas até o mês fechar no azul.",
                    por_que=(
                        f"As despesas ({brl(despesas)}) passaram as receitas "
                        f"({brl(receitas)}) em {brl(excesso)}."
                    ),
                    quanto=brl(excesso),
                )
        if _present(totais, "saldo"):
            saldo = to_float(totais.get("saldo"))
            if saldo > 0:
                return AISuggestion(
                    tipo="orcamento",
                    titulo="Direcionar a sobra do mês",
                    o_que="Separar a sobra para uma meta ou reserva.",
                    por_que=f"Sobraram {brl(saldo)} neste mês.",
                    quanto=brl(saldo),
                )
        return None

    def _empty_suggestion(self, context: AIContext) -> AISuggestion:
        return AISuggestion(
            tipo="contexto",
            titulo="Ainda não há dados suficientes",
            o_que="Registrar receitas e despesas do mês para a Jev AI poder sugerir algo.",
            por_que="O contexto veio sem totais, categorias, metas ou pendências.",
            quanto=SEM_ESTIMATIVA,
        )

    # -- chat --------------------------------------------------------------

    def chat(self, messages: Sequence[Mapping[str, Any]], context: AIContext) -> str:
        ctx = _coerce_context(context)
        pergunta = self._last_user_text(messages)
        partes: list[str] = []

        if ctx.is_empty():
            partes.append("Ainda não há dados suficientes neste contexto para calcular valores.")
            partes.append("Registre receitas e despesas do mês para eu poder comparar categorias e metas.")
            if self._asks_savings(pergunta):
                partes.append(f"Com o que tenho aqui, {SEM_ESTIMATIVA}.")
            partes.append("Isso é apoio para a decisão, não uma decisão pronta.")
            return " ".join(partes)

        totais = ctx.totais
        resumo: list[str] = []
        if _present(totais, "receitas"):
            resumo.append(f"receitas {brl(totais['receitas'])}")
        if _present(totais, "despesas"):
            resumo.append(f"despesas {brl(totais['despesas'])}")
        if _present(totais, "saldo"):
            resumo.append(f"saldo {brl(totais['saldo'])}")
        if resumo:
            partes.append("Neste mês: " + ", ".join(resumo) + ".")

        if ctx.banco_pendentes > 0:
            partes.append(
                f"Há {ctx.banco_pendentes} transação(ões) bancária(s) pendente(s) "
                "para importar ou conciliar."
            )

        if self._asks_savings(pergunta):
            if not _present(totais, "saldo"):
                partes.append(f"Não tenho o saldo do mês; {SEM_ESTIMATIVA}.")
            else:
                saldo = to_float(totais.get("saldo"))
                if saldo > 0:
                    partes.append(
                        f"Com os dados deste mês, sobra {brl(saldo)}; dá para começar por aí."
                    )
                elif saldo < 0:
                    partes.append(
                        f"O mês fechou negativo em {brl(abs(saldo))}; "
                        f"{SEM_ESTIMATIVA} de economia sem ajustar despesas."
                    )
                else:
                    partes.append(f"O saldo do mês está zerado; {SEM_ESTIMATIVA}.")
        else:
            despesas = _despesa_categories(ctx)
            if despesas:
                biggest = max(despesas, key=lambda item: item["total"])
                partes.append(
                    f"A maior despesa é {biggest['categoria']} ({brl(biggest['total'])})."
                )
            partes.append(
                "Próximo passo: revisar as categorias com maior gasto e as pendências do banco."
            )

        partes.append("Isso é apoio para a decisão, não uma decisão pronta.")
        return " ".join(partes)

    @staticmethod
    def _last_user_text(messages: Sequence[Mapping[str, Any]] | None) -> str:
        if not messages:
            return ""
        for message in reversed(list(messages)):
            if not isinstance(message, Mapping):
                continue
            role = normalize_text(message.get("role", "user"))
            if role and role != "user":
                continue
            content = message.get("content")
            if isinstance(content, str) and content.strip():
                return normalize_text(content)
        return ""

    @staticmethod
    def _asks_savings(pergunta: str) -> bool:
        return any(word in pergunta for word in _SAVINGS_WORDS)
