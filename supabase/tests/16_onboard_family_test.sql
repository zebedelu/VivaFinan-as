begin;
set local search_path = public, extensions;

create temp table tap_out(seq serial, line text);
grant all on tap_out to public;
grant all on sequence tap_out_seq_seq to public;

create temp table onb(seq serial, family_id uuid, profile_id uuid);
grant all on onb to public;
grant all on sequence onb_seq_seq to public;

insert into auth.users (id, email) values
  ('ac000000-0000-4000-8000-0000000000a1', 'novo.ac000000@test.local'),
  ('ac000000-0000-4000-8000-0000000000b2', 'existente.ac000000@test.local'),
  ('ac000000-0000-4000-8000-0000000000c3', 'orfao.ac000000@test.local'),
  ('ac000000-0000-4000-8000-0000000000d4', 'orfao.com.perfis.ac000000@test.local'),
  ('ac000000-0000-4000-8000-0000000000e5', 'espacos.ac000000@test.local'),
  ('ac000000-0000-4000-8000-0000000000e6', 'perfil.d.ac000000@test.local');

insert into public.families (id, nome, criado_por) values
  ('ac000000-0000-4000-8000-000000000002', 'Familia Existente 16', 'ac000000-0000-4000-8000-0000000000b2'),
  ('ac000000-0000-4000-8000-000000000003', 'Familia Orfa 16', 'ac000000-0000-4000-8000-0000000000c3'),
  ('ac000000-0000-4000-8000-000000000004', 'Familia D 16', 'ac000000-0000-4000-8000-0000000000d4');

insert into public.profiles (id, family_id, nome, papel, status) values
  ('ac000000-0000-4000-8000-0000000000b2', 'ac000000-0000-4000-8000-000000000002', 'Existente', 'admin', 'ativo'),
  ('ac000000-0000-4000-8000-0000000000e6', 'ac000000-0000-4000-8000-000000000004', 'Perfil D', 'membro', 'ativo');

insert into tap_out(line) select plan(30);

-- novo usuario cria familia e perfil admin
set local role authenticated;
set local request.jwt.claim.sub = 'ac000000-0000-4000-8000-0000000000a1';
insert into onb(family_id, profile_id) select * from public.onboard_family('Familia Nova 16', 'Novo');
insert into tap_out(line) select is((select count(*) from onb where seq = 1), 1::bigint, 'onboard devolve familia e perfil');
insert into tap_out(line) select is((select p.papel || '|' || p.status || '|' || p.nome from public.profiles p where p.id = 'ac000000-0000-4000-8000-0000000000a1' and p.family_id = (select family_id from onb where seq = 1)), 'admin|ativo|Novo', 'novo usuario vira admin ativo');
insert into tap_out(line) select is((select count(*) from public.categories where family_id = (select family_id from onb where seq = 1)), 12::bigint, 'trigger cria as 12 categorias');
insert into tap_out(line) select is((select count(*) from public.families where criado_por = 'ac000000-0000-4000-8000-0000000000a1'), 1::bigint, 'onboard cria uma familia');

-- idempotencia
insert into onb(family_id, profile_id) select * from public.onboard_family('Familia Nova 16', 'Novo');
insert into tap_out(line) select is((select family_id from onb where seq = 2), (select family_id from onb where seq = 1), 'segunda chamada devolve a mesma familia');
insert into tap_out(line) select is((select profile_id from onb where seq = 2), (select profile_id from onb where seq = 1), 'segunda chamada devolve o mesmo perfil');
insert into tap_out(line) select is((select count(*) from public.families where criado_por = 'ac000000-0000-4000-8000-0000000000a1'), 1::bigint, 'segunda chamada nao cria outra familia');
insert into tap_out(line) select is((select count(*) from public.profiles where id = 'ac000000-0000-4000-8000-0000000000a1'), 1::bigint, 'segunda chamada nao cria outro perfil');
insert into tap_out(line) select is((select count(*) from public.categories where family_id = (select family_id from onb where seq = 1)), 12::bigint, 'segunda chamada nao duplica categorias');
reset role;
reset request.jwt.claim.sub;

-- usuario que ja tem perfil
set local role authenticated;
set local request.jwt.claim.sub = 'ac000000-0000-4000-8000-0000000000b2';
insert into onb(family_id, profile_id) select * from public.onboard_family('Outra Familia 16', 'Outro Nome');
insert into tap_out(line) select is((select family_id::text || '|' || profile_id::text from onb where seq = 3), 'ac000000-0000-4000-8000-000000000002|ac000000-0000-4000-8000-0000000000b2', 'perfil existente devolve familia e perfil atuais');
reset role;
reset request.jwt.claim.sub;
insert into tap_out(line) select is((select count(*) from public.families where criado_por = 'ac000000-0000-4000-8000-0000000000b2'), 1::bigint, 'perfil existente nao cria familia');
insert into tap_out(line) select is((select count(*) from public.profiles where id = 'ac000000-0000-4000-8000-0000000000b2'), 1::bigint, 'perfil existente nao duplica perfil');

