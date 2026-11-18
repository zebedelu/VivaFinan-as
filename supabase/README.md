# Supabase - Fatia 1

Schema, RLS, testes pgTAP e seed demo do VivaFinancas.

## Estrutura

```text
supabase/
  config.toml
  migrations/     # schema, constraints, triggers, RLS, funcoes, hardening
  seed/           # dados demo
  tests/          # contrato executavel em pgTAP
  checks/         # inventario da Task 14
  scripts/        # caminho CLI opcional
```

Notas de migrations: o repo inclui `20261103000100_extensions.sql` para reset do zero; o projeto hospedado ja tem `extensions` via MCP. O `rls_identity_fix` do historico esta retrofittado em `20261103000600`/`20261103000900`, sem arquivo separado.

## Execucao via MCP

O projeto hospedado e acessado pelo MCP Supabase:

```text
apply_migration(name, query)  # DDL
execute_sql(query)            # seed, testes, consultas
get_advisors(type)            # seguranca/performance
```

Cada migration em `supabase/migrations/` e aplicada uma vez, na ordem dos
arquivos. O seed e os testes rodam por `execute_sql`.

Suite atual: 20 arquivos, 497 assercoes.

### Harness pgTAP

Os testes usam o mesmo pgTAP, mas capturam o TAP em uma tabela temporaria para
que o MCP devolva todas as linhas de uma vez:

```sql
begin;
set local search_path = public, extensions;

create temp table tap_out(seq serial, line text);
grant all on tap_out to public;
grant all on sequence tap_out_seq_seq to public;

insert into tap_out(line) select plan(1);
insert into tap_out(line) select ok(true, 'exemplo');
insert into tap_out(line) select * from finish();

select string_agg(line, E'\n' order by seq) as tap from tap_out;
rollback;
```

O resultado esperado de um teste verde e `ok ...` para cada assercao. Qualquer
`not ok` ou `# Looks like you failed` reprova a tarefa.

## Demo

- Ana (admin): `ana@demo.vivafinancas.app` / `Demo@2026!`
- Carlos (membro): `carlos@demo.vivafinancas.app` / `Demo@2026!`
- Lucas (membro): `lucas@demo.vivafinancas.app` / `Demo@2026!`
- Familia Demo: `eeeeeeee-0000-4000-8000-000000000001`
- 6 meses, 91 lancamentos, 3 metas, 4 sugestoes de IA, 1 conexao/1 conta/8
  transacoes bancarias simuladas.

O seed `010`-`040` e idempotente: limpa os dados demo e recria; a segunda
execucao mantem as contagens.

## Auth e e-mail (dashboard)

Os links de e-mail passam por `/auth/confirm` no SPA, que chama
`supabase.auth.verifyOtp({ token_hash, type })` uma unica vez e segue para
`/reset-password` quando `type=recovery` (a sessao ja chega ativa); nos demais
tipos usa `next` (destino do proprio app) ou `/painel`. Link sem `token_hash` ou
expirado mostra mensagem com volta para `/login`.

Configuracao no painel do Supabase, em **Authentication**:

- **URL Configuration**: Site URL `https://trabalho-terceiro-trimestre-vivafinancas.vercel.app`; Redirect
  URLs `https://trabalho-terceiro-trimestre-vivafinancas.vercel.app/**`, `http://localhost:5173/**` e
  `vivafinancas://**` (APK).
- **Confirm email** ligado: o cadastro so entra depois de confirmar.
- **SMTP**: Mailjet com remetente single sender verificado.
- Templates **Confirm signup**, **Invite** e **Reset password** com `token_hash`
  (nao use `{{ .ConfirmationURL }}`: ele nao passa o hash para o SPA).
  `Confirm signup` e reset usam `{{ .RedirectTo }}`, que o app monta como
  `/auth/confirm?next=/painel` ou `/auth/confirm?next=/reset-password`; o convite
  usa `{{ .SiteURL }}` e leva `{{ .RedirectTo }}` em `next`.

Confirm signup:

```html
<a href="{{ .RedirectTo }}&token_hash={{ .TokenHash }}&type=signup">Confirmar e-mail</a>
```

Invite (o backend envia `redirect_to=PUBLIC_SITE_URL/invite/<token>`):

```html
<a href="{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=invite&next={{ .RedirectTo }}">Aceitar convite</a>
```

Reset password:

```html
<a href="{{ .RedirectTo }}&token_hash={{ .TokenHash }}&type=recovery">Criar nova senha</a>
```

`PUBLIC_SITE_URL` no backend (default `https://trabalho-terceiro-trimestre-vivafinancas.vercel.app`) monta o
`redirect_to` do convite; o token do convite e gerado antes da chamada a Admin
API e gravado em `invites.token`.

## Correcao C1 - vinculo bancario

`20261103001500_bank_link_guard.sql` adiciona `tg_guard_transaction_bank_link`
em `transactions`: INSERT/UPDATE/DELETE com `bank_transaction_id` novo ou antigo
exigem `private.owns_connection`; vinculo inalterado continua livre para edicao
familiar; seed/service role (`auth.uid()` nulo) passa. O teste
`13_bank_link_guard_test.sql` cobre link/swap/delete/cross-family, INSERT,
link do dono em transacao de outro membro, lockout do delete e os controles
positivos (28/28).

## Fatia 1b - migrations de fechamento

