"""Contrato do serviço de IA (Jev AI + fallback determinístico).

O backend monta o :class:`AIContext` a partir do banco e entrega ao adaptador.
Este módulo não consulta banco, não lê credenciais e não envia dados de outro
membro: no escopo ``familia`` só sobrevivem agregados.
"""

from __future__ import annotations

import unicodedata
from dataclasses import dataclass, field
from typing import Any, Mapping, Protocol, Sequence, runtime_checkable

ESCOPO_FAMILIA = "familia"
ESCOPO_PESSOAL = "pessoal"

SEM_ESTIMATIVA = "não é possível estimar"

_TOTAL_KEYS = ("receitas", "despesas", "saldo")
_CATEGORIA_KEYS = ("category_id", "categoria", "nome", "total", "tipo", "media_3m", "variacao")
_META_KEYS = (
    "id",
    "titulo",
    "valor_alvo",
    "valor_atual",
    "contribuido",
    "progresso",
    "status",
    "prazo",
    "dias_para_prazo",
)
_TRANSACAO_KEYS = ("descricao", "valor", "data", "categoria", "tipo", "origem")

_DEFAULT_TIPO_POR_NOME = {
    "alimentacao": "despesa",
    "moradia": "despesa",
    "transporte": "despesa",
    "saude": "despesa",
    "educacao": "despesa",
    "lazer": "despesa",
    "assinaturas": "despesa",
    "outros": "despesa",
    "salario": "receita",
    "freelance": "receita",
    "investimentos": "receita",
}

DESPESA_NAMES = (
    "Alimentação",
    "Moradia",
    "Transporte",
    "Saúde",
    "Educação",
    "Lazer",
    "Assinaturas",
    "Outros",
)
RECEITA_NAMES = ("Salário", "Freelance", "Investimentos", "Outros")


class AIUnavailable(Exception):
    """O adaptador real falhou (rede, timeout, HTTP >= 400 ou resposta inválida)."""


def normalize_text(value: Any) -> str:
    """Minúsculas, sem acentos e com espaços colapsados."""
    if value is None:
        return ""
    text = unicodedata.normalize("NFKD", str(value))
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    return " ".join(text.lower().split())


def normalize_escopo(value: Any) -> str:
    """Normaliza o escopo; qualquer coisa ambígua cai em ``familia`` (agregado)."""
    text = normalize_text(value)
    if text in ("pessoal", "personal", "individual", "meu"):
        return ESCOPO_PESSOAL
    return ESCOPO_FAMILIA


def normalize_tipo(value: Any) -> str | None:
    text = normalize_text(value)
    if text.startswith("receita"):
        return "receita"
    if text.startswith("despesa"):
        return "despesa"
    return None


def to_float(value: Any, default: float = 0.0) -> float:
    """Converte número ou texto pt-BR (``R$ 1.234,56``) sem estourar."""
    if isinstance(value, bool) or value is None:
        return default
    if isinstance(value, str):
        text = value.strip().replace("R$", "").replace(" ", "")
        if not text:
            return default
        if "," in text:
            text = text.replace(".", "").replace(",", ".")
        try:
            return float(text)
        except ValueError:
            return default
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def brl(value: Any) -> str:
    """Formata em reais de forma determinística: ``R$ 1.234,56``."""
    number = to_float(value)
    formatted = f"{number:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
    return f"R$ {formatted}"


def _clean_mapping(value: Any, allowed: Sequence[str]) -> dict[str, Any]:
    if not isinstance(value, Mapping):
        return {}
    return {key: value[key] for key in allowed if key in value and value[key] is not None}


def _clean_list(value: Any, allowed: Sequence[str]) -> list[dict[str, Any]]:
    if not isinstance(value, (list, tuple)):
        return []
    cleaned: list[dict[str, Any]] = []
    for item in value:
        if isinstance(item, Mapping):
            cleaned.append(_clean_mapping(item, allowed))
    return cleaned


def _normalize_media(value: Any) -> dict[str, float]:
    """Aceita ``{categoria: valor}`` ou ``[{categoria, media|total}]``."""
    result: dict[str, float] = {}
    if isinstance(value, Mapping):
        for key, item in value.items():
            if isinstance(item, Mapping):
                item = item.get("media", item.get("total", item.get("valor", 0)))
            if key is not None:
                result[str(key)] = to_float(item)
    elif isinstance(value, (list, tuple)):
        for item in value:
            if not isinstance(item, Mapping):
                continue
            name = item.get("categoria", item.get("nome", item.get("category")))
            if name is None:
                continue
            amount = item.get("media", item.get("total", item.get("valor", 0)))
            result[str(name)] = to_float(amount)
    return result


def media_for(media: Mapping[str, float], categoria: Any) -> float | None:
    target = normalize_text(categoria)
    for key, value in media.items():
        if normalize_text(key) == target:
            return to_float(value)
    return None


def default_categories() -> list[dict[str, Any]]:
    return [
        {"id": None, "nome": name, "tipo": "despesa"} for name in DESPESA_NAMES
    ] + [{"id": None, "nome": name, "tipo": "receita"} for name in RECEITA_NAMES]


