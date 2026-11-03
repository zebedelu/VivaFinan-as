-- Fatia 1 - Task 12: funcoes de leitura agregada da familia.
-- security definer, stable, search_path vazio; apenas agregados.

create or replace function private.assert_family_member(p_family_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    if not private.is_active_member_of(p_family_id) then
        raise exception 'not a family member' using errcode = '42501';
    end if;
end;
$$;

create or replace function private.assert_month_start(p_mes date)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    if p_mes <> date_trunc('month', p_mes)::date then
        raise exception 'month start required' using errcode = '22023';
    end if;
end;
$$;

create or replace function public.family_totals(p_family_id uuid, p_mes date)
returns table(receitas numeric, despesas numeric)
language sql
stable
security definer
set search_path = ''
as $$
    select private.assert_family_member(p_family_id);
    select private.assert_month_start(p_mes);
    select
        coalesce(sum(case when t.tipo = 'receita' then t.valor else 0 end), 0)::numeric(14,2) as receitas,
        coalesce(sum(case when t.tipo = 'despesa' then t.valor else 0 end), 0)::numeric(14,2) as despesas
    from public.transactions t
    where t.family_id = p_family_id
      and t.data >= p_mes
      and t.data < (p_mes + interval '1 month')::date;
$$;

create or replace function public.family_category_totals(p_family_id uuid, p_mes date)
returns table(category_id uuid, categoria text, total numeric)
language sql
stable
security definer
set search_path = ''
as $$
    select private.assert_family_member(p_family_id);
    select private.assert_month_start(p_mes);
    select c.id as category_id, c.nome as categoria, coalesce(sum(t.valor), 0)::numeric(14,2) as total
    from public.categories c
    join public.transactions t
      on t.category_id = c.id
     and t.family_id = c.family_id
     and t.tipo = c.tipo
    where c.family_id = p_family_id
      and t.tipo = 'despesa'
      and t.data >= p_mes
      and t.data < (p_mes + interval '1 month')::date
    group by c.id, c.nome;
$$;

create or replace function public.family_monthly_totals(p_family_id uuid, p_mes_fim date)
returns table(mes date, receitas numeric, despesas numeric)
language sql
stable
security definer
set search_path = ''
as $$
    select private.assert_family_member(p_family_id);
    select private.assert_month_start(p_mes_fim);
    select
        date_trunc('month', t.data)::date as mes,
        coalesce(sum(case when t.tipo = 'receita' then t.valor else 0 end), 0)::numeric(14,2) as receitas,
        coalesce(sum(case when t.tipo = 'despesa' then t.valor else 0 end), 0)::numeric(14,2) as despesas
    from public.transactions t
    where t.family_id = p_family_id
      and t.data >= (p_mes_fim - interval '5 months')::date
      and t.data < (p_mes_fim + interval '1 month')::date
    group by date_trunc('month', t.data)::date
    order by mes;
$$;

create or replace function public.family_member_directory(p_family_id uuid)
returns table(member_id uuid, nome text, papel text)
language sql
stable
security definer
set search_path = ''
as $$
    select private.assert_family_member(p_family_id);
    select p.id as member_id, p.nome, p.papel
    from public.profiles p
    where p.family_id = p_family_id
      and p.status = 'ativo'
    order by p.nome;
$$;

revoke all on function private.assert_family_member(uuid) from public;
revoke all on function private.assert_month_start(date) from public;

revoke all on function public.family_totals(uuid, date) from public, anon, authenticated;
grant execute on function public.family_totals(uuid, date) to authenticated;

revoke all on function public.family_category_totals(uuid, date) from public, anon, authenticated;
grant execute on function public.family_category_totals(uuid, date) to authenticated;

revoke all on function public.family_monthly_totals(uuid, date) from public, anon, authenticated;
grant execute on function public.family_monthly_totals(uuid, date) to authenticated;

revoke all on function public.family_member_directory(uuid) from public, anon, authenticated;
grant execute on function public.family_member_directory(uuid) to authenticated;
