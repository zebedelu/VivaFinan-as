begin;
set local search_path = public, extensions;

create temp table tap_out(seq serial, line text);
grant all on tap_out to public;
grant all on sequence tap_out_seq_seq to public;

insert into auth.users (id, email) values
  ('aa000000-0000-4000-8000-0000000000a1', 'ana.aa000000@test.local'),
  ('aa000000-0000-4000-8000-0000000000b2', 'carlos.aa000000@test.local'),
  ('aa000000-0000-4000-8000-0000000000d4', 'externo.aa000000@test.local');

insert into public.families (id, nome, criado_por) values
  ('aa000000-0000-4000-8000-000000000001', 'Familia Teste A 10', 'aa000000-0000-4000-8000-0000000000a1'),
  ('aa000000-0000-4000-8000-000000000002', 'Familia Teste B 10', 'aa000000-0000-4000-8000-0000000000d4');

insert into public.profiles (id, family_id, nome, papel, status) values
  ('aa000000-0000-4000-8000-0000000000a1', 'aa000000-0000-4000-8000-000000000001', 'Ana', 'admin', 'ativo'),
  ('aa000000-0000-4000-8000-0000000000b2', 'aa000000-0000-4000-8000-000000000001', 'Carlos', 'membro', 'ativo'),
  ('aa000000-0000-4000-8000-0000000000d4', 'aa000000-0000-4000-8000-000000000002', 'Externo', 'admin', 'ativo');

insert into public.goals (id, family_id, member_id, criado_por, titulo, valor_alvo) values
  ('aa000000-0000-4000-8000-0000000000f1', 'aa000000-0000-4000-8000-000000000001', null, 'aa000000-0000-4000-8000-0000000000a1', 'Meta Familia 10', 1000),
  ('aa000000-0000-4000-8000-0000000000f2', 'aa000000-0000-4000-8000-000000000001', 'aa000000-0000-4000-8000-0000000000a1', 'aa000000-0000-4000-8000-0000000000a1', 'Meta Pessoal Ana 10', 500),
  ('aa000000-0000-4000-8000-0000000000f3', 'aa000000-0000-4000-8000-000000000001', 'aa000000-0000-4000-8000-0000000000b2', 'aa000000-0000-4000-8000-0000000000b2', 'Meta Pessoal Carlos 10', 500),
  ('aa000000-0000-4000-8000-0000000000f4', 'aa000000-0000-4000-8000-000000000001', null, 'aa000000-0000-4000-8000-0000000000a1', 'Meta Alvo 10', 100),
  ('aa000000-0000-4000-8000-0000000000f5', 'aa000000-0000-4000-8000-000000000001', null, 'aa000000-0000-4000-8000-0000000000a1', 'Meta Delete 10', 100),
  ('aa000000-0000-4000-8000-0000000000f6', 'aa000000-0000-4000-8000-000000000001', null, 'aa000000-0000-4000-8000-0000000000a1', 'Meta Cancel 10', 100);

insert into public.goal_contributions (id, goal_id, member_id, valor) values
  ('aa000000-0000-4000-8000-0000000000e1', 'aa000000-0000-4000-8000-0000000000f1', 'aa000000-0000-4000-8000-0000000000a1', 100),
  ('aa000000-0000-4000-8000-0000000000e2', 'aa000000-0000-4000-8000-0000000000f2', 'aa000000-0000-4000-8000-0000000000a1', 100),
  ('aa000000-0000-4000-8000-0000000000e3', 'aa000000-0000-4000-8000-0000000000f3', 'aa000000-0000-4000-8000-0000000000b2', 100),
  ('aa000000-0000-4000-8000-0000000000e4', 'aa000000-0000-4000-8000-0000000000f4', 'aa000000-0000-4000-8000-0000000000b2', 100),
  ('aa000000-0000-4000-8000-0000000000e5', 'aa000000-0000-4000-8000-0000000000f5', 'aa000000-0000-4000-8000-0000000000a1', 100),
  ('aa000000-0000-4000-8000-0000000000e6', 'aa000000-0000-4000-8000-0000000000f6', 'aa000000-0000-4000-8000-0000000000a1', 100);

