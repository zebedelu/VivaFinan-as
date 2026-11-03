begin;
set local search_path = public, extensions;

create temp table tap_out(seq serial, line text);
grant all on tap_out to public;
grant all on sequence tap_out_seq_seq to public;

insert into auth.users (id, email) values
  ('44000000-0000-4000-8000-0000000000a1', 'ana.44000000@test.local'),
  ('44000000-0000-4000-8000-0000000000b2', 'carlos.44000000@test.local'),
  ('44000000-0000-4000-8000-0000000000c3', 'lucas.44000000@test.local'),
  ('44000000-0000-4000-8000-0000000000d4', 'externo.44000000@test.local');

insert into public.families (id, nome, criado_por) values
  ('44000000-0000-4000-8000-000000000001', 'Familia Teste A 04', '44000000-0000-4000-8000-0000000000a1'),
  ('44000000-0000-4000-8000-000000000002', 'Familia Teste B 04', '44000000-0000-4000-8000-0000000000d4');

insert into public.profiles (id, family_id, nome, papel, status) values
  ('44000000-0000-4000-8000-0000000000a1', '44000000-0000-4000-8000-000000000001', 'Ana', 'admin', 'ativo'),
  ('44000000-0000-4000-8000-0000000000b2', '44000000-0000-4000-8000-000000000001', 'Carlos', 'membro', 'ativo'),
  ('44000000-0000-4000-8000-0000000000c3', '44000000-0000-4000-8000-000000000001', 'Lucas', 'membro', 'ativo'),
  ('44000000-0000-4000-8000-0000000000d4', '44000000-0000-4000-8000-000000000002', 'Externo', 'admin', 'ativo');

insert into public.categories (id, family_id, nome, tipo, criado_por) values
  ('44000000-0000-4000-8000-0000000000c1', '44000000-0000-4000-8000-000000000001', 'Categoria Despesa 04', 'despesa', '44000000-0000-4000-8000-0000000000a1'),
  ('44000000-0000-4000-8000-0000000000c2', '44000000-0000-4000-8000-000000000001', 'Categoria Receita 04', 'receita', '44000000-0000-4000-8000-0000000000a1');

insert into public.transactions (id, family_id, member_id, tipo, escopo, valor, category_id, data, criado_por) values
  ('44000000-0000-4000-8000-0000000000d1', '44000000-0000-4000-8000-000000000001', '44000000-0000-4000-8000-0000000000a1', 'despesa', 'pessoal', 50, '44000000-0000-4000-8000-0000000000c1', '2026-11-10', '44000000-0000-4000-8000-0000000000a1');

insert into public.bank_connections (id, family_id, member_id, pluggy_connection_id, institution_name, status) values
  ('44000000-0000-4000-8000-0000000000e1', '44000000-0000-4000-8000-000000000001', '44000000-0000-4000-8000-0000000000a1', 'conn-44000000-a', 'Banco Teste A', 'ativa'),
  ('44000000-0000-4000-8000-0000000000e2', '44000000-0000-4000-8000-000000000001', '44000000-0000-4000-8000-0000000000b2', 'conn-44000000-c', 'Banco Teste C', 'ativa');

insert into public.bank_accounts (id, connection_id, pluggy_account_id, nome, tipo, balance) values
  ('44000000-0000-4000-8000-0000000000f1', '44000000-0000-4000-8000-0000000000e1', 'acc-44000000-a', 'Conta A', 'corrente', 1000),
  ('44000000-0000-4000-8000-0000000000f2', '44000000-0000-4000-8000-0000000000e2', 'acc-44000000-c', 'Conta C', 'corrente', 500);

insert into public.bank_transactions (id, bank_connection_id, bank_account_id, pluggy_transaction_id, data, valor, descricao, tipo, status) values
  ('44000000-0000-4000-8000-0000000000f3', '44000000-0000-4000-8000-0000000000e1', '44000000-0000-4000-8000-0000000000f1', 'tx-44000000-a', '2026-11-10', 100, 'Transacao Teste A', 'debito', 'pendente_importacao');

insert into tap_out(line) select plan(13);

insert into tap_out(line) select has_table('public', 'bank_connections', 'tabela bank_connections existe');
insert into tap_out(line) select has_table('public', 'bank_accounts', 'tabela bank_accounts existe');
insert into tap_out(line) select has_table('public', 'bank_transactions', 'tabela bank_transactions existe');

