-- Etapas 4-5 do plano escolar: consentimento e sync Pluggy v2.
-- Metadados do item (consentimento/execucao) e cartao de credito como tipo.
-- Idempotente: reaplicar sobre um banco que ja recebeu esta migration e seguro.

alter table public.bank_connections
    add column if not exists consent_expires_at timestamptz,
    add column if not exists execution_status text,
    add column if not exists last_updated_at timestamptz;

alter table public.bank_connections
    drop constraint if exists bank_connections_account_type_check;
alter table public.bank_connections
    add constraint bank_connections_account_type_check
    check (account_type is null or account_type in ('corrente', 'poupanca', 'cartao'));

alter table public.bank_accounts
    drop constraint if exists bank_accounts_tipo_check;
alter table public.bank_accounts
    add constraint bank_accounts_tipo_check
    check (tipo in ('corrente', 'poupanca', 'cartao'));
