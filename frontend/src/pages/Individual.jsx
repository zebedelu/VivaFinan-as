import { useState } from 'react'
import { Link } from 'react-router-dom'
import { Landmark, Target } from 'lucide-react'
import AlertList from '../components/AlertList'
import DonutChart from '../components/DonutChart'
import EmptyState from '../components/EmptyState'
import { Loading } from '../components/Loading'
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
import { firstName, formatDateTime, formatMoney, goalProgress } from '../lib/format'
import { apiFetch, errorMessage } from '../services/api'

export default function Individual() {
  const { mes, label, prev, next, setMes, isCurrent } = useMonth()
  const { profile, family } = useSession()
  const summary = useApi(`/me/summary?mes=${mes}`)
  const toast = useToast()
  const [busyPending, setBusyPending] = useState(null)

  if (summary.loading) {
    return (
      <div>
        <p className="text-sm text-muted">Meu espaço</p>
        <h1 className="mt-1 font-display text-3xl">Olá, {firstName(profile?.nome) || 'você'}!</h1>
        <Loading label="Somando seus números" rows={4} />
      </div>
    )
  }

  if (summary.error?.status === 503) {
    return (
      <div>
        <h1 className="font-display text-3xl">Olá, {firstName(profile?.nome) || 'você'}!</h1>
        <div className="mt-6">
          <UnavailableState
            title="Seu resumo está indisponível"
            description="O servidor não conseguiu somar o seu mês agora. Tente de novo em instantes."
            onRetry={summary.refetch}
          />
        </div>
      </div>
    )
  }

  if (summary.error) {
    return (
      <div>
        <h1 className="font-display text-3xl">Olá, {firstName(profile?.nome) || 'você'}!</h1>
        <div className="mt-6">
          <ErrorState error={summary.error} onRetry={summary.refetch} />
        </div>
      </div>
    )
  }

  const data = summary.data || {}
  const totais = data.totais || { receitas: 0, despesas: 0, saldo: 0 }
  const categorias = data.categorias || []
  const metas = data.metas || []
  const pendentes = data.recorrentes_pendentes || []
  const sugestoes = data.sugestoes || []
  const banco = data.banco || { conexoes: 0, pendentes: 0, ultima_sync: null }
  const alertas = data.alertas || []
  const saldo = Number(totais.saldo) || 0

  async function confirmPending(occurrence, custom) {
    if (custom) return
    const id = occurrence.occurrence_id || occurrence.id
    setBusyPending(id)
    try {
      await apiFetch(`/recurring/occurrences/${id}/confirm`, { method: 'POST', body: {} })
      toast.push('Conta confirmada no seu mês.')
      summary.refetch()
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
      summary.refetch()
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
          <p className="text-sm text-muted">{family?.nome || 'Sua família'}</p>
          <h1 className="mt-1 font-display text-4xl leading-tight sm:text-5xl">
            Olá, {firstName(profile?.nome) || 'você'}!
          </h1>
          <p className="mt-2 max-w-md text-sm text-muted">
            Aqui ficam só os seus números. Ninguém mais na família vê este detalhe.
          </p>
        </div>
        <MonthPicker mes={mes} label={label} onPrev={prev} onNext={next} onToday={() => setMes(null)} isCurrent={isCurrent} />
      </div>

      <section className="mt-8 grid gap-8 border-t border-linha pt-8 lg:grid-cols-[1.3fr_1fr] lg:gap-14">
        <div>
          <p className="text-sm text-muted">Seu saldo no mês</p>
          <p className={`num mt-1 font-display text-[3rem] leading-[0.98] sm:text-[3.8rem] ${saldo < 0 ? 'text-terracota-texto' : 'text-grafite'}`}>
            {formatMoney(saldo)}
          </p>
          <div className="mt-4 flex flex-wrap gap-x-5 gap-y-2 text-sm">
            <span>
              <span className="text-muted">Receitas </span>
              <Money value={totais.receitas} tipo="receita" className="font-medium" />
            </span>
            <span className="text-linha" aria-hidden="true">|</span>
            <span>
              <span className="text-muted">Despesas </span>
              <Money value={totais.despesas} tipo="despesa" className="font-medium" />
            </span>
          </div>
        </div>

        <div className="rounded-card border border-linha bg-superficie p-4">
          <div className="flex items-center gap-2 text-sm font-medium">
            <Landmark size={16} className="text-muted" aria-hidden="true" />
            Seu banco
          </div>
          <div className="mt-2 space-y-1.5 text-sm">
            <p className="flex justify-between gap-3">
              <span className="text-muted">Contas conectadas</span>
              <span className="num">{banco.conexoes ?? 0}</span>
            </p>
            <p className="flex justify-between gap-3">
              <span className="text-muted">Para importar</span>
              <span className="num">{banco.pendentes ?? 0}</span>
            </p>
            <p className="flex justify-between gap-3">
              <span className="text-muted">Última sincronização</span>
              <span className="num text-xs">{banco.ultima_sync ? formatDateTime(banco.ultima_sync) : 'Ainda não'}</span>
            </p>
          </div>
          <Link to="/banking" className="mt-3 inline-flex items-center gap-1 text-xs text-verde-texto">
            Abrir extrato
          </Link>
        </div>
      </section>

      <div className="mt-10 grid gap-10 lg:grid-cols-2">
        <Section id="pessoais-categorias" title="Onde seu dinheiro foi" description="Categorias do seu mês.">
          {categorias.length ? (
            <DonutChart data={categorias} ariaLabel="Suas despesas por categoria neste mês" />
          ) : (
            <EmptyState title="Sem despesas pessoais neste mês" description="Seus gastos aparecem aqui conforme você registra." />
          )}
        </Section>

        <Section
          id="pessoais-metas"
          title="Suas metas"
          action={
            <Link to="/goals" className="text-sm link-quiet">
              Ver metas
            </Link>
          }
        >
          {metas.length ? (
            <ul>
              {metas.map((meta) => {
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
            <EmptyState title="Nenhuma meta pessoal" description="Metas pessoais não aparecem para o resto da família." />
          )}
        </Section>
      </div>

      <Section
        id="pessoais-recorrentes"
        title="Suas contas a confirmar"
        description="Só as regras pessoais. As da família ficam no painel."
        className="mt-10"
      >
        {pendentes.length ? (
          <div>
            {pendentes.map((occurrence) => (
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
          <p className="py-4 text-sm text-muted">Nada vencendo no seu nome agora.</p>
        )}
      </Section>

      <div className="mt-10 grid gap-10 lg:grid-cols-[1.1fr_0.9fr]">
        <Section id="pessoais-sugestoes" title="Sugestões para você" description="Baseadas só nas suas transações e metas.">
          {sugestoes.length ? (
            <div>
              {sugestoes.map((suggestion) => (
                <SuggestionCard key={suggestion.id} suggestion={suggestion} />
              ))}
            </div>
          ) : (
            <p className="py-4 text-sm text-muted">
              A Jev ainda não tem sugestões pessoais. Converse com ela para pedir uma análise.
            </p>
          )}
        </Section>

        <Section id="pessoais-alertas" title="Seus alertas">
          <AlertList alerts={alertas} compact />
        </Section>
      </div>
    </div>
  )
}
