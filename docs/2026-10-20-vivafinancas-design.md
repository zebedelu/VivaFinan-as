# VivaFinanças — Documento de Design

- **Data:** 2026-10-20
- **Versão:** 1.0
- **Status:** Aguardando aprovação do parceiro (nada é construído antes da aprovação)
- **Origem:** Continuação de brainstorming (duas conversas anteriores + sessão de perguntas finais)

---

## 1. Intenção, contexto e objetivos

### 1.1 Por que o VivaFinanças existe

O VivaFinanças é um aplicativo de gestão financeira familiar. A família registra receitas e despesas, acompanha gráficos e análises, e usa essas informações para melhorar seus hábitos de consumo. A ideia central do produto não é vigiar dinheiro, e sim dar clareza: mostrar para onde o dinheiro está indo, projetar o que ainda vem (aluguel, salários, assinaturas) e sugerir, com a ajuda da inteligência artificial Jev AI, oportunidades realistas de economia.

A Jev AI é uma auxiliadora, nunca uma tomadora de decisões. Ela classifica despesas, identifica padrões de consumo e recomenda otimizações, mas cada recomendação explica três coisas: o que poderia ser melhorado, por que isso ajudaria e, quando os dados permitirem, quanto a família poderia economizar. A decisão final continua sempre com a família. O aplicativo tem sucesso quando ajuda a família a conversar sobre dinheiro com menos ansiedade e mais informação.

### 1.2 Como a família usa no dia a dia

O fluxo imaginado pelo usuário: cada membro registra seus gastos manualmente conforme eles acontecem; contas fixas (aluguel, salários, assinaturas) são cadastradas uma vez como regras recorrentes e o aplicativo avisa quando elas vencem, esperando a confirmação da pessoa antes de virar lançamento. O painel familiar mostra o quadro geral somado, sem expor o detalhe de ninguém. Cada pessoa tem uma página própria com saudação personalizada, onde vê seus próprios números e recebe sugestões da Jev AI voltadas aos próprios hábitos. Nos momentos de decisão (cancelar uma assinatura, cortar uma categoria), a família olha o painel, conversa e decide.

### 1.3 Objetivos da versão 1

- Painel familiar objetivo (sem saudação pessoal) com saldo, receitas e despesas do mês, gráficos interativos e alertas.
- Página individual para cada membro, com saudação personalizada ("Olá, Tiago!") e dados exclusivamente seus.
- Registro manual de receitas e despesas, com escopo pessoal ou da família.
- Contas recorrentes com fluxo de confirmação (o aplicativo avisa, a pessoa confirma).
- Previsão de gastos mensal (12 meses à frente) e anual, incluindo aluguel, salários e assinaturas.
- Metas financeiras familiares e individuais, com progresso acompanhável.
- Jev AI integrada como inteligência principal de classificação, análise de padrões e recomendação de economia.
- Privacidade estrita por membro, garantida no banco de dados, não só na tela.
- Alertas in-app (conta a vencer, meta atingida, categoria estourada) e tema escuro.
- Família de demonstração pré-carregada, para a primeira experiência já mostrar gráficos e análises.

### 1.4 Não-objetivos (fora do escopo da v1)

- Conexão com bancos / Open Finance — lançamentos são 100% manuais nesta versão.
- Importação de extrato CSV.
- Rateio de despesas e cálculo de "quem deve a quem" entre membros.
- Exportação de relatórios em CSV/PDF.
- Aplicativo nativo (Android/iOS) — a interface é web responsiva.
- Notificações por e-mail ou push — alertas existem apenas dentro do aplicativo.
- Múltiplas famílias por usuário ou multi-moeda (a v1 é pt-BR e Real).

### 1.5 Anti-objetivos (o que tornaria o projeto um fracasso mesmo funcionando)

- A Jev AI executando ações ou tomando decisões financeiras sozinha.
- Qualquer membro — inclusive o administrador — conseguindo ver as transações pessoais de outro membro, mesmo explorando a API diretamente.
- Sensação de vigilância: se um membro sentir que está sendo espionado, ele para de registrar gastos e o produto morre.
- Recomendações vagas sem explicação ("gaste menos") — cada sugestão precisa de o quê, por quê e quanto.

