import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Landmark, Sparkles, Target } from 'lucide-react'
import AlertList from '../components/AlertList'
import DonutChart from '../components/DonutChart'
import EmptyState from '../components/EmptyState'
import LineChart from '../components/LineChart'
import { Loading } from '../components/Loading'
import MemberAvatars from '../components/MemberAvatars'
import Money from '../components/Money'
import MonthPicker from '../components/MonthPicker'
import ProgressBar from '../components/ProgressBar'
import RecurringCard from '../components/RecurringCard'
import Section from '../components/Section'
import SuggestionCard from '../components/SuggestionCard'
import { ErrorState, UnavailableState } from '../components/StatePanels'
import { useToast } from '../components/Toast'
import { useApi } from '../hooks/useApi'
import { useMonth } from '../hooks/useMonth'
import { useSession } from '../hooks/useSession'
import { formatMoney, goalProgress } from '../lib/format'
import { apiFetch, errorMessage } from '../services/api'

export default function Dashboard() {
  const { mes, label, prev, next, setMes, isCurrent } = useMonth()
  const { profile, family } = useSession()
  const { data, loading, error, refetch } = useApi(`/dashboard?mes=${mes}`)
  const navigate = useNavigate()
  const toast = useToast()
  const [busyPending, setBusyPending] = useState(null)

  if (loading) {
    return (
      <div>
        <div className="flex items-end justify-between">
          <div>
            <p className="text-sm text-muted">Painel da família</p>
            <h1 className="mt-1 font-display text-3xl">{family?.nome || 'Sua família'}</h1>
          </div>
          <MonthPicker mes={mes} label={label} onPrev={prev} onNext={next} onToday={() => setMes(null)} isCurrent={isCurrent} />
        </div>
        <Loading label="Calculando o mês" rows={5} />
      </div>
    )
  }

  if (error?.status === 503) {
    return (
      <div>
        <h1 className="font-display text-3xl">{family?.nome || 'Painel da família'}</h1>
        <div className="mt-6">
          <UnavailableState
            title="Painel indisponível"
            description="O servidor não conseguiu montar o mês agora. Seus lançamentos continuam guardados."
            onRetry={refetch}
          />
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div>
        <h1 className="font-display text-3xl">{family?.nome || 'Painel da família'}</h1>
        <div className="mt-6">
          <ErrorState error={error} onRetry={refetch} />
        </div>
      </div>
    )
  }

  const totais = data?.totais || { receitas: 0, despesas: 0, saldo: 0 }
  const acumulado = data?.acumulado || { receitas: 0, despesas: 0 }
  const categorias = data?.categorias || []
  const serie = data?.serie || []
  const metas = data?.metas || []
  const sugestoes = data?.sugestoes || []
  const alertas = data?.alertas || []
  const pendentes = data?.recorrentes_pendentes || []
  const membros = data?.membros || []
  const banco = data?.banco || { conexoes_ativas: 0, pendentes: 0 }
  const saldo = Number(totais.saldo) || 0

  async function confirmPending(occurrence, custom) {
    if (custom) {
      navigate('/recurring')
      return
    }
    const id = occurrence.occurrence_id || occurrence.id
    setBusyPending(id)
    try {
      await apiFetch(`/recurring/occurrences/${id}/confirm`, { method: 'POST', body: {} })
      toast.push('Conta confirmada. O lançamento já está em Lançamentos.')
      refetch()
    } catch (err) {
      toast.push(errorMessage(err, 'Não foi possível confirmar a conta.'), 'error')
    } finally {
      setBusyPending(null)
    }
  }

  async function ignorePending(occurrence) {
    const id = occurrence.occurrence_id || occurrence.id
    setBusyPending(id)
    try {
      await apiFetch(`/recurring/occurrences/${id}/ignore`, { method: 'POST' })
      toast.push('Conta ignorada neste mês.')
      refetch()
    } catch (err) {
      toast.push(errorMessage(err, 'Não foi possível ignorar a conta.'), 'error')
    } finally {
      setBusyPending(null)
    }
  }

  return (
    <div>
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="text-sm text-muted">Painel da família</p>
          <h1 className="mt-1 font-display text-3xl leading-tight">{family?.nome || 'Sua família'}</h1>
          <div className="mt-3">
            <MemberAvatars members={membros} currentId={profile?.id} />
          </div>
        </div>
        <MonthPicker mes={mes} label={label} onPrev={prev} onNext={next} onToday={() => setMes(null)} isCurrent={isCurrent} />
      </div>

      <section className="mt-8 grid gap-8 border-t border-linha pt-8 lg:grid-cols-[1.35fr_1fr] lg:gap-14">
        <div>
          <p className="text-sm text-muted">Saldo do mês</p>
          <p
            className={`num mt-1 font-display text-[3.4rem] leading-[0.95] tracking-tight sm:text-[4.4rem] ${
              saldo < 0 ? 'text-terracota-texto' : 'text-grafite'
            }`}
          >
            {formatMoney(saldo)}
          </p>
          <p className="mt-3 max-w-md text-sm text-muted">
            Receitas menos despesas do mês. Contas recorrentes ainda não confirmadas ficam fora da
            conta.
          </p>
          <div className="mt-5 flex flex-wrap items-center gap-x-5 gap-y-2 text-sm">
            <span>
              <span className="text-muted">Entraram </span>
              <Money value={totais.receitas} tipo="receita" className="font-medium" />
            </span>
            <span className="text-linha" aria-hidden="true">|</span>
            <span>
              <span className="text-muted">Saíram </span>
              <Money value={totais.despesas} tipo="despesa" className="font-medium" />
            </span>
          </div>

          <div className="mt-6 flex flex-wrap items-center gap-4 border-t border-linha pt-4 text-sm">
            <button
              type="button"
              onClick={() => navigate('/banking')}
              className="inline-flex items-center gap-2 text-left text-verde-texto"
            >
              <Landmark size={16} aria-hidden="true" />
              {banco.conexoes_ativas > 0
                ? `${banco.conexoes_ativas} ${banco.conexoes_ativas === 1 ? 'conta conectada' : 'contas conectadas'}`
                : 'Nenhuma conta conectada'}
            </button>
            {banco.pendentes > 0 ? (
              <span className="text-xs text-muted">{banco.pendentes} transações para importar</span>
            ) : null}
          </div>
          {banco.conexoes_ativas === 0 ? (
            <p className="mt-2 max-w-sm text-xs text-muted">
              Conecte um banco para ver o extrato aqui. A família funciona inteira sem isso.
            </p>
          ) : null}
        </div>

        <div className="lg:border-l lg:border-linha lg:pl-10">
          <p className="text-sm text-muted">Acumulado em 6 meses</p>
          <div className="mt-2">
            <div className="stat-line">
              <span className="text-sm">Receitas</span>
              <Money value={acumulado.receitas} tipo="receita" className="font-display text-2xl" />
            </div>
            <div className="stat-line">
              <span className="text-sm">Despesas</span>
              <Money value={acumulado.despesas} tipo="despesa" className="font-display text-2xl" />
            </div>
            <div className="stat-line">
              <span className="text-sm">Sobra no período</span>
              <Money
                value={(Number(acumulado.receitas) || 0) - (Number(acumulado.despesas) || 0)}
                className="font-display text-2xl"
              />
            </div>
          </div>
        </div>
      </section>

      <Section
        id="serie"
        title="Receitas x despesas"
        description="Últimos 6 meses, incluindo o atual."
        className="mt-10"
      >
        {serie.length ? (
          <LineChart data={serie} ariaLabel="Receitas e despesas nos últimos 6 meses" />
        ) : (
          <p className="py-6 text-sm text-muted">Ainda não há histórico suficiente para o gráfico.</p>
        )}
      </Section>

      <div className="mt-10 grid gap-10 lg:grid-cols-[1fr_1fr]">
        <Section id="categorias" title="Despesas por categoria" description="Somente o mês atual.">
          {categorias.length ? (
            <DonutChart data={categorias} />
          ) : (
            <EmptyState
              title="Sem despesas neste mês"
              description="Quando houver gastos, a distribuição por categoria aparece aqui."
            />
          )}
        </Section>

        <Section
          id="metas"
          title="Metas da família"
          action={
            <button type="button" onClick={() => navigate('/goals')} className="text-sm link-quiet">
              Ver metas
            </button>
          }
        >
          {metas.length ? (
            <ul>
              {metas.slice(0, 3).map((meta) => {
                const { contribuido, pct } = goalProgress(meta)
                return (
                  <li key={meta.id} className="border-b border-linha py-3.5 last:border-b-0">
                    <div className="flex items-baseline justify-between gap-3">
                      <span className="flex items-center gap-2 text-sm font-medium">
                        <Target size={14} className="text-dourado-forte" aria-hidden="true" />
                        {meta.titulo}
                      </span>
                      <span className="num text-xs text-muted">
                        {formatMoney(contribuido)} de {formatMoney(meta.valor_alvo)}
                      </span>
                    </div>
                    <ProgressBar value={pct} className="mt-2" label={`Progresso da meta ${meta.titulo}`} />
                  </li>
                )
              })}
            </ul>
          ) : (
            <EmptyState
              title="Nenhuma meta ainda"
              description="Uma viagem, uma reserva, a troca do carro. Metas dão direção ao mês."
              action={
                <button type="button" onClick={() => navigate('/goals')} className="btn-secondary">
                  Criar meta
                </button>
              }
            />
          )}
        </Section>
      </div>

      <Section
        id="pendentes"
        title="Contas a confirmar"
        description="Vencem nos próximos dias ou já passaram. Confirmar cria o lançamento; ignorar fecha o mês sem ele."
        className="mt-10"
        action={
          <button type="button" onClick={() => navigate('/recurring')} className="text-sm link-quiet">
            Ver todas
          </button>
        }
      >
        {pendentes.length ? (
          <div>
            {pendentes.slice(0, 4).map((occurrence) => (
              <RecurringCard
                key={occurrence.occurrence_id || occurrence.id}
                occurrence={occurrence}
                onConfirm={confirmPending}
                onIgnore={ignorePending}
                busy={busyPending === (occurrence.occurrence_id || occurrence.id)}
                allowCustomValue={false}
              />
            ))}
          </div>
        ) : (
          <p className="py-4 text-sm text-muted">
            Nada vencendo agora. Contas recorrentes aparecem aqui três dias antes do vencimento.
          </p>
        )}
      </Section>

      <div className="mt-10 grid gap-10 lg:grid-cols-[1.1fr_0.9fr]">
        <Section
          id="sugestoes"
          title="Sugestões da Jev"
          description="Sempre com o que fazer, por quê e quanto."
          action={
            <button type="button" onClick={() => navigate('/ai')} className="text-sm link-quiet">
              Conversar
            </button>
          }
        >
          {sugestoes.length ? (
            <div>
              {sugestoes.slice(0, 3).map((suggestion) => (
                <SuggestionCard key={suggestion.id} suggestion={suggestion} />
              ))}
            </div>
          ) : (
            <EmptyState
              icon={Sparkles}
              title="A Jev ainda está observando"
              description="Quando houver padrão suficiente, as sugestões aparecem aqui e no seu espaço."
              action={
                <button type="button" onClick={() => navigate('/ai')} className="btn-secondary">
                  Abrir a Jev
                </button>
              }
            />
          )}
        </Section>

        <Section id="alertas" title="Alertas do dia">
          <AlertList alerts={alertas} compact />
        </Section>
      </div>
    </div>
  )
}
