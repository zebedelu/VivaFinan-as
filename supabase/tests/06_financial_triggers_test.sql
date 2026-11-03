begin;
set local search_path = public, extensions;

create temp table tap_out(seq serial, line text);
grant all on tap_out to public;
grant all on sequence tap_out_seq_seq to public;

insert into auth.users (id, email) values
  ('66000000-0000-4000-8000-0000000000a1', 'ana.66000000@test.local'),
  ('66000000-0000-4000-8000-0000000000b2', 'carlos.66000000@test.local'),
  ('66000000-0000-4000-8000-0000000000d4', 'externo.66000000@test.local');

insert into public.families (id, nome, criado_por) values
  ('66000000-0000-4000-8000-000000000001', 'Familia Teste A 06', '66000000-0000-4000-8000-0000000000a1'),
  ('66000000-0000-4000-8000-000000000002', 'Familia Teste B 06', '66000000-0000-4000-8000-0000000000d4');

insert into public.profiles (id, family_id, nome, papel, status) values
  ('66000000-0000-4000-8000-0000000000a1', '66000000-0000-4000-8000-000000000001', 'Ana', 'admin', 'ativo'),
  ('66000000-0000-4000-8000-0000000000b2', '66000000-0000-4000-8000-000000000001', 'Carlos', 'membro', 'ativo'),
  ('66000000-0000-4000-8000-0000000000d4', '66000000-0000-4000-8000-000000000002', 'Externo', 'admin', 'ativo');

insert into public.goals (id, family_id, member_id, criado_por, titulo, valor_alvo) values
  ('66000000-0000-4000-8000-0000000000f1', '66000000-0000-4000-8000-000000000001', null, '66000000-0000-4000-8000-0000000000a1', 'Meta 06 A', 100),
  ('66000000-0000-4000-8000-0000000000f2', '66000000-0000-4000-8000-000000000001', null, '66000000-0000-4000-8000-0000000000a1', 'Meta 06 B', 200);

insert into public.goal_contributions (id, goal_id, member_id, valor) values
  ('66000000-0000-4000-8000-0000000000e1', '66000000-0000-4000-8000-0000000000f1', '66000000-0000-4000-8000-0000000000a1', 100),
  ('66000000-0000-4000-8000-0000000000e2', '66000000-0000-4000-8000-0000000000f2', '66000000-0000-4000-8000-0000000000a1', 100);

insert into public.recurring_rules (id, family_id, criado_por, tipo, escopo, valor, descricao, category_id, dia_vencimento) values
  ('66000000-0000-4000-8000-0000000000d1', '66000000-0000-4000-8000-000000000001', '66000000-0000-4000-8000-0000000000a1', 'despesa', 'pessoal', 100, 'Regra 06 A', (select id from public.categories where family_id = '66000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação'), 10),
  ('66000000-0000-4000-8000-0000000000d2', '66000000-0000-4000-8000-000000000001', '66000000-0000-4000-8000-0000000000a1', 'despesa', 'pessoal', 100, 'Regra 06 B', (select id from public.categories where family_id = '66000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação'), 10);

insert into public.bank_connections (id, family_id, member_id, pluggy_connection_id, institution_name, status, atualizada_em) values
  ('66000000-0000-4000-8000-000000000101', '66000000-0000-4000-8000-000000000001', '66000000-0000-4000-8000-0000000000a1', 'conn-66000000-1', 'Banco 1', 'ativa', now()),
  ('66000000-0000-4000-8000-000000000102', '66000000-0000-4000-8000-000000000001', '66000000-0000-4000-8000-0000000000a1', 'conn-66000000-2', 'Banco 2', 'ativa', now()),
  ('66000000-0000-4000-8000-000000000103', '66000000-0000-4000-8000-000000000001', '66000000-0000-4000-8000-0000000000a1', 'conn-66000000-3', 'Banco 3', 'ativa', now()),
  ('66000000-0000-4000-8000-000000000104', '66000000-0000-4000-8000-000000000001', '66000000-0000-4000-8000-0000000000a1', 'conn-66000000-4', 'Banco 4', 'inativa', now() - interval '1 day');

insert into public.bank_accounts (id, connection_id, pluggy_account_id, nome, tipo, balance) values
  ('66000000-0000-4000-8000-000000000201', '66000000-0000-4000-8000-000000000101', 'acc-66000000-1', 'Conta 06', 'corrente', 1000);