---

## 2. Decisões consolidadas (D1–D12)

Todas as perguntas já respondidas nas conversas anteriores e na sessão final de perguntas, consolidadas em uma única tabela para que nenhuma seja re-perguntada. Marcação de origem: "conversas anteriores" = definido nos brainstormings anteriores; "sessão final" = respondido na rodada de perguntas desta sessão.

| # | Decisão | Conteúdo | Origem |
|---|---------|----------|--------|
| D1 | Privacidade | Cada membro vê apenas os próprios lançamentos; o painel familiar exibe somente totais agregados da família | Conversas anteriores |
| D2 | Administrador | A primeira pessoa a se cadastrar torna-se administradora; poderes: convidar membros, editar dados de cadastro, disparar redefinição de senha e desativar contas — sempre preservando o histórico | Conversas anteriores |
| D3 | Papel da Jev AI | Auxiliadora, nunca tomadora de decisões: classifica, identifica padrões e recomenda; a família decide | Conversas anteriores |
| D4 | Tom das telas | Painel familiar sem saudação pessoal; página individual abre com "Olá, {nome}!" | Conversas anteriores |
| D5 | Integração da IA | Via adaptador no backend (`JevAIAdapter` + `FallbackLLMAdapter`); endpoint e chave em variáveis de ambiente | Sessão final |
| D6 | Contas recorrentes | Nunca lançam automaticamente: o aplicativo avisa 3 dias antes e a pessoa confirma (ou ignora, ou confirma com outro valor) | Sessão final |
| D7 | "Quem pagou" | Referência histórica no lançamento da família, sem cálculo de dívida ou rateio | Sessão final |
| D8 | Lançamentos | Somente manuais nesta versão (sem Open Finance, sem importação de extrato) | Sessão final |
| D9 | Dados de demonstração | Família Demo pré-carregada (Ana, Carlos e Lucas) com 6 meses de histórico realista | Sessão final |
| D10 | Extras da v1 | Alertas in-app + tema escuro | Sessão final |
| D11 | Formato desta especificação | Markdown no repositório + cópia em PDF | Sessão final |
| D12 | Stack obrigatória | React (frontend), Python + Flask (backend), Supabase (banco), Vercel (hospedagem), Git + GitHub, Jev AI (IA) | Brief original do usuário |

### 2.1 Palpites herdados do construtor (decisão minha)

Itens que as conversas não fecharam explicitamente e que o construtor assume como decisões próprias — o usuário pode derrubar qualquer um deles sem afetar o resto do documento:

1. **Convites por e-mail nativo do Supabase Auth** — em vez de sistema de convites próprio.
2. **Redefinição de senha apenas por link** enviado ao e-mail do próprio membro; a administradora só dispara o envio, nunca define senhas.
3. **Contas desativadas mantêm os dados privados** e o histórico preservado; saem apenas das listagens.
4. **Administrador edita apenas dados de cadastro** (nome, e-mail, status) — nunca lançamentos financeiros de outra pessoa.
5. **Receitas seguem a mesma regra de privacidade das despesas** — o que vale para gastos vale para salários e entradas.

### 2.2 Decisões complementares do builder check (decisão minha)

Revisão de construtor (subagente independente) apontou ambiguidades e lacunas de integração; os itens abaixo fecham cada uma delas. Todas são revogáveis como as da seção 2.1:

