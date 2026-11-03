begin;
set local search_path = public, extensions;

create temp table tap_out(seq serial, line text);
grant all on tap_out to public;
grant all on sequence tap_out_seq_seq to public;

insert into auth.users (id, email) values
  ('33000000-0000-4000-8000-0000000000a1', 'ana.33000000@test.local'),
  ('33000000-0000-4000-8000-0000000000b2', 'carlos.33000000@test.local'),
  ('33000000-0000-4000-8000-0000000000c3', 'lucas.33000000@test.local'),
  ('33000000-0000-4000-8000-0000000000d4', 'externo.33000000@test.local');

insert into public.families (id, nome, criado_por) values
  ('33000000-0000-4000-8000-000000000001', 'Familia Teste A 03', '33000000-0000-4000-8000-0000000000a1'),
  ('33000000-0000-4000-8000-000000000002', 'Familia Teste B 03', '33000000-0000-4000-8000-0000000000d4');

insert into public.profiles (id, family_id, nome, papel, status) values
  ('33000000-0000-4000-8000-0000000000a1', '33000000-0000-4000-8000-000000000001', 'Ana', 'admin', 'ativo'),
  ('33000000-0000-4000-8000-0000000000b2', '33000000-0000-4000-8000-000000000001', 'Carlos', 'membro', 'ativo'),
  ('33000000-0000-4000-8000-0000000000c3', '33000000-0000-4000-8000-000000000001', 'Lucas', 'membro', 'ativo'),
  ('33000000-0000-4000-8000-0000000000d4', '33000000-0000-4000-8000-000000000002', 'Externo', 'admin', 'ativo');

insert into tap_out(line) select plan(21);

insert into tap_out(line) select has_table('public', 'goals', 'tabela goals existe');
insert into tap_out(line) select has_table('public', 'goal_contributions', 'tabela goal_contributions existe');
insert into tap_out(line) select has_table('public', 'ai_messages', 'tabela ai_messages existe');
insert into tap_out(line) select has_table('public', 'ai_suggestions', 'tabela ai_suggestions existe');

insert into tap_out(line) select lives_ok($$
  insert into public.goals (id, family_id, member_id, criado_por, titulo, valor_alvo)
  values ('33000000-0000-4000-8000-0000000000f1', '33000000-0000-4000-8000-000000000001', null, '33000000-0000-4000-8000-0000000000a1', 'Meta Familia 03', 1000)
  $$, 'meta familiar aceita member_id nulo');

insert into tap_out(line) select lives_ok($$
  insert into public.goals (id, family_id, member_id, criado_por, titulo, valor_alvo)
  values ('33000000-0000-4000-8000-0000000000f2', '33000000-0000-4000-8000-000000000001', '33000000-0000-4000-8000-0000000000a1', '33000000-0000-4000-8000-0000000000a1', 'Meta Pessoal 03', 500)
  $$, 'meta pessoal aceita member_id');

insert into tap_out(line) select throws_ok($$
  insert into public.goals (family_id, member_id, criado_por, titulo, valor_alvo)
  values ('33000000-0000-4000-8000-000000000001', null, null, 'Sem criador 03', 100)
  $$, '23502', null, 'criado_por e obrigatorio');

insert into tap_out(line) select throws_ok($$
  insert into public.goals (family_id, member_id, criado_por, titulo, valor_alvo)
  values ('33000000-0000-4000-8000-000000000001', null, '33000000-0000-4000-8000-0000000000d4', 'Criador de outra familia 03', 100)
  $$, '23503', null, 'criador de outra familia e recusado');

insert into tap_out(line) select throws_ok($$
  insert into public.goals (family_id, member_id, criado_por, titulo, valor_alvo)
  values ('33000000-0000-4000-8000-000000000001', null, '33000000-0000-4000-8000-0000000000a1', 'Alvo zero 03', 0)
  $$, '23514', null, 'valor_alvo zero e recusado');

insert into tap_out(line) select throws_ok($$
  insert into public.goals (family_id, member_id, criado_por, titulo, valor_alvo, status)
  values ('33000000-0000-4000-8000-000000000001', null, '33000000-0000-4000-8000-0000000000a1', 'Status invalido 03', 100, 'pausada')
  $$, '23514', null, 'status invalido e recusado');

