import { Check } from 'lucide-react'
import Badge from './Badge'

export default function SuggestionCard({ suggestion, onRead }) {
  const unread = !suggestion.lida
  return (
    <article className="border-b border-linha py-4 last:border-b-0">
      <div className="flex items-start justify-between gap-3">
        <div className="flex items-start gap-2.5">
          <span
            className={`mt-1.5 h-1.5 w-1.5 shrink-0 rounded-full ${unread ? 'bg-dourado-forte' : 'bg-transparent'}`}
            aria-label={unread ? 'Não lida' : undefined}
          />
          <h3 className="font-display text-base leading-snug">{suggestion.titulo}</h3>
        </div>
        {suggestion.tipo ? <Badge>{suggestion.tipo}</Badge> : null}
      </div>
      <dl className="mt-3 space-y-2 text-sm">
        <div>
          <dt className="text-2xs text-muted">O que fazer</dt>
          <dd className="mt-0.5">{suggestion.o_que}</dd>
        </div>
        <div>
          <dt className="text-2xs text-muted">Por quê</dt>
          <dd className="mt-0.5 text-muted">{suggestion.por_que}</dd>
        </div>
        <div>
          <dt className="text-2xs text-muted">Quanto</dt>
          <dd className="mt-0.5">{suggestion.quanto || 'Não é possível estimar'}</dd>
        </div>
      </dl>
      {unread && onRead ? (
        <button
          type="button"
          onClick={() => onRead(suggestion)}
          className="mt-3 inline-flex items-center gap-1.5 text-xs text-muted underline decoration-linha underline-offset-4 hover:text-grafite"
        >
          <Check size={12} aria-hidden="true" />
          Marcar como lida
        </button>
      ) : null}
    </article>
  )
}