1. **Acesso a dados:** o Flask consulta o Supabase com o **JWT do usuário** — o RLS vale de ponta a ponta; a service role é usada apenas pela Admin API (convites, desativação) e pelo seed. Sem isso, a garantia da seção 4.4 viraria dependência dos filtros do Flask.
2. **Tabela `recurring_occurrences`** (rule_id, mes_referencia, status pendente/confirmado/ignorado, valor confirmado, única por regra+mês) — sem ela, "ignorar" e a proteção contra confirmação dupla são inimplementáveis.
3. **Tabelas de IA no modelo:** `ai_messages` (histórico da tela Jev AI) e `ai_suggestions` (recomendações do painel e sugestões prontas do demo).
4. **Estado de alertas** persistido (lida/dispensada por usuário; meta já notificada) — sem isso o sino nunca esvazia.
5. **RLS completo:** política DELETE (só o autor exclui; edição segue a regra da seção 3.3), filtro de membro ativo e cobertura explícita de recurring_rules, categories e goal_contributions.
6. **Cadastro sem convite sempre cria nova família**; a Família Demo é acessada exclusivamente pelas credenciais/botão de demonstração.
7. **Guardas:** o último admin ativo não pode ser desativado; usuário que já pertence a uma família recebe erro claro ao aceitar convite (uma família por usuário).
8. **Categorias:** qualquer membro ativo cria categorias personalizadas; ocultar remove a categoria das listas de seleção, mas o histórico permanece nos gráficos.
9. **Saldo do mês = receitas − despesas do mês corrente** (escopos pessoal e família somados; recorrentes pendentes de confirmação ficam fora); "acumuladas" = totais dos últimos 6 meses, mesma janela dos gráficos.
10. **Vencimento dia 29/30/31 em mês curto** cai no último dia do mês; timezone de referência: America/Sao_Paulo.
11. **Alerta de categoria estourada:** escopo família → sino de todos os membros; escopo pessoal → só o dono. A comparação usa o mês corrente em curso versus a média dos 3 meses anteriores completos.
12. **Contribuições de meta na v1 são registradas direto na meta** (sem vínculo automático com lançamentos); metas familiares exibem apenas o progresso total, sem detalhamento por membro (mesma lógica do ponto aberto 9.1).
13. **IA sem nenhuma chave configurada:** painel de IA entra em modo degradado com estado vazio explicativo; falha/timeout da Jev AI ativa failover automático para o fallback, com timeout curto no adaptador.

### 2.3 O que o construtor precisará do usuário (não bloqueia o início)

1. **Contrato real da API da Jev AI** (endpoint, autenticação, schema) — até lá, o adaptador segue com mock e o fallback cobre a experiência.
2. **Provisionamento de produção:** projeto Supabase, SMTP com envio entregável (convites e redefinição de senha dependem de e-mail), contas Vercel/GitHub e os valores das variáveis de ambiente da seção 4.7.
3. **O mockup aprovado como artefato** — a paleta verde e o layout citados (9.1, 8.3) hoje vivem apenas na descrição textual.

---

## 3. Escopo funcional da v1

### 3.1 Painel familiar (início)

A página inicial é objetiva e não tem saudação pessoal. Ela apresenta, em blocos: saldo familiar disponível do mês (receitas menos despesas do mês corrente, escopos pessoal e família somados; recorrentes pendentes ficam fora), receitas e despesas acumuladas nos últimos 6 meses, gráfico interativo "Receitas x Despesas" dos últimos 6 meses, despesas por categoria (gráfico de rosca), lista de contas previstas aguardando confirmação, metas familiares com progresso, recomendações recentes da Jev AI e alertas do dia. O objetivo é que a família entenda sua situação em menos de um minuto de olhar. Todos os valores do painel são somados da família: receitas e despesas pessoais entram nos totais, mas nenhum valor individual é exibido (ver ponto aberto na seção 9).

### 3.2 Página individual do membro

Cada membro tem uma página própria que abre com saudação personalizada ("Olá, Tiago!"). Nela ficam: resumo de receitas e despesas pessoais do mês, categorias de consumo pessoal, metas pessoais com progresso, regras recorrentes pessoais pendentes de confirmação e sugestões da Jev AI baseadas apenas nos dados da própria pessoa. Nenhum outro membro consegue acessar esta página com dados de outro; o servidor filtra por identidade, e a regra está repetida no banco (RLS) como segunda camada.

### 3.3 Lançamentos

Registro manual de receitas e despesas. Campos: tipo (receita ou despesa), escopo (pessoal ou da família), valor, categoria, data, descrição opcional e, quando o escopo é da família, "pago por" como referência histórica (sem cálculo de dívida). A edição de lançamentos da família é permitida a qualquer membro ativo; a exclusão, apenas ao autor do lançamento. Listagem com filtros por mês, tipo, escopo e categoria.

### 3.4 Contas recorrentes com confirmação

