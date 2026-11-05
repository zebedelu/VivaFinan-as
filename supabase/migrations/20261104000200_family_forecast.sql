-- Fatia 1b - forecast familiar agregado.
-- 12 meses a partir de p_mes_inicio; sem membro, descricao ou categoria individual.

create or replace function public.family_forecast(p_family_id uuid, p_mes_inicio date)
returns table (
    mes date,
    receitas numeric,
    despesas numeric,
    recorrentes_receitas numeric,
    recorrentes_despesas numeric,
    variavel_receitas numeric,
    variavel_despesas numeric
)
language sql
stable
security definer
set search_path = ''
as $$
    select private.assert_family_member(p_family_id);
    select private.assert_month_start(p_mes_inicio);

    with meses as (
        select (p_mes_inicio + (g.i || ' months')::interval)::date as mes
        from generate_series(0, 11) as g(i)
    ),
    regras as (
        select
            r.id,
            r.tipo,
            coalesce(
                (select o.valor_confirmado
                 from public.recurring_occurrences o
                 where o.rule_id = r.id
                   and o.status = 'confirmado'
                   and o.valor_confirmado is not null
                   and o.mes_referencia >= (p_mes_inicio - interval '6 months')::date
                   and o.mes_referencia < p_mes_inicio
                 order by o.mes_referencia desc, o.confirmado_em desc
                 limit 1),
                r.valor
            )::numeric(14,2) as valor_projetado
        from public.recurring_rules r
        where r.family_id = p_family_id
          and r.ativo
          and exists (
              select 1
              from public.recurring_occurrences o
              where o.rule_id = r.id
                and o.status = 'confirmado'
                and o.mes_referencia >= (p_mes_inicio - interval '6 months')::date
                and o.mes_referencia < p_mes_inicio
          )
    ),
    recorrente as (
        select
            m.mes,
            coalesce(sum(case when g.tipo = 'receita' then g.valor_projetado else 0 end), 0)::numeric(14,2) as receitas,
            coalesce(sum(case when g.tipo = 'despesa' then g.valor_projetado else 0 end), 0)::numeric(14,2) as despesas
        from meses m
        left join regras g on true
        group by m.mes
    ),
    variavel as (
        select
            (coalesce(sum(case when t.tipo = 'receita' then t.valor else 0 end), 0) / 3.0)::numeric(14,2) as receitas,
            (coalesce(sum(case when t.tipo = 'despesa' then t.valor else 0 end), 0) / 3.0)::numeric(14,2) as despesas
        from public.transactions t
        where t.family_id = p_family_id
          and t.recurring_rule_id is null
          and t.data >= (p_mes_inicio - interval '4 months')::date
          and t.data < (p_mes_inicio - interval '1 month')::date
    )
    select
        m.mes,
        (coalesce(r.receitas, 0) + v.receitas)::numeric(14,2) as receitas,
        (coalesce(r.despesas, 0) + v.despesas)::numeric(14,2) as despesas,
        coalesce(r.receitas, 0)::numeric(14,2) as recorrentes_receitas,
        coalesce(r.despesas, 0)::numeric(14,2) as recorrentes_despesas,
        v.receitas as variavel_receitas,
        v.despesas as variavel_despesas
    from meses m
    cross join variavel v
    left join recorrente r on r.mes = m.mes
    order by m.mes;
$$;

revoke all on function public.family_forecast(uuid, date) from public, anon, authenticated;
grant execute on function public.family_forecast(uuid, date) to authenticated;
