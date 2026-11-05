begin;
set local search_path = public, extensions;

create temp table tap_out(seq serial, line text);
grant all on tap_out to public;
grant all on sequence tap_out_seq_seq to public;

insert into auth.users (id, email) values
  ('dd000000-0000-4000-8000-0000000000a1', 'ana.dd000000@test.local'),
  ('dd000000-0000-4000-8000-0000000000b2', 'carlos.dd000000@test.local'),
  ('dd000000-0000-4000-8000-0000000000c3', 'convidado.dd000000@test.local'),
  ('dd000000-0000-4000-8000-0000000000d4', 'externo.dd000000@test.local'),
  ('dd000000-0000-4000-8000-0000000000e5', 'espacos.dd000000@test.local');

insert into public.families (id, nome, criado_por) values
  ('dd000000-0000-4000-8000-000000000001', 'Familia Teste A 14', 'dd000000-0000-4000-8000-0000000000a1'),
  ('dd000000-0000-4000-8000-000000000002', 'Familia Teste B 14', 'dd000000-0000-4000-8000-0000000000d4');

insert into public.profiles (id, family_id, nome, papel, status) values
  ('dd000000-0000-4000-8000-0000000000a1', 'dd000000-0000-4000-8000-000000000001', 'Ana', 'admin', 'ativo'),
  ('dd000000-0000-4000-8000-0000000000b2', 'dd000000-0000-4000-8000-000000000001', 'Carlos', 'membro', 'ativo'),
  ('dd000000-0000-4000-8000-0000000000d4', 'dd000000-0000-4000-8000-000000000002', 'Externo', 'admin', 'ativo');

insert into tap_out(line) select plan(44);

-- admin da familia B cria o proprio convite
set local role authenticated;
set local request.jwt.claim.sub = 'dd000000-0000-4000-8000-0000000000d4';
set local request.jwt.claim.email = 'externo.dd000000@test.local';
insert into tap_out(line) select lives_ok($$
  insert into public.invites (id, family_id, family_nome, email, nome, token, criado_por)
  values ('dd000000-0000-4000-8000-000000000e03', 'dd000000-0000-4000-8000-000000000002', 'Familia Teste B 14', 'membro.b.dd000000@test.local', 'Membro B',
          'dd000000-0000-4000-8000-000000000e03', 'dd000000-0000-4000-8000-0000000000d4')
$$, 'admin B cria convite');
reset role;
reset request.jwt.claim.sub;
reset request.jwt.claim.email;

-- admin da familia A cria dois convites
set local role authenticated;
set local request.jwt.claim.sub = 'dd000000-0000-4000-8000-0000000000a1';
set local request.jwt.claim.email = 'ana.dd000000@test.local';
insert into tap_out(line) select lives_ok($$
  insert into public.invites (id, family_id, family_nome, email, nome, token, criado_por)
  values ('dd000000-0000-4000-8000-000000000e01', 'dd000000-0000-4000-8000-000000000001', 'Familia Teste A 14', 'convidado.dd000000@test.local', 'Convidado',
          'dd000000-0000-4000-8000-000000000e01', 'dd000000-0000-4000-8000-0000000000a1')
$$, 'admin A cria convite para convidado');
insert into tap_out(line) select lives_ok($$
  insert into public.invites (id, family_id, family_nome, email, nome, token, criado_por)
  values ('dd000000-0000-4000-8000-000000000e02', 'dd000000-0000-4000-8000-000000000001', 'Familia Teste A 14', 'outro.dd000000@test.local', 'Outro',
          'dd000000-0000-4000-8000-000000000e02', 'dd000000-0000-4000-8000-0000000000a1')
$$, 'admin A cria segundo convite');
insert into tap_out(line) select is((select count(*) from public.invites), 2::bigint, 'admin A ve os dois convites da familia');
insert into tap_out(line) select is((select count(*) from public.invites where family_id = 'dd000000-0000-4000-8000-000000000002'), 0::bigint, 'admin A nao ve convite da familia B');
reset role;
reset request.jwt.claim.sub;
reset request.jwt.claim.email;

