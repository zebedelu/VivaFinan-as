-- Gate 1b - rastreia o usuário Auth criado pelo convite.
-- O backend grava o id devolvido pela Admin API em /admin/invites e o usa
-- para apagar o usuário quando o convite é cancelado.

alter table public.invites add column if not exists auth_user_id uuid;
