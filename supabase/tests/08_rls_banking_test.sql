begin;
set local search_path = public, extensions;

create temp table tap_out(seq serial, line text);
grant all on tap_out to public;
grant all on sequence tap_out_seq_seq to public;

insert into auth.users (id, email) values
  ('88000000-0000-4000-8000-0000000000a1', 'ana.88000000@test.local'),
  ('88000000-0000-4000-8000-0000000000b2', 'carlos.88000000@test.local'),
  ('88000000-0000-4000-8000-0000000000d4', 'externo.88000000@test.local');

insert into public.families (id, nome, criado_por) values
  ('88000000-0000-4000-8000-000000000001', 'Familia Teste A 08', '88000000-0000-4000-8000-0000000000a1'),
  ('88000000-0000-4000-8000-000000000002', 'Familia Teste B 08', '88000000-0000-4000-8000-0000000000d4');

insert into public.profiles (id, family_id, nome, papel, status) values
  ('88000000-0000-4000-8000-0000000000a1', '88000000-0000-4000-8000-000000000001', 'Ana', 'admin', 'ativo'),
  ('88000000-0000-4000-8000-0000000000b2', '88000000-0000-4000-8000-000000000001', 'Carlos', 'membro', 'ativo'),
  ('88000000-0000-4000-8000-0000000000d4', '88000000-0000-4000-8000-000000000002', 'Externo', 'admin', 'ativo');

insert into public.bank_connections (id, family_id, member_id, pluggy_connection_id, institution_name, status, is_demo_sync) values
  ('88000000-0000-4000-8000-000000000101', '88000000-0000-4000-8000-000000000001', '88000000-0000-4000-8000-0000000000a1', 'conn-88000000-a', 'Banco Ana', 'ativa', false),
  ('88000000-0000-4000-8000-000000000102', '88000000-0000-4000-8000-000000000001', '88000000-0000-4000-8000-0000000000b2', 'conn-88000000-c', 'Banco Carlos', 'ativa', false),
  ('88000000-0000-4000-8000-000000000103', '88000000-0000-4000-8000-000000000001', '88000000-0000-4000-8000-0000000000a1', 'conn-88000000-demo', 'Banco Demo', 'ativa', true);

insert into public.bank_accounts (id, connection_id, pluggy_account_id, nome, tipo, balance) values
  ('88000000-0000-4000-8000-000000000201', '88000000-0000-4000-8000-000000000101', 'acc-88000000-a', 'Conta Ana', 'corrente', 1000),
  ('88000000-0000-4000-8000-000000000202', '88000000-0000-4000-8000-000000000102', 'acc-88000000-c', 'Conta Carlos', 'corrente', 500),
  ('88000000-0000-4000-8000-000000000203', '88000000-0000-4000-8000-000000000103', 'acc-88000000-demo', 'Conta Demo', 'corrente', 4820.35);

insert into public.bank_transactions (id, bank_connection_id, bank_account_id, pluggy_transaction_id, data, valor, descricao, tipo, status, is_demo_sync) values
  ('88000000-0000-4000-8000-000000000301', '88000000-0000-4000-8000-000000000101', '88000000-0000-4000-8000-000000000201', 'tx-88000000-a', '2026-11-10', 10, 'Tx Ana', 'debito', 'pendente_importacao', false),
  ('88000000-0000-4000-8000-000000000302', '88000000-0000-4000-8000-000000000102', '88000000-0000-4000-8000-000000000202', 'tx-88000000-c', '2026-11-10', 20, 'Tx Carlos', 'debito', 'pendente_importacao', false),
  ('88000000-0000-4000-8000-000000000303', '88000000-0000-4000-8000-000000000103', '88000000-0000-4000-8000-000000000203', 'tx-88000000-demo', '2026-11-10', 30, 'Tx Demo', 'debito', 'pendente_importacao', true);

insert into tap_out(line) select plan(34);

