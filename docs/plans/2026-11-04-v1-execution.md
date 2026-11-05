# VivaFinanças v1 — plano de execução (fatias 1b–4)

**Data:** 2026-11-04
**Base:** fatia 1 commitada em `629fce9` (branch `fatia-1-supabase`, sem push).
**Spec:** `docs/2026-10-27-vivafinancas-brainstorming.md`.
**Contrato de banco:** `docs/2026-11-03-vivafinancas-supabase-rls-seed.md` e `supabase/README.md`.
**Gate 0:** Conditional; remediation em `docs/plans/2026-11-04-gate0-remediation.md`; migrations em `docs/plans/2026-11-04-fatia-1b-migrations.md`.
**Decisão:** full spec; DB URL no pooler `aws-1-us-west-2:6543` OK; service role Admin API OK.

## Objetivo

Entregar a v1 utilizável ponta a ponta: migrations de fechamento (fatia 1b), backend Flask + Pluggy (mock quando não há chave), frontend React com a direção “Editorial acolhedor” e Jev AI (adaptador real + fallback). O banco e o RLS da fatia 1 são a fonte da verdade; nenhuma credencial no repositório; schema novo só em migration.

## Fases e gates

| Fase | Entrega | Gate |
|---|---|---|
| 0 | Planos, preflight, revisão independente dos planos | `@oracle` antes de código (Conditional; remediation aplicada) |
| 1a | Migrations `invites`, `family_forecast`, `onboard_family`, `demo_bank_ignore` + pgTAP | `@oracle` de RLS/contrato |
| 1b | Backend Flask + Supabase REST/JWT + Pluggy mock/import/reconcile + pytest | `@oracle` de RLS/JWT/Pluggy |
| 1c | Jev AI adaptador/fallback + testes | `@oracle` de IA/modo degradado |
| 2 | Frontend React/Tailwind/Recharts + testes de componente | `@oracle` de design/API/estado |
| 3 | E2E Playwright (login/demo/import/restore) + integração | `@oracle` dos fluxos reais |
| 4 | README/env examples, validação final, go/no-go | revisor independente |

Cada gate tem uma revisão inicial e no máximo duas re-revisões, conforme `deepwork`.

## Ownership (um escritor por arquivo)

- **Orchestrator:** `docs/plans/**`, `.slim/deepwork/**`, `README.md`, `.env.example`, `.gitignore`, `.ignore`.
- **Migrations 1b:** `supabase/migrations/2026110400*.sql`, `supabase/tests/14_*`..`16_*`, ajuste de `08_rls_banking_test.sql`.
- **Backend:** `backend/**`, exceto `backend/app/services/ai/**`; `backend/tests/**`, exceto `test_ai_service*`.
- **IA:** `backend/app/services/ai/**`, `backend/tests/test_ai_service*`; entrega `base.py`/`__init__.py` antes do backend importar.
- **Frontend:** `frontend/**`, incluindo testes de componente.
- **E2E:** `tests/e2e/**`, `playwright.config.*`.

Nenhuma lane edita arquivo de outra. O contrato de API e o contrato da IA ficam nos planos; mudanças de contrato passam pelo orchestrator.

## Ambiente e credenciais

