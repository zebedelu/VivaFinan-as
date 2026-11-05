# Fatia 2 — Backend Flask + Pluggy (v1)

> **Contrato canônico:** `docs/plans/2026-11-04-v1-contract.md` + `2026-11-04-gate0-remediation.md` + `2026-11-04-fatia-1b-migrations.md` vencem este plano onde houver conflito. As seções abaixo são históricas; a lane deve seguir o contrato canônico.

**Data:** 2026-11-04
**Depende de:** fatia 1 commitada (`629fce9`), 350/350 pgTAP.
**Spec:** `docs/2026-10-27-vivafinancas-brainstorming.md` (§3, §4, §6, §7).
**Contrato de banco:** `docs/2026-11-03-vivafinancas-supabase-rls-seed.md`, `supabase/README.md`.

## Objetivo

API REST Flask que usa o JWT do usuário em todas as consultas de dados, deixa o RLS como fonte da verdade e expõe os fluxos da v1: identidade, painel, lançamentos, recorrentes, metas, previsões, Jev AI, extrato/importação/reconciliação Pluggy, admin e restauração da demo. A service role fica restrita a Admin API, seed e sync Pluggy; a restauração usa `SUPABASE_DB_URL`.

## Restrições

- Nenhum endpoint aceita `family_id` ou `member_id` do cliente; o backend deriva do JWT/perfil.
- Leitura/escrita normal usa `apikey: SUPABASE_ANON_KEY` + `Authorization: Bearer <jwt do usuário>` no PostgREST. O RLS decide.
- Service role só em `/auth/v1/admin/*` (convite/reset) e no insert de `bank_transactions` da sync Pluggy. Sem a chave, esses caminhos retornam 503.
- Restore da demo: `psycopg` + `SUPABASE_DB_URL`, reexecutando `supabase/seed/010`–`040` em uma transação. Sem a URL, 503.
- Sem `PLUGGY_API_KEY`, usar `MockPluggyAdapter`; sem `JEV_AI_*`, usar o fallback da fatia 4.
- Nenhuma credencial no repositório; `.env` fica fora do git.
- TDD: cada endpoint/serviço tem teste pytest; mocks de HTTP para Supabase/Pluggy/IA.

## Estrutura

```text
backend/
  app/
    __init__.py            # create_app, CORS, blueprints, error handlers
    config.py              # env e defaults
    auth.py                # get_current_user, get_profile
    supabase.py            # SupabaseRest (user JWT) + AdminClient (service role)
    errors.py              # ApiError e handlers
    models/                # repositórios por tabela (queries PostgREST)
      profiles.py
      transactions.py
      recurring.py
      goals.py
      categories.py
      banking.py
      ai.py
    schemas/               # validação de payloads (sem query)
      transactions.py
      recurring.py
      goals.py
      banking.py
      admin.py
      ai.py
    blueprints/
      health.py
      me.py
      family.py
      transactions.py
      recurring.py
      goals.py
      forecast.py
      ai.py
      banking.py
      admin.py
      demo.py
    services/
      forecast.py
      alerts.py
      demo_restore.py
      pluggy/
        __init__.py
        adapter.py          # PluggyAdapter real + MockPluggyAdapter
        sync.py             # PluggySyncService
        import_service.py   # import/reconcile
      ai/                   # ownership da fatia 4
  tests/
    conftest.py
    test_health.py
    test_auth.py
    test_me.py
    test_transactions.py
    test_recurring.py
    test_goals.py
    test_forecast.py
    test_banking.py
    test_admin.py
    test_demo_restore.py
    test_ai_api.py
  requirements.txt
  .env.example
  wsgi.py
```

## Configuração

| Variável | Uso |
|---|---|
| `SUPABASE_URL` | base do PostgREST/Auth |
| `SUPABASE_ANON_KEY` | apikey pública do PostgREST/Auth |
| `SUPABASE_SERVICE_ROLE_KEY` | opcional; Admin API e sync |
| `SUPABASE_DB_URL` | opcional; restore da demo |
| `PLUGGY_API_KEY` | opcional; sem ela, mock |
| `PLUGGY_BASE_URL` | default `https://api.pluggy.ai` |
| `JEV_AI_BASE_URL` / `JEV_AI_API_KEY` | opcionais; fallback sem elas |
| `CORS_ORIGINS` | default `http://localhost:5173,http://127.0.0.1:5173` |
| `DEMO_FAMILY_ID` | `eeeeeeee-0000-4000-8000-000000000001` |
| `SEED_DIR` | default `../supabase/seed` |