insert into public.bank_transactions (id, bank_connection_id, bank_account_id, pluggy_transaction_id, data, valor, descricao, tipo, status) values
  ('66000000-0000-4000-8000-000000000301', '66000000-0000-4000-8000-000000000101', '66000000-0000-4000-8000-000000000201', 'tx-66000000-1', '2026-11-10', 10, 'Tx 06 1', 'debito', 'pendente_importacao'),
  ('66000000-0000-4000-8000-000000000302', '66000000-0000-4000-8000-000000000101', '66000000-0000-4000-8000-000000000201', 'tx-66000000-2', '2026-11-10', 10, 'Tx 06 2', 'debito', 'pendente_importacao'),
  ('66000000-0000-4000-8000-000000000303', '66000000-0000-4000-8000-000000000101', '66000000-0000-4000-8000-000000000201', 'tx-66000000-3', '2026-11-10', 10, 'Tx 06 3', 'debito', 'pendente_importacao'),
  ('66000000-0000-4000-8000-000000000304', '66000000-0000-4000-8000-000000000101', '66000000-0000-4000-8000-000000000201', 'tx-66000000-4', '2026-11-10', 10, 'Tx 06 4', 'debito', 'pendente_importacao');

insert into public.transactions (id, family_id, member_id, tipo, escopo, valor, category_id, data, criado_por) values
  ('66000000-0000-4000-8000-000000000401', '66000000-0000-4000-8000-000000000001', '66000000-0000-4000-8000-0000000000a1', 'despesa', 'pessoal', 10, (select id from public.categories where family_id = '66000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação'), '2026-11-10', '66000000-0000-4000-8000-0000000000a1');

insert into public.ai_suggestions (id, family_id, member_id, tipo, titulo, o_que, por_que, quanto) values
  ('66000000-0000-4000-8000-000000000501', '66000000-0000-4000-8000-000000000001', null, 'dica', 'Sugestao 06', 'O que', 'Por que', 'Quanto');

insert into tap_out(line) select plan(32);

insert into tap_out(line) select is((select status from public.goals where id = '66000000-0000-4000-8000-0000000000f1'), 'concluida', 'contribuicao que atinge o alvo conclui a meta');
insert into tap_out(line) select is((select status from public.goals where id = '66000000-0000-4000-8000-0000000000f2'), 'em_andamento', 'contribuicao parcial nao conclui a meta');
update public.goals set valor_alvo = 100 where id = '66000000-0000-4000-8000-0000000000f2';
insert into tap_out(line) select is((select status from public.goals where id = '66000000-0000-4000-8000-0000000000f2'), 'concluida', 'reduzir o alvo abaixo da soma conclui a meta');
update public.goals set valor_alvo = 300 where id = '66000000-0000-4000-8000-0000000000f2';
insert into tap_out(line) select is((select status from public.goals where id = '66000000-0000-4000-8000-0000000000f2'), 'em_andamento', 'aumentar o alvo acima da soma reabre a meta');
update public.goals set status = 'cancelada' where id = '66000000-0000-4000-8000-0000000000f2';
insert into tap_out(line) select is((select status from public.goals where id = '66000000-0000-4000-8000-0000000000f2'), 'cancelada', 'meta cancelada permanece cancelada');

insert into tap_out(line) select throws_ok($$ insert into public.goal_contributions (goal_id, member_id, valor) values ('66000000-0000-4000-8000-0000000000f1', '66000000-0000-4000-8000-0000000000a1', 10) $$, '42501', null, 'contribuicao em meta concluida e recusada');

insert into tap_out(line) select throws_ok($$ update public.transactions set member_id = '66000000-0000-4000-8000-0000000000b2' where id = '66000000-0000-4000-8000-000000000401' $$, '42501', null, 'member_id de lancamento e imutavel');
insert into tap_out(line) select throws_ok($$ update public.transactions set criado_por = '66000000-0000-4000-8000-0000000000b2' where id = '66000000-0000-4000-8000-000000000401' $$, '42501', null, 'criado_por de lancamento e imutavel');
insert into tap_out(line) select throws_ok($$ update public.transactions set family_id = '66000000-0000-4000-8000-000000000002' where id = '66000000-0000-4000-8000-000000000401' $$, '42501', null, 'family_id de lancamento e imutavel');
insert into tap_out(line) select throws_ok($$ update public.transactions set escopo = 'familia' where id = '66000000-0000-4000-8000-000000000401' $$, '42501', null, 'escopo de lancamento e imutavel');
insert into tap_out(line) select throws_ok($$ update public.transactions set origem = 'pluggy' where id = '66000000-0000-4000-8000-000000000401' $$, '42501', null, 'origem de lancamento e imutavel');
insert into tap_out(line) select throws_ok($$ update public.transactions set recurring_rule_id = '66000000-0000-4000-8000-0000000000d1' where id = '66000000-0000-4000-8000-000000000401' $$, '42501', null, 'recurring_rule_id de lancamento e imutavel');
insert into tap_out(line) select throws_ok($$ update public.transactions set mes_referencia = '2026-11-01' where id = '66000000-0000-4000-8000-000000000401' $$, '42501', null, 'mes_referencia de lancamento e imutavel');

