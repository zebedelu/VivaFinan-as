-- Fatia 1b - onboarding atomico e idempotente.
-- Se ja existe perfil, devolve o existente. Se existe familia orfa criada pelo
-- usuario, adota. Senao cria familia + perfil admin na mesma transacao.
-- A corrida de duas chamadas e resolvida por unique_violation + releitura.

create or replace function public.onboard_family(p_nome_familia text, p_nome text)
returns table (family_id uuid, profile_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := (select auth.uid());
    v_family uuid;
    v_profile uuid;
begin
    if v_uid is null then
        raise exception 'not authenticated' using errcode = '42501';
    end if;

    if p_nome_familia is null
       or p_nome is null
       or length(btrim(p_nome_familia)) not between 1 and 80
       or length(btrim(p_nome)) not between 1 and 80 then
        raise exception 'invalid name' using errcode = '22023';
    end if;

    select id into v_profile
    from public.profiles
    where id = v_uid;

    if found then
        return query
            select p.family_id, p.id
            from public.profiles p
            where p.id = v_uid;
        return;
    end if;

    select id into v_family
    from public.families
    where criado_por = v_uid;

    if found then
        if exists (select 1 from public.profiles p where p.family_id = v_family) then
            raise exception 'family already has profiles' using errcode = '23505';
        end if;
    else
        begin
            insert into public.families (nome, criado_por)
            values (btrim(p_nome_familia), v_uid)
            returning id into v_family;
        exception when unique_violation then
            select id into v_family
            from public.families
            where criado_por = v_uid;
            if not found then
                raise;
            end if;
            if exists (select 1 from public.profiles p where p.family_id = v_family) then
                raise exception 'family already has profiles' using errcode = '23505';
            end if;
        end;
    end if;

    begin
        insert into public.profiles (id, family_id, nome, papel, status)
        values (v_uid, v_family, btrim(p_nome), 'admin', 'ativo')
        returning id into v_profile;
    exception when unique_violation then
        select p.id, p.family_id into v_profile, v_family
        from public.profiles p
        where p.id = v_uid;
        if not found then
            raise;
        end if;
    end;

    return query select v_family, v_profile;
end;
$$;

revoke all on function public.onboard_family(text, text) from public, anon, authenticated;
grant execute on function public.onboard_family(text, text) to authenticated;
