# Fatia 1b — migrations de fechamento (v1 full spec) — v2

**Data:** 2026-11-04
**Depende de:** fatia 1 (`629fce9`), 350/350 pgTAP.
**Gate 0:** attempt 3 final; remediation + contrato canônico; plano 1b v2 aprovado condicional.
**Decisão:** full spec; DB URL no pooler `aws-1-us-west-2:6543` OK; service role OK.
**Ownership:** lane de migrations escreve `supabase/migrations/2026110400*.sql`, `supabase/tests/14_*`..`18_*` e o ajuste de `08_rls_banking_test.sql`. Nenhuma lane de backend/frontend toca nesses arquivos.

## Objetivo

Fechar os buracos de schema/contrato do gate 0 sem service role em leitura/escrita normal:

1. `invites` + RPC `accept_invite` (convite/aceite).
2. RPC `family_forecast` (forecast familiar sem membro/descrição).
3. RPC `onboard_family` (onboarding atômico/idempotente).
4. Policy `bank_transactions_update_demo` (dono ignora bank tx demo; só status).
5. RPC `confirm_occurrence` (confirmação atômica de recorrente; sem compensação destrutiva).
6. Índice único de dedup de `ai_suggestions` (geração idempotente).
7. Ajuste do teste 08 e da suíte.

## Correções do gate 0 attempt 3

- `invites.family_nome` snapshot (1..80); se `20261104000100` já aplicada, criar `20261104000700_invites_family_nome.sql`; incluir no test 14.
- `accept_invite`: validar `p_nome`/`v_inv.nome` com 1..80 (22023).
- `onboard_family`: tratar corrida `unique_violation` 23505 relendo e devolvendo o perfil/família existente.
- `confirm_occurrence`: data do lançamento = `least(vencimento, hoje em America/Sao_Paulo)`; ajustar test 17.

## Migrations

### 1. `20261104000100_invites.sql`

```sql
create table public.invites (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  email text not null check (length(btrim(email)) between 3 and 254),
  nome text not null check (length(btrim(nome)) between 1 and 80),
  papel text not null default 'membro' check (papel = 'membro'),
  status text not null default 'pendente' check (status in ('pendente','aceito','cancelado')),
  token uuid not null default gen_random_uuid() unique,
  criado_por uuid not null references public.profiles(id) on delete cascade,
  criado_em timestamptz not null default now(),
  aceito_em timestamptz
);
create unique index invites_pending_email_key on public.invites (family_id, lower(email)) where status = 'pendente';
alter table public.invites enable row level security;
revoke all on public.invites from public, anon, authenticated;
grant select, insert, update, delete on public.invites to authenticated;
```

RLS:
- `invites_select`: admin da família (`private.is_admin_of(family_id)`) **ou** convidado (`lower(email) = lower(auth.email()) and status='pendente'`).
- `invites_insert`: admin da família e `criado_por = auth.uid()`.
- `invites_update`: admin da família; `using` e `with check` explícitos.
- `invites_delete`: admin da família.

RPC:
```sql
create or replace function public.accept_invite(p_token uuid, p_nome text)
returns table (profile_id uuid, family_id uuid)
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_email text := (select auth.email());
  v_inv public.invites;
  v_nome text;
begin
  if v_uid is null or v_email is null then raise exception 'not authenticated' using errcode='42501'; end if;
  select * into v_inv from public.invites where token = p_token and status = 'pendente' for update;
  if not found then raise exception 'invite not found' using errcode='42501'; end if;
  if lower(v_inv.email) <> lower(v_email) then raise exception 'invite email mismatch' using errcode='42501'; end if;
  if exists (select 1 from public.profiles where id = v_uid) then raise exception 'profile already exists' using errcode='23505'; end if;
  v_nome := coalesce(nullif(btrim(p_nome), ''), v_inv.nome);
  insert into public.profiles (id, family_id, nome, papel, status)
  values (v_uid, v_inv.family_id, v_nome, 'membro', 'ativo');
  update public.invites set status='aceito', aceito_em=now() where id = v_inv.id;
  return query select v_uid, v_inv.family_id;
end; $$;
revoke all on function public.accept_invite(uuid, text) from public, anon, authenticated;
grant execute on function public.accept_invite(uuid, text) to authenticated;
```

