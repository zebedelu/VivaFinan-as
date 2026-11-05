import { useMemo, useState } from 'react'
import { Pencil, Plus, Repeat } from 'lucide-react'
import Badge from '../components/Badge'
import Button from '../components/Button'
import EmptyState from '../components/EmptyState'
import { Field, Input, Select } from '../components/FormField'
import { Loading } from '../components/Loading'
import Modal from '../components/Modal'
import MonthPicker from '../components/MonthPicker'
import RecurringCard from '../components/RecurringCard'
import Section from '../components/Section'
import { ErrorState, UnavailableState } from '../components/StatePanels'
import { useToast } from '../components/Toast'
import { useApi } from '../hooks/useApi'
import { useMonth } from '../hooks/useMonth'
import { clampNumber, formatMoney } from '../lib/format'
import { ESCOPO_LABEL, TIPO_LABEL } from '../lib/labels'
import { apiFetch, errorMessage } from '../services/api'

function asList(data, key) {
  if (Array.isArray(data)) return data
  return data?.[key] || data?.items || []
}

function RuleForm({ rule, categories, onClose, onSaved }) {
  const toast = useToast()
  const [form, setForm] = useState(() => ({
    tipo: rule?.tipo || 'despesa',
    escopo: rule?.escopo || 'familia',
    valor: rule?.valor != null ? String(rule.valor) : '',
    descricao: rule?.descricao || '',
    category_id: rule?.category_id || '',
    dia_vencimento: rule?.dia_vencimento ? String(rule.dia_vencimento) : '5',
    ativo: rule?.ativo ?? true,
  }))
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  const filtered = categories.filter(
    (category) => !category.oculta && (!form.tipo || category.tipo === form.tipo),
  )

  function update(field) {
    return (event) => {
      const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value
      setForm((current) => ({
        ...current,
        [field]: value,
        ...(field === 'tipo' ? { category_id: '' } : null),
      }))
    }
  }

  async function submit(event) {
    event.preventDefault()
    setError('')
    const valor = clampNumber(form.valor)
    const dia = Number(form.dia_vencimento)
    if (!form.descricao.trim()) {
      setError('Dê um nome para a conta recorrente.')
      return
    }
    if (!(valor > 0)) {
      setError('Informe um valor maior que zero.')
      return
    }
    if (!form.category_id) {
      setError('Escolha uma categoria.')
      return
    }
    if (!(dia >= 1 && dia <= 31)) {
      setError('O dia do vencimento precisa ficar entre 1 e 31.')
      return
    }
    const body = {
      tipo: form.tipo,
      escopo: form.escopo,
      valor,
      descricao: form.descricao.trim(),
      category_id: form.category_id,
      dia_vencimento: dia,
      ativo: form.ativo,
    }
    setBusy(true)
    try {
      if (rule) {
        await apiFetch(`/recurring/rules/${rule.id}`, { method: 'PATCH', body })
        toast.push('Regra atualizada.')
      } else {
        await apiFetch('/recurring/rules', { method: 'POST', body })
        toast.push('Regra criada. Ela aparece no mês quando chegar perto do vencimento.')
      }
      onSaved()
    } catch (err) {
      setError(errorMessage(err, 'Não foi possível salvar a regra.'))
    } finally {
      setBusy(false)
    }
  }

  return (
    <form onSubmit={submit} className="space-y-4" noValidate>
      <Field label="Descrição" htmlFor="rule-descricao">
        <Input
          id="rule-descricao"
          value={form.descricao}
          onChange={update('descricao')}
          placeholder="Aluguel, internet, salário…"
          required
        />
      </Field>

      <div className="grid gap-4 sm:grid-cols-2">
        <Field label="Tipo" htmlFor="rule-tipo">
          <Select id="rule-tipo" value={form.tipo} onChange={update('tipo')}>
            <option value="despesa">Despesa</option>
            <option value="receita">Receita</option>
          </Select>
        </Field>
        <Field label="Escopo" htmlFor="rule-escopo">
          <Select id="rule-escopo" value={form.escopo} onChange={update('escopo')}>
            <option value="familia">Família</option>
            <option value="pessoal">Pessoal</option>
          </Select>
        </Field>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <Field label="Valor" htmlFor="rule-valor">
          <Input
            id="rule-valor"
            inputMode="decimal"
            value={form.valor}
            onChange={update('valor')}
            placeholder="0,00"
            required
          />
        </Field>
        <Field label="Dia do vencimento" htmlFor="rule-dia" hint="Entre 1 e 31.">
          <Input
            id="rule-dia"
            type="number"
            min="1"
            max="31"
            value={form.dia_vencimento}
            onChange={update('dia_vencimento')}
            required
          />
        </Field>
      </div>

      <Field label="Categoria" htmlFor="rule-categoria">
        <Select id="rule-categoria" value={form.category_id} onChange={update('category_id')} required>
          <option value="">Escolha uma categoria</option>
          {filtered.map((category) => (
            <option key={category.id} value={category.id}>
              {category.nome}
            </option>
          ))}
        </Select>
      </Field>

      <label className="flex items-center gap-2 text-sm">
        <input
          type="checkbox"
          className="h-4 w-4 accent-[var(--verde)]"
          checked={form.ativo}
          onChange={update('ativo')}
        />
        Regra ativa
      </label>

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
          {rule ? 'Salvar regra' : 'Criar regra'}
        </Button>
      </div>
    </form>
  )
}

