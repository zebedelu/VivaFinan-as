# VivaFinanças — Fatia 1: Supabase (schema, RLS e seed demo) — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar a base de dados da v1 do VivaFinanças no Supabase — 13 tabelas, constraints, triggers, RLS por membro, funções de leitura agregada e Família Demo com 6 meses de histórico — de forma testável localmente e sem nenhuma credencial bancária no banco.

**Architecture:** Migrations SQL versionadas no Supabase CLI, com RLS como camada primária de privacidade e funções `security definer` restritas para os agregados do painel familiar. O seed demo é SQL idempotente e usa usuários de Auth locais com senha bcrypt. Nenhum código de Flask ou React é criado nesta fatia.

**Tech Stack:** Supabase (Postgres + Auth), Supabase CLI, pgTAP, SQL, pgcrypto.

**Spec:** `C:\Users\vinic\Desktop\VivaFinancas\docs\2026-10-27-vivafinancas-brainstorming.md` (v2.0; vence o design de 2026-10-20 e o PDF). O executor lê a spec inteira antes da primeira tarefa.

**Status:** planejamento. Nada é construído antes da aprovação do parceiro (spec §1, §9). Este documento não implementa, não cria repositório git e não faz commit.

---

## 0. Decisões de produto fechadas em 2026-11-03

Estas respostas substituem as perguntas técnicas que estavam no plano. As escolhas técnicas abaixo delas são minhas, guiadas pela privacidade e pelo escopo da spec.

- **Painel familiar:** mostra avatares e nomes dos membros, sem nenhum valor individual. Cada avatar leva à página da pessoa.
- **Família Demo:** o visitante pode explorar e testar. Um botão “Restaurar demo” volta os dados ao estado original. O flag `is_demo` continua imutável; os dados brutos da conexão simulada são somente leitura, mas importar/reconciliar um lançamento a partir das transações pendentes é permitido e o restore desfaz.
- **Metas da família:** qualquer membro ativo pode editar; só quem criou pode excluir. Metas pessoais continuam visíveis e editáveis apenas pelo dono.
- **Jev AI:** o campo `lida` é leitura compartilhada na v1. Uma sugestão da família some do sino quando qualquer membro a lê. Leitura por pessoa fica para uma v2, se o produto pedir.
- **Sincronização bancária:** o extrato tenta sincronizar ao abrir, se a última sincronização passou de 24h, e oferece o botão “Sincronizar agora”. Nada de cron diário na v1.
- **Visual:** direção “Editorial acolhedor”, detalhada na §2.3. A skill `frontend-design` conduz a fatia 3.
- **Categorias padrão:** 8 de despesa (Alimentação, Moradia, Transporte, Saúde, Educação, Lazer, Assinaturas, Outros) e 4 de receita (Salário, Freelance, Investimentos, Outros). Categorias personalizadas continuam disponíveis.
- **Pluggy:** validação de endpoints, header, widget, webhooks e sandbox é trabalho técnico da fatia 2, não uma pergunta de produto.

---

## 1. Scope Check e corte de escopo

A spec cobre **quatro subsistemas independentes**. Empacotar tudo em um plano só produziria um documento impossível de revisar e tarefas que não entregam software testável sozinhas. Corte proposto:

| # | Fatia | O que entrega | Depende de |
|---|---|---|---|
| **1** | **Supabase / RLS + seed** (este plano) | Migrations, constraints, triggers, políticas RLS, funções de leitura familiar, seed demo, testes pgTAP | — |
| 2 | Backend Flask + Pluggy | App factory, validação de JWT, clientes Supabase, models/schemas/controllers, endpoints REST, `PluggyAdapter`, `PluggySyncService`, `PluggyImportService`, testes pytest | Fatia 1 |
| 3 | Frontend React | Vite + Tailwind + Recharts, autenticação, páginas, componentes/hooks/services, widget Pluggy, direção visual própria, testes de UI | Fatias 1 e 2 |
| 4 | Jev AI | `JevAIAdapter`, `FallbackLLMAdapter`, prompts, classificação, sugestões, failover, modo degradado, testes | Fatia 2 |

**Por que a fatia 1 primeiro:** é a fonte da verdade da privacidade (spec §4.4). Sem schema, RLS e seed testados, o backend não tem contrato confiável e o frontend não tem dados para exibir. A spec §9 já fixa essa ordem: monorepo → Supabase → backend → frontend → Jev AI.

**Contrato entre fatias:**
- A fatia 2 consome o schema e as funções desta fatia; o Flask usa o **JWT do usuário** em todas as consultas de dados e a **service role** apenas para Admin API, seed e sincronização Pluggy (spec §4.4). A restauração da demo usa conexão Postgres direta, não a service role.
- A fatia 2 expõe `POST /api/demo/restore` para o botão “Restaurar demo”. O endpoint reexecuta os arquivos de `supabase/seed/` dentro de uma transação usando uma conexão Postgres direta (`SUPABASE_DB_URL`), não a service role key; a service role continua restrita a PostgREST/Admin API. O endpoint só aceita chamadas de um membro da Família Demo. O seed da Task 13 é a fonte única da restauração.
- A fatia 2 não cria tabelas novas sem uma migration nesta fatia ou em migration própria acordada.
- A fatia 3 consome apenas a API REST; nunca recebe `SUPABASE_SERVICE_ROLE_KEY`, `PLUGGY_API_KEY` ou `JEV_AI_API_KEY`.
- A fatia 4 implementa a interface de IA que a fatia 2 deixou como stub/fallback; não altera o schema.

**Este documento entrega somente a fatia 1 completa.** As fatias 2–4 terão planos próprios em `docs/plans/`, após a aprovação deste.

---

## 2. Regras de execução (valem para todas as tarefas)

### 2.1 Lista de to-dos da sessão

- Ao iniciar a execução, criar uma lista de to-dos com os títulos das tarefas 1–14 deste plano.
- Manter **exatamente uma** tarefa `in_progress`; as demais ficam `pending` ou `completed`.
- Marcar `completed` somente depois que o comando de verificação da tarefa passar e a saída tiver sido lida.
- Se uma tarefa for dividida, adicionar subtarefas com o mesmo critério de aceite; não remover tarefa sem registrar o motivo.
- A lista de to-dos é a fonte de verdade do progresso; este plano é a fonte de verdade do escopo.

### 2.2 Ponytail (filosofia de implementação)

- Cada tarefa implementa **o menor código que faz o teste passar**. Nada de abstração, tabela, trigger, função, índice ou coluna que não seja exigida por um teste ou pela spec.
- Se um teste passa sem uma camada extra, a camada extra não entra.
- Não “melhorar” nomes, status ou estruturas da spec sem registrar a decisão na §9.
- SQL repetido em testes é aceitável; helper de teste compartilhado que exige infraestrutura nova não é.

### 2.3 Frontend-design (direção aprovada em 2026-11-03)

- Toda tarefa de UI carrega a skill `frontend-design` **antes** de escrever JSX/Tailwind.
- Direção aprovada: **Editorial acolhedor**. Verde institucional profundo `#1F4D3A`, fundo areia `#F4EFE6`, superfície `#FBF8F2`, texto grafite `#22201D`, terracota `#C46A4A` para despesas/alertas e dourado `#C9A227` para metas.
- Tipografia: **Fraunces** nos títulos e no saldo grande; **IBM Plex Sans** no corpo, formulários e navegação; números com `font-variant-numeric: tabular-nums`. Nada de Inter, Roboto ou system-ui como fonte principal.
- Layout mobile-first: navegação inferior com Início, Lançamentos, Extrato e Mais; botão “+” sempre visível para novo lançamento; no desktop, sidebar à esquerda e conteúdo até 1200px. Cartões com borda fina de 1px, raio de 12px e sombra discreta, sem gradientes roxos nem excesso de badges.
- O visual de “caderno de contas” aparece em detalhes: linhas finas nos gráficos, réguas discretas nas listas e valores alinhados à direita. O verde é a cor de marca; terracota e dourado entram só onde há significado.
- A fatia 3 abre com uma tarefa 0 que transforma esta direção em tokens (cores, tipos, espaçamento, raios) e uma página de referência. Nenhuma tela começa antes disso.

### 2.4 MVC e fronteiras

| Camada | Onde mora | Regra |
|---|---|---|
| Banco | `supabase/migrations/`, `supabase/seed/`, `supabase/tests/` | Schema/constraints em migrations; dados em seed; contrato em testes |
| Flask — models | `backend/app/models/` | Acesso a dados/Supabase; nenhuma rota |
| Flask — schemas | `backend/app/schemas/` | Validação e serialização de entrada/saída; nenhuma query |
| Flask — controllers | `backend/app/blueprints/` | Rotas/HTTP; chama models, schemas e services; sem SQL solto |
| Flask — services | `backend/app/services/` | Pluggy e IA; chamados pelos controllers, nunca pelas rotas diretamente |
| React — components | `frontend/src/components/` | Apresentação; sem `fetch` |
| React — hooks | `frontend/src/hooks/` | Estado/efeitos; sem JSX de página |
| React — services | `frontend/src/services/` | HTTP/Supabase; sem estado de UI |

Nesta fatia, **só existem arquivos em `supabase/`**. Nenhuma tarefa cria `backend/` ou `frontend/`. As fatias 2 e 3 seguem a tabela acima sem exceção.

### 2.5 Execução por subagentes

- O header exige `subagent-driven-development`: um implementador fresco por tarefa, testes da tarefa, um revisor fresco antes da próxima tarefa e uma revisão final da fatia.
- Todo prompt de subagente inclui: o texto da tarefa, os **Global Constraints**, o modelo de dados canônico (§6), as fixtures (§7) e o critério de aceite da tarefa.
- Tarefas mecânicas, repetitivas ou isoladas são marcadas **Delegável: sim** com contexto fechado e aceite objetivo: Tasks 1, 2, 3, 4, 5 e 13.
- Tarefas de privacidade/RLS são marcadas **Delegável: com revisor independente obrigatório**: Tasks 6–12. O revisor deve tentar um bypass (outra família, admin, membro inativo, `family_id` forjado) e rodar os testes.
- Task 14 é **não delegável**: é o gate final de verificação.
- Um subagente nunca “conserta” um teste para passar; se o teste estiver errado, ele para e devolve a dúvida ao orquestrador.

### 2.6 Git

- A pasta ainda não é repositório git. Na execução, a Task 1 roda `git init` e cria o primeiro commit; cada tarefa termina com um commit local.
- **Nenhum commit/push é feito durante o planejamento.** Não há push para GitHub nesta fatia; o remoto só entra quando o parceiro aprovar.
- Se o parceiro preferir não versionar agora, os passos de commit viram checkpoints de revisão; o plano não depende de git para os testes.

---

## 3. Global Constraints (verbatim da spec)

Estas restrições valem para todas as tarefas. Copiadas literalmente da spec v2.0:

- “Cada membro vê apenas os próprios lançamentos; o painel familiar exibe somente totais agregados da família” — D1.
- “Privacidade estrita por membro, garantida no banco de dados, não só na tela.” — §1.3.
- “Qualquer membro — inclusive o administrador — conseguindo ver as transações pessoais de outro membro, mesmo explorando a API diretamente.” — §1.5 (anti-objetivo).
- “Qualquer membro conseguindo ver dados bancários (conexões, extrato, transações importadas) de outro membro.” — §1.5 (anti-objetivo).
- “Conexões bancárias e transações importadas são pessoais por padrão (escopo ‘pessoal’). O usuário pode, ao confirmar a importação, mudar o escopo para ‘família’ se desejar. O administrador NÃO tem acesso a conexões ou dados bancários de outros membros.” — D31.
- “Transações bancárias NUNCA viram lançamento automaticamente. Aparecem como ‘sugestões de importação’ pendentes de confirmação.” — D30.
- “Transações bancárias virando lançamentos automaticamente sem confirmação do usuário.” — §1.5 (anti-objetivo).
- “O VivaFinanças nunca armazena credenciais bancárias; o Pluggy cuida da autenticação com o banco.” — D27.
- “Armazenamento de credenciais bancárias (senhas, tokens de banco) no banco de dados do VivaFinanças.” — §1.5 (anti-objetivo).
- “Nenhum campo armazena senha, token bancário ou credencial sensível. O `pluggy_connection_id` é um identificador opaco fornecido pelo Pluggy.” — §4.3.
- “O VivaFinanças nunca armazena senhas bancárias, tokens de banco ou dados de autenticação financeira. O Pluggy é o único responsável por esse armazenamento.” — §7.3.
- “O backend consulta o banco com o JWT do próprio usuário — o RLS vale de ponta a ponta; a service role é reservada à Admin API (convites, desativação), ao seed e à sincronização Pluggy (que precisa inserir `bank_transactions` em nome do usuário).” — §4.4.
- “Mesmo que o frontend contenha uma falha, o banco recusa a consulta; mesmo chamando a API diretamente com um token válido, o resultado é o mesmo.” — §4.4.

**Consequência operacional:** nenhuma migration, seed, teste ou função pode armazenar senha bancária, token Pluggy, API key ou credencial de banco. A `PLUGGY_API_KEY` nunca aparece no repositório; em produção fica só em variável de ambiente do backend.

---

## 4. Review Focus

Cinco classes de entrada/falha que a spec implica mas nenhum requisito testa diretamente. Cada uma tem teste na tarefa dona do código:

1. **Admin da mesma família lendo lançamento pessoal de outro membro via API direta.** Pessoa razoável espera zero linhas; o painel só pode ver agregados. Teste na Task 10 (RLS de `transactions`).
2. **Membro desativado com JWT ainda válido.** Pessoa razoável espera perder leitura/escrita dos dados da família, mantendo só o próprio perfil. Teste nas Tasks 8, 9 e 10.
3. **Sync Pluggy inserindo `bank_transactions`.** Pessoa razoável espera que nenhum `transactions` seja criado; importação só nasce de confirmação explícita com `origem='pluggy'` e vínculo. Testes nas Tasks 5, 9, 10 e 13.
4. **Usuário forjando `family_id`/`member_id` em INSERT/UPDATE.** Pessoa razoável espera recusa; nenhuma linha de outra família pode ser criada ou assumida. Testes nas Tasks 9 e 10.
5. **Seed rodando duas vezes ou confirmação dupla de recorrente/importação.** Pessoa razoável espera idempotência e constraints únicas impedindo duplicata. Testes nas Tasks 7 e 13.

