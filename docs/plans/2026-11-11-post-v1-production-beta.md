# VivaFinancas — plano pós-v1: produção, beta e Capacitor

**Status:** **CONDICIONAL** — gate final @oracle. As decisões de plataforma (Supabase Free com **um único projeto de produção**, Meu Pluggy múltiplo, e-mail single sender) estão incorporadas; faltam a escolha do provedor de e-mail e as respostas de beta/demo.
**Data:** 2026-11-11
**Objetivo:** levar a v1 (Flask + React + Supabase + Jev AI) para produção com um beta fechado de 5–10 famílias, incluindo o app Android via CapacitorJS e um APK distribuído diretamente.
**Base:** v1 com GO (pgTAP 497, backend 180, frontend 47, E2E desktop 5/5), commits locais sem push.
**Fora do escopo:** Play Store, push notifications, iOS, domínio próprio do app, Pluggy em escala.

## Condições do gate final

| ID | Condição | Como o plano fecha |
|---|---|---|
| C1 | Supabase Free com **um projeto**, sem staging e sem backup/PITR | produção única; demo oculta/removida; sem backup automático; `pg_dump` manual opcional; **risco aceito** |
| C2 | Signup/onboarding abertos, apesar de “invite-only” | `enable_signup=false` no hosted; `/onboarding` gated; demo oculta/removida do build de produção |
| C3 | IA de sugestões dentro do `/dashboard` (pode travar até 90 s) | sugestões fora do request; `/dashboard` mede p95 sem IA; Fase 6 re-mede com IA |
| I1 | Rate limit sem store compartilhado; 5xx/429 do Auth viram 401 | Upstash Redis + Flask-Limiter; 5xx/429/timeout → 503/429, sessão preservada; Fase 1 |
| I2 | CI com “pgTAP via MCP” não roda em runner | `supabase test db` em runner Linux com Docker (ou psql + pgTAP) |
| I3 | Pluggy: webhook ambíguo, migrations faltando, posse sem `clientUserId`, termos do Meu Pluggy | `POST /webhooks` + `X-Webhook-Secret`; migrations; vínculo connect token→item; Meu Pluggy com risco registrado/confirmação |
| I4 | E-mail single sender sem DKIM; redirects incompletos | melhor single sender; 3/3 caixas; `{{ .RedirectTo }}`; `/auth/confirm` com recovery; `nome_familia` no metadata |
| I5 | Exclusão de conta bloqueada por FKs `restrict` | migration/estratégia de anonimização ou transferência antes de apagar o Auth |
| I6 | Expurgo de 90 dias esbarra em FKs; logs da Vercel Hobby duram 1 h | colunas/linhas definidas; sem payload bruto; Sentry como log durável |
| I7 | OpenCode Go é “coding agents”; ZDR do DeepSeek vence em 30/11/2026 | risco aceito para volume baixo; fallback pay-as-you-go/provider direto; região Global |
| I8 | APK sem versão mínima, sem backup da upload key, fontes externas | `X-App-Version`/versão mínima; backup da keystore; fontes locais; teste em aparelho real |

## Decisões fechadas

| Tema | Decisão |
|---|---|
| Backend | Vercel Services (Hobby), Flask WSGI + Vite no mesmo projeto |
| URL do app | `https://vivafinancas.vercel.app` |
| Capacitor | Bundle estático, Android, `com.vivafinancas.app` |
| Distribuição | APK direto (Drive/WhatsApp); sem Play; push depois |
| E-mail | **single sender sem domínio**; provedor definido pela pesquisa (Brevo/SendGrid/outro) |
| Supabase | **Free com um único projeto de produção**; sem staging; demo oculta/removida; sem backup; `pg_dump` manual opcional; risco aceito |
| Pluggy | **várias contas Meu Pluggy** (uma por tester/CPF); beta gratuito/não comercial; risco de termos registrado; confirmação com a Pluggy; fallback trial/pago |
| IA | OpenCode Go (plano Go aceito), classificação/sugestões estruturadas, sem chat, fora do request |
| Beta | 5–10 famílias, 3 com Meu Pluggy, 4–6 semanas, invite-only |
| LGPD | termos/privacidade, consentimento, export/delete, retenção, DPO |

## Arquitetura alvo