-- membro comum nao administra convites
set local role authenticated;
set local request.jwt.claim.sub = 'dd000000-0000-4000-8000-0000000000b2';
set local request.jwt.claim.email = 'carlos.dd000000@test.local';
insert into tap_out(line) select throws_ok($$
  insert into public.invites (family_id, family_nome, email, nome, criado_por)
  values ('dd000000-0000-4000-8000-000000000001', 'Familia Teste A 14', 'novo.dd000000@test.local', 'Novo', 'dd000000-0000-4000-8000-0000000000b2')
$$, '42501', null, 'membro comum nao cria convite');
insert into tap_out(line) select is((select count(*) from public.invites), 0::bigint, 'membro comum nao ve convites');
reset role;
reset request.jwt.claim.sub;
reset request.jwt.claim.email;

-- convidado le apenas o proprio convite pendente
set local role authenticated;
set local request.jwt.claim.sub = 'dd000000-0000-4000-8000-0000000000c3';
set local request.jwt.claim.email = 'convidado.dd000000@test.local';
insert into tap_out(line) select is((select count(*) from public.invites), 1::bigint, 'convidado ve apenas um convite');
insert into tap_out(line) select is((select count(*) from public.invites where id = 'dd000000-0000-4000-8000-000000000e01'), 1::bigint, 'convidado ve o proprio convite');
insert into tap_out(line) select is((select family_nome from public.invites where id = 'dd000000-0000-4000-8000-000000000e01'), 'Familia Teste A 14', 'convite carrega o snapshot do nome da familia');
insert into tap_out(line) select is((select count(*) from public.invites where id = 'dd000000-0000-4000-8000-000000000e02'), 0::bigint, 'convidado nao ve convite de outro e-mail');
with u as (update public.invites set status = 'cancelado' where id = 'dd000000-0000-4000-8000-000000000e01' returning 1)
insert into tap_out(line) select is((select count(*) from u), 0::bigint, 'convidado nao atualiza convite');
with d as (delete from public.invites where id = 'dd000000-0000-4000-8000-000000000e01' returning 1)
insert into tap_out(line) select is((select count(*) from d), 0::bigint, 'convidado nao apaga convite');
insert into tap_out(line) select throws_ok($$
  insert into public.invites (family_id, family_nome, email, nome, criado_por)
  values ('dd000000-0000-4000-8000-000000000001', 'Familia Teste A 14', 'invasor.dd000000@test.local', 'Invasor', 'dd000000-0000-4000-8000-0000000000c3')
$$, '42501', null, 'convidado nao insere convite');
reset role;
reset request.jwt.claim.sub;
reset request.jwt.claim.email;

-- admin de outra familia nao toca no convite
set local role authenticated;
set local request.jwt.claim.sub = 'dd000000-0000-4000-8000-0000000000d4';
set local request.jwt.claim.email = 'externo.dd000000@test.local';
insert into tap_out(line) select is((select count(*) from public.invites where family_id = 'dd000000-0000-4000-8000-000000000001'), 0::bigint, 'admin B nao ve convites da familia A');
with u as (update public.invites set status = 'cancelado' where id = 'dd000000-0000-4000-8000-000000000e01' returning 1)
insert into tap_out(line) select is((select count(*) from u), 0::bigint, 'admin B nao atualiza convite da familia A');
reset role;
reset request.jwt.claim.sub;
reset request.jwt.claim.email;
insert into tap_out(line) select is((select status from public.invites where id = 'dd000000-0000-4000-8000-000000000e01'), 'pendente', 'convite da familia A intacto');