---

## 5. Estrutura de arquivos desta fatia

```
VivaFinancas/
  .gitignore                          # entradas locais (env, temp, venv); `docs/` versionado
  README.md                           # instalação e execução da fatia 1
  supabase/
    config.toml                       # gerado por supabase init; seed aponta para ./seed/*.sql
    migrations/
      20261103000100_extensions.sql   # pgcrypto + schema private
      20261103000200_identity_schema.sql
      20261103000300_financial_schema.sql
      20261103000400_goals_ai_schema.sql
      20261103000500_banking_schema.sql
      20261103000600_private_helpers.sql
      20261103000700_identity_triggers.sql
      20261103000800_financial_triggers.sql
      20261103000900_rls_identity.sql
      20261103001000_rls_banking.sql
      20261103001100_rls_financial.sql
      20261103001200_rls_goals_ai.sql
      20261103001300_family_read_functions.sql
    seed/
      000_placeholder.sql             # no-op até a Task 13
      010_demo_users.sql              # auth.users + auth.identities
      020_demo_family.sql             # família, perfis e categorias padrão
      030_demo_history.sql            # 6 meses, recorrentes, metas, IA
      040_demo_banking.sql            # conexão/contas/transações simuladas
    checks/
      inventory.sql                   # consultas de inventário da Task 14
    tests/
      00_smoke_test.sql
      01_identity_schema_test.sql
      02_financial_schema_test.sql
      03_goals_ai_schema_test.sql
      04_banking_schema_test.sql
      05_identity_triggers_test.sql
      06_financial_triggers_test.sql
      07_rls_identity_test.sql
      08_rls_banking_test.sql
      09_rls_financial_test.sql
      10_rls_goals_ai_test.sql
      11_read_functions_test.sql
      12_seed_test.sql
    README.md                         # comandos locais, credenciais demo, contrato RLS
```

**Responsabilidade de cada arquivo:** migrations = schema/constraints/triggers/políticas; seed = dados demo; tests = contrato executável; README = como rodar e o que a fatia garante. Nenhuma lógica de aplicação (HTTP, UI, Pluggy) mora aqui.

---

## 6. Modelo de dados canônico

Convenções:
- `uuid` PK default `gen_random_uuid()`.
- Dinheiro em `numeric(14,2)`, sempre positivo; sinal vem de `tipo` (`receita`/`despesa` ou `debito`/`credito`).
- Datas de negócio em `date`; timestamps em `timestamptz`; timezone de referência `America/Sao_Paulo` (cálculo no backend; o banco não muda o timezone global).
- Valores canônicos em ASCII: `pessoal|familia`, `receita|despesa`, `debito|credito`, `ativo|inativo`, `pendente|confirmado|ignorado`, `em_andamento|concluida|cancelada`, `pendente_importacao|importada|ignorada|reconciliada`, `ativa|inativa|erro_sincronizacao|expirada`, `manual|pluggy`, `admin|membro`, `corrente|poupanca`. A UI traduz para “Pessoal/Família” etc.
- Toda tabela de dados de família tem `family_id` e FK composta quando a linha precisa provar que o membro/categoria/regra é da mesma família.
- RLS é habilitado na mesma migration que cria a tabela; sem política, o acesso é negado. As políticas entram nas tasks 9–12.

### 6.1 Tabelas

#### `families`
- `id uuid pk default gen_random_uuid()`
- `nome text not null check (length(btrim(nome)) between 1 and 80)`
- `criado_por uuid not null references auth.users(id) on delete restrict`
- `criado_em timestamptz not null default now()`
- `is_demo boolean not null default false`
- Índice: `(criado_por)`.

#### `profiles`
- `id uuid pk references auth.users(id) on delete cascade`
- `family_id uuid not null references families(id) on delete cascade`
- `nome text not null check (length(btrim(nome)) between 1 and 80)`
- `papel text not null default 'membro' check (papel in ('admin','membro'))`
- `status text not null default 'ativo' check (status in ('ativo','inativo'))`
- `tema text not null default 'claro' check (tema in ('claro','escuro'))` — campo adicional necessário para a persistência de tema da §3.9; não estava listado em §4.3.
- `criado_em timestamptz not null default now()`
- Unique: `(id, family_id)` (para FKs compostas).
- Índice: `(family_id, status)`.

#### `categories`
- `id uuid pk default gen_random_uuid()`
- `family_id uuid not null references families(id) on delete cascade`
- `nome text not null check (length(btrim(nome)) between 1 and 60)`
- `tipo text not null check (tipo in ('receita','despesa'))`
- `personalizada boolean not null default true`
- `oculta boolean not null default false`
- `criado_por uuid references profiles(id) on delete set null`
- Unique: `(id, family_id)` e `(family_id, tipo, nome)`; `(id, family_id, tipo)` para a FK de tipo.
- Índice: `(family_id, tipo, oculta)`.

#### `transactions`
- `id uuid pk default gen_random_uuid()`
- `family_id uuid not null references families(id) on delete cascade`
- `member_id uuid not null` — dono do lançamento; no escopo família é o autor, e `pago_por` guarda quem pagou.
- `tipo text not null check (tipo in ('receita','despesa'))`
- `escopo text not null check (escopo in ('pessoal','familia'))`
- `valor numeric(14,2) not null check (valor > 0)`
- `descricao text`
- `category_id uuid not null`
- `data date not null`
- `pago_por uuid` — só no escopo família; referência histórica (D7).
- `recurring_rule_id uuid`
- `mes_referencia date`
- `criado_por uuid not null`
- `origem text not null default 'manual' check (origem in ('manual','pluggy'))`
- `bank_transaction_id uuid unique` — FK `on delete restrict`, adicionada na Task 5 para evitar o ciclo com `bank_transactions`.
- `criado_em timestamptz not null default now()`
- FKs compostas: `(member_id, family_id)`, `(criado_por, family_id)`, `(pago_por, family_id)` → `profiles(id, family_id)`; `(category_id, family_id, tipo)` → `categories(id, family_id, tipo)`; `(recurring_rule_id, family_id)` → `recurring_rules(id, family_id)`.
- Checks: `pago_por is null or escopo = 'familia'`; `(recurring_rule_id is null) = (mes_referencia is null)`; `mes_referencia is null or mes_referencia = date_trunc('month', mes_referencia)::date`; `origem = 'manual' or bank_transaction_id is not null`.
- Unique: `(recurring_rule_id, mes_referencia)` — impede confirmação dupla da mesma regra/mês.
- Índices: `(family_id, data desc)`, `(member_id, data desc)`, `(category_id)`, `(recurring_rule_id, mes_referencia)`.

#### `recurring_rules`
- `id uuid pk default gen_random_uuid()`
- `family_id uuid not null references families(id) on delete cascade`
- `criado_por uuid not null`
- `tipo text not null check (tipo in ('receita','despesa'))`
- `escopo text not null check (escopo in ('pessoal','familia'))`
- `valor numeric(14,2) not null check (valor > 0)`
- `descricao text not null`
- `category_id uuid not null`
- `dia_vencimento smallint not null check (dia_vencimento between 1 and 31)`
- `ativo boolean not null default true`
- `criado_em timestamptz not null default now()`
- FKs compostas: `(criado_por, family_id)` → `profiles`; `(category_id, family_id, tipo)` → `categories(id, family_id, tipo)`.
- Unique: `(id, family_id)`.
- Índice: `(family_id, ativo)`.

#### `recurring_occurrences`
- `id uuid pk default gen_random_uuid()`
- `rule_id uuid not null references recurring_rules(id) on delete cascade`
- `mes_referencia date not null check (mes_referencia = date_trunc('month', mes_referencia)::date)`
- `status text not null check (status in ('pendente','confirmado','ignorado'))`
- `valor_confirmado numeric(14,2) check (valor_confirmado is null or valor_confirmado > 0)`
- `confirmado_por uuid references profiles(id) on delete set null`
- `confirmado_em timestamptz`
- Unique: `(rule_id, mes_referencia)`.
- Checks: `status <> 'confirmado' or (valor_confirmado is not null and confirmado_por is not null and confirmado_em is not null)`; `status = 'confirmado' or (valor_confirmado is null and confirmado_por is null and confirmado_em is null)`.

#### `goals`
- `id uuid pk default gen_random_uuid()`
- `family_id uuid not null references families(id) on delete cascade`
- `member_id uuid` — `null` = meta da família; preenchido = meta pessoal do membro.
- `criado_por uuid not null` — quem criou; só ele pode excluir (decisão de produto de 2026-11-03).
- `titulo text not null check (length(btrim(titulo)) between 1 and 120)`
- `valor_alvo numeric(14,2) not null check (valor_alvo > 0)`
- `prazo date`
- `status text not null default 'em_andamento' check (status in ('em_andamento','concluida','cancelada'))`
- `descricao text`
- `criado_em timestamptz not null default now()`
- FKs compostas: `(member_id, family_id)` e `(criado_por, family_id)` → `profiles(id, family_id)`.
- Índice: `(family_id, member_id, status)`.

#### `goal_contributions`
- `id uuid pk default gen_random_uuid()`
- `goal_id uuid not null references goals(id) on delete cascade`
- `member_id uuid not null references profiles(id) on delete restrict`
- `valor numeric(14,2) not null check (valor > 0)`
- `data date not null default current_date`
- `criado_em timestamptz not null default now()`
- Índice: `(goal_id)`.
- Imutável na v1: sem políticas de UPDATE/DELETE (decisão de produto da §0).

#### `ai_messages`
- `id uuid pk default gen_random_uuid()`
- `family_id uuid not null references families(id) on delete cascade`
- `member_id uuid` — `null` = thread da família; preenchido = thread pessoal.
- `role text not null` — valores definidos pela fatia 4; a spec não fixa o enum.
- `content text not null check (length(btrim(content)) > 0)`
- `criado_em timestamptz not null default now()`
- FK composta: `(member_id, family_id)` → `profiles(id, family_id)`.
- Índice: `(family_id, member_id, criado_em desc)`.

#### `ai_suggestions`
- `id uuid pk default gen_random_uuid()`
- `family_id uuid not null references families(id) on delete cascade`
- `member_id uuid` — `null` = sugestão da família; preenchido = pessoal.
- `tipo text not null check (length(btrim(tipo)) > 0)`
- `titulo text not null check (length(btrim(titulo)) > 0)`
- `o_que text not null check (length(btrim(o_que)) > 0)`
- `por_que text not null check (length(btrim(por_que)) > 0)`
- `quanto text not null check (length(btrim(quanto)) > 0)` — texto, porque a spec permite “não é possível estimar”.
- `criado_em timestamptz not null default now()`
- `lida boolean not null default false` — leitura compartilhada na v1: a sugestão é da família e qualquer membro ativo pode marcá-la. Leitura por pessoa fica para v2.
- FK composta: `(member_id, family_id)` → `profiles(id, family_id)`.
- Índice: `(family_id, member_id, lida)`.

#### `bank_connections`
- `id uuid pk default gen_random_uuid()`
- `family_id uuid not null references families(id) on delete cascade`
- `member_id uuid not null`
- `pluggy_connection_id text not null unique`
- `institution_name text not null`
- `institution_logo_url text`
- `account_name text`
- `account_type text check (account_type is null or account_type in ('corrente','poupanca'))`
- `account_number_masked text`
- `status text not null default 'ativa' check (status in ('ativa','inativa','erro_sincronizacao','expirada'))`
- `consentido_em timestamptz not null default now()`
- `ultima_sync_em timestamptz`
- `criada_em timestamptz not null default now()`
- `atualizada_em timestamptz not null default now()`
- `is_demo_sync boolean not null default false` — §8.1 cita o flag em `bank_connections`; §4.3 só lista em `bank_transactions`. Ver §9.2.
- FK composta: `(member_id, family_id)` → `profiles(id, family_id)`.
- Índice: `(member_id, status)`.

#### `bank_accounts`
- `id uuid pk default gen_random_uuid()`
- `connection_id uuid not null references bank_connections(id) on delete cascade`
- `pluggy_account_id text not null`
- `nome text not null`
- `tipo text not null check (tipo in ('corrente','poupanca'))`
- `currency text not null default 'BRL' check (currency = 'BRL')`
- `balance numeric(14,2) not null default 0`
- `updated_at timestamptz not null default now()`
- Unique: `(connection_id, pluggy_account_id)` e `(id, connection_id)` (para a FK composta de `bank_transactions`).
- Índice: `(connection_id)`.

#### `bank_transactions`
- `id uuid pk default gen_random_uuid()`
- `bank_connection_id uuid not null references bank_connections(id) on delete cascade`
- `bank_account_id uuid not null`
- `pluggy_transaction_id text not null`
- `data date not null`
- `valor numeric(14,2) not null check (valor > 0)`
- `descricao text not null`
- `tipo text not null check (tipo in ('debito','credito'))`
- `categoria_bancaria text`
- `status text not null default 'pendente_importacao' check (status in ('pendente_importacao','importada','ignorada','reconciliada'))`
- `transaction_id uuid unique references transactions(id) on delete restrict`
- `sincronizado_em timestamptz not null default now()`
- `is_demo_sync boolean not null default false` — imutável após o insert; só o seed/service role define.
- Checks: `status in ('importada','reconciliada') = (transaction_id is not null)`; `status in ('pendente_importacao','ignorada') = (transaction_id is null)`.
- Unique: `(bank_connection_id, pluggy_transaction_id)`.
- FK composta: `(bank_account_id, bank_connection_id)` → `bank_accounts(id, connection_id)`.
- Índice: `(bank_connection_id, data desc)`, `(status)`.

### 6.2 Constraints transversais

