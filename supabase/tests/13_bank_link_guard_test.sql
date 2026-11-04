begin;
set local search_path = public, extensions;

create temp table tap_out(seq serial, line text);
grant all on tap_out to public;
grant all on sequence tap_out_seq_seq to public;

insert into tap_out(line) select plan(28);

insert into auth.users (id, email) values
  ('cc000000-0000-4000-8000-0000000000a1', 'ana.13@test.local'),
  ('cc000000-0000-4000-8000-0000000000b2', 'carlos.13@test.local'),
  ('cc000000-0000-4000-8000-0000000000d4', 'externo.13@test.local');

insert into public.families (id, nome, criado_por) values
  ('cc000000-0000-4000-8000-000000000001', 'Familia 13 A', 'cc000000-0000-4000-8000-0000000000a1'),
  ('cc000000-0000-4000-8000-000000000002', 'Familia 13 B', 'cc000000-0000-4000-8000-0000000000d4');

insert into public.profiles (id, family_id, nome, papel, status) values
  ('cc000000-0000-4000-8000-0000000000a1', 'cc000000-0000-4000-8000-000000000001', 'Ana', 'admin', 'ativo'),
  ('cc000000-0000-4000-8000-0000000000b2', 'cc000000-0000-4000-8000-000000000001', 'Carlos', 'membro', 'ativo'),
  ('cc000000-0000-4000-8000-0000000000d4', 'cc000000-0000-4000-8000-000000000002', 'Externo', 'admin', 'ativo');

insert into public.bank_connections (id, family_id, member_id, pluggy_connection_id, institution_name, status) values
  ('cc000000-0000-4000-8000-0000000000c1', 'cc000000-0000-4000-8000-000000000001', 'cc000000-0000-4000-8000-0000000000a1', 'cc13-ana-bank', 'Banco Ana 13', 'ativa'),
  ('cc000000-0000-4000-8000-0000000000c2', 'cc000000-0000-4000-8000-000000000001', 'cc000000-0000-4000-8000-0000000000b2', 'cc13-carlos-bank', 'Banco Carlos 13', 'ativa'),
  ('cc000000-0000-4000-8000-0000000000c3', 'cc000000-0000-4000-8000-000000000002', 'cc000000-0000-4000-8000-0000000000d4', 'cc13-externo-bank', 'Banco Externo 13', 'ativa');

insert into public.bank_accounts (id, connection_id, pluggy_account_id, nome, tipo, balance) values
  ('cc000000-0000-4000-8000-0000000000e1', 'cc000000-0000-4000-8000-0000000000c1', 'cc13-ana-acc', 'Conta Ana 13', 'corrente', 10),
  ('cc000000-0000-4000-8000-0000000000e2', 'cc000000-0000-4000-8000-0000000000c2', 'cc13-carlos-acc', 'Conta Carlos 13', 'corrente', 10),
  ('cc000000-0000-4000-8000-0000000000e3', 'cc000000-0000-4000-8000-0000000000c3', 'cc13-externo-acc', 'Conta Externo 13', 'corrente', 10);

insert into public.bank_transactions (id, bank_connection_id, bank_account_id, pluggy_transaction_id, data, valor, descricao, tipo, status) values
  ('cc000000-0000-4000-8000-000000000301', 'cc000000-0000-4000-8000-0000000000c1', 'cc000000-0000-4000-8000-0000000000e1', 'cc13-ana-tx-1', '2026-11-01', 10, 'Ana tx 1', 'debito', 'pendente_importacao'),
  ('cc000000-0000-4000-8000-000000000302', 'cc000000-0000-4000-8000-0000000000c2', 'cc000000-0000-4000-8000-0000000000e2', 'cc13-carlos-tx-1', '2026-11-01', 10, 'Carlos tx 1', 'debito', 'pendente_importacao'),
  ('cc000000-0000-4000-8000-000000000303', 'cc000000-0000-4000-8000-0000000000c3', 'cc000000-0000-4000-8000-0000000000e3', 'cc13-externo-tx-1', '2026-11-01', 10, 'Externo tx 1', 'debito', 'pendente_importacao'),
  ('cc000000-0000-4000-8000-000000000304', 'cc000000-0000-4000-8000-0000000000c1', 'cc000000-0000-4000-8000-0000000000e1', 'cc13-ana-tx-2', '2026-11-01', 10, 'Ana tx 2', 'debito', 'pendente_importacao'),
  ('cc000000-0000-4000-8000-000000000305', 'cc000000-0000-4000-8000-0000000000c1', 'cc000000-0000-4000-8000-0000000000e1', 'cc13-ana-tx-3', '2026-11-01', 10, 'Ana tx 3', 'debito', 'pendente_importacao'),
  ('cc000000-0000-4000-8000-000000000308', 'cc000000-0000-4000-8000-0000000000c2', 'cc000000-0000-4000-8000-0000000000e2', 'cc13-carlos-tx-2', '2026-11-01', 10, 'Carlos tx 2', 'debito', 'pendente_importacao');

