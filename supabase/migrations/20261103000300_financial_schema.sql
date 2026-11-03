-- Fatia 1 - Task 3: schema financeiro.
-- recurring_rules -> transactions -> recurring_occurrences.
-- bank_transaction_id fica sem FK ate a Task 5.

create table public.recurring_rules (
    id uuid primary key default gen_random_uuid(),
    family_id uuid not null references public.families(id) on delete cascade,
    criado_por uuid not null,
    tipo text not null check (tipo in ('receita', 'despesa')),
    escopo text not null check (escopo in ('pessoal', 'familia')),
    valor numeric(14,2) not null check (valor > 0),
    descricao text not null,
    category_id uuid not null,
    dia_vencimento smallint not null check (dia_vencimento between 1 and 31),
    ativo boolean not null default true,
    criado_em timestamptz not null default now(),
    constraint recurring_rules_id_family_key unique (id, family_id),
    constraint recurring_rules_creator_family_fkey foreign key (criado_por, family_id)
        references public.profiles (id, family_id),
    constraint recurring_rules_category_family_fkey foreign key (category_id, family_id, tipo)
        references public.categories (id, family_id, tipo)
);

create index recurring_rules_family_ativo_idx on public.recurring_rules (family_id, ativo);

create table public.transactions (
    id uuid primary key default gen_random_uuid(),
    family_id uuid not null references public.families(id) on delete cascade,
    member_id uuid not null,
    tipo text not null check (tipo in ('receita', 'despesa')),
    escopo text not null check (escopo in ('pessoal', 'familia')),
    valor numeric(14,2) not null check (valor > 0),
    descricao text,
    category_id uuid not null,
    data date not null,
    pago_por uuid,
    recurring_rule_id uuid,
    mes_referencia date,
    criado_por uuid not null,
    origem text not null default 'manual' check (origem in ('manual', 'pluggy')),
    bank_transaction_id uuid unique,
    criado_em timestamptz not null default now(),
    constraint transactions_member_family_fkey foreign key (member_id, family_id)
        references public.profiles (id, family_id),
    constraint transactions_creator_family_fkey foreign key (criado_por, family_id)
        references public.profiles (id, family_id),
    constraint transactions_payer_family_fkey foreign key (pago_por, family_id)
        references public.profiles (id, family_id),
    constraint transactions_category_family_fkey foreign key (category_id, family_id, tipo)
        references public.categories (id, family_id, tipo),
    constraint transactions_rule_family_fkey foreign key (recurring_rule_id, family_id)
        references public.recurring_rules (id, family_id),
    constraint transactions_pago_por_scope_check check (pago_por is null or escopo = 'familia'),
    constraint transactions_recurring_month_check check ((recurring_rule_id is null) = (mes_referencia is null)),
    constraint transactions_mes_referencia_start_check check (
        mes_referencia is null or mes_referencia = date_trunc('month', mes_referencia)::date
    ),
    constraint transactions_origem_link_check check (origem = 'manual' or bank_transaction_id is not null),
    constraint transactions_rule_month_key unique (recurring_rule_id, mes_referencia)
);

create index transactions_family_data_idx on public.transactions (family_id, data desc);
create index transactions_member_data_idx on public.transactions (member_id, data desc);
create index transactions_category_idx on public.transactions (category_id);

create table public.recurring_occurrences (
    id uuid primary key default gen_random_uuid(),
    rule_id uuid not null references public.recurring_rules(id) on delete cascade,
    mes_referencia date not null check (mes_referencia = date_trunc('month', mes_referencia)::date),
    status text not null check (status in ('pendente', 'confirmado', 'ignorado')),
    valor_confirmado numeric(14,2) check (valor_confirmado is null or valor_confirmado > 0),
    confirmado_por uuid references public.profiles(id) on delete set null,
    confirmado_em timestamptz,
    constraint recurring_occurrences_rule_month_key unique (rule_id, mes_referencia),
    constraint recurring_occurrences_confirmado_check check (
        status <> 'confirmado'
        or (valor_confirmado is not null and confirmado_por is not null and confirmado_em is not null)
    ),
    constraint recurring_occurrences_pendente_check check (
        status = 'confirmado'
        or (valor_confirmado is null and confirmado_por is null and confirmado_em is null)
    )
);

alter table public.transactions enable row level security;
alter table public.recurring_rules enable row level security;
alter table public.recurring_occurrences enable row level security;

grant select, insert, update, delete on public.transactions to authenticated;
grant select, insert, update on public.recurring_rules to authenticated;
grant select, insert, update on public.recurring_occurrences to authenticated;
revoke all on public.transactions, public.recurring_rules, public.recurring_occurrences from anon;
