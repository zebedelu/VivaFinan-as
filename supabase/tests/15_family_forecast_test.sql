begin;
set local search_path = public, extensions;

create temp table tap_out(seq serial, line text);
grant all on tap_out to public;
grant all on sequence tap_out_seq_seq to public;

insert into auth.users (id, email) values
  ('ab000000-0000-4000-8000-0000000000a1', 'ana.ab000000@test.local'),
  ('ab000000-0000-4000-8000-0000000000b2', 'carlos.ab000000@test.local'),
  ('ab000000-0000-4000-8000-0000000000c3', 'lucas.ab000000@test.local'),
  ('ab000000-0000-4000-8000-0000000000d4', 'externo.ab000000@test.local');

insert into public.families (id, nome, criado_por) values
  ('ab000000-0000-4000-8000-000000000001', 'Familia Teste A 15', 'ab000000-0000-4000-8000-0000000000a1'),
  ('ab000000-0000-4000-8000-000000000002', 'Familia Teste B 15', 'ab000000-0000-4000-8000-0000000000d4');

insert into public.profiles (id, family_id, nome, papel, status) values
  ('ab000000-0000-4000-8000-0000000000a1', 'ab000000-0000-4000-8000-000000000001', 'Ana', 'admin', 'ativo'),
  ('ab000000-0000-4000-8000-0000000000b2', 'ab000000-0000-4000-8000-000000000001', 'Carlos', 'membro', 'ativo'),
  ('ab000000-0000-4000-8000-0000000000c3', 'ab000000-0000-4000-8000-000000000001', 'Lucas', 'membro', 'inativo'),
  ('ab000000-0000-4000-8000-0000000000d4', 'ab000000-0000-4000-8000-000000000002', 'Externo', 'admin', 'ativo');

insert into public.recurring_rules (id, family_id, criado_por, tipo, escopo, valor, descricao, category_id, dia_vencimento, ativo) values
  ('ab000000-0000-4000-8000-000000000101', 'ab000000-0000-4000-8000-000000000001', 'ab000000-0000-4000-8000-0000000000a1', 'despesa', 'familia', 100, 'Aluguel', (select id from public.categories where family_id = 'ab000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação'), 10, true),
  ('ab000000-0000-4000-8000-000000000102', 'ab000000-0000-4000-8000-000000000001', 'ab000000-0000-4000-8000-0000000000b2', 'receita', 'pessoal', 500, 'Salário Extra', (select id from public.categories where family_id = 'ab000000-0000-4000-8000-000000000001' and tipo = 'receita' and nome = 'Salário'), 31, true),
  ('ab000000-0000-4000-8000-000000000103', 'ab000000-0000-4000-8000-000000000001', 'ab000000-0000-4000-8000-0000000000a1', 'despesa', 'pessoal', 200, 'Fora da janela', (select id from public.categories where family_id = 'ab000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Outros'), 15, true),
  ('ab000000-0000-4000-8000-000000000104', 'ab000000-0000-4000-8000-000000000001', 'ab000000-0000-4000-8000-0000000000a1', 'receita', 'pessoal', 999, 'Inativa', (select id from public.categories where family_id = 'ab000000-0000-4000-8000-000000000001' and tipo = 'receita' and nome = 'Freelance'), 5, false),
  ('ab000000-0000-4000-8000-000000000105', 'ab000000-0000-4000-8000-000000000001', 'ab000000-0000-4000-8000-0000000000a1', 'despesa', 'familia', 50, 'Mes corrente', (select id from public.categories where family_id = 'ab000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Transporte'), 5, true),
  ('ab000000-0000-4000-8000-000000000106', 'ab000000-0000-4000-8000-000000000001', 'ab000000-0000-4000-8000-0000000000a1', 'despesa', 'familia', 777, 'So pendente', (select id from public.categories where family_id = 'ab000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Lazer'), 1, true);

