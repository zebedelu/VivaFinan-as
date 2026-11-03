begin;
set local search_path = public, extensions;

create temp table tap_out(seq serial, line text);
grant all on tap_out to public;
grant all on sequence tap_out_seq_seq to public;

insert into auth.users (id, email) values
  ('55000000-0000-4000-8000-0000000000a1', 'ana.55000000@test.local'),
  ('55000000-0000-4000-8000-0000000000b2', 'carlos.55000000@test.local'),
  ('55000000-0000-4000-8000-0000000000c3', 'lucas.55000000@test.local'),
  ('55000000-0000-4000-8000-0000000000d4', 'externo.55000000@test.local');

insert into public.families (id, nome, criado_por) values
  ('55000000-0000-4000-8000-000000000001', 'Familia Teste A 05', '55000000-0000-4000-8000-0000000000a1'),
  ('55000000-0000-4000-8000-000000000002', 'Familia Teste B 05', '55000000-0000-4000-8000-0000000000d4');

insert into public.profiles (id, family_id, nome, papel, status) values
  ('55000000-0000-4000-8000-0000000000a1', '55000000-0000-4000-8000-000000000001', 'Ana', 'admin', 'ativo'),
  ('55000000-0000-4000-8000-0000000000b2', '55000000-0000-4000-8000-000000000001', 'Carlos', 'membro', 'ativo'),
  ('55000000-0000-4000-8000-0000000000c3', '55000000-0000-4000-8000-000000000001', 'Lucas', 'membro', 'ativo'),
  ('55000000-0000-4000-8000-0000000000d4', '55000000-0000-4000-8000-000000000002', 'Externo', 'admin', 'ativo');

insert into tap_out(line) select plan(19);

insert into tap_out(line) select is((select count(*) from public.categories where family_id = '55000000-0000-4000-8000-000000000001'), 12::bigint, 'familia recebe 12 categorias');
insert into tap_out(line) select is((select count(*) from public.categories where family_id = '55000000-0000-4000-8000-000000000001' and tipo = 'despesa'), 8::bigint, '8 categorias de despesa');
insert into tap_out(line) select is((select count(*) from public.categories where family_id = '55000000-0000-4000-8000-000000000001' and tipo = 'receita'), 4::bigint, '4 categorias de receita');
insert into tap_out(line) select is((select count(*) from public.categories where family_id = '55000000-0000-4000-8000-000000000001' and personalizada = true), 0::bigint, 'categorias padrao nao sao personalizadas');
insert into tap_out(line) select is((select count(*) from public.categories where family_id = '55000000-0000-4000-8000-000000000001' and oculta = true), 0::bigint, 'categorias padrao comecam visiveis');

insert into public.categories (id, family_id, nome, tipo, personalizada, criado_por) values
  ('55000000-0000-4000-8000-0000000000c1', '55000000-0000-4000-8000-000000000001', 'Pet 05', 'despesa', true, '55000000-0000-4000-8000-0000000000a1');

insert into public.transactions (id, family_id, member_id, tipo, escopo, valor, category_id, data, criado_por) values
  ('55000000-0000-4000-8000-0000000000d1', '55000000-0000-4000-8000-000000000001', '55000000-0000-4000-8000-0000000000a1', 'despesa', 'pessoal', 10, '55000000-0000-4000-8000-0000000000c1', '2026-11-10', '55000000-0000-4000-8000-0000000000a1');

insert into tap_out(line) select throws_ok($$ update public.profiles set papel = 'admin' where id = '55000000-0000-4000-8000-0000000000b2' $$, '42501', null, 'papel de perfil e imutavel');
insert into tap_out(line) select throws_ok($$ update public.profiles set family_id = '55000000-0000-4000-8000-000000000002' where id = '55000000-0000-4000-8000-0000000000b2' $$, '42501', null, 'family_id de perfil e imutavel');

set local request.jwt.claim.sub = '55000000-0000-4000-8000-0000000000a1';
insert into tap_out(line) select throws_ok($$ update public.profiles set status = 'inativo' where id = '55000000-0000-4000-8000-0000000000a1' $$, '42501', null, 'ultimo admin ativo nao pode ser desativado');
insert into tap_out(line) select lives_ok($$ update public.profiles set status = 'inativo' where id = '55000000-0000-4000-8000-0000000000c3' $$, 'membro comum pode ser desativado');
insert into tap_out(line) select throws_ok($$ update public.profiles set tema = 'escuro' where id = '55000000-0000-4000-8000-0000000000b2' $$, '42501', null, 'admin nao altera tema de outro membro');
reset request.jwt.claim.sub;

set local request.jwt.claim.sub = '55000000-0000-4000-8000-0000000000b2';
insert into tap_out(line) select lives_ok($$ update public.profiles set tema = 'escuro' where id = '55000000-0000-4000-8000-0000000000b2' $$, 'membro altera o proprio tema');
reset request.jwt.claim.sub;

insert into tap_out(line) select throws_ok($$ update public.families set is_demo = true where id = '55000000-0000-4000-8000-000000000001' $$, '42501', null, 'is_demo da familia e imutavel');
insert into tap_out(line) select throws_ok($$ update public.families set criado_por = '55000000-0000-4000-8000-0000000000b2' where id = '55000000-0000-4000-8000-000000000001' $$, '42501', null, 'criado_por da familia e imutavel');

insert into tap_out(line) select throws_ok($$ update public.categories set nome = 'Alimentacao 05' where family_id = '55000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação' $$, '42501', null, 'categoria padrao nao pode ser renomeada');
insert into tap_out(line) select lives_ok($$ update public.categories set oculta = true where family_id = '55000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação' $$, 'categoria padrao pode ser ocultada');
insert into tap_out(line) select lives_ok($$ update public.categories set nome = 'Pet Renomeado 05' where id = '55000000-0000-4000-8000-0000000000c1' $$, 'categoria personalizada pode ser renomeada');
insert into tap_out(line) select throws_ok($$ update public.categories set personalizada = false where id = '55000000-0000-4000-8000-0000000000c1' $$, '42501', null, 'personalizada e imutavel');
insert into tap_out(line) select throws_ok($$ update public.categories set tipo = 'receita' where id = '55000000-0000-4000-8000-0000000000c1' $$, '42501', null, 'tipo de categoria em uso e imutavel');

insert into tap_out(line) select ok((
  select p.prosecdef and (p.proconfig @> array['search_path='] or p.proconfig @> array['search_path=""'])
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'tg_seed_default_categories'
), 'trigger de categorias e security definer com search_path vazio');

insert into tap_out(line) select * from finish();

select string_agg(line, E'\n' order by seq) as tap from tap_out;
rollback;
