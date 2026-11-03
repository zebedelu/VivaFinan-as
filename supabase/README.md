# Supabase - Fatia 1

Schema, RLS, testes pgTAP e seed demo do VivaFinancas.

## Estrutura

```text
supabase/
  config.toml
  migrations/     # schema, constraints, triggers, RLS, funcoes
  seed/           # dados demo
  tests/          # contrato executavel em pgTAP
  checks/         # inventario da Task 14
  scripts/        # caminho CLI opcional
```

## Execucao via MCP

O projeto hospedado e acessado pelo MCP Supabase:

```text
apply_migration(name, query)  # DDL
execute_sql(query)            # seed, testes, consultas
get_advisors(type)            # seguranca/performance
```

Cada migration em `supabase/migrations/` e aplicada uma vez, na ordem dos
arquivos. O seed e os testes rodam por `execute_sql`.

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

## Caminho CLI opcional

O CLI 3.0.0 exige container para `supabase test db` no Windows. Por isso, o
caminho opcional usa `pg_prove` nativo (Strawberry Perl) contra a conexao
Postgres do projeto. Ele precisa de um arquivo
`%USERPROFILE%\.config\vivafinancas\hosted.env` com:

```text
SUPABASE_ACCESS_TOKEN
SUPABASE_PROJECT_REF
VIVAFINANCAS_DEV_PROJECT_REF
VIVAFINANCAS_ALLOW_REMOTE_RESET
SUPABASE_DB_PASSWORD
SUPABASE_DB_URL
SUPABASE_URL
SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File supabase/scripts/preflight.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File supabase/scripts/reset-db.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File supabase/scripts/run-tests.ps1
```

`reset-db.ps1` executa `supabase db reset --remote --yes` e so roda com
`VIVAFINANCAS_ALLOW_REMOTE_RESET=yes` e o ref confirmado.

## Credenciais

- O MCP atual nao expoe a service role key e nao precisa dela.
- A service role key, se usada no caminho CLI, fica apenas no ambiente e nunca
  no repositorio, no frontend ou no backend.
- A restauracao da demo no hosted precisa recriar os usuarios Auth pela Admin
  API e os dados da familia por SQL direto.

## Versoes usadas

- Supabase CLI 3.0.0
- PostgreSQL client 18
- pg_prove 3.37 (Strawberry Perl 5.42.3.1)
- Node.js 26.7.0

## Demo

Credenciais e dados da Familia Demo serao preenchidos na Task 13.
