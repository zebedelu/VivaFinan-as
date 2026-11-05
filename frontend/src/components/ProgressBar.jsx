import { classNames } from '../lib/format'

export default function ProgressBar({ value = 0, label, tone = 'dourado', className }) {
  const pct = Math.max(0, Math.min(100, Number(value) || 0))
  return (
    <div className={className}>
      <div
        className="h-1.5 w-full overflow-hidden rounded-full bg-linha"
        role="progressbar"
        aria-valuenow={Math.round(pct)}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-label={label || 'Progresso da meta'}
      >
        <div
          className={classNames(
            'h-full rounded-full transition-[width] duration-500',
            tone === 'verde' ? 'bg-verde' : tone === 'terracota' ? 'bg-terracota' : 'bg-dourado-forte',
          )}
          style={{ width: `${pct}%` }}
        />
      </div>
    </div>
  )
}
