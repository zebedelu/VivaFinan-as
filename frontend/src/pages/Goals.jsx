import { useMemo, useState } from 'react'
import { Plus, Target } from 'lucide-react'
import Button from '../components/Button'
import EmptyState from '../components/EmptyState'
import { Field, Input, Textarea } from '../components/FormField'
import GoalCard from '../components/GoalCard'
import { Loading } from '../components/Loading'
import Modal from '../components/Modal'
import SegmentedControl from '../components/SegmentedControl'
import { ErrorState } from '../components/StatePanels'
import { useToast } from '../components/Toast'
import { useApi } from '../hooks/useApi'
import { useSession } from '../hooks/useSession'
import { clampNumber, formatMoney, todayISO } from '../lib/format'
import { apiFetch, errorMessage } from '../services/api'

function asList(data, key) {
  if (Array.isArray(data)) return data
  return data?.[key] || data?.items || []
}

function GoalForm({ goal, escopo, memberId, onClose, onSaved }) {
  const toast = useToast()
  const [form, setForm] = useState(() => ({
    titulo: goal?.titulo || '',
    valor_alvo: goal?.valor_alvo != null ? String(goal.valor_alvo) : '',
    prazo: goal?.prazo?.slice(0, 10) || '',
    descricao: goal?.descricao || '',
  }))
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)

  function update(field) {
    return (event) => setForm((current) => ({ ...current, [field]: event.target.value }))
  }

  async function submit(event) {
    event.preventDefault()
    setError('')
    const valor = clampNumber(form.valor_alvo)
    if (!form.titulo.trim()) {
      setError('Dê um nome para a meta.')
      return
    }
    if (!(valor > 0)) {
      setError('O valor-alvo precisa ser maior que zero.')
      return
    }
    const body = {
      titulo: form.titulo.trim(),
      valor_alvo: valor,
      prazo: form.prazo || null,
      descricao: form.descricao.trim() || null,
    }
    if (!goal) body.member_id = escopo === 'pessoal' ? memberId : null

    setBusy(true)
    try {
      if (goal) {
        await apiFetch(`/goals/${goal.id}`, { method: 'PATCH', body })
        toast.push('Meta atualizada.')
      } else {
        await apiFetch('/goals', { method: 'POST', body })
        toast.push('Meta criada.')
      }
      onSaved()
    } catch (err) {
      setError(errorMessage(err, 'Não foi possível salvar a meta.'))
    } finally {
      setBusy(false)
    }
  }

  return (
    <form onSubmit={submit} className="space-y-4" noValidate>
      <Field label="Título" htmlFor="goal-titulo">
        <Input
          id="goal-titulo"
          value={form.titulo}
          onChange={update('titulo')}
          placeholder="Reserva de emergência"
          required
        />
      </Field>

      <div className="grid grid-cols-2 gap-3">
        <Field label="Valor-alvo" htmlFor="goal-valor">
          <Input
            id="goal-valor"
            inputMode="decimal"
            value={form.valor_alvo}
            onChange={update('valor_alvo')}
            placeholder="0,00"
            required
          />
        </Field>
        <Field label="Prazo" htmlFor="goal-prazo" hint="Opcional.">
          <Input id="goal-prazo" type="date" value={form.prazo} onChange={update('prazo')} />
        </Field>
      </div>

      <Field label="Descrição" htmlFor="goal-descricao" hint="Opcional. Ajuda a lembrar por que a meta existe.">
        <Textarea
          id="goal-descricao"
          value={form.descricao}
          onChange={update('descricao')}
          placeholder="Seis meses de contas guardados."
        />
      </Field>

      <p className="text-xs text-muted">
        {goal
          ? 'O progresso vem das contribuições. Ninguém edita o valor já contribuído.'
          : escopo === 'pessoal'
            ? 'Meta pessoal: só você vê o progresso e as contribuições.'
            : 'Meta da família: todos veem o progresso e quem contribuiu com quanto.'}
      </p>

      {error ? (
        <p className="rounded-control border border-terracota/30 bg-terracota/5 px-3 py-2 text-sm text-terracota-texto" role="alert">
          {error}
        </p>
      ) : null}

      <div className="flex justify-end gap-2 pt-2">
        <Button variant="secondary" onClick={onClose}>
          Cancelar
        </Button>
        <Button type="submit" loading={busy}>
          {goal ? 'Salvar meta' : 'Criar meta'}
        </Button>
      </div>
    </form>
  )
}

