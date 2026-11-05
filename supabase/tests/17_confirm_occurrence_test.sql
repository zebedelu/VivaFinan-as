begin;
set local search_path = public, extensions;

create temp table tap_out(seq serial, line text);
grant all on tap_out to public;
grant all on sequence tap_out_seq_seq to public;

insert into auth.users (id, email) values
  ('ad000000-0000-4000-8000-0000000000a1', 'ana.ad000000@test.local'),
  ('ad000000-0000-4000-8000-0000000000b2', 'carlos.ad000000@test.local'),
  ('ad000000-0000-4000-8000-0000000000c3', 'lucas.ad000000@test.local'),
  ('ad000000-0000-4000-8000-0000000000d4', 'externo.ad000000@test.local');

insert into public.families (id, nome, criado_por) values
  ('ad000000-0000-4000-8000-000000000001', 'Familia Teste A 17', 'ad000000-0000-4000-8000-0000000000a1'),
  ('ad000000-0000-4000-8000-000000000002', 'Familia Teste B 17', 'ad000000-0000-4000-8000-0000000000d4');

insert into public.profiles (id, family_id, nome, papel, status) values
  ('ad000000-0000-4000-8000-0000000000a1', 'ad000000-0000-4000-8000-000000000001', 'Ana', 'admin', 'ativo'),
  ('ad000000-0000-4000-8000-0000000000b2', 'ad000000-0000-4000-8000-000000000001', 'Carlos', 'membro', 'ativo'),
  ('ad000000-0000-4000-8000-0000000000c3', 'ad000000-0000-4000-8000-000000000001', 'Lucas', 'membro', 'ativo'),
  ('ad000000-0000-4000-8000-0000000000d4', 'ad000000-0000-4000-8000-000000000002', 'Externo', 'admin', 'ativo');

insert into public.recurring_rules (id, family_id, criado_por, tipo, escopo, valor, descricao, category_id, dia_vencimento, ativo) values
  ('ad000000-0000-4000-8000-000000000101', 'ad000000-0000-4000-8000-000000000001', 'ad000000-0000-4000-8000-0000000000a1', 'despesa', 'familia', 100, 'Aluguel', (select id from public.categories where family_id = 'ad000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação'), 31, true),
  ('ad000000-0000-4000-8000-000000000102', 'ad000000-0000-4000-8000-000000000001', 'ad000000-0000-4000-8000-0000000000b2', 'receita', 'pessoal', 2000, 'Freelance', (select id from public.categories where family_id = 'ad000000-0000-4000-8000-000000000001' and tipo = 'receita' and nome = 'Salário'), 15, true),
  ('ad000000-0000-4000-8000-000000000103', 'ad000000-0000-4000-8000-000000000001', 'ad000000-0000-4000-8000-0000000000a1', 'despesa', 'familia', 300, 'Inativa', (select id from public.categories where family_id = 'ad000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Outros'), 10, false),
  ('ad000000-0000-4000-8000-000000000104', 'ad000000-0000-4000-8000-000000000002', 'ad000000-0000-4000-8000-0000000000d4', 'despesa', 'familia', 400, 'Familia B', (select id from public.categories where family_id = 'ad000000-0000-4000-8000-000000000002' and tipo = 'despesa' and nome = 'Alimentação'), 20, true),
  ('ad000000-0000-4000-8000-000000000105', 'ad000000-0000-4000-8000-000000000001', 'ad000000-0000-4000-8000-0000000000a1', 'despesa', 'familia', 500, 'Corrida', (select id from public.categories where family_id = 'ad000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Transporte'), 5, true),
  ('ad000000-0000-4000-8000-000000000106', 'ad000000-0000-4000-8000-000000000001', 'ad000000-0000-4000-8000-0000000000a1', 'despesa', 'familia', 600, 'Mes corrente', (select id from public.categories where family_id = 'ad000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Lazer'), 31, true);

insert into public.recurring_occurrences (id, rule_id, mes_referencia, status) values
  ('ad000000-0000-4000-8000-000000000201', 'ad000000-0000-4000-8000-000000000101', '2026-02-01', 'pendente'),
  ('ad000000-0000-4000-8000-000000000202', 'ad000000-0000-4000-8000-000000000102', '2026-04-01', 'pendente'),
  ('ad000000-0000-4000-8000-000000000203', 'ad000000-0000-4000-8000-000000000103', '2026-06-01', 'pendente'),
  ('ad000000-0000-4000-8000-000000000204', 'ad000000-0000-4000-8000-000000000104', '2026-06-01', 'pendente'),
  ('ad000000-0000-4000-8000-000000000205', 'ad000000-0000-4000-8000-000000000105', '2026-05-01', 'pendente'),
  ('ad000000-0000-4000-8000-000000000206', 'ad000000-0000-4000-8000-000000000101', '2026-03-01', 'pendente'),
  ('ad000000-0000-4000-8000-000000000207', 'ad000000-0000-4000-8000-000000000101', '2026-04-01', 'pendente'),
  ('ad000000-0000-4000-8000-000000000208', 'ad000000-0000-4000-8000-000000000106', date_trunc('month', (now() at time zone 'America/Sao_Paulo')::date)::date, 'pendente');

