const TZ = 'America/Sao_Paulo'

export const brl = new Intl.NumberFormat('pt-BR', {
  style: 'currency',
  currency: 'BRL',
})

export function formatMoney(value) {
  const n = Number(value)
  return brl.format(Number.isFinite(n) ? n : 0)
}

export function formatSignedMoney(value, tipo) {
  const n = Math.abs(Number(value) || 0)
  const prefix = tipo === 'receita' ? '+' : tipo === 'despesa' ? '−' : ''
  return `${prefix}${brl.format(n)}`
}

export function todayISO() {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: TZ,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date())
  return parts
}

export function currentMonth() {
  return `${todayISO().slice(0, 7)}-01`
}

export function monthKey(date = new Date()) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: TZ,
    year: 'numeric',
    month: '2-digit',
  }).format(date)
}

export function addMonths(isoMonth, delta) {
  const [year, month] = isoMonth.split('-').map(Number)
  const d = new Date(Date.UTC(year, month - 1 + delta, 1))
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}-01`
}

export function formatMonth(isoMonth, opts = {}) {
  if (!isoMonth) return '—'
  const [year, month] = isoMonth.split('-').map(Number)
  const d = new Date(Date.UTC(year, month - 1, 1))
  const label = new Intl.DateTimeFormat('pt-BR', {
    month: opts.short ? 'short' : 'long',
    year: opts.hideYear ? undefined : 'numeric',
    timeZone: 'UTC',
  }).format(d)
  return label.replace('.', '').replace(/^./, (c) => c.toUpperCase())
}

export function formatMonthShort(isoMonth) {
  if (!isoMonth) return '—'
  const [year, month] = isoMonth.split('-').map(Number)
  const d = new Date(Date.UTC(year, month - 1, 1))
  return new Intl.DateTimeFormat('pt-BR', { month: 'short', timeZone: 'UTC' })
    .format(d)
    .replace('.', '')
}

export function formatDate(iso) {
  if (!iso) return '—'
  const [year, month, day] = iso.slice(0, 10).split('-').map(Number)
  const d = new Date(Date.UTC(year, month - 1, day))
  return new Intl.DateTimeFormat('pt-BR', { timeZone: 'UTC' }).format(d)
}

export function formatDateTime(iso) {
  if (!iso) return '—'
  const d = new Date(iso)
  return new Intl.DateTimeFormat('pt-BR', {
    timeZone: TZ,
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(d)
}

export function daysUntil(iso) {
  if (!iso) return null
  const today = todayISO()
  const a = Date.UTC(...today.split('-').map(Number))
  const b = Date.UTC(...iso.slice(0, 10).split('-').map(Number))
  return Math.round((b - a) / 86_400_000)
}

export function dueLabel(iso) {
  const days = daysUntil(iso)
  if (days === null) return 'Sem data'
  if (days < 0) return `Atrasada há ${Math.abs(days)} ${Math.abs(days) === 1 ? 'dia' : 'dias'}`
  if (days === 0) return 'Vence hoje'
  if (days === 1) return 'Vence amanhã'
  return `Vence em ${days} dias`
}

export function percent(value, total) {
  const t = Number(total)
  if (!t) return 0
  return Math.min(100, Math.max(0, (Number(value) / t) * 100))
}

export function initials(name = '') {
  return name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => part[0])
    .join('')
    .toUpperCase()
}

export function firstName(name = '') {
  return name.trim().split(/\s+/)[0] || ''
}

export function classNames(...values) {
  return values.filter(Boolean).join(' ')
}

export function clampNumber(value) {
  if (value == null) return 0
  let text = String(value)
    .trim()
    .replace(/R\$/gi, '')
    .replace(/\s/g, '')
  if (!text) return 0

  const commas = (text.match(/,/g) || []).length
  const dots = (text.match(/\./g) || []).length
  if (commas && dots) {
    // The last separator is the decimal one: 1.234,56 or 1,234.56.
    text =
      text.lastIndexOf(',') > text.lastIndexOf('.')
        ? text.replace(/\./g, '').replace(',', '.')
        : text.replace(/,/g, '')
  } else if (commas) {
    text = text.replace(',', '.')
  } else if (dots) {
    const parts = text.split('.')
    const isThousands = parts.slice(1).every((part) => part.length === 3)
    if (isThousands) text = parts.join('')
  }

  const n = Number(text)
  return Number.isFinite(n) ? n : 0
}

// `progresso` is a percentage in the API; `contribuicoes` carries the values.
export function goalProgress(goal = {}) {
  const target = Number(goal.valor_alvo) || 0
  if (Array.isArray(goal.contribuicoes)) {
    const contribuido = goal.contribuicoes.reduce((acc, item) => acc + (Number(item.valor) || 0), 0)
    return { contribuido, pct: percent(contribuido, target) }
  }
  const pct = Math.min(100, Math.max(0, Number(goal.progresso) || 0))
  return { contribuido: target * (pct / 100), pct }
}