export default function Recurring() {
  const { mes, label, prev, next, setMes, isCurrent } = useMonth()
  const toast = useToast()
  const pending = useApi(`/recurring/pending?mes=${mes}`)
  const rules = useApi('/recurring/rules')
  const categoriesApi = useApi('/categories')
  const [busyId, setBusyId] = useState(null)
  const [ruleModal, setRuleModal] = useState({ open: false, rule: null })
  const [customValue, setCustomValue] = useState(null)
  const [customInput, setCustomInput] = useState('')
  const [customError, setCustomError] = useState('')

  const pendingItems = asList(pending.data, 'items')
  const ruleItems = asList(rules.data, 'rules')
  const categories = useMemo(() => asList(categoriesApi.data, 'categories'), [categoriesApi.data])

  async function confirm(occurrence, custom = false) {
    if (custom) {
      setCustomValue(occurrence)
      setCustomInput(String(occurrence.valor ?? ''))
      setCustomError('')
      return
    }
    await sendConfirm(occurrence, null)
  }

  async function sendConfirm(occurrence, valor) {
    const id = occurrence.occurrence_id || occurrence.id
    setBusyId(id)
    try {
      await apiFetch(`/recurring/occurrences/${id}/confirm`, {
        method: 'POST',
        body: valor != null ? { valor } : {},
      })
      toast.push('Conta confirmada. O lançamento já está em Lançamentos.')
      setCustomValue(null)
      pending.refetch()
    } catch (err) {
      if (err.status === 409) {
        toast.push('Essa conta já foi decidida. Atualizando a lista.', 'error')
        pending.refetch()
      } else {
        toast.push(errorMessage(err, 'Não foi possível confirmar a conta.'), 'error')
      }
    } finally {
      setBusyId(null)
    }
  }

  async function ignore(occurrence) {
    const id = occurrence.occurrence_id || occurrence.id
    setBusyId(id)
    try {
      await apiFetch(`/recurring/occurrences/${id}/ignore`, { method: 'POST' })
      toast.push('Conta ignorada neste mês.')
      pending.refetch()
    } catch (err) {
      toast.push(errorMessage(err, 'Não foi possível ignorar a conta.'), 'error')
    } finally {
      setBusyId(null)
    }
  }

  async function toggleRule(rule) {
    setBusyId(rule.id)
    try {
      await apiFetch(`/recurring/rules/${rule.id}`, {
        method: 'PATCH',
        body: { ativo: !rule.ativo },
      })
      toast.push(rule.ativo ? 'Regra desativada.' : 'Regra ativada.')
      rules.refetch()
      pending.refetch()
    } catch (err) {
      toast.push(errorMessage(err, 'Não foi possível alterar a regra.'), 'error')
    } finally {
      setBusyId(null)
    }
  }

  function submitCustom(event) {
    event.preventDefault()
    const valor = clampNumber(customInput)
    if (!(valor > 0)) {
      setCustomError('Informe um valor maior que zero.')
      return
    }
    sendConfirm(customValue, valor)
  }

  const loading = pending.loading || rules.loading

  return (
    <div>
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="text-sm text-muted">Recorrentes</p>
          <h1 className="mt-1 font-display text-3xl">O que volta todo mês</h1>
          <p className="mt-2 max-w-lg text-sm text-muted">
            O app não lança sozinho. Três dias antes do vencimento, a conta aparece para você
            confirmar, ajustar o valor ou ignorar.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <MonthPicker mes={mes} label={label} onPrev={prev} onNext={next} onToday={() => setMes(null)} isCurrent={isCurrent} />
          <Button onClick={() => setRuleModal({ open: true, rule: null })}>
            <Plus size={16} aria-hidden="true" /> Nova regra
          </Button>
        </div>
      </div>

      {loading ? <Loading label="Carregando recorrências" rows={4} /> : null}

      {!loading && pending.error?.status === 503 ? (
        <div className="mt-6">
          <UnavailableState
            title="Contas a confirmar indisponíveis"
            description="O servidor não conseguiu montar a fila do mês agora."
            onRetry={pending.refetch}
          />
        </div>
      ) : null}

      {!loading && pending.error && pending.error.status !== 503 ? (
        <div className="mt-6">
          <ErrorState error={pending.error} onRetry={pending.refetch} />
        </div>
      ) : null}

      {!loading && !pending.error ? (
        <Section
          id="fila"
          title="Para confirmar"
          description={
            pendingItems.length
              ? `${pendingItems.length} ${pendingItems.length === 1 ? 'conta esperando' : 'contas esperando'} uma decisão.`
              : 'Nada pendente neste mês.'
          }
          className="mt-8"
        >
          {pendingItems.length ? (
            <div>
              {pendingItems.map((occurrence) => (
                <RecurringCard
                  key={occurrence.occurrence_id || occurrence.id}
                  occurrence={occurrence}
                  onConfirm={confirm}
                  onIgnore={ignore}
                  busy={busyId === (occurrence.occurrence_id || occurrence.id)}
                />
              ))}
            </div>
          ) : (
            <EmptyState
              icon={Repeat}
              title="Fila vazia"
              description="As contas recorrentes aparecem aqui conforme a data de vencimento se aproxima."
            />
          )}
        </Section>
      ) : null}

      {!rules.loading && rules.error?.status === 503 ? (
        <div className="mt-8">
          <UnavailableState
            title="Regras indisponíveis"
            description="Não foi possível listar suas regras agora."
            onRetry={rules.refetch}
          />
        </div>
      ) : null}

      {!rules.loading && rules.error && rules.error.status !== 503 ? (
        <div className="mt-8">
          <ErrorState error={rules.error} onRetry={rules.refetch} />
        </div>
      ) : null}

      {!rules.loading && !rules.error ? (
        <Section
          id="regras"
          title="Suas regras"
          description="Desative o que não vale mais. O histórico de lançamentos fica como está."
          className="mt-10"
        >
          {ruleItems.length ? (
            <ul>
              {ruleItems.map((rule) => (
                <li key={rule.id} className="flex flex-wrap items-center justify-between gap-3 border-b border-linha py-3.5 last:border-b-0">
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <p className={`font-medium ${rule.ativo ? '' : 'text-muted line-through'}`}>
                        {rule.descricao || rule.categoria || 'Regra'}
                      </p>
                      <Badge tone={rule.ativo ? 'verde' : 'neutro'}>
                        {rule.ativo ? 'Ativa' : 'Inativa'}
                      </Badge>
                    </div>
                    <p className="mt-0.5 flex flex-wrap gap-x-2 text-xs text-muted">
                      <span>{TIPO_LABEL[rule.tipo] || rule.tipo}</span>
                      <span>· {ESCOPO_LABEL[rule.escopo] || rule.escopo}</span>
                      <span>· todo dia {rule.dia_vencimento}</span>
                      {rule.categoria ? <span>· {rule.categoria}</span> : null}
                    </p>
                  </div>
                  <div className="flex items-center gap-3">
                    <span className={`num text-sm ${rule.tipo === 'receita' ? 'text-verde-texto' : 'text-terracota-texto'}`}>
                      {formatMoney(rule.valor)}
                    </span>
                    <button
                      type="button"
                      onClick={() => setRuleModal({ open: true, rule })}
                      className="btn-ghost p-1.5"
                      aria-label={`Editar ${rule.descricao || 'regra'}`}
                    >
                      <Pencil size={15} aria-hidden="true" />
                    </button>
                    <Button
                      variant="secondary"
                      className="px-2.5 py-1 text-xs"
                      onClick={() => toggleRule(rule)}
                      loading={busyId === rule.id}
                    >
                      {rule.ativo ? 'Desativar' : 'Ativar'}
                    </Button>
                  </div>
                </li>
              ))}
            </ul>
          ) : (
            <EmptyState
              icon={Repeat}
              title="Nenhuma regra ainda"
              description="Aluguel, internet, salário. Cadastre uma vez e confirme todo mês."
              action={<Button onClick={() => setRuleModal({ open: true, rule: null })}>Criar regra</Button>}
            />
          )}
        </Section>
      ) : null}

      <Modal
        open={ruleModal.open}
        onClose={() => setRuleModal({ open: false, rule: null })}
        title={ruleModal.rule ? 'Editar regra' : 'Nova conta recorrente'}
        description="A regra gera um cartão de confirmação perto do vencimento."
        size="lg"
      >
        {ruleModal.open ? (
          <RuleForm
            rule={ruleModal.rule}
            categories={categories}
            onClose={() => setRuleModal({ open: false, rule: null })}
            onSaved={() => {
              setRuleModal({ open: false, rule: null })
              rules.refetch()
              pending.refetch()
            }}
          />
        ) : null}
      </Modal>

      <Modal
        open={Boolean(customValue)}
        onClose={() => setCustomValue(null)}
        title="Confirmar com outro valor"
        description={customValue?.descricao || 'Ajuste o valor deste mês. A regra continua igual.'}
        size="sm"
      >
        <form onSubmit={submitCustom} className="space-y-4">
          <Field label="Valor deste mês" htmlFor="custom-valor">
            <Input
              id="custom-valor"
              inputMode="decimal"
              value={customInput}
              onChange={(event) => setCustomInput(event.target.value)}
              required
            />
          </Field>
          {customError ? (
            <p className="text-sm text-terracota-texto" role="alert">
              {customError}
            </p>
          ) : null}
          <div className="flex justify-end gap-2">
            <Button variant="secondary" onClick={() => setCustomValue(null)}>
              Cancelar
            </Button>
            <Button type="submit" loading={busyId === (customValue?.occurrence_id || customValue?.id)}>
              Confirmar
            </Button>
          </div>
        </form>
      </Modal>
    </div>
  )
}