- **Vercel Services**: `frontend/` (Vite) e `backend/` (Flask WSGI) no mesmo projeto; `/api` na mesma origem, sem CORS no caminho normal. Hobby: 300 s por função; logs de 1 h.
- **Supabase**: **um único projeto Free de produção**; sem staging; migrations testadas via pgTAP/MCP antes de aplicar; demo oculta/removida; sem backup automático/PITR; `pg_dump` manual opcional. Auth com SMTP do provedor single sender; RLS como fonte da verdade.
- **E-mail**: provedor single sender escolhido pela pesquisa (candidatos: Brevo 300/dia, SendGrid 100/dia); `Confirm Email` ligado; templates com `token_hash` e `{{ .RedirectTo }}`; convite via Admin API com `redirectTo`; reset com redirect por plataforma e deep link `vivafinancas://reset-password`.
- **IA**: `OpenCodeGoAdapter` sobre `https://opencode.ai/inference/go/openai/v1`, `Authorization: Bearer oc_sk_...`, `x-opencode-session` estável, `response_format: json_object`, `deepseek-v4.1-flash`, timeout 60–90 s, fallback determinístico. Sugestões fora do `/dashboard`.
- **Android**: Capacitor 8.6, Android SDK 36, minSdk 24, JDK 21; bundle do `dist`, deep links, CORS para `https://localhost` e `capacitor://localhost`, safe area, teclado e back; APK assinado distribuído diretamente.
- **Operação**: Sentry web/api (log durável), logs com `request_id`, rate limit no Upstash, `pg_dump` manual, CI e rollback.

## Fases

### Fase 0 — Spikes e preflight (≈1–2 semanas)

- **Supabase único**: usar o projeto hosted como produção; **remover ou ocultar a demo** (a decidir); sem staging; migrations testadas via pgTAP/MCP; combinar `pg_dump` manual semanal (opcional) e aceitar a ausência de backup automático.
- **Invite-only**: `enable_signup=false`; gate de `/onboarding`; demo fora do build de produção.
- **Dashboard + IA**: remover `generate_suggestions` do `/dashboard` (`backend/app/services/panel.py`); criar endpoint/cache de sugestões; medir p95 sem IA.
- **OpenCode Go**: chamar `/openai/v1/chat/completions` com `x-opencode-session`, `deepseek-v4.1-flash`, JSON; medir custo/latência; confirmar região Global.
- **E-mail**: pesquisa do melhor single sender (Brevo/SendGrid/outro); criar conta, verificar o remetente, configurar SMTP no Supabase e testar Gmail/Outlook/iCloud.
- **Pluggy**: abrir a aplicação Pluggy (`clientId`/`clientSecret`); registrar o risco dos termos do Meu Pluggy e confirmar com a Pluggy; fallback trial/pago.
- **Android**: smoke de toolchain (~1 dia): `cap add android`, APK debug, CORS de `https://localhost`, JDK/SDK/AGP.

**Aceite:** cada spike com evidência (comando, saída, latência, custo) e decisão registrada.

### Fase 1 — Deploy na Vercel + invite-only (≈3–5 dias)

- `vercel.json` com Services: `frontend` (Vite) e `backend` (Flask, entrypoint `wsgi:app`).
- `backend/.python-version` **3.13**; separar `requirements.txt` (runtime) de `requirements-dev.txt`.
- Copiar `supabase/seed/010`–`040` para `backend/seed/`; `SEED_DIR=seed`; teste de deriva.
- `VITE_API_URL=/api` no web; `CORS_ORIGINS` com o domínio de produção e localhost.
- `maxDuration` 300; rewrite SPA; **sem** `SUPABASE_DB_URL`/restore em produção; Deployment Protection no Preview.
- **Invite-only**: `enable_signup=false`; `/onboarding` gated; demo oculta/removida; teste de usuário anônimo.
- **5xx/429→401**: mapear 5xx/429/timeout do Auth para 503/429; o frontend não desloga nesses casos.
- Build falha se `VITE_*` obrigatórias faltarem.
- Preview com o banco de produção: restringir a leitura/demo; não rodar E2E que muta contra a produção.

**Aceite:** build dos dois serviços; health 200; login demo (no ambiente demo local); deep link SPA; anônimo não cria família; 5xx do Auth não derruba sessão.

### Fase 2 — Operação e segurança (≈3–5 dias)

