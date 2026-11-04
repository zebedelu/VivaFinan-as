begin;
set local search_path = public, extensions;

create temp table tap_out(seq serial, line text);
grant all on tap_out to public;
grant all on sequence tap_out_seq_seq to public;

insert into tap_out(line) select plan(53);

insert into tap_out(line) select is((select count(*) from public.families where is_demo = true), 1::bigint, 'existe uma familia demo');
insert into tap_out(line) select is((select count(*) from public.profiles where family_id = 'eeeeeeee-0000-4000-8000-000000000001'), 3::bigint, 'familia demo tem 3 perfis');
insert into tap_out(line) select is((select count(*) from public.profiles where family_id = 'eeeeeeee-0000-4000-8000-000000000001' and papel = 'admin'), 1::bigint, 'familia demo tem 1 admin');
insert into tap_out(line) select is((select count(*) from public.categories where family_id = 'eeeeeeee-0000-4000-8000-000000000001' and personalizada = false), 12::bigint, 'familia demo tem 12 categorias padrao');
insert into tap_out(line) select is((select count(*) from public.categories where family_id = 'eeeeeeee-0000-4000-8000-000000000001' and personalizada = false and tipo = 'despesa'), 8::bigint, '8 categorias de despesa');
insert into tap_out(line) select is((select count(*) from public.categories where family_id = 'eeeeeeee-0000-4000-8000-000000000001' and personalizada = false and tipo = 'receita'), 4::bigint, '4 categorias de receita');
insert into tap_out(line) select is((select count(*) from public.recurring_rules where family_id = 'eeeeeeee-0000-4000-8000-000000000001'), 6::bigint, 'familia demo tem 6 regras');
insert into tap_out(line) select is((select count(distinct date_trunc('month', data)) from public.transactions where family_id = 'eeeeeeee-0000-4000-8000-000000000001'), 6::bigint, 'historico cobre 6 meses');
insert into tap_out(line) select is((select count(*) from public.transactions where family_id = 'eeeeeeee-0000-4000-8000-000000000001' and descricao = 'Aluguel' and valor = 1800), 6::bigint, '6 alugueis de 1800');
insert into tap_out(line) select is((select count(*) from public.transactions where family_id = 'eeeeeeee-0000-4000-8000-000000000001' and descricao = 'Salário Ana' and valor = 6500), 6::bigint, '6 salarios de Ana');
insert into tap_out(line) select is((select count(*) from public.transactions where family_id = 'eeeeeeee-0000-4000-8000-000000000001' and descricao = 'Salário Carlos' and valor = 5200), 6::bigint, '6 salarios de Carlos');
insert into tap_out(line) select is((select max(data) from public.transactions where family_id = 'eeeeeeee-0000-4000-8000-000000000001') <= (now() at time zone 'America/Sao_Paulo')::date, true, 'nenhum lancamento no futuro');
insert into tap_out(line) select is((select count(*) from public.goals where family_id = 'eeeeeeee-0000-4000-8000-000000000001'), 3::bigint, 'familia demo tem 3 metas');
insert into tap_out(line) select is((select sum(c.valor) from public.goal_contributions c join public.goals g on g.id = c.goal_id where g.family_id = 'eeeeeeee-0000-4000-8000-000000000001' and g.member_id is null), 4000::numeric, 'meta familiar soma 4000');
insert into tap_out(line) select is((select count(*) from public.goals where family_id = 'eeeeeeee-0000-4000-8000-000000000001' and status <> 'em_andamento'), 0::bigint, 'metas demo seguem em andamento');
insert into tap_out(line) select is((select count(*) from public.goals where family_id = 'eeeeeeee-0000-4000-8000-000000000001' and member_id is null and criado_por = 'eeeeeeee-0000-4000-8000-0000000000a1'), 1::bigint, 'meta familiar criada por Ana');
insert into tap_out(line) select is((select count(*) from public.ai_suggestions where family_id = 'eeeeeeee-0000-4000-8000-000000000001'), 4::bigint, '4 sugestoes de IA');
insert into tap_out(line) select is((select count(*) from public.ai_suggestions where family_id = 'eeeeeeee-0000-4000-8000-000000000001' and (btrim(o_que) = '' or btrim(por_que) = '' or btrim(quanto) = '')), 0::bigint, 'sugestoes com o que/por que/quanto');
insert into tap_out(line) select ok(exists(select 1 from public.ai_suggestions where family_id = 'eeeeeeee-0000-4000-8000-000000000001' and quanto ilike '%não é possível estimar%'), 'ha sugestao sem estimativa inventada');
insert into tap_out(line) select is((select count(*) from public.bank_connections where id = 'eeeeeeee-0000-4000-8000-000000000301' and is_demo_sync = true), 1::bigint, '1 conexao bancaria demo');
insert into tap_out(line) select is((select count(*) from public.bank_accounts where connection_id = 'eeeeeeee-0000-4000-8000-000000000301'), 1::bigint, '1 conta bancaria demo');
insert into tap_out(line) select is((select count(*) from public.bank_transactions where bank_connection_id = 'eeeeeeee-0000-4000-8000-000000000301'), 8::bigint, '8 transacoes bancarias demo');
insert into tap_out(line) select is((select count(distinct status) from public.bank_transactions where bank_connection_id = 'eeeeeeee-0000-4000-8000-000000000301'), 4::bigint, '4 status bancarios representados');
insert into tap_out(line) select is((select count(*) from public.bank_transactions where bank_connection_id = 'eeeeeeee-0000-4000-8000-000000000301' and is_demo_sync = true), 8::bigint, 'todas as transacoes demo tem is_demo_sync');
insert into tap_out(line) select is((select count(*) from public.bank_transactions where bank_connection_id = 'eeeeeeee-0000-4000-8000-000000000301' and status in ('importada', 'reconciliada') and transaction_id is not null), 4::bigint, 'importadas e reconciliadas tem vinculo');
insert into tap_out(line) select is((select count(*) from public.transactions where family_id = 'eeeeeeee-0000-4000-8000-000000000001' and origem = 'pluggy' and bank_transaction_id is null), 0::bigint, 'todo pluggy tem bank_transaction_id');
insert into tap_out(line) select is((select count(*) from public.bank_transactions bt join public.bank_connections bc on bc.id = bt.bank_connection_id join public.transactions t on t.id = bt.transaction_id where bt.bank_connection_id = 'eeeeeeee-0000-4000-8000-000000000301' and bt.status = 'reconciliada' and t.member_id <> bc.member_id), 0::bigint, 'reconciliadas pertencem ao dono da conexao');
insert into tap_out(line) select is((select count(*) from auth.users where id in ('eeeeeeee-0000-4000-8000-0000000000a1','eeeeeeee-0000-4000-8000-0000000000b2','eeeeeeee-0000-4000-8000-0000000000c3')), 3::bigint, '3 usuarios Auth demo');
insert into tap_out(line) select is((select count(*) from auth.identities where user_id in ('eeeeeeee-0000-4000-8000-0000000000a1','eeeeeeee-0000-4000-8000-0000000000b2','eeeeeeee-0000-4000-8000-0000000000c3')), 3::bigint, '3 identidades email demo');
insert into tap_out(line) select is((select count(*) from auth.users where id in ('eeeeeeee-0000-4000-8000-0000000000a1','eeeeeeee-0000-4000-8000-0000000000b2','eeeeeeee-0000-4000-8000-0000000000c3') and encrypted_password like '$2%' and encrypted_password <> 'Demo@2026!'), 3::bigint, 'senhas demo em bcrypt');
insert into tap_out(line) select is_empty($$ select column_name from information_schema.columns where table_schema = 'public' and table_name like 'bank_%' and column_name ~* '(password|senha|token|secret|credential|credencial)' $$, 'nenhuma coluna de credencial bancaria');
insert into tap_out(line) select is((select count(*) from public.transactions where family_id = 'eeeeeeee-0000-4000-8000-000000000001' and data > (now() at time zone 'America/Sao_Paulo')::date), 0::bigint, 'nenhum lancamento futuro');
insert into tap_out(line) select is((select count(*) from public.recurring_occurrences o join public.recurring_rules r on r.id = o.rule_id where r.family_id = 'eeeeeeee-0000-4000-8000-000000000001' and o.status = 'pendente' and o.mes_referencia = date_trunc('month', (now() at time zone 'America/Sao_Paulo')::date)::date), 3::bigint, '3 ocorrencias pendentes no mes corrente');

