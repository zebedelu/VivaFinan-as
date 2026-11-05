import { formatDate, formatMoney, goalProgress } from '../lib/format'
import { GOAL_STATUS } from '../lib/labels'
import Badge from './Badge'
import Button from './Button'
import ProgressBar from './ProgressBar'

export default function GoalCard({ goal, currentUserId, onContribute, onEdit, onDelete }) {
  const contribuicoes = goal.contribuicoes || []
  const { contribuido: total, pct } = goalProgress(goal)
  const status = GOAL_STATUS[goal.status] || GOAL_STATUS.em_andamento
  const isOwner = goal.criado_por === currentUserId
  const canContribute = goal.status === 'em_andamento'

  const byMember = contribuicoes.reduce((acc, item) => {
    const key = item.member_nome || 'Sem nome'
    acc[key] = (acc[key] || 0) + (Number(item.valor) || 0)
    return acc
  }, {})

  return (
    <article className="border-b border-linha py-5 last:border-b-0">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div className="min-w-0">
          <h3 className="font-display text-lg leading-snug">{goal.titulo}</h3>
          {goal.descricao ? <p className="mt-1 text-sm text-muted">{goal.descricao}</p> : null}
        </div>
        <Badge tone={status.tone}>{status.label}</Badge>
      </div>

      <div className="mt-4">
        <div className="mb-1.5 flex items-baseline justify-between gap-3 text-sm">
          <span className="num">
            {formatMoney(total)} <span className="text-muted">de {formatMoney(goal.valor_alvo)}</span>
          </span>
          <span className="num text-xs text-muted">{Math.round(pct)}%</span>
        </div>
        <ProgressBar value={pct} label={`Progresso da meta ${goal.titulo}`} />
      </div>

      <div className="mt-3 flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted">
        {goal.prazo ? <span>Prazo em {formatDate(goal.prazo)}</span> : <span>Sem prazo</span>}
        <span>{goal.member_id ? `Pessoal de ${goal.member_nome || 'membro'}` : 'Meta da família'}</span>
        {goal.criado_por_nome ? <span>Criada por {goal.criado_por_nome}</span> : null}
      </div>

      {Object.keys(byMember).length > 0 ? (
        <ul className="mt-3 flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted">
          {Object.entries(byMember).map(([nome, valor]) => (
            <li key={nome}>
              {nome}: <span className="num text-grafite">{formatMoney(valor)}</span>
            </li>
          ))}
        </ul>
      ) : null}

      {contribuicoes.length > 0 ? (
        <details className="mt-3 text-sm">
          <summary className="cursor-pointer text-xs text-muted">Ver contribuições</summary>
          <ul className="mt-2 space-y-1.5">
            {contribuicoes.map((item) => (
              <li key={item.id} className="flex justify-between gap-3 text-xs">
                <span>
                  {formatDate(item.data)} · {item.member_nome || 'Membro'}
                </span>
                <span className="num">{formatMoney(item.valor)}</span>
              </li>
            ))}
          </ul>
        </details>
      ) : null}

      <div className="mt-4 flex flex-wrap gap-2">
        {canContribute ? (
          <Button variant="secondary" className="px-3 py-1.5 text-xs" onClick={() => onContribute(goal)}>
            Contribuir
          </Button>
        ) : null}
        {isOwner ? (
          <>
            <Button variant="ghost" className="px-3 py-1.5 text-xs" onClick={() => onEdit(goal)}>
              Editar
            </Button>
            <Button variant="ghost" className="px-3 py-1.5 text-xs text-terracota-texto" onClick={() => onDelete(goal)}>
              Excluir
            </Button>
          </>
        ) : null}
      </div>
    </article>
  )
}
