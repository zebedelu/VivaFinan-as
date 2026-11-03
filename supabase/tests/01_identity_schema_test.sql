begin;
set local search_path = public, extensions;

create temp table tap_out(seq serial, line text);
grant all on tap_out to public;
grant all on sequence tap_out_seq_seq to public;

insert into auth.users (id, email) values
  ('11000000-0000-4000-8000-0000000000a1', 'ana.11000000@test.local'),
  ('11000000-0000-4000-8000-0000000000b2', 'carlos.11000000@test.local'),
  ('11000000-0000-4000-8000-0000000000c3', 'lucas.11000000@test.local'),
  ('11000000-0000-4000-8000-0000000000d4', 'externo.11000000@test.local'),
  ('11000000-0000-4000-8000-0000000000e5', 'invalido.11000000@test.local');

insert into public.families (id, nome, criado_por) values
  ('11000000-0000-4000-8000-000000000001', 'Familia Teste A', '11000000-0000-4000-8000-0000000000a1'),
  ('11000000-0000-4000-8000-000000000002', 'Familia Teste B', '11000000-0000-4000-8000-0000000000d4');

insert into public.profiles (id, family_id, nome, papel, status) values
  ('11000000-0000-4000-8000-0000000000a1', '11000000-0000-4000-8000-000000000001', 'Ana', 'admin', 'ativo'),
  ('11000000-0000-4000-8000-0000000000b2', '11000000-0000-4000-8000-000000000001', 'Carlos', 'membro', 'ativo'),
  ('11000000-0000-4000-8000-0000000000c3', '11000000-0000-4000-8000-000000000001', 'Lucas', 'membro', 'ativo'),
  ('11000000-0000-4000-8000-0000000000d4', '11000000-0000-4000-8000-000000000002', 'Externo', 'admin', 'ativo');

insert into tap_out(line) select plan(12);

insert into tap_out(line) select has_table('public', 'families', 'tabela families existe');
insert into tap_out(line) select has_table('public', 'profiles', 'tabela profiles existe');
insert into tap_out(line) select has_table('public', 'categories', 'tabela categories existe');
insert into tap_out(line) select has_column('public', 'profiles', 'tema', 'profiles guarda o tema');
insert into tap_out(line) select col_type_is('public', 'profiles', 'tema', 'text', 'tema e text');
insert into tap_out(line) select has_column('public', 'categories', 'personalizada', 'categories marca personalizada');
insert into tap_out(line) select col_type_is('public', 'categories', 'personalizada', 'boolean', 'personalizada e boolean');

insert into tap_out(line) select throws_ok($$ insert into public.profiles (id, family_id, nome, papel, status)
  values ('11000000-0000-4000-8000-0000000000e5', '11000000-0000-4000-8000-000000000001', 'Invalido', 'dono', 'ativo') $$,
  '23514', null, 'papel invalido e recusado');

insert into tap_out(line) select throws_ok($$ insert into public.categories (family_id, nome, tipo)
  values ('11000000-0000-4000-8000-000000000001', 'Pet', 'investimento') $$,
  '23514', null, 'tipo de categoria invalido e recusado');

insert into tap_out(line) select throws_ok($$ insert into public.categories (family_id, nome, tipo)
  values ('11000000-0000-4000-8000-000000000001', 'Pet', 'despesa'),
         ('11000000-0000-4000-8000-000000000001', 'Pet', 'despesa') $$,
  '23505', null, 'categoria duplicada na familia e recusada');

insert into tap_out(line) select ok((select relrowsecurity from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'families'), 'RLS habilitado em families');
insert into tap_out(line) select ok((select relrowsecurity from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'profiles'), 'RLS habilitado em profiles');

insert into tap_out(line) select * from finish();

select string_agg(line, E'\n' order by seq) as tap from tap_out;
rollback;
