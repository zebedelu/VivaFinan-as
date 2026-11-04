begin;
set local search_path = public, extensions;

create temp table tap_out(seq serial, line text);
grant all on tap_out to public;
grant all on sequence tap_out_seq_seq to public;

insert into auth.users (id, email) values
  ('66000001-0000-4000-8000-0000000000a1', 'ana.links.66000000@test.local'),
  ('66000001-0000-4000-8000-0000000000d4', 'externo.links.66000000@test.local');

insert into public.families (id, nome, criado_por) values
  ('66000001-0000-4000-8000-000000000001', 'Familia Links 06', '66000001-0000-4000-8000-0000000000a1');

insert into public.profiles (id, family_id, nome, papel, status) values
  ('66000001-0000-4000-8000-0000000000a1', '66000001-0000-4000-8000-000000000001', 'Ana', 'admin', 'ativo');

insert into public.recurring_rules (id, family_id, criado_por, tipo, escopo, valor, descricao, category_id, dia_vencimento) values
  ('66000001-0000-4000-8000-0000000000d1', '66000001-0000-4000-8000-000000000001', '66000001-0000-4000-8000-0000000000a1', 'despesa', 'pessoal', 100, 'Regra Links A', (select id from public.categories where family_id = '66000001-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação'), 10),
  ('66000001-0000-4000-8000-0000000000d2', '66000001-0000-4000-8000-000000000001', '66000001-0000-4000-8000-0000000000a1', 'despesa', 'pessoal', 100, 'Regra Links B', (select id from public.categories where family_id = '66000001-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação'), 10);

insert into public.bank_connections (id, family_id, member_id, pluggy_connection_id, institution_name, status) values
  ('66000001-0000-4000-8000-000000000101', '66000001-0000-4000-8000-000000000001', '66000001-0000-4000-8000-0000000000a1', 'conn-links-1', 'Banco Links', 'ativa');

insert into public.bank_accounts (id, connection_id, pluggy_account_id, nome, tipo, balance) values
  ('66000001-0000-4000-8000-000000000201', '66000001-0000-4000-8000-000000000101', 'acc-links-1', 'Conta Links', 'corrente', 1000);

insert into public.bank_transactions (id, bank_connection_id, bank_account_id, pluggy_transaction_id, data, valor, descricao, tipo, status) values
  ('66000001-0000-4000-8000-000000000301', '66000001-0000-4000-8000-000000000101', '66000001-0000-4000-8000-000000000201', 'tx-links-1', '2026-11-10', 10, 'Tx Links 1', 'debito', 'pendente_importacao'),
  ('66000001-0000-4000-8000-000000000302', '66000001-0000-4000-8000-000000000101', '66000001-0000-4000-8000-000000000201', 'tx-links-2', '2026-11-10', 20, 'Tx Links 2', 'debito', 'pendente_importacao'),
  ('66000001-0000-4000-8000-000000000303', '66000001-0000-4000-8000-000000000101', '66000001-0000-4000-8000-000000000201', 'tx-links-3', '2026-11-10', 30, 'Tx Links 3', 'debito', 'pendente_importacao');

insert into tap_out(line) select plan(7);

insert into tap_out(line) select is((select count(*) from public.transactions where bank_transaction_id = '66000001-0000-4000-8000-000000000302'), 0::bigint, 'transacao bancaria nao cria lancamento sozinha');

insert into public.transactions (id, family_id, member_id, tipo, escopo, valor, category_id, data, criado_por, origem, bank_transaction_id) values
  ('66000001-0000-4000-8000-000000000401', '66000001-0000-4000-8000-000000000001', '66000001-0000-4000-8000-0000000000a1', 'despesa', 'pessoal', 10, (select id from public.categories where family_id = '66000001-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação'), '2026-11-10', '66000001-0000-4000-8000-0000000000a1', 'pluggy', '66000001-0000-4000-8000-000000000301');

insert into tap_out(line) select is((select status || '|' || coalesce(transaction_id::text, '') from public.bank_transactions where id = '66000001-0000-4000-8000-000000000301'), 'importada|66000001-0000-4000-8000-000000000401', 'lancamento pluggy marca importada e grava o vinculo');

insert into public.transactions (id, family_id, member_id, tipo, escopo, valor, category_id, data, criado_por, origem, bank_transaction_id) values
  ('66000001-0000-4000-8000-000000000402', '66000001-0000-4000-8000-000000000001', '66000001-0000-4000-8000-0000000000a1', 'despesa', 'pessoal', 20, (select id from public.categories where family_id = '66000001-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação'), '2026-11-10', '66000001-0000-4000-8000-0000000000a1', 'manual', '66000001-0000-4000-8000-000000000302');

insert into tap_out(line) select is((select status || '|' || coalesce(transaction_id::text, '') from public.bank_transactions where id = '66000001-0000-4000-8000-000000000302'), 'reconciliada|66000001-0000-4000-8000-000000000402', 'lancamento manual marca reconciliada e grava o vinculo');

update public.transactions set bank_transaction_id = null where id = '66000001-0000-4000-8000-000000000402';

insert into tap_out(line) select is((select status || '|' || coalesce(transaction_id::text, '') from public.bank_transactions where id = '66000001-0000-4000-8000-000000000302'), 'pendente_importacao|', 'limpar o vinculo devolve a transacao para pendente');

insert into public.transactions (id, family_id, member_id, tipo, escopo, valor, category_id, data, criado_por, origem, bank_transaction_id, recurring_rule_id, mes_referencia) values
  ('66000001-0000-4000-8000-000000000403', '66000001-0000-4000-8000-000000000001', '66000001-0000-4000-8000-0000000000a1', 'despesa', 'pessoal', 30, (select id from public.categories where family_id = '66000001-0000-4000-8000-000000000001' and tipo = 'despesa' and nome = 'Alimentação'), '2026-11-13', '66000001-0000-4000-8000-0000000000a1', 'pluggy', '66000001-0000-4000-8000-000000000303', '66000001-0000-4000-8000-0000000000d1', '2026-11-01');

insert into public.recurring_occurrences (id, rule_id, mes_referencia, status) values
  ('66000001-0000-4000-8000-000000000601', '66000001-0000-4000-8000-0000000000d1', '2026-11-01', 'pendente');

delete from public.transactions where id = '66000001-0000-4000-8000-000000000403';

insert into tap_out(line) select is((select count(*) from public.recurring_occurrences where rule_id = '66000001-0000-4000-8000-0000000000d1' and mes_referencia = '2026-11-01'), 0::bigint, 'apagar o lancamento remove a ocorrencia confirmada');
insert into tap_out(line) select is((select status || '|' || coalesce(transaction_id::text, '') from public.bank_transactions where id = '66000001-0000-4000-8000-000000000303'), 'pendente_importacao|', 'apagar o lancamento devolve a transacao para pendente');

insert into public.recurring_occurrences (id, rule_id, mes_referencia, status) values
  ('66000001-0000-4000-8000-000000000602', '66000001-0000-4000-8000-0000000000d2', '2026-12-01', 'pendente');

update public.recurring_occurrences
set status = 'confirmado', valor_confirmado = 100, confirmado_por = '66000001-0000-4000-8000-0000000000a1', confirmado_em = now()
where id = '66000001-0000-4000-8000-000000000602';

insert into tap_out(line) select is((select count(*) from public.transactions where recurring_rule_id = '66000001-0000-4000-8000-0000000000d2'), 0::bigint, 'confirmar ocorrencia nao cria lancamento');

insert into tap_out(line) select * from finish();

select string_agg(line, E'\n' order by seq) as tap from tap_out;
rollback;