insert into public.recurring_occurrences (rule_id, mes_referencia, status, valor_confirmado, confirmado_por, confirmado_em) values
  ('ab000000-0000-4000-8000-000000000101', '2025-12-01', 'confirmado', 105, 'ab000000-0000-4000-8000-0000000000a1', now()),
  ('ab000000-0000-4000-8000-000000000101', '2026-01-01', 'confirmado', 110, 'ab000000-0000-4000-8000-0000000000a1', now()),
  ('ab000000-0000-4000-8000-000000000101', '2026-02-01', 'confirmado', 110, 'ab000000-0000-4000-8000-0000000000a1', now()),
  ('ab000000-0000-4000-8000-000000000102', '2025-12-01', 'confirmado', 500, 'ab000000-0000-4000-8000-0000000000b2', now()),
  ('ab000000-0000-4000-8000-000000000103', '2025-11-01', 'confirmado', 200, 'ab000000-0000-4000-8000-0000000000a1', now()),
  ('ab000000-0000-4000-8000-000000000103', '2026-05-01', 'pendente', null, null, null),
  ('ab000000-0000-4000-8000-000000000104', '2026-03-01', 'confirmado', 999, 'ab000000-0000-4000-8000-0000000000a1', now()),
  ('ab000000-0000-4000-8000-000000000105', '2026-05-01', 'confirmado', 50, 'ab000000-0000-4000-8000-0000000000a1', now()),
  ('ab000000-0000-4000-8000-000000000106', '2026-05-01', 'pendente', null, null, null);

insert into public.transactions (family_id, member_id, tipo, escopo, valor, descricao, category_id, data, criado_por) values
  ('ab000000-0000-4000-8000-000000000001', 'ab000000-0000-4000-8000-0000000000a1', 'receita', 'pessoal', 300, 'Receita Fev', (select id from public.categories where family_id = 'ab000000-0000-4000-8000-000000000001' and tipo = 'receita' and nome = 'Salário'), '2026-02-10', 'ab000000-0000-4000-8000-0000000000a1'),
  ('ab000000-0000-4000-8000-000000000001', 'ab000000-0000-4000-8000-0000000000a1', 'despesa', 'pessoal', 60, 'Despesa Fev', (select id from public.categories where family_id = 'ab000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação'), '2026-02-11', 'ab000000-0000-4000-8000-0000000000a1'),
  ('ab000000-0000-4000-8000-000000000001', 'ab000000-0000-4000-8000-0000000000a1', 'receita', 'pessoal', 300, 'Receita Mar', (select id from public.categories where family_id = 'ab000000-0000-4000-8000-000000000001' and tipo = 'receita' and nome = 'Salário'), '2026-03-10', 'ab000000-0000-4000-8000-0000000000a1'),
  ('ab000000-0000-4000-8000-000000000001', 'ab000000-0000-4000-8000-0000000000a1', 'despesa', 'pessoal', 90, 'Despesa Mar', (select id from public.categories where family_id = 'ab000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação'), '2026-03-11', 'ab000000-0000-4000-8000-0000000000a1'),
  ('ab000000-0000-4000-8000-000000000001', 'ab000000-0000-4000-8000-0000000000a1', 'receita', 'pessoal', 300, 'Receita Abr', (select id from public.categories where family_id = 'ab000000-0000-4000-8000-000000000001' and tipo = 'receita' and nome = 'Salário'), '2026-04-10', 'ab000000-0000-4000-8000-0000000000a1'),
  ('ab000000-0000-4000-8000-000000000001', 'ab000000-0000-4000-8000-0000000000a1', 'despesa', 'pessoal', 120, 'Despesa Abr', (select id from public.categories where family_id = 'ab000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação'), '2026-04-11', 'ab000000-0000-4000-8000-0000000000a1'),
  ('ab000000-0000-4000-8000-000000000001', 'ab000000-0000-4000-8000-0000000000a1', 'despesa', 'pessoal', 1000, 'Despesa Mai parcial', (select id from public.categories where family_id = 'ab000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação'), '2026-05-10', 'ab000000-0000-4000-8000-0000000000a1'),
  ('ab000000-0000-4000-8000-000000000001', 'ab000000-0000-4000-8000-0000000000a1', 'despesa', 'pessoal', 30, 'Despesa Jan', (select id from public.categories where family_id = 'ab000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação'), '2026-01-10', 'ab000000-0000-4000-8000-0000000000a1'),
  ('ab000000-0000-4000-8000-000000000002', 'ab000000-0000-4000-8000-0000000000d4', 'receita', 'pessoal', 9999, 'Receita B', (select id from public.categories where family_id = 'ab000000-0000-4000-8000-000000000002' and tipo = 'receita' and nome = 'Salário'), '2026-02-10', 'ab000000-0000-4000-8000-0000000000d4'),
  ('ab000000-0000-4000-8000-000000000002', 'ab000000-0000-4000-8000-0000000000d4', 'despesa', 'pessoal', 9999, 'Despesa B', (select id from public.categories where family_id = 'ab000000-0000-4000-8000-000000000002' and tipo = 'despesa' and nome = 'Alimentação'), '2026-02-11', 'ab000000-0000-4000-8000-0000000000d4');