insert into tap_out(line) select is((select count(*) from public.ai_messages where family_id = 'eeeeeeee-0000-4000-8000-000000000001'), 4::bigint, '4 mensagens de IA');
insert into tap_out(line) select is((select count(*) from public.ai_messages where family_id = 'eeeeeeee-0000-4000-8000-000000000001' and member_id is null), 2::bigint, '2 mensagens de familia');
insert into tap_out(line) select is((select count(*) from public.ai_messages where family_id = 'eeeeeeee-0000-4000-8000-000000000001' and member_id is not null), 2::bigint, '2 mensagens pessoais');
insert into tap_out(line) select is((select count(*) from public.ai_suggestions where family_id = 'eeeeeeee-0000-4000-8000-000000000001' and member_id is null), 2::bigint, '2 sugestoes de familia');
insert into tap_out(line) select is((select count(*) from public.ai_suggestions where family_id = 'eeeeeeee-0000-4000-8000-000000000001' and member_id is not null), 2::bigint, '2 sugestoes pessoais');
insert into tap_out(line) select is((select count(*) from public.recurring_rules where family_id = 'eeeeeeee-0000-4000-8000-000000000001' and (
  (descricao = 'Aluguel' and valor = 1800 and dia_vencimento = 5 and escopo = 'familia' and tipo = 'despesa') or
  (descricao = 'Salário Ana' and valor = 6500 and dia_vencimento = 5 and escopo = 'pessoal' and tipo = 'receita') or
  (descricao = 'Salário Carlos' and valor = 5200 and dia_vencimento = 5 and escopo = 'pessoal' and tipo = 'receita') or
  (descricao = 'Streaming' and valor = 59.90 and dia_vencimento = 15 and escopo = 'familia' and tipo = 'despesa') or
  (descricao = 'Música' and valor = 21.90 and dia_vencimento = 20 and escopo = 'pessoal' and tipo = 'despesa') or
  (descricao = 'Academia' and valor = 129.90 and dia_vencimento = 10 and escopo = 'pessoal' and tipo = 'despesa')
)), 6::bigint, '6 regras com valores, dias e escopos');
insert into tap_out(line) select is((select count(*) from public.goals where family_id = 'eeeeeeee-0000-4000-8000-000000000001' and (
  (titulo = 'Viagem em família' and valor_alvo = 12000 and member_id is null) or
  (titulo = 'Curso de fotografia' and valor_alvo = 2500 and member_id = 'eeeeeeee-0000-4000-8000-0000000000a1') or
  (titulo = 'Notebook novo' and valor_alvo = 5000 and member_id = 'eeeeeeee-0000-4000-8000-0000000000b2')
)), 3::bigint, '3 metas com alvos e donos');
insert into tap_out(line) select is((select count(*) from public.goal_contributions c join public.goals g on g.id = c.goal_id where g.family_id = 'eeeeeeee-0000-4000-8000-000000000001' and (
  (g.titulo = 'Viagem em família' and c.member_id = 'eeeeeeee-0000-4000-8000-0000000000a1' and c.valor = 2000) or
  (g.titulo = 'Viagem em família' and c.member_id = 'eeeeeeee-0000-4000-8000-0000000000b2' and c.valor = 1500) or
  (g.titulo = 'Viagem em família' and c.member_id = 'eeeeeeee-0000-4000-8000-0000000000c3' and c.valor = 500) or
  (g.titulo = 'Curso de fotografia' and c.member_id = 'eeeeeeee-0000-4000-8000-0000000000a1' and c.valor = 800) or
  (g.titulo = 'Notebook novo' and c.member_id = 'eeeeeeee-0000-4000-8000-0000000000b2' and c.valor = 1200)
)), 5::bigint, '5 contribuicoes com valores e membros');
insert into tap_out(line) select is((select count(*) from public.categories where family_id = 'eeeeeeee-0000-4000-8000-000000000001' and personalizada = false and (
  (tipo = 'despesa' and nome in ('Alimentação','Moradia','Transporte','Saúde','Educação','Lazer','Assinaturas','Outros')) or
  (tipo = 'receita' and nome in ('Salário','Freelance','Investimentos','Outros'))
)), 12::bigint, '12 categorias com nomes e tipos');
insert into tap_out(line) select is((select min(date_trunc('month', data))::date from public.transactions where family_id = 'eeeeeeee-0000-4000-8000-000000000001'), (date_trunc('month', (now() at time zone 'America/Sao_Paulo')::date) - interval '5 months')::date, 'primeiro mes da janela');
insert into tap_out(line) select is((select max(date_trunc('month', data))::date from public.transactions where family_id = 'eeeeeeee-0000-4000-8000-000000000001'), date_trunc('month', (now() at time zone 'America/Sao_Paulo')::date)::date, 'ultimo mes da janela');
insert into tap_out(line) select is((select count(*) from public.transactions where family_id = 'eeeeeeee-0000-4000-8000-000000000001'), 91::bigint, '91 lancamentos');
insert into tap_out(line) select is((select account_name || '|' || account_type || '|' || account_number_masked || '|' || (ultima_sync_em is not null)::text from public.bank_connections where id = 'eeeeeeee-0000-4000-8000-000000000301'), 'Conta Corrente|corrente|**** 4321|true', 'campos da conexao demo');
insert into tap_out(line) select is((select nome || '|' || tipo || '|' || currency || '|' || balance from public.bank_accounts where connection_id = 'eeeeeeee-0000-4000-8000-000000000301'), 'Conta Corrente|corrente|BRL|4820.35', 'campos da conta demo');
insert into tap_out(line) select is((select string_agg(status || ':' || n, ',' order by status) from (select status, count(*) n from public.bank_transactions where bank_connection_id = 'eeeeeeee-0000-4000-8000-000000000301' group by status) s), 'ignorada:2,importada:2,pendente_importacao:2,reconciliada:2', '2 transacoes por status');
insert into tap_out(line) select is((select count(*) from public.bank_transactions bt join public.transactions t on t.id = bt.transaction_id where bt.bank_connection_id = 'eeeeeeee-0000-4000-8000-000000000301' and t.bank_transaction_id = bt.id), 4::bigint, '4 vinculos bidirecionais');
insert into tap_out(line) select is((select count(*) from public.bank_transactions bt join public.transactions t on t.id = bt.transaction_id where bt.bank_connection_id = 'eeeeeeee-0000-4000-8000-000000000301' and t.bank_transaction_id is distinct from bt.id), 0::bigint, 'nenhum vinculo divergente');
insert into tap_out(line) select is((select count(*) from auth.users where id in ('eeeeeeee-0000-4000-8000-0000000000a1','eeeeeeee-0000-4000-8000-0000000000b2','eeeeeeee-0000-4000-8000-0000000000c3') and email in ('ana@demo.vivafinancas.app','carlos@demo.vivafinancas.app','lucas@demo.vivafinancas.app')), 3::bigint, '3 e-mails demo');
insert into tap_out(line) select is((select count(*) from auth.identities where user_id in ('eeeeeeee-0000-4000-8000-0000000000a1','eeeeeeee-0000-4000-8000-0000000000b2','eeeeeeee-0000-4000-8000-0000000000c3') and provider = 'email' and provider_id = user_id::text), 3::bigint, '3 identidades email');
insert into tap_out(line) select is((select count(*) from auth.users where id in ('eeeeeeee-0000-4000-8000-0000000000a1','eeeeeeee-0000-4000-8000-0000000000b2','eeeeeeee-0000-4000-8000-0000000000c3') and crypt('Demo@2026!', encrypted_password) = encrypted_password), 3::bigint, 'senha demo confere no bcrypt');

insert into tap_out(line) select * from finish();

select string_agg(line, E'\n' order by seq) as tap from tap_out;
rollback;