- **Ciclo de vínculo bancário:** `transactions.bank_transaction_id` → `bank_transactions.id` e `bank_transactions.transaction_id` → `transactions.id`, ambas `on delete restrict`. As FKs são criadas em migrations separadas (Task 5) para evitar ciclo na criação. Desconectar banco é `status='inativa'`, não DELETE; o trigger de delete de lançamento limpa o vínculo antes de apagar.
- **Status bancário coerente:** `importada`/`reconciliada` exigem `transaction_id`; `pendente_importacao`/`ignorada` exigem `transaction_id` nulo.
- **Mesma família:** FKs compostas impedem `member_id`, `criado_por`, `pago_por`, `category_id`, `recurring_rule_id`, `member_id` de meta/IA, `criado_por` de meta e `member_id` de conexão apontarem para outra família.
- **Uma conexão bancária por transação:** `bank_transactions.transaction_id` é unique; uma transação bancária não pode ser importada duas vezes.
- **Um vínculo por lançamento:** `transactions.bank_transaction_id` é unique; um lançamento não pode apontar para duas transações bancárias.
- **Confirmação dupla:** `recurring_occurrences (rule_id, mes_referencia)` e `transactions (recurring_rule_id, mes_referencia)` são unique.
- **Dinheiro:** todo `valor`/`valor_alvo`/`valor_confirmado`/`balance` é `numeric(14,2)`; valores de lançamento/regra/meta/contribuição > 0.

### 6.3 Funções de leitura familiar (Task 12)

Assinaturas exatas, todas `security definer`, `stable`, `set search_path = ''`, `language sql`, com checagem de membro ativo e `raise exception 'not a family member' using errcode = '42501'`:

- `public.family_totals(p_family_id uuid, p_mes date) returns table(receitas numeric, despesas numeric)` — mês corrente.
- `public.family_category_totals(p_family_id uuid, p_mes date) returns table(category_id uuid, categoria text, total numeric)` — mês corrente.
- `public.family_monthly_totals(p_family_id uuid, p_mes_fim date) returns table(mes date, receitas numeric, despesas numeric)` — 6 meses terminando em `p_mes_fim`.
- `public.family_member_directory(p_family_id uuid) returns table(member_id uuid, nome text, papel text)`

Regras:
- `p_mes` e `p_mes_fim` precisam ser o primeiro dia de um mês; qualquer outro valor levanta `22023` (`invalid parameter value`). Isso impede consultas de um único dia para inferir o gasto pessoal de outro membro.
- `family_totals` e `family_category_totals` somam **todos** os lançamentos da família no mês, inclusive escopo pessoal, mas retornam apenas agregados; nunca retornam `member_id`, `descricao` ou linhas individuais.
- `family_monthly_totals` devolve até 6 linhas, uma por mês com lançamento; o frontend preenche meses vazios com zero.
- `family_member_directory` retorna apenas `id`, `nome`, `papel` de membros **ativos**; não retorna e-mail, status financeiro ou lançamentos. Existe para os avatares do painel (§0).
- `grant execute` apenas para `authenticated`; `revoke all` de `public` e `anon`.
- As funções não substituem o RLS das tabelas; são a única porta para agregados que atravessam escopos pessoais.

---

## 7. Fixtures de teste

Cada arquivo de teste usa um prefixo de UUID próprio para permitir execução isolada/paralela. Padrão:

- Família A: `<prefixo>-0000-4000-8000-000000000001`
- Família B: `<prefixo>-0000-4000-8000-000000000002`
- Ana (admin da A): `<prefixo>-0000-4000-8000-0000000000a1`
- Carlos (membro da A): `<prefixo>-0000-4000-8000-0000000000b2`
- Lucas (membro da A): `<prefixo>-0000-4000-8000-0000000000c3`
- Externo (admin da B): `<prefixo>-0000-4000-8000-0000000000d4`

Prefixos por arquivo: `11000000` (01), `22000000` (02), `33000000` (03), `44000000` (04), `55000000` (05), `66000000` (06), `77000000` (07), `88000000` (08), `99000000` (09), `aa000000` (10), `bb000000` (11). O teste de seed (12) usa os UUIDs fixos da Família Demo (`eeeeeeee-...`).

Fixture canônica (repetir no início de cada teste, antes de `set local role`):

```sql
insert into auth.users (id, email) values
  ('<prefixo>-0000-4000-8000-0000000000a1', 'ana@test.local'),
  ('<prefixo>-0000-4000-8000-0000000000b2', 'carlos@test.local'),
  ('<prefixo>-0000-4000-8000-0000000000c3', 'lucas@test.local'),
  ('<prefixo>-0000-4000-8000-0000000000d4', 'externo@test.local');

insert into public.families (id, nome, criado_por) values
  ('<prefixo>-0000-4000-8000-000000000001', 'Família Teste A', '<prefixo>-0000-4000-8000-0000000000a1'),
  ('<prefixo>-0000-4000-8000-000000000002', 'Família Teste B', '<prefixo>-0000-4000-8000-0000000000d4');

insert into public.profiles (id, family_id, nome, papel, status) values
  ('<prefixo>-0000-4000-8000-0000000000a1', '<prefixo>-0000-4000-8000-000000000001', 'Ana', 'admin', 'ativo'),
  ('<prefixo>-0000-4000-8000-0000000000b2', '<prefixo>-0000-4000-8000-000000000001', 'Carlos', 'membro', 'ativo'),
  ('<prefixo>-0000-4000-8000-0000000000c3', '<prefixo>-0000-4000-8000-000000000001', 'Lucas', 'membro', 'ativo'),
  ('<prefixo>-0000-4000-8000-0000000000d4', '<prefixo>-0000-4000-8000-000000000002', 'Externo', 'admin', 'ativo');
```

Para atuar como usuário:

```sql
set local role authenticated;
set local request.jwt.claim.sub = '<uuid-do-usuário>';
-- ... asserções ...
reset role;
reset request.jwt.claim.sub;
reset request.jwt.claims;
```

Os testes rodam em transação (`begin; ... rollback;`) e revertem tudo. Fixtures são inseridas como `postgres` (bypassa RLS) antes de trocar o role. **Sempre** limpar `request.jwt.claim.sub` e `request.jwt.claims` ao voltar para `postgres`; `reset role` não limpa o GUC, e um teste de membro inativo rodaria com o `auth.uid()` do ator anterior.

---

## 8. Tarefas

### Task 1: Bootstrap do Supabase local, git e smoke test

**Delegação:** sim — tarefa mecânica de ambiente. Contexto: Windows; Docker/WSL e Supabase CLI podem não estar instalados. Se o CLI não existir, instalar `supabase@3.0.0`; se o Docker não existir, instalar Docker Desktop + WSL2 (exige admin e reboot) ou executar a fatia em CI Linux/Supabase hospedado. Não existe instalação de Docker via npm.
**Ponytail:** só o necessário para `supabase test db` rodar; nenhuma config extra.

**Files:**
- Create: `supabase/config.toml` (gerado por `supabase init`)
- Create: `supabase/migrations/20261103000100_extensions.sql`
- Create: `supabase/tests/00_smoke_test.sql`
- Create: `supabase/seed/000_placeholder.sql`
- Create: `supabase/README.md`
- Create: `README.md` (raiz, mínimo da fatia 1)
- Modify: `.gitignore`

**Interfaces:**
- Consumes: nada.
- Produces: stack local; schema `private`; extensão `pgcrypto`; `[db.seed] sql_paths = ["./seed/*.sql"]`; CLI fixado em 3.0.0; `psql` disponível para os arquivos multi-statement.

- [ ] **Step 0: Preflight de ambiente**

```powershell
docker version
docker info
supabase --version
psql --version
```

Se `docker` ou `wsl` não existirem, parar e instalar Docker Desktop + WSL2, ou trocar para um ambiente Linux/CI. Se o CLI não existir ou estiver em outra major:

```powershell
npm i -g supabase@3.0.0
supabase --version
```

Esperado: `supabase 3.0.0`, Docker e `psql` respondendo. Registrar as versões no `README.md` da raiz.

- [ ] **Step 1: Inicializar git e Supabase**

```powershell
git init
supabase init
```

Esperado: `.git` criado; `supabase/config.toml` e `supabase/.gitignore` criados. Se `supabase/config.toml` já existir, pular o `supabase init`.

- [ ] **Step 2: Apontar o seed para `supabase/seed/*.sql` e criar o placeholder**

Em `supabase/config.toml`, garantir:

```toml
[db.seed]
enabled = true
sql_paths = ["./seed/*.sql"]
```

Criar `supabase/seed/000_placeholder.sql` com apenas um comentário. Sem ele, o CLI emite `no files matched pattern: ./seed/*.sql` nas Tasks 1–12; o reset continua, mas o aviso confunde.

- [ ] **Step 3: Subir a stack e escrever o smoke test que falha**

`supabase/tests/00_smoke_test.sql`:

```sql
begin;
select plan(2);
select has_schema('private', 'schema private existe');
select has_extension('pgcrypto', 'pgcrypto habilitado');
select * from finish();
rollback;
```

```powershell
supabase start
supabase test db
```

Esperado: `private` falha e `pgcrypto` passa (o Supabase local já traz pgcrypto). O importante é que `test db` erre por schema ausente, não por stack parada.

- [ ] **Step 4: Criar a migration de extensões**

`supabase/migrations/20261103000100_extensions.sql`:

```sql
create extension if not exists pgcrypto with schema extensions;
create schema if not exists private;
```

- [ ] **Step 5: Aplicar e verificar**

```powershell
supabase db reset
supabase test db
```

Esperado: `1..2`, ambos os testes `ok`, `All tests successful`.

- [ ] **Step 6: README mínimo da fatia e README raiz**

`supabase/README.md` com: pré-requisitos (Docker + Supabase CLI 3.0.0 + `psql`), `supabase start`, `supabase db reset`, `supabase test db`, `supabase status -o env`, credenciais demo (preenchidas na Task 13), e a nota “service role só para Admin API, seed e sync Pluggy; a restauração da demo usa conexão Postgres direta”.

`README.md` da raiz com: o que é a fatia 1, pré-requisitos, como rodar a suíte e um link para `supabase/README.md`. As seções de backend, frontend e Pluggy entram nas fatias 2–4.

- [ ] **Step 7: Ajustar `.gitignore`**

Adicionar ao `.gitignore` da raiz: `.env`, `.env.*`, `supabase/.branches/`, `supabase/.temp/`, `node_modules/`, `.venv/`, `__pycache__/`, `.pytest_cache/`. Remover a linha `docs/` existente: D11 diz que a especificação Markdown mora no repositório, então `docs/` e `docs/plans/` precisam ser versionados.

- [ ] **Step 8: Commit**

```powershell
git add .gitignore docs README.md supabase
git commit -m "chore: bootstrap supabase local com pgcrypto e schema private"
```

**Critério de aceite:** `supabase test db` passa os 2 testes; `supabase status -o env` mostra API URL e chaves; `supabase db reset` aplica a migration sem erro; Docker e CLI 3.0.0 registrados no README.

---

### Task 2: Schema de identidade (`families`, `profiles`, `categories`)

**Delegação:** sim — DDL mecânico, isolado, com contrato fechado no §6.1.
**Ponytail:** só as colunas/constraints do §6.1; nenhum trigger nesta task.

**Files:**
- Create: `supabase/migrations/20261103000200_identity_schema.sql`
- Create: `supabase/tests/01_identity_schema_test.sql`

**Interfaces:**
- Consumes: `private`/`pgcrypto` da Task 1.
- Produces: tabelas `public.families`, `public.profiles`, `public.categories` com colunas, checks, FKs compostas, uniques e índices do §6.1; RLS habilitado sem políticas (acesso negado até as tasks 8–11).

- [ ] **Step 1: Escrever o teste que falha**

`supabase/tests/01_identity_schema_test.sql` usa o prefixo `11000000`, insere a fixture canônica do §7 e mais um usuário `...00e5` sem perfil. Afirma:

```sql
begin;
select plan(12);

-- fixture canônica do §7 (4 usuários, 2 famílias, 4 perfis) aqui
insert into auth.users (id, email) values
  ('11000000-0000-4000-8000-0000000000e5', 'invalido@test.local');

select has_table('public', 'families', 'tabela families existe');
select has_table('public', 'profiles', 'tabela profiles existe');
select has_table('public', 'categories', 'tabela categories existe');
select has_column('public', 'profiles', 'tema', 'profiles guarda o tema');
select col_type_is('public', 'profiles', 'tema', 'text', 'tema é text');
select has_column('public', 'categories', 'personalizada', 'categories marca personalizada');
select col_type_is('public', 'categories', 'personalizada', 'boolean', 'personalizada é boolean');
select throws_ok($$ insert into public.profiles (id, family_id, nome, papel, status)
  values ('11000000-0000-4000-8000-0000000000e5', '11000000-0000-4000-8000-000000000001', 'Inválido', 'dono', 'ativo') $$,
  '23514', null, 'papel inválido é recusado');
select throws_ok($$ insert into public.categories (family_id, nome, tipo)
  values ('11000000-0000-4000-8000-000000000001', 'Pet', 'investimento') $$,
  '23514', null, 'tipo de categoria inválido é recusado');
select throws_ok($$ insert into public.categories (family_id, nome, tipo)
  values ('11000000-0000-4000-8000-000000000001', 'Pet', 'despesa'),
         ('11000000-0000-4000-8000-000000000001', 'Pet', 'despesa') $$,
  '23505', null, 'categoria duplicada na família é recusada');
select ok((select relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname='families'), 'RLS habilitado em families');
select ok((select relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname='profiles'), 'RLS habilitado em profiles');

select * from finish();
rollback;
```

Rodar `supabase test db`. Esperado: falha “relation does not exist”.

- [ ] **Step 2: Implementar a migration**

Criar as três tabelas na ordem `families` → `profiles` → `categories`, com:

```sql
alter table public.families enable row level security;
alter table public.profiles enable row level security;
alter table public.categories enable row level security;

grant select, insert, update on public.families, public.profiles to authenticated;
grant select, insert, update, delete on public.categories to authenticated;
revoke all on public.families, public.profiles, public.categories from anon;
```

Incluir as FKs compostas:

```sql
alter table public.families
  add constraint families_criado_por_key unique (criado_por);
alter table public.profiles
  add constraint profiles_id_family_key unique (id, family_id);
alter table public.categories
  add constraint categories_id_family_key unique (id, family_id),
  add constraint categories_id_family_tipo_key unique (id, family_id, tipo);
```

- [ ] **Step 3: Rodar o teste**

```powershell
supabase db reset
supabase test db
```

Esperado: os testes de schema passam; os de RLS ainda não existem.

- [ ] **Step 4: Commit**

```powershell
git add supabase/migrations/20261103000200_identity_schema.sql supabase/tests/01_identity_schema_test.sql
git commit -m "feat(db): schema de familias, perfis e categorias"
```

**Critério de aceite:** 3 tabelas criadas; checks de `papel`, `status`, `tipo` e unique de categoria funcionam; RLS habilitado; nenhuma política ainda.

