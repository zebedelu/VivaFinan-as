begin;
set local search_path = public, extensions;

create temp table tap_out(seq serial, line text);
grant all on tap_out to public;
grant all on sequence tap_out_seq_seq to public;

insert into auth.users (id, email) values
  ('22000000-0000-4000-8000-0000000000a1', 'ana.22000000@test.local'),
  ('22000000-0000-4000-8000-0000000000b2', 'carlos.22000000@test.local'),
  ('22000000-0000-4000-8000-0000000000c3', 'lucas.22000000@test.local'),
  ('22000000-0000-4000-8000-0000000000d4', 'externo.22000000@test.local');

insert into public.families (id, nome, criado_por) values
  ('22000000-0000-4000-8000-000000000001', 'Familia Teste A 02', '22000000-0000-4000-8000-0000000000a1'),
  ('22000000-0000-4000-8000-000000000002', 'Familia Teste B 02', '22000000-0000-4000-8000-0000000000d4');

insert into public.profiles (id, family_id, nome, papel, status) values
  ('22000000-0000-4000-8000-0000000000a1', '22000000-0000-4000-8000-000000000001', 'Ana', 'admin', 'ativo'),
  ('22000000-0000-4000-8000-0000000000b2', '22000000-0000-4000-8000-000000000001', 'Carlos', 'membro', 'ativo'),
  ('22000000-0000-4000-8000-0000000000c3', '22000000-0000-4000-8000-000000000001', 'Lucas', 'membro', 'ativo'),
  ('22000000-0000-4000-8000-0000000000d4', '22000000-0000-4000-8000-000000000002', 'Externo', 'admin', 'ativo');

insert into public.categories (id, family_id, nome, tipo, criado_por) values
  ('22000000-0000-4000-8000-0000000000c1', '22000000-0000-4000-8000-000000000001', 'Categoria Despesa 02', 'despesa', '22000000-0000-4000-8000-0000000000a1'),
  ('22000000-0000-4000-8000-0000000000c2', '22000000-0000-4000-8000-000000000001', 'Categoria Receita 02', 'receita', '22000000-0000-4000-8000-0000000000a1'),
  ('22000000-0000-4000-8000-0000000000c4', '22000000-0000-4000-8000-000000000002', 'Categoria B 02', 'despesa', '22000000-0000-4000-8000-0000000000d4');

insert into public.recurring_rules (id, family_id, criado_por, tipo, escopo, valor, descricao, category_id, dia_vencimento)
values (
  '22000000-0000-4000-8000-0000000000e1',
  '22000000-0000-4000-8000-000000000001',
  '22000000-0000-4000-8000-0000000000a1',
  'despesa', 'pessoal', 100.00, 'Regra Teste 02',
  '22000000-0000-4000-8000-0000000000c1', 10
);

insert into tap_out(line) select plan(14);

insert into tap_out(line) select has_table('public', 'transactions', 'tabela transactions existe');
insert into tap_out(line) select has_table('public', 'recurring_rules', 'tabela recurring_rules existe');
insert into tap_out(line) select has_table('public', 'recurring_occurrences', 'tabela recurring_occurrences existe');

insert into tap_out(line) select throws_ok($$
  insert into public.transactions (family_id, member_id, tipo, escopo, valor, category_id, data, criado_por)
  values ('22000000-0000-4000-8000-000000000001', '22000000-0000-4000-8000-0000000000a1', 'despesa', 'pessoal', 0, '22000000-0000-4000-8000-0000000000c1', '2026-11-10', '22000000-0000-4000-8000-0000000000a1')
  $$, '23514', null, 'valor zero e recusado');

insert into tap_out(line) select throws_ok($$
  insert into public.transactions (family_id, member_id, tipo, escopo, valor, category_id, data, criado_por)
  values ('22000000-0000-4000-8000-000000000001', '22000000-0000-4000-8000-0000000000a1', 'investimento', 'pessoal', 100, '22000000-0000-4000-8000-0000000000c1', '2026-11-10', '22000000-0000-4000-8000-0000000000a1')
  $$, '23514', null, 'tipo invalido e recusado');

insert into tap_out(line) select throws_ok($$
  insert into public.transactions (family_id, member_id, tipo, escopo, valor, category_id, data, criado_por)
  values ('22000000-0000-4000-8000-000000000001', '22000000-0000-4000-8000-0000000000a1', 'despesa', 'global', 100, '22000000-0000-4000-8000-0000000000c1', '2026-11-10', '22000000-0000-4000-8000-0000000000a1')
  $$, '23514', null, 'escopo invalido e recusado');

