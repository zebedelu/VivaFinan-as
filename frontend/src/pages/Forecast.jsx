import { useState } from 'react'
import { Info } from 'lucide-react'
import Badge from '../components/Badge'
import ForecastChart from '../components/ForecastChart'
import { Loading } from '../components/Loading'
import Money from '../components/Money'
import SegmentedControl from '../components/SegmentedControl'
import Section from '../components/Section'
import { ErrorState, UnavailableState } from '../components/StatePanels'
import { useApi } from '../hooks/useApi'
import { formatMonth, formatMoney } from '../lib/format'

function DetailList({ detalhes }) {
  if (!detalhes) return null
  if (Array.isArray(detalhes)) {
    return (
      <ul className="space-y-1">
        {detalhes.map((item, index) => (
          <li key={item.id || index} className="flex justify-between gap-3 text-xs">
            <span>{item.categoria || item.descricao || item.nome || 'Item'}</span>
            <span className="num">{formatMoney(item.valor ?? item.total ?? 0)}</span>
          </li>
        ))}
      </ul>
    )
  }
  return (
    <ul className="space-y-1">
      {Object.entries(detalhes).map(([key, value]) => (
        <li key={key} className="flex justify-between gap-3 text-xs">
          <span className="capitalize">{key.replaceAll('_', ' ')}</span>
          <span className="num">{typeof value === 'number' ? formatMoney(value) : String(value)}</span>
        </li>
      ))}
    </ul>
  )
}

export default function Forecast() {
  const [escopo, setEscopo] = useState('familia')
  const { data, loading, error, refetch } = useApi(`/forecast?meses=12&escopo=${escopo}`)

  const meses = data?.meses || []
  const anual = data?.anual || {
    receitas: meses.reduce((acc, row) => acc + (Number(row.receitas) || 0), 0),
    despesas: meses.reduce((acc, row) => acc + (Number(row.despesas) || 0), 0),
    saldo: meses.reduce((acc, row) => acc + (Number(row.saldo) || 0), 0),
  }

  return (
    <div>
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="text-sm text-muted">Previsões</p>
          <h1 className="mt-1 font-display text-3xl">Os próximos doze meses</h1>
          <p className="mt-2 max-w-xl text-sm text-muted">
            Uma estimativa para planejar, não uma promessa. Contas pendentes de confirmação ficam de
            fora.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Badge tone="dourado">Estimativa</Badge>
          <SegmentedControl
            label="Escopo da previsão"
            value={escopo}
            onChange={setEscopo}
            options={[
              { value: 'familia', label: 'Família' },
              { value: 'pessoal', label: 'Pessoal' },
            ]}
          />
        </div>
      </div>

      {loading ? <Loading label="Calculando a previsão" rows={4} /> : null}

      {error?.status === 503 ? (
        <div className="mt-6">
          <UnavailableState
            title="Previsão indisponível"
            description="O servidor não conseguiu calcular a projeção agora."
            onRetry={refetch}
          />
        </div>
      ) : null}

      {error && error.status !== 503 ? (
        <div className="mt-6">
          <ErrorState error={error} onRetry={refetch} />
        </div>
      ) : null}

      {!loading && !error ? (
        <>
          <section className="mt-8 grid gap-6 border-y border-linha py-6 sm:grid-cols-3">
            <div>
              <p className="text-xs text-muted">Saldo previsto no ano</p>
              <p className={`num mt-1 font-display text-[2.2rem] leading-tight ${Number(anual.saldo) < 0 ? 'text-terracota-texto' : 'text-grafite'}`}>
                {formatMoney(anual.saldo)}
              </p>
            </div>
            <div>
              <p className="text-xs text-muted">Receitas estimadas</p>
              <Money value={anual.receitas} tipo="receita" className="mt-1 block font-display text-[2.2rem] leading-tight" />
            </div>
            <div>
              <p className="text-xs text-muted">Despesas estimadas</p>
              <Money value={anual.despesas} tipo="despesa" className="mt-1 block font-display text-[2.2rem] leading-tight" />
            </div>
          </section>

          <Section id="grafico-previsao" title="Mês a mês" description="Barras para receitas e despesas; a linha mostra o saldo." className="mt-8">
            {meses.length ? (
              <ForecastChart data={meses} />
            ) : (
              <p className="py-6 text-sm text-muted">Ainda não há dados suficientes para projetar.</p>
            )}
          </Section>

          <Section id="detalhe-previsao" title="Detalhamento" description="Abra um mês para ver de onde vem a estimativa." className="mt-10">
            <ul className="border-t border-linha">
              {meses.map((row) => (
                <li key={row.mes} className="border-b border-linha">
                  <details className="group">
                    <summary className="flex cursor-pointer list-none flex-wrap items-center justify-between gap-3 py-3.5">
                      <span className="text-sm">{formatMonth(row.mes)}</span>
                      <span className="flex items-center gap-4 text-xs text-muted">
                        <span className="num text-verde-texto">+{formatMoney(row.receitas)}</span>
                        <span className="num text-terracota-texto">−{formatMoney(row.despesas)}</span>
                        <span className={`num w-24 text-right ${Number(row.saldo) < 0 ? 'text-terracota-texto' : 'text-grafite'}`}>
                          {formatMoney(row.saldo)}
                        </span>
                      </span>
                    </summary>
                    <div className="grid gap-4 pb-4 sm:grid-cols-2">
                      <div className="text-xs text-muted">
                        <p className="mb-1 font-medium text-grafite">Receitas</p>
                        <p className="flex justify-between gap-3">
                          <span>Recorrentes confirmadas</span>
                          <span className="num">{formatMoney(row.recorrentes_receitas ?? 0)}</span>
                        </p>
                        <p className="flex justify-between gap-3">
                          <span>Média do que varia</span>
                          <span className="num">{formatMoney(row.variavel_receitas ?? 0)}</span>
                        </p>
                      </div>
                      <div className="text-xs text-muted">
                        <p className="mb-1 font-medium text-grafite">Despesas</p>
                        <p className="flex justify-between gap-3">
                          <span>Recorrentes confirmadas</span>
                          <span className="num">{formatMoney(row.recorrentes_despesas ?? 0)}</span>
                        </p>
                        <p className="flex justify-between gap-3">
                          <span>Média do que varia</span>
                          <span className="num">{formatMoney(row.variavel_despesas ?? 0)}</span>
                        </p>
                      </div>
                      {row.detalhes ? (
                        <div className="sm:col-span-2">
                          <p className="mb-1 text-xs font-medium">Itens considerados</p>
                          <DetailList detalhes={row.detalhes} />
                        </div>
                      ) : null}
                    </div>
                  </details>
                </li>
              ))}
            </ul>
          </Section>

          <div className="mt-8 flex gap-3 rounded-card border border-linha p-4 text-xs text-muted">
            <Info size={15} className="mt-0.5 shrink-0 text-verde-texto" aria-hidden="true" />
            <p>
              Como calculamos: somamos as contas recorrentes ativas confirmadas nos últimos seis meses
              (ou o valor da regra) e a média dos três meses completos anteriores para o que varia. O
              mês corrente fica fora porque ainda está em andamento. Todos os valores são estimativas.
            </p>
          </div>
        </>
      ) : null}
    </div>
  )
}
