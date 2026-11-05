import { currentMonth } from '../lib/format'

export const demoSession = {
  access_token: 'token-demo',
  user: { id: 'u-ana', email: 'ana@demo.vivafinancas.app' },
}

export const demoProfile = {
  id: 'u-ana',
  family_id: 'fam-1',
  nome: 'Ana Souza',
  papel: 'admin',
  status: 'ativo',
  tema: 'claro',
}

export const demoFamily = {
  id: 'fam-1',
  nome: 'Família Souza',
  is_demo: true,
}

export const categories = [
  { id: 'c-moradia', nome: 'Moradia', tipo: 'despesa', personalizada: false, oculta: false },
  { id: 'c-mercado', nome: 'Mercado', tipo: 'despesa', personalizada: false, oculta: false },
  { id: 'c-transporte', nome: 'Transporte', tipo: 'despesa', personalizada: true, oculta: false },
  { id: 'c-lazer', nome: 'Lazer', tipo: 'despesa', personalizada: true, oculta: true },
  { id: 'c-salario', nome: 'Salário', tipo: 'receita', personalizada: false, oculta: false },
]

const serie = [
  { mes: '2026-06-01', receitas: 11000, despesas: 8200 },
  { mes: '2026-07-01', receitas: 11200, despesas: 7900 },
  { mes: '2026-08-01', receitas: 11000, despesas: 8600 },
  { mes: '2026-09-01', receitas: 11800, despesas: 8100 },
  { mes: '2026-10-01', receitas: 12000, despesas: 8400 },
  { mes: '2026-11-01', receitas: 12000, despesas: 7800 },
]

export const pendingOccurrences = [
  {
    occurrence_id: 'occ-1',
    rule_id: 'r1',
    tipo: 'despesa',
    escopo: 'familia',
    valor: 2500,
    descricao: 'Aluguel',
    categoria: 'Moradia',
    data_vencimento: '2026-11-06',
    dias_para_vencimento: 2,
  },
  {
    occurrence_id: 'occ-2',
    rule_id: 'r2',
    tipo: 'despesa',
    escopo: 'familia',
    valor: 120,
    descricao: 'Internet',
    categoria: 'Moradia',
    data_vencimento: '2026-11-02',
    dias_para_vencimento: -2,
  },
]

export const goals = [
  {
    id: 'g1',
    titulo: 'Reserva de emergência',
    valor_alvo: 6000,
    prazo: '2027-06-01',
    status: 'em_andamento',
    descricao: 'Seis meses de contas guardados.',
    member_id: null,
    member_nome: null,
    criado_por: 'u-ana',
    criado_por_nome: 'Ana Souza',
    progresso: 20,
    contribuicoes: [
      { id: 'k1', member_id: 'u-ana', member_nome: 'Ana Souza', valor: 1200, data: '2026-10-10' },
    ],
  },
  {
    id: 'g2',
    titulo: 'Viagem de fim de ano',
    valor_alvo: 4000,
    prazo: null,
    status: 'em_andamento',
    descricao: null,
    member_id: null,
    member_nome: null,
    criado_por: 'u-carlos',
    criado_por_nome: 'Carlos Souza',
    progresso: 50,
    contribuicoes: [
      { id: 'k2', member_id: 'u-carlos', member_nome: 'Carlos Souza', valor: 2000, data: '2026-09-10' },
    ],
  },
]

export function dashboardPayload() {
  return {
    mes: currentMonth(),
    totais: { receitas: 12000, despesas: 7800, saldo: 4200 },
    acumulado: { receitas: 74000, despesas: 54000 },
    categorias: [
      { category_id: 'c-moradia', categoria: 'Moradia', total: 3200 },
      { category_id: 'c-mercado', categoria: 'Mercado', total: 2100 },
    ],
    serie,
    membros: [
      { member_id: 'u-ana', nome: 'Ana Souza', papel: 'admin' },
      { member_id: 'u-carlos', nome: 'Carlos Souza', papel: 'membro' },
    ],
    metas: goals,
    sugestoes: [
      {
        id: 's1',
        tipo: 'assinatura',
        titulo: 'Revise as assinaturas',
        o_que: 'Cancele o streaming que você não assiste há dois meses.',
        por_que: 'É o gasto que mais cresceu fora do padrão.',
        quanto: 'R$ 80 por mês',
        lida: false,
      },
    ],
    alertas: [
      {
        tipo: 'conta_a_vencer',
        titulo: 'Aluguel vence em 2 dias',
        detalhe: 'Confirme para entrar no mês.',
        escopo: 'familia',
      },
    ],
    recorrentes_pendentes: pendingOccurrences,
    banco: { conexoes_ativas: 1, pendentes: 3 },
  }
}

