begin;
set local search_path = public, extensions;

create temp table tap_out(seq serial, line text);
grant all on tap_out to public;
grant all on sequence tap_out_seq_seq to public;

insert into auth.users (id, email) values
  ('bb000000-0000-4000-8000-0000000000a1', 'ana.bb000000@test.local'),
  ('bb000000-0000-4000-8000-0000000000b2', 'carlos.bb000000@test.local'),
  ('bb000000-0000-4000-8000-0000000000c3', 'lucas.bb000000@test.local'),
  ('bb000000-0000-4000-8000-0000000000d4', 'externo.bb000000@test.local');

insert into public.families (id, nome, criado_por) values
  ('bb000000-0000-4000-8000-000000000001', 'Familia Teste A 11', 'bb000000-0000-4000-8000-0000000000a1');

insert into public.profiles (id, family_id, nome, papel, status) values
  ('bb000000-0000-4000-8000-0000000000a1', 'bb000000-0000-4000-8000-000000000001', 'Ana', 'admin', 'ativo'),
  ('bb000000-0000-4000-8000-0000000000b2', 'bb000000-0000-4000-8000-000000000001', 'Carlos', 'membro', 'ativo'),
  ('bb000000-0000-4000-8000-0000000000c3', 'bb000000-0000-4000-8000-000000000001', 'Lucas', 'membro', 'ativo');

insert into public.transactions (id, family_id, member_id, tipo, escopo, valor, category_id, data, criado_por) values
  ('bb000000-0000-4000-8000-000000000401', 'bb000000-0000-4000-8000-000000000001', 'bb000000-0000-4000-8000-0000000000a1', 'despesa', 'pessoal', 100, (select id from public.categories where family_id = 'bb000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação'), date_trunc('month', current_date)::date, 'bb000000-0000-4000-8000-0000000000a1'),
  ('bb000000-0000-4000-8000-000000000402', 'bb000000-0000-4000-8000-000000000001', 'bb000000-0000-4000-8000-0000000000b2', 'despesa', 'pessoal', 200, (select id from public.categories where family_id = 'bb000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação'), date_trunc('month', current_date)::date, 'bb000000-0000-4000-8000-0000000000b2'),
  ('bb000000-0000-4000-8000-000000000403', 'bb000000-0000-4000-8000-000000000001', 'bb000000-0000-4000-8000-0000000000a1', 'despesa', 'familia', 300, (select id from public.categories where family_id = 'bb000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação'), date_trunc('month', current_date)::date, 'bb000000-0000-4000-8000-0000000000a1'),
  ('bb000000-0000-4000-8000-000000000404', 'bb000000-0000-4000-8000-000000000001', 'bb000000-0000-4000-8000-0000000000b2', 'receita', 'familia', 1000, (select id from public.categories where family_id = 'bb000000-0000-4000-8000-000000000001' and tipo = 'receita' and nome = 'Salário'), date_trunc('month', current_date)::date, 'bb000000-0000-4000-8000-0000000000b2');

insert into tap_out(line) select plan(15);

set local role authenticated;
set local request.jwt.claim.sub = 'bb000000-0000-4000-8000-0000000000b2';
insert into tap_out(line) select is((select receitas from public.family_totals('bb000000-0000-4000-8000-000000000001', date_trunc('month', current_date)::date)), 1000::numeric, 'family_totals soma receitas');
insert into tap_out(line) select is((select despesas from public.family_totals('bb000000-0000-4000-8000-000000000001', date_trunc('month', current_date)::date)), 600::numeric, 'family_totals soma despesas incluindo pessoais');
insert into tap_out(line) select throws_ok($$ select * from public.family_totals('bb000000-0000-4000-8000-000000000001', '2026-11-15') $$, '22023', null, 'dia isolado e recusado');
insert into tap_out(line) select is((select sum(total) from public.family_category_totals('bb000000-0000-4000-8000-000000000001', date_trunc('month', current_date)::date)), 600::numeric, 'family_category_totals soma despesas');
insert into tap_out(line) select is((select count(*) from public.family_monthly_totals('bb000000-0000-4000-8000-000000000001', date_trunc('month', current_date)::date)), 1::bigint, 'family_monthly_totals devolve meses com lancamentos');
insert into tap_out(line) select is((select count(*) from public.family_member_directory('bb000000-0000-4000-8000-000000000001')), 3::bigint, 'diretorio devolve 3 ativos');
reset role;
reset request.jwt.claim.sub;

set local role authenticated;
set local request.jwt.claim.sub = 'bb000000-0000-4000-8000-0000000000d4';
insert into tap_out(line) select throws_ok($$ select * from public.family_totals('bb000000-0000-4000-8000-000000000001', date_trunc('month', current_date)::date) $$, '42501', null, 'externo nao acessa os totais');
reset role;
reset request.jwt.claim.sub;

update public.profiles set status = 'inativo' where id = 'bb000000-0000-4000-8000-0000000000b2';
set local role authenticated;
set local request.jwt.claim.sub = 'bb000000-0000-4000-8000-0000000000b2';
insert into tap_out(line) select throws_ok($$ select * from public.family_totals('bb000000-0000-4000-8000-000000000001', date_trunc('month', current_date)::date) $$, '42501', null, 'membro inativo nao acessa os totais');
reset role;
reset request.jwt.claim.sub;
update public.profiles set status = 'ativo' where id = 'bb000000-0000-4000-8000-0000000000b2';

update public.profiles set status = 'inativo' where id = 'bb000000-0000-4000-8000-0000000000c3';
set local role authenticated;
set local request.jwt.claim.sub = 'bb000000-0000-4000-8000-0000000000b2';
insert into tap_out(line) select is((select count(*) from public.family_member_directory('bb000000-0000-4000-8000-000000000001')), 2::bigint, 'diretorio ignora membro inativo');
reset role;
reset request.jwt.claim.sub;
update public.profiles set status = 'ativo' where id = 'bb000000-0000-4000-8000-0000000000c3';

insert into tap_out(line) select is(has_function_privilege('anon', 'public.family_totals(uuid,date)', 'EXECUTE'), false, 'anon nao executa family_totals');
insert into tap_out(line) select is(has_function_privilege('authenticated', 'public.family_totals(uuid,date)', 'EXECUTE'), true, 'authenticated executa family_totals');
insert into tap_out(line) select is(has_function_privilege('authenticated', 'private.assert_family_member(uuid)', 'EXECUTE'), false, 'authenticated nao executa assert_family_member');
insert into tap_out(line) select is((select p.proargnames[3:5] from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'family_category_totals'), array['category_id','categoria','total'], 'family_category_totals devolve colunas agregadas');
insert into tap_out(line) select is((select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname in ('family_totals','family_category_totals','family_monthly_totals') and not ('member_id' = any(p.proargnames))), 3::bigint, 'funcoes de totais nao devolvem member_id');
insert into tap_out(line) select is((select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname like 'family_%' and p.prosecdef and (p.proconfig @> array['search_path='] or p.proconfig @> array['search_path=""'])), 5::bigint, 'family_* sao security definer com search_path vazio (inclui forecast)');

insert into tap_out(line) select * from finish();

select string_agg(line, E'\n' order by seq) as tap from tap_out;
rollback;
