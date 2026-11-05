# Fatia 1b — migrations de fechamento (v1 full spec)

**Data:** 2026-11-04
**Depende de:** fatia 1 (`629fce9`), 350/350 pgTAP.
**Gate 0:** Conditional; remediation em `docs/plans/2026-11-04-gate0-remediation.md`.
**Decisão:** full spec; nada de cortar convite/forecast/ignore.
**Ownership:** lane de migrations escreve `supabase/migrations/2026110400*.sql`, `supabase/tests/14_*`..`16_*` e o ajuste de `08_rls_banking_test.sql`. Nenhuma lane de backend/frontend toca nesses arquivos.

## Objetivo

Fechar os buracos de schema/contrato que o gate apontou, sem service role em leitura/escrita normal:

1. `invites` + RPC `accept_invite` para convite/aceite.
2. RPC `family_forecast` para o forecast familiar sem vazar membro/descrição.
3. RPC `onboard_family` para onboarding atômico/idempotente.
4. Policy `bank_transactions_update_demo` para o dono ignorar bank tx demo (só status).
5. Ajustar o teste 08 e a suíte para o novo comportamento.

## Migrations

### 1. `20261104000100_invites.sql`

```sql
create table public.invites (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  email text not null check (length(btrim(email)) between 3 and 254),
  nome text not null check (length(btrim(nome)) between 1 and 80),
  papel text not null default 'membro' check (papel in ('admin','membro')),
  status text not null default 'pendente' check (status in ('pendente','aceito','cancelado')),
  token uuid not null default gen_random_uuid() unique,
  criado_por uuid not null references public.profiles(id) on delete cascade,
  criado_em timestamptz not null default now(),
  aceito_em timestamptz,
  unique (id, family_id)
);
create unique index invites_pending_email_key on public.invites (family_id, lower(email)) where status = 'pendente';
alter table public.invites enable row level security;
```

RLS:
- `invites_select`: admin da família (`private.is_admin_of(family_id)`) **ou** convidado (`lower(email) = lower(auth.email()) and status='pendente'`).
- `invites_insert`: admin da família e `criado_por = auth.uid()`.
- `invites_update`: admin da família (cancelar).
- `invites_delete`: admin da família.
- `grant select, insert, update, delete on public.invites to authenticated; revoke all from anon;`

RPC:
```sql
create or replace function public.accept_invite(p_token uuid, p_nome text)
returns table (profile_id uuid, family_id uuid)
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_email text := (select auth.email()); v_inv public.invites;
begin
  if v_uid is null or v_email is null then raise exception 'not authenticated' using errcode='42501'; end if;
  select * into v_inv from public.invites where token = p_token and status = 'pendente' for update;
  if not found then raise exception 'invite not found' using errcode='42501'; end if;
  if lower(v_inv.email) <> lower(v_email) then raise exception 'invite email mismatch' using errcode='42501'; end if;
  if exists (select 1 from public.profiles where id = v_uid) then raise exception 'profile already exists' using errcode='409'; end if;
  insert into public.profiles (id, family_id, nome, papel, status)
  values (v_uid, v_inv.family_id, coalesce(nullif(btrim(p_nome), ''), v_inv.nome), v_inv.papel, 'ativo');
  update public.invites set status='aceito', aceito_em=now() where id = v_inv.id;
  return query select v_uid, v_inv.family_id;
end; $$;
revoke all on function public.accept_invite(uuid, text) from public, anon, authenticated;
grant execute on function public.accept_invite(uuid, text) to authenticated;
```

### 2. `20261104000200_family_forecast.sql`

```sql
create or replace function public.family_forecast(p_family_id uuid, p_mes_fim date)
returns table (mes date, receitas numeric, despesas numeric,
               recorrentes_receitas numeric, recorrentes_despesas numeric,
               variavel_receitas numeric, variavel_despesas numeric)
language sql stable security definer set search_path = '' as $$
  -- assert_family_member + assert_month_start; 12 meses; agregados sem membro/descricao.
$$;
revoke all on function public.family_forecast(uuid, date) from public, anon, authenticated;
grant execute on function public.family_forecast(uuid, date) to authenticated;
```