insert into public.ai_messages (id, family_id, member_id, role, content) values
  ('aa000000-0000-4000-8000-0000000000d1', 'aa000000-0000-4000-8000-000000000001', null, 'assistant', 'Mensagem familia'),
  ('aa000000-0000-4000-8000-0000000000d2', 'aa000000-0000-4000-8000-000000000001', 'aa000000-0000-4000-8000-0000000000a1', 'assistant', 'Mensagem Ana');

insert into public.ai_suggestions (id, family_id, member_id, tipo, titulo, o_que, por_que, quanto) values
  ('aa000000-0000-4000-8000-0000000000c1', 'aa000000-0000-4000-8000-000000000001', null, 'dica', 'Sugestao familia', 'O que', 'Por que', 'Quanto'),
  ('aa000000-0000-4000-8000-0000000000c2', 'aa000000-0000-4000-8000-000000000001', 'aa000000-0000-4000-8000-0000000000a1', 'dica', 'Sugestao Ana', 'O que', 'Por que', 'Quanto');

insert into tap_out(line) select plan(39);

set local role authenticated; set local request.jwt.claim.sub = 'aa000000-0000-4000-8000-0000000000b2';
insert into tap_out(line) select is((select count(*) from public.goals where id = 'aa000000-0000-4000-8000-0000000000f1'), 1::bigint, 'Carlos ve a meta da familia');
insert into tap_out(line) select is((select count(*) from public.goals where id = 'aa000000-0000-4000-8000-0000000000f2'), 0::bigint, 'Carlos nao ve a meta pessoal de Ana');
insert into tap_out(line) select is((select count(*) from public.goals where id = 'aa000000-0000-4000-8000-0000000000f3'), 1::bigint, 'Carlos ve a propria meta pessoal');
reset role; reset request.jwt.claim.sub;

set local role authenticated; set local request.jwt.claim.sub = 'aa000000-0000-4000-8000-0000000000a1';
insert into tap_out(line) select is((select count(*) from public.goals where id = 'aa000000-0000-4000-8000-0000000000f1'), 1::bigint, 'Ana ve a meta da familia');
insert into tap_out(line) select is((select count(*) from public.goals where id = 'aa000000-0000-4000-8000-0000000000f2'), 1::bigint, 'Ana ve a propria meta pessoal');
insert into tap_out(line) select is((select count(*) from public.goals where id = 'aa000000-0000-4000-8000-0000000000f3'), 0::bigint, 'Ana nao ve a meta pessoal de Carlos');
reset role; reset request.jwt.claim.sub;

set local role authenticated; set local request.jwt.claim.sub = 'aa000000-0000-4000-8000-0000000000b2';
insert into tap_out(line) select throws_ok($$ insert into public.goals (family_id, member_id, criado_por, titulo, valor_alvo) values ('aa000000-0000-4000-8000-000000000001', null, 'aa000000-0000-4000-8000-0000000000a1', 'Meta com criador errado', 100) $$, '42501', null, 'Carlos nao cria meta com criador Ana');
insert into tap_out(line) select lives_ok($$ insert into public.goals (id, family_id, member_id, criado_por, titulo, valor_alvo) values ('aa000000-0000-4000-8000-0000000000f7', 'aa000000-0000-4000-8000-000000000001', null, 'aa000000-0000-4000-8000-0000000000b2', 'Meta Carlos familia', 100) $$, 'Carlos cria meta familiar com o proprio criador');
delete from public.goals where id = 'aa000000-0000-4000-8000-0000000000f5';
reset role; reset request.jwt.claim.sub;
insert into tap_out(line) select is((select count(*) from public.goals where id = 'aa000000-0000-4000-8000-0000000000f5'), 1::bigint, 'Carlos nao apaga meta familiar de Ana');

