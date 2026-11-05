# VivaFinancas

Finanças da família em uma página: painel do mês, lançamentos, contas recorrentes, metas, previsão de 12 meses, Jev AI e extrato bancário (demo).

## Stack

- **Banco**: Supabase/Postgres 17.11 com RLS por membro, Auth e RPCs (`family_forecast`, `onboard_family`, `accept_invite`, `confirm_occurrence`).
- **Backend**: Flask. Toda leitura/escrita normal usa o JWT do usuário no PostgREST e o RLS decide; a service role fica restrita à Admin API de convite e ao sync Pluggy; o restore da demo usa `SUPABASE_DB_URL`.
- **Frontend**: React 18 + Vite + Tailwind 4 + Recharts + Supabase JS, com tema claro/escuro e layout mobile-first.
- **Jev AI**: adapter HTTP (`JEV_AI_*`) com fallback determinístico quando não há chave.
- **E2E**: Playwright em desktop (1280) e mobile (390).

## Estrutura

```
backend/     API Flask, serviços e testes pytest
frontend/    SPA React, testes Vitest e E2E Playwright
supabase/    migrations, seed demo e testes pgTAP
docs/plans/  contrato da v1, planos das fatias e backlog
```

## Banco

- Projeto: `pqxfeyuutkkqavhnysus` (Postgres 17.11); branch local `fatia-1-supabase`.
- Migrations: schema/RLS da fatia 1a + invites, `family_forecast`, `onboard_family`, demo ignore, `confirm_occurrence`, dedup de IA e `invites.auth_user_id` na 1b.
- Testes: 20 arquivos pgTAP, **497 asserções**; seed `010`–`040` idempotente (6 meses, 91 lançamentos, 3 metas, 4 sugestões de IA, 1 conexão/8 transações bancárias).
- Harness e notas: [supabase/README.md](supabase/README.md).

## Demo

Ana (admin), Carlos e Lucas — `Demo@2026!`, e-mails `*@demo.vivafinancas.app`.

## Backend

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r backend/requirements.txt
Copy-Item backend/.env.example backend/.env   # preencha as chaves
$env:PYTHONPATH='backend'
.\.venv\Scripts\python.exe -m flask --app app run --port 5000
```

`GET http://127.0.0.1:5000/api/health` responde `{"ok":true}`. Com `$env:PYTHONPATH='backend'`, os testes rodam com `pytest -q backend/tests` (**180**).

## Frontend

```powershell
cd frontend
npm install
Copy-Item .env.example .env.local   # VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY, VITE_API_URL
npm run dev
```

Testes: `npm test` (**47**). Build: `npm run build`.

## E2E

Pré-requisitos: backend na 5000, frontend na 5173 e demo no baseline. O spec restaura a demo no fim; se um run falhar no meio, rode o restore antes de repetir.

```powershell
cd frontend
npx playwright test e2e/v1.spec.js --project=desktop          # 5/5
npx playwright test e2e/v1.spec.js --project=mobile -g "painel"
```

Cobre login e tema persistente, criar lançamento com categoria sugerida, confirmar recorrente, importar/ignorar/desfazer transação do extrato demo, restaurar a demonstração e voltar ao login. Screenshots em `frontend/e2e-artifacts/`.

## Modos degradados

- Sem `JEV_AI_API_KEY`: fallback determinístico; a classificação usa palavra-chave e as sugestões não inventam números.
- Sem `PLUGGY_API_KEY`: conexão real desabilitada (503); a conexão e as transações demo continuam.
- Sem `SUPABASE_SERVICE_ROLE_KEY`: convites/admin respondem 503; o resto funciona.
- Sem `SUPABASE_DB_URL`: restore responde 503.
- Sem `VITE_SUPABASE_*`: o app compila mas não autentica — não é artefato de deploy.

## Evidência da v1

- pgTAP 497/497; backend 180/180; frontend 47/47 + build; E2E desktop 5/5 e mobile 1/1; demo restaurada ao baseline (15 lançamentos, saldo 6.913).
- Contrato canônico: [docs/plans/2026-11-04-v1-contract.md](docs/plans/2026-11-04-v1-contract.md). Backlog e limitações: [docs/plans/2026-11-04-v1-backlog.md](docs/plans/2026-11-04-v1-backlog.md).

## Limitações conhecidas

- Pluggy real não habilitada (sem chave/widget); o fluxo demo é completo.
- O dashboard pode levar ~20 s no Supabase hospedado por causa das RPCs em série — otimização no backlog.
- O restore apaga e recria os usuários Auth; sessões antigas podem valer até expirar, então entre de novo.
- Desconectar a conexão demo retorna 403 por RLS somente leitura; documentado no backend.
