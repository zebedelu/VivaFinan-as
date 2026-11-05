# Gate 0 — remediation B1–B8 (full spec)

**Data:** 2026-11-04
**Gate:** `@oracle` Conditional, tentativa 1 de 3.
**Decisão do usuário:** full spec (migrations novas + pgTAP), não cortar convite/forecast.
**Credenciais:** service role Admin API OK; `SUPABASE_DB_URL` no pooler `aws-1-us-west-2:6543` OK para multi-statement; restore testável.
**Regra:** nenhuma lane de backend/frontend começa antes deste remediation ser commitado e re-revisado pelo Oracle.

## B1 — ciclo de `recurring_occurrences`

- `GET /recurring/pending?mes=YYYY-MM-01` materializa, de forma idempotente, uma ocorrência `pendente` para cada regra ativa visível cujo dia de vencimento cai no mês, quando ainda não existe. Usa `POST /rest/v1/recurring_occurrences?on_conflict=rule_id,mes_referencia` com `Prefer: resolution=ignore-duplicates` e `return=representation`; devolve `occurrence_id`, dados da regra, `data_vencimento` (dia limitado ao último dia do mês) e `dias_para_vencimento`.
- `POST /transactions` público **não** aceita `recurring_rule_id`/`mes_referencia`; só o serviço interno de confirmação grava esses campos.
- Confirmar: `POST /recurring/occurrences/{id}/confirm` cria o lançamento (`data` = vencimento no mês, limitado; `valor` = override ou valor da regra; `escopo`/`category_id` da regra), depois atualiza a ocorrência (`confirmado`, `valor_confirmado`, `confirmado_por`, `confirmado_em`). Se o update falhar, apaga o lançamento criado; se o insert falhar, a ocorrência fica intacta. A unique `(recurring_rule_id, mes_referencia)` impede duplicata.
- `GET /dashboard` inclui `recorrentes_pendentes` (cartões de até 3 dias/atrasados); `/recurring` mostra todos.
- Testes: regra nova aparece; confirmar cria lançamento+ocorrência; duplicata recusada; apagar lançamento remove a ocorrência (trigger).

## B2/B3 — forecast familiar

- Nova RPC `public.family_forecast(p_family_id uuid, p_mes_fim date)` (fatia 1b), `security definer`, `stable`, `search_path=''`, checagem de membro ativo e mês inicial. Retorna 12 linhas `mes, receitas, despesas, recorrentes_receitas, recorrentes_despesas, variavel_receitas, variavel_despesas`; nunca `member_id`/descrição.
- Fórmula: para cada mês M de `p_mes_fim` a +11:
  - recorrentes: regras ativas com ao menos uma ocorrência `confirmado` nos 6 meses anteriores a `p_mes_fim`; usa o último `valor_confirmado` não nulo, senão `valor` da regra; regra ativa cujo dia cai em M; pendentes do mês corrente não entram.
  - variável: média dos 3 meses completos anteriores a `p_mes_fim` das transações com `recurring_rule_id is null`, por tipo; aplicada a todos os meses (estimativa estável; o mês corrente parcial não entra).
- `GET /forecast?escopo=familia` usa a RPC; `escopo=pessoal` usa o backend sobre os dados do próprio usuário (pode trazer detalhe por categoria/descrição).
- Testes: membro ativo 12 linhas; não membro/inativo/anon 42501; sem `member_id`/descrição; valores do fixture; pendente do mês corrente fora; regra com confirmação histórica projetada; média de 3 meses.

## B4 — convite/aceite

- Nova tabela `public.invites` (fatia 1b): `id`, `family_id`, `email`, `nome`, `papel` (`membro`), `status` (`pendente|aceito|cancelado`), `token uuid unique default gen_random_uuid()`, `criado_por`, `criado_em`, `aceito_em`; unique parcial `(family_id, lower(email)) where status='pendente'`; unique `(id, family_id)`.
- RLS: admin da família seleciona/insere/atualiza/cancela convites da própria família; convidado seleciona somente `lower(email)=lower(auth.email()) and status='pendente'`; sem insert/update direto do convidado.
- RPC `public.accept_invite(p_token uuid, p_nome text)`: `security definer`, `search_path=''`; exige `auth.uid()`, e-mail do JWT igual ao do convite, status `pendente`, sem perfil existente; cria `profiles` (`id=auth.uid`, `family_id`, `nome`, `papel` do convite, `ativo`), marca convite `aceito`; retorna o perfil. E-mail divergente/convite inválido/perfil existente → 42501/409.
- Backend: `POST /admin/invites` (admin) chama Admin API `POST /auth/v1/invite` com service role (503 sem chave) e insere a linha em `invites` com o JWT do admin; devolve `{invite_id, token, email}`. `POST /invites/accept` (autenticado) chama a RPC. `GET /admin/invites` lista pendentes; `DELETE /admin/invites/{id}` cancela.
- Frontend: `/invite/:token` (login/cadastro → aceite → dashboard); Settings/Admin com formulário de convite, lista de pendentes, link copiável; sem rota de aceite, o fluxo não existe.
- Testes: admin cria; não-admin recusa; convidado lê só o próprio; aceite cria perfil; e-mail/família/token errados recusam; perfil existente 409.

