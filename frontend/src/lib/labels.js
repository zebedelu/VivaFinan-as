export const TIPO_LABEL = { receita: 'Receita', despesa: 'Despesa' }
export const ESCOPO_LABEL = { pessoal: 'Pessoal', familia: 'Família' }
export const ORIGEM_LABEL = { manual: 'Manual', pluggy: 'Banco' }
export const PAPEL_LABEL = { admin: 'Administrador', membro: 'Membro' }
export const STATUS_MEMBRO_LABEL = { ativo: 'Ativo', inativo: 'Inativo' }

export const BANK_STATUS = {
  pendente_importacao: { label: 'Pendente', tone: 'dourado' },
  importada: { label: 'Importada', tone: 'verde' },
  reconciliada: { label: 'Reconciliada', tone: 'verde' },
  ignorada: { label: 'Ignorada', tone: 'neutro' },
}

export const GOAL_STATUS = {
  em_andamento: { label: 'Em andamento', tone: 'dourado' },
  concluida: { label: 'Concluída', tone: 'verde' },
  cancelada: { label: 'Cancelada', tone: 'neutro' },
}

export const CONNECTION_STATUS = {
  ativa: { label: 'Ativa', tone: 'verde' },
  expirada: { label: 'Expirada', tone: 'terracota' },
  erro: { label: 'Com erro', tone: 'terracota' },
  inativa: { label: 'Inativa', tone: 'neutro' },
}

export function pluralize(count, singular, plural) {
  return `${count} ${count === 1 ? singular : plural}`
}
