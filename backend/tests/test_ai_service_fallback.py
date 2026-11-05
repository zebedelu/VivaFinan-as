"""Testes do contrato e do fallback determinístico da Jev AI."""

from __future__ import annotations

import json

import pytest

from app.services.ai import (
    AIContext,
    AISuggestion,
    FallbackLLMAdapter,
    SEM_ESTIMATIVA,
)
from app.services.ai.base import brl, normalize_categories, resolve_category

CATEGORIAS = [
    {"id": "c-alimentacao", "nome": "Alimentação", "tipo": "despesa"},
    {"id": "c-moradia", "nome": "Moradia", "tipo": "despesa"},
    {"id": "c-transporte", "nome": "Transporte", "tipo": "despesa"},
    {"id": "c-saude", "nome": "Saúde", "tipo": "despesa"},
    {"id": "c-educacao", "nome": "Educação", "tipo": "despesa"},
    {"id": "c-lazer", "nome": "Lazer", "tipo": "despesa"},
    {"id": "c-assinaturas", "nome": "Assinaturas", "tipo": "despesa"},
    {"id": "c-outros-despesa", "nome": "Outros", "tipo": "despesa"},
    {"id": "c-salario", "nome": "Salário", "tipo": "receita"},
    {"id": "c-freelance", "nome": "Freelance", "tipo": "receita"},
    {"id": "c-investimentos", "nome": "Investimentos", "tipo": "receita"},
    {"id": "c-outros-receita", "nome": "Outros", "tipo": "receita"},
]


@pytest.fixture()
def adapter() -> FallbackLLMAdapter:
    return FallbackLLMAdapter()


def _ctx() -> AIContext:
    return AIContext(
        escopo="familia",
        totais={"receitas": 8000, "despesas": 6200, "saldo": 1800},
        categorias=[
            {"categoria": "Alimentação", "total": 1400, "tipo": "despesa"},
            {"categoria": "Moradia", "total": 1200, "tipo": "despesa"},
            {"categoria": "Assinaturas", "total": 180, "tipo": "despesa"},
        ],
        media_3m={"Alimentação": 1000, "Moradia": 1200, "Assinaturas": 150},
        metas=[
            {
                "titulo": "Viagem em família",
                "valor_alvo": 10000,
                "progresso": 30,
                "prazo": "2026-12-01",
                "dias_para_prazo": 27,
                "status": "ativa",
            }
        ],
        banco_pendentes=3,
    )


@pytest.mark.parametrize(
    ("descricao", "tipo", "esperado"),
    [
        ("Supermercado do mês", "despesa", "Alimentação"),
        ("Aluguel e condomínio", "despesa", "Moradia"),
        ("Uber para a reunião", "despesa", "Transporte"),
        ("Farmácia da esquina", "despesa", "Saúde"),
        ("Curso de inglês", "despesa", "Educação"),
        ("Cinema com a família", "despesa", "Lazer"),
        ("Netflix e Spotify", "despesa", "Assinaturas"),
        ("Salário de novembro", "receita", "Salário"),
        ("Freelance de design", "receita", "Freelance"),
        ("Dividendos do fundo", "receita", "Investimentos"),
    ],
)
def test_classify_por_palavra_chave(adapter, descricao, tipo, esperado):
    resultado = adapter.classify(descricao, tipo, CATEGORIAS)
    assert resultado["categoria"] == esperado
    assert resultado["categoria_id"] is not None


def test_classify_respeita_tipo(adapter):
    # "mercado" é despesa; no tipo receita não pode virar Alimentação nem Outros.
    resultado = adapter.classify("Mercado", "receita", CATEGORIAS)
    assert resultado == {"categoria_id": None, "categoria": None}


def test_classify_sem_palavra_devolve_nulo_mesmo_com_outros(adapter):
    assert adapter.classify("Compra aleatória", "despesa", CATEGORIAS) == {
        "categoria_id": None,
        "categoria": None,
    }
    assert adapter.classify("Crédito aleatório", "receita", CATEGORIAS) == {
        "categoria_id": None,
        "categoria": None,
    }


def test_classify_match_por_palavra_chave_continua(adapter):
    assert adapter.classify("Uber para a reunião", "despesa", CATEGORIAS) == {
        "categoria_id": "c-transporte",
        "categoria": "Transporte",
    }


def test_classify_sem_categoria_outros_devolve_id_nulo(adapter):
    cats = [{"id": "c-alimentacao", "nome": "Alimentação", "tipo": "despesa"}]
    resultado = adapter.classify("Compra aleatória", "despesa", cats)
    assert resultado == {"categoria_id": None, "categoria": None}


def test_classify_aceita_lista_de_nomes(adapter):
    cats = normalize_categories(["Alimentação", "Outros"])
    assert adapter.classify("Padaria", "despesa", cats)["categoria"] == "Alimentação"


