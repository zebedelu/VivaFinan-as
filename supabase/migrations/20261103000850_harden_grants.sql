-- Fatia 1 - hardening de grants no Supabase hospedado.
-- O projeto concede ALL em tabelas novas para authenticated (auto_expose_new_tables).
-- Sem este revoke, authenticated teria TRUNCATE/REFERENCES/TRIGGER e UPDATE em
-- colunas que o plano quer somente leitura (bank_transactions.transaction_id,
-- ai_suggestions.lida, etc.).

revoke all on public.families, public.profiles, public.categories,
    public.transactions, public.recurring_rules, public.recurring_occurrences,
    public.goals, public.goal_contributions, public.ai_messages, public.ai_suggestions,
    public.bank_connections, public.bank_accounts, public.bank_transactions
    from authenticated;

revoke all on public.families, public.profiles, public.categories,
    public.transactions, public.recurring_rules, public.recurring_occurrences,
    public.goals, public.goal_contributions, public.ai_messages, public.ai_suggestions,
    public.bank_connections, public.bank_accounts, public.bank_transactions
    from anon;

revoke all on public.families, public.profiles, public.categories,
    public.transactions, public.recurring_rules, public.recurring_occurrences,
    public.goals, public.goal_contributions, public.ai_messages, public.ai_suggestions,
    public.bank_connections, public.bank_accounts, public.bank_transactions
    from public;

grant select, insert, update on public.families to authenticated;
grant select, insert, update on public.profiles to authenticated;
grant select, insert, update, delete on public.categories to authenticated;
grant select, insert, update, delete on public.transactions to authenticated;
grant select, insert, update on public.recurring_rules to authenticated;
grant select, insert, update on public.recurring_occurrences to authenticated;
grant select, insert, update, delete on public.goals to authenticated;
grant select, insert on public.goal_contributions to authenticated;
grant select, insert on public.ai_messages to authenticated;
grant select, insert on public.ai_suggestions to authenticated;
grant update (lida) on public.ai_suggestions to authenticated;
grant select, insert, update on public.bank_connections to authenticated;
grant select, insert, update on public.bank_accounts to authenticated;
grant select on public.bank_transactions to authenticated;
grant update (status) on public.bank_transactions to authenticated;
