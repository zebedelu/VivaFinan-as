-- Fatia 1 - Task 2: schema de identidade.
-- families, profiles e categories. RLS habilitado sem politicas ainda.

create table public.families (
    id uuid primary key default gen_random_uuid(),
    nome text not null check (length(btrim(nome)) between 1 and 80),
    criado_por uuid not null references auth.users(id) on delete restrict,
    criado_em timestamptz not null default now(),
    is_demo boolean not null default false,
    constraint families_criado_por_key unique (criado_por)
);

create table public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    family_id uuid not null references public.families(id) on delete cascade,
    nome text not null check (length(btrim(nome)) between 1 and 80),
    papel text not null default 'membro' check (papel in ('admin', 'membro')),
    status text not null default 'ativo' check (status in ('ativo', 'inativo')),
    tema text not null default 'claro' check (tema in ('claro', 'escuro')),
    criado_em timestamptz not null default now(),
    constraint profiles_id_family_key unique (id, family_id)
);

create index profiles_family_status_idx on public.profiles (family_id, status);

create table public.categories (
    id uuid primary key default gen_random_uuid(),
    family_id uuid not null references public.families(id) on delete cascade,
    nome text not null check (length(btrim(nome)) between 1 and 60),
    tipo text not null check (tipo in ('receita', 'despesa')),
    personalizada boolean not null default true,
    oculta boolean not null default false,
    criado_por uuid references public.profiles(id) on delete set null,
    constraint categories_id_family_key unique (id, family_id),
    constraint categories_family_tipo_nome_key unique (family_id, tipo, nome),
    constraint categories_id_family_tipo_key unique (id, family_id, tipo)
);

create index categories_family_tipo_oculta_idx on public.categories (family_id, tipo, oculta);

alter table public.families enable row level security;
alter table public.profiles enable row level security;
alter table public.categories enable row level security;

grant select, insert, update on public.families, public.profiles to authenticated;
grant select, insert, update, delete on public.categories to authenticated;
revoke all on public.families, public.profiles, public.categories from anon;
