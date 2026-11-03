-- Inventario da fatia 1. Rodar via MCP execute_sql ou psql.
select tablename, rowsecurity from pg_tables where schemaname = 'public' order by tablename;
select schemaname, tablename, policyname from pg_policies where schemaname = 'public' order by tablename, policyname;
select p.proname, p.prosecdef, p.proconfig
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname like 'family_%'
order by p.proname;
