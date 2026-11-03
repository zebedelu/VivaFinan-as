-- Fatia 1 - Task 10: RLS financeiro.
-- transactions, recurring_rules e recurring_occurrences.
-- Admin nao tem bypass de dados pessoais.

create policy transactions_select on public.transactions
for select to authenticated
using (
    family_id = (select private.current_family_id())
    and (escopo = 'familia' or member_id = (select auth.uid()))
);

create policy transactions_insert on public.transactions
for insert to authenticated
with check (
    family_id = (select private.current_family_id())
    and member_id = (select auth.uid())
    and criado_por = (select auth.uid())
    and (recurring_rule_id is null or (select private.can_view_rule(recurring_rule_id)))
    and (
        bank_transaction_id is null
        or exists (
            select 1
            from public.bank_transactions bt
            where bt.id = bank_transaction_id
              and (select private.owns_connection(bt.bank_connection_id))
        )
    )
);

create policy transactions_update on public.transactions
for update to authenticated
using (
    family_id = (select private.current_family_id())
    and (escopo = 'familia' or member_id = (select auth.uid()))
)
with check (
    family_id = (select private.current_family_id())
    and (escopo = 'familia' or member_id = (select auth.uid()))
    and (
        recurring_rule_id is null
        or escopo = 'familia'
        or (select private.can_view_rule(recurring_rule_id))
    )
    and (
        bank_transaction_id is null
        or escopo = 'familia'
        or exists (
            select 1
            from public.bank_transactions bt
            where bt.id = bank_transaction_id
              and (select private.owns_connection(bt.bank_connection_id))
        )
    )
);

create policy transactions_delete on public.transactions
for delete to authenticated
using (
    family_id = (select private.current_family_id())
    and criado_por = (select auth.uid())
);

create policy recurring_rules_select on public.recurring_rules
for select to authenticated
using (
    family_id = (select private.current_family_id())
    and (escopo = 'familia' or criado_por = (select auth.uid()))
);

create policy recurring_rules_insert on public.recurring_rules
for insert to authenticated
with check (
    family_id = (select private.current_family_id())
    and criado_por = (select auth.uid())
);

create policy recurring_rules_update on public.recurring_rules
for update to authenticated
using (
    family_id = (select private.current_family_id())
    and (escopo = 'familia' or criado_por = (select auth.uid()))
)
with check (
    family_id = (select private.current_family_id())
    and (escopo = 'familia' or criado_por = (select auth.uid()))
);

create policy recurring_occurrences_select on public.recurring_occurrences
for select to authenticated
using ((select private.can_view_rule(rule_id)));

create policy recurring_occurrences_insert on public.recurring_occurrences
for insert to authenticated
with check (
    (select private.can_view_rule(rule_id))
    and status = 'pendente'
    and confirmado_por is null
);

create policy recurring_occurrences_update on public.recurring_occurrences
for update to authenticated
using ((select private.can_view_rule(rule_id)))
with check (
    (select private.can_view_rule(rule_id))
    and (confirmado_por is null or confirmado_por = (select auth.uid()))
);