---

### Task 3: Schema financeiro (`transactions`, `recurring_rules`, `recurring_occurrences`)

**Delegação:** sim — DDL mecânico, isolado.
**Ponytail:** nada além do §6.1; `bank_transaction_id` fica sem FK até a Task 5.

**Files:**
- Create: `supabase/migrations/20261103000300_financial_schema.sql`
- Create: `supabase/tests/02_financial_schema_test.sql`

**Interfaces:**
- Consumes: `families`, `profiles`, `categories`.
- Produces: `public.transactions`, `public.recurring_rules`, `public.recurring_occurrences`; FKs compostas; uniques; RLS habilitado sem políticas.

- [ ] **Step 1: Escrever o teste que falha**

Prefix `22000000`. Inserir manualmente as categorias necessárias (a trigger de categorias padrão só existe na Task 6), usando nomes fora da lista padrão, como `Categoria Teste 02`, para não colidir com o unique `(family_id, tipo, nome)` depois que a trigger existir. Afirmar:
- `has_table` para as 3 tabelas.
- `throws_ok` 23514 para `transactions.valor = 0`, `tipo='investimento'`, `escopo='global'`, `pago_por` preenchido com `escopo='pessoal'`, `mes_referencia` que não é primeiro dia, `origem='pluggy'` sem `bank_transaction_id`.
- `throws_ok` 23505 ao inserir duas `recurring_occurrences` com mesmo `(rule_id, mes_referencia)`.
- `throws_ok` 23505 ao inserir duas `transactions` com mesmo `(recurring_rule_id, mes_referencia)`.
- `throws_ok` 23503 ao inserir `transactions.category_id` de outra família (FK composta).
- `throws_ok` 23503 ao inserir despesa com categoria de receita (FK composta `(category_id, family_id, tipo)`).
- `throws_ok` 23514 para `recurring_rules.dia_vencimento = 32`.

- [ ] **Step 2: Implementar a migration**

Ordem: `recurring_rules` → `transactions` → `recurring_occurrences`.

```sql
alter table public.transactions enable row level security;
alter table public.recurring_rules enable row level security;
alter table public.recurring_occurrences enable row level security;

grant select, insert, update, delete on public.transactions to authenticated;
grant select, insert, update on public.recurring_rules to authenticated;
grant select, insert, update on public.recurring_occurrences to authenticated;
revoke all on public.transactions, public.recurring_rules, public.recurring_occurrences from anon;
```

FKs compostas:
```sql
alter table public.recurring_rules
  add constraint recurring_rules_id_family_key unique (id, family_id),
  add constraint recurring_rules_category_family_fkey foreign key (category_id, family_id, tipo)
    references public.categories (id, family_id, tipo);
alter table public.transactions
  add constraint transactions_member_family_fkey foreign key (member_id, family_id)
    references public.profiles (id, family_id),
  add constraint transactions_creator_family_fkey foreign key (criado_por, family_id)
    references public.profiles (id, family_id),
  add constraint transactions_payer_family_fkey foreign key (pago_por, family_id)
    references public.profiles (id, family_id),
  add constraint transactions_category_family_fkey foreign key (category_id, family_id, tipo)
    references public.categories (id, family_id, tipo),
  add constraint transactions_rule_family_fkey foreign key (recurring_rule_id, family_id)
    references public.recurring_rules (id, family_id);
```

- [ ] **Step 3: Rodar o teste**

```powershell
supabase db reset
supabase test db
```

- [ ] **Step 4: Commit**

```powershell
git add supabase/migrations/20261103000300_financial_schema.sql supabase/tests/02_financial_schema_test.sql
git commit -m "feat(db): schema de lancamentos e recorrentes"
```

**Critério de aceite:** checks e uniques acima passam; `origem='pluggy'` sem vínculo é recusado; nenhuma FK para `bank_transactions` ainda.

---

### Task 4: Schema de metas e IA (`goals`, `goal_contributions`, `ai_messages`, `ai_suggestions`)

**Delegação:** sim — DDL mecânico, isolado.
**Ponytail:** só o §6.1; sem trigger de meta (fica na Task 7).

**Files:**
- Create: `supabase/migrations/20261103000400_goals_ai_schema.sql`
- Create: `supabase/tests/03_goals_ai_schema_test.sql`

**Interfaces:**
- Consumes: `families`, `profiles`.
- Produces: as 4 tabelas; `member_id` nullable = escopo família; RLS habilitado sem políticas.

- [ ] **Step 1: Teste que falha**

Prefix `33000000`. Afirmar:
- `has_table` das 4 tabelas.
- `goals.member_id` aceita `null` (meta familiar) e UUID de perfil.
- `goals.criado_por` é `not null`; inserir meta sem criador dá 23502.
- FK composta `(criado_por, family_id)` com família errada dá 23503.
- `valor_alvo = 0` e `status='pausada'` dão 23514.
- `goal_contributions.valor = 0` dá 23514.
- `ai_messages.content = ''` dá 23514.
- `ai_suggestions.titulo`, `o_que`, `por_que` e `quanto` vazios dão 23514; `null` dá 23502.
- FK composta de `goals.member_id` com família errada dá 23503.

- [ ] **Step 2: Implementar migration**

```sql
alter table public.goals enable row level security;
alter table public.goal_contributions enable row level security;
alter table public.ai_messages enable row level security;
alter table public.ai_suggestions enable row level security;

grant select, insert, update, delete on public.goals to authenticated;
grant select, insert on public.goal_contributions to authenticated;
grant select, insert on public.ai_messages to authenticated;
grant select, insert on public.ai_suggestions to authenticated;
grant update (lida) on public.ai_suggestions to authenticated;
revoke all on public.goals, public.goal_contributions, public.ai_messages, public.ai_suggestions from anon;
```

- [ ] **Step 3: Rodar e commitar**

```powershell
supabase db reset
supabase test db
git add supabase/migrations/20261103000400_goals_ai_schema.sql supabase/tests/03_goals_ai_schema_test.sql
git commit -m "feat(db): schema de metas e historico da Jev AI"
```

**Critério de aceite:** metas familiares/pessoais e sugestões com `member_id` nulo são aceitas; checks de status, valor e conteúdo passam; `goal_contributions`/`ai_messages` não têm UPDATE/DELETE; `ai_suggestions` só permite UPDATE em `lida`.

---

### Task 5: Schema bancário e guarda de credenciais

**Delegação:** sim — DDL mecânico, isolado; a varredura de credenciais é o aceite.
**Ponytail:** nenhuma coluna de token/senha; só metadados e transações.

**Files:**
- Create: `supabase/migrations/20261103000500_banking_schema.sql`
- Create: `supabase/tests/04_banking_schema_test.sql`

**Interfaces:**
- Consumes: `transactions`, `families`, `profiles`.
- Produces: `bank_connections`, `bank_accounts`, `bank_transactions`; FKs circulares de vínculo; RLS habilitado sem políticas.

- [ ] **Step 1: Teste que falha**

Prefix `44000000`. Afirmar:
- `has_table` das 3 tabelas.
- `bank_connections.status='conectada'` dá 23514.
- `bank_transactions.status='pendente'` dá 23514.
- `bank_transactions.status='importada'` com `transaction_id` nulo dá 23514; `status='pendente_importacao'` com `transaction_id` preenchido dá 23514.
- `bank_accounts.tipo='investimento'` dá 23514.
- Inserir duas `bank_transactions` com mesmo `(bank_connection_id, pluggy_transaction_id)` dá 23505.
- Inserir `bank_account_id` de outra conexão dá 23503 (FK composta).
- `is_empty` para colunas sensíveis:

```sql
select is_empty($$
  select column_name from information_schema.columns
  where table_schema = 'public'
    and table_name like 'bank_%'
    and column_name ~* '(password|senha|token|secret|credential|credencial)'
$$, 'nenhuma coluna de credencial nas tabelas bancárias');
```

- `select is((select count(*) from information_schema.columns where table_schema='public' and table_name like 'bank_%' and column_name='pluggy_connection_id'), 1::bigint, 'pluggy_connection_id é identificador opaco, não credencial')`.

- [ ] **Step 2: Implementar migration**

Ordem: `bank_connections` → `bank_accounts` → `bank_transactions` → alterar `transactions` para a FK de volta.

```sql
alter table public.bank_connections enable row level security;
alter table public.bank_accounts enable row level security;
alter table public.bank_transactions enable row level security;

grant select, insert, update on public.bank_connections, public.bank_accounts to authenticated;
grant select on public.bank_transactions to authenticated;
grant update (status) on public.bank_transactions to authenticated;
revoke all on public.bank_connections, public.bank_accounts, public.bank_transactions from anon;
-- INSERT/DELETE em bank_transactions: apenas service_role (bypassa RLS); sem policy para authenticated.

alter table public.transactions
  add constraint transactions_bank_transaction_fkey
  foreign key (bank_transaction_id) references public.bank_transactions(id) on delete restrict;
```

- [ ] **Step 3: Rodar e commitar**

```powershell
supabase db reset
supabase test db
git add supabase/migrations/20261103000500_banking_schema.sql supabase/tests/04_banking_schema_test.sql
git commit -m "feat(db): schema bancario sem credenciais"
```

**Critério de aceite:** 3 tabelas com constraints do §6.1; vínculo circular funciona; nenhuma coluna/valor de credencial; `bank_transactions` só tem SELECT e UPDATE de `status` para `authenticated`; o vínculo `transaction_id` é escrito pelo trigger do lançamento; status e vínculo bancário não podem divergir.

---

### Task 6: Funções privadas e triggers de identidade

**Delegação:** com revisor independente obrigatório — mexe em admin, demo e categorias padrão.
**Ponytail:** só as funções/triggers exigidas pelos testes; nenhuma função “utils” genérica.

**Files:**
- Create: `supabase/migrations/20261103000600_private_helpers.sql`
- Create: `supabase/migrations/20261103000700_identity_triggers.sql`
- Create: `supabase/tests/05_identity_triggers_test.sql`

**Interfaces:**
- Consumes: tabelas das Tasks 2–5.
- Produces:
  - `private.current_family_id() returns uuid`
  - `private.is_active_member_of(p_family_id uuid) returns boolean`
  - `private.is_admin_of(p_family_id uuid) returns boolean`
  - `private.owns_connection(p_connection_id uuid) returns boolean`
  - `private.is_demo_connection(p_connection_id uuid) returns boolean`
  - `private.can_write_connection(p_connection_id uuid) returns boolean`
  - `private.can_view_transaction(p_transaction_id uuid) returns boolean`
  - `private.can_view_rule(p_rule_id uuid) returns boolean`
  - `private.can_view_goal(p_goal_id uuid) returns boolean`
  - `private.family_has_profiles(p_family_id uuid) returns boolean`
  - `private.category_in_use(p_category_id uuid) returns boolean`
  - Trigger `tg_seed_default_categories` after insert on `families`
  - Trigger `tg_guard_profile_update` before update on `profiles`
  - Trigger `tg_guard_family_update` before update on `families`
  - Trigger `tg_guard_category_update` before update on `categories`

- [ ] **Step 1: Teste que falha**

Prefix `55000000`. Afirmar:
- Inserir uma família cria exatamente 12 categorias padrão: 8 `despesa` (`Alimentação`, `Moradia`, `Transporte`, `Saúde`, `Educação`, `Lazer`, `Assinaturas`, `Outros`) + 4 `receita` (`Salário`, `Freelance`, `Investimentos`, `Outros`), todas `personalizada=false`, `oculta=false`.
- `update profiles set papel='admin'` de um membro falha (immutable).
- `update profiles set family_id=...` falha.
- Desativar o único admin da família falha com 42501; desativar um membro comum funciona.
- Admin não altera o `tema` de outro membro; o próprio membro altera o seu.
- `update families set is_demo=true` falha; `set criado_por=...` falha.
- Renomear categoria padrão falha; `update categories set oculta=true` funciona.
- Renomear categoria personalizada pelo criador funciona; mudar `personalizada` para `false` falha; mudar `tipo` de categoria em uso falha.
- `tg_seed_default_categories` é `security definer` e tem `search_path=''` em `proconfig`.

- [ ] **Step 2: Implementar helpers**

```sql
create schema if not exists private;

create or replace function private.current_family_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select family_id
  from public.profiles
  where id = (select auth.uid())
    and status = 'ativo'
$$;

create or replace function private.is_active_member_of(p_family_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid())
      and family_id = p_family_id
      and status = 'ativo'
  )
$$;

create or replace function private.is_admin_of(p_family_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid())
      and family_id = p_family_id
      and papel = 'admin'
      and status = 'ativo'
  )
$$;

create or replace function private.owns_connection(p_connection_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.bank_connections bc
    where bc.id = p_connection_id
      and bc.member_id = (select auth.uid())
      and bc.family_id = private.current_family_id()
  )
$$;

create or replace function private.can_view_rule(p_rule_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.recurring_rules r
    where r.id = p_rule_id
      and r.family_id = private.current_family_id()
      and (r.escopo = 'familia' or r.criado_por = (select auth.uid()))
  )
$$;

create or replace function private.can_view_goal(p_goal_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.goals g
    where g.id = p_goal_id
      and g.family_id = private.current_family_id()
      and (g.member_id is null or g.member_id = (select auth.uid()))
  )
$$;

create or replace function private.is_demo_connection(p_connection_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.bank_connections bc
    where bc.id = p_connection_id and bc.is_demo_sync
  )
$$;

create or replace function private.can_write_connection(p_connection_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.owns_connection(p_connection_id)
     and not private.is_demo_connection(p_connection_id)
$$;

create or replace function private.can_view_transaction(p_transaction_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.transactions t
    where t.id = p_transaction_id
      and t.family_id = private.current_family_id()
      and (t.escopo = 'familia' or t.member_id = (select auth.uid()))
  )
$$;

create or replace function private.family_has_profiles(p_family_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.profiles where family_id = p_family_id)
$$;

create or replace function private.category_in_use(p_category_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.transactions where category_id = p_category_id)
      or exists (select 1 from public.recurring_rules where category_id = p_category_id)
$$;

revoke all on function private.current_family_id() from public;
revoke all on function private.is_active_member_of(uuid) from public;
revoke all on function private.is_admin_of(uuid) from public;
revoke all on function private.owns_connection(uuid) from public;
revoke all on function private.is_demo_connection(uuid) from public;
revoke all on function private.can_write_connection(uuid) from public;
revoke all on function private.can_view_transaction(uuid) from public;
revoke all on function private.can_view_rule(uuid) from public;
revoke all on function private.can_view_goal(uuid) from public;
revoke all on function private.family_has_profiles(uuid) from public;
revoke all on function private.category_in_use(uuid) from public;
grant usage on schema private to authenticated;
grant execute on function private.current_family_id() to authenticated;
grant execute on function private.is_active_member_of(uuid) to authenticated;
grant execute on function private.is_admin_of(uuid) to authenticated;
grant execute on function private.owns_connection(uuid) to authenticated;
grant execute on function private.can_write_connection(uuid) to authenticated;
grant execute on function private.can_view_transaction(uuid) to authenticated;
grant execute on function private.can_view_rule(uuid) to authenticated;
grant execute on function private.can_view_goal(uuid) to authenticated;
grant execute on function private.family_has_profiles(uuid) to authenticated;
grant execute on function private.category_in_use(uuid) to authenticated;
```