O backend mapeia `23505` para HTTP 409. O convite só cria membro; admin continua imutável (D2). `GET /invites/mine` (backend, RLS select) devolve o convite pendente do e-mail do JWT; o onboarding checa isso antes de criar família.

### 2. `20261104000200_family_forecast.sql`

```sql
create or replace function public.family_forecast(p_family_id uuid, p_mes_inicio date)
returns table (mes date, receitas numeric, despesas numeric,
               recorrentes_receitas numeric, recorrentes_despesas numeric,
               variavel_receitas numeric, variavel_despesas numeric)
language sql stable security definer set search_path = '' as $$
  -- assert_family_member + assert_month_start; 12 linhas; agregados sem membro/descricao.
$$;
revoke all on function public.family_forecast(uuid, date) from public, anon, authenticated;
grant execute on function public.family_forecast(uuid, date) to authenticated;
```

Janela e fórmula:
- `p_mes_inicio` é o **primeiro mês previsto** (o backend passa o primeiro dia do mês seguinte ao corrente) e precisa ser o primeiro dia; 12 linhas `p_mes_inicio + 0..11 months`.
- Recorrentes: regras ativas com ao menos uma ocorrência `confirmado` nos 6 meses que terminam no mês anterior a `p_mes_inicio`, inclusive (`>= p_mes_inicio - 6 months` e `< p_mes_inicio`); o mês corrente entra. Valor = último `valor_confirmado` não nulo ordenado por `mes_referencia desc, confirmado_em desc`, senão `valor` da regra. Todas as regras ativas com confirmação histórica entram em todos os meses; o dia de vencimento não filtra o agregado (o clamp torna todo dia 1..31 válido em todo mês).
- Variável: média dos 3 meses completos anteriores ao mês corrente (`>= p_mes_inicio - 4 months` e `< p_mes_inicio - 1 month`) das transações com `recurring_rule_id is null`, por tipo; aplicada aos 12 meses. O mês corrente parcial não entra.
- Retorna apenas agregados; sem `member_id`, descrição, categoria individual ou linha de membro.

### 3. `20261104000300_onboard_family.sql`

```sql
create or replace function public.onboard_family(p_nome_familia text, p_nome text)
returns table (family_id uuid, profile_id uuid)
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_family uuid; v_profile uuid;
begin
  if v_uid is null then raise exception 'not authenticated' using errcode='42501'; end if;
  if p_nome_familia is null or p_nome is null
     or length(btrim(p_nome_familia)) not between 1 and 80
     or length(btrim(p_nome)) not between 1 and 80
     then raise exception 'invalid name' using errcode='22023'; end if;
  select id into v_profile from public.profiles where id = v_uid;
  if found then return query select family_id, v_uid from public.profiles where id = v_uid; return; end if;
  select id into v_family from public.families where criado_por = v_uid;
  if not found then
    insert into public.families (nome, criado_por) values (btrim(p_nome_familia), v_uid) returning id into v_family;
  end if;
  insert into public.profiles (id, family_id, nome, papel, status)
  values (v_uid, v_family, btrim(p_nome), 'admin', 'ativo') returning id into v_profile;
  return query select v_family, v_profile;
end; $$;
revoke all on function public.onboard_family(text, text) from public, anon, authenticated;
grant execute on function public.onboard_family(text, text) to authenticated;
```

A trigger `tg_seed_default_categories` cria as 12 categorias ao inserir a família. Se a família órfã já tem perfis (estado impossível), a RPC levanta 23505.

