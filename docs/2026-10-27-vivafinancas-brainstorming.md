# VivaFinanças — Documento de Design (Revisado com Integração Pluggy)

**Data:** 2026-10-27
**Versão:** 2.0
**Status:** Aguardando aprovação do parceiro (nada é construído antes da aprovação)
**Origem:** Continuação de brainstorming + sessão de perguntas finais + revisão de inconsistências + integração Pluggy/Open Finance

---

## 1. Intenção, contexto e objetivos

### 1.1 Por que o VivaFinanças existe

O VivaFinanças é um aplicativo de gestão financeira familiar. A família registra receitas e despesas, acompanha gráficos e análises, e usa essas informações para melhorar seus hábitos de consumo. A ideia central do produto não é vigiar dinheiro, e sim dar clareza: mostrar para onde o dinheiro está indo, projetar o que ainda vem (aluguel, salários, assinaturas) e sugerir, com a ajuda da inteligência artificial Jev AI, oportunidades realistas de economia.

A Jev AI é uma auxiliadora, nunca uma tomadora de decisões. Ela classifica despesas, identifica padrões de consumo e recomenda otimizações, mas cada recomendação explica três coisas: o que poderia ser melhorado, por que isso ajudaria e, quando os dados permitirem, quanto a família poderia economizar. A decisão final continua sempre com a família. O aplicativo tem sucesso quando ajuda a família a conversar sobre dinheiro com menos ansiedade e mais informação.

Com a integração Pluggy (Open Finance), o VivaFinanças passa a oferecer **visualização de extrato bancário** e **importação assistida de transações**, reduzindo o esforço de digitação manual sem abrir mão do controle do usuário. A conexão bancária é **opcional, somente leitura e pessoal por padrão**.

### 1.2 Como a família usa no dia a dia

O fluxo imaginado pelo usuário: cada membro registra seus gastos manualmente conforme eles acontecem **ou conecta sua conta bancária via Pluggy para visualizar o extrato e importar transações com confirmação**; contas fixas (aluguel, salários, assinaturas) são cadastradas uma vez como regras recorrentes e o aplicativo avisa quando elas vencem, esperando a confirmação da pessoa antes de virar lançamento. O painel familiar mostra o quadro geral somado, sem expor o detalhe de ninguém. Cada pessoa tem uma página própria com saudação personalizada, onde vê seus próprios números e recebe sugestões da Jev AI voltadas aos próprios hábitos. Nos momentos de decisão (cancelar uma assinatura, cortar uma categoria), a família olha o painel, conversa e decide.

**Fluxo com Pluggy (novo):** um membro pode conectar uma ou mais contas bancárias. O extrato aparece em uma tela própria ("Extrato bancário"). Transações bancárias aparecem como **sugestões de importação pendentes de confirmação** — nunca viram lançamento automaticamente. O membro revisa, ajusta categoria/escopo se necessário, e confirma. Transações já reconciliadas com lançamentos manuais são marcadas para evitar duplicidade.

### 1.3 Objetivos da versão 1

- Painel familiar objetivo (sem saudação pessoal) com saldo, receitas e despesas do mês, gráficos interativos e alertas.
- Página individual para cada membro, com saudação personalizada ("Olá, Tiago!") e dados exclusivamente seus.
- Registro manual de receitas e despesas, com escopo pessoal ou da família.
- **Conexão bancária opcional via Pluggy (Open Finance), somente leitura, com visualização de extrato e importação assistida de transações.**
- **Tela de extrato bancário com lista de transações sincronizadas, filtro por conta/período e status de sincronização.**
- **Fluxo de importação confirmável: transações bancárias aparecem como sugestões pendentes; o usuário confirma, ajusta e converte em lançamento.**
- **Reconciliação básica: detecção de provável duplicidade entre transação bancária e lançamento manual existente.**
- Contas recorrentes com fluxo de confirmação (o aplicativo avisa, a pessoa confirma).
- Previsão de gastos mensal (12 meses à frente) e anual, incluindo aluguel, salários e assinaturas.
- Metas financeiras familiares e individuais, com progresso acompanhável e detalhamento de contribuição por membro.
- Jev AI integrada como inteligência principal de classificação, análise de padrões e recomendação de economia.
- Privacidade estrita por membro, garantida no banco de dados, não só na tela.
- Alertas in-app (conta a vencer, meta atingida, categoria estourada) e tema escuro.
- Família de demonstração pré-carregada, para a primeira experiência já mostrar gráficos e análises.

### 1.4 Não-objetivos (fora do escopo da v1)

- ~~Conexão com bancos / Open Finance — lançamentos são 100% manuais nesta versão.~~ → **Removido: a conexão com bancos via Pluggy agora faz parte do escopo.**
- ~~Importação de extrato CSV.~~ → **Ajustado: importação via Pluggy substitui a necessidade de CSV; importação manual de arquivo CSV permanece fora do escopo.**
- **Iniciação de pagamentos, transferências ou qualquer ação financeira ativa via Pluggy** — a integração é estritamente somente leitura.
- **Conciliação contábil completa** (matching automático 100%, regras de deduplicação complexas) — a v1 oferece sugestão de match com confirmação manual.
- Rateio de despesas e cálculo de "quem deve a quem" entre membros.
- Exportação de relatórios em CSV/PDF.
- Aplicativo nativo (Android/iOS) — a interface é web responsiva.
- Notificações por e-mail ou push — alertas existem apenas dentro do aplicativo.
- Múltiplas famílias por usuário ou multi-moeda (a v1 é pt-BR e Real).
- **Conexão com contas de investimento, cartões de crédito ou outros produtos financeiros além de conta corrente/poupança** — a v1 foca em conta bancária com extrato de transações. *(a validar: Pluggy suporta esses produtos; escopo pode ser expandido em v2)*

### 1.5 Anti-objetivos (o que tornaria o projeto um fracasso mesmo funcionando)

- A Jev AI executando ações ou tomando decisões financeiras sozinha.
- Qualquer membro — inclusive o administrador — conseguindo ver as transações pessoais de outro membro, mesmo explorando a API diretamente.
- **Qualquer membro conseguindo ver dados bancários (conexões, extrato, transações importadas) de outro membro.**
- Sensação de vigilância: se um membro sentir que está sendo espionado, ele para de registrar gastos e o produto morre.
- Recomendações vagas sem explicação ("gaste menos") — cada sugestão precisa de o quê, por quê e quanto.
- **Transações bancárias virando lançamentos automaticamente sem confirmação do usuário.**
- **Armazenamento de credenciais bancárias (senhas, tokens de banco) no banco de dados do VivaFinanças.**

---

## 2. Decisões consolidadas (D1–D33)

Todas as perguntas já respondidas nas conversas anteriores, na sessão final de perguntas, na revisão de inconsistências e na integração Pluggy, consolidadas em uma única tabela.

