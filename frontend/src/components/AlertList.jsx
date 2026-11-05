import { CalendarClock, RefreshCw, Target, TrendingUp, TriangleAlert } from 'lucide-react'

const ICONS = {
  conta_a_vencer: CalendarClock,
  meta_atingida: Target,
  categoria_estourada: TrendingUp,
  sync_concluida: RefreshCw,
  sync_erro: TriangleAlert,
}

export default function AlertList({ alerts = [], compact = false }) {
  if (!alerts.length) {
    return (
      <p className="py-4 text-sm text-muted">
        Nenhum alerta por agora. Contas a vencer, metas atingidas e categorias acima do normal
        aparecem aqui.
      </p>
    )
  }

  return (
    <ul className="divide-y divide-linha">
      {alerts.map((alert, index) => {
        const Icon = ICONS[alert.tipo] || TriangleAlert
        return (
          <li key={`${alert.tipo}-${index}`} className="flex gap-3 py-3.5">
            <span className="mt-0.5 flex h-7 w-7 shrink-0 items-center justify-center rounded-full border border-linha text-terracota-texto">
              <Icon size={14} aria-hidden="true" />
            </span>
            <div className="min-w-0">
              <p className="text-sm font-medium">{alert.titulo}</p>
              {alert.detalhe ? (
                <p className={`mt-0.5 text-muted ${compact ? 'text-xs' : 'text-sm'}`}>{alert.detalhe}</p>
              ) : null}
              {alert.escopo ? (
                <p className="mt-1 text-2xs text-muted">
                  {alert.escopo === 'familia' ? 'Família' : 'Pessoal'}
                </p>
              ) : null}
            </div>
          </li>
        )
      })}
    </ul>
  )
}
