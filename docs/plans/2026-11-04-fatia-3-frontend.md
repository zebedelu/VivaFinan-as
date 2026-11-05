# Fatia 3 — Frontend React (v1)

> **Contrato canônico:** `docs/plans/2026-11-04-v1-contract.md` + `2026-11-04-gate0-remediation.md` + `2026-11-04-fatia-1b-migrations.md` vencem este plano onde houver conflito. As seções abaixo são históricas; a lane deve seguir o contrato canônico.

**Data:** 2026-11-04
**Depende de:** fatia 1 (`629fce9`) e contrato da fatia 2 (`docs/plans/2026-11-04-fatia-2-backend-pluggy.md`).
**Spec:** `docs/2026-10-27-vivafinancas-brainstorming.md` (§2.3, §3, §5).

## Objetivo

SPA React/Vite que entrega os fluxos da v1 no navegador: login/cadastro/demo, painel familiar, página individual, lançamentos, recorrentes, metas, previsões, Jev AI, extrato/importação/reconciliação, configurações/admin e tema claro/escuro. Mobile-first, com a direção “Editorial acolhedor”.

## Stack

- Vite + React (JavaScript/JSX), React Router, Tailwind CSS, Recharts, `@supabase/supabase-js`.
- Ícones `lucide-react`; sem biblioteca de UI pesada.
- Testes: Vitest + React Testing Library + jsdom.
- E2E na fase 3: Playwright contra Vite + Flask + Supabase hospedado.

## Configuração

`frontend/.env.example`:

```text
VITE_SUPABASE_URL=
VITE_SUPABASE_ANON_KEY=
VITE_API_URL=http://localhost:5000/api
```

O `.env.local` fica fora do git. A anon key é pública; a service role nunca entra no frontend.

## Direção visual

- Cores: verde institucional `#1F4D3A`; fundo areia `#F4EFE6`; superfície `#FBF8F2`; texto grafite `#22201D`; terracota `#C46A4A` (despesa/alerta); dourado `#C9A227` (metas).
- Tipografia: Fraunces nos títulos e no saldo; IBM Plex Sans no corpo, formulários e navegação; números com `font-variant-numeric: tabular-nums`.
- Layout: mobile-first; navegação inferior com Início, Lançamentos, Extrato e Mais; botão “+” sempre visível; desktop com sidebar à esquerda e conteúdo até 1200px.
- Cartões com borda de 1px, raio 12px, sombra discreta; sem gradientes roxos, sem excesso de badges.
- “Caderno de contas”: linhas finas nos gráficos, réguas discretas nas listas, valores alinhados à direita.
- Tema claro/escuro via `data-theme` no `<html>`; persistido em `profiles.tema` e localStorage; contraste verificado.

## Rotas

| Rota | Página | Protegida |
|---|---|---|
| `/login` | Login/cadastro/demo | não |
| `/` | Painel familiar | sim |
| `/individual` | Página do membro | sim |
| `/transactions` | Lançamentos | sim |
| `/recurring` | Recorrentes | sim |
| `/goals` | Metas | sim |
| `/forecast` | Previsões | sim |
| `/ai` | Jev AI | sim |
| `/banking` | Extrato bancário | sim |
| `/settings` | Configurações/admin | sim |

`ProtectedRoute` redireciona para `/login` sem sessão. O login demo chama `signInWithPassword` com as credenciais do README.

## Estrutura

```text
frontend/
  index.html
  package.json
  vite.config.js
  src/
    main.jsx
    App.jsx
    styles.css                 # tokens, base, tema, utilitarios
    lib/supabase.js
    services/api.js            # fetch com Bearer + erros
    hooks/useSession.js
    hooks/useApi.js
    hooks/useTheme.js
    hooks/useMonth.js
    components/
      AppShell.jsx
      Sidebar.jsx
      BottomNav.jsx
      ProtectedRoute.jsx
      Card.jsx
      StatCard.jsx
      Money.jsx
      LineChart.jsx
      DonutChart.jsx
      ProgressBar.jsx
      Modal.jsx
      FormField.jsx
      Button.jsx
      Badge.jsx
      AlertList.jsx
      MemberAvatars.jsx
      GoalCard.jsx
      SuggestionCard.jsx
      RecurringCard.jsx
      TransactionTable.jsx
      BankTxTable.jsx
      PluggyConnect.jsx
      Toast.jsx
      EmptyState.jsx
      Loading.jsx
    pages/
      Login.jsx
      Dashboard.jsx
      Individual.jsx
      Transactions.jsx
      Recurring.jsx
      Goals.jsx
      Forecast.jsx
      JevAI.jsx
      Banking.jsx
      Settings.jsx
    test/
      setup.js
      *.test.jsx
```

## Integração

- `services/api.js`: `apiFetch(path, {method, body})`; pega o `access_token` da sessão Supabase; envia `Authorization`; trata 401 (sign out), 403/409/422/503 com toast; base `VITE_API_URL`.
- `hooks/useSession.js`: `supabase.auth.getSession`, `onAuthStateChange`, `signIn`, `signUp`, `signOut`.
- `useApi.js`: loading/error/data; abort em unmount.
- `useTheme.js`: lê `profile.tema`, aplica `data-theme`, alterna via `PATCH /me`; fallback localStorage.
- O frontend não fala com o PostgREST para dados; só Auth via Supabase JS. Dados e mutações passam pelo Flask.