-- Corrida simulada: o mes de R5 ja tem lancamento antes da confirmacao.
insert into public.transactions (id, family_id, member_id, tipo, escopo, valor, descricao, category_id, data, criado_por, recurring_rule_id, mes_referencia) values
  ('ad000000-0000-4000-8000-000000000401', 'ad000000-0000-4000-8000-000000000001', 'ad000000-0000-4000-8000-0000000000a1', 'despesa', 'familia', 500, 'Corrida', (select id from public.categories where family_id = 'ad000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Transporte'), '2026-05-05', 'ad000000-0000-4000-8000-0000000000a1', 'ad000000-0000-4000-8000-000000000105', '2026-05-01');

insert into tap_out(line) select plan(32);

-- confirmacao simples com clamp no ultimo dia
set local role authenticated;
set local request.jwt.claim.sub = 'ad000000-0000-4000-8000-0000000000a1';
insert into tap_out(line) select ok((select public.confirm_occurrence('ad000000-0000-4000-8000-000000000201')) is not null, 'confirma ocorrencia pendente');
insert into tap_out(line) select is((select count(*) from public.transactions where recurring_rule_id = 'ad000000-0000-4000-8000-000000000101' and mes_referencia = '2026-02-01'), 1::bigint, 'confirmacao cria um lancamento');
insert into tap_out(line) select is((select data from public.transactions where recurring_rule_id = 'ad000000-0000-4000-8000-000000000101' and mes_referencia = '2026-02-01'), '2026-02-28'::date, 'data usa o vencimento com clamp');
insert into tap_out(line) select is((select valor from public.transactions where recurring_rule_id = 'ad000000-0000-4000-8000-000000000101' and mes_referencia = '2026-02-01'), 100::numeric, 'valor padrao vem da regra');
insert into tap_out(line) select is((select tipo || '|' || escopo || '|' || descricao || '|' || member_id::text || '|' || criado_por::text || '|' || origem from public.transactions where recurring_rule_id = 'ad000000-0000-4000-8000-000000000101' and mes_referencia = '2026-02-01'), 'despesa|familia|Aluguel|ad000000-0000-4000-8000-0000000000a1|ad000000-0000-4000-8000-0000000000a1|manual', 'lancamento herda tipo, escopo, descricao e autoria');
insert into tap_out(line) select is((select category_id from public.transactions where recurring_rule_id = 'ad000000-0000-4000-8000-000000000101' and mes_referencia = '2026-02-01'), (select category_id from public.recurring_rules where id = 'ad000000-0000-4000-8000-000000000101'), 'lancamento herda a categoria da regra');
insert into tap_out(line) select is((select status || '|' || valor_confirmado::text || '|' || confirmado_por::text || '|' || (confirmado_em is not null)::text from public.recurring_occurrences where id = 'ad000000-0000-4000-8000-000000000201'), 'confirmado|100.00|ad000000-0000-4000-8000-0000000000a1|true', 'ocorrencia fica confirmada com autor e data');
insert into tap_out(line) select throws_ok($$ select public.confirm_occurrence('ad000000-0000-4000-8000-000000000201') $$, '42501', null, 'duplicata de confirmacao e recusada');
insert into tap_out(line) select is((select count(*) from public.transactions where recurring_rule_id = 'ad000000-0000-4000-8000-000000000101' and mes_referencia = '2026-02-01'), 1::bigint, 'duplicata nao cria segundo lancamento');
reset role;
reset request.jwt.claim.sub;

-- override de valor e escopo pessoal
set local role authenticated;
set local request.jwt.claim.sub = 'ad000000-0000-4000-8000-0000000000b2';
insert into tap_out(line) select ok((select public.confirm_occurrence('ad000000-0000-4000-8000-000000000202', 2500)) is not null, 'confirma ocorrencia pessoal com override');
insert into tap_out(line) select is((select data from public.transactions where recurring_rule_id = 'ad000000-0000-4000-8000-000000000102' and mes_referencia = '2026-04-01'), '2026-04-15'::date, 'data pessoal usa o dia de vencimento');
insert into tap_out(line) select is((select valor::text || '|' || member_id::text || '|' || escopo from public.transactions where recurring_rule_id = 'ad000000-0000-4000-8000-000000000102' and mes_referencia = '2026-04-01'), '2500.00|ad000000-0000-4000-8000-0000000000b2|pessoal', 'override define valor e o membro confirma como dono');
insert into tap_out(line) select is((select status || '|' || valor_confirmado::text || '|' || confirmado_por::text from public.recurring_occurrences where id = 'ad000000-0000-4000-8000-000000000202'), 'confirmado|2500.00|ad000000-0000-4000-8000-0000000000b2', 'ocorrencia pessoal guarda o valor override');
reset role;
reset request.jwt.claim.sub;

