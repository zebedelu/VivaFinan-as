# VivaFinancas

Fatia 1: base de dados Supabase (schema, RLS e seed demo).

## Projeto

- URL: `https://pqxfeyuutkkqavhnysus.supabase.co`
- Ref: `pqxfeyuutkkqavhnysus`
- Postgres 17.11

## Execucao

O caminho atual usa o MCP Supabase do projeto:

- `apply_migration` para DDL versionado.
- `execute_sql` para seed, testes, consultas e inventario.
- `get_advisors` para seguranca e performance.

Os testes pgTAP sao arquivos SQL em `supabase/tests/`. Cada arquivo abre uma
transacao, coleta as linhas TAP em `tap_out` e devolve o TAP completo em uma
unica coluna. Isso permite rodar a suite pelo MCP, sem Docker e sem `psql`.
O harness esta descrito em [supabase/README.md](supabase/README.md).

## CLI opcional

O caminho por Supabase CLI + `pg_prove` continua em `supabase/scripts/`, mas
exige `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_URL`, `SUPABASE_DB_PASSWORD` e
`SUPABASE_SERVICE_ROLE_KEY`. O MCP atual nao precisa dessas chaves e e o
caminho usado nesta execucao.

## Aviso

Nenhum reset remoto (`supabase db reset --remote`) e executado neste caminho.
As migrations sao aplicadas pelo MCP; o projeto e dedicado e descartavel.
