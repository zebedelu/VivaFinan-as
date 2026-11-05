begin;
set local search_path = public, extensions;

create temp table tap_out(seq serial, line text);
grant all on tap_out to public;
grant all on sequence tap_out_seq_seq to public;

insert into auth.users (id, email) values
  ('ae000000-0000-4000-8000-0000000000a1', 'ana.ae000000@test.local'),
  ('ae000000-0000-4000-8000-0000000000b2', 'carlos.ae000000@test.local'),
  ('ae000000-0000-4000-8000-0000000000d4', 'externo.ae000000@test.local');

insert into public.families (id, nome, criado_por) values
  ('ae000000-0000-4000-8000-000000000001', 'Familia Teste A 18', 'ae000000-0000-4000-8000-0000000000a1'),
  ('ae000000-0000-4000-8000-000000000002', 'Familia Teste B 18', 'ae000000-0000-4000-8000-0000000000d4');

insert into public.profiles (id, family_id, nome, papel, status) values
  ('ae000000-0000-4000-8000-0000000000a1', 'ae000000-0000-4000-8000-000000000001', 'Ana', 'admin', 'ativo'),
  ('ae000000-0000-4000-8000-0000000000b2', 'ae000000-0000-4000-8000-000000000001', 'Carlos', 'membro', 'ativo'),
  ('ae000000-0000-4000-8000-0000000000d4', 'ae000000-0000-4000-8000-000000000002', 'Externo', 'admin', 'ativo');

insert into public.ai_suggestions (id, family_id, member_id, tipo, titulo, o_que, por_que, quanto) values
  ('ae000000-0000-4000-8000-0000000000c1', 'ae000000-0000-4000-8000-000000000001', null, 'economia', 'Titulo A', 'O que A', 'Por que A', 'Quanto A'),
  ('ae000000-0000-4000-8000-0000000000c2', 'ae000000-0000-4000-8000-000000000001', null, 'meta', 'Titulo B', 'O que B', 'Por que B', 'Quanto B'),
  ('ae000000-0000-4000-8000-0000000000c3', 'ae000000-0000-4000-8000-000000000001', 'ae000000-0000-4000-8000-0000000000a1', 'categoria', 'Titulo A', 'O que A', 'Por que A', 'Quanto A'),
  ('ae000000-0000-4000-8000-0000000000c4', 'ae000000-0000-4000-8000-000000000001', 'ae000000-0000-4000-8000-0000000000a1', 'categoria', 'Titulo C', 'O que C', 'Por que C', 'Quanto C'),
  ('ae000000-0000-4000-8000-0000000000c5', 'ae000000-0000-4000-8000-000000000002', null, 'economia', 'Titulo A', 'O que A', 'Por que A', 'Quanto A');

insert into tap_out(line) select plan(14);

insert into tap_out(line) select is((select count(*) from public.ai_suggestions where family_id = 'ae000000-0000-4000-8000-000000000001'), 4::bigint, 'quatro sugestoes distintas na familia A');

insert into tap_out(line) select throws_ok($$
  insert into public.ai_suggestions (family_id, member_id, tipo, titulo, o_que, por_que, quanto)
  values ('ae000000-0000-4000-8000-000000000001', null, 'economia', 'Titulo A', 'O que A', 'Outro por que', 'Outro quanto')
$$, '23505', null, 'duplicata de familia/membro/titulo/o_que e recusada');

insert into tap_out(line) select lives_ok($$
  insert into public.ai_suggestions (family_id, member_id, tipo, titulo, o_que, por_que, quanto)
  values ('ae000000-0000-4000-8000-000000000001', 'ae000000-0000-4000-8000-0000000000b2', 'categoria', 'Titulo A', 'O que A', 'Por que B2', 'Quanto B2')
$$, 'mesmo titulo e o_que com outro membro passa');

insert into tap_out(line) select lives_ok($$
  insert into public.ai_suggestions (family_id, member_id, tipo, titulo, o_que, por_que, quanto)
  values ('ae000000-0000-4000-8000-000000000001', null, 'economia', 'Titulo A', 'Outro o que', 'Por que A', 'Quanto A')
$$, 'mesmo titulo com outro o_que passa');

insert into tap_out(line) select throws_ok($$
  insert into public.ai_suggestions (family_id, member_id, tipo, titulo, o_que, por_que, quanto)
  values ('ae000000-0000-4000-8000-000000000002', null, 'economia', 'Titulo A', 'O que A', 'Por que A', 'Quanto A')
$$, '23505', null, 'duplicata na familia B e recusada');

insert into tap_out(line) select is((select count(*) from public.ai_suggestions where family_id = 'ae000000-0000-4000-8000-000000000001'), 6::bigint, 'sugestoes distintas continuam passando');
insert into tap_out(line) select is((select count(*) from public.ai_suggestions where family_id = 'ae000000-0000-4000-8000-000000000002'), 1::bigint, 'familia B mantem uma sugestao');
insert into tap_out(line) select is((select count(*) from public.ai_suggestions where family_id = 'ae000000-0000-4000-8000-000000000001' and member_id is null), 3::bigint, 'membro nulo usa coalesce na chave');
insert into tap_out(line) select is((select count(*) from public.ai_suggestions where family_id = 'eeeeeeee-0000-4000-8000-000000000001'), 4::bigint, 'seed demo mantem as quatro sugestoes');

insert into tap_out(line) select is((select count(*) from pg_indexes where schemaname = 'public' and indexname = 'ai_suggestions_dedup_key'), 1::bigint, 'indice de dedup existe');
insert into tap_out(line) select is((select indisunique from pg_index where indexrelid = 'public.ai_suggestions_dedup_key'::regclass), true, 'indice de dedup e unico');
insert into tap_out(line) select is((select indexdef ilike '%COALESCE%' from pg_indexes where schemaname = 'public' and indexname = 'ai_suggestions_dedup_key'), true, 'indice usa coalesce em member_id');
insert into tap_out(line) select is((select indexdef ilike '%titulo%' and indexdef ilike '%o_que%' from pg_indexes where schemaname = 'public' and indexname = 'ai_suggestions_dedup_key'), true, 'indice cobre titulo e o_que');

insert into tap_out(line) select throws_ok($$
  insert into public.ai_suggestions (family_id, member_id, tipo, titulo, o_que, por_que, quanto)
  values ('ae000000-0000-4000-8000-000000000001', null, 'meta', 'Titulo B', 'O que B', 'Outro por que', 'Outro quanto')
$$, '23505', null, 'duplicata com member_id nulo e recusada');

insert into tap_out(line) select * from finish();

select string_agg(line, E'\n' order by seq) as tap from tap_out;
rollback;
