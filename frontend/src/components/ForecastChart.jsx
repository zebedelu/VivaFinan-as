import {
  Bar,
  CartesianGrid,
  ComposedChart,
  Line,
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

export default function ForecastChart({ data = [], height = 260 }) {
  const summary = data
    .map((row) => `${formatMonthShort(row.mes)}: saldo ${formatMoney(row.saldo)}`)
    .join('; ')

  return (
    <div>
      <div className="h-[260px] w-full" role="img" aria-label={`Previsão de 12 meses. ${summary}`}>
        <ResponsiveContainer width="100%" height={height}>
          <ComposedChart data={data} margin={{ top: 8, right: 8, bottom: 0, left: -8 }}>
            <CartesianGrid stroke="var(--linha)" vertical={false} />
            <XAxis
              dataKey="mes"
              tickFormatter={formatMonthShort}
              tick={{ fontSize: 10, fill: 'var(--muted)' }}
              axisLine={false}
              tickLine={false}
              interval={1}
              dy={6}
            />
            <YAxis
              tickFormatter={compact}
              tick={{ fontSize: 10, fill: 'var(--muted)' }}
              axisLine={false}
              tickLine={false}
              width={46}
            />
            <Tooltip content={<ChartTooltip />} cursor={{ fill: 'var(--verde-claro)', opacity: 0.5 }} />
            <Bar dataKey="receitas" name="Receitas" fill="var(--verde-texto)" fillOpacity={0.75} radius={[2, 2, 0, 0]} maxBarSize={14} />
            <Bar dataKey="despesas" name="Despesas" fill="var(--terracota)" fillOpacity={0.75} radius={[2, 2, 0, 0]} maxBarSize={14} />
            <Line type="monotone" dataKey="saldo" name="Saldo" stroke="var(--grafite)" strokeWidth={1.5} dot={false} />
          </ComposedChart>
        </ResponsiveContainer>
      </div>
      <div className="mt-2 flex flex-wrap gap-4 text-xs text-muted">
        <span className="flex items-center gap-1.5"><span className="h-2 w-2 rounded-sm bg-verde-texto" aria-hidden="true" /> Receitas</span>
        <span className="flex items-center gap-1.5"><span className="h-2 w-2 rounded-sm bg-terracota" aria-hidden="true" /> Despesas</span>
        <span className="flex items-center gap-1.5"><span className="h-px w-4 bg-grafite" aria-hidden="true" /> Saldo</span>
      </div>
      <table className="sr-only">
        <caption>Previsão mês a mês</caption>
        <thead>
          <tr>
            <th scope="col">Mês</th>
            <th scope="col">Receitas</th>
            <th scope="col">Despesas</th>
            <th scope="col">Saldo</th>
          </tr>
        </thead>
        <tbody>
          {data.map((row) => (
            <tr key={row.mes}>
              <th scope="row">{formatMonthShort(row.mes)}</th>
              <td>{formatMoney(row.receitas)}</td>
              <td>{formatMoney(row.despesas)}</td>
              <td>{formatMoney(row.saldo)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
