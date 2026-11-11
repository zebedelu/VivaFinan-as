# VivaFinancas — frontend

React 18 + Vite + Tailwind 4 + Recharts + Supabase JS. O app fala com o Supabase Auth e com a API Flask.

## Rodar

```powershell
npm install
Copy-Item .env.example .env.local
npm run dev
```

## Env

- `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY`: Auth e cliente Supabase. A anon key é pública; a service role nunca entra aqui.
- `VITE_API_URL`: base da API Flask. Default no código: `http://localhost:5000/api`; o `.env.production` define `/api` (Flask no mesmo domínio, via Vercel).

Sem as duas primeiras o app compila, mas não autentica: não é artefato de deploy.
`vite.config.js` tem um guard: se alguma das três `VITE_*` faltar, o build falha na
Vercel (`VERCEL=1`) e em CI (`CI`). Localmente ele só avisa; `VITE_ENV_GUARD=strict`
força a falha e `VITE_ENV_GUARD=off` desliga.

## Testes

```powershell
npm test          # Vitest/RTL, 47 testes
npm run build     # build de produção
```

## E2E

Pré-requisitos: backend na 5000, frontend na 5173 e demo no baseline.

```powershell
npx playwright test e2e/v1.spec.js --project=desktop
npx playwright test e2e/v1.spec.js --project=mobile -g "painel"
```

O spec usa navegação SPA (clica nos links do menu), restaura a demo no fim e salva screenshots em `e2e-artifacts/` (ignorado no git). Se um run falhar no meio, rode o restore antes de repetir.

## Estrutura

- `src/pages`: login, onboarding, convite, reset, painel, individual, lançamentos, recorrentes, metas, previsões, Jev AI, extrato, configurações.
- `src/components`: layout, gráficos, tabelas, modais e estados.
- `src/hooks`, `src/services`, `src/lib`: sessão, API (token em cache), tema, mês e formatação.
- `e2e`: specs Playwright.