Todas usam `security definer` e `set search_path = ''` para evitar recursão de RLS e escalada por search_path. Não conceder a `anon`.

- [ ] **Step 3: Implementar triggers de identidade**

`tg_seed_default_categories` precisa ser `security definer`, com `set search_path = ''` e `insert into public.categories`, porque roda antes de existir o perfil do criador e insere em `categories` com RLS. Inserir as 8 categorias de despesa e as 4 de receita do teste.

`tg_guard_profile_update`:
- recusa mudança de `id`, `family_id` ou `papel` com `errcode='42501'`;
- recusa desativar o último admin ativo da família somente quando o alvo é admin: `old.papel='admin'`, `new.status='inativo'` e não existe outro admin ativo (`p.id <> old.id`); membros comuns podem ser desativados pelo admin;
- recusa mudança de `status` por quem não é admin da família (exceto quando `auth.uid()` é nulo, caso do seed/service role), com 42501;
- recusa que um admin altere o `tema` de outro membro; `tema` só muda pelo próprio dono (service role pode).

`tg_guard_family_update`: recusa mudar `is_demo` ou `criado_por` (42501). O `criado_por` imutável fecha a porta de autopromoção via `profiles_insert`.

`tg_guard_category_update`:
- categoria padrão (`personalizada=false`): só `oculta` pode mudar; qualquer outro campo → 42501;
- categoria personalizada: `family_id`, `criado_por` e `personalizada` imutáveis; `tipo` só pode mudar se `private.category_in_use(id)` for falso. Renomear e ocultar continuam permitidos.

- [ ] **Step 4: Rodar e commitar**

```powershell
supabase db reset
supabase test db
git add supabase/migrations/20261103000600_private_helpers.sql supabase/migrations/20261103000700_identity_triggers.sql supabase/tests/05_identity_triggers_test.sql
git commit -m "feat(db): helpers privados e triggers de identidade"
```

**Critério de aceite:** 12 categorias por família; última admin protegida; demo e campos de identidade imutáveis; helpers só para `authenticated`; testes verdes.

---

### Task 7: Triggers financeiros, de meta e de conexão

**Delegação:** com revisor independente obrigatório — mexe em status de meta, identidade de lançamento e timestamps.
**Ponytail:** só os triggers abaixo; nenhum trigger de criação automática de lançamento.

**Files:**
- Create: `supabase/migrations/20261103000800_financial_triggers.sql`
- Create: `supabase/tests/06_financial_triggers_test.sql`

**Interfaces:**
- Consumes: tabelas e helpers da Task 6.
- Produces:
  - `private.recalc_goal_status(p_goal_id uuid)` + `private.tg_recalc_goal_status_contribution()` e `private.tg_recalc_goal_status_target()` (triggers `security definer` após insert/update em `goal_contributions` e após update de `valor_alvo` em `goals`)
  - `tg_guard_goal_contribution` before insert on `goal_contributions`
  - `tg_guard_occurrence_status` before update on `recurring_occurrences`
  - `tg_reset_links_on_transaction_delete` before delete on `transactions`
  - `tg_sync_bank_link_from_transaction` after insert/update of `bank_transaction_id` on `transactions`
  - `public.set_updated_at()` + triggers em `bank_connections` e `bank_accounts`
  - `tg_guard_transaction_identity` before update on `transactions`
  - `tg_guard_recurring_rule_identity` before update on `recurring_rules`
  - `tg_guard_goal_identity` before update on `goals`
  - `tg_guard_bank_connection_identity` before update on `bank_connections`
  - `tg_guard_bank_transaction_identity` before update on `bank_transactions`
  - `tg_limit_bank_connections` before insert/update on `bank_connections`
  - `tg_guard_ai_suggestion_update` before update on `ai_suggestions`

- [ ] **Step 1: Teste que falha**

Prefix `66000000`. Afirmar:
- Inserir contribuição que atinge o `valor_alvo` muda `goals.status` de `em_andamento` para `concluida`; contribuição parcial não muda; reduzir o alvo para abaixo da soma conclui; aumentar o alvo acima da soma volta para `em_andamento`; meta `cancelada` não muda.
- Contribuição em meta `concluida` ou `cancelada` falha.
- `update transactions set member_id=...` falha; `set criado_por=...`, `set family_id=...`, `set escopo=...`, `set origem=...`, `set recurring_rule_id=...` e `set mes_referencia=...` falham.
- `update recurring_rules set criado_por=...` falha; `set escopo=...` falha.
- `update goals set member_id=...` falha; `set family_id=...` falha; `set criado_por=...` falha.
- `update bank_connections set member_id=...`, `pluggy_connection_id=...`, `is_demo_sync=...` falham; a 4ª conexão ativa falha, mas uma conexão `inativa` não conta.
- `update bank_transactions set valor=...`, `pluggy_transaction_id=...`, `is_demo_sync=...` falham; `set status=...` é permitido; `set transaction_id=...` é negado por privilégio de coluna (42501).
- `update ai_suggestions set o_que=...` falha; `set lida=true` funciona; voltar `lida` para `false` falha.
- `update bank_connections set status='inativa'` atualiza `atualizada_em`; antes do update, forçar `atualizada_em = now() - interval '1 day'` como postgres para a comparação não empatar com `now()` da transação.
- **Invariante:** atualizar uma `recurring_occurrence` para `confirmado` **não** cria linha em `transactions`; inserir `bank_transactions` também não. Apagar um lançamento vinculado remove a ocorrência confirmada (o cartão volta a aparecer por ausência) e devolve a transação bancária para `pendente_importacao`.
- Inserir um lançamento com `bank_transaction_id` marca a transação bancária como `importada` (origem pluggy) ou `reconciliada` (manual) e grava o `transaction_id`; limpar o vínculo devolve para `pendente_importacao`.

- [ ] **Step 2: Implementar**

`private.recalc_goal_status`, `tg_reset_links_on_transaction_delete` e `tg_sync_bank_link_from_transaction` são `security definer`, `set search_path = ''` e nomes schema-qualified; o resto dos triggers de guarda roda como invoker.
```sql
update public.goals g
set status = case
  when g.status = 'cancelada' then 'cancelada'
  when (select coalesce(sum(c.valor), 0) from public.goal_contributions c where c.goal_id = g.id) >= g.valor_alvo then 'concluida'
  else 'em_andamento'
end
where g.id = p_goal_id;
```
Os triggers `tg_recalc_goal_status_contribution` (após insert/update em `goal_contributions`, com `new.goal_id`) e `tg_recalc_goal_status_target` (após update de `valor_alvo`, com `new.id`) são `security definer`, `set search_path = ''` e chamam a função; não precisam de grant para `authenticated`.

`tg_guard_goal_contribution`: se a meta não estiver `em_andamento`, recusa com 42501. `tg_guard_occurrence_status`: se `old.status <> 'pendente'` e `new.status <> old.status`, recusa com 42501; a transição `pendente` → `confirmado`/`ignorado` continua livre.

`tg_reset_links_on_transaction_delete`:
```sql
if old.recurring_rule_id is not null then
  delete from public.recurring_occurrences
  where rule_id = old.recurring_rule_id and mes_referencia = old.mes_referencia;
end if;
if old.bank_transaction_id is not null then
  update public.bank_transactions
  set status = 'pendente_importacao', transaction_id = null
  where id = old.bank_transaction_id;
end if;
```

`tg_sync_bank_link_from_transaction`: depois de insert/update de `bank_transaction_id`, se o vínculo antigo existir e for diferente do novo, limpa a transação bancária antiga (`status='pendente_importacao'`, `transaction_id=null`); se o novo vínculo existe, atualiza a `bank_transactions` alvo com `transaction_id = new.id` e `status = case when new.origem='pluggy' then 'importada' else 'reconciliada' end`. É `security definer` com `search_path=''`; a policy de INSERT/UPDATE de `transactions` já garantiu que a conexão é do usuário.

`set_updated_at()`:
```sql
new.atualizada_em = now(); -- bank_connections
new.updated_at = now();    -- bank_accounts (trigger separado ou função com TG_TABLE_NAME)
```
Usar uma função `public.set_updated_at()` com `TG_TABLE_NAME` só se ela couber em 5 linhas; caso contrário, duas funções pequenas. Ponytail: duas funções de uma linha são aceitáveis.

`tg_guard_transaction_identity`: recusa mudança de `family_id`, `member_id`, `criado_por`, `origem`, `escopo`, `recurring_rule_id` e `mes_referencia` com 42501. `bank_transaction_id`, `valor`, `categoria`, `data`, `descricao`, `pago_por` continuam editáveis (reconciliação precisa do vínculo).

`tg_guard_recurring_rule_identity`: recusa mudança de `family_id`, `criado_por`, `escopo`.

`tg_guard_goal_identity`: recusa mudança de `family_id`, `member_id` e `criado_por`.

`tg_guard_bank_connection_identity`: recusa mudança de `family_id`, `member_id`, `pluggy_connection_id`, `is_demo_sync`.

`tg_guard_bank_transaction_identity`: recusa mudança de `bank_connection_id`, `bank_account_id`, `pluggy_transaction_id`, `valor`, `data`, `descricao`, `tipo`, `categoria_bancaria`, `is_demo_sync`; só `status` e `transaction_id` mudam.

`tg_limit_bank_connections`: antes de inserir ou reativar, conta as conexões `status='ativa'` do membro; se já houver 3 e a linha não for a mesma, recusa com 42501. `inativa` não conta.

`tg_guard_ai_suggestion_update`: recusa mudança de `family_id`, `member_id`, `tipo`, `titulo`, `o_que`, `por_que`, `quanto`; `lida` só pode ir de `false` para `true`.

- [ ] **Step 3: Rodar e commitar**

```powershell
supabase db reset
supabase test db
git add supabase/migrations/20261103000800_financial_triggers.sql supabase/tests/06_financial_triggers_test.sql
git commit -m "feat(db): triggers de meta, identidade e atualizacao"
```

**Critério de aceite:** meta recalcula ao inserir contribuição e ao mudar o alvo; contribuição só em meta `em_andamento`; campos de identidade imutáveis; timestamps atualizam; limite de 3 conexões ativas; dados brutos bancários e conteúdo da IA imutáveis; nenhuma ocorrência/transação bancária cria lançamento sozinha; apagar lançamento desfaz os vínculos.

---

### Task 8: RLS de identidade (`families`, `profiles`, `categories`)

**Delegação:** com revisor independente obrigatório — primeira camada de privacidade real.
**Ponytail:** só as políticas abaixo; nenhuma policy `for all` genérica.

**Files:**
- Create: `supabase/migrations/20261103000900_rls_identity.sql`
- Create: `supabase/tests/07_rls_identity_test.sql`

**Interfaces:**
- Consumes: helpers da Task 6; tabelas da Task 2.
- Produces: políticas `select/insert/update` de `families` e `profiles`, `select/insert/update/delete` de `categories`; DELETE de família/perfil é negado por ausência de policy (desativação via `status`).

- [ ] **Step 1: Teste que falha**

Prefix `77000000`. Rodar como Ana, Carlos, Lucas e Externo. Afirmar:
- Ana vê a própria família; Externo não vê a família A; Ana, já com perfil, não cria uma segunda família.
- Criador sem perfil consegue inserir a família e depois o próprio perfil como admin; um usuário qualquer **não** consegue inserir perfil na família A (42501); ninguém insere `papel='admin'` em família que já tem perfis.
- Ana (admin) vê 3 perfis da família A; Carlos vê só o próprio; Externo não vê nenhum da A.
- Ana atualiza `status` de Carlos para `inativo`; Carlos não atualiza o `status` de Lucas; Carlos atualiza o próprio `nome`.
- Ana não altera o `tema` de Carlos; Carlos altera o próprio tema.
- DELETE de família/perfil é negado (0 linhas/42501).
- Categorias da família A visíveis a Ana/Carlos; não visíveis a Externo.
- Carlos insere categoria personalizada; não consegue inserir categoria padrão (`personalizada=false`) nem categoria em família B.
- Renomear categoria padrão falha (trigger da Task 6); ocultar funciona.
- Carlos não renomeia categoria personalizada de Ana; Ana renomeia a própria.
- Ana não apaga categoria padrão; Carlos apaga a própria categoria personalizada sem uso; não apaga a de Ana; categoria em uso não pode ser apagada, mas pode ser ocultada.

- [ ] **Step 2: Implementar políticas**

```sql
-- families
create policy families_select on public.families
for select to authenticated
using (
  id = (select private.current_family_id())
  or (
    criado_por = (select auth.uid())
    and not exists (select 1 from public.profiles p where p.id = (select auth.uid()))
  )
);

create policy families_insert on public.families
for insert to authenticated
with check (
  criado_por = (select auth.uid())
  and is_demo = false
  and not exists (select 1 from public.profiles p where p.id = (select auth.uid()))
);

create policy families_update on public.families
for update to authenticated
using ((select private.is_admin_of(id)) and is_demo = false)
with check ((select private.is_admin_of(id)) and is_demo = false);

-- profiles
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
  and exists (
    select 1 from public.families f
    where f.id = family_id
      and f.criado_por = (select auth.uid())
      and f.is_demo = false
  )
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

-- categories
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
```

- [ ] **Step 3: Rodar e commitar**

