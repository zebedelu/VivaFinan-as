-- Fatia 1b - dedup idempotente de sugestoes de IA.
-- O backend trata 23505 como "sugestao ja existe".

create unique index ai_suggestions_dedup_key
on public.ai_suggestions (
    family_id,
    coalesce(member_id, '00000000-0000-0000-0000-000000000000'::uuid),
    titulo,
    o_que
);
