begin;
set local search_path = public, extensions;

create temp table tap_out(seq serial, line text);
grant all on tap_out to public;
grant all on sequence tap_out_seq_seq to public;

insert into auth.users (id, email) values
  ('99000000-0000-4000-8000-0000000000a1', 'ana.99000000@test.local'),
  ('99000000-0000-4000-8000-0000000000b2', 'carlos.99000000@test.local'),
  ('99000000-0000-4000-8000-0000000000c3', 'lucas.99000000@test.local'),
  ('99000000-0000-4000-8000-0000000000d4', 'externo.99000000@test.local');

insert into public.families (id, nome, criado_por) values
  ('99000000-0000-4000-8000-000000000001', 'Familia Teste A 09', '99000000-0000-4000-8000-0000000000a1'),
  ('99000000-0000-4000-8000-000000000002', 'Familia Teste B 09', '99000000-0000-4000-8000-0000000000d4');

insert into public.profiles (id, family_id, nome, papel, status) values
  ('99000000-0000-4000-8000-0000000000a1', '99000000-0000-4000-8000-000000000001', 'Ana', 'admin', 'ativo'),
  ('99000000-0000-4000-8000-0000000000b2', '99000000-0000-4000-8000-000000000001', 'Carlos', 'membro', 'ativo'),
  ('99000000-0000-4000-8000-0000000000c3', '99000000-0000-4000-8000-000000000001', 'Lucas', 'membro', 'ativo'),
  ('99000000-0000-4000-8000-0000000000d4', '99000000-0000-4000-8000-000000000002', 'Externo', 'admin', 'ativo');

insert into public.categories (id, family_id, nome, tipo, personalizada, criado_por) values
  ('99000000-0000-4000-8000-0000000000b1', '99000000-0000-4000-8000-000000000002', 'Categoria B 09', 'despesa', true, '99000000-0000-4000-8000-0000000000d4'),
  ('99000000-0000-4000-8000-0000000000c1', '99000000-0000-4000-8000-000000000001', 'Categoria A 09', 'despesa', true, '99000000-0000-4000-8000-0000000000a1');

insert into public.transactions (id, family_id, member_id, tipo, escopo, valor, descricao, category_id, data, criado_por) values
  ('99000000-0000-4000-8000-000000000401', '99000000-0000-4000-8000-000000000001', '99000000-0000-4000-8000-0000000000a1', 'despesa', 'pessoal', 100, 'Pessoal Ana', (select id from public.categories where family_id = '99000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação'), '2026-11-10', '99000000-0000-4000-8000-0000000000a1'),
  ('99000000-0000-4000-8000-000000000402', '99000000-0000-4000-8000-000000000001', '99000000-0000-4000-8000-0000000000b2', 'despesa', 'pessoal', 200, 'Pessoal Carlos', (select id from public.categories where family_id = '99000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação'), '2026-11-10', '99000000-0000-4000-8000-0000000000b2'),
  ('99000000-0000-4000-8000-000000000403', '99000000-0000-4000-8000-000000000001', '99000000-0000-4000-8000-0000000000a1', 'despesa', 'familia', 300, 'Familia 300', (select id from public.categories where family_id = '99000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação'), '2026-11-10', '99000000-0000-4000-8000-0000000000a1'),
  ('99000000-0000-4000-8000-000000000404', '99000000-0000-4000-8000-000000000001', '99000000-0000-4000-8000-0000000000b2', 'receita', 'familia', 1000, 'Familia 1000', (select id from public.categories where family_id = '99000000-0000-4000-8000-000000000001' and tipo = 'receita' and nome = 'Salário'), '2026-11-10', '99000000-0000-4000-8000-0000000000b2');

insert into public.recurring_rules (id, family_id, criado_por, tipo, escopo, valor, descricao, category_id, dia_vencimento) values
  ('99000000-0000-4000-8000-000000000501', '99000000-0000-4000-8000-000000000001', '99000000-0000-4000-8000-0000000000a1', 'despesa', 'pessoal', 100, 'Regra Pessoal Ana 09', (select id from public.categories where family_id = '99000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação'), 10),
  ('99000000-0000-4000-8000-000000000502', '99000000-0000-4000-8000-000000000001', '99000000-0000-4000-8000-0000000000a1', 'despesa', 'familia', 100, 'Regra Familia 09', (select id from public.categories where family_id = '99000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação'), 10);