def normalize_categories(categorias: Any) -> list[dict[str, Any]]:
    """Normaliza ``[{id,nome,tipo}]`` ou ``["Alimentação", ...]``."""
    if not categorias:
        return []
    normalized: list[dict[str, Any]] = []
    for item in categorias:
        if isinstance(item, str):
            name = item.strip()
            category_id = None
            tipo = _DEFAULT_TIPO_POR_NOME.get(normalize_text(name))
        elif isinstance(item, Mapping):
            name = item.get("nome", item.get("categoria", item.get("name", item.get("titulo"))))
            category_id = item.get("id", item.get("category_id", item.get("categoria_id")))
            tipo = normalize_tipo(item.get("tipo", item.get("type")))
            if tipo is None and name is not None:
                tipo = _DEFAULT_TIPO_POR_NOME.get(normalize_text(name))
        else:
            continue
        if not name or not str(name).strip():
            continue
        normalized.append(
            {
                "id": category_id,
                "nome": str(name).strip(),
                "tipo": tipo,
            }
        )
    return normalized


def find_category(categorias: Sequence[Mapping[str, Any]], nome: Any) -> dict[str, Any] | None:
    target = normalize_text(nome)
    for item in categorias:
        if normalize_text(item.get("nome")) == target:
            return dict(item)
    return None


def resolve_category(
    nome: Any,
    tipo: Any,
    categorias: Any,
) -> dict[str, Any]:
    """Resolve nome -> ``{categoria_id, categoria}`` respeitando o tipo."""
    tipo_norm = normalize_tipo(tipo)
    cats = normalize_categories(categorias)
    if tipo_norm:
        candidates = [item for item in cats if item["tipo"] in (None, tipo_norm)]
    else:
        candidates = cats
    found = find_category(candidates, nome)
    if found is not None:
        return {"categoria_id": found.get("id"), "categoria": found.get("nome")}
    if nome is not None and str(nome).strip():
        return {"categoria_id": None, "categoria": str(nome).strip()}
    return {"categoria_id": None, "categoria": None}


@dataclass
class AIContext:
    """Contexto financeiro pronto para a IA.

    ``member_id`` é opcional e nunca vai no payload; serve só para descartar
    itens de outro membro no escopo pessoal. No escopo família ele é zerado e
    ``transacoes`` fica vazio por construção.
    """

    escopo: str = ESCOPO_FAMILIA
    totais: dict[str, Any] = field(default_factory=dict)
    categorias: list[dict[str, Any]] = field(default_factory=list)
    media_3m: dict[str, float] = field(default_factory=dict)
    metas: list[dict[str, Any]] = field(default_factory=list)
    transacoes: list[dict[str, Any]] = field(default_factory=list)
    banco_pendentes: int = 0
    member_id: str | None = None

    def __post_init__(self) -> None:
        self.escopo = normalize_escopo(self.escopo)
        self.totais = _clean_mapping(self.totais, _TOTAL_KEYS)
        self.categorias = _clean_list(self.categorias, _CATEGORIA_KEYS)
        self.media_3m = _normalize_media(self.media_3m)
        self.metas = _clean_list(self.metas, _META_KEYS)
        try:
            self.banco_pendentes = max(0, int(self.banco_pendentes or 0))
        except (TypeError, ValueError):
            self.banco_pendentes = 0

        raw_transacoes = self.transacoes if isinstance(self.transacoes, (list, tuple)) else []
        if self.escopo == ESCOPO_FAMILIA:
            self.member_id = None
            self.transacoes = []
        else:
            if self.member_id:
                own = [
                    item
                    for item in raw_transacoes
                    if not isinstance(item, Mapping)
                    or item.get("member_id") in (None, "")
                    or str(item.get("member_id")) == str(self.member_id)
                ]
            else:
                own = list(raw_transacoes)
            self.transacoes = _clean_list(own, _TRANSACAO_KEYS)

    def is_empty(self) -> bool:
        """Sem qualquer sinal financeiro útil para estimar algo."""
        if any(abs(to_float(value)) > 0 for value in self.totais.values()):
            return False
        return not (self.categorias or self.metas or self.transacoes or self.banco_pendentes)

    def to_payload(self) -> dict[str, Any]:
        """Payload seguro para o adaptador real; nunca inclui ``member_id``."""
        return {
            "escopo": self.escopo,
            "totais": dict(self.totais),
            "categorias": [dict(item) for item in self.categorias],
            "media_3m": dict(self.media_3m),
            "metas": [dict(item) for item in self.metas],
            "transacoes": [dict(item) for item in self.transacoes],
            "banco_pendentes": self.banco_pendentes,
        }


@dataclass
class AISuggestion:
    """Sugestão no formato da spec: o quê, por quê e quanto."""

    tipo: str
    titulo: str
    o_que: str
    por_que: str
    quanto: str

    def is_valid(self) -> bool:
        return all(
            isinstance(value, str) and value.strip()
            for value in (self.tipo, self.titulo, self.o_que, self.por_que, self.quanto)
        )

    def as_dict(self) -> dict[str, str]:
        return {
            "tipo": self.tipo,
            "titulo": self.titulo,
            "o_que": self.o_que,
            "por_que": self.por_que,
            "quanto": self.quanto,
        }


@runtime_checkable
class AIAdapter(Protocol):
    """Interface única usada pelos endpoints ``/api/ai/*``."""

    mode: str

    def classify(
        self,
        descricao: str,
        tipo: str,
        categorias: Sequence[Mapping[str, Any] | str] | None = None,
    ) -> dict[str, Any]:
        """Devolve ``{categoria_id, categoria}``; sem match, ``categoria_id`` nulo."""

    def suggest(self, context: AIContext) -> list[AISuggestion]:
        """Devolve de 1 a 4 sugestões com os três campos preenchidos."""

    def chat(self, messages: Sequence[Mapping[str, Any]], context: AIContext) -> str:
        """Resposta curta de apoio, sem inventar número."""