```powershell
supabase db reset
supabase test db
git add supabase/migrations/20261103000900_rls_identity.sql supabase/tests/07_rls_identity_test.sql
git commit -m "feat(db): RLS de familias, perfis e categorias"
```

**Critério de aceite:** membro vê só o próprio perfil; admin vê os perfis da própria família; uma família por usuário; admin não muda tema alheio; família/perfil não têm DELETE; categorias padrão só ocultáveis; categoria em uso não é excluível; nenhum acesso cruzado entre famílias.

---

### Task 9: RLS bancário

**Delegação:** com revisor independente obrigatório — dados bancários são o ativo mais sensível.
**Ponytail:** só as políticas do §4.4; `bank_transactions` não tem INSERT/DELETE para usuário.

**Files:**
- Create: `supabase/migrations/20261103001000_rls_banking.sql`
- Create: `supabase/tests/08_rls_banking_test.sql`

**Interfaces:**
- Consumes: `private.owns_connection` (Task 6); tabelas da Task 5.
- Produces: políticas de `bank_connections`, `bank_accounts`, `bank_transactions`.

- [ ] **Step 1: Teste que falha**

Prefix `88000000`. Criar conexões para Ana e Carlos, uma conexão demo para Ana, uma transação bancária em cada e uma transação pendente na conexão demo. Afirmar:
- Ana vê a própria conexão; não vê a de Carlos; Carlos não vê a de Ana; Ana admin **não** vê a de Carlos.
- Ana vê apenas as `bank_accounts` e `bank_transactions` da própria conexão.
- **Membro inativo:** após `update profiles set status='inativo'` como postgres (com `reset request.jwt.claim.sub` antes), Carlos vê 0 conexões, 0 contas e 0 transações bancárias, mesmo com JWT válido.
- Ana insere conexão com `member_id` de Carlos → 42501.
- Ana não insere `bank_transactions` como `authenticated` → 42501 (sem policy de INSERT).
- Ana atualiza o `status` de uma `bank_transaction` da própria conexão não-demo → 1 linha; não atualiza a de Carlos; não atualiza a da conexão demo.
- Ana não atualiza nem apaga a conta da conexão demo; a conta da conexão normal é atualizável.
- Ana não deleta `bank_transaction` (sem policy) → 0 linhas/42501.
- Ana não deleta a própria conexão; desconexão é `status='inativa'`. Carlos também não deleta a conexão de Ana.
- Ana insere um lançamento pessoal com `bank_transaction_id` de uma transação demo pendente → passa; o trigger marca a demo como importada. O fluxo de importação é demonstrável, mas os dados brutos continuam sem edição direta.
- Ana tenta gravar `transaction_id` diretamente na `bank_transaction` → 42501 (o grant é só de `status`; o vínculo é escrito pelo trigger).

- [ ] **Step 2: Implementar políticas**

```sql
-- bank_connections
create policy bank_connections_select on public.bank_connections
for select to authenticated
using (member_id = (select auth.uid()) and family_id = (select private.current_family_id()));
create policy bank_connections_insert on public.bank_connections
for insert to authenticated
with check (
  member_id = (select auth.uid())
  and family_id = (select private.current_family_id())
  and is_demo_sync = false
);
create policy bank_connections_update on public.bank_connections
for update to authenticated
using (member_id = (select auth.uid()) and family_id = (select private.current_family_id()))
with check (
  member_id = (select auth.uid())
  and family_id = (select private.current_family_id())
  and is_demo_sync = false
);
-- sem DELETE: desconexão = status 'inativa'; DELETE fica para service role.

-- bank_accounts
create policy bank_accounts_select on public.bank_accounts
for select to authenticated
using ((select private.owns_connection(connection_id)));
create policy bank_accounts_insert on public.bank_accounts
for insert to authenticated
with check ((select private.can_write_connection(connection_id)));
create policy bank_accounts_update on public.bank_accounts
for update to authenticated
using ((select private.can_write_connection(connection_id)))
with check ((select private.can_write_connection(connection_id)));
-- sem DELETE: conta é sincronizada pelo Pluggy; demo é somente leitura.

-- bank_transactions
create policy bank_transactions_select on public.bank_transactions
for select to authenticated
using ((select private.owns_connection(bank_connection_id)));
create policy bank_transactions_update on public.bank_transactions
for update to authenticated
using (
  (select private.can_write_connection(bank_connection_id))
  and (transaction_id is null or (select private.can_view_transaction(transaction_id)))
)
with check (
  (select private.can_write_connection(bank_connection_id))
  and (transaction_id is null or (select private.can_view_transaction(transaction_id)))
);
-- sem INSERT/DELETE para authenticated; service_role bypassa.
```

- [ ] **Step 3: Rodar e commitar**

```powershell
supabase db reset
supabase test db
git add supabase/migrations/20261103001000_rls_banking.sql supabase/tests/08_rls_banking_test.sql
git commit -m "feat(db): RLS de conexoes, contas e transacoes bancarias"
```

**Critério de aceite:** admin não vê banco de outro membro; usuário não insere transação bancária; usuário não deleta conexão/conta/transação; conexão só do dono; dados brutos da demo são somente leitura, mas importar/reconciliar a partir das pendências é permitido; `transaction_id` só é escrito pelo trigger do lançamento, nunca direto pelo usuário.

---

### Task 10: RLS financeiro (`transactions`, `recurring_rules`, `recurring_occurrences`)

**Delegação:** com revisor independente obrigatório — é a política central de privacidade da spec.
**Ponytail:** só as políticas abaixo; nenhum bypass para admin.

**Files:**
- Create: `supabase/migrations/20261103001100_rls_financial.sql`
- Create: `supabase/tests/09_rls_financial_test.sql`

**Interfaces:**
- Consumes: helpers da Task 6; `private.owns_connection`; tabelas das Tasks 3 e 5.
- Produces: políticas de `transactions`, `recurring_rules`, `recurring_occurrences`.

- [ ] **Step 1: Teste que falha**

Prefix `99000000`. Criar: Ana pessoal 100; Carlos pessoal 200; família 300 (Ana); família receita 1000 (Carlos); regra pessoal de Ana; regra família; ocorrências; conexão + conta + transação bancária para Ana e para Carlos. Afirmar:
- Carlos vê 3 lançamentos (o pessoal dele + 2 da família), **não** o pessoal de Ana; Ana vê 3 (o dela + 2 da família), **não** o de Carlos.
- Carlos atualiza a transação da família → 1 linha; não atualiza a pessoal de Ana → 0 linhas.
- Ana cria uma transação familiar importada (`origem='pluggy'` com a `bank_transaction_id` dela); Carlos edita a descrição → 1 linha, porque o escopo é família.
- Carlos não deleta a transação da família (não é autor) → 0 linhas; Ana deleta a própria transação da família → 1 linha.
- Carlos insere transação pessoal com `member_id` de Ana → 42501.
- Carlos insere transação na família B → 42501.
- Carlos insere transação com `recurring_rule_id` de uma regra pessoal de Ana → 42501 (a policy exige `can_view_rule`).
- Carlos insere transação com `bank_transaction_id` de uma transação bancária de Ana → 42501.
- Carlos insere transação `origem='pluggy'` sem `bank_transaction_id` → 23514; com a própria transação bancária → passa.
- Regra pessoal de Ana invisível a Carlos; regra família visível/editável por Carlos; DELETE de regra é negado, mas `ativo=false` funciona.
- Ocorrência de regra pessoal de Ana invisível a Carlos; ocorrência da regra família pode ser confirmada por Carlos; INSERT direto de ocorrência `confirmado` por `authenticated` → 42501 (só `pendente` entra; a confirmação é UPDATE junto com o lançamento).
- Confirmar ocorrência **não** cria `transactions`.
- Membro inativo: após `reset role; reset request.jwt.claim.sub;` e `update profiles set status='inativo'` como postgres, Carlos vê 0 transações e não insere.

- [ ] **Step 2: Implementar políticas**

```sql
-- transactions
create policy transactions_select on public.transactions
for select to authenticated
using (
  family_id = (select private.current_family_id())
  and (escopo = 'familia' or member_id = (select auth.uid()))
);

create policy transactions_insert on public.transactions
for insert to authenticated
with check (
  family_id = (select private.current_family_id())
  and member_id = (select auth.uid())
  and criado_por = (select auth.uid())
  and (recurring_rule_id is null or (select private.can_view_rule(recurring_rule_id)))
  and (bank_transaction_id is null or exists (
    select 1
    from public.bank_transactions bt
    where bt.id = bank_transaction_id
      and (select private.owns_connection(bt.bank_connection_id))
  ))
);

create policy transactions_update on public.transactions
for update to authenticated
using (
  family_id = (select private.current_family_id())
  and (escopo = 'familia' or member_id = (select auth.uid()))
)
with check (
  family_id = (select private.current_family_id())
  and (escopo = 'familia' or member_id = (select auth.uid()))
  and (recurring_rule_id is null or escopo = 'familia' or (select private.can_view_rule(recurring_rule_id)))
  and (bank_transaction_id is null or escopo = 'familia' or exists (
    select 1
    from public.bank_transactions bt
    where bt.id = bank_transaction_id
      and (select private.owns_connection(bt.bank_connection_id))
  ))
);

create policy transactions_delete on public.transactions
for delete to authenticated
using (
  family_id = (select private.current_family_id())
  and criado_por = (select auth.uid())
);

-- recurring_rules
create policy recurring_rules_select on public.recurring_rules
for select to authenticated
using (
  family_id = (select private.current_family_id())
  and (escopo = 'familia' or criado_por = (select auth.uid()))
);
create policy recurring_rules_insert on public.recurring_rules
for insert to authenticated
with check (
  family_id = (select private.current_family_id())
  and criado_por = (select auth.uid())
);
create policy recurring_rules_update on public.recurring_rules
for update to authenticated
using (
  family_id = (select private.current_family_id())
  and (escopo = 'familia' or criado_por = (select auth.uid()))
)
with check (
  family_id = (select private.current_family_id())
  and (escopo = 'familia' or criado_por = (select auth.uid()))
);
-- sem DELETE: regra se desativa com ativo=false; o histórico fica.

-- recurring_occurrences
create policy recurring_occurrences_select on public.recurring_occurrences
for select to authenticated
using ((select private.can_view_rule(rule_id)));
create policy recurring_occurrences_insert on public.recurring_occurrences
for insert to authenticated
with check (
  (select private.can_view_rule(rule_id))
  and status = 'pendente'
  and confirmado_por is null
);
create policy recurring_occurrences_update on public.recurring_occurrences
for update to authenticated
using ((select private.can_view_rule(rule_id)))
with check (
  (select private.can_view_rule(rule_id))
  and (confirmado_por is null or confirmado_por = (select auth.uid()))
);
```

O trigger da Task 7 já protege `family_id`, `member_id`, `criado_por`, `origem`, `escopo`, `recurring_rule_id` e `mes_referencia` no UPDATE; a policy não precisa repetir. A condição `origem='pluggy' => bank_transaction_id` fica só no CHECK da tabela, para o erro ser 23514.

- [ ] **Step 3: Rodar e commitar**

```powershell
supabase db reset
supabase test db
git add supabase/migrations/20261103001100_rls_financial.sql supabase/tests/09_rls_financial_test.sql
git commit -m "feat(db): RLS de lancamentos e recorrentes"
```

**Critério de aceite:** admin não vê/edita pessoal de outro; família é compartilhada para edição e só o autor deleta; inativo perde tudo; `pluggy` só com vínculo próprio; regra recorrente se desativa, não se apaga.

---

### Task 11: RLS de metas, IA e diretório

**Delegação:** com revisor independente obrigatório.
**Ponytail:** sem policy de UPDATE/DELETE para contribuições e mensagens; só o necessário.

**Files:**
- Create: `supabase/migrations/20261103001200_rls_goals_ai.sql`
- Create: `supabase/tests/10_rls_goals_ai_test.sql`

**Interfaces:**
- Consumes: `private.can_view_goal`; tabelas da Task 4.
- Produces: políticas de `goals`, `goal_contributions`, `ai_messages`, `ai_suggestions`.

- [ ] **Step 1: Teste que falha**

Prefix `aa000000`. Afirmar:
- Meta familiar visível a Ana/Carlos; meta pessoal de Ana invisível a Carlos.
- Carlos insere meta familiar com `criado_por` de Ana → 42501; com o próprio `criado_por` → passa.
- Carlos não exclui a meta familiar criada por Ana; Ana exclui a própria meta familiar; Carlos exclui a própria meta pessoal; excluir a meta remove as contribuições em cascade, enquanto `status='cancelada'` as preserva.
- Carlos insere contribuição na meta familiar com `member_id` próprio → passa; com `member_id` de Ana → 42501; na meta pessoal de Ana → 42501; em meta `concluida`/`cancelada` → 42501.
- Contribuições da meta familiar visíveis a todos; da meta pessoal de Ana só a ela.
- Inserir contribuição que atinge o alvo muda status para `concluida` (trigger da Task 7) e não cria alerta persistido.
- `ai_messages` com `member_id=null` visível a todos; pessoal de Ana invisível a Carlos; Carlos não insere mensagem como Ana.
- `ai_suggestions` idem; `lida` de sugestão familiar pode ser atualizada por qualquer membro; `lida` de sugestão pessoal só pelo dono; Carlos não altera `o_que`/`por_que`/`quanto` de sugestão familiar.
- Nenhuma policy de UPDATE/DELETE em `goal_contributions`/`ai_messages` (contribuições e mensagens imutáveis na v1).

- [ ] **Step 2: Implementar políticas**

```sql
-- goals
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

-- goal_contributions
create policy goal_contributions_select on public.goal_contributions
for select to authenticated
using ((select private.can_view_goal(goal_id)));
create policy goal_contributions_insert on public.goal_contributions
for insert to authenticated
with check (
  member_id = (select auth.uid())
  and (select private.can_view_goal(goal_id))
);

-- ai_messages
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

-- ai_suggestions
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
```

- [ ] **Step 3: Rodar e commitar**

```powershell
supabase db reset
supabase test db
git add supabase/migrations/20261103001200_rls_goals_ai.sql supabase/tests/10_rls_goals_ai_test.sql
git commit -m "feat(db): RLS de metas, contribuicoes e IA"
```

