-- Fatia 1 - Task 13: conexao bancaria simulada da Familia Demo.

do $$
declare
    v_family uuid := 'eeeeeeee-0000-4000-8000-000000000001';
    v_ana uuid := 'eeeeeeee-0000-4000-8000-0000000000a1';
    v_as_of date := (now() at time zone 'America/Sao_Paulo')::date;
    v_cat uuid;
begin
    select id into v_cat from public.categories
    where family_id = v_family and tipo = 'despesa' and nome = 'Alimentação';

    insert into public.bank_connections (
        id, family_id, member_id, pluggy_connection_id, institution_name,
        account_name, account_type, account_number_masked, status, ultima_sync_em, is_demo_sync
    ) values (
        'eeeeeeee-0000-4000-8000-000000000301', v_family, v_ana, 'demo-connection-1', 'Banco Demo',
        'Conta Corrente', 'corrente', '**** 4321', 'ativa', now(), true
    );

    insert into public.bank_accounts (id, connection_id, pluggy_account_id, nome, tipo, balance) values
        ('eeeeeeee-0000-4000-8000-000000000302', 'eeeeeeee-0000-4000-8000-000000000301', 'demo-account-1', 'Conta Corrente', 'corrente', 4820.35);

    insert into public.bank_transactions (
        id, bank_connection_id, bank_account_id, pluggy_transaction_id, data, valor, descricao, tipo, status, is_demo_sync
    ) values
        ('eeeeeeee-0000-4000-8000-000000000303', 'eeeeeeee-0000-4000-8000-000000000301', 'eeeeeeee-0000-4000-8000-000000000302', 'demo-tx-1', v_as_of, 120.00, 'Mercado Demo', 'debito', 'pendente_importacao', true),
        ('eeeeeeee-0000-4000-8000-000000000304', 'eeeeeeee-0000-4000-8000-000000000301', 'eeeeeeee-0000-4000-8000-000000000302', 'demo-tx-2', v_as_of, 80.00, 'Farmacia Demo', 'debito', 'pendente_importacao', true),
        ('eeeeeeee-0000-4000-8000-000000000305', 'eeeeeeee-0000-4000-8000-000000000301', 'eeeeeeee-0000-4000-8000-000000000302', 'demo-tx-3', v_as_of, 45.00, 'Assinatura Demo', 'debito', 'ignorada', true),
        ('eeeeeeee-0000-4000-8000-000000000306', 'eeeeeeee-0000-4000-8000-000000000301', 'eeeeeeee-0000-4000-8000-000000000302', 'demo-tx-4', v_as_of, 60.00, 'PIX Demo', 'credito', 'ignorada', true),
        ('eeeeeeee-0000-4000-8000-000000000307', 'eeeeeeee-0000-4000-8000-000000000301', 'eeeeeeee-0000-4000-8000-000000000302', 'demo-tx-5', v_as_of, 100.00, 'Importada 1', 'debito', 'pendente_importacao', true),
        ('eeeeeeee-0000-4000-8000-000000000308', 'eeeeeeee-0000-4000-8000-000000000301', 'eeeeeeee-0000-4000-8000-000000000302', 'demo-tx-6', v_as_of, 120.00, 'Importada 2', 'debito', 'pendente_importacao', true),
        ('eeeeeeee-0000-4000-8000-000000000309', 'eeeeeeee-0000-4000-8000-000000000301', 'eeeeeeee-0000-4000-8000-000000000302', 'demo-tx-7', v_as_of, 130.00, 'Reconciliada 1', 'debito', 'pendente_importacao', true),
        ('eeeeeeee-0000-4000-8000-000000000310', 'eeeeeeee-0000-4000-8000-000000000301', 'eeeeeeee-0000-4000-8000-000000000302', 'demo-tx-8', v_as_of, 140.00, 'Reconciliada 2', 'debito', 'pendente_importacao', true);

    insert into public.transactions (
        id, family_id, member_id, tipo, escopo, valor, descricao, category_id, data, criado_por, origem, bank_transaction_id
    ) values
        ('eeeeeeee-0000-4000-8000-000000000401', v_family, v_ana, 'despesa', 'pessoal', 100.00, 'Importada 1', v_cat, v_as_of, v_ana, 'pluggy', 'eeeeeeee-0000-4000-8000-000000000307'),
        ('eeeeeeee-0000-4000-8000-000000000402', v_family, v_ana, 'despesa', 'pessoal', 120.00, 'Importada 2', v_cat, v_as_of, v_ana, 'pluggy', 'eeeeeeee-0000-4000-8000-000000000308'),
        ('eeeeeeee-0000-4000-8000-000000000403', v_family, v_ana, 'despesa', 'pessoal', 130.00, 'Reconciliada 1', v_cat, v_as_of, v_ana, 'manual', 'eeeeeeee-0000-4000-8000-000000000309'),
        ('eeeeeeee-0000-4000-8000-000000000404', v_family, v_ana, 'despesa', 'pessoal', 140.00, 'Reconciliada 2', v_cat, v_as_of, v_ana, 'manual', 'eeeeeeee-0000-4000-8000-000000000310');
end;
$$;