## B5 — ignore na demo

- Nova policy `bank_transactions_update_demo` (fatia 1b): `for update to authenticated using (private.owns_connection(bank_connection_id) and is_demo_sync) with check (private.owns_connection(bank_connection_id) and is_demo_sync and (transaction_id is null or private.can_view_transaction(transaction_id)))`.
- O grant de coluna continua só `status`; o trigger `tg_guard_bank_transaction_identity` só permite status/transaction_id; o dono pode marcar `ignorada`/`pendente_importacao` numa bank tx demo pendente; campos brutos continuam imutáveis.
- Atualizar `08_rls_banking_test.sql`: o dono atualiza o status de uma bank tx demo pendente (1 linha); outro membro não; campos brutos continuam bloqueados. O teste deixa de afirmar “demo 100% somente leitura”; a leitura/raw continua.
- Backend `/banking/ignore` funciona na demo; frontend mostra a ação. Documentar a exceção de status.

## B6 — contrato congelado

- Shapes de resposta documentados no plano 2: `transactions`, `goals`, `contributions`, `dashboard`, `alerts`, `banking`, `ai`. Incluir `pago_por_nome` e `member_nome` via `family_member_directory` (membro inativo → `null`/“Membro”).
- `SupabaseRest` usa `Prefer: return=representation` em POST/PATCH/DELETE; 0 linhas por RLS → 403/404, nunca 204 “sucesso”.
- `GET /api/health` (não `/health`); invariante: “sem `family_id` do cliente; `member_id` só `auth.uid()`; `pago_por` é a exceção D7”.
- `/dashboard` inclui `recorrentes_pendentes`; `/me/summary` inclui alertas pessoais.

## B7 — IA

- `POST /api/ai/classify` (já no plano) é usado no modal de lançamento e na importação bancária; mapeia nome→categoria da família.
- Geração: `GET /dashboard`/`GET /me/summary` chamam `suggest(context)` quando não há sugestões recentes e fazem upsert idempotente por `(family_id, member_id, titulo, o_que)`; `POST /ai/messages` gera e persiste; `ai_suggestions` não tem unique, então a deduplicação é do backend.
- `AIContext` inclui `media_3m` por categoria/tipo, `metas` com `prazo`/`dias_para_prazo` e `banco_pendentes`; o fallback usa isso e nunca inventa número.
- Testes: classificação; sugestões com os três campos; geração idempotente; timeout/500 → fallback; contexto família sem membro/descrição.

## B8 — onboarding

- Nova RPC `public.onboard_family(p_nome_familia text, p_nome text)` (fatia 1b), `security definer`, `search_path=''`: exige `auth.uid()`, se já existe perfil devolve o existente; se existe família criada pelo usuário sem perfil, adota; senão cria família+perfil admin na mesma transação; a trigger cria as 12 categorias. Nomes vazios → 22023.
- `GET /me` devolve `profile: null` quando não há perfil (não 404); o frontend redireciona para `/onboarding`; `POST /api/onboarding` chama a RPC (idempotente). O fluxo pós-confirmação de e-mail está coberto.
- Testes: novo usuário; perfil existente; família órfã; nomes vazios; categorias; papel admin.

## Outros ajustes obrigatórios

- Sync Pluggy: validar com o JWT que a conexão é do usuário antes de usar service role; `pluggy_connection_id` não pode reivindicar conexão alheia; service role pode escrever `bank_connections`/`bank_accounts`/`bank_transactions` na sync, mas só depois da checagem.
- Reconciliação: `GET /banking/reconcile-candidates?bank_transaction_id=` retorna lançamentos manuais com mesmo valor ±0,01 e data ±1 dia, sem vínculo; o frontend sugere.
- Reset de senha: `POST /auth/v1/recover` com anon key (sem service role) + `supabase.auth.updateUser({password})` na página de nova senha; não usar Admin API para definir senha.
- Desconexão: se houver chave Pluggy, chamar `DELETE /connections/{id}` antes de marcar `inativa`; sem chave, mock/no-op documentado.
- Sync lazy: ao abrir `/banking`, se `ultima_sync_em` > 24h ou nula, chamar `/sync`.
- Fluxos que faltavam: aceitar convite, recuperar/trocar senha, onboarding, central de notificações (sino), importação em lote, des-ignorar bank tx, contas previstas no painel.
- E2E: com o pooler 6543, o restore é testável; o E2E restaura a demo ao final. O access token do Supabase é autocontido: apagar `auth.sessions` invalida refresh, não o access até exp; o sign out é UX, não revogação — documentar.
- Ownership: `test_ai_api.py` é do backend; `test_ai_service*` da IA. A IA entrega `base.py`/`__init__.py` antes de o backend importar; o backend usa stub até a fase 1c.
- Commit dos planos/setup antes de liberar código.
- Lane de migrations 1b com pgTAP e gate de RLS; sem isso, backend improvisaria service role.
