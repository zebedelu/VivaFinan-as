-- Fatia 1 - Task 13: seis meses de historico da Familia Demo.

do $$
declare
    v_family uuid := 'eeeeeeee-0000-4000-8000-000000000001';
    v_ana uuid := 'eeeeeeee-0000-4000-8000-0000000000a1';
    v_carlos uuid := 'eeeeeeee-0000-4000-8000-0000000000b2';
    v_lucas uuid := 'eeeeeeee-0000-4000-8000-0000000000c3';
    v_as_of date := (now() at time zone 'America/Sao_Paulo')::date;
    v_mes_atual date := date_trunc('month', v_as_of)::date;
    v_mes date;
    v_i int;
    v_w int;
    v_cat_moradia uuid;
    v_cat_salario uuid;
    v_cat_assinaturas uuid;
    v_cat_saude uuid;
    v_cat_alimentacao uuid;
    v_cat_transporte uuid;
    v_cat_lazer uuid;
begin
    select id into v_cat_moradia from public.categories where family_id = v_family and tipo = 'despesa' and nome = 'Moradia';
    select id into v_cat_salario from public.categories where family_id = v_family and tipo = 'receita' and nome = 'Salário';
    select id into v_cat_assinaturas from public.categories where family_id = v_family and tipo = 'despesa' and nome = 'Assinaturas';
    select id into v_cat_saude from public.categories where family_id = v_family and tipo = 'despesa' and nome = 'Saúde';
    select id into v_cat_alimentacao from public.categories where family_id = v_family and tipo = 'despesa' and nome = 'Alimentação';
    select id into v_cat_transporte from public.categories where family_id = v_family and tipo = 'despesa' and nome = 'Transporte';
    select id into v_cat_lazer from public.categories where family_id = v_family and tipo = 'despesa' and nome = 'Lazer';

    insert into public.recurring_rules (id, family_id, criado_por, tipo, escopo, valor, descricao, category_id, dia_vencimento) values
        ('eeeeeeee-0000-4000-8000-000000000101', v_family, v_ana, 'despesa', 'familia', 1800.00, 'Aluguel', v_cat_moradia, 5),
        ('eeeeeeee-0000-4000-8000-000000000102', v_family, v_ana, 'receita', 'pessoal', 6500.00, 'Salário Ana', v_cat_salario, 5),
        ('eeeeeeee-0000-4000-8000-000000000103', v_family, v_carlos, 'receita', 'pessoal', 5200.00, 'Salário Carlos', v_cat_salario, 5),
        ('eeeeeeee-0000-4000-8000-000000000104', v_family, v_ana, 'despesa', 'familia', 59.90, 'Streaming', v_cat_assinaturas, 15),
        ('eeeeeeee-0000-4000-8000-000000000105', v_family, v_ana, 'despesa', 'pessoal', 21.90, 'Música', v_cat_assinaturas, 20),
        ('eeeeeeee-0000-4000-8000-000000000106', v_family, v_carlos, 'despesa', 'pessoal', 129.90, 'Academia', v_cat_saude, 10);

    insert into public.goals (id, family_id, member_id, criado_por, titulo, valor_alvo, status) values
        ('eeeeeeee-0000-4000-8000-000000000201', v_family, null, v_ana, 'Viagem em família', 12000.00, 'em_andamento'),
        ('eeeeeeee-0000-4000-8000-000000000202', v_family, v_ana, v_ana, 'Curso de fotografia', 2500.00, 'em_andamento'),
        ('eeeeeeee-0000-4000-8000-000000000203', v_family, v_carlos, v_carlos, 'Notebook novo', 5000.00, 'em_andamento');

    insert into public.goal_contributions (goal_id, member_id, valor, data) values
        ('eeeeeeee-0000-4000-8000-000000000201', v_ana, 2000.00, v_as_of),
        ('eeeeeeee-0000-4000-8000-000000000201', v_carlos, 1500.00, v_as_of),
        ('eeeeeeee-0000-4000-8000-000000000201', v_lucas, 500.00, v_as_of),
        ('eeeeeeee-0000-4000-8000-000000000202', v_ana, 800.00, v_as_of),
        ('eeeeeeee-0000-4000-8000-000000000203', v_carlos, 1200.00, v_as_of);

    for v_i in 0..5 loop
        v_mes := (v_mes_atual - (v_i || ' months')::interval)::date;

        insert into public.transactions (family_id, member_id, tipo, escopo, valor, descricao, category_id, data, pago_por, recurring_rule_id, mes_referencia, criado_por) values
            (v_family, v_ana, 'despesa', 'familia', 1800.00, 'Aluguel', v_cat_moradia, least(v_mes + 4, v_as_of), v_carlos, 'eeeeeeee-0000-4000-8000-000000000101', v_mes, v_ana),
            (v_family, v_ana, 'receita', 'pessoal', 6500.00, 'Salário Ana', v_cat_salario, least(v_mes + 4, v_as_of), null, 'eeeeeeee-0000-4000-8000-000000000102', v_mes, v_ana),
            (v_family, v_carlos, 'receita', 'pessoal', 5200.00, 'Salário Carlos', v_cat_salario, least(v_mes + 4, v_as_of), null, 'eeeeeeee-0000-4000-8000-000000000103', v_mes, v_carlos);

        insert into public.recurring_occurrences (rule_id, mes_referencia, status, valor_confirmado, confirmado_por, confirmado_em) values
            ('eeeeeeee-0000-4000-8000-000000000101', v_mes, 'confirmado', 1800.00, v_ana, now()),
            ('eeeeeeee-0000-4000-8000-000000000102', v_mes, 'confirmado', 6500.00, v_ana, now()),
            ('eeeeeeee-0000-4000-8000-000000000103', v_mes, 'confirmado', 5200.00, v_carlos, now());

        if v_i >= 1 then
            insert into public.transactions (family_id, member_id, tipo, escopo, valor, descricao, category_id, data, pago_por, recurring_rule_id, mes_referencia, criado_por) values
                (v_family, v_ana, 'despesa', 'familia', 59.90, 'Streaming', v_cat_assinaturas, least(v_mes + 14, v_as_of), v_carlos, 'eeeeeeee-0000-4000-8000-000000000104', v_mes, v_ana),
                (v_family, v_ana, 'despesa', 'pessoal', 21.90, 'Música', v_cat_assinaturas, least(v_mes + 19, v_as_of), null, 'eeeeeeee-0000-4000-8000-000000000105', v_mes, v_ana),
                (v_family, v_carlos, 'despesa', 'pessoal', 129.90, 'Academia', v_cat_saude, least(v_mes + 9, v_as_of), null, 'eeeeeeee-0000-4000-8000-000000000106', v_mes, v_carlos);

            insert into public.recurring_occurrences (rule_id, mes_referencia, status, valor_confirmado, confirmado_por, confirmado_em) values
                ('eeeeeeee-0000-4000-8000-000000000104', v_mes, 'confirmado', 59.90, v_ana, now()),
                ('eeeeeeee-0000-4000-8000-000000000105', v_mes, 'confirmado', 21.90, v_ana, now()),
                ('eeeeeeee-0000-4000-8000-000000000106', v_mes, 'confirmado', 129.90, v_carlos, now());
        else
            insert into public.recurring_occurrences (rule_id, mes_referencia, status) values
                ('eeeeeeee-0000-4000-8000-000000000104', v_mes, 'pendente'),
                ('eeeeeeee-0000-4000-8000-000000000105', v_mes, 'pendente'),
                ('eeeeeeee-0000-4000-8000-000000000106', v_mes, 'pendente');
        end if;

        for v_w in 1..4 loop
            insert into public.transactions (family_id, member_id, tipo, escopo, valor, descricao, category_id, data, pago_por, criado_por) values
                (v_family, v_ana, 'despesa', 'familia', 380 + ((v_i * 37 + v_w * 23) % 120), 'Supermercado', v_cat_alimentacao, least(v_mes + (v_w * 7 - 4), v_as_of), v_carlos, v_ana);
        end loop;

        for v_w in 1..3 loop
            insert into public.transactions (family_id, member_id, tipo, escopo, valor, descricao, category_id, data, pago_por, criado_por) values
                (v_family, v_ana, 'despesa', 'familia', 80 + ((v_i * 41 + v_w * 19) % 60), 'Transporte', v_cat_transporte, least(v_mes + (v_w * 7 - 1), v_as_of), v_carlos, v_ana);
        end loop;

        for v_w in 1..2 loop
            insert into public.transactions (family_id, member_id, tipo, escopo, valor, descricao, category_id, data, pago_por, criado_por) values
                (v_family, v_ana, 'despesa', 'familia', 150 + ((v_i * 29 + v_w * 31) % 100), 'Lazer', v_cat_lazer, least(v_mes + (v_w * 14 - 6), v_as_of), v_carlos, v_ana);
        end loop;
    end loop;

    insert into public.ai_suggestions (family_id, member_id, tipo, titulo, o_que, por_que, quanto) values
        (v_family, null, 'economia', 'Revise as assinaturas', 'Revisar as assinaturas de streaming e música', 'Uso baixo nos últimos meses', 'Não é possível estimar'),
        (v_family, null, 'meta', 'Meta da viagem', 'Aumentar a contribuição mensal da meta', 'A meta está em andamento', 'Até R$ 200/mês'),
        (v_family, v_ana, 'categoria', 'Transporte', 'Reduzir transporte por aplicativo', 'Gasto acima da média', 'Até R$ 80/mês'),
        (v_family, v_carlos, 'categoria', 'Academia', 'Revisar a assinatura da academia', 'Gasto recorrente', 'R$ 129,90/mês');

    insert into public.ai_messages (family_id, member_id, role, content) values
        (v_family, null, 'assistant', 'A família está com o orçamento equilibrado.'),
        (v_family, null, 'user', 'Como podemos economizar?'),
        (v_family, v_ana, 'assistant', 'Seu gasto com transporte pode diminuir.'),
        (v_family, v_carlos, 'assistant', 'Sua academia é um gasto recorrente.');
end;
$$;
