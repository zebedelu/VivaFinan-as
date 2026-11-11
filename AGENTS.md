# AGENTS.md

VivaFinancas: React SPA + Flask API over a hosted Supabase/Postgres project with RLS. Windows/PowerShell is the documented shell.

## Layout

- `backend/` — Flask API (`app/`), pytest suite. Entrypoint `backend/wsgi.py`; app factory `app.create_app`.
- `frontend/` — React 18 + Vite + Tailwind 4 SPA (`src/`), Vitest/RTL, Playwright in `e2e/`.
- `supabase/` — migrations, demo seed (`seed/010`–`040`), pgTAP tests, optional CLI scripts.
- `docs/plans/2026-11-04-v1-contract.md` — canonical API/behavior contract; slice plans are historical where they conflict.

## Commands

Backend (`.venv` lives at repo root; `PYTHONPATH=backend` is required or `app` is not importable):

```powershell
$env:PYTHONPATH='backend'
.\.venv\Scripts\python.exe -m pytest -q backend/tests          # 216 tests, fully mocked (no network/Supabase)
.\.venv\Scripts\python.exe -m flask --app app run --port 5000  # health: GET /api/health
```

Frontend:

```powershell
cd frontend
npm test                  # Vitest, 59 tests, e2e excluded by vite.config.js
npm run build
npm run dev               # port 5173
```

There is no lint/typecheck script, no CI workflow, and no deploy config. Do not assume `ruff`/ESLint exists.

## E2E

Requires real services: backend on `:5000`, frontend on `:5173`, `frontend/.env.local`, demo at baseline, and system Chrome (Playwright config uses `channel: "chrome"`).

```powershell
cd frontend
npx playwright test e2e/v1.spec.js --project=desktop
npx playwright test e2e/v1.spec.js --project=mobile -g "painel"
```

The spec is serial and mutates the hosted demo (creates a transaction, confirms/imports, then restores the demo in the last test). If a run fails midway, restore the demo before rerunning.

## Database work

- Hosted project `pqxfeyuutkkqavhnysus`, Postgres 17. Apply each file in `supabase/migrations/` once, in filename order, via Supabase MCP `apply_migration`; seed and tests via `execute_sql`.
- `supabase test db` needs a Docker container on Windows. The working harness is the Supabase MCP, with TAP captured into a temp table (`supabase/README.md`). Optional `pg_prove` scripts require `%USERPROFILE%\.config\vivafinancas\hosted.env`.
- `supabase db reset --remote` wipes the hosted demo project and needs `VIVAFINANCAS_ALLOW_REMOTE_RESET=yes`; do not run it without explicit user approval.
- Seed `010`–`040` is idempotent (deletes and recreates demo data). Demo restore deletes/recreates Auth users, so old access tokens remain valid until `exp`; the frontend signs out and asks for login again.
- Canonical status values and RLS rules are listed in `supabase/README.md`; reuse them instead of inventing variants.

## Invariants

- RLS is the access-control source of truth. Normal backend calls use the user JWT + anon key (`SupabaseRest`); the service role is limited to the Auth Admin API (invites) and Pluggy sync; demo restore uses `SUPABASE_DB_URL`.
- The backend never accepts `family_id` from the client. `member_id` can only be `auth.uid()` (except the documented `pago_por` family case).
- Missing credentials are contract, not bugs: no `JEV_AI_API_KEY` → deterministic fallback (`mode:"fallback"`); no `PLUGGY_API_KEY` → real Pluggy 503, demo no-op; no service role → admin/invite 503; no `SUPABASE_DB_URL` → restore 503.
- `transactions` with `origem='pluggy'` require `bank_transaction_id`; bank transactions never create transactions automatically; link changes are guarded by `tg_guard_transaction_bank_link`.
- PATCH on transactions cannot change identity/link fields; reconciliation goes through `/banking/reconcile`.
- Dashboard/summary can take ~20 s on hosted Supabase because RPCs run serially; known/backlogged, not a regression.

## Demo

Ana (admin), Carlos, Lucas — `Demo@2026!`, e-mails `*@demo.vivafinancas.app`; family id `eeeeeeee-0000-4000-8000-000000000001`.