insert into tap_out(line) select throws_ok($$ update public.recurring_rules set criado_por = '66000000-0000-4000-8000-0000000000b2' where id = '66000000-0000-4000-8000-0000000000d1' $$, '42501', null, 'criado_por de regra e imutavel');
insert into tap_out(line) select throws_ok($$ update public.recurring_rules set escopo = 'familia' where id = '66000000-0000-4000-8000-0000000000d1' $$, '42501', null, 'escopo de regra e imutavel');

insert into tap_out(line) select throws_ok($$ update public.goals set member_id = '66000000-0000-4000-8000-0000000000a1' where id = '66000000-0000-4000-8000-0000000000f1' $$, '42501', null, 'member_id de meta e imutavel');
insert into tap_out(line) select throws_ok($$ update public.goals set family_id = '66000000-0000-4000-8000-000000000002' where id = '66000000-0000-4000-8000-0000000000f1' $$, '42501', null, 'family_id de meta e imutavel');
insert into tap_out(line) select throws_ok($$ update public.goals set criado_por = '66000000-0000-4000-8000-0000000000b2' where id = '66000000-0000-4000-8000-0000000000f1' $$, '42501', null, 'criado_por de meta e imutavel');

insert into tap_out(line) select throws_ok($$ update public.bank_connections set member_id = '66000000-0000-4000-8000-0000000000b2' where id = '66000000-0000-4000-8000-000000000101' $$, '42501', null, 'member_id de conexao e imutavel');
insert into tap_out(line) select throws_ok($$ update public.bank_connections set pluggy_connection_id = 'conn-outra' where id = '66000000-0000-4000-8000-000000000101' $$, '42501', null, 'pluggy_connection_id e imutavel');
insert into tap_out(line) select throws_ok($$ update public.bank_connections set is_demo_sync = true where id = '66000000-0000-4000-8000-000000000101' $$, '42501', null, 'is_demo_sync e imutavel');

insert into tap_out(line) select lives_ok($$ insert into public.bank_connections (id, family_id, member_id, pluggy_connection_id, institution_name, status) values ('66000000-0000-4000-8000-000000000105', '66000000-0000-4000-8000-000000000001', '66000000-0000-4000-8000-0000000000a1', 'conn-66000000-5', 'Banco 5', 'inativa') $$, 'conexao inativa nao conta no limite');
insert into tap_out(line) select throws_ok($$ insert into public.bank_connections (id, family_id, member_id, pluggy_connection_id, institution_name, status) values ('66000000-0000-4000-8000-000000000106', '66000000-0000-4000-8000-000000000001', '66000000-0000-4000-8000-0000000000a1', 'conn-66000000-6', 'Banco 6', 'ativa') $$, '42501', null, 'quarta conexao ativa e recusada');

insert into tap_out(line) select throws_ok($$ update public.bank_transactions set valor = 20 where id = '66000000-0000-4000-8000-000000000304' $$, '42501', null, 'valor de transacao bancaria e imutavel');
insert into tap_out(line) select throws_ok($$ update public.bank_transactions set pluggy_transaction_id = 'tx-outra' where id = '66000000-0000-4000-8000-000000000304' $$, '42501', null, 'pluggy_transaction_id e imutavel');
insert into tap_out(line) select throws_ok($$ update public.bank_transactions set is_demo_sync = true where id = '66000000-0000-4000-8000-000000000304' $$, '42501', null, 'is_demo_sync de transacao e imutavel');
insert into tap_out(line) select lives_ok($$ update public.bank_transactions set status = 'ignorada' where id = '66000000-0000-4000-8000-000000000304' $$, 'status de transacao bancaria pode mudar');

set local role authenticated;
set local request.jwt.claim.sub = '66000000-0000-4000-8000-0000000000a1';
insert into tap_out(line) select throws_ok($$ update public.bank_transactions set transaction_id = '66000000-0000-4000-8000-000000000401' where id = '66000000-0000-4000-8000-000000000304' $$, '42501', null, 'usuario nao escreve transaction_id direto');
reset role;
reset request.jwt.claim.sub;

insert into tap_out(line) select throws_ok($$ update public.ai_suggestions set o_que = 'Outro' where id = '66000000-0000-4000-8000-000000000501' $$, '42501', null, 'conteudo de sugestao e imutavel');
insert into tap_out(line) select lives_ok($$ update public.ai_suggestions set lida = true where id = '66000000-0000-4000-8000-000000000501' $$, 'sugestao pode ser marcada como lida');
insert into tap_out(line) select throws_ok($$ update public.ai_suggestions set lida = false where id = '66000000-0000-4000-8000-000000000501' $$, '42501', null, 'lida nao volta para false');

update public.bank_connections set status = 'inativa' where id = '66000000-0000-4000-8000-000000000104';
insert into tap_out(line) select is((select atualizada_em > now() - interval '1 minute' from public.bank_connections where id = '66000000-0000-4000-8000-000000000104'), true, 'atualizada_em e atualizada no update');

insert into tap_out(line) select * from finish();

select string_agg(line, E'\n' order by seq) as tap from tap_out;
rollback;