insert into public.transactions (id, family_id, member_id, tipo, escopo, valor, descricao, category_id, data, criado_por, origem) values
  ('cc000000-0000-4000-8000-000000000401', 'cc000000-0000-4000-8000-000000000001', 'cc000000-0000-4000-8000-0000000000a1', 'despesa', 'familia', 10, 'Ana familia sem vinculo', (select id from public.categories where family_id = 'cc000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação'), '2026-11-01', 'cc000000-0000-4000-8000-0000000000a1', 'manual'),
  ('cc000000-0000-4000-8000-000000000402', 'cc000000-0000-4000-8000-000000000001', 'cc000000-0000-4000-8000-0000000000b2', 'despesa', 'familia', 10, 'Carlos familia sem vinculo', (select id from public.categories where family_id = 'cc000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação'), '2026-11-01', 'cc000000-0000-4000-8000-0000000000b2', 'manual');

insert into public.transactions (id, family_id, member_id, tipo, escopo, valor, descricao, category_id, data, criado_por, origem, bank_transaction_id) values
  ('cc000000-0000-4000-8000-000000000403', 'cc000000-0000-4000-8000-000000000001', 'cc000000-0000-4000-8000-0000000000a1', 'despesa', 'familia', 10, 'Ana familia com vinculo', (select id from public.categories where family_id = 'cc000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação'), '2026-11-01', 'cc000000-0000-4000-8000-0000000000a1', 'manual', 'cc000000-0000-4000-8000-000000000301');

insert into public.transactions (id, family_id, member_id, tipo, escopo, valor, descricao, category_id, data, criado_por, origem, bank_transaction_id) values
  ('cc000000-0000-4000-8000-000000000404', 'cc000000-0000-4000-8000-000000000001', 'cc000000-0000-4000-8000-0000000000b2', 'despesa', 'familia', 10, 'Carlos familia com vinculo da Ana', (select id from public.categories where family_id = 'cc000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação'), '2026-11-01', 'cc000000-0000-4000-8000-0000000000b2', 'manual', 'cc000000-0000-4000-8000-000000000304'),
  ('cc000000-0000-4000-8000-000000000407', 'cc000000-0000-4000-8000-000000000001', 'cc000000-0000-4000-8000-0000000000b2', 'despesa', 'familia', 10, 'Carlos familia com vinculo proprio', (select id from public.categories where family_id = 'cc000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação'), '2026-11-01', 'cc000000-0000-4000-8000-0000000000b2', 'manual', 'cc000000-0000-4000-8000-000000000308');

-- Guard no INSERT: postgres bypassa a policy, mas auth.uid() continua Carlos.
set local request.jwt.claim.sub = 'cc000000-0000-4000-8000-0000000000b2';
insert into tap_out(line) select throws_ok($$ insert into public.transactions (id, family_id, member_id, tipo, escopo, valor, descricao, category_id, data, criado_por, origem, bank_transaction_id) values ('cc000000-0000-4000-8000-000000000409', 'cc000000-0000-4000-8000-000000000001', 'cc000000-0000-4000-8000-0000000000b2', 'despesa', 'pessoal', 10, 'Insert guard', (select id from public.categories where family_id = 'cc000000-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação'), '2026-11-01', 'cc000000-0000-4000-8000-0000000000b2', 'manual', 'cc000000-0000-4000-8000-000000000305') $$, '42501', null, 'guard bloqueia INSERT com bank tx alheia');
reset request.jwt.claim.sub;

-- Carlos tenta linkar a bank tx pendente da Ana na transacao familiar dele.
set local role authenticated;
set local request.jwt.claim.sub = 'cc000000-0000-4000-8000-0000000000b2';
insert into tap_out(line) select throws_ok($$ update public.transactions set bank_transaction_id = 'cc000000-0000-4000-8000-000000000305' where id = 'cc000000-0000-4000-8000-000000000402' $$, '42501', null, 'Carlos nao linka bank tx da Ana');
reset role;
reset request.jwt.claim.sub;
insert into tap_out(line) select is((select status || '|' || coalesce(transaction_id::text, '') from public.bank_transactions where id = 'cc000000-0000-4000-8000-000000000305'), 'pendente_importacao|', 'bank tx da Ana intacta apos link recusado');

