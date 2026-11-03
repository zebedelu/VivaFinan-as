-- Fatia 1 - Task 8: RLS de identidade.
-- families, profiles e categories.

create policy families_select on public.families
for select to authenticated
using (
    id = (select private.current_family_id())
    or (
        criado_por = (select auth.uid())
        and not private.user_has_profile()
    )
);

create policy families_insert on public.families
for insert to authenticated
with check (
    criado_por = (select auth.uid())
    and is_demo = false
    and not private.user_has_profile()
);

create policy families_update on public.families
for update to authenticated
using ((select private.is_admin_of(id)) and is_demo = false)
with check ((select private.is_admin_of(id)) and is_demo = false);

create policy profiles_select on public.profiles
for select to authenticated
using (
    id = (select auth.uid())
    or (select private.is_admin_of(family_id))
);

create policy profiles_insert on public.profiles
for insert to authenticated
with check (
    id = (select auth.uid())
    and (select private.is_family_creator(family_id))
    and (
        (papel = 'admin' and not (select private.family_has_profiles(family_id)))
        or (papel = 'membro' and (select private.family_has_profiles(family_id)))
    )
);

create policy profiles_update on public.profiles
for update to authenticated
using (
    id = (select auth.uid())
    or (select private.is_admin_of(family_id))
)
with check (
    id = (select auth.uid())
    or (select private.is_admin_of(family_id))
);

create policy categories_select on public.categories
for select to authenticated
using (family_id = (select private.current_family_id()));

create policy categories_insert on public.categories
for insert to authenticated
with check (
    family_id = (select private.current_family_id())
    and personalizada = true
    and criado_por = (select auth.uid())
);

create policy categories_update on public.categories
for update to authenticated
using (
    family_id = (select private.current_family_id())
    and (
        (personalizada = true and criado_por = (select auth.uid()))
        or personalizada = false
    )
)
with check (
    family_id = (select private.current_family_id())
    and (
        (personalizada = true and criado_por = (select auth.uid()))
        or personalizada = false
    )
);

create policy categories_delete on public.categories
for delete to authenticated
using (
    family_id = (select private.current_family_id())
    and personalizada = true
    and criado_por = (select auth.uid())
    and not (select private.category_in_use(id))
);