## Páginas e fluxos

### Login

- Email/senha; botões “Entrar como Ana/Carlos/Lucas” com as credenciais demo.
- Cadastro: email, senha, nome, nome da família → `supabase.auth.signUp` + `POST /api/onboarding`; em caso de e-mail com confirmação pendente, mostrar mensagem.
- Erros claros; link para o modo demo.

### Painel familiar

- `GET /api/dashboard?mes=...`: saldo do mês, receitas/despesas acumuladas (soma da série de 6 meses), linha de 6 meses, rosca por categoria, metas familiares, sugestões da Jev AI, alertas, avatares dos membros, indicador de conexões bancárias.
- Sem valores individuais; cada avatar leva a `/individual`.
- Estado vazio e loading; se `banco.conexoes_ativas=0`, CTA para `/banking`.

### Página individual

- `GET /api/me/summary?mes=...`: totais pessoais, categorias, metas pessoais, recorrentes pendentes, sugestões pessoais, resumo bancário.
- Alertas pessoais (conta a vencer, categoria estourada, meta atingida) via `GET /api/alerts`; a RLS já limita ao que o usuário pode ver.
- “Olá, {nome}!”; nenhum dado de outro membro.

### Lançamentos

- Filtros por mês, tipo, escopo, categoria e origem; tabela com valores à direita.
- Modal criar/editar: tipo, escopo, valor, categoria, data, descrição, pago por (só família), origem (manual/pluggy; pluggy exige vínculo e vem do extrato).
- Quando a descrição é preenchida e a categoria ainda está vazia, chamar `POST /api/ai/classify` e mostrar a categoria sugerida; o usuário pode trocar.
- Delete com confirmação; RLS pode recusar (mostrar erro).

### Recorrentes

- Lista de regras (ativa/inativa; sem delete; “desativar”).
- Cartões pendentes com “Confirmar”, “Ignorar” e “Confirmar com outro valor”; o painel mostra os que vencem em até 3 dias (ou atrasados), a página mostra todos.
- Após confirmar, o lançamento aparece em `/transactions` e o cartão some.

### Metas

- Abas família/pessoais; progresso, prazo, contribuições por membro; criar/editar; excluir só o criador; contribuir.
- Meta concluída/cancelada não aceita contribuição.

### Previsões

- `GET /api/forecast?meses=12`: gráfico/linha e tabela por mês; total anual; detalhamento por item; rótulo “estimativa”.
- Explicar a fórmula em texto curto.

### Jev AI

- Chat com histórico (`GET/POST /api/ai/messages`), sugestões (`GET /api/ai/suggestions`), marcar como lida.
- Cada sugestão mostra o quê, por quê e quanto (ou “não é possível estimar”).
- Banner de modo degradado quando `mode !== 'jev'`.

### Extrato bancário

- Conexões, contas e transações; filtros por conta/status/mês.
- Ações: importar (modal com categoria/escopo/valor), reconciliar (vincular a lançamento existente), ignorar, sincronizar.
- No modal de importação, chamar `POST /api/ai/classify` com a descrição da bank tx e pré-selecionar a categoria sugerida; o usuário pode trocar.
- Conexão demo é somente leitura; importar/reconciliar a partir das pendências é permitido.
- Sem Pluggy key, `PluggyConnect` mostra “Integração bancária indisponível” e o botão de conexão real fica desabilitado; a demo continua.

### Configurações/admin

- Perfil e tema; membros (admin vê todos; edita nome/status; não muda papel/tema de outro); categorias (padrão só oculta; personalizada cria/edita/exclui); contas bancárias (desconectar = inativa).
- Convite/reset: se o backend responder 503, mostrar “Admin API indisponível: configure SUPABASE_SERVICE_ROLE_KEY”.
- “Restaurar demo”: confirma, chama `POST /api/demo/restore`; se 503, mostrar “Configure SUPABASE_DB_URL”; se ok, sign out e voltar ao login.

## Componentes e acessibilidade

- Botões com foco visível, labels associados, contraste AA, navegação por teclado no modal.
- Gráficos com resumo textual (`aria-label`) e tabela alternativa.
- Mobile: bottom nav com 4 itens + “Mais” para metas/previsões/IA/configurações; desktop: sidebar.
- Valores monetários em BRL; datas em `pt-BR`; timezone America/Sao_Paulo.

## Testes

- Vitest + RTL com `services/api` e Supabase mockados.
- Cobrir: login demo chama signIn; ProtectedRoute; dashboard renderiza totais/gráficos; transação create/edit/delete; recorrente confirm/ignore; meta contribuição; importação de bank tx; tema claro/escuro; estado 503 de restore/admin.
- `npm run build` sem erro; `npm test` verde.
- E2E (fase 3): Playwright com backend/frontend reais; login demo, dashboard, criar lançamento, confirmar recorrente, importar bank tx demo, alternar tema; screenshots 390px e 1280px; console sem erros.

## Aceite

- `npm run build` e `npm test` verdes.
- Fluxos da v1 navegáveis com o backend local e o Supabase hospedado.
- Nenhuma chave secreta no bundle; só `VITE_SUPABASE_URL`/`VITE_SUPABASE_ANON_KEY`.
- Tema claro/escuro funcional; mobile-first; sem gradientes roxos.
- Modo degradado visível para Pluggy/IA/restore/Admin API.