Uma regra recorrente guarda: tipo (receita/despesa), escopo, valor, categoria, descrição, dia do vencimento no mês e status ativo/inativo. O aplicativo não lança nada sozinho: a regra gera um cartão de confirmação que aparece no painel (familiar e/ou individual, conforme o escopo) a partir de 3 dias antes do vencimento, com o texto "Aluguel vence em 3 dias — confirmar?". Ao confirmar, o lançamento entra vinculado à regra e ao mês de referência. A pessoa também pode ignorar (o período é marcado como não ocorrido, sem lançamento) ou confirmar com valor diferente (ex.: conta de luz variável). O fluxo de contas a vencer alimenta os alertas.

### 3.5 Metas

Metas familiares (visíveis a todos) e pessoais (visíveis só ao dono). Campos: título, valor-alvo, prazo opcional e descrição. O progresso é alimentado por contribuições registradas (valor + data), que na v1 são lançadas direto na meta, sem vínculo automático com lançamentos; metas familiares exibem apenas o progresso total, sem detalhamento por membro (mesma lógica do ponto aberto 9.1). A barra de progresso aparece no painel (familiares) e na página individual (pessoais). Ao atingir 100%, dispara alerta de meta atingida.

### 3.6 Previsões

Previsão mensal para os próximos 12 meses e projeção anual. O cálculo soma (a) as regras recorrentes ativas com vencimento no mês e (b) a média móvel dos últimos 3 meses das despesas variáveis da família. O mesmo método vale para receitas (salários recorrentes + média das receitas variáveis). Toda previsão é rotulada como "estimativa" na interface, e a tela mostra o detalhamento por item para que a família confie no número.

### 3.7 Jev AI

A inteligência principal do aplicativo, sempre em papel de apoio. Funcionalidades na v1: classificar lançamentos em categorias quando a pessoa não escolhe, identificar padrões de consumo (aumentos repentinos, assinaturas pouco usadas, compras recorrentes por impulso) e recomendar otimizações com economia estimada. Na página individual, a Jev AI analisa só os dados da própria pessoa; no painel da família, trabalha com valores somados, sem expor o detalhe de ninguém.

### 3.8 Alertas (in-app)

Central de notificações com ícone de sino. Três gatilhos na v1: conta recorrente a vencer (3 dias antes, repetindo no dia), meta atingida (100% do alvo) e categoria estourada (gasto do mês na categoria 20% acima da média dos últimos 3 meses). Os alertas são calculados quando a família usa o aplicativo, sem serviço agendado externo na v1.

### 3.9 Tema escuro

Alternância claro/escuro nas configurações, persistida por usuário. O tema escuro segue a mesma paleta do produto (verde institucional) com contraste verificado.

### 3.10 Família de demonstração

Na primeira execução, o aplicativo já contém a "Família Demo" com Ana (administradora), Carlos e Lucas, seis meses de histórico realista, regras recorrentes (aluguel, salários, assinaturas de streaming), metas e sugestões prontas da Jev AI. As credenciais de demonstração ficam visíveis na tela de login, e um botão "entrar como demonstração" abre a experiência completa.

---

## 4. Arquitetura técnica e modelo de dados

### 4.1 Stack obrigatória (decisão do usuário)

| Camada | Tecnologia | Observações |
|--------|-----------|-------------|
| Frontend | JavaScript + React (Vite) | SPA responsiva; React Router; Recharts para gráficos; Tailwind CSS |
| Backend | Python + Flask | API REST com blueprints por domínio; valida JWT do Supabase |
| Banco | Supabase (Postgres + Auth) | RLS (Row Level Security) é a camada de privacidade primária |
| Hospedagem | Vercel | Frontend estático; backend Flask como função serverless (alternativa documentada: Render/Railway) |
| Versionamento | Git + GitHub | Monorepo único |
| IA | Jev AI via adaptador | Endpoint e chave por variáveis de ambiente; fallback para IA genérica |

### 4.2 Estrutura do repositório

