# VivaFinanças — backend Flask (v1)

API REST que usa o JWT do usuário em todas as leituras/escritas normais. O RLS do
Supabase é a fonte da verdade; o backend não aceita `family_id` do cliente e só
usa `member_id = auth.uid()`.

## Rodar

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r backend/requirements.txt
Copy-Item backend/.env.example backend/.env   # preencha as chaves
$env:PYTHONPATH='backend'
.\.venv\Scripts\python.exe -m flask --app app run --debug
```

`GET http://127.0.0.1:5000/api/health` responde `{"ok": true}` sem token.

```powershell
$env:PYTHONPATH='backend'
.\.venv\Scripts\python.exe -m pytest -q backend/tests
```

## Variáveis

| Variável | Uso |
|---|---|
| `SUPABASE_URL` / `SUPABASE_ANON_KEY` | Auth (`/auth/v1/user`) e PostgREST com o JWT do usuário |
| `SUPABASE_SERVICE_ROLE_KEY` | só Admin API (convite) e sync Pluggy |
| `SUPABASE_DB_URL` | só restauração da demo (pooler 6543) |
| `PLUGGY_API_KEY` / `PLUGGY_BASE_URL` | sync real; sem chave, conexão demo é no-op e conexão real retorna 503 |
| `JEV_AI_BASE_URL` / `JEV_AI_API_KEY` | Jev AI; sem chave, fallback determinístico |
| `CORS_ORIGINS` | origens do frontend, separadas por vírgula |
| `DEMO_FAMILY_ID` | família que pode chamar `/api/demo/restore` |
| `SEED_DIR` | pasta com `010`–`040` do seed |

Nenhuma chave tem valor no repositório. `backend/.env` está no `.gitignore`.

## Arquitetura

```text
app/
  __init__.py      create_app, CORS, blueprints, erros
  config.py        ambiente e defaults
  auth.py          Bearer validado em /auth/v1/user, perfil e admin
  supabase.py      SupabaseRest (JWT do usuário), AdminClient e ServiceRest
  errors.py        ApiError -> {error:{code,message,details?}}
  models/          queries PostgREST por tabela
  schemas/         validação de payload (sem query)
  blueprints/      rotas /api
  services/        painel, alertas, forecast, recorrência, IA, Pluggy, restore
```

Erros de RLS e de RPC são traduzidos:

- `42501` → 403 (exceto confirmação de ocorrência já decidida → 409)
- `23505` → 409
- `22023`/`22P02` → 422
- 0 linhas em PATCH/DELETE → 404; POST sem representação → 403

## Endpoints

| Método | Rota | Observação |
|---|---|---|
| GET | `/api/health` | público |
| GET/PATCH | `/api/me` | `profile:null` sem perfil; PATCH nome/tema |
| POST | `/api/onboarding` | RPC `onboard_family`, idempotente |
| GET | `/api/invites/mine` | convite pendente do e-mail do JWT ou `null` |
| POST | `/api/invites/accept` | RPC `accept_invite`; 409 se já tem perfil |
| GET | `/api/dashboard` | painel da família, inclui pendentes e banco |
| GET | `/api/me/summary` | totais e pendentes pessoais |
| GET | `/api/alerts` | alertas pessoais calculados |
| GET/POST | `/api/transactions` | POST manual; importação só em `/banking/import` |
| PATCH/DELETE | `/api/transactions/{id}` | identidade e vínculo imutáveis |
| GET/POST/PATCH | `/api/recurring/rules` | sem DELETE |
| GET | `/api/recurring/pending?mes=` | materializa e relê pendentes |
| POST | `/api/recurring/occurrences/{id}/confirm` | RPC atômica `confirm_occurrence` |
| POST | `/api/recurring/occurrences/{id}/ignore` | status `ignorado` |
| GET/POST | `/api/goals` | `member_id` nulo = família; pessoal = `auth.uid()` |
| PATCH/DELETE | `/api/goals/{id}` | DELETE só criador (RLS) |
| GET/POST | `/api/goals/{id}/contributions` | contribuição sempre do próprio usuário |
| GET | `/api/forecast?escopo=&meses=` | família via RPC; pessoal no backend |
| GET/POST | `/api/ai/messages` | contexto montado pelo backend |
| POST | `/api/ai/classify` | nome → categoria da família; sem match, id nulo |
| GET | `/api/ai/suggestions` | `{suggestions, mode}` |
| PATCH | `/api/ai/suggestions/{id}/read` | `{lida:true}` |
| GET/POST | `/api/banking/connections` | conexão sempre pessoal |
| DELETE | `/api/banking/connections/{id}` | Pluggy DELETE (se houver chave) e status `inativa` |
| GET | `/api/banking/accounts` | filtro `connection_id` |
| GET | `/api/banking/transactions` | `connection_id`, `status`, `mes`, paginação |
| POST | `/api/banking/sync` | valida dono pelo JWT; escreve bank tables com service role |
| POST | `/api/banking/import` | cria lançamento `origem='pluggy'` |
| GET | `/api/banking/reconcile-candidates` | valor ±0,01, data ±1 dia |
| POST | `/api/banking/reconcile` | vincula lançamento existente |
| POST | `/api/banking/ignore` / `unignore` | só status |
| GET/PATCH | `/api/admin/members` | admin; sem e-mail |
| GET/POST/DELETE | `/api/admin/invites` | Admin API + linha em `invites` |
| GET/POST/PATCH/DELETE | `/api/categories` | padrão só oculta; personalizada do criador |
| POST | `/api/demo/restore` | membro demo + `SUPABASE_DB_URL` |

## Modos degradados

- **IA**: sem `JEV_AI_*` o fallback determinístico responde com `mode:"fallback"`;
  falha externa cai para `mode:"degraded"` no mesmo request.
- **Pluggy**: sem chave, sync de conexão demo responde no-op; conexão real 503.
- **Restore**: sem `SUPABASE_DB_URL` responde 503.
- **Admin API**: sem `SUPABASE_SERVICE_ROLE_KEY` responde 503 antes da rede.
- **Conexão demo**: o dono pode ignorar/des-ignorar bank tx demo, mas a conexão em
  si é somente leitura no RLS; `DELETE /banking/connections/{id}` nela retorna 403.

### Restauração da demo e o token

O restore apaga sessões/refresh no Supabase, mas o access token é autocontido e
pode continuar válido até o `exp`. O frontend faz sign out e pede login de novo;
isso é UX, não revogação imediata do access token.

## Testes

`backend/tests` usa `httpx.MockTransport` para o Supabase, a Admin API e a Pluggy.
A suíte cobre auth, shapes do contrato, onboarding/convites, forecast, recorrência,
importação/reconciliação/ignore, 503 de admin/restore e fallback da IA. Um teste
verifica que chamadas normais levam `apikey` anon + Bearer do usuário e nunca a
service role.