set local role authenticated; set local request.jwt.claim.sub = 'aa000000-0000-4000-8000-0000000000a1';
delete from public.goals where id = 'aa000000-0000-4000-8000-0000000000f5';
reset role; reset request.jwt.claim.sub;
insert into tap_out(line) select is((select count(*) from public.goals where id = 'aa000000-0000-4000-8000-0000000000f5'), 0::bigint, 'Ana apaga a propria meta familiar');
insert into tap_out(line) select is((select count(*) from public.goal_contributions where goal_id = 'aa000000-0000-4000-8000-0000000000f5'), 0::bigint, 'apagar a meta remove as contribuicoes em cascade');

set local role authenticated; set local request.jwt.claim.sub = 'aa000000-0000-4000-8000-0000000000b2';
delete from public.goals where id = 'aa000000-0000-4000-8000-0000000000f3';
reset role; reset request.jwt.claim.sub;
insert into tap_out(line) select is((select count(*) from public.goals where id = 'aa000000-0000-4000-8000-0000000000f3'), 0::bigint, 'Carlos apaga a propria meta pessoal');
insert into tap_out(line) select is((select count(*) from public.goal_contributions where goal_id = 'aa000000-0000-4000-8000-0000000000f3'), 0::bigint, 'meta pessoal apagada remove contribuicoes');

set local role authenticated; set local request.jwt.claim.sub = 'aa000000-0000-4000-8000-0000000000a1';
update public.goals set status = 'cancelada' where id = 'aa000000-0000-4000-8000-0000000000f6';
reset role; reset request.jwt.claim.sub;
insert into tap_out(line) select is((select status from public.goals where id = 'aa000000-0000-4000-8000-0000000000f6'), 'cancelada', 'meta familiar pode ser cancelada');
insert into tap_out(line) select is((select count(*) from public.goal_contributions where goal_id = 'aa000000-0000-4000-8000-0000000000f6'), 1::bigint, 'cancelar a meta preserva as contribuicoes');

set local role authenticated; set local request.jwt.claim.sub = 'aa000000-0000-4000-8000-0000000000b2';
insert into tap_out(line) select lives_ok($$ insert into public.goal_contributions (id, goal_id, member_id, valor) values ('aa000000-0000-4000-8000-0000000000e7', 'aa000000-0000-4000-8000-0000000000f1', 'aa000000-0000-4000-8000-0000000000b2', 100) $$, 'Carlos contribui na meta da familia');
insert into tap_out(line) select throws_ok($$ insert into public.goal_contributions (goal_id, member_id, valor) values ('aa000000-0000-4000-8000-0000000000f1', 'aa000000-0000-4000-8000-0000000000a1', 100) $$, '42501', null, 'Carlos nao contribui como Ana');
insert into tap_out(line) select throws_ok($$ insert into public.goal_contributions (goal_id, member_id, valor) values ('aa000000-0000-4000-8000-0000000000f2', 'aa000000-0000-4000-8000-0000000000b2', 100) $$, '42501', null, 'Carlos nao contribui em meta pessoal de Ana');
insert into tap_out(line) select throws_ok($$ insert into public.goal_contributions (goal_id, member_id, valor) values ('aa000000-0000-4000-8000-0000000000f4', 'aa000000-0000-4000-8000-0000000000b2', 100) $$, '42501', null, 'contribuicao em meta concluida e recusada');
insert into tap_out(line) select is((select count(*) from public.goal_contributions where id = 'aa000000-0000-4000-8000-0000000000e1'), 1::bigint, 'Carlos ve contribuicoes da meta familiar');
insert into tap_out(line) select is((select count(*) from public.goal_contributions where id = 'aa000000-0000-4000-8000-0000000000e2'), 0::bigint, 'Carlos nao ve contribuicoes da meta pessoal de Ana');
reset role; reset request.jwt.claim.sub;
insert into tap_out(line) select is((select status from public.goals where id = 'aa000000-0000-4000-8000-0000000000f4'), 'concluida', 'contribuicao que atinge o alvo conclui a meta');

