import {
  CartesianGrid,
  Line,
  LineChart as ReLineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import { formatMonth, formatMonthShort, formatMoney } from '../lib/format'

function compact(value) {
  const n = Number(value) || 0
  if (Math.abs(n) >= 1000) return `${Math.round(n / 1000)}k`
  return String(Math.round(n))
}

function ChartTooltip({ active, payload, label }) {
  if (!active || !payload?.length) return null
  return (
    <div className="rounded-control border border-linha bg-superficie px-3 py-2 text-xs shadow-discreta">
      <p className="mb-1 font-medium text-grafite">{formatMonth(label)}</p>
      {payload.map((item) => (
        <p key={item.dataKey} className="num flex items-center justify-between gap-4 text-muted">
          <span>{item.name}</span>
          <span className="text-grafite">{formatMoney(item.value)}</span>
        </p>
      ))}
    </div>
  )
}

export default function LineChart({ data = [], height = 220, ariaLabel }) {
  const summary = data
    .map((row) => `${formatMonthShort(row.mes)}: receitas ${formatMoney(row.receitas)}, despesas ${formatMoney(row.despesas)}`)
    .join('; ')

  return (
    <div>
      <div className="h-[220px] w-full" role="img" aria-label={ariaLabel || `Receitas e despesas nos últimos 6 meses. ${summary}`}>
        <ResponsiveContainer width="100%" height={height}>
          <ReLineChart data={data} margin={{ top: 8, right: 8, bottom: 0, left: -8 }}>
            <CartesianGrid stroke="var(--linha)" vertical={false} />
            <XAxis
              dataKey="mes"
              tickFormatter={formatMonthShort}
              tick={{ fontSize: 11, fill: 'var(--muted)' }}
              axisLine={false}
              tickLine={false}
              dy={6}
            />
            <YAxis
              tickFormatter={compact}
              tick={{ fontSize: 11, fill: 'var(--muted)' }}
              axisLine={false}
              tickLine={false}
              width={48}
            />
            <Tooltip content={<ChartTooltip />} cursor={{ stroke: 'var(--linha)' }} />
            <Line
              type="monotone"
              dataKey="receitas"
              name="Receitas"
              stroke="var(--verde-texto)"
              strokeWidth={1.75}
              dot={false}
              activeDot={{ r: 3 }}
            />
            <Line
              type="monotone"
              dataKey="despesas"
              name="Despesas"
              stroke="var(--terracota)"
              strokeWidth={1.75}
              dot={false}
              activeDot={{ r: 3 }}
            />
          </ReLineChart>
        </ResponsiveContainer>
      </div>
      <table className="sr-only">
        <caption>Receitas e despesas nos últimos 6 meses</caption>
        <thead>
          <tr>
            <th scope="col">Mês</th>
            <th scope="col">Receitas</th>
            <th scope="col">Despesas</th>
          </tr>
        </thead>
        <tbody>
          {data.map((row) => (
            <tr key={row.mes}>
              <th scope="row">{formatMonthShort(row.mes)}</th>
              <td>{formatMoney(row.receitas)}</td>
              <td>{formatMoney(row.despesas)}</td>
            </tr>
          ))}
        </tbody>
      </table>
      <div className="mt-2 flex gap-5 text-xs text-muted">
        <span className="flex items-center gap-1.5">
          <span className="h-px w-4 bg-verde-texto" aria-hidden="true" /> Receitas
        </span>
        <span className="flex items-center gap-1.5">
          <span className="h-px w-4 bg-terracota" aria-hidden="true" /> Despesas
        </span>
      </div>
    </div>
  )
}