insert into tap_out(line) select throws_ok($$
  insert into public.goal_contributions (goal_id, member_id, valor)
  values ('33000000-0000-4000-8000-0000000000f1', '33000000-0000-4000-8000-0000000000a1', 0)
  $$, '23514', null, 'contribuicao zero e recusada');

insert into tap_out(line) select throws_ok($$
  insert into public.ai_messages (family_id, member_id, role, content)
  values ('33000000-0000-4000-8000-000000000001', null, 'assistant', '')
  $$, '23514', null, 'mensagem vazia e recusada');

insert into tap_out(line) select throws_ok($$
  insert into public.ai_suggestions (family_id, member_id, tipo, titulo, o_que, por_que, quanto)
  values ('33000000-0000-4000-8000-000000000001', null, 'dica', '', 'O que', 'Por que', 'Quanto')
  $$, '23514', null, 'sugestao com titulo vazio e recusada');

insert into tap_out(line) select throws_ok($$
  insert into public.ai_suggestions (family_id, member_id, tipo, titulo, o_que, por_que, quanto)
  values ('33000000-0000-4000-8000-000000000001', null, 'dica', 'Titulo', '', 'Por que', 'Quanto')
  $$, '23514', null, 'sugestao com o_que vazio e recusada');

insert into tap_out(line) select throws_ok($$
  insert into public.ai_suggestions (family_id, member_id, tipo, titulo, o_que, por_que, quanto)
  values ('33000000-0000-4000-8000-000000000001', null, 'dica', 'Titulo', 'O que', '', 'Quanto')
  $$, '23514', null, 'sugestao com por_que vazio e recusada');

insert into tap_out(line) select throws_ok($$
  insert into public.ai_suggestions (family_id, member_id, tipo, titulo, o_que, por_que, quanto)
  values ('33000000-0000-4000-8000-000000000001', null, 'dica', 'Titulo', 'O que', 'Por que', '')
  $$, '23514', null, 'sugestao com quanto vazio e recusada');

insert into tap_out(line) select throws_ok($$
  insert into public.ai_suggestions (family_id, member_id, tipo, titulo, o_que, por_que, quanto)
  values ('33000000-0000-4000-8000-000000000001', null, 'dica', null, 'O que', 'Por que', 'Quanto')
  $$, '23502', null, 'sugestao com titulo nulo e recusada');

insert into tap_out(line) select throws_ok($$
  insert into public.ai_suggestions (family_id, member_id, tipo, titulo, o_que, por_que, quanto)
  values ('33000000-0000-4000-8000-000000000001', null, 'dica', 'Titulo', null, 'Por que', 'Quanto')
  $$, '23502', null, 'sugestao com o_que nulo e recusada');

insert into tap_out(line) select throws_ok($$
  insert into public.ai_suggestions (family_id, member_id, tipo, titulo, o_que, por_que, quanto)
  values ('33000000-0000-4000-8000-000000000001', null, 'dica', 'Titulo', 'O que', null, 'Quanto')
  $$, '23502', null, 'sugestao com por_que nulo e recusada');

insert into tap_out(line) select throws_ok($$
  insert into public.ai_suggestions (family_id, member_id, tipo, titulo, o_que, por_que, quanto)
  values ('33000000-0000-4000-8000-000000000001', null, 'dica', 'Titulo', 'O que', 'Por que', null)
  $$, '23502', null, 'sugestao com quanto nulo e recusada');

insert into tap_out(line) select throws_ok($$
  insert into public.goals (family_id, member_id, criado_por, titulo, valor_alvo)
  values ('33000000-0000-4000-8000-000000000002', '33000000-0000-4000-8000-0000000000b2', '33000000-0000-4000-8000-0000000000d4', 'Meta cruzada 03', 100)
  $$, '23503', null, 'member_id de outra familia e recusado');

insert into tap_out(line) select * from finish();

select string_agg(line, E'\n' order by seq) as tap from tap_out;
rollback;
