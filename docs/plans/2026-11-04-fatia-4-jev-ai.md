# Fatia 4 — Jev AI (v1)

> **Contrato canônico:** `docs/plans/2026-11-04-v1-contract.md` + `2026-11-04-gate0-remediation.md` + `2026-11-04-fatia-1b-migrations.md` vencem este plano onde houver conflito. As seções abaixo são históricas; a lane deve seguir o contrato canônico.

**Data:** 2026-11-04
**Depende de:** fatia 1 (`629fce9`) e contrato do backend (`docs/plans/2026-11-04-fatia-2-backend-pluggy.md`).
**Spec:** `docs/2026-10-27-vivafinancas-brainstorming.md` (§3.7, §4.6, §7.1, §7.2).

## Objetivo

Serviço de IA do backend com um adaptador real (`JevAIAdapter`) e um fallback determinístico (`FallbackLLMAdapter`), usado pelos endpoints `/api/ai/*`. Sem chave real, o fallback entrega classificação, sugestões e respostas úteis; a UI mostra o modo degradado. O contexto familiar usa apenas agregados; o pessoal usa os dados do próprio usuário.

## Ownership

- A lane de IA escreve `backend/app/services/ai/**` e `backend/tests/test_ai_service*`.
- O backend importa `from app.services.ai import get_ai_service`; não edita os arquivos da IA.
- O contrato abaixo é congelado; mudanças passam pelo orchestrator.

## Interface

```python
# backend/app/services/ai/base.py
@dataclass
class AIContext:
    escopo: str                 # "familia" | "pessoal"
    totais: dict                # receitas, despesas, saldo
    categorias: list[dict]      # categoria, total
    metas: list[dict]           # titulo, valor_alvo, progresso, status
    transacoes: list[dict]      # somente pessoal; descricao, valor, data, categoria
    banco_pendentes: int = 0

@dataclass
class AISuggestion:
    tipo: str
    titulo: str
    o_que: str
    por_que: str
    quanto: str                 # texto; pode ser "não é possível estimar"

class AIAdapter(Protocol):
    mode: str                   # "jev" | "fallback" | "degraded"
    def classify(self, descricao: str, categorias: list[str]) -> str: ...
    def suggest(self, context: AIContext) -> list[AISuggestion]: ...
    def chat(self, messages: list[dict], context: AIContext) -> str: ...
```

`get_ai_service()` escolhe:
- `JEV_AI_BASE_URL` + `JEV_AI_API_KEY` configurados → `JevAIAdapter` com fallback interno.
- Sem chave → `FallbackLLMAdapter` com `mode="fallback"`.
- Falha/timeout do adaptador real → fallback no mesmo request; `mode="degraded"` na resposta.
- Sem nenhum contexto/dados → fallback com `mode="degraded"` e resposta explicativa.

## JevAIAdapter

- `httpx.Client` com timeout curto (8s connect/15s read).
- Headers: `Authorization: Bearer <JEV_AI_API_KEY>`, `Content-Type: application/json`.
- Endpoints (contrato a validar com a Jev AI):
  - `POST {BASE_URL}/classify` body `{descricao, categorias}` → `{categoria}`.
  - `POST {BASE_URL}/suggest` body `{contexto}` → `{sugestoes:[...]}`.
  - `POST {BASE_URL}/chat` body `{messages, contexto}` → `{resposta}`.
- Parse tolerante; valida `o_que`/`por_que`/`quanto`; se faltar, completa com fallback.
- Erros/timeout → `AIUnavailable`; o chamador usa fallback.
- Nenhuma chave é logada; não enviar dados de outro membro no contexto familiar.

## FallbackLLMAdapter

Determinístico, sem rede:

- **Classificação** por palavras-chave (case-insensitive): supermercado/mercado → Alimentação; aluguel/condomínio → Moradia; uber/ônibus/combustível → Transporte; farmácia/médico → Saúde; escola/curso → Educação; cinema/show → Lazer; streaming/assinatura → Assinaturas; salário/holerite → Salário; freelance/pix recebido → Freelance; investimento/dividendo → Investimentos; senão → Outros (respeitando o tipo).
- **Sugestões** a partir do contexto:
  - Categoria com maior aumento/maior total: “Revisar {categoria}”, com o porquê nos números e o quanto estimado pela diferença para a média (ou “não é possível estimar”).
  - Assinaturas: se houver categoria Assinaturas, sugerir revisão; quanto = total do mês.
  - Metas: se progresso < 50% e prazo próximo, sugerir aporte; quanto = lacuna ou “não é possível estimar”.
  - Banco: se `banco_pendentes > 0`, sugerir revisar as pendências; quanto = “não é possível estimar”.
  - Sem dados: uma sugestão explicativa, sem número inventado.
- **Chat**: resposta curta com resumo dos totais, próximos passos e a ressalva de que é apoio, não decisão. Para “quanto economizar”, usar os mesmos cálculos; se não houver base, dizer “não é possível estimar”.
- Garantir 1–4 sugestões, todas com os três campos não vazios; `quanto` pode ser a frase explícita.

## Contexto

- **Família:** `family_totals`, `family_category_totals`, `family_monthly_totals`, metas familiares, contagem de pendências bancárias. Nunca `member_id`, descrição ou valor individual.
- **Pessoal:** transações e metas do próprio usuário, categorias pessoais, pendências bancárias próprias.
- O backend monta o `AIContext` e passa ao serviço; o serviço não consulta o banco.

## Integração com o backend

- `GET /api/ai/messages` lê `ai_messages` (família ou pessoal; RLS).
- `POST /api/ai/messages` grava a mensagem do usuário, chama `chat`, grava a resposta e retorna `{messages, suggestions, mode}`.
- `POST /api/ai/classify` usa `classify` e mapeia o nome para a categoria da família; o frontend usa no modal de lançamento e na importação bancária.
- `GET /api/ai/suggestions` lê `ai_suggestions`; `PATCH /{id}/read` marca `lida=true`.
- O backend pode gravar sugestões geradas pelo fallback com `member_id=null` (família) ou o usuário (pessoal); a RLS decide.
- Falha do adaptador real não derruba o endpoint; resposta usa fallback e `mode="degraded"`.

## Testes

- `pytest -q backend/tests/test_ai_service*`:
  - classificação por palavra-chave e fallback “Outros”;
  - sugestões com `o_que`/`por_que`/`quanto` não vazios; pelo menos uma com “não é possível estimar” quando não há base;
  - chat responde sem inventar número;
  - `JevAIAdapter` com `httpx.MockTransport` sucesso, timeout e 500 → fallback;
  - `get_ai_service()` sem chave → fallback; com chave → jev; falha → degraded;
  - contexto familiar não contém `member_id`/descrição pessoal.
- Sem rede real; nenhuma chave de teste no repo.

## Aceite

- Sem `JEV_AI_*`, a UI e os endpoints funcionam no fallback; sugestões têm os três campos.
- Com chave real (quando existir), o adaptador é usado e o fallback cobre falha/timeout.
- Nenhum dado de outro membro no contexto familiar.
- `pytest` verde; modo degradado documentado no README.
