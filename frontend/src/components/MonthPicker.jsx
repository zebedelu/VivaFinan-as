import { useId } from 'react'
import { ChevronLeft, ChevronRight } from 'lucide-react'
import { classNames } from '../lib/format'

export default function MonthPicker({ mes, label, onPrev, onNext, onToday, isCurrent, className }) {
  const labelId = useId()
  return (
    <div className={classNames('flex items-center gap-1', className)}>
      <button
        type="button"
        onClick={onPrev}
        className="rounded-control border border-linha p-2 text-muted transition-colors hover:text-grafite"
        aria-label="Mês anterior"
      >
        <ChevronLeft size={16} aria-hidden="true" />
      </button>
      <span
        id={labelId}
        className="min-w-[9.5rem] text-center text-sm font-medium text-grafite"
        aria-live="polite"
      >
        {label}
      </span>
      <button
        type="button"
        onClick={onNext}
        className="rounded-control border border-linha p-2 text-muted transition-colors hover:text-grafite"
        aria-label="Próximo mês"
      >
        <ChevronRight size={16} aria-hidden="true" />
      </button>
      {!isCurrent && onToday ? (
        <button
          type="button"
          onClick={onToday}
          className="ml-1 rounded-control px-2 py-1 text-xs text-verde-texto underline decoration-verde-texto/30 hover:decoration-verde-texto"
        >
          Este mês
        </button>
      ) : null}
      <input type="hidden" name="mes" value={mes} readOnly />
    </div>
  )
}