`backend/.env.example` lista as chaves sem valores.

## Contrato REST

Prefixo `/api`. Autenticação `Authorization: Bearer <access_token>`. Erros:

```json
{"error": {"code": "forbidden", "message": "...", "details": {}}}
```

### Identidade

- `GET /health` → `{ok:true}` (público).
- `GET /me` → `{user:{id,email}, profile:{id,family_id,nome,papel,status,tema}, family:{id,nome,is_demo}}`.
- `PATCH /me` body `{nome?,tema?}` → atualiza o próprio perfil (RLS/trigger); usado por Configurações e tema.
- `POST /onboarding` body `{nome_familia, nome}` → cria `families` + `profiles` para o usuário sem perfil (RLS); retorna `/me`. Se já tem perfil, 409.

### Painel e individual

- `GET /dashboard?mes=YYYY-MM-01` → `{mes, totais:{receitas,despesas,saldo}, acumulado:{receitas,despesas}, categorias:[{category_id,categoria,total}], serie:[{mes,receitas,despesas}], membros:[{member_id,nome,papel}], metas:[...], sugestoes:[...], alertas:[...], banco:{conexoes_ativas,pendentes}}`.
- `GET /me/summary?mes=YYYY-MM-01` → `{mes, totais, categorias, metas, recorrentes_pendentes, sugestoes, banco:{conexoes,pendentes,ultima_sync}}`.
- `GET /alerts?mes=...` → lista calculada (conta a vencer, meta atingida, categoria estourada, sync).

As funções `family_*` recebem o primeiro dia do mês. O backend rejeita mês inválido com 422 antes de chamar o banco.

### Lançamentos

- `GET /transactions?mes=&tipo=&escopo=&categoria=&origem=&limit=&offset=` → lista ordenada por `data desc`.
- `POST /transactions` body `{tipo,escopo,valor,descricao?,category_id,data,pago_por?,recurring_rule_id?,mes_referencia?,bank_transaction_id?,origem?}`. `origem` default `manual`; `pluggy` exige `bank_transaction_id`. O backend ignora `family_id`/`member_id` do cliente e usa o perfil.
- `PATCH /transactions/{id}` body com campos editáveis (`valor`, `descricao`, `category_id`, `data`, `pago_por`, `bank_transaction_id`); o RLS/trigger recusa identidade.
- `DELETE /transactions/{id}`.

### Recorrentes

- `GET /recurring/rules?escopo=`; `POST /recurring/rules` body `{tipo,escopo,valor,descricao,category_id,dia_vencimento,ativo?}`; `PATCH /recurring/rules/{id}` (ativo, valor, descricao, categoria, dia); sem DELETE.
- `GET /recurring/pending?mes=YYYY-MM-01` → ocorrências `pendente` com dados da regra, `data_vencimento` (dia limitado ao último dia do mês) e `dias_para_vencimento`; o frontend usa `<= 3` ou atrasado para os cartões do painel e mostra todas na página de recorrentes.
- `POST /recurring/occurrences/{id}/confirm` body `{valor?}` → cria o lançamento (`origem='manual'`, `recurring_rule_id`, `mes_referencia`) e atualiza a ocorrência (`confirmado`, `valor_confirmado`, `confirmado_por`, `confirmado_em`). A `data` do lançamento é o dia de vencimento da regra no mês da ocorrência, limitado ao último dia do mês; `valor` é o override ou o valor da regra; `escopo`/`category_id` vêm da regra. Se o update falhar, o lançamento criado é removido; se o insert falhar, a ocorrência fica intacta. A unique `(recurring_rule_id, mes_referencia)` impede duplicata.
- `POST /recurring/occurrences/{id}/ignore` → status `ignorado`.

### Metas

- `GET /goals?escopo=familia|pessoal`; `POST /goals` body `{titulo,valor_alvo,prazo?,descricao?,member_id?}` (família = `member_id` nulo); `PATCH /goals/{id}`; `DELETE /goals/{id}` (só criador; RLS).
- `GET /goals/{id}/contributions`; `POST /goals/{id}/contributions` body `{valor,data?}`; contribuições imutáveis.

### Previsão

- `GET /forecast?meses=12&escopo=familia|pessoal` → `{meses:[{mes,receitas,despesas,saldo,detalhes:[{tipo,descricao,valor,origem}]}], anual:{receitas,despesas,saldo}}`.
- Regra: para cada mês futuro, regras ativas com ocorrência confirmada no mês + média móvel de 3 meses das transações variáveis (`recurring_rule_id is null`) do escopo. Sem persistência.