set local role authenticated;
set local request.jwt.claim.sub = '88000000-0000-4000-8000-0000000000a1';
insert into tap_out(line) select is((select count(*) from public.bank_connections where id = '88000000-0000-4000-8000-000000000101'), 1::bigint, 'Ana ve a propria conexao');
insert into tap_out(line) select is((select count(*) from public.bank_connections where id = '88000000-0000-4000-8000-000000000102'), 0::bigint, 'Ana nao ve a conexao de Carlos');
insert into tap_out(line) select is((select count(*) from public.bank_accounts where id = '88000000-0000-4000-8000-000000000201'), 1::bigint, 'Ana ve a propria conta');
insert into tap_out(line) select is((select count(*) from public.bank_accounts where id = '88000000-0000-4000-8000-000000000202'), 0::bigint, 'Ana nao ve a conta de Carlos');
insert into tap_out(line) select is((select count(*) from public.bank_transactions where id = '88000000-0000-4000-8000-000000000301'), 1::bigint, 'Ana ve a propria transacao bancaria');
insert into tap_out(line) select is((select count(*) from public.bank_transactions where id = '88000000-0000-4000-8000-000000000302'), 0::bigint, 'Ana nao ve a transacao de Carlos');
reset role;
reset request.jwt.claim.sub;

set local role authenticated;
set local request.jwt.claim.sub = '88000000-0000-4000-8000-0000000000b2';
insert into tap_out(line) select is((select count(*) from public.bank_connections where id = '88000000-0000-4000-8000-000000000102'), 1::bigint, 'Carlos ve a propria conexao');
insert into tap_out(line) select is((select count(*) from public.bank_connections where id = '88000000-0000-4000-8000-000000000101'), 0::bigint, 'Carlos nao ve a conexao de Ana');
reset role;
reset request.jwt.claim.sub;

update public.profiles set status = 'inativo' where id = '88000000-0000-4000-8000-0000000000b2';

set local role authenticated;
set local request.jwt.claim.sub = '88000000-0000-4000-8000-0000000000b2';
insert into tap_out(line) select is((select count(*) from public.bank_connections), 0::bigint, 'membro inativo ve 0 conexoes');
insert into tap_out(line) select is((select count(*) from public.bank_accounts), 0::bigint, 'membro inativo ve 0 contas');
insert into tap_out(line) select is((select count(*) from public.bank_transactions), 0::bigint, 'membro inativo ve 0 transacoes bancarias');
reset role;
reset request.jwt.claim.sub;

update public.profiles set status = 'ativo' where id = '88000000-0000-4000-8000-0000000000b2';

set local role authenticated;
set local request.jwt.claim.sub = '88000000-0000-4000-8000-0000000000a1';
insert into tap_out(line) select throws_ok($$ insert into public.bank_connections (family_id, member_id, pluggy_connection_id, institution_name, status) values ('88000000-0000-4000-8000-000000000001', '88000000-0000-4000-8000-0000000000b2', 'conn-invalid-88000000', 'Banco Invalido', 'ativa') $$, '42501', null, 'Ana nao cria conexao para Carlos');
insert into tap_out(line) select throws_ok($$ insert into public.bank_transactions (bank_connection_id, bank_account_id, pluggy_transaction_id, data, valor, descricao, tipo, status) values ('88000000-0000-4000-8000-000000000101', '88000000-0000-4000-8000-000000000201', 'tx-invalid-88000000', '2026-11-10', 10, 'Tx Invalida', 'debito', 'pendente_importacao') $$, '42501', null, 'usuario nao insere transacao bancaria');
update public.bank_transactions set status = 'ignorada' where id = '88000000-0000-4000-8000-000000000301';
update public.bank_transactions set status = 'ignorada' where id = '88000000-0000-4000-8000-000000000302';
update public.bank_transactions set status = 'ignorada' where id = '88000000-0000-4000-8000-000000000303';
update public.bank_accounts set nome = 'Conta Ana Editada' where id = '88000000-0000-4000-8000-000000000201';
update public.bank_accounts set nome = 'Conta Demo Editada' where id = '88000000-0000-4000-8000-000000000203';
reset role;
reset request.jwt.claim.sub;

insert into tap_out(line) select is((select status from public.bank_transactions where id = '88000000-0000-4000-8000-000000000301'), 'ignorada', 'Ana atualiza o status da propria transacao');
insert into tap_out(line) select is((select status from public.bank_transactions where id = '88000000-0000-4000-8000-000000000302'), 'pendente_importacao', 'Ana nao atualiza a transacao de Carlos');
insert into tap_out(line) select is((select status from public.bank_transactions where id = '88000000-0000-4000-8000-000000000303'), 'pendente_importacao', 'Ana nao atualiza a transacao demo');
insert into tap_out(line) select is((select nome from public.bank_accounts where id = '88000000-0000-4000-8000-000000000201'), 'Conta Ana Editada', 'Ana atualiza a propria conta');
insert into tap_out(line) select is((select nome from public.bank_accounts where id = '88000000-0000-4000-8000-000000000203'), 'Conta Demo', 'Ana nao atualiza a conta demo');