export const transactions = [
  {
    id: 't1',
    tipo: 'despesa',
    escopo: 'familia',
    valor: 210.5,
    descricao: 'Mercado',
    category_id: 'c-mercado',
    categoria: 'Mercado',
    data: '2026-11-02',
    pago_por: null,
    pago_por_nome: null,
    recurring_rule_id: null,
    mes_referencia: null,
    origem: 'manual',
    bank_transaction_id: null,
    criado_por: 'u-ana',
    criado_em: '2026-11-02T12:00:00Z',
  },
  {
    id: 't2',
    tipo: 'receita',
    escopo: 'pessoal',
    valor: 5000,
    descricao: 'Freela',
    category_id: 'c-salario',
    categoria: 'Salário',
    data: '2026-11-03',
    pago_por: null,
    pago_por_nome: null,
    recurring_rule_id: null,
    mes_referencia: null,
    origem: 'pluggy',
    bank_transaction_id: 'bt1',
    criado_por: 'u-ana',
    criado_em: '2026-11-03T12:00:00Z',
  },
]

export const rules = [
  {
    id: 'r1',
    tipo: 'despesa',
    escopo: 'familia',
    valor: 2500,
    descricao: 'Aluguel',
    category_id: 'c-moradia',
    categoria: 'Moradia',
    dia_vencimento: 5,
    ativo: true,
    criado_por: 'u-ana',
  },
  {
    id: 'r2',
    tipo: 'despesa',
    escopo: 'familia',
    valor: 120,
    descricao: 'Internet',
    category_id: 'c-moradia',
    categoria: 'Moradia',
    dia_vencimento: 10,
    ativo: true,
    criado_por: 'u-ana',
  },
]

export function forecastPayload() {
  const months = Array.from({ length: 12 }, (_, index) => {
    const mes = `2026-${String((index % 12) + 1).padStart(2, '0')}-01`
    return {
      mes,
      receitas: 12000,
      despesas: 7600,
      saldo: 4400,
      recorrentes_receitas: 9000,
      recorrentes_despesas: 5000,
      variavel_receitas: 3000,
      variavel_despesas: 2600,
      detalhes: [{ categoria: 'Moradia', valor: 3200 }],
    }
  })
  return {
    meses: months,
    anual: { receitas: 144000, despesas: 91200, saldo: 52800 },
  }
}

export const bankConnections = [
  {
    id: 'bc1',
    institution_name: 'Banco Demo',
    account_name: 'Conta corrente',
    account_type: 'Corrente',
    account_number_masked: '•••• 1234',
    status: 'ativa',
    ultima_sync_em: new Date().toISOString(),
    is_demo_sync: true,
  },
]

export const bankAccounts = [
  {
    id: 'ba1',
    connection_id: 'bc1',
    nome: 'Conta corrente',
    tipo: 'Corrente',
    currency: 'BRL',
    balance: 3200.5,
    updated_at: new Date().toISOString(),
  },
]

export const bankTransactions = [
  {
    id: 'bt1',
    bank_connection_id: 'bc1',
    data: '2026-11-01',
    valor: 45.9,
    descricao: 'Padaria',
    tipo: 'debito',
    categoria_bancaria: 'Alimentação',
    status: 'pendente_importacao',
    transaction_id: null,
  },
  {
    id: 'bt2',
    bank_connection_id: 'bc1',
    data: '2026-11-02',
    valor: 89.9,
    descricao: 'Farmácia',
    tipo: 'debito',
    categoria_bancaria: 'Saúde',
    status: 'pendente_importacao',
    transaction_id: null,
  },
  {
    id: 'bt3',
    bank_connection_id: 'bc1',
    data: '2026-11-03',
    valor: 23,
    descricao: 'Uber',
    tipo: 'debito',
    categoria_bancaria: 'Transporte',
    status: 'pendente_importacao',
    transaction_id: null,
  },
  {
    id: 'bt4',
    bank_connection_id: 'bc1',
    data: '2026-10-28',
    valor: 310,
    descricao: 'Mercado antigo',
    tipo: 'debito',
    categoria_bancaria: 'Alimentação',
    status: 'ignorada',
    transaction_id: null,
  },
  {
    id: 'bt5',
    bank_connection_id: 'bc1',
    data: '2026-11-05',
    valor: 1500,
    descricao: 'Salário',
    tipo: 'credito',
    categoria_bancaria: 'Salário',
    status: 'pendente_importacao',
    transaction_id: null,
  },
]

export const suggestions = [
  {
    id: 's1',
    tipo: 'assinatura',
    titulo: 'Revise as assinaturas',
    o_que: 'Cancele o streaming que você não assiste há dois meses.',
    por_que: 'É o gasto que mais cresceu fora do padrão.',
    quanto: 'R$ 80 por mês',
    lida: false,
  },
]