- Python 3.13, Node 26, npm 12, `psql` 18, Supabase CLI 3.0.0.
- `hosted.env`: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` e `SUPABASE_DB_URL` (pooler 6543) preenchidos; o arquivo fica fora do repo.
- Backend/frontend usam a **anon key** + JWT do usuário. Service role só Admin API/seed/sync; restore usa `SUPABASE_DB_URL` (pooler 6543, multi-statement OK).
- Sem Pluggy/Jev AI, mock/fallback; nenhuma chave inventada.
- O access token do Supabase é autocontido: o restore apaga sessões/refresh, mas o access antigo pode valer até exp; o sign out é UX, não revogação.

## Contrato de API (resumo)

Prefixo `/api`; autenticação `Authorization: Bearer <access_token do Supabase>`. Erros `{error:{code,message,details?}}`; `Prefer: return=representation` em POST/PATCH/DELETE; 0 linhas por RLS → 403/404.

- `GET /api/health` (público).
- `GET /me`; `PATCH /me` (`nome`, `tema`); `POST /onboarding` (RPC `onboard_family`, idempotente; `/me` com `profile:null`).
- `GET /dashboard?mes=YYYY-MM-01` (inclui `recorrentes_pendentes` e `acumulado`); `GET /me/summary?mes=...`; `GET /alerts`.
- `GET/POST /transactions` (sem `recurring_rule_id`/`mes_referencia` no público); `PATCH/DELETE /transactions/{id}`.
- `GET/POST /recurring/rules`; `PATCH /recurring/rules/{id}`; `GET /recurring/pending` (materializa ocorrências); `POST /recurring/occurrences/{id}/confirm|ignore`.
- `GET/POST /goals`; `PATCH/DELETE /goals/{id}`; `GET/POST /goals/{id}/contributions`.
- `GET /forecast?meses=12&escopo=familia|pessoal` (família via RPC `family_forecast`; pessoal via backend).
- `GET/POST /ai/messages`; `POST /ai/classify`; `GET /ai/suggestions`; `PATCH /ai/suggestions/{id}/read`.
- `GET/POST /banking/connections`; `DELETE /banking/connections/{id}` (status inativa; Pluggy delete se houver chave); `GET /banking/accounts`; `GET /banking/transactions`; `POST /banking/sync`; `POST /banking/import`; `POST /banking/reconcile`; `GET /banking/reconcile-candidates`; `POST /banking/ignore`.
- `GET/PATCH /admin/members`; `GET/POST/DELETE /admin/invites`; `POST /invites/accept`; `POST /auth/recover` (recover); `GET/POST/PATCH/DELETE /categories`.
- `POST /demo/restore` (somente membro demo; DB URL; recria usuários/dados; sign out UX).

## Critérios de aceite da v1

- Login/cadastro/demo; aceite de convite; painel familiar; individual; lançamentos; recorrentes; metas; previsões; Jev AI; extrato/importação/reconciliação/ignore; configurações/admin; tema claro/escuro; recuperar/trocar senha.
- RLS é a fonte da verdade; o backend não usa service role em leitura/escrita normal; nenhum endpoint aceita `family_id` do cliente; `member_id` só `auth.uid()`; `pago_por` é a exceção D7.
- `family_forecast` sem membro/descrição; convite/aceite com RLS; onboarding atômico; demo ignore só status.
- pytest verde; testes de componente verdes; E2E de login/demo/import/restore verde; suíte pgTAP antiga + nova verde; sem segredo no repo.
- O que não puder rodar é registrado com comando, entrada, saída e motivo; nada de “deve funcionar”.

## Riscos e decisões

- **Pooler 6543:** transaction mode; o restore usa uma transação por conexão e foi testado com `begin/rollback`; não usar session features.
- **Convite:** Admin API cria o auth user e envia e-mail; a linha `invites` é criada pelo admin; o convidado aceita via RPC. Sem service role, 503.
- **Forecast:** estimativa rotulada; família só agregados; pessoal pode detalhar.
- **Demo ignore:** exceção de status; raw continua bloqueado; documentar.
- **Recorrentes:** materialização idempotente; confirmação com compensação; unique impede duplicata.
- **Pluggy sem chave:** mock/demo; sync real 503.
- **Jev AI sem chave:** fallback; modo degradado visível.
- **Lockout do vínculo bancário:** o dono da conexão controla o vínculo; documentado na fatia 1.
- **E2E:** restaura a demo ao final via `/api/demo/restore`; se o pooler cair, registrar one-shot.
- **Frontend/backend local:** Vite 5173, Flask 5000; CORS/proxy.
