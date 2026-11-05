import { classNames } from '../lib/format'

const TONES = {
  verde: 'border-verde/30 bg-verde-claro text-verde-texto',
  terracota: 'border-terracota/30 bg-terracota/10 text-terracota-texto',
  dourado: 'border-dourado/40 bg-dourado/10 text-grafite',
  neutro: 'border-linha bg-transparent text-muted',
}

export default function Badge({ children, tone = 'neutro', className }) {
  return (
    <span
      className={classNames(
        'inline-flex items-center gap-1 rounded-full border px-2 py-0.5 text-2xs font-medium',
        TONES[tone] || TONES.neutro,
        className,
      )}
    >
      {children}
    </span>
  )
}
