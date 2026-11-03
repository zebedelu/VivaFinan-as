# VivaFinancas

Fatia 1: base de dados Supabase (schema, RLS e seed demo).

## Projeto

- URL: `https://pqxfeyuutkkqavhnysus.supabase.co`
- Ref: `pqxfeyuutkkqavhnysus`
- Postgres 17.11
- Branch local: `fatia-1-supabase` (sem push)

## O que está pronto

- 13 tabelas com constraints, triggers e RLS por membro.
- 4 funcoes de leitura agregada da familia.
- Familia Demo com 6 meses, 91 lancamentos, 3 metas, 4 sugestoes de IA e
  conexao bancaria simulada com 8 transacoes nos 4 status.
- Testes pgTAP em `supabase/tests/`, executados via MCP. Detalhes em
  [supabase/README.md](supabase/README.md).

## Demo

- Ana (admin): `ana@demo.vivafinancas.app` / `Demo@2026!`
- Carlos (membro): `carlos@demo.vivafinancas.app` / `Demo@2026!`
- Lucas (membro): `lucas@demo.vivafinancas.app` / `Demo@2026!`

A senha e uma credencial de demonstracao documentada, nao uma credencial
bancaria. O seed fica em `supabase/seed/`.

## Execucao

O caminho usado nesta fatia e o MCP Supabase do projeto:

- `apply_migration` para DDL.
- `execute_sql` para seed, testes e inventario.
- `get_advisors` para os gates de seguranca/performance.

Os testes usam uma tabela temporaria `tap_out` para devolver o TAP completo
em uma unica coluna; o harness esta descrito em `supabase/README.md`.

## CLI opcional

O caminho por Supabase CLI + `pg_prove` continua em `supabase/scripts/`, mas
exige `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_URL`, `SUPABASE_DB_PASSWORD` e
`SUPABASE_SERVICE_ROLE_KEY`. O MCP atual nao precisa dessas chaves.

## Aviso

`supabase/scripts/reset-db.ps1` executa `supabase db reset --remote --yes` e
apaga todos os schemas de usuario do projeto. Ele so roda com
`VIVAFINANCAS_ALLOW_REMOTE_RESET=yes` e o ref confirmado. O projeto e dedicado
e descartavel; nunca use producao.
