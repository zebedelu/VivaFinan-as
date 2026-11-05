import { useEffect, useMemo, useRef, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { Filter, Plus, X } from 'lucide-react'
import Button from '../components/Button'
import { Field, Input, Select } from '../components/FormField'
import { Loading } from '../components/Loading'
import Modal from '../components/Modal'
import MonthPicker from '../components/MonthPicker'
import TransactionTable from '../components/TransactionTable'
import { ErrorState, UnavailableState } from '../components/StatePanels'
import { useToast } from '../components/Toast'
import { useApi } from '../hooks/useApi'
import { useMonth } from '../hooks/useMonth'
import { useSession } from '../hooks/useSession'
import { clampNumber, formatMoney, todayISO } from '../lib/format'
import { ESCOPO_LABEL, TIPO_LABEL } from '../lib/labels'
import { apiFetch, errorMessage } from '../services/api'

function asList(data, key) {
  if (Array.isArray(data)) return data
  return data?.[key] || data?.items || []
}

function TransactionForm({ item, categories, mes, onClose, onSaved }) {
  const { profile } = useSession()
  const toast = useToast()
  const [form, setForm] = useState(() => ({
    tipo: item?.tipo || 'despesa',
    escopo: item?.escopo || 'familia',
    valor: item?.valor != null ? String(item.valor) : '',
    descricao: item?.descricao || '',
    category_id: item?.category_id || '',
    data: item?.data?.slice(0, 10) || todayISO(),
    pago_por: item?.pago_por || '',
  }))
  const [members, setMembers] = useState([])
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)
  const [suggestion, setSuggestion] = useState(null)
  const [classifyNote, setClassifyNote] = useState('')
  const touchedCategory = useRef(Boolean(item?.category_id))
  const timer = useRef(null)

  useEffect(() => {
    if (form.escopo !== 'familia') return undefined
    let active = true
    apiFetch(`/dashboard?mes=${mes}`)
      .then((data) => {
        if (active) setMembers(data?.membros || [])
      })
      .catch(() => {
        if (active) setMembers([])
      })
    return () => {
      active = false
    }
    // Members are only needed for the "pago por" field.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [form.escopo, item])

  useEffect(() => {
    if (item) return undefined
    if (touchedCategory.current) return undefined
    const descricao = form.descricao.trim()
    if (descricao.length < 3) {
      setSuggestion(null)
      return undefined
    }
    window.clearTimeout(timer.current)
    timer.current = window.setTimeout(async () => {
      try {
        const result = await apiFetch('/ai/classify', {
          method: 'POST',
          body: { descricao, tipo: form.tipo },
        })
        const match = categories.find(
          (category) =>
            category.id === result?.categoria_id &&
            category.tipo === form.tipo &&
            !category.oculta,
        )
        if (match && !touchedCategory.current) {
          setForm((current) => ({ ...current, category_id: match.id }))
          setSuggestion({ nome: result.categoria, mode: result.mode })
          setClassifyNote('')
        }
      } catch (err) {
        if (err.status === 503) {
          setClassifyNote('Classificação automática indisponível. Escolha a categoria manualmente.')
        }
      }
    }, 700)
    return () => window.clearTimeout(timer.current)
  }, [form.descricao, form.tipo, item, categories])

  const filteredCategories = categories.filter(
    (category) => !category.oculta && (!form.tipo || category.tipo === form.tipo),
  )

  function update(field) {
    return (event) => {
      const value = event.target.value
      setForm((current) => ({
        ...current,
        [field]: value,
        ...(field === 'tipo' ? { category_id: '' } : null),
      }))
      if (field === 'category_id') {
        touchedCategory.current = true
        setSuggestion(null)
      }
      if (field === 'tipo') {
        touchedCategory.current = false
        setSuggestion(null)
      }
    }
  }

  async function submit(event) {
    event.preventDefault()
    setError('')
    const valor = clampNumber(form.valor)
    if (!form.category_id) {
      setError('Escolha uma categoria.')
      return
    }
    if (!(valor > 0)) {
      setError('Informe um valor maior que zero.')
      return
    }
    if (!form.data) {
      setError('Informe a data do lançamento.')
      return
    }
    const body = {
      tipo: form.tipo,
      valor,
      descricao: form.descricao.trim() || null,
      category_id: form.category_id,
      data: form.data,
    }
    if (!item) {
      body.escopo = form.escopo
      if (form.escopo === 'familia') body.pago_por = form.pago_por || null
    } else {
      body.pago_por = form.escopo === 'familia' ? form.pago_por || null : null
    }

    setBusy(true)
    try {
      if (item) {
        await apiFetch(`/transactions/${item.id}`, { method: 'PATCH', body })
        toast.push('Lançamento atualizado.')
      } else {
        await apiFetch('/transactions', { method: 'POST', body })
        toast.push('Lançamento salvo.')
      }
      onSaved()
    } catch (err) {
      setError(errorMessage(err, 'Não foi possível salvar o lançamento.'))
    } finally {
      setBusy(false)
    }
  }

  return (
    <form onSubmit={submit} className="space-y-4" noValidate>
      {item?.origem === 'pluggy' ? (
        <p className="rounded-control border border-linha bg-verde-claro px-3 py-2 text-xs">
          Veio do extrato bancário. Valor, descrição, categoria e data podem ser ajustados aqui; o
          vínculo com o banco fica no extrato.
        </p>
      ) : null}

      <div className="grid grid-cols-2 gap-3">
        <Field label="Tipo" htmlFor="tx-tipo">
          <Select id="tx-tipo" value={form.tipo} onChange={update('tipo')}>
            <option value="despesa">Despesa</option>
            <option value="receita">Receita</option>
          </Select>
        </Field>
        <Field label="Escopo" htmlFor="tx-escopo">
          <Select id="tx-escopo" value={form.escopo} onChange={update('escopo')} disabled={Boolean(item)}>
            <option value="familia">Família</option>
            <option value="pessoal">Pessoal</option>
          </Select>
        </Field>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <Field label="Valor" htmlFor="tx-valor" hint="Use vírgula ou ponto.">
          <Input
            id="tx-valor"
            inputMode="decimal"
            value={form.valor}
            onChange={update('valor')}
            placeholder="0,00"
            required
          />
        </Field>
        <Field label="Data" htmlFor="tx-data">
          <Input id="tx-data" type="date" value={form.data} onChange={update('data')} required />
        </Field>
      </div>

      <Field label="Descrição" htmlFor="tx-descricao">
        <Input
          id="tx-descricao"
          value={form.descricao}
          onChange={update('descricao')}
          placeholder="Mercado, aluguel, salário…"
        />
      </Field>

      <Field
        label="Categoria"
        htmlFor="tx-categoria"
        hint={suggestion ? `Sugerido pela Jev: ${suggestion.nome}` : classifyNote || undefined}
      >
        <Select id="tx-categoria" value={form.category_id} onChange={update('category_id')} required>
          <option value="">Escolha uma categoria</option>
          {filteredCategories.map((category) => (
            <option key={category.id} value={category.id}>
              {category.nome}
            </option>
          ))}
        </Select>
      </Field>

      {form.escopo === 'familia' ? (
        <Field label="Pago por" htmlFor="tx-pago-por" hint="Referência de quem pagou. Opcional.">
          <Select id="tx-pago-por" value={form.pago_por} onChange={update('pago_por')}>
            <option value="">Não informado</option>
            {members.length ? (
              members.map((member) => (
                <option key={member.member_id || member.id} value={member.member_id || member.id}>
                  {member.nome}
                </option>
              ))
            ) : profile ? (
              <option value={profile.id}>{profile.nome}</option>
            ) : null}
          </Select>
        </Field>
      ) : null}

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
          {item ? 'Salvar alterações' : 'Salvar lançamento'}
        </Button>
      </div>
    </form>
  )
}

export default function Transactions() {
  const { mes, label, prev, next, setMes, isCurrent } = useMonth()
  const toast = useToast()
  const [filters, setFilters] = useState({ tipo: '', escopo: '', categoria: '', origem: '' })
  const [modal, setModal] = useState({ open: false, item: null })
  const [deleting, setDeleting] = useState(null)
  const [busyId, setBusyId] = useState(null)
  const [searchParams, setSearchParams] = useSearchParams()

  const query = new URLSearchParams({ mes, limit: '100', offset: '0' })
  Object.entries(filters).forEach(([key, value]) => {
    if (value) query.set(key, value)
  })
  const transactions = useApi(`/transactions?${query.toString()}`)
  const categoriesApi = useApi('/categories')

  useEffect(() => {
    if (searchParams.get('novo') === '1') {
      setModal({ open: true, item: null })
      const nextParams = new URLSearchParams(searchParams)
      nextParams.delete('novo')
      setSearchParams(nextParams, { replace: true })
    }
  }, [searchParams, setSearchParams])

  const items = asList(transactions.data, 'items')
  const total = transactions.data?.total ?? items.length
  const categories = useMemo(() => asList(categoriesApi.data, 'categories'), [categoriesApi.data])
  const filterCategories = categories.filter(
    (category) => !category.oculta && (!filters.tipo || category.tipo === filters.tipo),
  )
  const hasFilters = Object.values(filters).some(Boolean)

  function updateFilter(field) {
    return (event) => setFilters((current) => ({ ...current, [field]: event.target.value }))
  }

  function closeModal() {
    setModal({ open: false, item: null })
  }

  async function remove() {
    if (!deleting) return
    setBusyId(deleting.id)
    try {
      await apiFetch(`/transactions/${deleting.id}`, { method: 'DELETE' })
      toast.push('Lançamento excluído.')
      setDeleting(null)
      transactions.refetch()
    } catch (err) {
      toast.push(errorMessage(err, 'Não foi possível excluir o lançamento.'), 'error')
    } finally {
      setBusyId(null)
    }
  }

  return (
    <div>
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="text-sm text-muted">Lançamentos</p>
          <h1 className="mt-1 font-display text-3xl">O que entrou e saiu</h1>
          <p className="mt-2 text-sm text-muted">
            {total} {total === 1 ? 'lançamento' : 'lançamentos'} em {label.toLowerCase()}
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <MonthPicker mes={mes} label={label} onPrev={prev} onNext={next} onToday={() => setMes(null)} isCurrent={isCurrent} />
          <Button onClick={() => setModal({ open: true, item: null })}>
            <Plus size={16} aria-hidden="true" /> Novo lançamento
          </Button>
        </div>
      </div>

      <div className="mt-6 flex flex-wrap items-center gap-2 border-y border-linha py-3">
        <span className="mr-1 inline-flex items-center gap-1.5 text-xs text-muted">
          <Filter size={13} aria-hidden="true" /> Filtrar
        </span>
        <select
          aria-label="Tipo"
          className="field w-auto py-1.5 text-xs"
          value={filters.tipo}
          onChange={updateFilter('tipo')}
        >
          <option value="">Todos os tipos</option>
          <option value="receita">Receitas</option>
          <option value="despesa">Despesas</option>
        </select>
        <select
          aria-label="Escopo"
          className="field w-auto py-1.5 text-xs"
          value={filters.escopo}
          onChange={updateFilter('escopo')}
        >
          <option value="">Todo escopo</option>
          <option value="familia">Família</option>
          <option value="pessoal">Pessoal</option>
        </select>
        <select
          aria-label="Categoria"
          className="field w-auto py-1.5 text-xs"
          value={filters.categoria}
          onChange={updateFilter('categoria')}
        >
          <option value="">Toda categoria</option>
          {filterCategories.map((category) => (
            <option key={category.id} value={category.id}>
              {category.nome}
            </option>
          ))}
        </select>
        <select
          aria-label="Origem"
          className="field w-auto py-1.5 text-xs"
          value={filters.origem}
          onChange={updateFilter('origem')}
        >
          <option value="">Toda origem</option>
          <option value="manual">Manual</option>
          <option value="pluggy">Banco</option>
        </select>
        {hasFilters ? (
          <button
            type="button"
            onClick={() => setFilters({ tipo: '', escopo: '', categoria: '', origem: '' })}
            className="inline-flex items-center gap-1 px-1 text-xs text-muted hover:text-grafite"
          >
            <X size={12} aria-hidden="true" /> Limpar
          </button>
        ) : null}
      </div>

      <div className="mt-2">
        {transactions.loading ? <Loading label="Carregando lançamentos" rows={4} /> : null}

        {transactions.error?.status === 503 ? (
          <UnavailableState
            title="Lançamentos indisponíveis"
            description="O servidor não conseguiu listar o período agora."
            onRetry={transactions.refetch}
          />
        ) : null}

        {transactions.error && transactions.error.status !== 503 ? (
          <ErrorState error={transactions.error} onRetry={transactions.refetch} />
        ) : null}

        {!transactions.loading && !transactions.error ? (
          <TransactionTable
            items={items}
            onEdit={(item) => setModal({ open: true, item })}
            onDelete={(item) => setDeleting(item)}
            busyId={busyId}
          />
        ) : null}
      </div>

      {!transactions.loading && !transactions.error && items.length > 0 && total > items.length ? (
        <p className="mt-4 text-xs text-muted">
          Mostrando {items.length} de {total}. Refine os filtros para ver o restante.
        </p>
      ) : null}

      <Modal
        open={modal.open}
        onClose={closeModal}
        title={modal.item ? 'Editar lançamento' : 'Novo lançamento'}
        description={
          modal.item
            ? 'Alterações em lançamentos da família ficam visíveis para todos.'
            : 'Leva menos de um minuto. Só o essencial.'
        }
        size="lg"
      >
        {modal.open ? (
          <TransactionForm
            item={modal.item}
            categories={categories}
            mes={mes}
            onClose={closeModal}
            onSaved={() => {
              closeModal()
              transactions.refetch()
            }}
          />
        ) : null}
      </Modal>

      <Modal
        open={Boolean(deleting)}
        onClose={() => setDeleting(null)}
        title="Excluir lançamento?"
        description="Essa ação não pode ser desfeita."
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
        <p className="text-sm text-muted">
          {deleting?.descricao || TIPO_LABEL[deleting?.tipo] || 'Lançamento'} ·{' '}
          {formatMoney(deleting?.valor || 0)} · {ESCOPO_LABEL[deleting?.escopo] || ''}
        </p>
      </Modal>
    </div>
  )
}
