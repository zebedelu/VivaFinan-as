import { classNames } from '../lib/format'

export default function SegmentedControl({ options, value, onChange, label, className }) {
  return (
    <div
      className={classNames('inline-flex rounded-control border border-linha p-0.5', className)}
      role="group"
      aria-label={label}
    >
      {options.map((option) => {
        const active = option.value === value
        return (
          <button
            key={option.value}
            type="button"
            onClick={() => onChange(option.value)}
            aria-pressed={active}
            className={classNames(
              'rounded-[6px] px-3 py-1.5 text-xs font-medium transition-colors',
              active ? 'bg-verde text-sobre-verde' : 'text-muted hover:text-grafite',
            )}
          >
            {option.label}
          </button>
        )
      })}
    </div>
  )
}
