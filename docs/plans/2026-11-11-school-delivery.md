# VivaFinancas — plano de entrega escolar (1 semana)

**Contexto:** atividade escolar, entrega em **até 1 semana**. Não é produção nem beta real: o objetivo é entregar a v1 funcionando com **todas as integrações demonstráveis**. O prazo é um teto, não um cronograma diário: se uma etapa terminar antes, avance para a próxima.
**Base:** v1 com GO (pgTAP 497, backend 180, frontend 47, E2E desktop 5/5), commits locais.
**Público:** 1 família, com 3 testers e 3 contas Meu Pluggy (as contas dos seus beta-testers).

## Escopo

- **App web na Vercel** (`https://vivafinancas.vercel.app`) com login, painel, lançamentos, recorrentes, metas, previsão, Jev AI, extrato e configurações.
- **Supabase/Auth** com um único projeto Free; sem staging; sem backup automático; demo removida.
- **E-mail** com verificação no cadastro, convite e reset.
- **Jev AI** com OpenCode Go (classificação e sugestões estruturadas, sem chat).
- **Pluggy/Meu Pluggy** com 3 contas, connect token, widget, sync, importação e reconciliação.
- **Capacitor/APK** Android assinado, distribuído diretamente.

## Decisões

| Tema | Decisão |
|---|---|
| Backend | Vercel Services (Hobby), Flask WSGI + Vite no mesmo projeto |
| Supabase | um único projeto Free de produção; demo removida; sem staging/backup |
| E-mail | **Mailjet Free** single sender, sem domínio |
| IA | OpenCode Go (plano do usuário), `deepseek-v4.1-flash`, JSON, sem chat |
| Pluggy | **3 contas Meu Pluggy** (uma por tester/CPF); beta não comercial |
| Android | Capacitor 8.6, bundle, `com.vivafinancas.app`, APK direto |
| Escopo extra | Sem Play, sem push, sem domínio, sem staging, sem backup automático |

## Etapas (teto de 1 semana)

Sem datas fixas e sem “1 dia por tarefa”: a ordem é por dependência e cada etapa termina com um aceite. Se uma etapa terminar antes, avance para a próxima.

### Etapa 1 — Deploy base e login

- Vercel Services: `vercel.json`, entrypoint `wsgi:app`, `maxDuration`, SPA, `SEED_DIR`, health, login.
- Supabase: um projeto; `enable_signup=false`; demo removida; seed da família de teste.
- Criar em paralelo (não bloqueia esta etapa): conta **Mailjet** + remetente verificado; aplicação **Pluggy** (`clientId`/`clientSecret`); adicionar as chaves ao `hosted.env` (OpenCode Go, Pluggy, Mailjet, Supabase).
- Aceite: health 200; login; app no ar.

### Etapa 2 — Auth e e-mail (Mailjet)

- Mailjet no SMTP do Supabase; Site URL `https://vivafinancas.vercel.app`; allowlist `vivafinancas://**` e localhost.
- `Confirm Email`; templates de confirmação, convite e reset com `token_hash`/`{{ .RedirectTo }}`.
- `/auth/confirm` com `verifyOtp` (signup e recovery); `signUp` com `emailRedirectTo`; convite com `redirectTo`; reset por plataforma.
- Teste em Gmail/Outlook/iCloud; se spam, avaliar domínio (~R$ 40/ano).
- Aceite: signup → verificação → login; convite → aceite; reset no web e no app.

### Etapa 3 — OpenCode Go / Jev AI

- `OpenCodeGoAdapter`: base `https://opencode.ai/inference/go/openai/v1`, `x-opencode-session`, `User-Agent`, `response_format: json_object`, `deepseek-v4.1-flash`, timeout 60–90 s.
- Classificação e sugestões; fallback determinístico; sem página de chat.
- Aceite: “Padaria” → Alimentação; sugestões com os três campos; fallback em erro/timeout.

### Etapa 4 — Pluggy connect token + widget