| # | Decisão | Conteúdo | Origem |
|---|---|---|---|
| D1 | Privacidade | Cada membro vê apenas os próprios lançamentos; o painel familiar exibe somente totais agregados da família | Conversas anteriores |
| D2 | Administrador | A primeira pessoa a se cadastrar torna-se administradora; poderes: convidar membros, editar dados de cadastro, disparar redefinição de senha e desativar contas — sempre preservando o histórico | Conversas anteriores |
| D3 | Papel da Jev AI | Auxiliadora, nunca tomadora de decisões: classifica, identifica padrões e recomenda; a família decide | Conversas anteriores |
| D4 | Tom das telas | Painel familiar sem saudação pessoal; página individual abre com "Olá, {nome}!" | Conversas anteriores |
| D5 | Integração da IA | Via adaptador no backend (`JevAIAdapter` + `FallbackLLMAdapter`); endpoint e chave em variáveis de ambiente | Sessão final |
| D6 | Contas recorrentes | Nunca lançam automaticamente: o aplicativo avisa 3 dias antes e a pessoa confirma (ou ignora, ou confirma com outro valor) | Sessão final |
| D7 | "Quem pagou" | Referência histórica no lançamento da família, sem cálculo de dívida ou rateio | Sessão final |
| D8 | Lançamentos | **Manuais + importação assistida via Pluggy.** Lançamentos podem ser criados manualmente ou a partir de transações bancárias sincronizadas pelo Pluggy, sempre com confirmação do usuário. Sem iniciação de pagamentos. | **Revisado (Pluggy)** |
| D9 | Dados de demonstração | Família Demo pré-carregada (Ana, Carlos e Lucas) com 6 meses de histórico realista | Sessão final |
| D10 | Extras da v1 | Alertas in-app + tema escuro | Sessão final |
| D11 | Formato desta especificação | Markdown no repositório + cópia em PDF | Sessão final |
| D12 | Stack obrigatória | React (frontend), Python + Flask (backend), Supabase (banco), Vercel (hospedagem), Git + GitHub, Jev AI (IA), **Pluggy (Open Finance / dados bancários)** | **Revisado (Pluggy)** |
| D13 | Edição de lançamentos da família | Qualquer membro ativo pode editar lançamentos de escopo "família" | Revisão |
| D14 | Persistência de recorrentes | Estado de confirmação/ignorado persistido em tabela `recurring_occurrences` | Revisão |
| D15 | Metas familiares | Exibem contribuição detalhada por membro | Revisão |
| D16 | Previsão de gastos | Considera apenas regras recorrentes já confirmadas no mês + média móvel de variáveis | Revisão |
| D17 | Terminologia de recorrentes | Usar "ignorado" / "período ignorado" consistentemente | Revisão |
| D18 | Alerta de categoria | Gatilho: "20% acima da média dos 3 meses anteriores" | Revisão |
| D19 | Totais acumulados | Cartões mostram soma total; gráfico mostra série temporal mês a mês | Revisão |
| D20 | Família Demo | Flag `is_demo = true` na tabela `families` | Construtor |
| D21 | Cálculo de alertas | Calculados apenas quando o usuário abre o app (não persistidos entre sessões) | Revisão |
| D22 | Edição de lançamentos pessoais | Apenas o autor pode editar lançamentos de escopo "pessoal" | Revisão |
| D23 | Categorias | Padrão: apenas ocultáveis; personalizadas: editáveis e excluíveis | Revisão |
| D24 | Contexto da Jev AI | Recebe transações e metas para análise | Revisão |
| D25 | Status de meta | `em_andamento` / `concluida` / `cancelada` | Revisão |
| D26 | Prazo de meta | Meta continua aberta após prazo ultrapassado | Revisão |
| **D27** | **Integração Pluggy** | **Conexão bancária via Pluggy (Open Finance Brasil), somente leitura, opcional por membro. O VivaFinanças nunca armazena credenciais bancárias; o Pluggy cuida da autenticação com o banco.** | **Pluggy** |
| **D28** | **Escopo da conexão** | **Somente leitura: consulta de contas, saldos e transações. Nenhum pagamento, transferência ou ação financeira ativa é permitida.** | **Pluggy** |
| **D29** | **Consentimento e revogação** | **O usuário consente explicitamente ao conectar via widget Pluggy. Pode desconectar/revogar a qualquer momento nas configurações. A desconexão remove o vínculo no Pluggy e marca a conexão como inativa no VivaFinanças (histórico de transações já importadas é preservado).** | **Pluggy** |
| **D30** | **Importação de transações** | **Transações bancárias NUNCA viram lançamento automaticamente. Aparecem como "sugestões de importação" pendentes de confirmação. O usuário revisa, ajusta categoria/escopo/valor se necessário, e confirma para criar o lançamento.** | **Pluggy** |
| **D31** | **Privacidade dos dados bancários** | **Conexões bancárias e transações importadas são pessoais por padrão (escopo "pessoal"). O usuário pode, ao confirmar a importação, mudar o escopo para "família" se desejar. O administrador NÃO tem acesso a conexões ou dados bancários de outros membros.** | **Pluggy** |
| **D32** | **Armazenamento de credenciais Pluggy** | **A API Key do Pluggy (`PLUGGY_API_KEY`) fica exclusivamente em variável de ambiente no backend. O frontend nunca recebe nem armazena essa chave. O Pluggy armazena as credenciais bancárias do usuário (o VivaFinanças nunca as vê).** | **Pluggy** |
| **D33** | **Tratamento de falhas Pluggy** | **Se a sincronização falhar ou o Pluggy estiver indisponível, o app exibe estado degradado com mensagem explicativa. Lançamentos manuais, painéis e demais funcionalidades continuam operando normalmente. A sincronização pode ser retomada manualmente.** | **Pluggy** |

### 2.1 Palpites herdados do construtor (decisão minha)

Itens que as conversas não fecharam explicitamente e que o construtor assume como decisões próprias — o usuário pode derrubar qualquer um deles sem afetar o resto do documento:

- Convites por e-mail nativo do Supabase Auth — em vez de sistema de convites próprio.
- Redefinição de senha apenas por link enviado ao e-mail do próprio membro; a administradora só dispara o envio, nunca define senhas.
- Contas desativadas mantêm os dados privados e o histórico preservado; saem apenas das listagens.
- Administrador edita apenas dados de cadastro (nome, e-mail, status) — nunca lançamentos financeiros de outra pessoa.
- Receitas seguem a mesma regra de privacidade das despesas — o que vale para gastos vale para salários e entradas.
- **Conexão Pluggy limitada a conta corrente e poupança na v1 (cartões de crédito e investimentos em v2).**
- **Sincronização automática a cada 24 horas + botão de sincronização manual na tela de extrato.**
- **Limite de 3 conexões bancárias por membro na v1.**

### 2.2 Decisões complementares do builder check (decisão minha)

Revisão de construtor (subagente independente) apontou ambiguidades e lacunas de integração; os itens abaixo fecham cada uma delas. Todas são revogáveis como as da seção 2.1:

- Acesso a dados: o Flask consulta o Supabase com o JWT do usuário — o RLS vale de ponta a ponta; a service role é usada apenas pela Admin API (convites, desativação) e pelo seed. Sem isso, a garantia da seção 4.4 viraria dependência dos filtros do Flask.
- Tabela `recurring_occurrences` (rule_id, mes_referencia, status pendente/confirmado/ignorado, valor confirmado, única por regra+mês) — persiste o estado de confirmação e impede confirmação dupla.
- Tabelas de IA no modelo: `ai_messages` (histórico da tela Jev AI) e `ai_suggestions` (recomendações do painel e sugestões prontas do demo).
- Estado de alertas calculado em tempo real quando o usuário abre o app — não há persistência de alertas "não lidos" entre sessões na v1.
- RLS completo: política DELETE (só o autor exclui; edição segue a regra da seção 3.3), filtro de membro ativo e cobertura explícita de `recurring_rules`, `recurring_occurrences`, `categories` e `goal_contributions`.
- Cadastro sem convite sempre cria nova família; a Família Demo é acessada exclusivamente pelas credenciais/botão de demonstração e identificada pelo flag `is_demo = true` na tabela `families`.
- Guardas: o último admin ativo não pode ser desativado; usuário que já pertence a uma família recebe erro claro ao aceitar convite (uma família por usuário).
- Categorias padrão (não editáveis pelo nome, apenas ocultáveis) e categorias personalizadas (editáveis e excluíveis pelo criador) — ocultar remove a categoria das listas de seleção, mas o histórico permanece nos gráficos.
- Saldo do mês = receitas − despesas do mês corrente (escopos pessoal e família somados; recorrentes pendentes de confirmação ficam fora); "acumuladas" = totais dos últimos 6 meses, mesma janela dos gráficos.
- Vencimento dia 29/30/31 em mês curto cai no último dia do mês; timezone de referência: America/Sao_Paulo.
- Alerta de categoria estourada: escopo família → sino de todos os membros; escopo pessoal → só o dono. A comparação usa o mês corrente em curso versus a média dos 3 meses anteriores completos.
- Contribuições de meta na v1 são registradas direto na meta (sem vínculo automático com lançamentos); metas familiares exibem o progresso total e o detalhamento por membro (quem contribuiu com quanto).
- IA sem nenhuma chave configurada: painel de IA entra em modo degradado com estado vazio explicativo; falha/timeout da Jev AI ativa failover automático para o fallback, com timeout curto no adaptador.
- **Pluggy sem chave configurada: seção de conexão bancária fica oculta ou exibe mensagem "Integração bancária indisponível". O restante do app funciona normalmente.**
- **Sincronização Pluggy: o backend agenda a sync via endpoint do Pluggy; se a sync falhar, o status da conexão é atualizado para "erro_sincronizacao" e o usuário é notificado no app.**

### 2.3 O que o construtor precisará do usuário (não bloqueia o início)