insert into public.transactions (family_id, member_id, tipo, escopo, valor, descricao, category_id, data, criado_por, recurring_rule_id, mes_referencia) values
  ('ab000000-0000-4000-8000-000000000001', 'ab000000-0000-4000-8000-0000000000a1', 'despesa', 'familia', 110, 'Aluguel', (select id from public.categories where family_id = 'ab000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação'), '2026-02-10', 'ab000000-0000-4000-8000-0000000000a1', 'ab000000-0000-4000-8000-000000000101', '2026-02-01');

insert into tap_out(line) select plan(25);

set local role authenticated;
set local request.jwt.claim.sub = 'ab000000-0000-4000-8000-0000000000b2';
insert into tap_out(line) select is((select count(*) from public.family_forecast('ab000000-0000-4000-8000-000000000001', '2026-06-01')), 12::bigint, 'forecast devolve 12 meses');
insert into tap_out(line) select is((select min(mes) from public.family_forecast('ab000000-0000-4000-8000-000000000001', '2026-06-01')), '2026-06-01'::date, 'primeiro mes e o mes inicial');
insert into tap_out(line) select is((select max(mes) from public.family_forecast('ab000000-0000-4000-8000-000000000001', '2026-06-01')), '2027-05-01'::date, 'ultimo mes e o decimo segundo');
insert into tap_out(line) select is((select count(distinct mes) from public.family_forecast('ab000000-0000-4000-8000-000000000001', '2026-06-01')), 12::bigint, 'meses sao distintos');
insert into tap_out(line) select is((select receitas from public.family_forecast('ab000000-0000-4000-8000-000000000001', '2026-06-01') where mes = '2026-06-01'), 800::numeric, 'receitas do primeiro mes');
insert into tap_out(line) select is((select despesas from public.family_forecast('ab000000-0000-4000-8000-000000000001', '2026-06-01') where mes = '2026-06-01'), 250::numeric, 'despesas do primeiro mes');
insert into tap_out(line) select is((select recorrentes_receitas from public.family_forecast('ab000000-0000-4000-8000-000000000001', '2026-06-01') where mes = '2026-06-01'), 500::numeric, 'recorrentes de receita usam valor confirmado');
insert into tap_out(line) select is((select recorrentes_despesas from public.family_forecast('ab000000-0000-4000-8000-000000000001', '2026-06-01') where mes = '2026-06-01'), 160::numeric, 'recorrentes de despesa somam regras confirmadas');
insert into tap_out(line) select is((select variavel_receitas from public.family_forecast('ab000000-0000-4000-8000-000000000001', '2026-06-01') where mes = '2026-06-01'), 300::numeric, 'variavel de receita e a media de 3 meses');
insert into tap_out(line) select is((select variavel_despesas from public.family_forecast('ab000000-0000-4000-8000-000000000001', '2026-06-01') where mes = '2026-06-01'), 90::numeric, 'variavel de despesa e a media de 3 meses');
insert into tap_out(line) select is((select count(*) from public.family_forecast('ab000000-0000-4000-8000-000000000001', '2026-06-01') where recorrentes_receitas = 500), 12::bigint, 'regra com dia 31 entra em todos os meses');
insert into tap_out(line) select is((select count(*) from public.family_forecast('ab000000-0000-4000-8000-000000000001', '2026-06-01') where recorrentes_despesas = 160), 12::bigint, 'regra confirmada no mes corrente entra em todos os meses');
insert into tap_out(line) select is((select recorrentes_receitas from public.family_forecast('ab000000-0000-4000-8000-000000000001', '2026-06-01') where mes = '2027-02-01'), 500::numeric, 'fevereiro tambem recebe a regra com clamp');
insert into tap_out(line) select is((select max(receitas) from public.family_forecast('ab000000-0000-4000-8000-000000000001', '2026-06-01')), 800::numeric, 'familia de fora nao entra no forecast');
insert into tap_out(line) select throws_ok($$
  select * from public.family_forecast('ab000000-0000-4000-8000-000000000001', '2026-06-15')
$$, '22023', null, 'mes inicial precisa ser o primeiro dia');
reset role;
reset request.jwt.claim.sub;