**Critério de aceite:** metas pessoais invisíveis a terceiros; família compartilhada; só o criador exclui meta; contribuição só em meta `em_andamento`; contribuições/mensagens imutáveis; mensagens de assistente são gravadas pela API e não editáveis; conteúdo da IA só muda por `lida`; IA familiar vs. pessoal separada.

---

### Task 12: Funções de leitura agregada da família

**Delegação:** com revisor independente obrigatório — é a única porta que atravessa escopos pessoais.
**Ponytail:** quatro funções, só agregados; nenhuma view que exponha linhas.

**Files:**
- Create: `supabase/migrations/20261103001300_family_read_functions.sql`
- Create: `supabase/tests/11_read_functions_test.sql`

**Interfaces:**
- Consumes: `private.is_active_member_of`; tabelas das Tasks 2–4.
- Produces: `private.assert_family_member(p_family_id uuid) returns void` (levanta 42501) e as 4 funções do §6.3, com grants apenas para `authenticated`.

- [ ] **Step 1: Teste que falha**

Prefix `bb000000`. Criar Ana pessoal 100, Carlos pessoal 200, família 300, receita família 1000, usando as categorias padrão criadas pela trigger (ex.: `Alimentação` e `Lazer`), tudo no mês corrente (`date_trunc('month', current_date)::date`). Afirmar:
- `family_totals(family, mês)` como Carlos retorna `receitas=1000`, `despesas=600` (inclui o pessoal da Ana, mas não retorna linhas).
- `family_totals` como Externo → 42501; como membro inativo → 42501; como `anon` → 42501.
- `has_function_privilege('anon', 'public.family_totals(uuid,date)', 'EXECUTE') = false`; `has_function_privilege('authenticated', 'public.family_totals(uuid,date)', 'EXECUTE') = true`.
- `family_totals(family, date '2026-11-15')` → 22023 (só o primeiro dia do mês é aceito).
- `family_category_totals` retorna totais por categoria, sem coluna `member_id`; `proargnames[3:5]` é `{category_id,categoria,total}`.
- `family_monthly_totals` retorna apenas os meses com lançamentos (não preenche meses vazios; o frontend preenche zeros); no fixture, 1 linha.
- `family_member_directory` retorna 3 ativos; após inativar Lucas, retorna 2; não retorna e-mail/status.
- `prosecdef=true` e `proconfig @> array['search_path=']` nas 4 funções.
- As 3 funções de totais não retornam `member_id` (checar `proargnames`); `family_member_directory` retorna `member_id`, `nome`, `papel` — é o diretório de avatares, não dado financeiro.
- `authenticated` não executa `private.assert_family_member` diretamente → 42501.

- [ ] **Step 2: Implementar**

As 4 funções são `security definer`, `stable`, `set search_path = ''`, `language sql`, e começam com `select private.assert_family_member(p_family_id);` e, quando aplicável, `select private.assert_month_start(p_mes);` ou `p_mes_fim`.

Criar `private.assert_family_member(p_family_id uuid) returns void` e `private.assert_month_start(p_mes date) returns void` em `plpgsql`, `security definer`, `set search_path = ''`:

```sql
if not private.is_active_member_of(p_family_id) then
  raise exception 'not a family member' using errcode = '42501';
end if;

if p_mes <> date_trunc('month', p_mes)::date then
  raise exception 'month start required' using errcode = '22023';
end if;
```

`revoke all` de `public` nas duas funções de assert e **não** conceder a `authenticated`: elas são chamadas pelas funções públicas `security definer`. Nas 4 funções públicas, `grant execute` apenas para `authenticated`.

`family_totals(p_family_id uuid, p_mes date)`:
```sql
select
  coalesce(sum(case when t.tipo = 'receita' then t.valor else 0 end), 0)::numeric(14,2) as receitas,
  coalesce(sum(case when t.tipo = 'despesa' then t.valor else 0 end), 0)::numeric(14,2) as despesas
from public.transactions t
where t.family_id = p_family_id
  and t.data >= p_mes
  and t.data < (p_mes + interval '1 month')::date;
```

`family_category_totals(p_family_id uuid, p_mes date)`: join `public.categories c` com `public.transactions t`, filtrar `t.tipo='despesa'`, agrupar por `c.id, c.nome`, somar `t.valor`, no intervalo do mês.

`family_monthly_totals(p_family_id uuid, p_mes_fim date)`: agrupar por `date_trunc('month', t.data)::date`, somar receitas/despesas, com `t.data >= (p_mes_fim - interval '5 months')::date` e `t.data < (p_mes_fim + interval '1 month')::date`.

`family_member_directory(p_family_id uuid)`:
```sql
select p.id as member_id, p.nome, p.papel
from public.profiles p
where p.family_id = p_family_id and p.status = 'ativo'
order by p.nome;
```

Grants:
```sql
revoke all on function public.family_totals(uuid, date) from public, anon, authenticated;
grant execute on function public.family_totals(uuid, date) to authenticated;
revoke all on function public.family_category_totals(uuid, date) from public, anon, authenticated;
grant execute on function public.family_category_totals(uuid, date) to authenticated;
revoke all on function public.family_monthly_totals(uuid, date) from public, anon, authenticated;
grant execute on function public.family_monthly_totals(uuid, date) to authenticated;
revoke all on function public.family_member_directory(uuid) from public, anon, authenticated;
grant execute on function public.family_member_directory(uuid) to authenticated;
```

- [ ] **Step 3: Rodar e commitar**

```powershell
supabase db reset
supabase test db
git add supabase/migrations/20261103001300_family_read_functions.sql supabase/tests/11_read_functions_test.sql
git commit -m "feat(db): funcoes de leitura agregada da familia"
```

**Critério de aceite:** agregados corretos incluindo escopo pessoal; só janelas mensais (dia isolado é recusado com 22023); não membro/inativo/anon recusados; `assert_family_member`/`assert_month_start` não são executáveis por `authenticated`; as 3 funções de totais não devolvem `member_id` nem linha individual; `family_member_directory` devolve só `member_id`/`nome`/`papel` de ativos.

---

### Task 13: Família Demo (seed idempotente)

**Delegação:** sim — tarefa grande/repetitiva, com contrato de dados fechado e teste de aceite; revisor confere fidelidade à spec §8.1.
**Ponytail:** gerar histórico com `generate_series` e fórmulas determinísticas; não escrever 90 INSERTs à mão.

**Files:**
- Create: `supabase/seed/010_demo_users.sql`
- Create: `supabase/seed/020_demo_family.sql`
- Create: `supabase/seed/030_demo_history.sql`
- Create: `supabase/seed/040_demo_banking.sql`
- Create: `supabase/tests/12_seed_test.sql`
- Modify: `supabase/README.md` (credenciais demo)

**Interfaces:**
- Consumes: schema, triggers, RLS e funções das tasks anteriores.
- Produces: Família Demo `eeeeeeee-0000-4000-8000-000000000001`, Ana (`...00a1`, admin), Carlos (`...00b2`), Lucas (`...00c3`), senha `Demo@2026!`; 6 meses de histórico; conexão bancária simulada.

**Dados fixos:**
- Emails: `ana@demo.vivafinancas.app`, `carlos@demo.vivafinancas.app`, `lucas@demo.vivafinancas.app`.
- Senha: `Demo@2026!` (bcrypt via `extensions.crypt(..., extensions.gen_salt('bf'))`).
- Família: `Família Demo`, `is_demo=true`.
- Categorias padrão: 12 no total, 8 de despesa e 4 de receita (`Salário`, `Freelance`, `Investimentos`, `Outros`). Nenhuma categoria customizada no seed; a demo usa as padrão.
- Regras: aluguel 1800 (família, dia 5), salário Ana 6500 (pessoal, dia 5), salário Carlos 5200 (pessoal, dia 5), streaming 59,90 (família, dia 15), música 21,90 (pessoal Ana, dia 20), academia 129,90 (pessoal Carlos, dia 10).
- Metas: “Viagem em família” 12000 (família, criada por Ana; contribuições 2000 Ana + 1500 Carlos + 500 Lucas); “Curso de fotografia” 2500 (Ana, criada por Ana, 800); “Notebook novo” 5000 (Carlos, criada por Carlos, 1200).
- IA: 4 sugestões (2 família, 2 pessoais), todas com `o_que`, `por_que`, `quanto` não vazios; pelo menos uma com “não é possível estimar” em `quanto`; 4 mensagens (2 família, 2 pessoais).
- Banco: 1 conexão `Banco Demo` (`is_demo_sync=true`, status `ativa`), 1 conta corrente saldo 4820,35, 8 transações com os 4 status (`pendente_importacao`, `importada`, `ignorada`, `reconciliada`); pelo menos uma importada e uma reconciliada com vínculo bidirecional.

- [ ] **Step 1: Escrever o teste de seed que falha**

`supabase/tests/12_seed_test.sql` com as asserções abaixo (contagens, 6 meses, aluguel 1800, 3 metas, sugestões completas, banco, auth bcrypt, ausência de credenciais). Rodar `supabase db reset && supabase test db`; esperado: falha porque o seed está vazio.

Asserções mínimas:
- 1 família `is_demo`, 3 perfis, 1 admin (Ana).
- 12 categorias padrão (`personalizada=false`): 8 de despesa e 4 de receita.
- 6 regras recorrentes; 6 meses distintos com lançamentos; 6 aluguéis de 1800; 6 salários de Ana e 6 de Carlos; `max(transactions.data) <= (now() at time zone 'America/Sao_Paulo')::date`.
- 3 metas (1 familiar, 2 pessoais); contribuições da meta familiar somam 4000; status `em_andamento`; toda meta tem `criado_por` preenchido e a familiar foi criada por Ana.
- 4 sugestões de IA; nenhuma com `o_que`/`por_que`/`quanto` vazio; pelo menos uma com “não é possível estimar” em `quanto`.
- 1 conexão demo, 1 conta, 8 transações bancárias, 4 status distintos; `bank_transactions.is_demo_sync=true` nas 8; `account_name`, `account_type`, `account_number_masked` e `ultima_sync_em` preenchidos; importadas/reconciliadas com `transaction_id` não nulo; todo `transactions.origem='pluggy'` com `bank_transaction_id` não nulo; no par reconciliado, `transactions.member_id = bank_connections.member_id`.
- 3 usuários Auth demo, 3 identidades email, senhas em bcrypt e não em texto puro.
- Nenhuma coluna `password|senha|token|secret|credential|credencial` nas tabelas `bank_%`.
- Nenhum lançamento com `data` futura; 3 ocorrências `pendente` no mês corrente (streaming, música, academia).
- Reexecutar os quatro arquivos de seed no mesmo banco não aumenta as contagens acima.

- [ ] **Step 2: Criar usuários Auth**

`010_demo_users.sql`:
- limpar demo existente (idempotência). A ordem importa: `transactions` antes de `bank_transactions` por causa da FK `on delete restrict`; o trigger de delete de lançamento limpa o vínculo bancário antes.
```sql
delete from public.transactions where family_id = 'eeeeeeee-0000-4000-8000-000000000001';
delete from public.bank_transactions where bank_connection_id in (select id from public.bank_connections where family_id = 'eeeeeeee-0000-4000-8000-000000000001');
delete from public.bank_accounts where connection_id in (select id from public.bank_connections where family_id = 'eeeeeeee-0000-4000-8000-000000000001');
delete from public.bank_connections where family_id = 'eeeeeeee-0000-4000-8000-000000000001';
delete from public.goal_contributions where goal_id in (select id from public.goals where family_id = 'eeeeeeee-0000-4000-8000-000000000001');
delete from public.goals where family_id = 'eeeeeeee-0000-4000-8000-000000000001';
delete from public.ai_messages where family_id = 'eeeeeeee-0000-4000-8000-000000000001';
delete from public.ai_suggestions where family_id = 'eeeeeeee-0000-4000-8000-000000000001';
delete from public.recurring_occurrences where rule_id in (select id from public.recurring_rules where family_id = 'eeeeeeee-0000-4000-8000-000000000001');
delete from public.recurring_rules where family_id = 'eeeeeeee-0000-4000-8000-000000000001';
delete from public.categories where family_id = 'eeeeeeee-0000-4000-8000-000000000001';
delete from public.profiles where family_id = 'eeeeeeee-0000-4000-8000-000000000001';
delete from public.families where id = 'eeeeeeee-0000-4000-8000-000000000001';
delete from auth.sessions where user_id in ('...00a1','...00b2','...00c3');
delete from auth.refresh_tokens where user_id in ('...00a1','...00b2','...00c3');
delete from auth.identities where user_id in ('...00a1','...00b2','...00c3');
delete from auth.users where id in ('...00a1','...00b2','...00c3');
```
Se a versão local do GoTrue não tiver `auth.sessions`/`auth.refresh_tokens`, remover essas duas linhas e registrar no README; não mascarar erro de FK. O endpoint “Restaurar demo” da fatia 2 roda `010`–`040`, então recria os usuários e encerra a sessão do visitante; a UI deve avisar e voltar ao login.
- inserir os 3 usuários com `instance_id='00000000-0000-0000-0000-000000000000'`, `aud='authenticated'`, `role='authenticated'`, `email_confirmed_at=now()`, `encrypted_password=extensions.crypt('Demo@2026!', extensions.gen_salt('bf'))`, `raw_app_meta_data='{"provider":"email","providers":["email"]}'`, `raw_user_meta_data=jsonb_build_object('nome', ...)`, timestamps e tokens vazios;
- inserir `auth.identities` com `provider='email'`, `provider_id=user_id::text`, `identity_data=jsonb_build_object('sub', user_id::text, 'email', email)`.

- [ ] **Step 3: Criar família e perfis**

`020_demo_family.sql`:
- `insert into families (id, nome, criado_por, is_demo) values (...)` — o trigger cria as 12 categorias padrão;
- `insert into profiles` Ana admin, Carlos/Lucas membros, todos ativos.

- [ ] **Step 4: Criar histórico de 6 meses**

