-- Fatia 1 - Task 7: triggers financeiros, de meta e de conexao.

create or replace function private.recalc_goal_status(p_goal_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.goals g
  set status = case
    when g.status = 'cancelada' then 'cancelada'
    when (select coalesce(sum(c.valor), 0) from public.goal_contributions c where c.goal_id = g.id) >= g.valor_alvo then 'concluida'
    else 'em_andamento'
  end
  where g.id = p_goal_id;
$$;

create or replace function private.tg_recalc_goal_status_contribution()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    perform private.recalc_goal_status(new.goal_id);
    return new;
end;
$$;

create or replace function private.tg_recalc_goal_status_target()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    perform private.recalc_goal_status(new.id);
    return new;
end;
$$;

create or replace function public.tg_guard_goal_contribution()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_status text;
begin
    select status into v_status from public.goals where id = new.goal_id;
    if v_status is not null and v_status <> 'em_andamento' then
        raise exception 'goal is not in progress' using errcode = '42501';
    end if;
    return new;
end;
$$;

create or replace function public.tg_guard_occurrence_status()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if old.status <> 'pendente' and new.status <> old.status then
        raise exception 'occurrence is already decided' using errcode = '42501';
    end if;
    return new;
end;
$$;

create or replace function public.tg_reset_links_on_transaction_delete()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if old.recurring_rule_id is not null then
        delete from public.recurring_occurrences
        where rule_id = old.recurring_rule_id
          and mes_referencia = old.mes_referencia;
    end if;
    if old.bank_transaction_id is not null then
        update public.bank_transactions
        set status = 'pendente_importacao', transaction_id = null
        where id = old.bank_transaction_id;
    end if;
    return old;
end;
$$;

create or replace function public.tg_sync_bank_link_from_transaction()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if tg_op = 'UPDATE'
       and old.bank_transaction_id is not null
       and new.bank_transaction_id is distinct from old.bank_transaction_id then
        update public.bank_transactions
        set status = 'pendente_importacao', transaction_id = null
        where id = old.bank_transaction_id;
    end if;

    if new.bank_transaction_id is not null then
        update public.bank_transactions
        set transaction_id = new.id,
            status = case when new.origem = 'pluggy' then 'importada' else 'reconciliada' end
        where id = new.bank_transaction_id;
    end if;

    return new;
end;
$$;

create or replace function public.set_updated_at_connection()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    new.atualizada_em = now();
    return new;
end;
$$;

create or replace function public.set_updated_at_account()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create or replace function public.tg_guard_transaction_identity()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.family_id <> old.family_id
       or new.member_id <> old.member_id
       or new.criado_por <> old.criado_por
       or new.origem <> old.origem
       or new.escopo <> old.escopo
       or new.recurring_rule_id is distinct from old.recurring_rule_id
       or new.mes_referencia is distinct from old.mes_referencia then
        raise exception 'transaction identity is immutable' using errcode = '42501';
    end if;
    return new;
end;
$$;

create or replace function public.tg_guard_recurring_rule_identity()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.family_id <> old.family_id
       or new.criado_por <> old.criado_por
       or new.escopo <> old.escopo then
        raise exception 'recurring rule identity is immutable' using errcode = '42501';
    end if;
    return new;
end;
$$;

create or replace function public.tg_guard_goal_identity()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.family_id <> old.family_id
       or new.member_id is distinct from old.member_id
       or new.criado_por <> old.criado_por then
        raise exception 'goal identity is immutable' using errcode = '42501';
    end if;
    return new;
end;
$$;

create or replace function public.tg_guard_bank_connection_identity()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.family_id <> old.family_id
       or new.member_id <> old.member_id
       or new.pluggy_connection_id <> old.pluggy_connection_id
       or new.is_demo_sync <> old.is_demo_sync then
        raise exception 'bank connection identity is immutable' using errcode = '42501';
    end if;
    return new;
end;
$$;

create or replace function public.tg_guard_bank_transaction_identity()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.bank_connection_id <> old.bank_connection_id
       or new.bank_account_id <> old.bank_account_id
       or new.pluggy_transaction_id <> old.pluggy_transaction_id
       or new.valor <> old.valor
       or new.data <> old.data
       or new.descricao <> old.descricao
       or new.tipo <> old.tipo
       or new.categoria_bancaria is distinct from old.categoria_bancaria
       or new.is_demo_sync <> old.is_demo_sync then
        raise exception 'bank transaction raw data is immutable' using errcode = '42501';
    end if;
    return new;
end;
$$;

create or replace function public.tg_limit_bank_connections()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_count integer;
begin
    if new.status = 'ativa' then
        if tg_op = 'INSERT' then
            select count(*) into v_count
            from public.bank_connections
            where member_id = new.member_id and status = 'ativa';
        else
            select count(*) into v_count
            from public.bank_connections
            where member_id = new.member_id and status = 'ativa' and id <> old.id;
        end if;
        if v_count >= 3 then
            raise exception 'bank connection limit reached' using errcode = '42501';
        end if;
    end if;
    return new;
end;
$$;

create or replace function public.tg_guard_ai_suggestion_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.family_id <> old.family_id
       or new.member_id is distinct from old.member_id
       or new.tipo <> old.tipo
       or new.titulo <> old.titulo
       or new.o_que <> old.o_que
       or new.por_que <> old.por_que
       or new.quanto <> old.quanto then
        raise exception 'ai suggestion content is immutable' using errcode = '42501';
    end if;
    if new.lida <> old.lida and not (old.lida = false and new.lida = true) then
        raise exception 'ai suggestion lida can only go from false to true' using errcode = '42501';
    end if;
    return new;
end;
$$;

create trigger tg_recalc_goal_status_contribution
after insert or update on public.goal_contributions
for each row execute function private.tg_recalc_goal_status_contribution();

create trigger tg_recalc_goal_status_target
after update of valor_alvo on public.goals
for each row execute function private.tg_recalc_goal_status_target();

create trigger tg_guard_goal_contribution
before insert on public.goal_contributions
for each row execute function public.tg_guard_goal_contribution();

create trigger tg_guard_occurrence_status
before update on public.recurring_occurrences
for each row execute function public.tg_guard_occurrence_status();

create trigger tg_reset_links_on_transaction_delete
before delete on public.transactions
for each row execute function public.tg_reset_links_on_transaction_delete();

create trigger tg_sync_bank_link_from_transaction
after insert or update of bank_transaction_id on public.transactions
for each row execute function public.tg_sync_bank_link_from_transaction();

create trigger tg_set_updated_at_connection
before update on public.bank_connections
for each row execute function public.set_updated_at_connection();

create trigger tg_set_updated_at_account
before update on public.bank_accounts
for each row execute function public.set_updated_at_account();

create trigger tg_guard_transaction_identity
before update on public.transactions
for each row execute function public.tg_guard_transaction_identity();

create trigger tg_guard_recurring_rule_identity
before update on public.recurring_rules
for each row execute function public.tg_guard_recurring_rule_identity();

create trigger tg_guard_goal_identity
before update on public.goals
for each row execute function public.tg_guard_goal_identity();

create trigger tg_guard_bank_connection_identity
before update on public.bank_connections
for each row execute function public.tg_guard_bank_connection_identity();

create trigger tg_guard_bank_transaction_identity
before update on public.bank_transactions
for each row execute function public.tg_guard_bank_transaction_identity();

create trigger tg_limit_bank_connections
before insert or update on public.bank_connections
for each row execute function public.tg_limit_bank_connections();

create trigger tg_guard_ai_suggestion_update
before update on public.ai_suggestions
for each row execute function public.tg_guard_ai_suggestion_update();
