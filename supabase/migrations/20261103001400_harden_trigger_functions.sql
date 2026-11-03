-- Fatia 1 - hardening dos triggers no Supabase hospedado.
-- Funcoes de trigger nao precisam de EXECUTE para disparar; sem o revoke,
-- o PostgREST as expoe como RPC para anon/authenticated.

revoke all on function public.tg_seed_default_categories() from public, anon, authenticated;
revoke all on function public.tg_guard_profile_update() from public, anon, authenticated;
revoke all on function public.tg_guard_family_update() from public, anon, authenticated;
revoke all on function public.tg_guard_category_update() from public, anon, authenticated;
revoke all on function public.tg_guard_goal_contribution() from public, anon, authenticated;
revoke all on function public.tg_guard_occurrence_status() from public, anon, authenticated;
revoke all on function public.tg_reset_links_on_transaction_delete() from public, anon, authenticated;
revoke all on function public.tg_sync_bank_link_from_transaction() from public, anon, authenticated;
revoke all on function public.set_updated_at_connection() from public, anon, authenticated;
revoke all on function public.set_updated_at_account() from public, anon, authenticated;
revoke all on function public.tg_guard_transaction_identity() from public, anon, authenticated;
revoke all on function public.tg_guard_recurring_rule_identity() from public, anon, authenticated;
revoke all on function public.tg_guard_goal_identity() from public, anon, authenticated;
revoke all on function public.tg_guard_bank_connection_identity() from public, anon, authenticated;
revoke all on function public.tg_guard_bank_transaction_identity() from public, anon, authenticated;
revoke all on function public.tg_limit_bank_connections() from public, anon, authenticated;
revoke all on function public.tg_guard_ai_suggestion_update() from public, anon, authenticated;

revoke all on function private.recalc_goal_status(uuid) from public;
revoke all on function private.tg_recalc_goal_status_contribution() from public;
revoke all on function private.tg_recalc_goal_status_target() from public;
