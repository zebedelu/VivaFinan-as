import { classNames, formatMoney } from '../lib/format'

export default function Money({
  value,
  tipo,
  signed = false,
  className,
  tone,
  currency = true,
}) {
  const n = Number(value) || 0
  const resolvedTone = tone || (tipo === 'receita' ? 'receita' : tipo === 'despesa' ? 'despesa' : 'neutro')
  const toneClass =
    resolvedTone === 'receita'
      ? 'text-verde-texto'
      : resolvedTone === 'despesa'
        ? 'text-terracota-texto'
        : resolvedTone === 'dourado'
          ? 'text-dourado-forte'
          : 'text-grafite'

  const text = currency ? formatMoney(Math.abs(n)) : new Intl.NumberFormat('pt-BR', { maximumFractionDigits: 2 }).format(Math.abs(n))
  const sign = signed ? (n < 0 || tipo === 'despesa' ? '−' : '+') : n < 0 ? '−' : ''

  return (
    <span className={classNames('num whitespace-nowrap', toneClass, className)}>
      {sign}
      {text}
    </span>
  )
}
