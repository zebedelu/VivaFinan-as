-- Fatia 1 - Task 11: RLS de metas, contribuicoes e IA.

create policy goals_select on public.goals
for select to authenticated
using (
    family_id = (select private.current_family_id())
    and (member_id is null or member_id = (select auth.uid()))
);

create policy goals_insert on public.goals
for insert to authenticated
with check (
    family_id = (select private.current_family_id())
    and (member_id is null or member_id = (select auth.uid()))
    and criado_por = (select auth.uid())
);

create policy goals_update on public.goals
for update to authenticated
using (
    family_id = (select private.current_family_id())
    and (member_id is null or member_id = (select auth.uid()))
)
with check (
    family_id = (select private.current_family_id())
    and (member_id is null or member_id = (select auth.uid()))
);

create policy goals_delete on public.goals
for delete to authenticated
using (
    family_id = (select private.current_family_id())
    and criado_por = (select auth.uid())
);

create policy goal_contributions_select on public.goal_contributions
for select to authenticated
using ((select private.can_view_goal(goal_id)));

create policy goal_contributions_insert on public.goal_contributions
for insert to authenticated
with check (
    member_id = (select auth.uid())
    and (select private.can_view_goal(goal_id))
);

create policy ai_messages_select on public.ai_messages
for select to authenticated
using (
    family_id = (select private.current_family_id())
    and (member_id is null or member_id = (select auth.uid()))
);

create policy ai_messages_insert on public.ai_messages
for insert to authenticated
with check (
    family_id = (select private.current_family_id())
    and (member_id is null or member_id = (select auth.uid()))
);

create policy ai_suggestions_select on public.ai_suggestions
for select to authenticated
using (
    family_id = (select private.current_family_id())
    and (member_id is null or member_id = (select auth.uid()))
);

create policy ai_suggestions_insert on public.ai_suggestions
for insert to authenticated
with check (
    family_id = (select private.current_family_id())
    and (member_id is null or member_id = (select auth.uid()))
);

create policy ai_suggestions_update on public.ai_suggestions
for update to authenticated
using (
    family_id = (select private.current_family_id())
    and (member_id is null or member_id = (select auth.uid()))
)
with check (
    family_id = (select private.current_family_id())
    and (member_id is null or member_id = (select auth.uid()))
);