- Sentry web/api com `send_default_pii=False`; logs com `request_id`; Sentry como log durável (Hobby: 1 h).
- Rate limit com **Upstash Redis** + Flask-Limiter: `/api/ai/*` 10/min, `/banking/sync` 2/min, mutações 60/min, global 300/min; 429 no formato da API.
- Headers/CSP na Vercel e no Flask; `Cache-Control: no-store` em respostas autenticadas.
- **Sem backup automático**: documentar o risco; combinar `pg_dump` manual semanal para um storage externo (opcional) e um drill de restore manual.
- **Sem staging**: CI com pytest, vitest, build e **`supabase test db` em runner Linux/Docker**; migrations testadas antes de aplicar; branch protection.
- Migrations expand/contract; proibir migration destrutiva durante o beta.

**Aceite:** alerta de 5xx/p95; 401 só para token inválido; 429 preserva sessão; `pg_dump` manual testado (se adotado); CI verde.

### Fase 3 — E-mail e Auth (≈3–5 dias)

- Provedor single sender definido pela pesquisa; `from` no remetente verificado; se a entrega falhar, reavaliar domínio.
- Site URL `https://vivafinancas.vercel.app`; allowlist `https://vivafinancas.vercel.app/**`, `http://localhost:5173/**`, `vivafinancas://**`.
- `Confirm Email` ligado; templates de confirmação, convite e reset com `token_hash` e `{{ .RedirectTo }}`.
- `signUp` com `emailRedirectTo`; nova rota `/auth/confirm` com `verifyOtp` para `signup` e **`recovery`** (next `/reset-password`); guarda contra StrictMode.
- Convite: Admin API com `redirectTo` para `/invite/<token>`; a tela de aceite define a senha.
- Reset: redirect por plataforma (`window.location.origin` no web, `vivafinancas://reset-password` no app).
- `nome_familia` no metadata do `signUp` para não pedir duas vezes.

**Aceite:** signup → verificação → login; convite → aceite com senha; reset no web e no app; 3/3 caixas inbox.

### Fase 4 — Agendamento e retenção (≈2–3 dias)

- `pg_cron` no Supabase para materializar recorrências do mês e expurgar dados conforme a política.
- Retenção em linhas/colunas: `bank_transactions` normalizadas (sem payload bruto), `ai_messages`, logs via Sentry. Resolver as FKs `restrict` (vínculo com `transactions`) antes do expurgo.
- Sync Pluggy agendado via `/api/cron/*` com `CRON_SECRET` ou pg_cron; idempotência e log.

**Aceite:** job idempotente com log; expurgo não quebra FKs; nada de trabalho longo no request.

### Fase 5 — Pluggy real com Meu Pluggy (≈5–10 dias)

- **Decisão:** **várias contas Meu Pluggy**, uma por tester (CPF); o app cria um item por pessoa via conector **MeuPluggy** no widget; o backend guarda um `itemId` por usuário. O beta é gratuito e não comercial.
- **O que não é possível:** uma única conta Meu Pluggy agregar as contas bancárias dos amigos. As 5 conexões são do próprio titular; conectar a conta de outra pessoa exigiria as credenciais/consentimento dela e violaria os termos. Cada tester precisa da própria conta (3 testers = 3 contas).
- **Risco registrado:** a doc do Meu Pluggy é “personal use only, no commercial use”; empresas que constroem produto seguem a integração regular. O beta é gratuito/invite-only, mas a confirmação com a Pluggy é necessária; fallback: trial de 15 dias ou plano pago.
- Auth: `clientId` + `clientSecret` → `POST /auth` com cache do `apiKey` (2 h) e refresh no 401.
- `POST /connect_token` com `options.clientUserId`, `avoidDuplicates`; widget no frontend; guardar o vínculo token→item.
- `DELETE /items/{id}`; `GET /v2/transactions` com cursor `after`, paginação e `dateFrom`; mapear `subtype` (BANK/CREDIT/CREDIT_CARD) e adicionar `cartao` ao check.
- Webhook: **`POST /webhooks`** com `headers: {X-Webhook-Secret}` (não usar `webhookUrl` com header); tratar como sinal e reler `GET /items/{id}`.
- Migration: `bank_connections` com `consent_expires_at`, `execution_status`, `last_updated_at`; `bank_accounts.tipo` com `cartao`.
- Posse: só aceitar item criado pelo nosso connect token; item sem `clientUserId` (criado no dashboard) recebe mensagem clara, não 403 permanente.

