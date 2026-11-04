-- Fatia 1 - correcao C1: guarda de vinculo bancario em transactions.
-- Um membro so pode criar, trocar ou remover um vinculo com uma bank tx
-- cuja conexao ele possui. O vinculo inalterado continua livre para a edicao
-- familiar dos demais campos. Service role/seed (auth.uid() nulo) passa.

create or replace function public.tg_guard_transaction_bank_link()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := (select auth.uid());
    v_conn uuid;
begin
    if v_uid is null then
        if tg_op = 'DELETE' then
            return old;
        end if;
        return new;
    end if;

    if tg_op in ('INSERT', 'UPDATE') then
        if tg_op = 'UPDATE' and new.bank_transaction_id is not distinct from old.bank_transaction_id then
            return new;
        end if;
        if new.bank_transaction_id is not null then
            select bt.bank_connection_id into v_conn
            from public.bank_transactions bt
            where bt.id = new.bank_transaction_id;
            if v_conn is null or not private.owns_connection(v_conn) then
                raise exception 'bank transaction is not owned by the member' using errcode = '42501';
            end if;
        end if;
    end if;

    if tg_op in ('UPDATE', 'DELETE') then
        if tg_op = 'UPDATE' and new.bank_transaction_id is not distinct from old.bank_transaction_id then
            return new;
        end if;
        if old.bank_transaction_id is not null then
            select bt.bank_connection_id into v_conn
            from public.bank_transactions bt
            where bt.id = old.bank_transaction_id;
            if v_conn is null or not private.owns_connection(v_conn) then
                raise exception 'bank transaction is not owned by the member' using errcode = '42501';
            end if;
        end if;
    end if;

    if tg_op = 'DELETE' then
        return old;
    end if;
    return new;
end;
$$;

revoke all on function public.tg_guard_transaction_bank_link() from public, anon, authenticated;

drop trigger if exists tg_guard_transaction_bank_link on public.transactions;
create trigger tg_guard_transaction_bank_link
before insert or update or delete on public.transactions
for each row execute function public.tg_guard_transaction_bank_link();
