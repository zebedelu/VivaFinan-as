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

Suite atual: 15 arquivos, 350 assercoes.

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

## Correcao C1 - vinculo bancario

`20261103001500_bank_link_guard.sql` adiciona `tg_guard_transaction_bank_link`
em `transactions`: INSERT/UPDATE/DELETE com `bank_transaction_id` novo ou antigo
exigem `private.owns_connection`; vinculo inalterado continua livre para edicao
familiar; seed/service role (`auth.uid()` nulo) passa. O teste
`13_bank_link_guard_test.sql` cobre link/swap/delete/cross-family, INSERT,
link do dono em transacao de outro membro, lockout do delete e os controles
positivos (28/28).

## Handoff para a fatia 2

- Funcoes de leitura (schema `public`, `security definer`, `search_path=''`,
  apenas `authenticated`):
  - `family_totals(p_family_id uuid, p_mes date) returns table(receitas numeric, despesas numeric)`
  - `family_category_totals(p_family_id uuid, p_mes date) returns table(category_id uuid, categoria text, total numeric)`
  - `family_monthly_totals(p_family_id uuid, p_mes_fim date) returns table(mes date, receitas numeric, despesas numeric)`
  - `family_member_directory(p_family_id uuid) returns table(member_id uuid, nome text, papel text)`
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