function ContributionForm({ goal, onClose, onSaved }) {
  const toast = useToast()
  const [valor, setValor] = useState('')
  const [data, setData] = useState(todayISO())
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)

  async function submit(event) {
    event.preventDefault()
    setError('')
    const parsed = clampNumber(valor)
    if (!(parsed > 0)) {
      setError('Informe um valor maior que zero.')
      return
    }
    setBusy(true)
    try {
      await apiFetch(`/goals/${goal.id}/contributions`, {
        method: 'POST',
        body: { valor: parsed, data },
      })
      toast.push('Contribuição registrada.')
      onSaved()
    } catch (err) {
      setError(errorMessage(err, 'Não foi possível registrar a contribuição.'))
    } finally {
      setBusy(false)
    }
  }

  return (
    <form onSubmit={submit} className="space-y-4" noValidate>
      <div className="border-l-2 border-dourado pl-3">
        <p className="font-display text-lg">{goal.titulo}</p>
        <p className="text-xs text-muted">Valor-alvo de {formatMoney(goal.valor_alvo)}</p>
      </div>
      <div className="grid gap-4 sm:grid-cols-2">
        <Field label="Valor" htmlFor="contrib-valor">
          <Input
            id="contrib-valor"
            inputMode="decimal"
            value={valor}
            onChange={(event) => setValor(event.target.value)}
            placeholder="0,00"
            required
          />
        </Field>
        <Field label="Data" htmlFor="contrib-data">
          <Input
            id="contrib-data"
            type="date"
            value={data}
            onChange={(event) => setData(event.target.value)}
            required
          />
        </Field>
      </div>
      {error ? (
        <p className="text-sm text-terracota-texto" role="alert">
          {error}
        </p>
      ) : null}
      <div className="flex justify-end gap-2">
        <Button variant="secondary" onClick={onClose}>
          Cancelar
        </Button>
        <Button type="submit" loading={busy}>
          Contribuir
        </Button>
      </div>
    </form>
  )
}

