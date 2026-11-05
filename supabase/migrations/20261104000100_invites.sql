-- Fatia 1b - convites e aceite.
-- family_nome e um snapshot para GET /invites/mine funcionar com o JWT do convidado.

create table public.invites (
    id uuid primary key default gen_random_uuid(),
    family_id uuid not null references public.families(id) on delete cascade,
    family_nome text not null check (length(btrim(family_nome)) between 1 and 80),
    email text not null check (length(btrim(email)) between 3 and 254),
    nome text not null check (length(btrim(nome)) between 1 and 80),
    papel text not null default 'membro' check (papel = 'membro'),
    status text not null default 'pendente' check (status in ('pendente', 'aceito', 'cancelado')),
    token uuid not null default gen_random_uuid() unique,
    criado_por uuid not null references public.profiles(id) on delete cascade,
    criado_em timestamptz not null default now(),
    aceito_em timestamptz
);

create unique index invites_pending_email_key
    on public.invites (family_id, lower(email))
    where status = 'pendente';

alter table public.invites enable row level security;

revoke all on public.invites from public, anon, authenticated;
grant select, insert, update, delete on public.invites to authenticated;

create policy invites_select on public.invites
for select to authenticated
using (
    (select private.is_admin_of(family_id))
    or (lower(email) = lower((select auth.email())) and status = 'pendente')
);

create policy invites_insert on public.invites
for insert to authenticated
with check (
    (select private.is_admin_of(family_id))
    and criado_por = (select auth.uid())
);

create policy invites_update on public.invites
for update to authenticated
using ((select private.is_admin_of(family_id)))
with check ((select private.is_admin_of(family_id)));

create policy invites_delete on public.invites
for delete to authenticated
using ((select private.is_admin_of(family_id)));

create or replace function public.accept_invite(p_token uuid, p_nome text)
returns table (profile_id uuid, family_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := (select auth.uid());
    v_email text := (select auth.email());
    v_inv public.invites;
    v_nome text;
begin
    if v_uid is null or v_email is null then
        raise exception 'not authenticated' using errcode = '42501';
    end if;

    select * into v_inv
    from public.invites
    where token = p_token
      and status = 'pendente'
    for update;

    if not found then
        raise exception 'invite not found' using errcode = '42501';
    end if;
    if lower(v_inv.email) <> lower(v_email) then
        raise exception 'invite email mismatch' using errcode = '42501';
    end if;
    if exists (select 1 from public.profiles where id = v_uid) then
        raise exception 'profile already exists' using errcode = '23505';
    end if;

    v_nome := btrim(coalesce(nullif(btrim(p_nome), ''), v_inv.nome));
    if length(v_nome) not between 1 and 80 then
        raise exception 'invalid name' using errcode = '22023';
    end if;

    insert into public.profiles (id, family_id, nome, papel, status)
    values (v_uid, v_inv.family_id, v_nome, 'membro', 'ativo');

    update public.invites
       set status = 'aceito', aceito_em = now()
     where id = v_inv.id;

    return query select v_uid, v_inv.family_id;
end;
$$;

revoke all on function public.accept_invite(uuid, text) from public, anon, authenticated;
grant execute on function public.accept_invite(uuid, text) to authenticated;