-- Carlos tenta trocar o vinculo da transacao familiar da Ana para a bank tx dele.
set local role authenticated;
set local request.jwt.claim.sub = 'cc000000-0000-4000-8000-0000000000b2';
insert into tap_out(line) select throws_ok($$ update public.transactions set bank_transaction_id = 'cc000000-0000-4000-8000-000000000302' where id = 'cc000000-0000-4000-8000-000000000403' $$, '42501', null, 'Carlos nao troca o vinculo da Ana');
reset role;
reset request.jwt.claim.sub;
insert into tap_out(line) select is((select status || '|' || coalesce(transaction_id::text, '') from public.bank_transactions where id = 'cc000000-0000-4000-8000-000000000301'), 'reconciliada|cc000000-0000-4000-8000-000000000403', 'vinculo da Ana intacto apos troca recusada');

-- Carlos tenta apagar a propria transacao familiar que aponta para a bank tx da Ana.
set local role authenticated;
set local request.jwt.claim.sub = 'cc000000-0000-4000-8000-0000000000b2';
insert into tap_out(line) select throws_ok($$ delete from public.transactions where id = 'cc000000-0000-4000-8000-000000000404' $$, '42501', null, 'Carlos nao apaga transacao com bank tx da Ana');
reset role;
reset request.jwt.claim.sub;
insert into tap_out(line) select is((select status || '|' || coalesce(transaction_id::text, '') from public.bank_transactions where id = 'cc000000-0000-4000-8000-000000000304'), 'reconciliada|cc000000-0000-4000-8000-000000000404', 'bank tx da Ana intacta apos delete recusado');

-- Carlos tenta linkar uma bank tx da familia B.
set local role authenticated;
set local request.jwt.claim.sub = 'cc000000-0000-4000-8000-0000000000b2';
insert into tap_out(line) select throws_ok($$ update public.transactions set bank_transaction_id = 'cc000000-0000-4000-8000-000000000303' where id = 'cc000000-0000-4000-8000-000000000402' $$, '42501', null, 'Carlos nao linka bank tx de outra familia');
reset role;
reset request.jwt.claim.sub;
insert into tap_out(line) select is((select status || '|' || coalesce(transaction_id::text, '') from public.bank_transactions where id = 'cc000000-0000-4000-8000-000000000303'), 'pendente_importacao|', 'bank tx da familia B intacta');

-- Carlos linka e deslinka a propria bank tx.
set local role authenticated;
set local request.jwt.claim.sub = 'cc000000-0000-4000-8000-0000000000b2';
insert into tap_out(line) select lives_ok($$ update public.transactions set bank_transaction_id = 'cc000000-0000-4000-8000-000000000302' where id = 'cc000000-0000-4000-8000-000000000402' $$, 'Carlos linka a propria bank tx');
insert into tap_out(line) select lives_ok($$ update public.transactions set bank_transaction_id = null where id = 'cc000000-0000-4000-8000-000000000402' $$, 'Carlos deslinka a propria bank tx');
reset role;
reset request.jwt.claim.sub;
insert into tap_out(line) select is((select status || '|' || coalesce(transaction_id::text, '') from public.bank_transactions where id = 'cc000000-0000-4000-8000-000000000302'), 'pendente_importacao|', 'bank tx do Carlos volta a pendente');

-- Ana linka e deslinka a propria bank tx.
set local role authenticated;
set local request.jwt.claim.sub = 'cc000000-0000-4000-8000-0000000000a1';
insert into tap_out(line) select lives_ok($$ update public.transactions set bank_transaction_id = 'cc000000-0000-4000-8000-000000000305' where id = 'cc000000-0000-4000-8000-000000000401' $$, 'Ana linka a propria bank tx');
insert into tap_out(line) select lives_ok($$ update public.transactions set bank_transaction_id = null where id = 'cc000000-0000-4000-8000-000000000401' $$, 'Ana deslinka a propria bank tx');
reset role;
reset request.jwt.claim.sub;
insert into tap_out(line) select is((select status || '|' || coalesce(transaction_id::text, '') from public.bank_transactions where id = 'cc000000-0000-4000-8000-000000000305'), 'pendente_importacao|', 'bank tx da Ana volta a pendente');