insert into public.recurring_occurrences (id, rule_id, mes_referencia, status) values
  ('99000000-0000-4000-8000-000000000601', '99000000-0000-4000-8000-000000000501', '2026-11-01', 'pendente'),
  ('99000000-0000-4000-8000-000000000602', '99000000-0000-4000-8000-000000000502', '2026-11-01', 'pendente');

insert into public.bank_connections (id, family_id, member_id, pluggy_connection_id, institution_name, status) values
  ('99000000-0000-4000-8000-000000000101', '99000000-0000-4000-8000-000000000001', '99000000-0000-4000-8000-0000000000a1', 'conn-99000000-a', 'Banco Ana 09', 'ativa'),
  ('99000000-0000-4000-8000-000000000102', '99000000-0000-4000-8000-000000000001', '99000000-0000-4000-8000-0000000000b2', 'conn-99000000-c', 'Banco Carlos 09', 'ativa');

insert into public.bank_accounts (id, connection_id, pluggy_account_id, nome, tipo, balance) values
  ('99000000-0000-4000-8000-000000000201', '99000000-0000-4000-8000-000000000101', 'acc-99000000-a', 'Conta Ana 09', 'corrente', 1000),
  ('99000000-0000-4000-8000-000000000202', '99000000-0000-4000-8000-000000000102', 'acc-99000000-c', 'Conta Carlos 09', 'corrente', 500);

insert into public.bank_transactions (id, bank_connection_id, bank_account_id, pluggy_transaction_id, data, valor, descricao, tipo, status) values
  ('99000000-0000-4000-8000-000000000301', '99000000-0000-4000-8000-000000000101', '99000000-0000-4000-8000-000000000201', 'tx-99000000-a', '2026-11-10', 10, 'Tx Ana 09', 'debito', 'pendente_importacao'),
  ('99000000-0000-4000-8000-000000000302', '99000000-0000-4000-8000-000000000102', '99000000-0000-4000-8000-000000000202', 'tx-99000000-c', '2026-11-10', 20, 'Tx Carlos 09', 'debito', 'pendente_importacao');

insert into tap_out(line) select plan(27);

set local role authenticated;
set local request.jwt.claim.sub = '99000000-0000-4000-8000-0000000000b2';
insert into tap_out(line) select is((select count(*) from public.transactions), 3::bigint, 'Carlos ve 3 lancamentos');
reset role;
reset request.jwt.claim.sub;

set local role authenticated;
set local request.jwt.claim.sub = '99000000-0000-4000-8000-0000000000a1';
insert into tap_out(line) select is((select count(*) from public.transactions), 3::bigint, 'Ana ve 3 lancamentos');
reset role;
reset request.jwt.claim.sub;

set local role authenticated;
set local request.jwt.claim.sub = '99000000-0000-4000-8000-0000000000b2';
update public.transactions set descricao = 'Familia editada' where id = '99000000-0000-4000-8000-000000000403';
update public.transactions set descricao = 'Hack' where id = '99000000-0000-4000-8000-000000000401';
reset role;
reset request.jwt.claim.sub;
insert into tap_out(line) select is((select descricao from public.transactions where id = '99000000-0000-4000-8000-000000000403'), 'Familia editada', 'Carlos edita lancamento da familia');
insert into tap_out(line) select is((select descricao from public.transactions where id = '99000000-0000-4000-8000-000000000401'), 'Pessoal Ana', 'Carlos nao edita lancamento pessoal de Ana');

set local role authenticated;
set local request.jwt.claim.sub = '99000000-0000-4000-8000-0000000000a1';
insert into tap_out(line) select lives_ok($$ insert into public.transactions (id, family_id, member_id, tipo, escopo, valor, descricao, category_id, data, criado_por, origem, bank_transaction_id) values ('99000000-0000-4000-8000-000000000405','99000000-0000-4000-8000-000000000001','99000000-0000-4000-8000-0000000000a1','despesa','familia',10,'Importada Ana',(select id from public.categories where family_id='99000000-0000-4000-8000-000000000001' and tipo='despesa' and nome='Alimentação'),'2026-11-10','99000000-0000-4000-8000-0000000000a1','pluggy','99000000-0000-4000-8000-000000000301') $$, 'Ana cria lancamento familiar importado');
reset role;
reset request.jwt.claim.sub;