```
vivafinancas/
  frontend/            # React + Vite (SPA)
    src/pages/         # Login, Painel, Individual, Lancamentos, Recorrentes,
                       # Metas, Previsoes, JevAI, Configuracoes
    src/components/    # Graficos, Cartoes, Formularios, Alertas
  backend/
    app/
      blueprints/      # auth, family, members, transactions, recurring,
                       # goals, forecast, ai, alerts, admin
      services/ai/     # adaptador Jev AI + fallback
    tests/
  supabase/
    migrations/        # DDL das tabelas + politicas RLS
    seed/              # familia de demonstracao
  docs/specs/          # este documento
  README.md            # instalacao, configuracao e execucao
```

### 4.3 Modelo de dados

Sete tabelas sustentam a versão 1, desenhadas de forma deliberadamente enxuta: cada uma tem um papel claro e nenhum dado pessoal fica fora do alcance das políticas RLS da seção 4.4. Tabelas complementares definidas na seção 2.2 (`recurring_occurrences`, `ai_messages`, `ai_suggestions`) completam o modelo.

| Tabela | Campos principais | Papel |
|--------|-------------------|-------|
| families | id, nome, criado_por, criado_em | Agrupamento central de tudo |
| profiles | id (= auth.users.id), family_id, nome, papel (admin/membro), status (ativo/inativo) | Identidade dentro da família |
| categories | id, family_id, nome, tipo (receita/despesa), personalizada (bool) | Categorias padrão + customizadas |
| transactions | id, family_id, member_id (nulo = despesa da família), tipo, escopo, valor, descricao, category_id, data, pago_por (ref.), recurring_rule_id, mes_referencia, criado_por | Todo lançamento |
| recurring_rules | id, family_id, criado_por, tipo, escopo, valor, descricao, category_id, dia_vencimento, ativo | Aluguel, salários, assinaturas |
| goals | id, family_id, member_id (nulo = meta da família), titulo, valor_alvo, prazo, status | Metas |
| goal_contributions | id, goal_id, member_id, valor, data | Progresso das metas |

### 4.4 Privacidade no banco (RLS) — a fonte da verdade

A regra de privacidade não vive só na tela: cada tabela tem políticas RLS no Supabase. A política central de `transactions` permite SELECT/INSERT/UPDATE/DELETE apenas quando o `family_id` da linha é o da família do usuário autenticado **e** (o escopo é `family` **ou** o `member_id` é o próprio usuário; o DELETE fica restrito ao autor do lançamento). O administrador não possui nenhuma política de bypass sobre dados pessoais — isso é intencional e faz parte dos requisitos. Metas pessoais e perfis seguem a mesma lógica. O backend consulta o banco com o **JWT do próprio usuário** — o RLS vale de ponta a ponta; a service role é reservada à Admin API (convites, desativação) e ao seed. Mesmo que o frontend contenha uma falha, o banco recusa a consulta; mesmo chamando a API diretamente com um token válido, o resultado é o mesmo.

### 4.5 Autenticação e fluxo de família

1. Primeira pessoa se cadastra com e-mail e senha (Supabase Auth) e cria a família — torna-se administradora. Todo cadastro sem convite cria uma nova família; a Família Demo é acessada apenas pelas credenciais de demonstração.
2. A administradora convida membros pelo e-mail (convite nativo do Supabase).
3. Cada membro define a própria senha no primeiro acesso.
4. Redefinição de senha sempre por link enviado ao e-mail do próprio membro; a administradora apenas dispara o envio.
5. Desativação de conta preserva o histórico e remove o membro das listagens.

### 4.6 Integração com a Jev AI

O backend concentra toda a chamada de IA em um adaptador único (`services/ai`). A interface do adaptador recebe um contexto financeiro pronto (nunca credenciais de outros usuários) e devolve sugestões estruturadas. Duas implementações: `JevAIAdapter` (chamada HTTP para `JEV_AI_BASE_URL` com `JEV_AI_API_KEY`, com timeout curto) e `FallbackLLMAdapter` (provedor genérico compatível). Falha ou timeout da Jev AI ativa failover automático para o fallback; sem nenhuma chave configurada, o painel de IA entra em modo degradado com estado vazio explicativo. Trocar de provedor ou inserir a chave real depois não exige mudança no resto do sistema.

### 4.7 Deploy