Fórmula:
- `p_mes_fim` é o primeiro dia do mês; 12 linhas (`+0..+11`).
- Recorrentes: regras ativas com ao menos uma ocorrência `confirmado` nos 6 meses anteriores a `p_mes_fim`; valor = último `valor_confirmado` não nulo, senão `valor` da regra; a regra entra no mês M se o dia de vencimento cai em M (clamp no último dia). Pendentes do mês corrente não entram.
- Variável: média dos 3 meses completos anteriores a `p_mes_fim` das transações com `recurring_rule_id is null`, por tipo; aplicada a todos os 12 meses (mês corrente parcial não entra).
- Retorna apenas agregados; sem `member_id`, descrição, categoria individual ou linha de membro.

### 3. `20261104000300_onboard_family.sql`

```sql
create or replace function public.onboard_family(p_nome_familia text, p_nome text)
returns table (family_id uuid, profile_id uuid)
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_family uuid; v_profile uuid;
begin
  if v_uid is null then raise exception 'not authenticated' using errcode='42501'; end if;
  if length(btrim(p_nome_familia)) not between 1 and 80 or length(btrim(p_nome)) not between 1 and 80
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

A trigger `tg_seed_default_categories` cria as 12 categorias ao inserir a família. Se a família órfã já tem perfis (estado impossível), a RPC levanta 409.

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

## Testes pgTAP

| Arquivo | Prefixo | Cobre |
|---|---|---|
| `14_invites_test.sql` | `dd000000` | admin cria; não-admin recusa; convidado lê só o próprio; aceite cria perfil; e-mail/token/família errados; perfil existente 409; RLS |
| `15_family_forecast_test.sql` | `ab000000` | membro ativo 12 linhas; não membro/inativo/anon 42501; sem `member_id`/descrição; valores; pendente fora; regra histórica; média 3 meses; `prosecdef`/`search_path` |
| `16_onboard_family_test.sql` | `ac000000` | novo usuário cria família/perfil admin/12 categorias; perfil existente idempotente; família órfã adotada; nomes vazios 22023; não autenticado 42501 |
| `08_rls_banking_test.sql` | `88000000` | ajuste do ignore demo: dono atualiza status; outro não; raw bloqueado; `plan()` atualizado |

Os testes usam `tap_out`, `begin`/`rollback`, `set local role authenticated` e GUC `request.jwt.claim.sub`; os testes de invite também setam `request.jwt.claim.email`. O MCP devolve o TAP; a suíte é arquivo a arquivo.

## Ordem de aplicação

1. `20261104000100_invites.sql` via MCP `apply_migration(name='invites')`.
2. `20261104000200_family_forecast.sql` via MCP `apply_migration(name='family_forecast')`.
3. `20261104000300_onboard_family.sql` via MCP `apply_migration(name='onboard_family')`.
4. `20261104000400_demo_bank_ignore.sql` via MCP `apply_migration(name='demo_bank_ignore')`.
5. Rodar 14, 15, 16 e 08 via MCP; depois os 15 arquivos antigos + 13; a suíte final deve ficar verde com a contagem nova.
6. `get_advisors('security')`: sem novo WARN; as RPCs `security definer` só para `authenticated`; `anon` sem execute.
7. Seed 2x + login demo; o demo não muda.

## Aceite

- 4 migrations aplicadas; testes 14/15/16 verdes; 08 ajustado e verde; suíte antiga + nova verde.
- `family_forecast` sem `member_id`/descrição; `accept_invite`/`onboard_family` só `authenticated`; `invites` com RLS.
- Demo ignore só status; raw continua bloqueado; C1/13 intacto.
- Nenhum service role em leitura/escrita normal; nenhuma credencial no repo.
- Gate `@oracle` de RLS/contrato após a fase 1a; re-review do gate 0 antes de codar backend/frontend.

## Riscos

- O pooler 6543 é transaction mode; os testes via MCP não usam essa conexão; o restore usa uma transação por conexão, o que funciona no teste `begin/rollback`.
- `auth.email()` depende do claim `email` no JWT; o teste seta `request.jwt.claim.email`; em produção o GoTrue inclui o claim.
- A policy demo ignore é uma exceção deliberada à leitura bruta; documentar no README e no handoff.
- O forecast familiar é uma estimativa; a UI rotula “estimativa” e explica a fórmula.