set local role authenticated; set local request.jwt.claim.sub = 'aa000000-0000-4000-8000-0000000000b2';
insert into tap_out(line) select is((select count(*) from public.ai_messages where id = 'aa000000-0000-4000-8000-0000000000d1'), 1::bigint, 'Carlos ve mensagem da familia');
insert into tap_out(line) select is((select count(*) from public.ai_messages where id = 'aa000000-0000-4000-8000-0000000000d2'), 0::bigint, 'Carlos nao ve mensagem pessoal de Ana');
insert into tap_out(line) select throws_ok($$ insert into public.ai_messages (family_id, member_id, role, content) values ('aa000000-0000-4000-8000-000000000001', 'aa000000-0000-4000-8000-0000000000a1', 'assistant', 'Como Ana') $$, '42501', null, 'Carlos nao insere mensagem como Ana');
insert into tap_out(line) select is((select count(*) from public.ai_suggestions where id = 'aa000000-0000-4000-8000-0000000000c1'), 1::bigint, 'Carlos ve sugestao da familia');
insert into tap_out(line) select is((select count(*) from public.ai_suggestions where id = 'aa000000-0000-4000-8000-0000000000c2'), 0::bigint, 'Carlos nao ve sugestao pessoal de Ana');
update public.ai_suggestions set lida = true where id = 'aa000000-0000-4000-8000-0000000000c1';
update public.ai_suggestions set lida = true where id = 'aa000000-0000-4000-8000-0000000000c2';
insert into tap_out(line) select throws_ok($$ update public.ai_suggestions set o_que = 'Outro' where id = 'aa000000-0000-4000-8000-0000000000c1' $$, '42501', null, 'conteudo da sugestao e imutavel');
insert into tap_out(line) select throws_ok($$ update public.goal_contributions set valor = 200 where id = 'aa000000-0000-4000-8000-0000000000e1' $$, '42501', null, 'contribuicao nao tem update');
insert into tap_out(line) select throws_ok($$ delete from public.ai_messages where id = 'aa000000-0000-4000-8000-0000000000d1' $$, '42501', null, 'mensagem nao tem delete');
reset role; reset request.jwt.claim.sub;

insert into tap_out(line) select is((select lida from public.ai_suggestions where id = 'aa000000-0000-4000-8000-0000000000c1'), true, 'sugestao da familia pode ser lida por Carlos');
insert into tap_out(line) select is((select lida from public.ai_suggestions where id = 'aa000000-0000-4000-8000-0000000000c2'), false, 'sugestao pessoal de Ana nao e lida por Carlos');

insert into tap_out(line) select is(has_table_privilege('authenticated', 'public.goal_contributions', 'UPDATE'), false, 'goal_contributions sem grant de update');
insert into tap_out(line) select is(has_table_privilege('authenticated', 'public.ai_messages', 'DELETE'), false, 'ai_messages sem grant de delete');
insert into tap_out(line) select is(has_table_privilege('authenticated', 'public.ai_suggestions', 'DELETE'), false, 'ai_suggestions sem grant de delete');
insert into tap_out(line) select is(has_column_privilege('authenticated', 'public.ai_suggestions', 'lida', 'UPDATE'), true, 'ai_suggestions.lida e updateable');
insert into tap_out(line) select is(has_column_privilege('authenticated', 'public.ai_suggestions', 'o_que', 'UPDATE'), false, 'ai_suggestions.o_que nao e updateable');
insert into tap_out(line) select is((select count(*) from pg_policies where schemaname = 'public' and tablename in ('goal_contributions', 'ai_messages') and cmd in ('UPDATE', 'DELETE')), 0::bigint, 'contribuicoes e mensagens sem policy de update/delete');
insert into tap_out(line) select is((select count(*) from pg_policies where schemaname = 'public' and tablename = 'ai_suggestions' and cmd = 'DELETE'), 0::bigint, 'sugestoes sem policy de delete');

insert into tap_out(line) select * from finish();

select string_agg(line, E'\n' order by seq) as tap from tap_out;
rollback;
