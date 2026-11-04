begin;
set local search_path = public, extensions;

create temp table tap_out(seq serial, line text);
grant all on tap_out to public;
grant all on sequence tap_out_seq_seq to public;

insert into auth.users (id, email) values
  ('77000000-0000-4000-8000-0000000000a1', 'ana.77000000@test.local'),
  ('77000000-0000-4000-8000-0000000000b2', 'carlos.77000000@test.local'),
  ('77000000-0000-4000-8000-0000000000c3', 'lucas.77000000@test.local'),
  ('77000000-0000-4000-8000-0000000000d4', 'externo.77000000@test.local'),
  ('77000000-0000-4000-8000-0000000000e5', 'novo.77000000@test.local'),
  ('77000000-0000-4000-8000-0000000000e6', 'outro.77000000@test.local');

insert into public.families (id, nome, criado_por) values
  ('77000000-0000-4000-8000-000000000001', 'Familia Teste A 07', '77000000-0000-4000-8000-0000000000a1'),
  ('77000000-0000-4000-8000-000000000002', 'Familia Teste B 07', '77000000-0000-4000-8000-0000000000d4');

insert into public.profiles (id, family_id, nome, papel, status) values
  ('77000000-0000-4000-8000-0000000000a1', '77000000-0000-4000-8000-000000000001', 'Ana', 'admin', 'ativo'),
  ('77000000-0000-4000-8000-0000000000b2', '77000000-0000-4000-8000-000000000001', 'Carlos', 'membro', 'ativo'),
  ('77000000-0000-4000-8000-0000000000c3', '77000000-0000-4000-8000-000000000001', 'Lucas', 'membro', 'ativo'),
  ('77000000-0000-4000-8000-0000000000d4', '77000000-0000-4000-8000-000000000002', 'Externo', 'admin', 'ativo');

insert into public.categories (id, family_id, nome, tipo, personalizada, criado_por) values
  ('77000000-0000-4000-8000-0000000000f1', '77000000-0000-4000-8000-000000000001', 'Pet Ana 07', 'despesa', true, '77000000-0000-4000-8000-0000000000a1'),
  ('77000000-0000-4000-8000-0000000000f2', '77000000-0000-4000-8000-000000000001', 'Pet Carlos 07', 'despesa', true, '77000000-0000-4000-8000-0000000000b2'),
  ('77000000-0000-4000-8000-0000000000f3', '77000000-0000-4000-8000-000000000001', 'Pet Carlos Uso 07', 'despesa', true, '77000000-0000-4000-8000-0000000000b2');

insert into public.transactions (id, family_id, member_id, tipo, escopo, valor, category_id, data, criado_por) values
  ('77000000-0000-4000-8000-0000000000e1', '77000000-0000-4000-8000-000000000001', '77000000-0000-4000-8000-0000000000b2', 'despesa', 'pessoal', 10, '77000000-0000-4000-8000-0000000000f3', '2026-11-10', '77000000-0000-4000-8000-0000000000b2');

insert into tap_out(line) select plan(34);

set local role authenticated;
set local request.jwt.claim.sub = '77000000-0000-4000-8000-0000000000a1';
insert into tap_out(line) select is((select count(*) from public.families where id = '77000000-0000-4000-8000-000000000001'), 1::bigint, 'Ana ve a propria familia');
reset role;
reset request.jwt.claim.sub;

set local role authenticated;
set local request.jwt.claim.sub = '77000000-0000-4000-8000-0000000000d4';
insert into tap_out(line) select is((select count(*) from public.families where id = '77000000-0000-4000-8000-000000000001'), 0::bigint, 'Externo nao ve a familia A');
reset role;
reset request.jwt.claim.sub;

set local role authenticated;
set local request.jwt.claim.sub = '77000000-0000-4000-8000-0000000000a1';
insert into tap_out(line) select throws_ok($$ insert into public.families (nome, criado_por) values ('Familia 2 07', '77000000-0000-4000-8000-0000000000a1') $$, '42501', null, 'Ana com perfil nao cria segunda familia');
reset role;
reset request.jwt.claim.sub;

set local role authenticated;
set local request.jwt.claim.sub = '77000000-0000-4000-8000-0000000000e6';
insert into tap_out(line) select throws_ok($$ insert into public.profiles (id, family_id, nome, papel, status) values ('77000000-0000-4000-8000-0000000000e6', '77000000-0000-4000-8000-000000000001', 'Outro', 'membro', 'ativo') $$, '42501', null, 'usuario de fora nao entra na familia A');
insert into tap_out(line) select throws_ok($$ insert into public.profiles (id, family_id, nome, papel, status) values ('77000000-0000-4000-8000-0000000000e6', '77000000-0000-4000-8000-000000000001', 'Outro', 'admin', 'ativo') $$, '42501', null, 'ninguem insere admin em familia que ja tem perfis');
reset role;
reset request.jwt.claim.sub;