set local role authenticated;
set local request.jwt.claim.sub = '88000000-0000-4000-8000-0000000000a1';
insert into tap_out(line) select throws_ok($$ delete from public.bank_accounts where id = '88000000-0000-4000-8000-000000000203' $$, '42501', null, 'conta demo nao tem delete');
insert into tap_out(line) select throws_ok($$ delete from public.bank_accounts where id = '88000000-0000-4000-8000-000000000201' $$, '42501', null, 'conta normal nao tem delete');
insert into tap_out(line) select throws_ok($$ delete from public.bank_transactions where id = '88000000-0000-4000-8000-000000000301' $$, '42501', null, 'transacao bancaria nao tem delete');
insert into tap_out(line) select throws_ok($$ delete from public.bank_connections where id = '88000000-0000-4000-8000-000000000101' $$, '42501', null, 'conexao propria nao tem delete');
insert into tap_out(line) select throws_ok($$ delete from public.bank_connections where id = '88000000-0000-4000-8000-000000000102' $$, '42501', null, 'Ana nao deleta a conexao de Carlos');
reset role;
reset request.jwt.claim.sub;

set local role authenticated;
set local request.jwt.claim.sub = '88000000-0000-4000-8000-0000000000b2';
insert into tap_out(line) select throws_ok($$ delete from public.bank_connections where id = '88000000-0000-4000-8000-000000000101' $$, '42501', null, 'Carlos nao deleta a conexao de Ana');
reset role;
reset request.jwt.claim.sub;

insert into public.transactions (id, family_id, member_id, tipo, escopo, valor, category_id, data, criado_por, origem, bank_transaction_id) values
  ('88000000-0000-4000-8000-000000000401', '88000000-0000-4000-8000-000000000001', '88000000-0000-4000-8000-0000000000a1', 'despesa', 'pessoal', 30, (select id from public.categories where family_id = '88000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação'), '2026-11-10', '88000000-0000-4000-8000-0000000000a1', 'pluggy', '88000000-0000-4000-8000-000000000303');

insert into tap_out(line) select is((select status || '|' || coalesce(transaction_id::text, '') from public.bank_transactions where id = '88000000-0000-4000-8000-000000000303'), 'importada|88000000-0000-4000-8000-000000000401', 'importacao da demo marca a transacao bancaria');

set local role authenticated;
set local request.jwt.claim.sub = '88000000-0000-4000-8000-0000000000a1';
update public.bank_transactions set status = 'ignorada' where id = '88000000-0000-4000-8000-000000000303';
reset role;
reset request.jwt.claim.sub;
insert into tap_out(line) select is((select status from public.bank_transactions where id = '88000000-0000-4000-8000-000000000303'), 'importada', 'dados brutos da demo continuam somente leitura');

insert into tap_out(line) select is(has_table_privilege('authenticated', 'public.bank_connections', 'DELETE'), false, 'bank_connections sem grant de delete');
insert into tap_out(line) select is(has_table_privilege('authenticated', 'public.bank_accounts', 'DELETE'), false, 'bank_accounts sem grant de delete');
insert into tap_out(line) select is(has_table_privilege('authenticated', 'public.bank_transactions', 'DELETE'), false, 'bank_transactions sem grant de delete');
insert into tap_out(line) select is(has_table_privilege('authenticated', 'public.bank_transactions', 'INSERT'), false, 'bank_transactions sem grant de insert');
insert into tap_out(line) select is(has_column_privilege('authenticated', 'public.bank_transactions', 'transaction_id', 'UPDATE'), false, 'transaction_id nao e updateable');
insert into tap_out(line) select is(has_column_privilege('authenticated', 'public.bank_transactions', 'status', 'UPDATE'), true, 'status e updateable');
insert into tap_out(line) select is((select count(*) from pg_policies where schemaname = 'public' and tablename in ('bank_connections', 'bank_accounts', 'bank_transactions') and cmd = 'DELETE'), 0::bigint, 'sem policy de delete bancario');
insert into tap_out(line) select is((select count(*) from pg_policies where schemaname = 'public' and tablename = 'bank_transactions' and cmd = 'INSERT'), 0::bigint, 'sem policy de insert em bank_transactions');

insert into tap_out(line) select * from finish();

select string_agg(line, E'\n' order by seq) as tap from tap_out;
rollback;