-- constraints
set local role authenticated;
set local request.jwt.claim.sub = 'dd000000-0000-4000-8000-0000000000a1';
set local request.jwt.claim.email = 'ana.dd000000@test.local';
insert into tap_out(line) select throws_ok($$
  insert into public.invites (family_id, family_nome, email, nome, criado_por)
  values ('dd000000-0000-4000-8000-000000000001', 'Familia Teste A 14', 'convidado.dd000000@test.local', 'Duplicado', 'dd000000-0000-4000-8000-0000000000a1')
$$, '23505', null, 'convite pendente duplicado e recusado');
insert into tap_out(line) select throws_ok($$
  insert into public.invites (family_id, family_nome, email, nome, papel, criado_por)
  values ('dd000000-0000-4000-8000-000000000001', 'Familia Teste A 14', 'admin.dd000000@test.local', 'Admin', 'admin', 'dd000000-0000-4000-8000-0000000000a1')
$$, '23514', null, 'papel do convite so pode ser membro');
insert into tap_out(line) select throws_ok($$
  insert into public.invites (family_id, family_nome, email, nome, criado_por)
  values ('dd000000-0000-4000-8000-000000000001', null, 'semfamilia.dd000000@test.local', 'Sem Familia', 'dd000000-0000-4000-8000-0000000000a1')
$$, '23502', null, 'family_nome nulo e recusado');
insert into tap_out(line) select throws_ok($$
  insert into public.invites (family_id, family_nome, email, nome, criado_por)
  values ('dd000000-0000-4000-8000-000000000001', '   ', 'vazio.dd000000@test.local', 'Vazio', 'dd000000-0000-4000-8000-0000000000a1')
$$, '23514', null, 'family_nome vazio e recusado');
reset role;
reset request.jwt.claim.sub;
reset request.jwt.claim.email;

-- aceite: token e e-mail precisam bater
set local role authenticated;
set local request.jwt.claim.sub = 'dd000000-0000-4000-8000-0000000000c3';
set local request.jwt.claim.email = 'convidado.dd000000@test.local';
insert into tap_out(line) select throws_ok($$
  select * from public.accept_invite('dd000000-0000-4000-8000-000000000e99', 'Convidado')
$$, '42501', null, 'token inexistente e recusado');
set local request.jwt.claim.email = 'outro.dd000000@test.local';
insert into tap_out(line) select throws_ok($$
  select * from public.accept_invite('dd000000-0000-4000-8000-000000000e01', 'Convidado')
$$, '42501', null, 'e-mail diferente do convite e recusado');
set local request.jwt.claim.email = 'convidado.dd000000@test.local';
insert into tap_out(line) select is(
  (select profile_id::text || '|' || family_id::text from public.accept_invite('dd000000-0000-4000-8000-000000000e01', 'Nome Aceito')),
  'dd000000-0000-4000-8000-0000000000c3|dd000000-0000-4000-8000-000000000001',
  'aceite cria perfil na familia do convite');
reset role;
reset request.jwt.claim.sub;
reset request.jwt.claim.email;

insert into tap_out(line) select is((select papel || '|' || status || '|' || nome from public.profiles where id = 'dd000000-0000-4000-8000-0000000000c3'), 'membro|ativo|Nome Aceito', 'perfil aceito e membro ativo com nome informado');
insert into tap_out(line) select is((select status from public.invites where id = 'dd000000-0000-4000-8000-000000000e01'), 'aceito', 'convite aceito muda de status');

set local role authenticated;
set local request.jwt.claim.sub = 'dd000000-0000-4000-8000-0000000000c3';
set local request.jwt.claim.email = 'convidado.dd000000@test.local';
insert into tap_out(line) select is((select count(*) from public.invites), 0::bigint, 'convidado nao ve mais o convite aceito');
insert into tap_out(line) select throws_ok($$
  select * from public.accept_invite('dd000000-0000-4000-8000-000000000e01', 'Nome Aceito')
$$, '42501', null, 'convite ja aceito e recusado');
reset role;
reset request.jwt.claim.sub;
reset request.jwt.claim.email;

insert into public.invites (id, family_id, family_nome, email, nome, token, criado_por)
values ('dd000000-0000-4000-8000-000000000e05', 'dd000000-0000-4000-8000-000000000001', 'Familia Teste A 14', 'espacos.dd000000@test.local', 'Outro',
        'dd000000-0000-4000-8000-000000000e05', 'dd000000-0000-4000-8000-0000000000a1');

set local role authenticated;
set local request.jwt.claim.sub = 'dd000000-0000-4000-8000-0000000000e5';
set local request.jwt.claim.email = 'espacos.dd000000@test.local';
insert into tap_out(line) select throws_ok($$
  select * from public.accept_invite('dd000000-0000-4000-8000-000000000e05', repeat('a', 81))
$$, '22023', null, 'nome do aceite com mais de 80 caracteres e recusado');
reset role;
reset request.jwt.claim.sub;
reset request.jwt.claim.email;

