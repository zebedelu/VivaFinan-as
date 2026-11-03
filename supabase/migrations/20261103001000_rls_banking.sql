-- Fatia 1 - Task 9: RLS bancario.
-- Conexoes, contas e transacoes sao pessoais; admin nao tem bypass.
-- Dados brutos da demo sao somente leitura para o usuario.

create policy bank_connections_select on public.bank_connections
for select to authenticated
using (
    member_id = (select auth.uid())
    and family_id = (select private.current_family_id())
);

create policy bank_connections_insert on public.bank_connections
for insert to authenticated
with check (
    member_id = (select auth.uid())
    and family_id = (select private.current_family_id())
    and is_demo_sync = false
);

create policy bank_connections_update on public.bank_connections
for update to authenticated
using (
    member_id = (select auth.uid())
    and family_id = (select private.current_family_id())
)
with check (
    member_id = (select auth.uid())
    and family_id = (select private.current_family_id())
    and is_demo_sync = false
);

create policy bank_accounts_select on public.bank_accounts
for select to authenticated
using ((select private.owns_connection(connection_id)));

create policy bank_accounts_insert on public.bank_accounts
for insert to authenticated
with check ((select private.can_write_connection(connection_id)));

create policy bank_accounts_update on public.bank_accounts
for update to authenticated
using ((select private.can_write_connection(connection_id)))
with check ((select private.can_write_connection(connection_id)));

create policy bank_transactions_select on public.bank_transactions
for select to authenticated
using ((select private.owns_connection(bank_connection_id)));

create policy bank_transactions_update on public.bank_transactions
for update to authenticated
using (
    (select private.can_write_connection(bank_connection_id))
    and (transaction_id is null or (select private.can_view_transaction(transaction_id)))
)
with check (
    (select private.can_write_connection(bank_connection_id))
    and (transaction_id is null or (select private.can_view_transaction(transaction_id)))
);