- Contrato real da API da Jev AI (endpoint, autenticação, schema) — até lá, o adaptador segue com mock e o fallback cobre a experiência.
- **Conta Pluggy com API Key de produção (ou sandbox para desenvolvimento). Documentação de referência: [docs.pluggy.ai](https://docs.pluggy.ai).**
- Provisionamento de produção: projeto Supabase, SMTP com envio entregável (convites e redefinição de senha dependem de e-mail), contas Vercel/GitHub e os valores das variáveis de ambiente da seção 4.7.
- O mockup aprovado como artefato — a paleta verde e o layout citados hoje vivem apenas na descrição textual.

---

## 3. Escopo funcional da v1

### 3.1 Painel familiar (início)

A página inicial é objetiva e não tem saudação pessoal. Ela apresenta, em blocos:

- Saldo familiar disponível do mês — receitas menos despesas do mês corrente, escopos pessoal e família somados; recorrentes pendentes de confirmação ficam fora do cálculo.
- Receitas e despesas acumuladas — soma total dos últimos 6 meses, exibida em cartões separados.
- Gráfico "Receitas x Despesas" — série temporal mês a mês dos últimos 6 meses.
- Despesas por categoria — gráfico de rosca com a distribuição do mês corrente.
- Contas previstas aguardando confirmação — lista de regras recorrentes pendentes.
- Metas familiares — com barra de progresso e detalhamento de contribuição por membro.
- Recomendações recentes da Jev AI — baseadas nos dados agregados da família.
- Alertas do dia — conta a vencer, meta atingida, categoria estourada.
- **Indicador de conexões bancárias ativas (ícone de banco com contagem) — clicável, leva à tela de extrato do membro.**

O objetivo é que a família entenda sua situação em menos de um minuto de olhar. Todos os valores do painel são somados da família: receitas e despesas pessoais entram nos totais, mas nenhum valor individual é exibido. O painel mostra avatares dos membros que levam cada um à própria página individual.

### 3.2 Página individual do membro

Cada membro tem uma página própria que abre com saudação personalizada ("Olá, Tiago!"). Nela ficam:

- Resumo de receitas e despesas pessoais do mês (saldo calculado da mesma forma que o familiar: recorrentes pendentes ficam fora).
- Categorias de consumo pessoal.
- Metas pessoais com progresso e histórico de contribuições.
- Regras recorrentes pessoais pendentes de confirmação.
- Sugestões da Jev AI baseadas apenas nos dados da própria pessoa (transações e metas pessoais).
- **Resumo de conexões bancárias: quantas contas conectadas, última sincronização, transações pendentes de importação.**

Nenhum outro membro consegue acessar esta página com dados de outro; o servidor filtra por identidade, e a regra está repetida no banco (RLS) como segunda camada.

### 3.3 Lançamentos

Registro manual de receitas e despesas. Campos:

- Tipo (receita ou despesa)
- Escopo (pessoal ou da família)
- Valor
- Categoria
- Data
- Descrição (opcional)
- Pago por (referência histórica — ID do membro que pagou, apenas quando o escopo é "família")
- **Origem: `manual` ou `pluggy` (preenchido automaticamente; lançamentos importados do Pluggy carregam o ID da transação bancária de origem)**

Regras de edição:

- Lançamentos de escopo "família": qualquer membro ativo pode editar; apenas o autor pode excluir.
- Lançamentos de escopo "pessoal": apenas o autor pode editar e excluir.
- O administrador não possui privilégios especiais sobre lançamentos financeiros de outros membros.
- Listagem com filtros por mês, tipo, escopo, categoria **e origem (manual / Pluggy)**.

### 3.4 Contas recorrentes com confirmação

*(Sem alterações em relação à versão anterior.)*

Uma regra recorrente guarda: tipo (receita/despesa), escopo, valor, categoria, descrição, dia do vencimento no mês e status ativo/inativo.

Fluxo:

1. O aplicativo não lança nada sozinho.
2. A regra gera um cartão de confirmação que aparece no painel (familiar e/ou individual, conforme o escopo) a partir de 3 dias antes do vencimento, com o texto "Aluguel vence em 3 dias — confirmar?".
3. Ao confirmar, o lançamento entra vinculado à regra e ao mês de referência, e o estado é persistido na tabela `recurring_occurrences` com status "confirmado".
4. A pessoa também pode ignorar — o período é marcado como "ignorado" na tabela `recurring_occurrences`, sem lançamento.
5. Ou confirmar com valor diferente (ex.: conta de luz variável) — o valor confirmado é registrado em `recurring_occurrences`.

O fluxo de contas a vencer alimenta os alertas. A confirmação é individual: para regras de família, qualquer membro ativo confirma; para regras pessoais, só o dono.

### 3.5 Metas

*(Sem alterações em relação à versão anterior.)*

Metas familiares (visíveis a todos) e pessoais (visíveis só ao dono). Campos:

- Título
- Valor-alvo
- Prazo (opcional)
- Descrição
- Status: `em_andamento` / `concluida` / `cancelada`

O progresso é alimentado por contribuições registradas (valor + data + membro), que na v1 são lançadas direto na meta, sem vínculo automático com lançamentos.

Exibição:

- Metas familiares: exibem o progresso total e o detalhamento de contribuição por membro (quem contribuiu com quanto).
- Metas pessoais: exibem apenas o progresso do dono.

A barra de progresso aparece no painel (familiares) e na página individual (pessoais). Ao atingir 100%, o status muda automaticamente para `concluida` e dispara alerta de meta atingida.

Quando o prazo é atingido mas o objetivo não, a meta continua aberta e o usuário pode continuar contribuindo.

### 3.6 Previsões

Previsão mensal para os próximos 12 meses e projeção anual. O cálculo soma:

(a) As regras recorrentes ativas com vencimento no mês que já foram confirmadas (recorrentes pendentes de confirmação não entram na previsão).
(b) A média móvel dos últimos 3 meses das despesas variáveis da família (lançamentos sem regra recorrente).

O mesmo método vale para receitas (salários recorrentes + média das receitas variáveis). Toda previsão é rotulada como "estimativa" na interface, e a tela mostra o detalhamento por item para que a família confie no número.

**Nota Pluggy:** a previsão na v1 continua usando apenas lançamentos confirmados (manuais ou importados via Pluggy). Transações bancárias sincronizadas mas ainda não confirmadas como lançamento NÃO entram na previsão. Em versão futura, a Jev AI poderá usar tendências do extrato para refinar estimativas.

### 3.7 Jev AI

A inteligência principal do aplicativo, sempre em papel de apoio. Funcionalidades na v1:

- Classificar lançamentos em categorias quando a pessoa não escolhe.
- **Sugerir categoria para transações bancárias importadas (com base na descrição e no histórico do usuário).**
- Identificar padrões de consumo (aumentos repentinos, assinaturas pouco usadas, compras recorrentes por impulso).
- Recomendar otimizações com economia estimada.
- Analisar metas para sugerir priorização e ajustes de contribuição.

Na página individual, a Jev AI analisa apenas as transações e metas da própria pessoa; no painel da família, trabalha com valores somados, sem expor o detalhe de ninguém.

### 3.8 Alertas (in-app)

Central de notificações com ícone de sino. Gatilhos na v1:

| Gatilho | Condição | Onde aparece |
|---|---|---|
| Conta a vencer | Regra recorrente a 3 dias ou menos do vencimento, sem confirmação | Painel + sino |
| Meta atingida | Contribuições acumuladas >= valor-alvo (status muda para `concluida`) | Painel + sino |
| Categoria estourada | Gasto do mês na categoria 20% acima da média dos 3 meses anteriores completos | Escopo família: sino de todos os membros; escopo pessoal: só o dono |
| **Sincronização bancária concluída** | **Nova sincronização Pluggy trouxe transações novas** | **Sino (pessoal)** |
| **Erro na sincronização bancária** | **Falha na sync Pluggy ou conexão expirada** | **Sino (pessoal)** |

Os alertas são calculados quando o usuário abre o aplicativo, não persistidos entre sessões. O usuário precisa abrir o app para ver os alertas do dia.

### 3.9 Tema escuro

Alternância claro/escuro nas configurações, persistida por usuário. O tema escuro segue a mesma paleta do produto (verde institucional) com contraste verificado.

### 3.10 Família de demonstração

Na primeira execução, o aplicativo já contém a "Família Demo" com Ana (administradora), Carlos e Lucas, seis meses de histórico realista, regras recorrentes (aluguel, salários, assinaturas de streaming), metas e sugestões prontas da Jev AI. As credenciais de demonstração ficam visíveis na tela de login, e um botão "entrar como demonstração" abre a experiência completa.

A Família Demo é identificada pelo flag `is_demo = true` na tabela `families` e não pode ser modificada por usuários normais.

**Nota:** a Família Demo não possui conexão Pluggy real. Para demonstrar a tela de extrato, transações bancárias simuladas são pré-carregadas com flag `is_demo_sync = true` na tabela `bank_transactions`.

### 3.11 Conexão bancária via Pluggy (NOVO)

Seção dedicada à integração com o Pluggy para visualização de extrato e importação assistida de transações.

#### 3.11.1 Visão geral

O Pluggy é uma plataforma brasileira de Open Finance que permite a aplicativos acessarem dados bancários de instituições financeiras brasileiras mediante consentimento do usuário. No VivaFinanças, o Pluggy é usado **exclusivamente para leitura**: consultar contas, saldos e transações. Nenhuma operação financeira ativa (pagamento, transferência, Pix) é realizada.

**Referência técnica:** [docs.pluggy.ai](https://docs.pluggy.ai) *(a validar: confirmar endpoints e schemas na documentação mais recente)*

#### 3.11.2 O que o Pluggy fornece ao VivaFinanças

- Lista de instituições financeiras conectáveis (bancos, fintechs)
- Autenticação do usuário com o banco (via widget seguro — o VivaFinanças nunca vê a senha)
- Dados da conta: nome, tipo (corrente/poupança), agência, número (mascarado)
- Saldo disponível
- Extrato: lista de transações com data, valor, descrição, tipo (débito/crédito), categoria bancária
- Status da conexão (ativa, expirada, erro)

#### 3.11.3 Fluxo de conexão (primeiro uso)

1. O membro acessa "Configurações → Contas bancárias" ou "Extrato → Conectar banco".
2. O frontend carrega o **Pluggy Connect Widget** (SDK JavaScript `@pluggyai/pluggy-js`).
3. O widget exibe a lista de instituições disponíveis. O usuário seleciona seu banco.
4. O widget abre o fluxo de autenticação do banco (login, senha, OTP, biometria — dependendo do banco). **Toda essa interação acontece dentro do widget Pluggy; o VivaFinanças não intermedia nem armazena credenciais.**
5. Após autenticação bem-sucedida, o widget retorna um `connectionId` ao frontend.
6. O frontend envia o `connectionId` ao backend Flask.
7. O backend registra a conexão na tabela `bank_connections` (vinculada ao `member_id` e `family_id`).
8. O backend faz a primeira sincronização: chama o endpoint de sync do Pluggy para buscar contas e transações.
9. As transações são armazenadas na tabela `bank_transactions` com status `pendente_importacao`.
10. O usuário vê as transações na tela de extrato e pode confirmar a importação.

#### 3.11.4 Sincronização de dados

- **Automática:** o backend dispara sincronização a cada 24 horas (via agendamento serverless na Vercel ou cron). *(a validar: confirmar viabilidade de cron na Vercel free tier; alternativa: Render/Railway para o backend)*
- **Manual:** botão "Sincronizar agora" na tela de extrato.
- **Ao conectar:** primeira sincronização imediata.
- A sync busca transações novas desde a última sincronização bem-sucedida.
- O Pluggy pode notificar via webhook quando há dados novos. *(a validar: confirmar formato e disponibilidade de webhooks na documentação Pluggy)*

#### 3.11.5 Tela de extrato bancário

Tela própria acessível pela página individual e pelo painel. Mostra:

- Lista de contas conectadas (nome do banco, tipo, últimos 4 dígitos, saldo).
- Extrato da conta selecionada: lista de transações com data, descrição, valor (+/-), categoria bancária.
- Filtros: período (mês), tipo (receita/despesa), status de importação.
- Status de cada transação: `pendente_importacao` / `importada` / `ignorada` / `reconciliada`.
- Botão "Sincronizar agora".
- Indicador de última sincronização.
- Estado vazio: "Nenhuma conta conectada. Conecte seu banco para ver o extrato aqui."
- Estado de erro: "Não foi possível sincronizar. Tente novamente mais tarde."

#### 3.11.6 Fluxo de importação (transação → lançamento)

1. O usuário vê transações com status `pendente_importacao` na tela de extrato.
2. Pode importar uma a uma ou em lote.
3. Ao selecionar uma transação para importar, o app abre um modal pré-preenchido:
   - Tipo (receita/despesa) — inferido pelo sinal do valor
   - Valor — pré-preenchido
   - Data — pré-preenchida
   - Descrição — pré-preenchida (do banco)
   - Categoria — sugerida pela Jev AI (com base na descrição) ou pela categoria bancária; **o usuário pode alterar**
   - Escopo — **pessoal por padrão**; o usuário pode mudar para "família"
4. O usuário confirma → o lançamento é criado na tabela `transactions` com `origem = 'pluggy'` e `bank_transaction_id` vinculando à transação bancária.
5. A transação bancária muda de status para `importada`.
6. Se o usuário ignora → status `ignorada` (pode ser revertido).

#### 3.11.7 Reconciliação (detecção de duplicidade)

Para evitar que o usuário importe uma transação que já lançou manualmente:

- Ao importar, o backend busca lançamentos manuais com: mesmo valor (± R$ 0,01), mesma data (± 1 dia), mesma família/membro.
- Se encontrar, exibe aviso: "Já existe um lançamento parecido em [data]. Deseja vincular esta transação ao lançamento existente em vez de criar um novo?"
- Se o usuário vincular → a transação bancária recebe status `reconciliada` e o `bank_transaction_id` é gravado no lançamento existente.
- Se o usuário confirma mesmo assim → lançamento é criado normalmente (pode ser uma transação legítima diferente com valor similar).

A reconciliação é **sempre sugerida, nunca automática**.

#### 3.11.8 Desconexão e revogação

- O usuário pode desconectar uma conta a qualquer momento em "Configurações → Contas bancárias → Desconectar".
- O backend chama o endpoint de delete do Pluggy para remover a conexão.
- A conexão é marcada como `inativa` no VivaFinanças.
- Transações já importadas como lançamento **permanecem** (são dados do VivaFinanças).
- Transações bancárias sincronizadas mas não importadas são mantidas por 90 dias e depois removidas. *(a validar: política de retenção)*
- O usuário pode reconectar a mesma conta posteriormente.

#### 3.11.9 Limites e restrições da v1

- Máximo de **3 conexões bancárias por membro**.
- Apenas conta corrente e poupança (cartões de crédito e investimentos em v2).
- Sincronização busca até **90 dias** de histórico na primeira conexão; syncs subsequentes buscam apenas o delta.
- A conexão bancária é **opcional** — o app funciona 100% sem ela.

---

## 4. Arquitetura técnica e modelo de dados

### 4.1 Stack obrigatória (decisão do usuário)

| Camada | Tecnologia | Observações |
|---|---|---|
| Frontend | JavaScript + React (Vite) | SPA responsiva; React Router; Recharts para gráficos; Tailwind CSS; **Pluggy Connect Widget (`@pluggyai/pluggy-js`)** |
| Backend | Python + Flask | API REST com blueprints por domínio; valida JWT do Supabase; **PluggyAdapter para comunicação com API Pluggy** |
| Banco | Supabase (Postgres + Auth) | RLS (Row Level Security) é a camada de privacidade primária |
| Hospedagem | Vercel | Frontend estático; backend Flask como função serverless (alternativa documentada: Render/Railway) |
| Versionamento | Git + GitHub | Monorepo único |
| IA | Jev AI via adaptador | Endpoint e chave por variáveis de ambiente; fallback para IA genérica |
| **Open Finance** | **Pluggy** | **Conexão bancária somente leitura; API Key em variável de ambiente; widget no frontend** |

### 4.2 Estrutura do repositório

```
vivafinancas/
   frontend/            # React + Vite (SPA)
     src/pages/         # Login, Painel, Individual, Lancamentos, Recorrentes,
                        # Metas, Previsoes, JevAI, Extrato, Configuracoes
     src/components/    # Graficos, Cartoes, Formularios, Alertas, PluggyConnect
   backend/
     app/
       blueprints/      # auth, family, members, transactions, recurring,
                        # goals, forecast, ai, alerts, admin, banking (NOVO)
       services/
         ai/            # adaptador Jev AI + fallback
         pluggy/        # PluggyAdapter + PluggySyncService (NOVO)
     tests/
   supabase/
     migrations/        # DDL das tabelas + politicas RLS
     seed/              # familia de demonstracao
   docs/specs/          # este documento
   README.md            # instalacao, configuracao e execucao
```

### 4.3 Modelo de dados

Treze tabelas sustentam a versão 1 (dez originais + três novas para Pluggy), desenhadas de forma deliberadamente enxuta: cada uma tem um papel claro e nenhum dado pessoal fica fora do alcance das políticas RLS da seção 4.4.

| Tabela | Campos principais | Papel |
|---|---|---|
| families | id, nome, criado_por, criado_em, is_demo | Agrupamento central de tudo; flag `is_demo` identifica a família de demonstração |
| profiles | id (= auth.users.id), family_id, nome, papel (admin/membro), status (ativo/inativo) | Identidade dentro da família |
| categories | id, family_id, nome, tipo (receita/despesa), personalizada (bool), oculta (bool), criado_por | Categorias padrão e customizadas |
| transactions | id, family_id, member_id, tipo, escopo, valor, descricao, category_id, data, pago_por, recurring_rule_id, mes_referencia, criado_por, **origem (manual/pluggy)**, **bank_transaction_id (nullable)** | Todo lançamento |
| recurring_rules | id, family_id, criado_por, tipo, escopo, valor, descricao, category_id, dia_vencimento, ativo | Aluguel, salários, assinaturas |
| recurring_occurrences | id, rule_id, mes_referencia, status, valor_confirmado, confirmado_por, confirmado_em | Estado de confirmação de cada ocorrência mensal |
| goals | id, family_id, member_id, titulo, valor_alvo, prazo, status, descricao | Metas |
| goal_contributions | id, goal_id, member_id, valor, data | Progresso das metas |
| ai_messages | id, family_id, member_id, role, content, criado_em | Histórico de conversas com a Jev AI |
| ai_suggestions | id, family_id, member_id, tipo, titulo, o_que, por_que, quanto, criado_em, lida | Recomendações da Jev AI |
| **bank_connections** | **id, family_id, member_id, pluggy_connection_id, institution_name, institution_logo_url, account_name, account_type, account_number_masked, status (ativa/inativa/erro_sincronizacao/expirada), consentido_em, ultima_sync_em, criada_em, atualizada_em** | **Conexões bancárias via Pluggy (pessoais)** |
| **bank_accounts** | **id, connection_id, pluggy_account_id, nome, tipo (corrente/poupanca), currency, balance, updated_at** | **Contas bancárias vinculadas a uma conexão** |
| **bank_transactions** | **id, bank_connection_id, bank_account_id, pluggy_transaction_id, data, valor, descricao, tipo (debito/credito), categoria_bancaria, status (pendente_importacao/importada/ignorada/reconciliada), transaction_id (nullable → vínculo com lançamento), sincronizado_em, is_demo_sync** | **Transações bancárias sincronizadas do Pluggy** |

**Notas sobre as novas tabelas:**

- `bank_connections` é **pessoal**: cada conexão pertence a um único `member_id`. O administrador não tem acesso.
- `bank_transactions` armazena os dados brutos vindos do Pluggy. O campo `transaction_id` (nullable) cria o vínculo quando a transação é importada ou reconciliada com um lançamento na tabela `transactions`.
- `is_demo_sync` permite pré-carregar transações bancárias fictícias para a Família Demo.
- Nenhum campo armazena senha, token bancário ou credencial sensível. O `pluggy_connection_id` é um identificador opaco fornecido pelo Pluggy.

### 4.4 Privacidade no banco (RLS) — a fonte da verdade

A regra de privacidade não vive só na tela: cada tabela tem políticas RLS no Supabase.

**Política central de `transactions`:**

- SELECT/INSERT/UPDATE/DELETE apenas quando o `family_id` da linha é o da família do usuário autenticado.
- Para UPDATE/DELETE: o escopo é `family` (qualquer membro ativo pode editar) ou o `member_id` é o próprio usuário (lançamento pessoal).
- DELETE restrito ao autor do lançamento (`criado_por = auth.uid()`).
- O administrador não possui nenhuma política de bypass sobre dados pessoais — isso é intencional e faz parte dos requisitos.

**Políticas das novas tabelas Pluggy:**

- **`bank_connections`:** SELECT/INSERT/UPDATE/DELETE apenas quando `member_id = auth.uid()`. Nenhum outro membro (nem admin) acessa.
- **`bank_accounts`:** SELECT/INSERT/UPDATE/DELETE via JOIN com `bank_connections` onde `member_id = auth.uid()`.
- **`bank_transactions`:** SELECT/UPDATE apenas quando a `bank_connection_id` pertence a uma conexão do próprio usuário. INSERT apenas pelo backend (via service role no momento da sync). DELETE não permitido ao usuário (o backend gerencia limpeza).

**Outras tabelas (sem alteração):**

- `profiles`: cada membro vê apenas o próprio perfil; o administrador vê todos os perfis da própria família.
- `goals` e `goal_contributions`: metas pessoais visíveis apenas ao dono; metas familiares visíveis a todos os membros ativos.
- `recurring_rules` e `recurring_occurrences`: regras pessoais visíveis apenas ao dono; regras familiares visíveis a todos os membros ativos.
- `categories`: todas as categorias da família visíveis a todos os membros ativos.
- `ai_messages` e `ai_suggestions`: mensagens pessoais visíveis apenas ao dono; mensagens familiares visíveis a todos os membros ativos.

O backend consulta o banco com o JWT do próprio usuário — o RLS vale de ponta a ponta; a service role é reservada à Admin API (convites, desativação), ao seed e à **sincronização Pluggy** (que precisa inserir `bank_transactions` em nome do usuário). Mesmo que o frontend contenha uma falha, o banco recusa a consulta; mesmo chamando a API diretamente com um token válido, o resultado é o mesmo.

### 4.5 Autenticação e fluxo de família

*(Sem alterações em relação à versão anterior.)*

Primeira pessoa se cadastra com e-mail e senha (Supabase Auth) e cria a família — torna-se administradora. Todo cadastro sem convite cria uma nova família; a Família Demo é acessada apenas pelas credenciais de demonstração.

A administradora convida membros pelo e-mail (convite nativo do Supabase). Cada membro define a própria senha no primeiro acesso. Redefinição de senha sempre por link enviado ao e-mail do próprio membro; a administradora apenas dispara o envio. Desativação de conta preserva o histórico e remove o membro das listagens.

### 4.6 Integração com a Jev AI

*(Sem alterações em relação à versão anterior.)*

O backend concentra toda a chamada de IA em um adaptador único (`services/ai`). A interface do adaptador recebe um contexto financeiro pronto (nunca credenciais de outros usuários) e devolve sugestões estruturadas. Duas implementações:

- `JevAIAdapter`: chamada HTTP para `JEV_AI_BASE_URL` com `JEV_AI_API_KEY`, com timeout curto.
- `FallbackLLMAdapter`: provedor genérico compatível.

Falha ou timeout da Jev AI ativa failover automático para o fallback; sem nenhuma chave configurada, o painel de IA entra em modo degradado com estado vazio explicativo.

### 4.7 Integração com o Pluggy (NOVO)

#### 4.7.1 Arquitetura da integração

```
┌─────────────┐       ┌──────────────────┐       ┌─────────────┐
│   React     │──────▶│   Flask Backend  │──────▶│  Pluggy API │
│  (Frontend) │       │  (PluggyAdapter) │       │  (REST)     │
│             │       │                  │       │             │
│  Pluggy     │       │  - Sync service  │       │  - Connectors│
│  Connect    │       │  - Import service│       │  - Accounts  │
│  Widget     │       │  - Reconcile svc │       │  - Transactions│
└─────────────┘       └──────────────────┘       └─────────────┘
       │                      │
       │                      ▼
       │              ┌──────────────┐
       └─────────────▶│  Supabase    │
         (via API)    │  (Postgres)  │
                      └──────────────┘
```

#### 4.7.2 Componentes novos

| Componente | Localização | Responsabilidade |
|---|---|---|
| `PluggyAdapter` | `backend/app/services/pluggy/adapter.py` | Encapsula todas as chamadas HTTP à API Pluggy (listar conectores, criar conexão, buscar contas, buscar transações, deletar conexão, disparar sync) |
| `PluggySyncService` | `backend/app/services/pluggy/sync.py` | Orquestra a sincronização: chama o adaptador, processa as transações, insere/atualiza no Supabase, atualiza status da conexão |
| `PluggyImportService` | `backend/app/services/pluggy/import_service.py` | Lógica de importação: converte transação bancária em lançamento, faz reconciliação, atualiza status |
| `PluggyConnect` (widget) | `frontend/src/components/PluggyConnect.jsx` | Wrapper React para o widget JavaScript do Pluggy; gerencia o fluxo de conexão no frontend |
| Blueprint `banking` | `backend/app/blueprints/banking.py` | Rotas REST: conectar, desconectar, listar conexões, extrato, sincronizar, importar, reconciliar |

#### 4.7.3 Chamadas do backend à API Pluggy

| Operação | Método Pluggy (a validar) | Quando |
|---|---|---|
| Listar instituições disponíveis | `GET /connectors` | Tela de "Conectar banco" |
| Criar conexão (após widget) | `POST /connections` ou uso do `connectionId` retornado pelo widget | Primeiro uso |
| Buscar contas da conexão | `GET /accounts?connectionId={id}` | Após conectar e em cada sync |
| Buscar transações | `GET /transactions?accountId={id}&from={date}&to={date}` | Sincronização |
| Disparar sincronização | `POST /connectors/{id}/sync` ou endpoint equivalente *(a validar)* | Sync automática/manual |
| Deletar conexão | `DELETE /connections/{id}` | Desconexão pelo usuário |
| Verificar status | `GET /connections/{id}` | Verificação de saúde |

**Autenticação:** header `X-API-KEY: {PLUGGY_API_KEY}` em todas as chamadas. *(a validar: confirmar nome exato do header na documentação Pluggy)*

#### 4.7.4 Segredos e variáveis de ambiente

| Variável | Onde fica | Nunca vai para |
|---|---|---|
| `PLUGGY_API_KEY` | Backend (Vercel env) | Frontend, repositório Git |
| `SUPABASE_URL` | Backend + Frontend (key pública) | — |
| `SUPABASE_ANON_KEY` | Backend + Frontend | — |
| `SUPABASE_SERVICE_ROLE_KEY` | Backend apenas | Frontend, repositório Git |
| `JEV_AI_BASE_URL` | Backend apenas | Frontend |
| `JEV_AI_API_KEY` | Backend apenas | Frontend |

#### 4.7.5 Webhooks (a validar)

O Pluggy pode oferecer webhooks para notificar quando uma sincronização foi concluída ou quando há novos dados. Se disponível:

- O backend expõe um endpoint `/api/banking/webhook` que recebe a notificação.
- O endpoint valida a assinatura/autenticidade do webhook.
- Ao receber, dispara a sync e atualiza o status.
- Se webhooks não estiverem disponíveis na versão contratada, a sync é feita por polling (cron a cada 24h + manual).

*(a validar: confirmar disponibilidade, formato e autenticação de webhooks na documentação Pluggy)*

#### 4.7.6 Sandbox / ambiente de teste

O Pluggy oferece ambiente sandbox com dados fictícios para desenvolvimento. *(a validar: confirmar se o sandbox é gratuito e quais conectores estão disponíveis)*

- Em desenvolvimento: `PLUGGY_API_KEY` aponta para sandbox.
- Em produção: `PLUGGY_API_KEY` aponta para ambiente real.
- A Família Demo usa transações pré-carregadas (não depende de sandbox em produção).

### 4.8 Deploy

Frontend na Vercel como site estático (o React gera o bundle). Backend Flask empacotado como função serverless da Vercel (`api/index.py`), com as variáveis de ambiente:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY` (somente backend)
- `JEV_AI_BASE_URL`
- `JEV_AI_API_KEY`
- **`PLUGGY_API_KEY`** (somente backend)

**Nota sobre cron/sync automática:** a Vercel free tier não oferece cron jobs nativos. Opções:
1. Vercel Cron (plano Pro) — *(a validar: custo)*
2. Serviço externo (ex.: cron-job.org chamando endpoint) — *(a validar: segurança)*
3. Mover o backend para Render/Railway que suporta cron nativo — alternativa já documentada.
4. Sync "lazy": disparar sync quando o usuário abre a tela de extrato se a última sync foi > 24h atrás.

**Recomendação para v1:** opção 4 (sync lazy) + botão manual. Evita dependência de cron externo.

O README documenta instalação local, configuração do Supabase (migrations + seed), configuração Pluggy e execução.

---

## 5. Telas e experiência

- **Login / Cadastro** — entrar, criar família (primeiro usuário) e aceitar convite. Credenciais demo visíveis.
- **Painel familiar** — objetivo, sem saudação: saldo, receitas x despesas (6 meses), categorias (rosca), contas a confirmar, metas familiares com detalhamento por membro, sugestões Jev AI, alertas. **Indicador de conexões bancárias ativas.**
- **Página individual** — "Olá, {nome}!": números pessoais, categorias pessoais, metas pessoais, recorrentes pessoais, sugestões pessoais da Jev AI. **Resumo de conexões bancárias e transações pendentes de importação.**
- **Lançamentos** — lista filtrável (mês, tipo, escopo, categoria, **origem**) + modal de criação/edição.
- **Recorrentes** — lista de regras + fila de confirmação ("confirmar", "ignorar", "confirmar com outro valor").
- **Metas** — familiares (com contribuição por membro) e pessoais, com progresso e registro de contribuições.
- **Previsões** — projeção mensal 12 meses e anual, detalhada por item, rotulada como estimativa.
- **Jev AI** — painel de conversa/sugestões com histórico, sempre com o quê / por quê / quanto.
- **Extrato bancário (NOVO)** — tela dedicada:
  - Lista de contas conectadas (banco, tipo, últimos 4 dígitos, saldo).
  - Extrato da conta selecionada com transações.
  - Filtros: período, tipo, status de importação.
  - Ações por transação: "Importar", "Ignorar", "Reconciliar".
  - Ações em lote: "Importar selecionadas".
  - Botão "Sincronizar agora".
  - Botão "Conectar nova conta" (se < 3 conexões).
  - Estados: vazio (sem conta conectada), carregando (sync em andamento), erro (falha na sync), sucesso.
- **Configurações / Admin** — membros (convidar, editar cadastro, disparar redefinição, desativar), categorias, tema claro/escuro. **Contas bancárias (conectar, desconectar, status).**

**Experiência:** interface moderna e limpa, mobile-first (a família registra gastos pelo celular), navegação em no máximo 2 toques para registrar um lançamento, estados vazios e de carregamento cuidados, verde institucional como cor de marca.

---

## 6. Regras de negócio

### 6.1 Confirmação de recorrentes

*(Sem alterações em relação à versão anterior.)*

A regra recorrente nunca cria lançamento automático. O servidor calcula, a cada uso, as ocorrências pendentes: para cada regra ativa cujo dia de vencimento cai no mês corrente (ou caiu e não foi confirmada), verifica na tabela `recurring_occurrences` se já existe um registro com status "confirmado" ou "ignorado". Se não existe, gera um cartão de confirmação visível 3 dias antes.

Confirmar cria o lançamento (com possibilidade de ajustar o valor) e insere um registro em `recurring_occurrences` com status "confirmado"; ignorar insere um registro com status "ignorado". Vencimento nos dias 29, 30 ou 31 em mês curto cai no último dia do mês (timezone de referência: America/Sao_Paulo). A confirmação é individual: para regras de família, qualquer membro ativo confirma; para regras pessoais, só o dono.

### 6.2 Previsão de gastos

Para cada mês futuro M: previsão(M) = soma das regras recorrentes ativas com vencimento em M que já foram confirmadas (status "confirmado" em `recurring_occurrences` para o mês de referência) + média móvel de 3 meses das despesas variáveis (lançamentos sem regra recorrente). A projeção anual é a soma dos 12 meses. O mesmo método se aplica a receitas. Como lançamentos passados mudam, a previsão é recalculada em tempo de exibição — não há tabela de previsão armazenada na v1.

**Nota Pluggy:** transações bancárias sincronizadas mas não confirmadas como lançamento NÃO entram na previsão. Somente lançamentos confirmados (manuais ou importados) são considerados.

### 6.3 Alertas

| Gatilho | Condição | Onde aparece |
|---|---|---|
| Conta a vencer | Regra recorrente a 3 dias ou menos do vencimento, sem registro em `recurring_occurrences` com status "confirmado" ou "ignorado" | Painel + sino |
| Meta atingida | Contribuições acumuladas >= valor-alvo (status muda para `concluida`) | Painel + sino |
| Categoria estourada | Gasto do mês em curso na categoria >= 120% da média dos 3 meses anteriores completos | Escopo família: sino de todos; escopo pessoal: só o dono |
| **Sincronização concluída** | **Sync Pluggy trouxe N transações novas** | **Sino (pessoal): "N novas transações do [banco] disponíveis"** |
| **Erro na sincronização** | **Sync Pluggy falhou ou conexão expirou** | **Sino (pessoal): "Não foi possível sincronizar com [banco]"** |

Os alertas são calculados quando o usuário abre o aplicativo, não persistidos entre sessões.

### 6.4 Categorias

Categorias padrão (não editáveis pelo nome, apenas ocultáveis):

Alimentação, Moradia, Transporte, Saúde, Educação, Lazer, Assinaturas, Outros.

Categorias personalizadas (editáveis e excluíveis pelo criador): qualquer membro ativo pode criar.

Ocultar uma categoria a remove das listas de seleção, mas o histórico existente permanece nos gráficos. A Jev AI pode sugerir categoria ao classificar um lançamento, mas a escolha final é da pessoa.

**Nota Pluggy:** transações bancárias trazem uma `categoria_bancaria` (ex.: "PIX", "TED", "CARTAO", "SALARIO"). Na importação, o app usa a categoria bancária como sugestão inicial e a Jev AI pode refinar com base na descrição. O usuário sempre pode alterar antes de confirmar.

### 6.5 Regras de importação Pluggy (NOVO)

#### 6.5.1 Transações bancárias NÃO criam lançamentos automaticamente

Toda transação sincronizada do Pluggy entra com status `pendente_importacao`. Ela só vira lançamento (`transactions`) quando o usuário explicitamente confirma. Isso preserva o controle manual e a coerência com o princípio do produto.

#### 6.5.2 Prevenção de duplicidade

- Ao importar, o sistema busca lançamentos existentes com mesmo valor (± R$ 0,01) e data próxima (± 1 dia).
- Se encontrar, sugere reconciliação (vincular) em vez de criar novo.
- Transações já importadas ou reconciliadas não aparecem mais como pendentes.
- O campo `pluggy_transaction_id` é único por conexão — impede importação dupla da mesma transação bancária.

#### 6.5.3 Tratamento de transferências entre contas

Transferências entre contas do mesmo usuário (ex.: PIX entre conta corrente e poupança) aparecem como duas transações (débito em uma, crédito em outra). Na v1:

- O usuário pode ignorar ambas (não são "gastos" nem "receitas" reais).
- Ou importar uma como despesa e outra como receita (o saldo líquido não muda).
- O sistema NÃO faz matching automático de transferências na v1. *(Possível melhoria em v2: detecção de transferências internas)*

#### 6.5.4 Contas pessoais vs. familiares

- Toda conexão bancária é **pessoal** (vinculada a um `member_id`).
- Ao importar uma transação, o escopo padrão é **pessoal**.
- O usuário pode mudar para **família** no momento da importação (ex.: compra de supermercado paga com cartão pessoal mas é despesa da família).
- Uma vez importada como lançamento familiar, segue as regras normais de edição (qualquer membro ativo pode editar).

#### 6.5.5 Saldo bancário

- O saldo da conta é exibido na tela de extrato (dado do Pluggy).
- O saldo bancário **NÃO** se confunde com o "saldo familiar do mês" do painel (que é receitas − despesas calculadas pelo app).
- O saldo bancário é informativo e pessoal; não aparece no painel familiar.

#### 6.5.6 Limite de conexões

- Máximo de 3 conexões por membro na v1.
- Se o usuário tentar conectar uma 4ª, recebe mensagem: "Limite de 3 conexões atingido. Desconecte uma conta para adicionar outra."

---

## 7. Jev AI e segurança

### 7.1 Contextos de análise

Contexto individual: a página do membro envia à Jev AI apenas as transações e metas da própria pessoa. As recomendações citam categorias e valores pessoais.

**Com Pluggy:** transações importadas do banco (já confirmadas como lançamento) entram no contexto individual normalmente. Transações ainda não importadas NÃO são enviadas à Jev AI (não são dados do VivaFinanças ainda).

Contexto familiar: o painel envia totais agregados por categoria e mês, sem identificação de membros. As recomendações falam de "a família", nunca de "Ana gastou X".

### 7.2 Formato das recomendações

Toda recomendação da Jev AI possui três campos obrigatórios:

- **O quê** — ação concreta (ex.: "revisar as assinaturas de streaming").
- **Por quê** — padrão detectado nos dados (ex.: "duas assinaturas com uso baixo nos últimos 3 meses").
- **Quanto** — economia potencial estimada (ex.: "até R$ 59,80/mês").

Quando os dados não permitem estimar, o campo "quanto" diz isso explicitamente em vez de inventar número. A interface deixa claro que são sugestões de apoio — a decisão é da família.

### 7.3 Segurança

- RLS no Supabase como camada primária; o backend repete os filtros por defesa em profundidade.
- JWT do Supabase validado em toda rota Flask; chaves de serviço nunca chegam ao frontend.
- CORS restrito ao domínio do frontend; HTTPS garantido pela Vercel.
- Segredos apenas em variáveis de ambiente; nada de credenciais no repositório.
- A Jev AI nunca recebe credenciais nem dados de outros membros além do contexto autorizado.
- **A API Key do Pluggy existe apenas no backend. O frontend interage com o Pluggy exclusivamente via widget JavaScript (que usa um token público/client-id, não a API Key secreta).** *(a validar: confirmar mecanismo de autenticação do widget na documentação Pluggy)*
- **O VivaFinanças nunca armazena senhas bancárias, tokens de banco ou dados de autenticação financeira. O Pluggy é o único responsável por esse armazenamento.**
- **Dados bancários em trânsito são protegidos por HTTPS (Vercel + Pluggy).**
- **Em caso de incidente de segurança, a desconexão no Pluggy revoga o acesso imediatamente.**

### 7.4 LGPD e privacidade de dados bancários (NOVO)

- O consentimento é explícito: o usuário opta por conectar e vê claramente quais dados serão acessados.
- O usuário pode desconectar a qualquer momento (revogação de consentimento).
- Após desconexão, transações já importadas como lançamento permanecem (são dados do usuário no VivaFinanças); transações bancárias brutas não importadas são removidas após 90 dias.
- O VivaFinanças não compartilha dados bancários com terceiros além do Pluggy (que é o processador).
- O Pluggy é responsável pela conformidade LGPD no tratamento dos dados bancários. *(a validar: confirmar termos de processamento de dados do Pluggy)*
- O VivaFinanças armazena apenas o mínimo necessário: transações (data, valor, descrição, categoria) e metadados da conexão. Não armazena saldos históricos completos, extratos em PDF ou dados cadastrais bancários.

---

## 8. Dados de demonstração, critérios de sucesso e liberdades do construtor

### 8.1 Família de demonstração

Família Demo com Ana (administradora), Carlos e Lucas. Histórico de 6 meses com:

- Aluguel: R$ 1.800
- Salários de Ana e Carlos
- Assinaturas (streaming, música, academia)
- Supermercado semanal
- Transporte e lazer variáveis
- Uma meta familiar ("Viagem em família")
- Duas metas pessoais
- **Conexão bancária simulada para Ana (flag `is_demo_sync = true` na tabela `bank_connections`)**
- **Transações bancárias simuladas na tabela `bank_transactions` (flag `is_demo_sync = true`), incluindo algumas pendentes de importação para demonstrar o fluxo**

Os valores são realistas para uma família brasileira de classe média e geram gráficos, previsões e recomendações interessantes desde o primeiro login.

### 8.2 Critérios de sucesso mensuráveis

- Login demo mostra painel completo (gráficos, previsão, sugestões) em menos de 10 segundos.
- Registrar um lançamento manual leva no máximo 3 toques e 30 segundos (navegação até o formulário em no máximo 2 toques).
- Um membro autenticado não consegue listar via API as transações pessoais de outro membro (teste automatizado de RLS).
- O administrador, ao desativar um membro, não ganha acesso aos dados pessoais do ex-membro.
- A previsão do mês seguinte é exatamente a soma de recorrentes confirmados + média móvel de 3 meses (teste automatizado).
- Toda sugestão da Jev AI exibida contém o quê, por quê e quanto (ou a declaração de que não é possível estimar).
- **Usuário consegue conectar conta bancária via widget Pluggy em menos de 2 minutos.**
- **Após conexão, o extrato é exibido corretamente na tela de extrato bancário.**
- **Transações sincronizadas aparecem com status `pendente_importacao` e podem ser importadas.**
- **Transação importada cria lançamento correto com vínculo `bank_transaction_id`.**
- **Reconciliação detecta lançamento manual duplicado e sugere vínculo.**
- **Dados bancários (conexões, transações brutas) não ficam visíveis para membros não autorizados (teste automatizado de RLS nas novas tabelas).**
- **Falha de sincronização Pluggy mostra estado de erro adequado e não quebra o restante do app.**
- **A `PLUGGY_API_KEY` não aparece em nenhuma resposta de API, bundle JavaScript ou log acessível ao frontend.**
- **Desconexão remove o vínculo no Pluggy e marca a conexão como inativa.**

### 8.3 Liberdades do construtor (decisões delegadas)

- Biblioteca de gráficos (sugestão: Recharts), estrutura de componentes e organização de estilos.
- Engenharia de prompts da Jev AI e do fallback.
- Estados vazios, skeletons de carregamento e microinterações.
- Estratégia de testes (mínimo: testes de RLS, de previsão e de importação Pluggy listados acima).
- Detalhes visuais dentro da paleta verde aprovada no mockup.
- **Implementação exata do PluggyAdapter (estrutura de classes, retry logic, paginação).**
- **Decisão entre sync lazy vs. cron (ver seção 4.8).**
- **UX exata do modal de importação (campos, ordem, validações).**

---

## 9. Próximos passos

1. Aprovação deste documento pelo usuário (gate da skill de brainstorming: nada é construído antes disso).
2. **Criação de conta Pluggy (sandbox) e obtenção de API Key de teste.**
3. **Validação da documentação Pluggy: confirmar endpoints, widget, webhooks, rate limits e sandbox.**
4. Elaboração do plano de implementação (ordem de construção, milestones).
5. Desenvolvimento: estrutura do monorepo → Supabase (migrations + RLS + seed) → backend Flask (incluindo PluggyAdapter) → frontend React (incluindo widget Pluggy) → Jev AI (adaptador + fallback) → testes → README e deploy.

---

## 10. Resumo das mudanças (desta revisão)

| Área | O que mudou |
|---|---|
| Seção 1.1 | Adicionada menção à integração Pluggy como complemento ao registro manual |
| Seção 1.2 | Fluxo atualizado com conexão bancária e importação assistida |
| Seção 1.3 | Novos objetivos: conexão Pluggy, tela de extrato, importação confirmável, reconciliação |
| Seção 1.4 | Removidos "sem Open Finance" e "sem importação de extrato" dos não-objetivos; adicionados não-objetivos de pagamento, conciliação contábil completa e produtos além de conta corrente |
| Seção 1.5 | Novos anti-objetivos: transações automáticas, armazenamento de credenciais bancárias |
| D8 | Revisada: de "somente manuais" para "manuais + importação assistida via Pluggy" |
| D12 | Pluggy adicionado à stack |
| D27–D33 | Novas decisões cobrindo: integração, escopo, consentimento, importação, privacidade bancária, armazenamento de credenciais, tratamento de falhas |
| Seção 2.2 | Novas decisões de construtor para Pluggy (sync, limite de conexões, modo degradado) |
| Seção 3.3 | Campo "origem" adicionado aos lançamentos |
| Seção 3.7 | Jev AI agora sugere categoria para transações importadas |
| Seção 3.8 | Novos gatilhos de alerta (sync concluída, erro de sync) |
| Seção 3.11 | **Seção inteiramente nova**: conexão Pluggy, fluxo, sincronização, tela de extrato, importação, reconciliação, desconexão, limites |
| Seção 4.1 | Pluggy na stack; widget no frontend |
| Seção 4.2 | Blueprint `banking` e serviços Pluggy na estrutura |
| Seção 4.3 | 3 novas tabelas: `bank_connections`, `bank_accounts`, `bank_transactions` |
| Seção 4.4 | RLS para as novas tabelas |
| Seção 4.7 | **Seção inteiramente nova**: arquitetura Pluggy, adaptador, chamadas, segredos, webhooks, sandbox |
| Seção 4.8 | Variável `PLUGGY_API_KEY`; nota sobre cron/sync |
| Seção 5 | Nova tela "Extrato bancário"; configurações atualizadas |
| Seção 6.5 | **Seção inteiramente nova**: regras de importação, duplicidade, transferências, escopo, saldo |
| Seção 7.3 | Novas regras de segurança Pluggy |
| Seção 7.4 | **Seção nova**: LGPD e privacidade de dados bancários |
| Seção 8.1 | Família Demo com conexão simulada |
| Seção 8.2 | Novos critérios de sucesso para Pluggy |

---

## 11. Premissas assumidas

1. O Pluggy oferece API REST com autenticação por API Key e um widget JavaScript para o fluxo de conexão bancária. *(a validar na documentação)*
2. O widget Pluggy pode ser integrado em aplicação React sem necessidade de backend para o fluxo de login bancário. *(a validar)*
3. O Pluggy retorna transações com campos: data, valor, descrição, tipo (débito/crédito) e categoria bancária. *(a validar schema exato)*
4. A sincronização pode ser disparada via API (POST) e/ou acontece automaticamente a cada 24h. *(a validar)*
5. O Pluggy não cobra por transação na faixa de uso esperada (família pequena, poucas contas). *(a validar pricing)*
6. O sandbox do Pluggy permite desenvolvimento e testes sem conta bancária real. *(a validar)*
7. A Vercel permite chamadas HTTP de saída do backend serverless para a API Pluggy (sem bloqueio de firewall). *(a validar)*
8. O tempo de resposta da API Pluggy é aceitável (< 5s por chamada de sync). *(a validar)*

---

## 12. Dúvidas e pontos a validar na documentação real do Pluggy

| # | Dúvida | Impacto |
|---|---|---|
| 1 | Qual o endpoint exato para criar/listar/deletar conexões? Qual o formato do `connectionId` retornado pelo widget? | Implementação do PluggyAdapter |
| 2 | Qual o header de autenticação exato? (`X-API-KEY`, `Authorization: Bearer`, outro?) | Implementação do PluggyAdapter |
| 3 | O widget JavaScript usa a mesma API Key ou um `client_id` público separado? | Segurança do frontend |
| 4 | Quais são os rate limits (requests/minuto, requests/dia)? | Estratégia de sync e cache |
| 5 | Webhooks estão disponíveis? Qual o formato e como autenticar? | Decisão entre webhook vs. polling |
| 6 | Qual a frequência mínima entre syncs? Há cooldown? | Estratégia de sync manual |
| 7 | O sandbox é gratuito? Quais conectores estão disponíveis? | Ambiente de desenvolvimento |
| 8 | Qual o schema exato de uma transação? (campos, tipos, paginação) | Modelo de dados e mapeamento |
| 9 | Como tratar conexão expirada (banco pede reautenticação)? O Pluggy notifica? | UX de erro e reconexão |
| 10 | Há limite de conexões simultâneas por API Key? | Limite de 3 por membro |
| 11 | Qual a política de retenção de dados no Pluggy? Posso solicitar deleção? | LGPD |
| 12 | O Pluggy suporta instituições como Nubank, Inter, Itaú, Bradesco, Caixa, Banco do Brasil, C6, PicPay? | Cobertura para o público-alvo |
| 13 | O custo do Pluggy é por conexão ativa, por chamada, ou flat? Impacta a viabilidade do projeto? | Decisão de seguir com Pluggy vs. alternativa |
| 14 | Há SDK Python oficial ou apenas REST? | Implementação do backend |

---

## 13. Glossário

| Termo | Definição |
|---|---|
| Pluggy | Plataforma brasileira de Open Finance que fornece API para acesso a dados bancários mediante consentimento |
| Open Finance | Sistema regulado pelo Banco Central do Brasil que permite compartilhamento de dados financeiros entre instituições mediante consentimento do titular |
| Conector | Representação de uma instituição financeira no Pluggy (ex.: "Nubank", "Itaú") |
| Conexão | Vínculo entre um usuário e uma instituição financeira, criado via widget Pluggy |
| Sincronização (sync) | Processo de buscar dados atualizados (transações, saldo) do banco via Pluggy |
| Importação | Ato de converter uma transação bancária em um lançamento no VivaFinanças (sempre com confirmação) |
| Reconciliação | Processo de vincular uma transação bancária a um lançamento manual já existente, evitando duplicidade |
| RLS | Row Level Security — política de segurança no nível do banco de dados (Supabase/Postgres) |
| Widget Pluggy | Componente JavaScript fornecido pelo Pluggy para o fluxo de autenticação bancária no frontend |
| API Key Pluggy | Chave secreta que autentica o backend do VivaFinanças nas chamadas à API Pluggy |

---