set local role authenticated;
set local request.jwt.claim.sub = '77000000-0000-4000-8000-0000000000e5';
insert into tap_out(line) select lives_ok($$ insert into public.families (id, nome, criado_por) values ('77000000-0000-4000-8000-000000000003', 'Familia C 07', '77000000-0000-4000-8000-0000000000e5') $$, 'criador sem perfil cria a familia');
insert into tap_out(line) select lives_ok($$ insert into public.profiles (id, family_id, nome, papel, status) values ('77000000-0000-4000-8000-0000000000e5', '77000000-0000-4000-8000-000000000003', 'Novo', 'admin', 'ativo') $$, 'criador sem perfil vira admin da propria familia');
reset role;
reset request.jwt.claim.sub;

set local role authenticated;
set local request.jwt.claim.sub = '77000000-0000-4000-8000-0000000000a1';
insert into tap_out(line) select is((select count(*) from public.profiles where family_id = '77000000-0000-4000-8000-000000000001'), 3::bigint, 'admin ve os 3 perfis da familia');
reset role;
reset request.jwt.claim.sub;

set local role authenticated;
set local request.jwt.claim.sub = '77000000-0000-4000-8000-0000000000b2';
insert into tap_out(line) select is((select count(*) from public.profiles), 1::bigint, 'membro ve apenas o proprio perfil');
reset role;
reset request.jwt.claim.sub;

set local role authenticated;
set local request.jwt.claim.sub = '77000000-0000-4000-8000-0000000000d4';
insert into tap_out(line) select is((select count(*) from public.profiles where family_id = '77000000-0000-4000-8000-000000000001'), 0::bigint, 'externo nao ve perfis da familia A');
reset role;
reset request.jwt.claim.sub;

set local role authenticated;
set local request.jwt.claim.sub = '77000000-0000-4000-8000-0000000000a1';
update public.profiles set status = 'inativo' where id = '77000000-0000-4000-8000-0000000000b2';
reset role;
reset request.jwt.claim.sub;
insert into tap_out(line) select is((select status from public.profiles where id = '77000000-0000-4000-8000-0000000000b2'), 'inativo', 'admin desativa membro comum');

set local role authenticated;
set local request.jwt.claim.sub = '77000000-0000-4000-8000-0000000000b2';
update public.profiles set status = 'inativo' where id = '77000000-0000-4000-8000-0000000000c3';
reset role;
reset request.jwt.claim.sub;
insert into tap_out(line) select is((select status from public.profiles where id = '77000000-0000-4000-8000-0000000000c3'), 'ativo', 'membro nao desativa outro membro');

set local role authenticated;
set local request.jwt.claim.sub = '77000000-0000-4000-8000-0000000000a1';
update public.profiles set status = 'ativo' where id = '77000000-0000-4000-8000-0000000000b2';
reset role;
reset request.jwt.claim.sub;

set local role authenticated;
set local request.jwt.claim.sub = '77000000-0000-4000-8000-0000000000b2';
update public.profiles set nome = 'Carlos Editado 07' where id = '77000000-0000-4000-8000-0000000000b2';
reset role;
reset request.jwt.claim.sub;
insert into tap_out(line) select is((select nome from public.profiles where id = '77000000-0000-4000-8000-0000000000b2'), 'Carlos Editado 07', 'membro edita o proprio nome');

set local role authenticated;
set local request.jwt.claim.sub = '77000000-0000-4000-8000-0000000000a1';
insert into tap_out(line) select throws_ok($$ update public.profiles set tema = 'escuro' where id = '77000000-0000-4000-8000-0000000000b2' $$, '42501', null, 'admin nao muda tema de outro membro');
reset role;
reset request.jwt.claim.sub;

set local role authenticated;
set local request.jwt.claim.sub = '77000000-0000-4000-8000-0000000000b2';
update public.profiles set tema = 'escuro' where id = '77000000-0000-4000-8000-0000000000b2';
reset role;
reset request.jwt.claim.sub;
insert into tap_out(line) select is((select tema from public.profiles where id = '77000000-0000-4000-8000-0000000000b2'), 'escuro', 'membro muda o proprio tema');

set local role authenticated;
set local request.jwt.claim.sub = '77000000-0000-4000-8000-0000000000a1';
insert into tap_out(line) select throws_ok($$ delete from public.families where id = '77000000-0000-4000-8000-000000000001' $$, '42501', null, 'familia nao tem delete');
insert into tap_out(line) select throws_ok($$ delete from public.profiles where id = '77000000-0000-4000-8000-0000000000b2' $$, '42501', null, 'perfil nao tem delete');
insert into tap_out(line) select is((select count(*) from public.categories where family_id = '77000000-0000-4000-8000-000000000001' and personalizada = false), 12::bigint, 'Ana ve as 12 categorias padrao');
reset role;
reset request.jwt.claim.sub;

set local role authenticated;
set local request.jwt.claim.sub = '77000000-0000-4000-8000-0000000000d4';
insert into tap_out(line) select is((select count(*) from public.categories where family_id = '77000000-0000-4000-8000-000000000001' and personalizada = false), 0::bigint, 'Externo nao ve categorias da familia A');
reset role;
reset request.jwt.claim.sub;