def test_sugestoes_tem_tres_campos_e_limite(adapter):
    sugestoes = adapter.suggest(_ctx())

    assert 1 <= len(sugestoes) <= 4
    for sugestao in sugestoes:
        assert isinstance(sugestao, AISuggestion)
        assert sugestao.is_valid()
        assert sugestao.o_que.strip()
        assert sugestao.por_que.strip()
        assert sugestao.quanto.strip()

    assert any("não é possível estimar" in s.quanto for s in sugestoes)
    assert any("Viagem em família" in s.titulo for s in sugestoes)
    assert any("assinatura" in s.titulo.lower() for s in sugestoes)
    assert any("pendências do banco" in s.titulo.lower() for s in sugestoes)


def test_sugestao_de_categoria_estima_pela_media(adapter):
    sugestoes = adapter.suggest(_ctx())
    categoria = next(s for s in sugestoes if s.titulo == "Revisar Alimentação")
    # 1400 no mês - 1000 de média = 400 de diferença.
    assert "400,00" in categoria.quanto


def test_sugestoes_sem_base_nao_inventam_numero(adapter):
    ctx = AIContext(
        escopo="familia",
        totais={"receitas": 5000, "despesas": 4000, "saldo": 1000},
        categorias=[{"categoria": "Moradia", "total": 1200, "tipo": "despesa"}],
        banco_pendentes=1,
    )
    sugestoes = adapter.suggest(ctx)
    assert 1 <= len(sugestoes) <= 4
    moradia = next(s for s in sugestoes if s.titulo == "Revisar Moradia")
    assert moradia.quanto == SEM_ESTIMATIVA
    banco = next(s for s in sugestoes if s.tipo == "banco")
    assert banco.quanto == SEM_ESTIMATIVA


def test_sugestoes_deterministicas(adapter):
    ctx = _ctx()
    assert adapter.suggest(ctx) == adapter.suggest(ctx)


def test_contexto_vazio_gera_sugestao_explicativa(adapter):
    sugestoes = adapter.suggest(AIContext())
    assert len(sugestoes) == 1
    assert sugestoes[0].is_valid()
    assert sugestoes[0].quanto == SEM_ESTIMATIVA


def test_chat_resume_totais_sem_inventar(adapter):
    resposta = adapter.chat(
        [{"role": "user", "content": "Quanto dá para economizar?"}], _ctx()
    )
    assert "R$ 8.000,00" in resposta
    assert "R$ 6.200,00" in resposta
    assert "R$ 1.800,00" in resposta
    assert "apoio" in resposta.lower()
    assert adapter.chat([{"role": "user", "content": "Quanto dá para economizar?"}], _ctx()) == resposta


def test_chat_sem_dados_nao_inventa_numero(adapter):
    resposta = adapter.chat(
        [{"role": "user", "content": "Quanto posso economizar?"}], AIContext()
    )
    assert "não é possível estimar" in resposta
    assert "R$" not in resposta


def test_contexto_familia_sem_membro_nem_descricao():
    ctx = AIContext(
        escopo="família",
        totais={"receitas": 5000, "despesas": 3000, "saldo": 2000, "member_id": "m-1"},
        categorias=[
            {"categoria": "Moradia", "total": 1800, "member_id": "m-1", "descricao": "aluguel"}
        ],
        metas=[
            {
                "titulo": "Viagem",
                "valor_alvo": 10000,
                "progresso": 20,
                "member_id": "m-1",
                "descricao": "detalhe pessoal",
            }
        ],
        transacoes=[
            {"descricao": "Mercado", "valor": 200, "member_id": "m-1", "categoria": "Alimentação"}
        ],
        member_id="m-1",
        banco_pendentes=2,
    )

    payload = ctx.to_payload()
    blob = json.dumps(payload, ensure_ascii=False)

    assert ctx.escopo == "familia"
    assert ctx.member_id is None
    assert payload["transacoes"] == []
    assert "member_id" not in payload
    assert "m-1" not in blob
    assert "Mercado" not in blob
    assert "aluguel" not in blob
    assert "detalhe pessoal" not in blob
    assert all("member_id" not in item for item in payload["categorias"])
    assert all("descricao" not in item for item in payload["metas"])


def test_contexto_pessoal_so_do_proprio_usuario():
    ctx = AIContext(
        escopo="pessoal",
        member_id="u-1",
        transacoes=[
            {"descricao": "Mercado", "valor": 100, "member_id": "u-1", "categoria": "Alimentação"},
            {"descricao": "Alheio", "valor": 50, "member_id": "u-2", "categoria": "Lazer"},
        ],
    )
    assert [item["descricao"] for item in ctx.transacoes] == ["Mercado"]


def test_resolve_category_respeita_tipo():
    assert resolve_category("Alimentação", "receita", CATEGORIAS) == {
        "categoria_id": None,
        "categoria": "Alimentação",
    }
    assert resolve_category("Salário", "receita", CATEGORIAS) == {
        "categoria_id": "c-salario",
        "categoria": "Salário",
    }


def test_brl_formata_pt_br():
    assert brl(1234.5) == "R$ 1.234,50"
    assert brl("R$ 1.234,56") == "R$ 1.234,56"