-- RLS e regras invalidas
set local role authenticated;
set local request.jwt.claim.sub = 'ad000000-0000-4000-8000-0000000000a1';
insert into tap_out(line) select throws_ok($$ select public.confirm_occurrence('ad000000-0000-4000-8000-000000000202') $$, '42501', null, 'outro membro nao confirma ocorrencia pessoal');
insert into tap_out(line) select throws_ok($$ select public.confirm_occurrence('ad000000-0000-4000-8000-000000000203') $$, '42501', null, 'regra inativa e recusada');
insert into tap_out(line) select throws_ok($$ select public.confirm_occurrence('ad000000-0000-4000-8000-000000000204') $$, '42501', null, 'ocorrencia de outra familia e recusada');
insert into tap_out(line) select throws_ok($$ select public.confirm_occurrence('ad000000-0000-4000-8000-000000000207', 0) $$, '22023', null, 'valor zero e recusado');
insert into tap_out(line) select is((select count(*) from public.transactions where recurring_rule_id = 'ad000000-0000-4000-8000-000000000101' and mes_referencia = '2026-04-01'), 0::bigint, 'valor invalido nao cria lancamento');
reset role;
reset request.jwt.claim.sub;

-- corrida: unique de (regra, mes) desfaz o insert e deixa a ocorrencia pendente
set local role authenticated;
set local request.jwt.claim.sub = 'ad000000-0000-4000-8000-0000000000a1';
insert into tap_out(line) select throws_ok($$ select public.confirm_occurrence('ad000000-0000-4000-8000-000000000205') $$, '23505', null, 'corrida com lancamento existente e recusada');
insert into tap_out(line) select is((select status from public.recurring_occurrences where id = 'ad000000-0000-4000-8000-000000000205'), 'pendente', 'corrida nao marca a ocorrencia');
insert into tap_out(line) select is((select count(*) from public.transactions where recurring_rule_id = 'ad000000-0000-4000-8000-000000000105' and mes_referencia = '2026-05-01'), 1::bigint, 'corrida nao duplica o lancamento existente');
reset role;
reset request.jwt.claim.sub;

set local role authenticated;
set local request.jwt.claim.sub = 'ad000000-0000-4000-8000-0000000000b2';
insert into tap_out(line) select throws_ok($$ select public.confirm_occurrence('ad000000-0000-4000-8000-000000000201') $$, '42501', null, 'confirmacao repetida por outro membro e recusada');
reset role;
reset request.jwt.claim.sub;

-- membro comum confirma regra familiar
set local role authenticated;
set local request.jwt.claim.sub = 'ad000000-0000-4000-8000-0000000000c3';
insert into tap_out(line) select ok((select public.confirm_occurrence('ad000000-0000-4000-8000-000000000206')) is not null, 'membro comum confirma regra familiar');
insert into tap_out(line) select is((select data::text || '|' || member_id::text from public.transactions where recurring_rule_id = 'ad000000-0000-4000-8000-000000000101' and mes_referencia = '2026-03-01'), '2026-03-31|ad000000-0000-4000-8000-0000000000c3', 'lancamento familiar usa o membro que confirmou');
reset role;
reset request.jwt.claim.sub;

-- mes corrente nao posta lancamento futuro
set local role authenticated;
set local request.jwt.claim.sub = 'ad000000-0000-4000-8000-0000000000a1';
insert into tap_out(line) select ok((select public.confirm_occurrence('ad000000-0000-4000-8000-000000000208')) is not null, 'confirma ocorrencia do mes corrente');
insert into tap_out(line) select is((select data from public.transactions where recurring_rule_id = 'ad000000-0000-4000-8000-000000000106' and mes_referencia = date_trunc('month', (now() at time zone 'America/Sao_Paulo')::date)::date), (now() at time zone 'America/Sao_Paulo')::date, 'lancamento do mes corrente nao fica no futuro');
reset role;
reset request.jwt.claim.sub;

-- hardening
set local role anon;
insert into tap_out(line) select throws_ok($$ select public.confirm_occurrence('ad000000-0000-4000-8000-000000000207') $$, '42501', null, 'anon nao executa confirm_occurrence');
reset role;
insert into tap_out(line) select is(has_function_privilege('authenticated', 'public.confirm_occurrence(uuid,numeric)', 'EXECUTE'), true, 'authenticated executa confirm_occurrence');
insert into tap_out(line) select is((select prosecdef from pg_proc where oid = 'public.confirm_occurrence(uuid,numeric)'::regprocedure), false, 'confirm_occurrence e security invoker');
insert into tap_out(line) select is((select proconfig @> array['search_path='] or proconfig @> array['search_path=""'] from pg_proc where oid = 'public.confirm_occurrence(uuid,numeric)'::regprocedure), true, 'confirm_occurrence usa search_path vazio');
insert into tap_out(line) select throws_ok($$ select public.confirm_occurrence('ad000000-0000-4000-8000-000000000207') $$, '42501', null, 'sem autenticacao e recusado');
insert into tap_out(line) select throws_ok($$ select public.confirm_occurrence('ad000000-0000-4000-8000-000000000299') $$, '42501', null, 'ocorrencia inexistente e recusada');

insert into tap_out(line) select * from finish();

select string_agg(line, E'\n' order by seq) as tap from tap_out;
rollback;