Frontend na Vercel como site estático (o React gera o bundle). Backend Flask empacotado como função serverless da Vercel (`api/index.py`), com as variáveis de ambiente `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` (somente backend), `JEV_AI_BASE_URL` e `JEV_AI_API_KEY`. O README documenta instalação local, configuração do Supabase (migrations + seed) e execução.

---

## 5. Telas e experiência

1. **Login / Cadastro** — entrar, criar família (primeiro usuário) e aceitar convite. Credenciais demo visíveis.
2. **Painel familiar** — objetivo, sem saudação: saldo, receitas x despesas (6 meses), categorias (rosca), contas a confirmar, metas familiares, sugestões Jev AI, alertas.
3. **Página individual** — "Olá, {nome}!": números pessoais, categorias pessoais, metas pessoais, recorrentes pessoais, sugestões pessoais da Jev AI.
4. **Lançamentos** — lista filtrável (mês, tipo, escopo, categoria) + modal de criação/edição.
5. **Recorrentes** — lista de regras + fila de confirmação ("confirmar", "ignorar", "confirmar com outro valor").
6. **Metas** — familiares e pessoais, com progresso e registro de contribuições.
7. **Previsões** — projeção mensal 12 meses e anual, detalhada por item, rotulada como estimativa.
8. **Jev AI** — painel de conversa/sugestões com histórico, sempre com o quê / por quê / quanto.
9. **Configurações / Admin** — membros (convidar, editar cadastro, disparar redefinição, desativar), categorias, tema claro/escuro.

Experiência: interface moderna e limpa, mobile-first (a família registra gastos pelo celular), navegação em no máximo 2 toques para registrar um lançamento, estados vazios e de carregamento cuidados, verde institucional como cor de marca.

---

## 6. Regras de negócio

### 6.1 Confirmação de recorrentes

A regra recorrente nunca cria lançamento automático. O servidor calcula, a cada uso, as ocorrências pendentes: para cada regra ativa cujo dia de vencimento cai no mês corrente (ou caiu e não foi confirmada), gera um cartão de confirmação visível 3 dias antes. Confirmar cria o lançamento (com possibilidade de ajustar o valor); ignorar marca o período como dispensado. Vencimento nos dias 29, 30 ou 31 em mês curto cai no último dia do mês (timezone de referência: America/Sao_Paulo). A confirmação é individual: para regras de família, qualquer membro ativo confirma; para regras pessoais, só o dono.

### 6.2 Previsão de gastos

Para cada mês futuro M: previsão(M) = soma das regras recorrentes ativas com vencimento em M + média móvel de 3 meses das despesas variáveis (lançamentos sem regra recorrente). A projeção anual é a soma dos 12 meses. O mesmo método se aplica a receitas. Como lançamentos passados mudam, a previsão é recalculada em tempo de exibição — não há tabela de previsão armazenada na v1.

### 6.3 Alertas

| Gatilho | Condição | Onde aparece |
|---------|----------|--------------|
| Conta a vencer | Regra recorrente a 3 dias ou menos do vencimento, sem confirmação | Painel + sino |
| Meta atingida | Contribuições acumuladas >= valor-alvo | Painel + sino |
| Categoria estourada | Gasto do mês em curso na categoria >= 120% da média dos 3 meses anteriores completos | Escopo família: sino de todos os membros; escopo pessoal: só o dono |

### 6.4 Categorias

Conjunto inicial padrão (não editável pelo nome, mas ocultável): Alimentação, Moradia, Transporte, Saúde, Educação, Lazer, Assinaturas, Outros. Qualquer membro ativo pode criar categorias personalizadas; ocultar uma categoria a remove das listas de seleção, mas o histórico existente permanece nos gráficos. A Jev AI pode sugerir categoria ao classificar um lançamento, mas a escolha final é da pessoa.

---

## 7. Jev AI e segurança

### 7.1 Contextos de análise

- **Contexto individual:** a página do membro envia à Jev AI apenas as transações e metas da própria pessoa. As recomendações citam categorias e valores pessoais.
- **Contexto familiar:** o painel envia totais agregados por categoria e mês, sem identificação de membros. As recomendações falam de "a família", nunca de "Ana gastou X".

### 7.2 Formato das recomendações