set local role authenticated;
set local request.jwt.claim.sub = 'ab000000-0000-4000-8000-0000000000d4';
insert into tap_out(line) select throws_ok($$
  select * from public.family_forecast('ab000000-0000-4000-8000-000000000001', '2026-06-01')
$$, '42501', null, 'nao membro nao acessa o forecast');
reset role;
reset request.jwt.claim.sub;

set local role authenticated;
set local request.jwt.claim.sub = 'ab000000-0000-4000-8000-0000000000c3';
insert into tap_out(line) select throws_ok($$
  select * from public.family_forecast('ab000000-0000-4000-8000-000000000001', '2026-06-01')
$$, '42501', null, 'membro inativo nao acessa o forecast');
reset role;
reset request.jwt.claim.sub;

set local role anon;
insert into tap_out(line) select throws_ok($$
  select * from public.family_forecast('ab000000-0000-4000-8000-000000000001', '2026-06-01')
$$, '42501', null, 'anon nao executa o forecast');
reset role;

insert into tap_out(line) select is((select p.proargnames[3:9] from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'family_forecast'), array['mes','receitas','despesas','recorrentes_receitas','recorrentes_despesas','variavel_receitas','variavel_despesas'], 'forecast devolve apenas colunas agregadas');
insert into tap_out(line) select is((select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'family_forecast' and ('member_id' = any(p.proargnames) or 'descricao' = any(p.proargnames))), 0::bigint, 'forecast nao devolve membro nem descricao');
insert into tap_out(line) select is((select prosecdef from pg_proc where oid = 'public.family_forecast(uuid,date)'::regprocedure), true, 'family_forecast e security definer');
insert into tap_out(line) select is((select provolatile from pg_proc where oid = 'public.family_forecast(uuid,date)'::regprocedure), 's', 'family_forecast e stable');
insert into tap_out(line) select is((select proconfig @> array['search_path='] or proconfig @> array['search_path=""'] from pg_proc where oid = 'public.family_forecast(uuid,date)'::regprocedure), true, 'family_forecast usa search_path vazio');
insert into tap_out(line) select is(has_function_privilege('anon', 'public.family_forecast(uuid,date)', 'EXECUTE'), false, 'anon nao tem execute');
insert into tap_out(line) select is(has_function_privilege('authenticated', 'public.family_forecast(uuid,date)', 'EXECUTE'), true, 'authenticated tem execute');

insert into tap_out(line) select * from finish();

select string_agg(line, E'\n' order by seq) as tap from tap_out;
rollback;