- `20261104000100_invites.sql`: tabela `invites`, RLS e `accept_invite` (convite/aceite; só membro).
- `20261104000200_family_forecast.sql`: RPC de forecast familiar (12 meses; sem membro/descrição).
- `20261104000300_onboard_family.sql`: onboarding atômico/idempotente.
- `20261104000400_demo_bank_ignore.sql`: dono pode alterar `status` de bank tx demo; raw continua bloqueado.
- `20261104000500_confirm_occurrence.sql`: confirmação atômica de recorrente (sem compensação destrutiva).
- `20261104000600_ai_suggestion_dedup.sql`: índice único de dedup de sugestões.
- `20261104000700_invites_auth_user.sql`: coluna `invites.auth_user_id` (uuid, nullable) para cancelar o convite apagando o usuário Auth; reconvidar o mesmo e-mail passa a funcionar.
- Testes `14`–`18` e ajuste do `08`/`11`; suíte 20 arquivos / 497 asserções (revalidada após a `000700`).

`auth.email()`/`auth.uid()` existem no projeto. Os default privileges do hosted concedem ALL em tabelas novas para `anon`/`authenticated`; por isso `invites` faz `revoke all` antes dos grants.

### Advisors aceitos

- `authenticated_security_definer_function_executable` (7): as 4 `family_*` e as 3 novas `accept_invite`, `family_forecast`, `onboard_family` são `security definer` com `search_path=''`, validação de membro/e-mail e grant só `authenticated`; `anon` sem execute.
- `multiple_permissive_policies` em `bank_transactions` UPDATE: `bank_transactions_update` (não-demo) + `bank_transactions_update_demo` (demo) são OR do mesmo dono; o WARN é de performance, não de acesso.
- `auth_leaked_password_protection` é pré-existente e não é da fatia 1b.
- O teste 11 foi ajustado de 4 para 5 funções `family_*` por causa do `family_forecast`; ajuste necessário, fora do escopo original da lane.

## Handoff para a fatia 2

- Fatia 1b: `invites` (family_nome), `accept_invite`, `family_forecast`, `onboard_family`, `confirm_occurrence`, dedup de IA; `bank_transactions_update_demo`.

- Funcoes de leitura (schema `public`, `security definer`, `search_path=''`,
  apenas `authenticated`):
  - `family_totals(p_family_id uuid, p_mes date) returns table(receitas numeric, despesas numeric)`
  - `family_category_totals(p_family_id uuid, p_mes date) returns table(category_id uuid, categoria text, total numeric)`
  - `family_monthly_totals(p_family_id uuid, p_mes_fim date) returns table(mes date, receitas numeric, despesas numeric)`
  - `family_member_directory(p_family_id uuid) returns table(member_id uuid, nome text, papel text)`
  - `family_forecast(p_family_id uuid, p_mes_inicio date) returns table(mes date, receitas numeric, despesas numeric, recorrentes_receitas numeric, recorrentes_despesas numeric, variavel_receitas numeric, variavel_despesas numeric)`
- `p_mes`/`p_mes_fim` precisam ser o primeiro dia do mes (22023).
- Status canonicos: `pessoal|familia`, `receita|despesa`, `debito|credito`,
  `ativo|inativo`, `pendente|confirmado|ignorado`,
  `em_andamento|concluida|cancelada`,
  `pendente_importacao|importada|ignorada|reconciliada`,
  `ativa|inativa|erro_sincronizacao|expirada`, `manual|pluggy`, `admin|membro`,
  `corrente|poupanca`.
- RLS: cada membro ve o proprio perfil e os proprios lancamentos pessoais; o
  admin nao tem bypass; lancamentos de familia sao editaveis por membros ativos,
  mas so o autor exclui; metas familiares sao editaveis, so o criador exclui;
  dados bancarios sao pessoais; membro inativo perde leitura/escrita.
- `bank_transactions`: INSERT/DELETE apenas service role; `authenticated` so
  atualiza `status`; `transaction_id` e escrito pelo trigger do lancamento.
- `transactions` com `origem='pluggy'` exige `bank_transaction_id` e nasce de
  confirmacao explicita; transacao bancaria nunca cria lancamento sozinha.
- Restauracao da demo: reexecutar `supabase/seed/010`-`040` por conexao
  Postgres direta (`SUPABASE_DB_URL`) dentro de uma transacao; recria usuarios
  Auth e dados, encerra a sessao do visitante. A service role key nao executa
  SQL; ela fica restrita a Admin API, seed e sync Pluggy.
- Hardening hospedado: `20261103000850_harden_grants.sql` remove o ALL/TUNCATE
  que o Supabase concede em tabelas novas para `authenticated`;
  `20261103001400_harden_trigger_functions.sql` revoga EXECUTE das funcoes de
  trigger expostas no schema public.

## Caminho CLI opcional

O CLI 3.0.0 exige container para `supabase test db` no Windows. O caminho
opcional usa `pg_prove` nativo contra a conexao Postgres do projeto. Ele
precisa de `%USERPROFILE%\.config\vivafinancas\hosted.env` com as chaves
descritas em `supabase/hosted.env.example`.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File supabase/scripts/preflight.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File supabase/scripts/reset-db.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File supabase/scripts/run-tests.ps1
```

O gate `db lint`/`pg_prove` nao rodou nesta sessao: `hosted.env` sem
`SUPABASE_ACCESS_TOKEN`/`SUPABASE_DB_URL`. O MCP segue como harness oficial.

## Credenciais

- O MCP atual nao expoe a service role key e nao precisa dela.
- A service role key, se usada no caminho CLI, fica apenas no ambiente e nunca
  no repositorio, no frontend ou no backend.
- Nenhuma senha, token bancario ou credencial Pluggy existe no banco; a coluna
  `pluggy_connection_id` e um identificador opaco.

## Versoes usadas

- Supabase CLI 3.0.0
- PostgreSQL client 18
- pg_prove 3.37 (Strawberry Perl 5.42.3.1)
- Node.js 26.7.0