- Auth `clientId`/`clientSecret` → `/auth` com cache; `POST /connect_token` com `options.clientUserId`; widget no frontend.
- Migration de `bank_connections` (`consent_expires_at`, `execution_status`, `last_updated_at`) e `bank_accounts.tipo` com `cartao`.
- Posse por vínculo token→item.
- Aceite: 1 conta Meu Pluggy conectada no trial/conector; item criado com o `clientUserId`.

### Etapa 5 — Pluggy sync/import/reconcile

- `/v2/transactions` com cursor `after` e `dateFrom`; mapear `subtype`; `DELETE /items/{id}`; webhook `POST /webhooks` com `X-Webhook-Secret` (se der tempo).
- Importar, reconciliar, ignorar e desfazer no extrato; 3 contas.
- Aceite: as 3 contas conectadas; extrato importado; reconciliação.

### Etapa 6 — Capacitor + APK

- `@capacitor/core/cli/android@8.6` + app/browser/keyboard/share/splash; `capacitor.config.json`; `build.target chrome87`; `npx cap add android`.
- CORS `https://localhost`/`capacitor://localhost`; `VITE_API_URL` HTTPS; deep link `vivafinancas://reset-password`; safe area/teclado/back; fontes locais.
- APK assinado (`assembleRelease`), keystore guardada; instalar no aparelho.
- Aceite: APK instala, login, CORS, deep link, telas principais.

### Etapa 7 — Demo, testes e documentação

- Fluxo de demonstração: login → lançamento com IA → recorrente → meta → previsão → Meu Pluggy → importar/reconciliar → tema.
- E2E/screenshots; rodar `pytest`, `npm test`, `npm run build`; corrigir os minors visíveis (contraste, flash de tema, categoria oculta).
- README com instruções e limitações; roteiro da apresentação.
- Aceite: demo de 5–10 min sem erro; evidências salvas.

### Etapa 8 — Buffer e entrega

- Buffer para o que atrasar; build final do APK; deploy final; apresentação.
- Aceite: link do app, APK, repositório, screenshots e roteiro.

## Critérios de aceite da entrega

- [ ] App na Vercel com login e Supabase.
- [ ] E-mail de verificação, convite e reset funcionando (3/3 caixas).
- [ ] Jev AI/OpenCode Go classificando e sugerindo (sem chat).
- [ ] Pluggy com 3 contas Meu Pluggy, connect token, widget, sync e import.
- [ ] APK Android instalado e funcionando.
- [ ] Testes verdes e screenshots.
- [ ] README e roteiro da apresentação.

## Riscos e fallbacks

| Risco | Fallback |
|---|---|
| Credenciais atrasam (Mailjet/Pluggy/OpenCode Go) | Criar as contas em paralelo; a Etapa 1 (deploy base e login) não depende de Mailjet/Pluggy; a IA usa o fallback até a chave entrar |
| Widget/connect token da Pluggy não fica pronto | Demo connection existente + roteiro; manter o código do connect token como evidência |
| E-mail cai em spam sem DKIM | Mailjet + teste; se falhar, domínio ~R$ 40/ano ou usar o link de convite copiável |
| APK/JDK/SDK atrasa | APK debug + web app; o bundle Capacitor fica pronto para o release |
| Meu Pluggy é pessoal/não comercial | A escola é não comercial; usar as contas dos testers e registrar o risco |
| OpenCode Go é para coding agents | Volume baixo; fallback determinístico; registrar o risco |
| 1 semana é apertado | Priorizar as integrações; cortar polish, não integração |

## O que NÃO entra

- Produção real, beta de 4–6 semanas, staging, backups/PITR, LGPD formal/DPO, CI completo, observabilidade enterprise, Play Store, push, iOS, domínio próprio.
- A demo pública (removida); a família de teste é criada para a entrega.

## Credenciais necessárias

- **OpenCode Go**: `JEV_AI_BASE_URL`, `JEV_AI_API_KEY` (você já tem).
- **Pluggy**: `PLUGGY_CLIENT_ID`, `PLUGGY_CLIENT_SECRET` (criar a aplicação).
- **Mailjet**: API Key/Secret e o remetente verificado.
- **Supabase**: URL, anon key, service role, DB URL (já tem).

Adicione ao `hosted.env`; não cole as chaves no chat.
