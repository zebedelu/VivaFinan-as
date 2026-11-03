-- Fatia 1 - Task 6: triggers de identidade e categorias padrão.

create or replace function public.tg_seed_default_categories()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into public.categories (family_id, nome, tipo, personalizada, oculta) values
        (new.id, 'Alimentação', 'despesa', false, false),
        (new.id, 'Moradia', 'despesa', false, false),
        (new.id, 'Transporte', 'despesa', false, false),
        (new.id, 'Saúde', 'despesa', false, false),
        (new.id, 'Educação', 'despesa', false, false),
        (new.id, 'Lazer', 'despesa', false, false),
        (new.id, 'Assinaturas', 'despesa', false, false),
        (new.id, 'Outros', 'despesa', false, false),
        (new.id, 'Salário', 'receita', false, false),
        (new.id, 'Freelance', 'receita', false, false),
        (new.id, 'Investimentos', 'receita', false, false),
        (new.id, 'Outros', 'receita', false, false);
    return new;
end;
$$;

create or replace function public.tg_guard_profile_update()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_uid uuid := (select auth.uid());
begin
    if new.id <> old.id or new.family_id <> old.family_id or new.papel <> old.papel then
        raise exception 'profile identity is immutable' using errcode = '42501';
    end if;

    if old.papel = 'admin' and new.status = 'inativo' then
        if not exists (
            select 1 from public.profiles p
            where p.family_id = old.family_id
              and p.papel = 'admin'
              and p.status = 'ativo'
              and p.id <> old.id
        ) then
            raise exception 'last active admin cannot be deactivated' using errcode = '42501';
        end if;
    end if;

    if new.status <> old.status and v_uid is not null then
        if not private.is_admin_of(old.family_id) then
            raise exception 'only an active admin can change status' using errcode = '42501';
        end if;
    end if;

    if new.tema <> old.tema and v_uid is not null and v_uid <> old.id then
        raise exception 'theme can only be changed by the owner' using errcode = '42501';
    end if;

    return new;
end;
$$;

create or replace function public.tg_guard_family_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.is_demo <> old.is_demo or new.criado_por <> old.criado_por then
        raise exception 'family identity is immutable' using errcode = '42501';
    end if;
    return new;
end;
$$;

create or replace function public.tg_guard_category_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if old.personalizada = false then
        if new.nome <> old.nome
           or new.tipo <> old.tipo
           or new.family_id <> old.family_id
           or new.criado_por is distinct from old.criado_por
           or new.personalizada <> old.personalizada then
            raise exception 'default category can only be hidden' using errcode = '42501';
        end if;
    else
        if new.family_id <> old.family_id
           or new.criado_por is distinct from old.criado_por
           or new.personalizada <> old.personalizada then
            raise exception 'custom category identity is immutable' using errcode = '42501';
        end if;
        if new.tipo <> old.tipo and private.category_in_use(old.id) then
            raise exception 'category type cannot change while in use' using errcode = '42501';
        end if;
    end if;
    return new;
end;
$$;

create trigger tg_seed_default_categories
after insert on public.families
for each row execute function public.tg_seed_default_categories();

create trigger tg_guard_profile_update
before update on public.profiles
for each row execute function public.tg_guard_profile_update();

create trigger tg_guard_family_update
before update on public.families
for each row execute function public.tg_guard_family_update();

create trigger tg_guard_category_update
before update on public.categories
for each row execute function public.tg_guard_category_update();