### 4. `20261104000400_demo_bank_ignore.sql`

```sql
create policy bank_transactions_update_demo on public.bank_transactions
for update to authenticated
using (private.owns_connection(bank_connection_id) and is_demo_sync)
with check (private.owns_connection(bank_connection_id) and is_demo_sync
            and (transaction_id is null or private.can_view_transaction(transaction_id)));
```

- O grant de coluna continua só `status`; o trigger `tg_guard_bank_transaction_identity` só permite status/transaction_id; o dono pode ignorar/voltar uma bank tx demo **pendente**; campos brutos continuam imutáveis.
- Atualizar `supabase/tests/08_rls_banking_test.sql`: o dono atualiza o status de uma bank tx demo pendente (1 linha); outro membro não; campos brutos continuam bloqueados. A asserção “dados brutos da demo continuam somente leitura” vira “status da demo é editável pelo dono; raw continua bloqueado”. Ajustar o `plan()`.
- O teste 13 (vínculo bancário) não muda.

### 5. `20261104000500_confirm_occurrence.sql`

```sql
create or replace function public.confirm_occurrence(p_occurrence_id uuid, p_valor numeric default null)
returns uuid
language plpgsql security invoker set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_occ public.recurring_occurrences;
  v_rule public.recurring_rules;
  v_data date;
  v_valor numeric;
  v_tx uuid;
begin
  if v_uid is null then raise exception 'not authenticated' using errcode='42501'; end if;
  select * into v_occ from public.recurring_occurrences where id = p_occurrence_id;
  if not found or v_occ.status <> 'pendente' then raise exception 'occurrence not pending' using errcode='42501'; end if;
  select * into v_rule from public.recurring_rules where id = v_occ.rule_id and ativo;
  if not found then raise exception 'rule not active' using errcode='42501'; end if;
  if p_valor is not null and p_valor <= 0 then raise exception 'invalid value' using errcode='22023'; end if;
  v_valor := coalesce(p_valor, v_rule.valor);
  v_data := least(
    (v_occ.mes_referencia + ((v_rule.dia_vencimento - 1) || ' days')::interval)::date,
    (date_trunc('month', v_occ.mes_referencia) + interval '1 month - 1 day')::date
  );
  insert into public.transactions
    (family_id, member_id, tipo, escopo, valor, descricao, category_id, data, criado_por, origem, recurring_rule_id, mes_referencia)
  values
    (v_rule.family_id, v_uid, v_rule.tipo, v_rule.escopo, v_valor, v_rule.descricao, v_rule.category_id, v_data, v_uid, 'manual', v_rule.id, v_occ.mes_referencia)
  returning id into v_tx;
  update public.recurring_occurrences
     set status='confirmado', valor_confirmado=v_valor, confirmado_por=v_uid, confirmado_em=now()
   where id = v_occ.id and status='pendente';
  if not found then raise exception 'occurrence already decided' using errcode='42501'; end if;
  return v_tx;
end; $$;
revoke all on function public.confirm_occurrence(uuid, numeric) from public, anon, authenticated;
grant execute on function public.confirm_occurrence(uuid, numeric) to authenticated;
```

`security invoker` de propósito: as policies de INSERT/UPDATE e a RLS do usuário valem; a função é atômica (insert+update na mesma transação) e não precisa de compensação. Se a ocorrência já foi decidida em corrida, o UPDATE não acha e a exceção desfaz o insert. O backend `POST /recurring/occurrences/{id}/confirm` chama a RPC; não apaga nada.

### 6. `20261104000600_ai_suggestion_dedup.sql`

```sql
create unique index ai_suggestions_dedup_key
on public.ai_suggestions (
  family_id,
  coalesce(member_id, '00000000-0000-0000-0000-000000000000'::uuid),
  titulo,
  o_que
);
```

O backend tenta inserir a sugestão; `23505` significa que já existe e é ignorado. A dedup é idempotente mesmo com duas aberturas simultâneas do painel. O seed tem 4 sugestões distintas; o índice não muda a contagem.

