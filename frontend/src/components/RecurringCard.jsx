import { dueLabel, formatMoney } from '../lib/format'
import { ESCOPO_LABEL } from '../lib/labels'
import Badge from './Badge'
import Button from './Button'

export default function RecurringCard({ occurrence, onConfirm, onIgnore, busy = false, allowCustomValue = true }) {
  const overdue = occurrence.dias_para_vencimento < 0
  return (
    <article className="flex flex-col gap-3 border-b border-linha py-4 last:border-b-0 sm:flex-row sm:items-center sm:justify-between">
      <div className="min-w-0 border-l-2 border-dourado pl-3">
        <div className="flex flex-wrap items-center gap-2">
          <p className="font-medium">{occurrence.descricao || occurrence.categoria || 'Conta recorrente'}</p>
          <Badge tone={overdue ? 'terracota' : 'neutro'}>{dueLabel(occurrence.data_vencimento)}</Badge>
        </div>
        <p className="mt-1 flex flex-wrap items-center gap-x-2 text-xs text-muted">
          <span>{ESCOPO_LABEL[occurrence.escopo] || occurrence.escopo}</span>
          {occurrence.categoria ? <span>· {occurrence.categoria}</span> : null}
        </p>
      </div>
      <div className="flex flex-wrap items-center justify-between gap-3 sm:justify-end">
        <span className={`num font-display text-lg ${occurrence.tipo === 'receita' ? 'text-verde-texto' : 'text-terracota-texto'}`}>
          {formatMoney(occurrence.valor)}
        </span>
        <div className="flex gap-2">
          <Button
            variant="primary"
            className="px-3 py-1.5 text-xs"
            onClick={() => onConfirm(occurrence)}
            disabled={busy}
          >
            Confirmar
          </Button>
          {allowCustomValue ? (
            <Button
              variant="secondary"
              className="px-3 py-1.5 text-xs"
              onClick={() => onConfirm(occurrence, true)}
              disabled={busy}
            >
              Outro valor
            </Button>
          ) : null}
          <Button
            variant="ghost"
            className="px-3 py-1.5 text-xs"
            onClick={() => onIgnore(occurrence)}
            disabled={busy}
          >
            Ignorar
          </Button>
        </div>
      </div>
    </article>
  )
}