**Aceite:** conectar 1 conta Meu Pluggy; sync incremental; revogação via `DELETE /items`; webhook autenticado; cartão não vira corrente.

### Fase 6 — OpenCode Go / Jev AI (≈2–4 dias)

- `OpenCodeGoAdapter` implementando `AIAdapter`; base `https://opencode.ai/inference/go/openai/v1`; `Authorization: Bearer oc_sk_...`; `x-opencode-session` estável; `User-Agent` próprio; timeout 60–90 s.
- Classificação e sugestões com `response_format: json_object`, `temperature: 0`, `max_tokens` baixo; reusar `resolve_category`, `normalize_categories` e o fallback.
- **Sugestões fora do `/dashboard`**: endpoint/cache; o dashboard lê o cache. p95 do dashboard re-medido com o provedor ligado.
- Remover a página de chat ou transformá-la em “Insights” com assistente local determinístico.
- Rate limit/orçamento; PII mínima (descrição do estabelecimento); DeepSeek V4.1 Flash tem ZDR até 30/11/2026 — reconfirmar; fallback é o padrão sem chave.

**Aceite:** classificação JSON válida; sugestões com os três campos; falha/timeout cai no fallback; dashboard p95 inalterado com IA.

### Fase 7 — LGPD e operação do beta (≈3–5 dias)

- Páginas de termos, privacidade e segurança; consentimento granular; registro de versão/data.
- Exportação JSON/CSV e exclusão de conta/família: resolver as FKs `restrict` (anonimizar/transferir) com migration; admin exclui família com confirmação e exportação prévia.
- Retenção implementada; encarregado/contato; playbook de incidentes; RIPD leve.
- Feedback in-app (tipo, texto, página, versão) e analytics sem PII; Sentry para crashes; sem session replay.
- Beta invite-only, 5–10 famílias, 3 com Meu Pluggy; WhatsApp/email; releases semanais; métricas de ativação/retenção/p95/erros.
- Corrigir os minors visíveis da v1: contraste da barra de progresso, flash de tema, categoria oculta no select. **Decidido: antes do beta.**

**Aceite:** termos/privacidade publicados; export/delete funcionando; retenção agendada; beta com métricas e canal de suporte.

### Fase 8 — Capacitor Android e APK (≈5–8 dias)

- `@capacitor/core/cli/android@8.6`, `@capacitor/app`, `browser`, `keyboard`, `share`, `splash-screen`; `capacitor.config.json` com `appId com.vivafinancas.app`, `webDir dist`, `SystemBars`, `Keyboard`, Splash.
- `build.target: ['chrome87']`; `npx cap add android`; commitar `frontend/android/` (sem `build/`, `local.properties`, keystore).
- `VITE_API_URL=https://vivafinancas.vercel.app/api` no build do APK; `VITE_PUBLIC_APP_URL`; helper `urls.js` com `authRedirectUrl`.
- CORS da API com `https://localhost` e `capacitor://localhost`; teste de preflight com `Authorization`.
- Deep link `vivafinancas://reset-password` no `AndroidManifest.xml`; `appUrlOpen` e `getLaunchUrl`.
- Safe area (`SystemBars`, `pt-safe`/`pb-safe`), teclado (`adjustResize`), back button, tema escuro, ícones/splash, fontes empacotadas localmente.
- Assinatura: upload key + `keystore.properties` fora do git; **backup da upload key**; `gradlew assembleRelease`; `apksigner`/`zipalign`; distribuição direta.
- Versão: `X-App-Version` nas chamadas e `min_app_version` para bloquear app antigo com mensagem de atualização manual (sem Play).

**Aceite:** APK instala em API 24 e 36; login demo; CORS ok; deep link de reset em cold start; safe area/teclado/back; APK assinado; keystore guardada; aparelho real de entrada testado.

### Fase 9 — Hardening e lançamento do beta (≈2–3 dias)

- Load test do dashboard e login; drill de restore de `pg_dump`; drill de rollback na Vercel.
- CSP em report-only e depois enforce; auditoria de dependências; revisão de segredos.
- Go/no-go do beta: sem P1 nas últimas 2 semanas, restore/dump testado (se adotado), LGPD mínima publicada, export/delete funcionando, APK assinado.

## Beta fechado

