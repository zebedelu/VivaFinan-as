-- Fatia 1b - demo ignore.
-- O dono da conexao demo pode alterar apenas o status de uma bank tx demo.
-- Campos brutos continuam imutaveis (grant de coluna e trigger de identidade).

create policy bank_transactions_update_demo on public.bank_transactions
for update to authenticated
using (
    (select private.owns_connection(bank_connection_id))
    and is_demo_sync
)
with check (
    (select private.owns_connection(bank_connection_id))
    and is_demo_sync
    and (transaction_id is null or (select private.can_view_transaction(transaction_id)))
);
