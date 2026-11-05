-- Fatia 1b - confirmacao atomica de ocorrencia recorrente.
-- security invoker de proposito: RLS e grants do usuario valem.
-- A data nunca fica no futuro: usa o vencimento com clamp e limita ao dia atual
-- de Sao Paulo (o mes corrente pode estar parcial).

create or replace function public.confirm_occurrence(p_occurrence_id uuid, p_valor numeric default null)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_uid uuid := (select auth.uid());
    v_occ public.recurring_occurrences;
    v_rule public.recurring_rules;
    v_data date;
    v_valor numeric;
    v_tx uuid;
begin
    if v_uid is null then
        raise exception 'not authenticated' using errcode = '42501';
    end if;

    select * into v_occ
    from public.recurring_occurrences
    where id = p_occurrence_id;

    if not found or v_occ.status <> 'pendente' then
        raise exception 'occurrence not pending' using errcode = '42501';
    end if;

    select * into v_rule
    from public.recurring_rules
    where id = v_occ.rule_id
      and ativo;

    if not found then
        raise exception 'rule not active' using errcode = '42501';
    end if;

    if p_valor is not null and p_valor <= 0 then
        raise exception 'invalid value' using errcode = '22023';
    end if;

    v_valor := coalesce(p_valor, v_rule.valor);
    v_data := least(
        least(
            (v_occ.mes_referencia + ((v_rule.dia_vencimento - 1) || ' days')::interval)::date,
            (date_trunc('month', v_occ.mes_referencia) + interval '1 month - 1 day')::date
        ),
        (now() at time zone 'America/Sao_Paulo')::date
    );

    insert into public.transactions
        (family_id, member_id, tipo, escopo, valor, descricao, category_id, data, criado_por, origem, recurring_rule_id, mes_referencia)
    values
        (v_rule.family_id, v_uid, v_rule.tipo, v_rule.escopo, v_valor, v_rule.descricao, v_rule.category_id, v_data, v_uid, 'manual', v_rule.id, v_occ.mes_referencia)
    returning id into v_tx;

    update public.recurring_occurrences
       set status = 'confirmado',
           valor_confirmado = v_valor,
           confirmado_por = v_uid,
           confirmado_em = now()
     where id = v_occ.id
       and status = 'pendente';

    if not found then
        raise exception 'occurrence already decided' using errcode = '42501';
    end if;

    return v_tx;
end;
$$;

revoke all on function public.confirm_occurrence(uuid, numeric) from public, anon, authenticated;
grant execute on function public.confirm_occurrence(uuid, numeric) to authenticated;