export default function Goals() {
  const { profile } = useSession()
  const toast = useToast()
  const [escopo, setEscopo] = useState('familia')
  const goals = useApi(`/goals?escopo=${escopo}`)
  const [goalModal, setGoalModal] = useState({ open: false, goal: null })
  const [contributing, setContributing] = useState(null)
  const [deleting, setDeleting] = useState(null)
  const [busyId, setBusyId] = useState(null)

  const items = useMemo(() => asList(goals.data, 'goals'), [goals.data])
  const totalSaved = items.reduce((acc, goal) => {
    const saved = (goal.contribuicoes || []).reduce((sum, item) => sum + (Number(item.valor) || 0), 0)
    return acc + saved
  }, 0)

  async function remove() {
    if (!deleting) return
    setBusyId(deleting.id)
    try {
      await apiFetch(`/goals/${deleting.id}`, { method: 'DELETE' })
      toast.push('Meta excluída.')
      setDeleting(null)
      goals.refetch()
    } catch (err) {
      toast.push(errorMessage(err, 'Não foi possível excluir a meta.'), 'error')
    } finally {
      setBusyId(null)
    }
  }

  return (
    <div>
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="text-sm text-muted">Metas</p>
          <h1 className="mt-1 font-display text-3xl">Para onde o dinheiro vai</h1>
          <p className="mt-2 max-w-lg text-sm text-muted">
            Uma meta não muda o saldo do mês. Ela mostra o que a família está construindo junto.
          </p>
        </div>
        <Button onClick={() => setGoalModal({ open: true, goal: null })}>
          <Plus size={16} aria-hidden="true" /> Nova meta
        </Button>
      </div>

      <div className="mt-6 flex flex-wrap items-center justify-between gap-3 border-y border-linha py-3">
        <SegmentedControl
          label="Escopo das metas"
          value={escopo}
          onChange={setEscopo}
          options={[
            { value: 'familia', label: 'Da família' },
            { value: 'pessoal', label: 'Minhas' },
          ]}
        />
        {!goals.loading && !goals.error ? (
          <p className="text-xs text-muted">
            {items.length} {items.length === 1 ? 'meta' : 'metas'} ·{' '}
            <span className="num">{formatMoney(totalSaved)}</span> guardados
          </p>
        ) : null}
      </div>

      {goals.loading ? <Loading label="Carregando metas" rows={3} /> : null}
      {goals.error ? <ErrorState error={goals.error} onRetry={goals.refetch} /> : null}

      {!goals.loading && !goals.error ? (
        items.length ? (
          <div className="mt-2">
            {items.map((goal) => (
              <GoalCard
                key={goal.id}
                goal={goal}
                currentUserId={profile?.id}
                onContribute={setContributing}
                onEdit={(item) => setGoalModal({ open: true, goal: item })}
                onDelete={setDeleting}
              />
            ))}
          </div>
        ) : (
          <EmptyState
            icon={Target}
            title={escopo === 'pessoal' ? 'Nenhuma meta pessoal' : 'Nenhuma meta da família'}
            description={
              escopo === 'pessoal'
                ? 'Uma reserva só sua. Ninguém mais na família vê este progresso.'
                : 'Comece com uma meta pequena. O progresso aparece no painel de todos.'
            }
            action={
              <Button onClick={() => setGoalModal({ open: true, goal: null })}>
                Criar {escopo === 'pessoal' ? 'meta pessoal' : 'meta da família'}
              </Button>
            }
          />
        )
      ) : null}

      <Modal
        open={goalModal.open}
        onClose={() => setGoalModal({ open: false, goal: null })}
        title={goalModal.goal ? 'Editar meta' : escopo === 'pessoal' ? 'Nova meta pessoal' : 'Nova meta da família'}
        description="Prazo e descrição ajudam, mas nenhum dos dois é obrigatório."
        size="lg"
      >
        {goalModal.open ? (
          <GoalForm
            goal={goalModal.goal}
            escopo={escopo}
            memberId={profile?.id}
            onClose={() => setGoalModal({ open: false, goal: null })}
            onSaved={() => {
              setGoalModal({ open: false, goal: null })
              goals.refetch()
            }}
          />
        ) : null}
      </Modal>

      <Modal
        open={Boolean(contributing)}
        onClose={() => setContributing(null)}
        title="Contribuir para a meta"
        description="A contribuição entra direto na meta, sem virar lançamento."
        size="sm"
      >
        {contributing ? (
          <ContributionForm
            goal={contributing}
            onClose={() => setContributing(null)}
            onSaved={() => {
              setContributing(null)
              goals.refetch()
            }}
          />
        ) : null}
      </Modal>

      <Modal
        open={Boolean(deleting)}
        onClose={() => setDeleting(null)}
        title="Excluir meta?"
        description="As contribuições já registradas deixam de aparecer no progresso."
        size="sm"
        footer={
          <>
            <Button variant="secondary" onClick={() => setDeleting(null)}>
              Cancelar
            </Button>
            <Button variant="danger" onClick={remove} loading={busyId === deleting?.id}>
              Excluir
            </Button>
          </>
        }
      >
        <p className="text-sm text-muted">{deleting?.titulo}</p>
      </Modal>
    </div>
  )
}