set local role authenticated;
set local request.jwt.claim.sub = '77000000-0000-4000-8000-0000000000b2';
insert into tap_out(line) select lives_ok($$ insert into public.categories (id, family_id, nome, tipo, personalizada, criado_por) values ('77000000-0000-4000-8000-0000000000f4', '77000000-0000-4000-8000-000000000001', 'Pet Carlos Novo 07', 'despesa', true, '77000000-0000-4000-8000-0000000000b2') $$, 'membro cria categoria personalizada');
insert into tap_out(line) select throws_ok($$ insert into public.categories (family_id, nome, tipo, personalizada, criado_por) values ('77000000-0000-4000-8000-000000000001', 'Default 07', 'despesa', false, '77000000-0000-4000-8000-0000000000b2') $$, '42501', null, 'membro nao cria categoria padrao');
insert into tap_out(line) select throws_ok($$ insert into public.categories (family_id, nome, tipo, personalizada, criado_por) values ('77000000-0000-4000-8000-000000000002', 'Pet B 07', 'despesa', true, '77000000-0000-4000-8000-0000000000b2') $$, '42501', null, 'membro nao cria categoria em outra familia');
insert into tap_out(line) select throws_ok($$ update public.categories set nome = 'Alimentacao 07' where id = (select id from public.categories where family_id = '77000000-0000-4000-8000-000000000001' and personalizada = false and tipo = 'despesa' and nome = 'Alimentação') $$, '42501', null, 'categoria padrao nao e renomeada');
update public.categories set oculta = true where id = (select id from public.categories where family_id = '77000000-0000-4000-8000-000000000001' and personalizada = false and tipo = 'despesa' and nome = 'Alimentação');
update public.categories set nome = 'Pet Ana Editado 07' where id = '77000000-0000-4000-8000-0000000000f1';
reset role;
reset request.jwt.claim.sub;
insert into tap_out(line) select is((select oculta from public.categories where id = (select id from public.categories where family_id = '77000000-0000-4000-8000-000000000001' and personalizada = false and tipo = 'despesa' and nome = 'Alimentação')), true, 'categoria padrao pode ser ocultada');
insert into tap_out(line) select is((select nome from public.categories where id = '77000000-0000-4000-8000-0000000000f1'), 'Pet Ana 07', 'Carlos nao renomeia categoria de Ana');

set local role authenticated;
set local request.jwt.claim.sub = '77000000-0000-4000-8000-0000000000a1';
update public.categories set nome = 'Pet Ana Editado 07' where id = '77000000-0000-4000-8000-0000000000f1';
delete from public.categories where id = (select id from public.categories where family_id = '77000000-0000-4000-8000-000000000001' and personalizada = false and tipo = 'despesa' and nome = 'Alimentação');
reset role;
reset request.jwt.claim.sub;
insert into tap_out(line) select is((select nome from public.categories where id = '77000000-0000-4000-8000-0000000000f1'), 'Pet Ana Editado 07', 'Ana renomeia a propria categoria');
insert into tap_out(line) select is((select count(*) from public.categories where id = (select id from public.categories where family_id = '77000000-0000-4000-8000-000000000001' and personalizada = false and tipo = 'despesa' and nome = 'Alimentação')), 1::bigint, 'Ana nao apaga categoria padrao');

set local role authenticated;
set local request.jwt.claim.sub = '77000000-0000-4000-8000-0000000000b2';
delete from public.categories where id = '77000000-0000-4000-8000-0000000000f2';
delete from public.categories where id = '77000000-0000-4000-8000-0000000000f1';
delete from public.categories where id = '77000000-0000-4000-8000-0000000000f3';
update public.categories set oculta = true where id = '77000000-0000-4000-8000-0000000000f3';
reset role;
reset request.jwt.claim.sub;
insert into tap_out(line) select is((select count(*) from public.categories where id = '77000000-0000-4000-8000-0000000000f2'), 0::bigint, 'Carlos apaga a propria categoria sem uso');
insert into tap_out(line) select is((select count(*) from public.categories where id = '77000000-0000-4000-8000-0000000000f1'), 1::bigint, 'Carlos nao apaga categoria de Ana');
insert into tap_out(line) select is((select count(*) from public.categories where id = '77000000-0000-4000-8000-0000000000f3'), 1::bigint, 'categoria em uso nao e apagada');
insert into tap_out(line) select is((select oculta from public.categories where id = '77000000-0000-4000-8000-0000000000f3'), true, 'categoria em uso pode ser ocultada');

insert into tap_out(line) select is(has_table_privilege('authenticated', 'public.families', 'DELETE'), false, 'families sem grant de delete');
insert into tap_out(line) select is(has_table_privilege('authenticated', 'public.profiles', 'DELETE'), false, 'profiles sem grant de delete');
insert into tap_out(line) select is((select count(*) from pg_policies where schemaname = 'public' and tablename in ('families', 'profiles') and cmd = 'DELETE'), 0::bigint, 'familias e perfis sem policy de delete');

insert into tap_out(line) select * from finish();

select string_agg(line, E'\n' order by seq) as tap from tap_out;
rollback;
