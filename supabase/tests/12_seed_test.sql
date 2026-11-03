begin;
set local search_path = public, extensions;

create temp table tap_out(seq serial, line text);
grant all on tap_out to public;
grant all on sequence tap_out_seq_seq to public;

insert into tap_out(line) select plan(33);

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

insert into tap_out(line) select * from finish();

select string_agg(line, E'\n' order by seq) as tap from tap_out;
rollback;