- **Público:** 5–10 famílias convidadas; 3 com Meu Pluggy; sem cadastro aberto.
- **Duração:** 4–6 semanas; releases semanais; hotfix quando necessário.
- **Canais:** WhatsApp para anúncios/incidentes; e-mail para conta/privacidade; formulário in-app para bugs.
- **Métricas:** ativação (família + 3 lançamentos em 7 dias), retenção W4, p95 do dashboard, 5xx, crash-free, feedback por família.
- **Gates:** 6 famílias ativas por 4 semanas, ativação ≥ 60%, retenção ≥ 40%, zero P1.
- **Sem Play:** APK direto; sem 12 testadores/Data safety; privacidade e exclusão de conta continuam necessárias por LGPD.

## Riscos

| Risco | Impacto | Mitigação |
|---|---|---|
| Supabase Free, um projeto, sem staging/backup | Migration/E2E direto na produção; perda de dados | pgTAP/MCP antes; `pg_dump` manual opcional; risco aceito |
| Meu Pluggy pessoal/não comercial | Uso bloqueado pela Pluggy | Beta gratuito/não comercial; confirmação; fallback trial/pago |
| Signup/onboarding abertos | Qualquer um cria família e gasta IA | `enable_signup=false`; onboarding gated |
| IA no request do dashboard | Primeiro acesso do dia pode travar 90 s | Sugestões fora do request; p95 medido |
| E-mail single sender | Spam bloqueia login/reset | Melhor provedor; 3/3 caixas; domínio se falhar |
| OpenCode Go fora do perfil | Throttling/bloqueio | Volume baixo; fallback; ZDR até 30/11 |
| APK sideload | Instalação/segurança | Assinatura; keystore guardada; versão mínima |
| LGPD/consentimento | Risco legal | Termos, export/delete, retenção, DPO |
| Demo no banco de produção | Credenciais públicas no banco real | Remover/ocultar a demo; invite-only |
| Suporte pequeno | Testers sem resposta | WhatsApp/email, SLA 1 dia útil |

## Pendências

1. **Demo no único banco de produção**: remover, manter oculta ou manter visível? A recomendação é remover (seed só local).
2. **Datas e orçamento do beta**: início, duração e o custo do OpenCode Go (~US$ 10/mês); o resto é free.
3. **Tamanho do beta**: 5–10 famílias?
4. **Confirmação dos termos do Meu Pluggy**: o beta é gratuito/não comercial; confirmar com a Pluggy (sales@pluggy.ai/Discord). O fallback é o trial de 15 dias ou o plano pago.
5. **Provedor de e-mail single sender**: pesquisa em andamento (Brevo/SendGrid/outro).

## Go/no-go

**CONDICIONAL.** O beta fica viável quando: (1) a demo no banco único estiver decidida (removida/oculta) e o risco de não ter staging/backup registrado; (2) signup fechado e onboarding gated com evidência; (3) sugestões fora do dashboard e p95 re-medido; (4) webhook da Pluggy escolhido e migrations de consentimento/tipo aplicadas; (5) termos do Meu Pluggy confirmados (ou fallback trial/pago); (6) rate limit com store compartilhado; (7) CI com `supabase test db` executável; (8) provedor de e-mail testado em 3/3 caixas.

## Referências

- Contrato v1: `docs/plans/2026-11-04-v1-contract.md`
- Execução v1: `docs/plans/2026-11-04-v1-execution.md`
- Backlog v1: `docs/plans/2026-11-04-v1-backlog.md`
- Relatório v1: `docs/plans/2026-11-04-v1-report.md`
- Vercel Services/Flask: https://vercel.com/docs/services · https://vercel.com/docs/frameworks/backend/flask
- Supabase backups: https://supabase.com/docs/guides/platform/backups · https://supabase.com/pricing
- Capacitor 8: https://capacitorjs.com/docs/updating/8-0 · https://capacitorjs.com/docs/guides/deep-links
- Pluggy: https://docs.pluggy.ai/en/docs/authentication · https://docs.pluggy.ai/en/docs/connect-widget/oauth-support · https://docs.pluggy.ai/en/docs/developer-tools/webhooks-ref
- Supabase Auth/SMTP: https://supabase.com/docs/guides/auth/auth-smtp · https://supabase.com/docs/guides/auth/auth-email-templates
- OpenCode Go: https://opencode.ai/docs/console/go/ · https://opencode.ai/docs/console/api/inference
