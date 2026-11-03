-- Fatia 1 - Task 5: schema bancario e guarda de credenciais.
-- Nenhuma coluna de senha/token/credencial; so metadados e transacoes.

create table public.bank_connections (
    id uuid primary key default gen_random_uuid(),
    family_id uuid not null references public.families(id) on delete cascade,
    member_id uuid not null,
    pluggy_connection_id text not null unique,
    institution_name text not null,
    institution_logo_url text,
    account_name text,
    account_type text check (account_type is null or account_type in ('corrente', 'poupanca')),
    account_number_masked text,
    status text not null default 'ativa' check (status in ('ativa', 'inativa', 'erro_sincronizacao', 'expirada')),
    consentido_em timestamptz not null default now(),
    ultima_sync_em timestamptz,
    criada_em timestamptz not null default now(),
    atualizada_em timestamptz not null default now(),
    is_demo_sync boolean not null default false,
    constraint bank_connections_member_family_fkey foreign key (member_id, family_id)
        references public.profiles (id, family_id)
);

create index bank_connections_member_status_idx on public.bank_connections (member_id, status);

create table public.bank_accounts (
    id uuid primary key default gen_random_uuid(),
    connection_id uuid not null references public.bank_connections(id) on delete cascade,
    pluggy_account_id text not null,
    nome text not null,
    tipo text not null check (tipo in ('corrente', 'poupanca')),
    currency text not null default 'BRL' check (currency = 'BRL'),
    balance numeric(14,2) not null default 0,
    updated_at timestamptz not null default now(),
    constraint bank_accounts_connection_pluggy_key unique (connection_id, pluggy_account_id),
    constraint bank_accounts_id_connection_key unique (id, connection_id)
);

create index bank_accounts_connection_idx on public.bank_accounts (connection_id);

create table public.bank_transactions (
    id uuid primary key default gen_random_uuid(),
    bank_connection_id uuid not null references public.bank_connections(id) on delete cascade,
    bank_account_id uuid not null,
    pluggy_transaction_id text not null,
    data date not null,
    valor numeric(14,2) not null check (valor > 0),
    descricao text not null,
    tipo text not null check (tipo in ('debito', 'credito')),
    categoria_bancaria text,
    status text not null default 'pendente_importacao' check (
        status in ('pendente_importacao', 'importada', 'ignorada', 'reconciliada')
    ),
    transaction_id uuid unique references public.transactions(id) on delete restrict,
    sincronizado_em timestamptz not null default now(),
    is_demo_sync boolean not null default false,
    constraint bank_transactions_connection_pluggy_key unique (bank_connection_id, pluggy_transaction_id),
    constraint bank_transactions_account_connection_fkey foreign key (bank_account_id, bank_connection_id)
        references public.bank_accounts (id, connection_id),
    constraint bank_transactions_link_check check (
        (status in ('importada', 'reconciliada')) = (transaction_id is not null)
    )
);

create index bank_transactions_connection_data_idx on public.bank_transactions (bank_connection_id, data desc);
create index bank_transactions_status_idx on public.bank_transactions (status);

alter table public.transactions
    add constraint transactions_bank_transaction_fkey
    foreign key (bank_transaction_id) references public.bank_transactions(id) on delete restrict;

alter table public.bank_connections enable row level security;
alter table public.bank_accounts enable row level security;
alter table public.bank_transactions enable row level security;

grant select, insert, update on public.bank_connections, public.bank_accounts to authenticated;
grant select on public.bank_transactions to authenticated;
grant update (status) on public.bank_transactions to authenticated;
revoke all on public.bank_connections, public.bank_accounts, public.bank_transactions from anon;