`030_demo_history.sql`:
- definir `v_as_of := (now() at time zone 'America/Sao_Paulo')::date`; usar `date_trunc('month', v_as_of)` como mês corrente e `generate_series(0,5)` para os meses;
- toda data de lançamento passa por `least(data_calculada, v_as_of)`, inclusive aluguel/salários do dia 5 e supermercado/transporte/lazer. Assim a suíte não depende do dia do mês e nenhum lançamento fica no futuro;
- inserir as 6 regras com UUIDs fixos (para os testes e vínculos);
- inserir ocorrências: confirmadas para os 5 meses passados de todas as regras; no mês corrente, confirmadas para aluguel/salários e pendentes para streaming/música/academia;
- inserir transações de aluguel e salários nos 6 meses (valores exatos 1800/6500/5200; aluguel em `Moradia`, salários em `Salário`), streaming/música/academia nos 5 meses passados, supermercado 4x/mês, transporte 3x/mês, lazer 2x/mês com valores determinísticos (ex.: `380 + ((m*37 + w*23) % 120)`), todas com `data <= v_as_of`;
- `criado_por`/`member_id` coerentes; `pago_por` só em escopo família; `origem='manual'`;
- inserir 3 metas e contribuições (abaixo do alvo, status `em_andamento`); preencher `criado_por` com Ana na meta familiar e com o próprio membro nas pessoais;
- inserir sugestões e mensagens de IA (família com `member_id=null`).

- [ ] **Step 5: Criar dados bancários simulados**

`040_demo_banking.sql`:
- conexão/Conta Demo de Ana (`is_demo_sync=true`, `status='ativa'`, `account_name='Conta Corrente'`, `account_type='corrente'`, `account_number_masked='**** 4321'`, `ultima_sync_em=now()`);
- inserir as 8 transações bancárias primeiro com `status='pendente_importacao'` (ou `ignorada` para as ignoradas) e `transaction_id=null`; `pluggy_transaction_id` únicos por conexão e `is_demo_sync=true` em todas;
- importada: escolher uma transação pendente e inserir `transactions` com `origem='pluggy'` e `bank_transaction_id`; o trigger promove a transação bancária para `importada` e grava `transaction_id`;
- reconciliada: escolher uma transação pendente e uma transação manual **de Ana**, escopo pessoal, sem vínculo; gravar `bank_transaction_id` no lançamento; o trigger promove a transação bancária para `reconciliada` e grava `transaction_id`;
- ignoradas/pendentes sem vínculo e com `transaction_id` nulo.

- [ ] **Step 6: Rodar o reset duas vezes e testar a idempotência de verdade**

```powershell
supabase db reset
supabase db reset
$env:DB_URL = ((supabase status -o env | Select-String '^DB_URL=').Line -split '=',2)[1].Trim('"')
psql $env:DB_URL -v ON_ERROR_STOP=1 -f supabase/seed/010_demo_users.sql
psql $env:DB_URL -v ON_ERROR_STOP=1 -f supabase/seed/020_demo_family.sql
psql $env:DB_URL -v ON_ERROR_STOP=1 -f supabase/seed/030_demo_history.sql
psql $env:DB_URL -v ON_ERROR_STOP=1 -f supabase/seed/040_demo_banking.sql
supabase test db
```

Esperado: os dois resets passam; a segunda execução dos quatro arquivos, no mesmo banco, também passa e não duplica dados. `db reset` sozinho recria o volume e não exercita o cleanup; a reexecução é o teste real da idempotência. Use `psql`, não `supabase db query --file`: o `db query` do CLI 3.0.0 aceita um statement por chamada e recusa os arquivos multi-statement com `42601`.

- [ ] **Step 7: Verificar login demo de verdade**

```powershell
$env:API_URL = ((supabase status -o env | Select-String '^API_URL=').Line -split '=',2)[1].Trim('"')
$env:ANON_KEY = ((supabase status -o env | Select-String '^ANON_KEY=').Line -split '=',2)[1].Trim('"')
Invoke-RestMethod -Method Post -Uri "$env:API_URL/auth/v1/token?grant_type=password" `
  -Headers @{ apikey = $env:ANON_KEY } -ContentType 'application/json' `
  -Body '{"email":"ana@demo.vivafinancas.app","password":"Demo@2026!"}'
```

O `.Trim('"')` remove as aspas que o CLI 3.0.0 coloca no valor. Esperado: resposta com `access_token` não vazio. Se falhar, o seed de Auth está errado; não mascarar com “login depois”.

- [ ] **Step 8: Atualizar README e commitar**

```powershell
git add supabase/seed supabase/tests/12_seed_test.sql supabase/README.md
git commit -m "feat(seed): familia demo com seis meses de historico"
```

**Critério de aceite:** reset duas vezes sem erro; reexecutar os quatro arquivos de seed no mesmo banco sem duplicar; teste de seed verde; login demo retorna `access_token`; nenhuma credencial bancária; 8 transações demo com `is_demo_sync=true`; 4 status bancários representados; 6 meses de histórico; o seed é a fonte do botão “Restaurar demo” da fatia 2, que recria usuários e encerra a sessão do visitante.

---

### Task 14: Verificação final e handoff para a fatia 2

**Delegação:** não — gate final.
**Ponytail:** só verificação e README; nenhuma feature nova.

**Files:**
- Modify: `supabase/README.md`
- Modify: `README.md`
- Create: `supabase/checks/inventory.sql`

**Interfaces:**
- Consumes: tudo.
- Produces: fatia 1 verificada; notas para a fatia 2.

- [ ] **Step 1: Rodar a suíte completa**

```powershell
supabase db reset
supabase test db
supabase db lint --schema public,private --level warning --fail-on error
```

Esperado: todos os testes passam; `db lint` retorna 0. No CLI 3.0.0, o default é `--fail-on none`; sem o flag, o comando sai 0 mesmo com erro.

- [ ] **Step 2: Verificar inventário**

Salvar em `supabase/checks/inventory.sql`:

```sql
select tablename, rowsecurity from pg_tables where schemaname='public' order by tablename;
select schemaname, tablename, policyname from pg_policies where schemaname='public' order by tablename, policyname;
select proname, prosecdef, proconfig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and proname like 'family_%';
```

```powershell
$env:DB_URL = ((supabase status -o env | Select-String '^DB_URL=').Line -split '=',2)[1].Trim('"')
psql $env:DB_URL -v ON_ERROR_STOP=1 -f supabase/checks/inventory.sql
```

Esperado: 13 tabelas, todas com `rowsecurity=true`; políticas nas 13; 4 funções `family_*` com `prosecdef=true` e `proconfig @> array['search_path=']`; `private` sem grants para `anon`. Use `psql` porque `inventory.sql` tem três statements e o `db query` do CLI 3.0.0 aceita um por chamada.

- [ ] **Step 3: Varredura de segredos**

```powershell
Get-ChildItem -Recurse -File supabase | Select-String -Pattern 'PLUGGY_API_KEY|X-API-KEY|password|senha|token|secret'
```

Esperado: nenhuma ocorrência de chave/token/credencial bancária. Ocorrências de `encrypted_password`, `auth.identities` e colunas de token vazio do GoTrue no seed de Auth são esperadas e não são credenciais bancárias; ler cada match e justificar no relatório.

- [ ] **Step 4: Conferir a matriz de cobertura**

| Requisito da spec | Onde está |
|---|---|
| 13 tabelas | Tasks 2–5 |
| RLS por membro e admin sem bypass | Tasks 8–11 |
| Privacidade bancária | Task 9 |
| Agregados do painel | Task 12 |
| Seed demo (Ana/Carlos/Lucas, 6 meses) | Task 13 |
| Demo editável com restauração | §1, §9.1, Task 13 |
| Categorias padrão (8+4) | Tasks 2, 6, 13 |
| Recorrentes com confirmação | Tasks 3, 7, 10, 13 |
| Metas com criador e recálculo | Tasks 4, 7, 11, 13 |
| IA (mensagens/sugestões) e `lida` compartilhada | Tasks 4, 7, 11, 13 |
| Tema claro/escuro persistido | `profiles.tema` (Task 2) |
| Nenhuma credencial bancária | Tasks 5, 9, 13, 14 |
| Transação bancária nunca vira lançamento sozinha | Tasks 5, 7, 9, 13 |
| README local | Tasks 1 e 14 |

- [ ] **Step 5: Handoff para a fatia 2**

No `supabase/README.md`, registrar:
- como o Flask autentica (JWT do usuário; service role só para Admin API, seed e sync; restauração usa `SUPABASE_DB_URL`);
- as 4 funções `family_*` e suas assinaturas;
- os valores canônicos de status/escopo;
- que `bank_transactions` INSERT é só service role;
- que `transactions` com `origem='pluggy'` exige vínculo e confirmação;
- que `POST /api/demo/restore` reexecuta `supabase/seed/*.sql` via conexão Postgres direta (`SUPABASE_DB_URL`) dentro de uma transação, recria usuários/dados, encerra a sessão do visitante e só aceita membro da demo; a service role key não executa SQL;
- as decisões da §9 que afetam o backend.

- [ ] **Step 6: Commit final**

```powershell
git add README.md supabase/README.md supabase/checks
git commit -m "docs: handoff da fatia supabase para o backend"
```

**Critério de aceite:** suíte completa verde; inventário confere; nenhum segredo; README permite um engenheiro novo rodar a fatia do zero; decisões registradas.

---

## 9. Decisões tomadas e confirmações

### 9.1 Produto (respondido em 2026-11-03)

- **Painel:** avatares e nomes dos membros, sem valores individuais. A função `family_member_directory` entrega id, nome e papel dos ativos.
- **Família Demo:** o visitante pode explorar e testar. A fatia 2 expõe “Restaurar demo”, que reexecuta `010`–`040` via conexão Postgres direta (`SUPABASE_DB_URL`) e recria usuários e dados; a restauração é global, disponível a qualquer membro da demo, e encerra a sessão do visitante, então a UI deve avisar e voltar ao login. Isso substitui a frase da spec §3.10 no ponto “não pode ser modificada por usuários normais”. O flag `is_demo` e os dados brutos da conexão bancária simulada continuam protegidos; contas e transações demo não são editáveis diretamente, mas a importação/reconciliação de um lançamento a partir delas é permitida para demonstrar o fluxo.
- **Metas:** qualquer membro ativo edita uma meta familiar; só quem criou exclui. Metas pessoais ficam com o dono. Contribuições são imutáveis na v1. Excluir a meta remove as contribuições em cascade; a UI avisa. Para preservar o histórico, o caminho é `status='cancelada'`.
- **Jev AI:** `lida` é leitura compartilhada. A sugestão é da família; qualquer membro ativo pode marcá-la. Leitura por pessoa fica para v2.
- **Sincronização:** ao abrir o extrato, se a última sincronização passou de 24h; mais o botão “Sincronizar agora”. Sem cron diário na v1.
- **Visual:** “Editorial acolhedor”, com a paleta e a tipografia da §2.3. A skill `frontend-design` conduz a fatia 3.
- **Categorias padrão:** 12 no total, 8 de despesa e 4 de receita (Salário, Freelance, Investimentos, Outros).

### 9.2 Técnicas (decididas por privacidade e escopo)

- **RLS de `transactions`:** `family_id = minha família AND (escopo='familia' OR member_id=auth.uid())`. O admin não tem bypass.
- **Agregados do painel:** três funções `security definer` retornam apenas totais em janelas mensais; dia isolado é recusado para não permitir inferência. `family_member_directory` retorna apenas identidade e papel.
- **Uma família por usuário:** `unique (criado_por)` em `families` e guarda na policy de INSERT.
- **Tipo de categoria:** FK composta `(category_id, family_id, tipo)` impede despesa com categoria de receita.
- **Metas:** status recalcula ao inserir contribuição e ao mudar o alvo; contribuição só em meta `em_andamento`. Contribuições imutáveis é decisão do construtor, não do usuário.
- **`is_demo_sync`:** presente em `bank_connections` e `bank_transactions`, porque §8.1 e §4.3 divergem.
- **`member_id`:** é o autor do lançamento; `pago_por` guarda quem pagou no escopo família. `escopo` é imutável no UPDATE; mover um lançamento entre pessoal e família vira delete + create.
- **Limite de conexões:** 3 conexões ativas por membro; uma conexão `inativa` não conta. O limite é garantido por trigger no banco, além do backend.
- **Bancos e IA:** dados brutos de `bank_transactions` só mudam em `status`; o vínculo `transaction_id` é escrito pelo trigger do lançamento, com service role/seed como exceção confiável. Conteúdo de `ai_suggestions` só muda em `lida`; `ai_messages` e `ai_suggestions` não têm UPDATE/DELETE para `authenticated`. Mensagens de assistente e criação de sugestões são gravadas pelo backend com o JWT do usuário; a RLS não distingue backend de membro, então a integridade do conteúdo da IA é responsabilidade da API, e a RLS impede edição posterior. Desconectar banco é `status='inativa'`; não há DELETE de conexão/conta/transação para `authenticated`.
- **Restauração da demo:** conexão Postgres direta via `SUPABASE_DB_URL`; a service role key do Supabase é JWT de PostgREST e não executa SQL arbitrário.
- **Admin:** edita `nome`/`status` de membros; não muda `papel`, `criado_por` da família nem o `tema` de outro membro.
- **`.gitignore`:** remover `docs/` do ignore para versionar a spec e os planos, como pede D11.
- **Pluggy real:** endpoints, header, widget, webhooks e sandbox serão validados na documentação antes da fatia 2. É trabalho técnico, não pergunta de produto.

### 9.3 Ajustes que o parceiro ainda pode pedir

- Trocar a lista de categorias de receita antes da Task 6. Nenhum outro ponto de produto está aberto.

---

## 10. Auto-revisão do plano

- **Cobertura da spec (fatia 1):** 13 tabelas, RLS, seed demo, categorias, recorrentes, metas, IA, banco, tema e README estão mapeados na Task 14. O que não pertence à fatia 1 (endpoints, UI, Pluggy real, Jev AI real) está explicitamente no corte.
- **Granularidade:** cada task termina com um comando de verificação e um commit; tasks de schema/trigger/RLS têm testes próprios.
- **Consistência de tipos/nomes:** `pessoal|familia`, `receita|despesa`, `pendente_importacao|importada|ignorada|reconciliada` são usados com o mesmo sentido; `member_id`, `criado_por` e `pago_por` têm papéis diferentes por tabela e estão definidos no §6.1.
- **Review Focus:** as cinco falhas têm teste nas tasks 8–11 e 13.
- **Proporção:** o plano descreve decisões e testes; não transcreve o SQL completo de todas as tabelas. O executor escreve os bodies a partir do contrato.
- **Pendências:** as decisões da §9; nenhuma bloqueia a execução da fatia 1.