insert into tap_out(line) select throws_ok($$
  insert into public.transactions (family_id, member_id, tipo, escopo, valor, category_id, data, pago_por, criado_por)
  values ('22000000-0000-4000-8000-000000000001', '22000000-0000-4000-8000-0000000000a1', 'despesa', 'pessoal', 100, '22000000-0000-4000-8000-0000000000c1', '2026-11-10', '22000000-0000-4000-8000-0000000000b2', '22000000-0000-4000-8000-0000000000a1')
  $$, '23514', null, 'pago_por exigido so no escopo familia');

insert into tap_out(line) select throws_ok($$
  insert into public.transactions (family_id, member_id, tipo, escopo, valor, category_id, data, criado_por, recurring_rule_id, mes_referencia)
  values ('22000000-0000-4000-8000-000000000001', '22000000-0000-4000-8000-0000000000a1', 'despesa', 'pessoal', 100, '22000000-0000-4000-8000-0000000000c1', '2026-11-10', '22000000-0000-4000-8000-0000000000a1', '22000000-0000-4000-8000-0000000000e1', '2026-11-15')
  $$, '23514', null, 'mes_referencia precisa ser o primeiro dia');

insert into tap_out(line) select throws_ok($$
  insert into public.transactions (family_id, member_id, tipo, escopo, valor, category_id, data, criado_por, origem)
  values ('22000000-0000-4000-8000-000000000001', '22000000-0000-4000-8000-0000000000a1', 'despesa', 'pessoal', 100, '22000000-0000-4000-8000-0000000000c1', '2026-11-10', '22000000-0000-4000-8000-0000000000a1', 'pluggy')
  $$, '23514', null, 'origem pluggy exige bank_transaction_id');

insert into tap_out(line) select throws_ok($$
  insert into public.recurring_occurrences (rule_id, mes_referencia, status) values
    ('22000000-0000-4000-8000-0000000000e1', '2026-11-01', 'pendente'),
    ('22000000-0000-4000-8000-0000000000e1', '2026-11-01', 'pendente')
  $$, '23505', null, 'ocorrencia duplicada e recusada');

insert into tap_out(line) select throws_ok($$
  insert into public.transactions (family_id, member_id, tipo, escopo, valor, category_id, data, criado_por, recurring_rule_id, mes_referencia) values
    ('22000000-0000-4000-8000-000000000001', '22000000-0000-4000-8000-0000000000a1', 'despesa', 'pessoal', 100, '22000000-0000-4000-8000-0000000000c1', '2026-11-10', '22000000-0000-4000-8000-0000000000a1', '22000000-0000-4000-8000-0000000000e1', '2026-11-01'),
    ('22000000-0000-4000-8000-000000000001', '22000000-0000-4000-8000-0000000000a1', 'despesa', 'pessoal', 100, '22000000-0000-4000-8000-0000000000c1', '2026-11-11', '22000000-0000-4000-8000-0000000000a1', '22000000-0000-4000-8000-0000000000e1', '2026-11-01')
  $$, '23505', null, 'confirmacao dupla da mesma regra/mes e recusada');

insert into tap_out(line) select throws_ok($$
  insert into public.transactions (family_id, member_id, tipo, escopo, valor, category_id, data, criado_por)
  values ('22000000-0000-4000-8000-000000000001', '22000000-0000-4000-8000-0000000000a1', 'despesa', 'pessoal', 100, '22000000-0000-4000-8000-0000000000c4', '2026-11-10', '22000000-0000-4000-8000-0000000000a1')
  $$, '23503', null, 'categoria de outra familia e recusada');

insert into tap_out(line) select throws_ok($$
  insert into public.transactions (family_id, member_id, tipo, escopo, valor, category_id, data, criado_por)
  values ('22000000-0000-4000-8000-000000000001', '22000000-0000-4000-8000-0000000000a1', 'despesa', 'pessoal', 100, '22000000-0000-4000-8000-0000000000c2', '2026-11-10', '22000000-0000-4000-8000-0000000000a1')
  $$, '23503', null, 'categoria de receita em despesa e recusada');

insert into tap_out(line) select throws_ok($$
  insert into public.recurring_rules (family_id, criado_por, tipo, escopo, valor, descricao, category_id, dia_vencimento)
  values ('22000000-0000-4000-8000-000000000001', '22000000-0000-4000-8000-0000000000a1', 'despesa', 'pessoal', 100, 'Regra invalida 02', '22000000-0000-4000-8000-0000000000c1', 32)
  $$, '23514', null, 'dia de vencimento 32 e recusado');

insert into tap_out(line) select * from finish();

select string_agg(line, E'\n' order by seq) as tap from tap_out;
rollback;