### Jev AI

- `GET /ai/messages?escopo=familia|pessoal`; `POST /ai/messages` body `{content, escopo}` → grava a mensagem do usuário, chama o serviço de IA, grava a resposta e devolve `{messages, suggestions, mode}`.
- `POST /ai/classify` body `{descricao, tipo}` → `{categoria_id, categoria, mode}`; usa o classificador e mapeia o nome para uma categoria da família; sem correspondência, `categoria_id=null`.
- `GET /ai/suggestions?escopo=`; `PATCH /ai/suggestions/{id}/read` body `{lida:true}`.
- O contexto familiar usa apenas agregados (sem `member_id`, sem descrição pessoal); o pessoal usa as transações/metas do próprio usuário. O serviço de IA é o da fatia 4.

### Banco/Pluggy

- `GET /banking/connections`; `POST /banking/connections` body `{pluggy_connection_id,institution_name,institution_logo_url?,account_name?,account_type?,account_number_masked?}` (mock/real; RLS); `DELETE /banking/connections/{id}` → `status='inativa'` (sem DELETE).
- `GET /banking/accounts?connection_id=`; `GET /banking/transactions?connection_id=&status=&mes=&limit=&offset=`.
- `POST /banking/sync` body `{connection_id}` → `PluggySyncService`. Sem service role/chave, 503 ou no-op para conexão demo. A sync nunca cria `transactions`.
- `POST /banking/import` body `{bank_transaction_id,category_id,escopo,valor?,data?,descricao?}` → cria `transactions` com `origem='pluggy'` e `bank_transaction_id`; o trigger marca a bank tx `importada`.
- `POST /banking/reconcile` body `{bank_transaction_id,transaction_id}` → grava `bank_transaction_id` no lançamento existente; o trigger marca `reconciliada`.
- `POST /banking/ignore` body `{bank_transaction_id}` → status `ignorada` (sem lançamento).

### Admin e demo

- `GET /admin/members`; `PATCH /admin/members/{id}` body `{nome?,status?,tema?}` (RLS/trigger).
- `POST /admin/invite` body `{email}`; `POST /admin/members/{id}/reset-password`; sem service role, 503.
- `GET/POST/PATCH/DELETE /categories` (RLS; padrão só oculta).
- `POST /demo/restore` → somente membro da família demo; sem `SUPABASE_DB_URL`, 503; com a URL, executa os quatro seeds em uma transação e retorna `{ok:true}`. O JWT do visitante deixa de valer; o frontend faz sign out.

## Serviços

- `SupabaseRest`: `get/post/patch/delete/rpc` com headers do usuário; parse de erro; timeout 10s; sem service role.
- `AdminClient`: `/auth/v1/admin/users` com service role; usado só em invite/reset.
- `ForecastService`: cálculo descrito acima; sem chamada externa.
- `AlertsService`: contas a vencer (3 dias), meta atingida, categoria 20% acima da média de 3 meses, sync; sem persistência.
- `DemoRestoreService`: lê `SEED_DIR/010..040`; `psycopg.connect(SUPABASE_DB_URL)`; `with conn.transaction():` executa os arquivos; falha faz rollback.
- `PluggyAdapter`: `httpx` com `X-API-KEY`; `MockPluggyAdapter` determinístico para testes e para o modo sem chave.
- `PluggySyncService`: busca contas/transações; insere `bank_transactions` com service role; nunca cria `transactions`.
- `PluggyImportService`: import/reconcile/ignore; usa o JWT do usuário; o trigger do banco grava o vínculo.

## Testes

- `pytest -q` com `httpx.MockTransport` para Supabase/Auth/Pluggy/IA.
- Cobrir: health; 401 sem token; `/me`; onboarding; dashboard (RPCs e mês inválido); CRUD de transactions (sem family_id do cliente); recorrentes confirm/ignore e compensação; metas/contribuições; forecast (regra + média); import/reconcile/ignore; admin 503 sem service role; demo restore 503 sem DB URL; AI API com fallback.
- Teste de contrato: toda chamada normal leva `Authorization` do usuário e **não** leva service role.
- `ruff`/`black` opcionais; não bloquear a v1.

## Aceite

- `python -m pytest -q` verde.
- `flask --app app run` sobe; `GET /api/health` 200; `GET /api/me` com JWT demo 200.
- Nenhum segredo no repo; `.env` ignorado.
- Endpoints documentados no README do backend.
- Modo degradado claro para Pluggy/IA/restore/Admin API.