-- perfil existente: 23505 (backend mapeia para 409)
set local role authenticated;
set local request.jwt.claim.sub = 'dd000000-0000-4000-8000-0000000000a1';
set local request.jwt.claim.email = 'ana.dd000000@test.local';
insert into tap_out(line) select lives_ok($$
  insert into public.invites (id, family_id, family_nome, email, nome, token, criado_por)
  values ('dd000000-0000-4000-8000-000000000e04', 'dd000000-0000-4000-8000-000000000001', 'Familia Teste A 14', 'ana.dd000000@test.local', 'Ana',
          'dd000000-0000-4000-8000-000000000e04', 'dd000000-0000-4000-8000-0000000000a1')
$$, 'admin cria convite para e-mail com perfil');
insert into tap_out(line) select throws_ok($$
  select * from public.accept_invite('dd000000-0000-4000-8000-000000000e04', 'Ana')
$$, '23505', null, 'perfil existente recusa o aceite com 23505');
reset role;
reset request.jwt.claim.sub;
reset request.jwt.claim.email;

-- admin cancela e apaga convites
set local role authenticated;
set local request.jwt.claim.sub = 'dd000000-0000-4000-8000-0000000000a1';
set local request.jwt.claim.email = 'ana.dd000000@test.local';
with u as (update public.invites set status = 'cancelado' where id = 'dd000000-0000-4000-8000-000000000e02' returning 1)
insert into tap_out(line) select is((select count(*) from u), 1::bigint, 'admin cancela convite da propria familia');
with d as (delete from public.invites where id = 'dd000000-0000-4000-8000-000000000e02' returning 1)
insert into tap_out(line) select is((select count(*) from d), 1::bigint, 'admin apaga convite da propria familia');
reset role;
reset request.jwt.claim.sub;
reset request.jwt.claim.email;

-- RLS e hardening
insert into tap_out(line) select is((select relrowsecurity from pg_class where oid = 'public.invites'::regclass), true, 'invites tem RLS habilitado');
insert into tap_out(line) select is((select count(*) from pg_policies where schemaname = 'public' and tablename = 'invites'), 4::bigint, 'invites tem quatro policies');
insert into tap_out(line) select is((select array_agg(cmd order by cmd) from pg_policies where schemaname = 'public' and tablename = 'invites'), array['DELETE','INSERT','SELECT','UPDATE'], 'policies cobrem select/insert/update/delete');
insert into tap_out(line) select is((select count(*) from pg_policies where schemaname = 'public' and tablename = 'invites' and cmd = 'UPDATE' and with_check is not null), 1::bigint, 'update tem with check explicito');
insert into tap_out(line) select is(has_table_privilege('anon', 'public.invites', 'SELECT'), false, 'anon nao le invites');
insert into tap_out(line) select is((select bool_and(has_table_privilege('authenticated', 'public.invites', p)) from unnest(array['SELECT','INSERT','UPDATE','DELETE']) p), true, 'authenticated tem select/insert/update/delete');
insert into tap_out(line) select is(has_table_privilege('authenticated', 'public.invites', 'TRUNCATE'), false, 'authenticated nao tem truncate em invites');
insert into tap_out(line) select is(has_function_privilege('anon', 'public.accept_invite(uuid,text)', 'EXECUTE'), false, 'anon nao executa accept_invite');
insert into tap_out(line) select is(has_function_privilege('authenticated', 'public.accept_invite(uuid,text)', 'EXECUTE'), true, 'authenticated executa accept_invite');
insert into tap_out(line) select is((select prosecdef from pg_proc where oid = 'public.accept_invite(uuid,text)'::regprocedure), true, 'accept_invite e security definer');
insert into tap_out(line) select is((select proconfig @> array['search_path='] or proconfig @> array['search_path=""'] from pg_proc where oid = 'public.accept_invite(uuid,text)'::regprocedure), true, 'accept_invite usa search_path vazio');

insert into tap_out(line) select * from finish();

select string_agg(line, E'\n' order by seq) as tap from tap_out;
rollback;
