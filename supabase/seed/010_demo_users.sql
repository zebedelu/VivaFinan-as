-- Fatia 1 - Task 13: usuarios Auth da Familia Demo.
-- Idempotente: limpa os dados demo antes de recriar.

delete from public.transactions where family_id = 'eeeeeeee-0000-4000-8000-000000000001';
delete from public.bank_transactions where bank_connection_id in (
    select id from public.bank_connections where family_id = 'eeeeeeee-0000-4000-8000-000000000001'
);
delete from public.bank_accounts where connection_id in (
    select id from public.bank_connections where family_id = 'eeeeeeee-0000-4000-8000-000000000001'
);
delete from public.bank_connections where family_id = 'eeeeeeee-0000-4000-8000-000000000001';
delete from public.goal_contributions where goal_id in (
    select id from public.goals where family_id = 'eeeeeeee-0000-4000-8000-000000000001'
);
delete from public.goals where family_id = 'eeeeeeee-0000-4000-8000-000000000001';
delete from public.ai_messages where family_id = 'eeeeeeee-0000-4000-8000-000000000001';
delete from public.ai_suggestions where family_id = 'eeeeeeee-0000-4000-8000-000000000001';
delete from public.recurring_occurrences where rule_id in (
    select id from public.recurring_rules where family_id = 'eeeeeeee-0000-4000-8000-000000000001'
);
delete from public.recurring_rules where family_id = 'eeeeeeee-0000-4000-8000-000000000001';
delete from public.categories where family_id = 'eeeeeeee-0000-4000-8000-000000000001';
delete from public.profiles where family_id = 'eeeeeeee-0000-4000-8000-000000000001';
delete from public.families where id = 'eeeeeeee-0000-4000-8000-000000000001';

delete from auth.sessions where user_id in (
    'eeeeeeee-0000-4000-8000-0000000000a1',
    'eeeeeeee-0000-4000-8000-0000000000b2',
    'eeeeeeee-0000-4000-8000-0000000000c3'
);
delete from auth.refresh_tokens where user_id in (
    'eeeeeeee-0000-4000-8000-0000000000a1',
    'eeeeeeee-0000-4000-8000-0000000000b2',
    'eeeeeeee-0000-4000-8000-0000000000c3'
);
delete from auth.identities where user_id in (
    'eeeeeeee-0000-4000-8000-0000000000a1',
    'eeeeeeee-0000-4000-8000-0000000000b2',
    'eeeeeeee-0000-4000-8000-0000000000c3'
);
delete from auth.users where id in (
    'eeeeeeee-0000-4000-8000-0000000000a1',
    'eeeeeeee-0000-4000-8000-0000000000b2',
    'eeeeeeee-0000-4000-8000-0000000000c3'
);

insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    confirmation_token, email_change, email_change_token_new, recovery_token,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
    ('00000000-0000-0000-0000-000000000000', 'eeeeeeee-0000-4000-8000-0000000000a1',
     'authenticated', 'authenticated', 'ana@demo.vivafinancas.app',
     extensions.crypt('Demo@2026!', extensions.gen_salt('bf')), now(),
     '', '', '', '',
     '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nome', 'Ana'),
     now(), now()),
    ('00000000-0000-0000-0000-000000000000', 'eeeeeeee-0000-4000-8000-0000000000b2',
     'authenticated', 'authenticated', 'carlos@demo.vivafinancas.app',
     extensions.crypt('Demo@2026!', extensions.gen_salt('bf')), now(),
     '', '', '', '',
     '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nome', 'Carlos'),
     now(), now()),
    ('00000000-0000-0000-0000-000000000000', 'eeeeeeee-0000-4000-8000-0000000000c3',
     'authenticated', 'authenticated', 'lucas@demo.vivafinancas.app',
     extensions.crypt('Demo@2026!', extensions.gen_salt('bf')), now(),
     '', '', '', '',
     '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nome', 'Lucas'),
     now(), now());

insert into auth.identities (user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at) values
    ('eeeeeeee-0000-4000-8000-0000000000a1', 'eeeeeeee-0000-4000-8000-0000000000a1',
     jsonb_build_object('sub', 'eeeeeeee-0000-4000-8000-0000000000a1', 'email', 'ana@demo.vivafinancas.app'),
     'email', now(), now(), now()),
    ('eeeeeeee-0000-4000-8000-0000000000b2', 'eeeeeeee-0000-4000-8000-0000000000b2',
     jsonb_build_object('sub', 'eeeeeeee-0000-4000-8000-0000000000b2', 'email', 'carlos@demo.vivafinancas.app'),
     'email', now(), now(), now()),
    ('eeeeeeee-0000-4000-8000-0000000000c3', 'eeeeeeee-0000-4000-8000-0000000000c3',
     jsonb_build_object('sub', 'eeeeeeee-0000-4000-8000-0000000000c3', 'email', 'lucas@demo.vivafinancas.app'),
     'email', now(), now(), now());