set local role authenticated;
set local request.jwt.claim.sub = '99000000-0000-4000-8000-0000000000b2';
update public.transactions set descricao = 'Importada editada' where id = '99000000-0000-4000-8000-000000000405';
delete from public.transactions where id = '99000000-0000-4000-8000-000000000405';
reset role;
reset request.jwt.claim.sub;
insert into tap_out(line) select is((select descricao from public.transactions where id = '99000000-0000-4000-8000-000000000405'), 'Importada editada', 'Carlos edita lancamento familiar importado');
insert into tap_out(line) select is((select count(*) from public.transactions where id = '99000000-0000-4000-8000-000000000405'), 1::bigint, 'Carlos nao apaga lancamento da familia');

set local role authenticated;
set local request.jwt.claim.sub = '99000000-0000-4000-8000-0000000000a1';
delete from public.transactions where id = '99000000-0000-4000-8000-000000000405';
reset role;
reset request.jwt.claim.sub;
insert into tap_out(line) select is((select count(*) from public.transactions where id = '99000000-0000-4000-8000-000000000405'), 0::bigint, 'Ana apaga o proprio lancamento da familia');

set local role authenticated;
set local request.jwt.claim.sub = '99000000-0000-4000-8000-0000000000b2';
insert into tap_out(line) select throws_ok($$ insert into public.transactions (family_id, member_id, tipo, escopo, valor, category_id, data, criado_por) values ('99000000-0000-4000-8000-000000000001','99000000-0000-4000-8000-0000000000a1','despesa','pessoal',10,(select id from public.categories where family_id='99000000-0000-4000-8000-000000000001' and tipo='despesa' and nome='Alimentação'),'2026-11-10','99000000-0000-4000-8000-0000000000b2') $$, '42501', null, 'Carlos nao cria lancamento com member_id de Ana');
insert into tap_out(line) select throws_ok($$ insert into public.transactions (family_id, member_id, tipo, escopo, valor, category_id, data, criado_por) values ('99000000-0000-4000-8000-000000000002','99000000-0000-4000-8000-0000000000b2','despesa','pessoal',10,'99000000-0000-4000-8000-0000000000b1','2026-11-10','99000000-0000-4000-8000-0000000000b2') $$, '42501', null, 'Carlos nao cria lancamento na familia B');
insert into tap_out(line) select throws_ok($$ insert into public.transactions (family_id, member_id, tipo, escopo, valor, category_id, data, criado_por, recurring_rule_id, mes_referencia) values ('99000000-0000-4000-8000-000000000001','99000000-0000-4000-8000-0000000000b2','despesa','pessoal',10,(select id from public.categories where family_id='99000000-0000-4000-8000-000000000001' and tipo='despesa' and nome='Alimentação'),'2026-11-10','99000000-0000-4000-8000-0000000000b2','99000000-0000-4000-8000-000000000501','2026-11-01') $$, '42501', null, 'Carlos nao usa regra pessoal de Ana');
insert into tap_out(line) select throws_ok($$ insert into public.transactions (family_id, member_id, tipo, escopo, valor, category_id, data, criado_por, origem, bank_transaction_id) values ('99000000-0000-4000-8000-000000000001','99000000-0000-4000-8000-0000000000b2','despesa','pessoal',10,(select id from public.categories where family_id='99000000-0000-4000-8000-000000000001' and tipo='despesa' and nome='Alimentação'),'2026-11-10','99000000-0000-4000-8000-0000000000b2','pluggy','99000000-0000-4000-8000-000000000301') $$, '42501', null, 'Carlos nao usa transacao bancaria de Ana');
insert into tap_out(line) select throws_ok($$ insert into public.transactions (family_id, member_id, tipo, escopo, valor, category_id, data, criado_por, origem) values ('99000000-0000-4000-8000-000000000001','99000000-0000-4000-8000-0000000000b2','despesa','pessoal',10,(select id from public.categories where family_id='99000000-0000-4000-8000-000000000001' and tipo='despesa' and nome='Alimentação'),'2026-11-10','99000000-0000-4000-8000-0000000000b2','pluggy') $$, '23514', null, 'pluggy sem bank_transaction_id e recusado');
insert into tap_out(line) select lives_ok($$ insert into public.transactions (id, family_id, member_id, tipo, escopo, valor, category_id, data, criado_por, origem, bank_transaction_id) values ('99000000-0000-4000-8000-000000000406','99000000-0000-4000-8000-000000000001','99000000-0000-4000-8000-0000000000b2','despesa','pessoal',10,(select id from public.categories where family_id='99000000-0000-4000-8000-000000000001' and tipo='despesa' and nome='Alimentação'),'2026-11-10','99000000-0000-4000-8000-0000000000b2','pluggy','99000000-0000-4000-8000-000000000302') $$, 'Carlos importa a propria transacao bancaria');
reset role;
reset request.jwt.claim.sub;