insert into tap_out(line) select throws_ok($$
  insert into public.bank_connections (family_id, member_id, pluggy_connection_id, institution_name, status)
  values ('44000000-0000-4000-8000-000000000001', '44000000-0000-4000-8000-0000000000a1', 'conn-invalid-44000000-1', 'Banco Invalido 04', 'conectada')
  $$, '23514', null, 'status de conexao invalido e recusado');

insert into tap_out(line) select throws_ok($$
  insert into public.bank_transactions (bank_connection_id, bank_account_id, pluggy_transaction_id, data, valor, descricao, tipo, status)
  values ('44000000-0000-4000-8000-0000000000e1', '44000000-0000-4000-8000-0000000000f1', 'tx-invalid-44000000-1', '2026-11-10', 10, 'Tx invalida 1', 'debito', 'pendente')
  $$, '23514', null, 'status bancario invalido e recusado');

insert into tap_out(line) select throws_ok($$
  insert into public.bank_transactions (bank_connection_id, bank_account_id, pluggy_transaction_id, data, valor, descricao, tipo, status, transaction_id)
  values ('44000000-0000-4000-8000-0000000000e1', '44000000-0000-4000-8000-0000000000f1', 'tx-invalid-44000000-2', '2026-11-10', 10, 'Tx invalida 2', 'debito', 'importada', null)
  $$, '23514', null, 'importada exige transaction_id');

insert into tap_out(line) select throws_ok($$
  insert into public.bank_transactions (bank_connection_id, bank_account_id, pluggy_transaction_id, data, valor, descricao, tipo, status, transaction_id)
  values ('44000000-0000-4000-8000-0000000000e1', '44000000-0000-4000-8000-0000000000f1', 'tx-invalid-44000000-3', '2026-11-10', 10, 'Tx invalida 3', 'debito', 'pendente_importacao', '44000000-0000-4000-8000-0000000000d1')
  $$, '23514', null, 'pendente_importacao nao aceita transaction_id');

insert into tap_out(line) select throws_ok($$
  insert into public.bank_accounts (connection_id, pluggy_account_id, nome, tipo)
  values ('44000000-0000-4000-8000-0000000000e1', 'acc-invalid-44000000-1', 'Conta Invalida 04', 'investimento')
  $$, '23514', null, 'tipo de conta invalido e recusado');

insert into tap_out(line) select throws_ok($$
  insert into public.bank_transactions (bank_connection_id, bank_account_id, pluggy_transaction_id, data, valor, descricao, tipo, status) values
    ('44000000-0000-4000-8000-0000000000e1', '44000000-0000-4000-8000-0000000000f1', 'tx-dup-44000000', '2026-11-10', 10, 'Tx dup 1', 'debito', 'pendente_importacao'),
    ('44000000-0000-4000-8000-0000000000e1', '44000000-0000-4000-8000-0000000000f1', 'tx-dup-44000000', '2026-11-11', 10, 'Tx dup 2', 'debito', 'pendente_importacao')
  $$, '23505', null, 'transacao bancaria duplicada e recusada');

insert into tap_out(line) select throws_ok($$
  insert into public.bank_transactions (bank_connection_id, bank_account_id, pluggy_transaction_id, data, valor, descricao, tipo, status)
  values ('44000000-0000-4000-8000-0000000000e1', '44000000-0000-4000-8000-0000000000f2', 'tx-cross-44000000', '2026-11-10', 10, 'Tx cross', 'debito', 'pendente_importacao')
  $$, '23503', null, 'conta de outra conexao e recusada');

insert into tap_out(line) select is_empty($$
  select column_name from information_schema.columns
  where table_schema = 'public'
    and table_name like 'bank_%'
    and column_name ~* '(password|senha|token|secret|credential|credencial)'
  $$, 'nenhuma coluna de credencial nas tabelas bancarias');

insert into tap_out(line) select is((
  select count(*) from information_schema.columns
  where table_schema = 'public'
    and table_name like 'bank_%'
    and column_name = 'pluggy_connection_id'
  ), 1::bigint, 'pluggy_connection_id e identificador opaco, nao credencial');

insert into tap_out(line) select ok(exists(
  select 1 from pg_constraint c
  join pg_class t on t.oid = c.conrelid
  join pg_namespace n on n.oid = t.relnamespace
  where n.nspname = 'public'
    and t.relname = 'transactions'
    and c.conname = 'transactions_bank_transaction_fkey'
    and c.contype = 'f'
), 'FK de transactions para bank_transactions');

insert into tap_out(line) select * from finish();

select string_agg(line, E'\n' order by seq) as tap from tap_out;
rollback;
