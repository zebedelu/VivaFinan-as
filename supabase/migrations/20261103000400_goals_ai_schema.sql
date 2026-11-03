-- Fatia 1 - Task 4: schema de metas e IA.

create table public.goals (
    id uuid primary key default gen_random_uuid(),
    family_id uuid not null references public.families(id) on delete cascade,
    member_id uuid,
    criado_por uuid not null,
    titulo text not null check (length(btrim(titulo)) between 1 and 120),
    valor_alvo numeric(14,2) not null check (valor_alvo > 0),
    prazo date,
    status text not null default 'em_andamento' check (status in ('em_andamento', 'concluida', 'cancelada')),
    descricao text,
    criado_em timestamptz not null default now(),
    constraint goals_member_family_fkey foreign key (member_id, family_id)
        references public.profiles (id, family_id),
    constraint goals_creator_family_fkey foreign key (criado_por, family_id)
        references public.profiles (id, family_id)
);

create index goals_family_member_status_idx on public.goals (family_id, member_id, status);

create table public.goal_contributions (
    id uuid primary key default gen_random_uuid(),
    goal_id uuid not null references public.goals(id) on delete cascade,
    member_id uuid not null references public.profiles(id) on delete restrict,
    valor numeric(14,2) not null check (valor > 0),
    data date not null default current_date,
    criado_em timestamptz not null default now()
);

create index goal_contributions_goal_idx on public.goal_contributions (goal_id);

create table public.ai_messages (
    id uuid primary key default gen_random_uuid(),
    family_id uuid not null references public.families(id) on delete cascade,
    member_id uuid,
    role text not null,
    content text not null check (length(btrim(content)) > 0),
    criado_em timestamptz not null default now(),
    constraint ai_messages_member_family_fkey foreign key (member_id, family_id)
        references public.profiles (id, family_id)
);

create index ai_messages_family_member_created_idx on public.ai_messages (family_id, member_id, criado_em desc);

create table public.ai_suggestions (
    id uuid primary key default gen_random_uuid(),
    family_id uuid not null references public.families(id) on delete cascade,
    member_id uuid,
    tipo text not null check (length(btrim(tipo)) > 0),
    titulo text not null check (length(btrim(titulo)) > 0),
    o_que text not null check (length(btrim(o_que)) > 0),
    por_que text not null check (length(btrim(por_que)) > 0),
    quanto text not null check (length(btrim(quanto)) > 0),
    criado_em timestamptz not null default now(),
    lida boolean not null default false,
    constraint ai_suggestions_member_family_fkey foreign key (member_id, family_id)
        references public.profiles (id, family_id)
);

create index ai_suggestions_family_member_lida_idx on public.ai_suggestions (family_id, member_id, lida);

alter table public.goals enable row level security;
alter table public.goal_contributions enable row level security;
alter table public.ai_messages enable row level security;
alter table public.ai_suggestions enable row level security;

grant select, insert, update, delete on public.goals to authenticated;
grant select, insert on public.goal_contributions to authenticated;
grant select, insert on public.ai_messages to authenticated;
grant select, insert on public.ai_suggestions to authenticated;
grant update (lida) on public.ai_suggestions to authenticated;
revoke all on public.goals, public.goal_contributions, public.ai_messages, public.ai_suggestions from anon;