-- Ana linka a propria bank tx na transacao familiar do Carlos; o Carlos nao apaga.
set local role authenticated;
set local request.jwt.claim.sub = 'cc000000-0000-4000-8000-0000000000a1';
insert into tap_out(line) select lives_ok($$ update public.transactions set bank_transaction_id = 'cc000000-0000-4000-8000-000000000305' where id = 'cc000000-0000-4000-8000-000000000402' $$, 'Ana linka a propria bank tx na transacao do Carlos');
reset role;
reset request.jwt.claim.sub;
insert into tap_out(line) select is((select status || '|' || coalesce(transaction_id::text, '') from public.bank_transactions where id = 'cc000000-0000-4000-8000-000000000305'), 'reconciliada|cc000000-0000-4000-8000-000000000402', 'bank tx da Ana linkada na transacao do Carlos');
set local role authenticated;
set local request.jwt.claim.sub = 'cc000000-0000-4000-8000-0000000000b2';
insert into tap_out(line) select throws_ok($$ delete from public.transactions where id = 'cc000000-0000-4000-8000-000000000402' $$, '42501', null, 'Carlos nao apaga transacao com bank tx da Ana');
reset role;
reset request.jwt.claim.sub;
insert into tap_out(line) select is((select status || '|' || coalesce(transaction_id::text, '') from public.bank_transactions where id = 'cc000000-0000-4000-8000-000000000305'), 'reconciliada|cc000000-0000-4000-8000-000000000402', 'bank tx da Ana intacta apos delete recusado');
set local role authenticated;
set local request.jwt.claim.sub = 'cc000000-0000-4000-8000-0000000000a1';
insert into tap_out(line) select lives_ok($$ update public.transactions set bank_transaction_id = null where id = 'cc000000-0000-4000-8000-000000000402' $$, 'Ana deslinka a propria bank tx da transacao do Carlos');
reset role;
reset request.jwt.claim.sub;
insert into tap_out(line) select is((select status || '|' || coalesce(transaction_id::text, '') from public.bank_transactions where id = 'cc000000-0000-4000-8000-000000000305'), 'pendente_importacao|', 'bank tx da Ana volta a pendente apos deslinkar');

-- Carlos edita a descricao de uma transacao familiar com o vinculo da Ana inalterado.
set local role authenticated;
set local request.jwt.claim.sub = 'cc000000-0000-4000-8000-0000000000b2';
insert into tap_out(line) select lives_ok($$ update public.transactions set descricao = 'Editada por Carlos' where id = 'cc000000-0000-4000-8000-000000000403' $$, 'Carlos edita descricao sem mudar o vinculo');
reset role;
reset request.jwt.claim.sub;
insert into tap_out(line) select is((select descricao || '|' || coalesce(bank_transaction_id::text, '') from public.transactions where id = 'cc000000-0000-4000-8000-000000000403'), 'Editada por Carlos|cc000000-0000-4000-8000-000000000301', 'descricao editada e vinculo preservado');

-- Ana apaga a propria transacao familiar com o proprio vinculo.
set local role authenticated;
set local request.jwt.claim.sub = 'cc000000-0000-4000-8000-0000000000a1';
insert into tap_out(line) select lives_ok($$ delete from public.transactions where id = 'cc000000-0000-4000-8000-000000000403' $$, 'Ana apaga a propria transacao com o proprio vinculo');
reset role;
reset request.jwt.claim.sub;
insert into tap_out(line) select is((select status || '|' || coalesce(transaction_id::text, '') from public.bank_transactions where id = 'cc000000-0000-4000-8000-000000000301'), 'pendente_importacao|', 'bank tx da Ana volta a pendente apos delete');

-- Carlos apaga a propria transacao familiar com o proprio vinculo.
set local role authenticated;
set local request.jwt.claim.sub = 'cc000000-0000-4000-8000-0000000000b2';
insert into tap_out(line) select lives_ok($$ delete from public.transactions where id = 'cc000000-0000-4000-8000-000000000407' $$, 'Carlos apaga a propria transacao com o proprio vinculo');
reset role;
reset request.jwt.claim.sub;
insert into tap_out(line) select is((select status || '|' || coalesce(transaction_id::text, '') from public.bank_transactions where id = 'cc000000-0000-4000-8000-000000000308'), 'pendente_importacao|', 'bank tx do Carlos volta a pendente apos delete');

insert into tap_out(line) select is((select tgenabled from pg_trigger where tgname = 'tg_guard_transaction_bank_link'), 'O', 'guard habilitado');

insert into tap_out(line) select * from finish();

select string_agg(line, E'\n' order by seq) as tap from tap_out;
rollback;
