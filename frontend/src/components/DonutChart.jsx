import { Cell, Pie, PieChart, ResponsiveContainer, Tooltip } from 'recharts'
import { formatMoney, percent } from '../lib/format'

const COLORS = [
  'var(--verde-texto)',
  'var(--terracota)',
  'var(--dourado-forte)',
  '#6E7F63',
  '#9C6B52',
  '#8A8468',
  '#4C6B5A',
  '#B08A5E',
  '#7B5C4B',
  '#A9A08F',
]

function ChartTooltip({ active, payload }) {
  if (!active || !payload?.length) return null
  const item = payload[0]
  return (
    <div className="rounded-control border border-linha bg-superficie px-3 py-2 text-xs shadow-discreta">
      <p className="font-medium text-grafite">{item.name}</p>
      <p className="num text-muted">{formatMoney(item.value)}</p>
    </div>
  )
}

export default function DonutChart({ data = [], total, ariaLabel }) {
  const sum = total ?? data.reduce((acc, row) => acc + (Number(row.total) || 0), 0)
  const summary = data
    .slice(0, 6)
    .map((row) => `${row.categoria}: ${formatMoney(row.total)}`)
    .join('; ')

  return (
    <div className="grid items-center gap-4 sm:grid-cols-[minmax(0,180px)_1fr]">
      <div
        className="relative mx-auto h-[180px] w-[180px]"
        role="img"
        aria-label={ariaLabel || `Despesas por categoria. ${summary}`}
      >
        <ResponsiveContainer width="100%" height="100%">
          <PieChart>
            <Pie
              data={data}
              dataKey="total"
              nameKey="categoria"
              innerRadius={54}
              outerRadius={82}
              paddingAngle={1.5}
              stroke="var(--superficie)"
              strokeWidth={2}
              isAnimationActive={false}
            >
              {data.map((entry, index) => (
                <Cell key={entry.category_id || entry.categoria} fill={COLORS[index % COLORS.length]} />
              ))}
            </Pie>
            <Tooltip content={<ChartTooltip />} />
          </PieChart>
        </ResponsiveContainer>
        <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center text-center">
          <span className="text-2xs text-muted">Despesas</span>
          <span className="num font-display text-lg">{formatMoney(sum)}</span>
        </div>
      </div>
      <ul className="space-y-0">
        {data.map((row, index) => (
          <li key={row.category_id || row.categoria} className="stat-line py-2">
            <span className="flex min-w-0 items-center gap-2 text-sm">
              <span
                className="h-2 w-2 shrink-0 rounded-full"
                style={{ background: COLORS[index % COLORS.length] }}
                aria-hidden="true"
              />
              <span className="truncate">{row.categoria}</span>
            </span>
            <span className="num shrink-0 text-sm text-muted">
              {Math.round(percent(row.total, sum))}%
            </span>
          </li>
        ))}
      </ul>
    </div>
  )
}
