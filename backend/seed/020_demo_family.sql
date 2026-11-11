-- Fatia 1 - Task 13: familia e perfis demo.
-- O trigger de familias cria as 12 categorias padrao.

insert into public.families (id, nome, criado_por, is_demo) values
    ('eeeeeeee-0000-4000-8000-000000000001', 'Família Demo', 'eeeeeeee-0000-4000-8000-0000000000a1', true);

insert into public.profiles (id, family_id, nome, papel, status) values
    ('eeeeeeee-0000-4000-8000-0000000000a1', 'eeeeeeee-0000-4000-8000-000000000001', 'Ana', 'admin', 'ativo'),
    ('eeeeeeee-0000-4000-8000-0000000000b2', 'eeeeeeee-0000-4000-8000-000000000001', 'Carlos', 'membro', 'ativo'),
    ('eeeeeeee-0000-4000-8000-0000000000c3', 'eeeeeeee-0000-4000-8000-000000000001', 'Lucas', 'membro', 'ativo');