-- familia orfa e adotada
set local role authenticated;
set local request.jwt.claim.sub = 'ac000000-0000-4000-8000-0000000000c3';
insert into onb(family_id, profile_id) select * from public.onboard_family('Ignorada 16', 'Orfao');
insert into tap_out(line) select is((select family_id::text || '|' || profile_id::text from onb where seq = 4), 'ac000000-0000-4000-8000-000000000003|ac000000-0000-4000-8000-0000000000c3', 'familia orfa e adotada');
reset role;
reset request.jwt.claim.sub;
insert into tap_out(line) select is((select papel || '|' || status from public.profiles where id = 'ac000000-0000-4000-8000-0000000000c3'), 'admin|ativo', 'perfil adotado e admin ativo');
insert into tap_out(line) select is((select count(*) from public.categories where family_id = 'ac000000-0000-4000-8000-000000000003'), 12::bigint, 'familia orfa mantem as 12 categorias');
insert into tap_out(line) select is((select count(*) from public.families where criado_por = 'ac000000-0000-4000-8000-0000000000c3'), 1::bigint, 'adocao nao cria outra familia');

-- familia orfa com perfis e estado impossivel
set local role authenticated;
set local request.jwt.claim.sub = 'ac000000-0000-4000-8000-0000000000d4';
insert into tap_out(line) select throws_ok($$
  select * from public.onboard_family('Familia D 16', 'Dono')
$$, '23505', null, 'familia orfa com perfis levanta 23505');
reset role;
reset request.jwt.claim.sub;

-- nomes com espacos sao normalizados
set local role authenticated;
set local request.jwt.claim.sub = 'ac000000-0000-4000-8000-0000000000e5';
insert into onb(family_id, profile_id) select * from public.onboard_family('  Familia Padded  ', '  Nome Padded  ');
insert into tap_out(line) select is((select nome from public.families where id = (select family_id from onb where seq = 5)), 'Familia Padded', 'nome da familia e aparado');
insert into tap_out(line) select is((select nome from public.profiles where id = 'ac000000-0000-4000-8000-0000000000e5'), 'Nome Padded', 'nome do perfil e aparado');
reset role;
reset request.jwt.claim.sub;

-- validacao de nomes
set local role authenticated;
set local request.jwt.claim.sub = 'ac000000-0000-4000-8000-0000000000a1';
insert into tap_out(line) select throws_ok($$ select * from public.onboard_family(null, 'Nome') $$, '22023', null, 'familia nula e recusada');
insert into tap_out(line) select throws_ok($$ select * from public.onboard_family('Familia', null) $$, '22023', null, 'nome nulo e recusado');
insert into tap_out(line) select throws_ok($$ select * from public.onboard_family('', 'Nome') $$, '22023', null, 'familia vazia e recusada');
insert into tap_out(line) select throws_ok($$ select * from public.onboard_family('Familia', '   ') $$, '22023', null, 'nome em branco e recusado');
insert into tap_out(line) select throws_ok($$ select * from public.onboard_family(repeat('a', 81), 'Nome') $$, '22023', null, 'familia com mais de 80 caracteres e recusada');
insert into tap_out(line) select throws_ok($$ select * from public.onboard_family('Familia', repeat('a', 81)) $$, '22023', null, 'nome com mais de 80 caracteres e recusado');
reset role;
reset request.jwt.claim.sub;

insert into tap_out(line) select throws_ok($$ select * from public.onboard_family('Familia', 'Nome') $$, '42501', null, 'sem autenticacao e recusado');

insert into tap_out(line) select is(has_function_privilege('anon', 'public.onboard_family(text,text)', 'EXECUTE'), false, 'anon nao executa onboard_family');
insert into tap_out(line) select is(has_function_privilege('authenticated', 'public.onboard_family(text,text)', 'EXECUTE'), true, 'authenticated executa onboard_family');
insert into tap_out(line) select is((select prosecdef from pg_proc where oid = 'public.onboard_family(text,text)'::regprocedure), true, 'onboard_family e security definer');
insert into tap_out(line) select is((select proconfig @> array['search_path='] or proconfig @> array['search_path=""'] from pg_proc where oid = 'public.onboard_family(text,text)'::regprocedure), true, 'onboard_family usa search_path vazio');

insert into tap_out(line) select * from finish();

select string_agg(line, E'\n' order by seq) as tap from tap_out;
rollback;
