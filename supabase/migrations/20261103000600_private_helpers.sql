-- Fatia 1 - Task 6: helpers privados.
-- security definer + search_path vazio evitam recursao de RLS e escalada.

create schema if not exists private;

create or replace function private.current_family_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select family_id
  from public.profiles
  where id = (select auth.uid())
    and status = 'ativo'
$$;

create or replace function private.is_active_member_of(p_family_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid())
      and family_id = p_family_id
      and status = 'ativo'
  )
$$;

create or replace function private.is_admin_of(p_family_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid())
      and family_id = p_family_id
      and papel = 'admin'
      and status = 'ativo'
  )
$$;

create or replace function private.owns_connection(p_connection_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.bank_connections bc
    where bc.id = p_connection_id
      and bc.member_id = (select auth.uid())
      and bc.family_id = private.current_family_id()
  )
$$;

create or replace function private.can_view_rule(p_rule_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.recurring_rules r
    where r.id = p_rule_id
      and r.family_id = private.current_family_id()
      and (r.escopo = 'familia' or r.criado_por = (select auth.uid()))
  )
$$;

create or replace function private.can_view_goal(p_goal_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.goals g
    where g.id = p_goal_id
      and g.family_id = private.current_family_id()
      and (g.member_id is null or g.member_id = (select auth.uid()))
  )
$$;

create or replace function private.is_demo_connection(p_connection_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.bank_connections bc
    where bc.id = p_connection_id and bc.is_demo_sync
  )
$$;

create or replace function private.can_write_connection(p_connection_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.owns_connection(p_connection_id)
     and not private.is_demo_connection(p_connection_id)
$$;

create or replace function private.can_view_transaction(p_transaction_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.transactions t
    where t.id = p_transaction_id
      and t.family_id = private.current_family_id()
      and (t.escopo = 'familia' or t.member_id = (select auth.uid()))
  )
$$;

create or replace function private.family_has_profiles(p_family_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.profiles where family_id = p_family_id)
$$;

create or replace function private.category_in_use(p_category_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.transactions where category_id = p_category_id)
      or exists (select 1 from public.recurring_rules where category_id = p_category_id)
$$;

create or replace function private.user_has_profile()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid())
  )
$$;

create or replace function private.is_family_creator(p_family_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.families f
    where f.id = p_family_id
      and f.criado_por = (select auth.uid())
      and f.is_demo = false
  )
$$;

revoke all on function private.user_has_profile() from public;
revoke all on function private.is_family_creator(uuid) from public;
revoke all on function private.current_family_id() from public;
revoke all on function private.is_active_member_of(uuid) from public;
revoke all on function private.is_admin_of(uuid) from public;
revoke all on function private.owns_connection(uuid) from public;
revoke all on function private.is_demo_connection(uuid) from public;
revoke all on function private.can_write_connection(uuid) from public;
revoke all on function private.can_view_transaction(uuid) from public;
revoke all on function private.can_view_rule(uuid) from public;
revoke all on function private.can_view_goal(uuid) from public;
revoke all on function private.family_has_profiles(uuid) from public;
revoke all on function private.category_in_use(uuid) from public;

grant usage on schema private to authenticated;
grant execute on function private.user_has_profile() to authenticated;
grant execute on function private.is_family_creator(uuid) to authenticated;
grant execute on function private.current_family_id() to authenticated;
grant execute on function private.is_active_member_of(uuid) to authenticated;
grant execute on function private.is_admin_of(uuid) to authenticated;
grant execute on function private.owns_connection(uuid) to authenticated;
grant execute on function private.can_write_connection(uuid) to authenticated;
grant execute on function private.can_view_transaction(uuid) to authenticated;
grant execute on function private.can_view_rule(uuid) to authenticated;
grant execute on function private.can_view_goal(uuid) to authenticated;
grant execute on function private.family_has_profiles(uuid) to authenticated;
grant execute on function private.category_in_use(uuid) to authenticated;