set local role authenticated;
set local request.jwt.claim.sub = '99000000-0000-4000-8000-0000000000b2';
insert into tap_out(line) select is((select count(*) from public.recurring_rules where id = '99000000-0000-4000-8000-000000000501'), 0::bigint, 'regra pessoal de Ana invisivel a Carlos');
insert into tap_out(line) select is((select count(*) from public.recurring_rules where id = '99000000-0000-4000-8000-000000000502'), 1::bigint, 'regra da familia visivel a Carlos');
update public.recurring_rules set ativo = false where id = '99000000-0000-4000-8000-000000000502';
insert into tap_out(line) select throws_ok($$ delete from public.recurring_rules where id = '99000000-0000-4000-8000-000000000502' $$, '42501', null, 'regra nao tem delete');
reset role;
reset request.jwt.claim.sub;
insert into tap_out(line) select is((select ativo from public.recurring_rules where id = '99000000-0000-4000-8000-000000000502'), false, 'regra da familia pode ser desativada');

set local role authenticated;
set local request.jwt.claim.sub = '99000000-0000-4000-8000-0000000000b2';
insert into tap_out(line) select is((select count(*) from public.recurring_occurrences where id = '99000000-0000-4000-8000-000000000601'), 0::bigint, 'ocorrencia pessoal de Ana invisivel a Carlos');
insert into tap_out(line) select is((select count(*) from public.recurring_occurrences where id = '99000000-0000-4000-8000-000000000602'), 1::bigint, 'ocorrencia da familia visivel a Carlos');
insert into tap_out(line) select throws_ok($$ insert into public.recurring_occurrences (rule_id, mes_referencia, status, valor_confirmado, confirmado_por, confirmado_em) values ('99000000-0000-4000-8000-000000000502','2026-12-01','confirmado',100,'99000000-0000-4000-8000-0000000000b2',now()) $$, '42501', null, 'insert direto de ocorrencia confirmada e recusado');
update public.recurring_occurrences set status = 'confirmado', valor_confirmado = 100, confirmado_por = '99000000-0000-4000-8000-0000000000b2', confirmado_em = now() where id = '99000000-0000-4000-8000-000000000602';
reset role;
reset request.jwt.claim.sub;
insert into tap_out(line) select is((select status from public.recurring_occurrences where id = '99000000-0000-4000-8000-000000000602'), 'confirmado', 'Carlos confirma a ocorrencia da familia');
insert into tap_out(line) select is((select count(*) from public.transactions where recurring_rule_id = '99000000-0000-4000-8000-000000000502'), 0::bigint, 'confirmar ocorrencia nao cria lancamento');

update public.profiles set status = 'inativo' where id = '99000000-0000-4000-8000-0000000000b2';
set local role authenticated;
set local request.jwt.claim.sub = '99000000-0000-4000-8000-0000000000b2';
insert into tap_out(line) select is((select count(*) from public.transactions), 0::bigint, 'membro inativo ve 0 lancamentos');
insert into tap_out(line) select throws_ok($$ insert into public.transactions (family_id, member_id, tipo, escopo, valor, category_id, data, criado_por) values ('99000000-0000-4000-8000-000000000001','99000000-0000-4000-8000-0000000000b2','despesa','pessoal',10,'99000000-0000-4000-8000-0000000000c1','2026-11-10','99000000-0000-4000-8000-0000000000b2') $$, '42501', null, 'membro inativo nao insere lancamento');
reset role;
reset request.jwt.claim.sub;

insert into tap_out(line) select is(has_table_privilege('authenticated', 'public.recurring_rules', 'DELETE'), false, 'recurring_rules sem grant de delete');
insert into tap_out(line) select is((select count(*) from pg_policies where schemaname = 'public' and tablename = 'recurring_rules' and cmd = 'DELETE'), 0::bigint, 'recurring_rules sem policy de delete');

insert into tap_out(line) select * from finish();

select string_agg(line, E'\n' order by seq) as tap from tap_out;
rollback;