Toda recomendação da Jev AI possui três campos obrigatórios: **o quê** (ação concreta, ex.: "revisar as assinaturas de streaming"), **por quê** (padrão detectado nos dados, ex.: "duas assinaturas com uso baixo nos últimos 3 meses") e **quanto** (economia potencial estimada, ex.: "até R$ 59,80/mês"). Quando os dados não permitem estimar, o campo "quanto" diz isso explicitamente em vez de inventar número. A interface deixa claro que são sugestões de apoio — a decisão é da família.

### 7.3 Segurança

- RLS no Supabase como camada primária; o backend repete os filtros por defesa em profundidade.
- JWT do Supabase validado em toda rota Flask; chaves de serviço nunca chegam ao frontend.
- CORS restrito ao domínio do frontend; HTTPS garantido pela Vercel.
- Segredos apenas em variáveis de ambiente; nada de credenciais no repositório.
- A Jev AI nunca recebe credenciais nem dados de outros membros além do contexto autorizado.

---

## 8. Dados de demonstração, critérios de sucesso e liberdades do construtor

### 8.1 Família de demonstração

Família Demo com Ana (administradora), Carlos e Lucas. Histórico de 6 meses com: aluguel 1.800, salários de Ana e Carlos, assinaturas (streaming, música, academia), supermercado semanal, transporte e lazer variáveis, uma meta familiar ("Viagem em família") e duas metas pessoais. Os valores são realistas para uma família brasileira de classe média e geram gráficos, previsões e recomendações interessantes desde o primeiro login.

### 8.2 Critérios de sucesso mensuráveis

1. Login demo mostra painel completo (gráficos, previsão, sugestões) em menos de 10 segundos.
2. Registrar um lançamento leva no máximo 3 toques e 30 segundos (navegação até o formulário em no máximo 2 toques).
3. Um membro autenticado **não consegue** listar via API as transações pessoais de outro membro (teste automatizado de RLS).
4. O administrador, ao desativar um membro, não ganha acesso aos dados pessoais do ex-membro.
5. A previsão do mês seguinte é exatamente a soma de recorrentes ativos + média móvel de 3 meses (teste automatizado).
6. Toda sugestão da Jev AI exibida contém o quê, por quê e quanto (ou a declaração de que não é possível estimar).

### 8.3 Liberdades do construtor (decisões delegadas)

- Biblioteca de gráficos (sugestão: Recharts), estrutura de componentes e organização de estilos.
- Engenharia de prompts da Jev AI e do fallback.
- Estados vazios, skeletons de carregamento e microinterações.
- Estratégia de testes (mínimo: testes de RLS e de previsão listados acima).
- Detalhes visuais dentro da paleta verde aprovada no mockup.

---

## 9. Ponto aberto e próximos passos

### 9.1 Único ponto em aberto: totais por membro no painel familiar

O mockup aprovado exibia, no painel da família, um cartão por membro com o total de despesas pessoais (Ana R$ 1.200, Carlos R$ 1.450, Lucas R$ 400). Essa pergunta ficou sem resposta explícita nas conversas anteriores, e ela afeta a privacidade definida em D1: um total por pessoa já revela informação individual. **Padrão adotado neste documento até decisão em contrário (decisão minha): o painel familiar não exibe totais por membro; cada pessoa vê o próprio total apenas na sua página individual; o painel mostra avatares que levam cada um à própria página.** Se o usuário preferir exibir os totais por membro (sem nenhum detalhe das compras), basta remover esta seção e ajustar a tela 2 — nenhuma outra parte do sistema muda.

### 9.2 Próximos passos

1. Aprovação deste documento pelo usuário (gate da skill de brainstorming: nada é construído antes disso).
2. Resposta ao ponto aberto da seção 9.1.
3. Elaboração do plano de implementação (ordem de construção, milestones).
4. Desenvolvimento: estrutura do monorepo → Supabase (migrations + RLS + seed) → backend Flask → frontend React → Jev AI (adaptador + fallback) → testes → README e deploy.

---

*Documento gerado no processo de brainstorming. Marcações explícitas: "decisão do usuário" para escolhas suas; "decisão minha" para palpites assumidos pelo construtor.*