## Testes pgTAP

| Arquivo | Prefixo | Cobre |
|---|---|---|
| `14_invites_test.sql` | `dd000000` | admin cria; não-admin recusa; convidado lê só o próprio; aceite cria perfil membro; e-mail/token/família errados; perfil existente 23505; RLS/hardening |
| `15_family_forecast_test.sql` | `ab000000` | membro ativo 12 linhas; não membro/inativo/anon 42501; sem `member_id`/descrição; janela/linha 0; pendente fora; regra histórica; média 3 meses |
| `16_onboard_family_test.sql` | `ac000000` | novo usuário cria família/perfil admin/12 categorias; perfil existente idempotente; família órfã adotada; nomes nulos/vazios 22023; não autenticado 42501 |
| `17_confirm_occurrence_test.sql` | `ad000000` | pendente→confirmado; transação criada; duplicata recusada; ocorrência de outro membro/inativa; rollback em corrida; família/pessoal |
| `18_ai_suggestion_dedup_test.sql` | `ae000000` | duplicata 23505; sugestões distintas passam; seed 4 intacto |
| `08_rls_banking_test.sql` | `88000000` | dono atualiza status demo; outro não; raw bloqueado; `plan()` atualizado |

Os testes usam `tap_out`, `begin`/`rollback`, `set local role authenticated` e GUC `request.jwt.claim.sub`; os testes de invite também setam `request.jwt.claim.email`. O MCP devolve o TAP; a suíte é arquivo a arquivo.

## Ordem de aplicação

1. `20261104000100_invites.sql` via MCP `apply_migration(name='invites')`.
2. `20261104000200_family_forecast.sql` via MCP `apply_migration(name='family_forecast')`.
3. `20261104000300_onboard_family.sql` via MCP `apply_migration(name='onboard_family')`.
4. `20261104000400_demo_bank_ignore.sql` via MCP `apply_migration(name='demo_bank_ignore')`.
5. `20261104000500_confirm_occurrence.sql` via MCP `apply_migration(name='confirm_occurrence')`.
6. `20261104000600_ai_suggestion_dedup.sql` via MCP `apply_migration(name='ai_suggestion_dedup')`.
7. Rodar 14–18 e 08 via MCP; depois os 15 arquivos antigos + 13; a suíte final deve ficar verde com a contagem nova.
8. `get_advisors('security')`: WARNs esperados documentados (3 security definer + multiple_permissive_policies); as RPCs `security definer` só para `authenticated`; `anon` sem execute; `invites` sem ALL/default privileges.
9. Seed 2x + login demo; o demo não muda.

## Aceite

- 6 migrations aplicadas; testes 14–18 verdes; 08 ajustado e verde; suíte antiga + nova verde.
- `family_forecast` sem `member_id`/descrição; `accept_invite`/`onboard_family` só `authenticated`; `invites` com RLS/hardening; `confirm_occurrence` atômica; dedup de IA.
- Demo ignore só status; raw continua bloqueado; C1/13 intacto.
- Nenhum service role em leitura/escrita normal; nenhuma credencial no repo.
- Gate `@oracle` de RLS/contrato após a fase 1a; re-review do gate 0 antes de codar backend/frontend.

## Riscos

- O pooler 6543 é transaction mode; os testes via MCP não usam essa conexão; o restore usa uma transação por conexão e foi testado com `begin/rollback`.
- `auth.email()` depende do claim `email`; o teste seta `request.jwt.claim.email`; em produção o GoTrue inclui o claim.
- A policy demo ignore é uma exceção deliberada à leitura bruta; documentar no README e no handoff.
- O forecast familiar é uma estimativa; a UI rotula “estimativa” e explica a fórmula.
- `confirm_occurrence` é `security invoker`; se o usuário não vê a regra/ocorrência, a RLS já recusa.
