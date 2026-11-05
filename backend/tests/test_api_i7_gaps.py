"""Lacunas I7 do gate 1b: mês, injeção de filtros, dedup e paginação."""

from __future__ import annotations

import pytest

from conftest import FAMILY_ID, PROFILE, profile_route

from app.errors import ApiError
from app.services.ai import AISuggestion
from app.services.ai_data import persist_suggestions


def _empty_transactions_routes(fake):
    profile_route(fake)
    fake.add("GET", "/rest/v1/transactions", [])
    fake.add("GET", "/rest/v1/categories", [])
    fake.add("POST", "/rest/v1/rpc/family_member_directory", [])


@pytest.mark.parametrize("mes", ["2026-11", "2026-11-01T10:30:00Z", "2026-11-01"])
def test_transactions_normaliza_mes(client, fake, auth_headers, mes):
    _empty_transactions_routes(fake)
    response = client.get(f"/api/transactions?mes={mes}", headers=auth_headers)
    assert response.status_code == 200, response.get_json()
    request = fake.last("GET", "/rest/v1/transactions")
    assert request.url.params.get("and") == (
        "(data.gte.2026-11-01,data.lt.2026-12-01)"
    )


@pytest.mark.parametrize("mes", ["2026-11", "2026-11-01T10:30:00Z"])
def test_banking_transactions_normaliza_mes(client, fake, auth_headers, mes):
    profile_route(fake)
    fake.add("GET", "/rest/v1/bank_transactions", [])
    response = client.get(f"/api/banking/transactions?mes={mes}", headers=auth_headers)
    assert response.status_code == 200, response.get_json()
    request = fake.last("GET", "/rest/v1/bank_transactions")
    assert request.url.params.get("and") == (
        "(data.gte.2026-11-01,data.lt.2026-12-01)"
    )


@pytest.mark.parametrize(
    "categoria",
    [
        "c1,category_id.eq.outro",
        "c1)",
        "c1&select=*",
        "c1=eq.x",
        "c1,or(id.neq.0)",
    ],
)
def test_categoria_nao_injeta_filtro(client, fake, auth_headers, categoria):
    _empty_transactions_routes(fake)
    response = client.get(
        "/api/transactions",
        headers=auth_headers,
        query_string={"categoria": categoria},
    )
    assert response.status_code == 422, response.get_json()
    assert response.get_json()["error"]["code"] == "validation_error"
    assert not fake.calls("GET", "/rest/v1/transactions")


@pytest.mark.parametrize(
    "path",
    [
        "/api/transactions/t1,id.eq.outro",
        "/api/transactions/t1)",
        "/api/transactions/t1&select=*",
    ],
)
def test_id_de_path_nao_injeta_filtro(client, fake, auth_headers, path):
    profile_route(fake)
    response = client.delete(path, headers=auth_headers)
    assert response.status_code == 422, response.get_json()
    assert not fake.calls("DELETE", "/rest/v1/transactions")


def test_connection_id_nao_injeta_filtro(client, fake, auth_headers):
    profile_route(fake)
    response = client.get(
        "/api/banking/transactions",
        headers=auth_headers,
        query_string={"connection_id": "bc1,status.eq.importada"},
    )
    assert response.status_code == 422, response.get_json()
    assert not fake.calls("GET", "/rest/v1/bank_transactions")


def test_invite_pendente_de_outro_escopo_nao_vira_update_cego(client, fake, auth_headers):
    profile_route(fake)
    response = client.delete(
        "/api/admin/invites/inv-1,status.eq.pendente",
        headers=auth_headers,
    )
    assert response.status_code == 422, response.get_json()
    assert not fake.calls("GET", "/rest/v1/invites")


class _SuggestionRest:
    def __init__(self) -> None:
        self.calls: list[dict] = []

    def post(self, path, payload):
        self.calls.append(payload)
        if len(self.calls) == 1:
            raise ApiError(409, "conflict", "Registro já existe.")
        return [{"id": "s-ok"}]


def _suggestion(titulo: str) -> AISuggestion:
    return AISuggestion(
        tipo="categoria",
        titulo=titulo,
        o_que="Revisar a categoria.",
        por_que="Está acima do padrão.",
        quanto="R$ 100,00",
    )


def test_dedup_23505_de_sugestoes_nao_interrompe_as_demais():
    rest = _SuggestionRest()
    created = persist_suggestions(
        rest,
        {"family_id": FAMILY_ID},
        PROFILE["id"],
        "familia",
        [_suggestion("Primeira a duplicar"), _suggestion("Segunda ok")],
    )
    assert created == 1
    assert len(rest.calls) == 2
    assert rest.calls[0]["titulo"] == "Primeira a duplicar"
    assert rest.calls[1]["titulo"] == "Segunda ok"


def test_revisited_months_do_not_reuse_previous_month_total(client, fake, auth_headers):
    """Sanidade: meses diferentes geram faixas diferentes (sem cache acidental)."""
    _empty_transactions_routes(fake)
    client.get("/api/transactions?mes=2026-11", headers=auth_headers)
    client.get("/api/transactions?mes=2026-12", headers=auth_headers)
    ranges = [request.url.params.get("and") for request in fake.calls("GET", "/rest/v1/transactions")]
    nov = "(data.gte.2026-11-01,data.lt.2026-12-01)"
    dez = "(data.gte.2026-12-01,data.lt.2027-01-01)"
    # Cada request faz a leitura paginada e o fallback de total (header ausente).
    assert ranges == [nov, nov, dez, dez]
