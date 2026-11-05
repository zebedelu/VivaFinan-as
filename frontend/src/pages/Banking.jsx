import { useEffect, useMemo, useRef, useState } from 'react'
import { Link2, RefreshCw, Download } from 'lucide-react'
import Badge from '../components/Badge'
import BankTxTable from '../components/BankTxTable'
import Button from '../components/Button'
import EmptyState from '../components/EmptyState'
import { Field, Input, Select } from '../components/FormField'
import { Loading } from '../components/Loading'
import Modal from '../components/Modal'
import PluggyConnect from '../components/PluggyConnect'
import Section from '../components/Section'
import { ErrorState, UnavailableState } from '../components/StatePanels'
import { useToast } from '../components/Toast'
import { useApi } from '../hooks/useApi'
import {
  addMonths,
  clampNumber,
  currentMonth,
  formatDate,
  formatDateTime,
  formatMoney,
  formatMonth,
  todayISO,
} from '../lib/format'
import { BANK_STATUS, CONNECTION_STATUS, TIPO_LABEL } from '../lib/labels'
import { apiFetch, errorMessage } from '../services/api'

function asList(data, key) {
  if (Array.isArray(data)) return data
  return data?.[key] || data?.items || []
}

const MONTH_OPTIONS = Array.from({ length: 7 }, (_, index) => addMonths(currentMonth(), -index))

export default function Banking() {
  const toast = useToast()
  const [filters, setFilters] = useState({ connection_id: '', status: '', mes: '' })
  const [selected, setSelected] = useState(new Set())
  const [busyId, setBusyId] = useState(null)
  const [importTx, setImportTx] = useState(null)
  const [reconcileTx, setReconcileTx] = useState(null)
  const [bulkOpen, setBulkOpen] = useState(false)
  const [syncNote, setSyncNote] = useState('')
  const autoSync = useRef(false)

  const query = new URLSearchParams({ limit: '100', offset: '0' })
  Object.entries(filters).forEach(([key, value]) => {
    if (value) query.set(key, value)
  })

  const connectionsApi = useApi('/banking/connections')
  const accountsApi = useApi('/banking/accounts')
  const transactionsApi = useApi(`/banking/transactions?${query.toString()}`)
  const categoriesApi = useApi('/categories')

  const connections = useMemo(() => asList(connectionsApi.data, 'connections'), [connectionsApi.data])
  const accounts = useMemo(() => asList(accountsApi.data, 'accounts'), [accountsApi.data])
  const transactions = useMemo(() => asList(transactionsApi.data, 'items'), [transactionsApi.data])
  const categories = useMemo(() => asList(categoriesApi.data, 'categories'), [categoriesApi.data])
  const pendingCount = transactions.filter((tx) => tx.status === 'pendente_importacao').length

  useEffect(() => {
    if (autoSync.current || connectionsApi.loading || !connections.length) return
    const stale = connections.find((connection) => {
      if (connection.status !== 'ativa') return false
      if (!connection.ultima_sync_em) return true
      return Date.now() - new Date(connection.ultima_sync_em).getTime() > 24 * 60 * 60 * 1000
    })
    if (!stale) return
    autoSync.current = true
    apiFetch('/banking/sync', { method: 'POST', body: { connection_id: stale.id } })
      .then(() => {
        transactionsApi.refetch()
        connectionsApi.refetch()
      })
      .catch((err) => {
        if (err.status === 503) {
          setSyncNote('Sincronização automática indisponível: configure a chave da Pluggy no servidor.')
        }
      })
    // Run once per page visit, when the connection list first arrives.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [connectionsApi.loading, connectionsApi.data])

  function updateFilter(field) {
    return (event) => setFilters((current) => ({ ...current, [field]: event.target.value }))
  }

  function refreshAll() {
    transactionsApi.refetch()
    connectionsApi.refetch()
    accountsApi.refetch()
  }

  async function sync(connection) {
    setBusyId(`sync-${connection.id}`)
    try {
      await apiFetch('/banking/sync', { method: 'POST', body: { connection_id: connection.id } })
      toast.push('Sincronização concluída.')
      setSyncNote('')
      refreshAll()
    } catch (err) {
      if (err.status === 503) {
        setSyncNote('Sincronização indisponível: configure a chave da Pluggy no servidor.')
      } else {
        toast.push(errorMessage(err, 'Não foi possível sincronizar agora.'), 'error')
      }
    } finally {
      setBusyId(null)
    }
  }

  async function ignore(tx) {
    setBusyId(tx.id)
    try {
      await apiFetch('/banking/ignore', {
        method: 'POST',
        body: { bank_transaction_id: tx.id },
      })
      toast.push('Transação ignorada.')
      transactionsApi.refetch()
    } catch (err) {
      toast.push(errorMessage(err, 'Não foi possível ignorar a transação.'), 'error')
    } finally {
      setBusyId(null)
    }
  }

  async function unignore(tx) {
    setBusyId(tx.id)
    try {
      await apiFetch('/banking/unignore', {
        method: 'POST',
        body: { bank_transaction_id: tx.id },
      })
      toast.push('Transação voltou para a fila.')
      transactionsApi.refetch()
    } catch (err) {
      toast.push(errorMessage(err, 'Não foi possível desfazer.'), 'error')
    } finally {
      setBusyId(null)
    }
  }

  function toggle(txId) {
    setSelected((current) => {
      const next = new Set(current)
      if (next.has(txId)) next.delete(txId)
      else next.add(txId)
      return next
    })
  }

  function openReconcile(tx) {
    setReconcileTx(tx)
  }

  const selectedTransactions = transactions.filter((tx) => selected.has(tx.id))

  return (
    <div>
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="text-sm text-muted">Extrato</p>
          <h1 className="mt-1 font-display text-3xl">O que passou pelo banco</h1>
          <p className="mt-2 max-w-xl text-sm text-muted">
            Leitura apenas. Importar cria o lançamento no VivaFinanças; reconciliar liga a transação a
            algo que você já lançou.
          </p>
        </div>
        {pendingCount > 0 ? <Badge tone="dourado">{pendingCount} para importar</Badge> : null}
      </div>

      {syncNote ? (
        <p className="mt-4 rounded-control border border-dourado/40 bg-dourado/10 px-3 py-2 text-xs">
          {syncNote}
        </p>
      ) : null}

      {connectionsApi.error?.status === 503 ? (
        <div className="mt-6">
          <UnavailableState
            title="Integração bancária indisponível"
            description="O servidor não tem a chave da Pluggy configurada. A conexão de demonstração, quando existe, continua visível abaixo."
            onRetry={connectionsApi.refetch}
          />
        </div>
      ) : null}

      {connectionsApi.error && connectionsApi.error.status !== 503 ? (
        <div className="mt-6">
          <ErrorState error={connectionsApi.error} onRetry={connectionsApi.refetch} />
        </div>
      ) : null}

      {!connectionsApi.error ? (
        <Section id="conexoes" title="Contas conectadas" description="Cada pessoa conecta as próprias contas." className="mt-8">
          {connectionsApi.loading ? <Loading label="Carregando conexões" rows={2} /> : null}
          {!connectionsApi.loading && connections.length === 0 ? (
            <EmptyState
              title="Nenhuma conta conectada"
              description="Conecte um banco para ver o extrato aqui. A família funciona inteira sem isso."
            />
          ) : null}
          {connections.length ? (
            <ul>
              {connections.map((connection) => {
                const status = CONNECTION_STATUS[connection.status] || CONNECTION_STATUS.inativa
                return (
                  <li
                    key={connection.id}
                    className="flex flex-wrap items-center justify-between gap-3 border-b border-linha py-3.5 last:border-b-0"
                  >
                    <div className="min-w-0">
                      <div className="flex flex-wrap items-center gap-2">
                        <p className="font-medium">
                          {connection.institution_name || connection.account_name || 'Conta conectada'}
                        </p>
                        <Badge tone={status.tone}>{status.label}</Badge>
                        {connection.is_demo_sync ? <Badge>Demo</Badge> : null}
                      </div>
                      <p className="mt-0.5 text-xs text-muted">
                        {connection.account_type || 'Conta'}
                        {connection.account_number_masked ? ` · ${connection.account_number_masked}` : ''}
                        {' · '}
                        {connection.ultima_sync_em
                          ? `Sincronizada em ${formatDateTime(connection.ultima_sync_em)}`
                          : 'Nunca sincronizada'}
                      </p>
                    </div>
                    {connection.status === 'ativa' ? (
                      <Button
                        variant="secondary"
                        className="px-3 py-1.5 text-xs"
                        onClick={() => sync(connection)}
                        loading={busyId === `sync-${connection.id}`}
                      >
                        <RefreshCw size={13} aria-hidden="true" /> Sincronizar agora
                      </Button>
                    ) : null}
                  </li>
                )
              })}
            </ul>
          ) : null}

          <div className="mt-4">
            <PluggyConnect unavailable={connectionsApi.error?.status === 503} />
          </div>
        </Section>
      ) : null}

      {accounts.length ? (
        <Section id="contas" title="Saldos" description="Atualizados na última sincronização." className="mt-10">
          <ul className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {accounts.map((account) => (
              <li key={account.id} className="rounded-card border border-linha bg-superficie p-4">
                <p className="text-xs text-muted">{account.tipo || 'Conta'}</p>
                <p className="mt-0.5 truncate text-sm font-medium">{account.nome}</p>
                <p className="num mt-2 font-display text-xl">{formatMoney(account.balance)}</p>
                <p className="mt-1 text-2xs text-muted">{formatDateTime(account.updated_at)}</p>
              </li>
            ))}
          </ul>
        </Section>
      ) : null}

      <Section
        id="transacoes-banco"
        title="Transações"
        description="Pendentes podem ser importadas, reconciliadas ou ignoradas."
        className="mt-10"
        action={
          selectedTransactions.length ? (
            <Button className="px-3 py-1.5 text-xs" onClick={() => setBulkOpen(true)}>
              <Download size={13} aria-hidden="true" /> Importar selecionadas ({selectedTransactions.length})
            </Button>
          ) : null
        }
      >
        <div className="mb-4 flex flex-wrap gap-2">
          <select
            aria-label="Conexão"
            className="field w-auto py-1.5 text-xs"
            value={filters.connection_id}
            onChange={updateFilter('connection_id')}
          >
            <option value="">Todas as conexões</option>
            {connections.map((connection) => (
              <option key={connection.id} value={connection.id}>
                {connection.institution_name || connection.account_name || 'Conta'}
              </option>
            ))}
          </select>
          <select
            aria-label="Status da transação"
            className="field w-auto py-1.5 text-xs"
            value={filters.status}
            onChange={updateFilter('status')}
          >
            <option value="">Todos os status</option>
            {Object.entries(BANK_STATUS).map(([value, meta]) => (
              <option key={value} value={value}>
                {meta.label}
              </option>
            ))}
          </select>
          <select
            aria-label="Mês"
            className="field w-auto py-1.5 text-xs"
            value={filters.mes}
            onChange={updateFilter('mes')}
          >
            <option value="">Todo o período</option>
            {MONTH_OPTIONS.map((mes) => (
              <option key={mes} value={mes}>
                {formatMonth(mes)}
              </option>
            ))}
          </select>
          {Object.values(filters).some(Boolean) ? (
            <button
              type="button"
              onClick={() => setFilters({ connection_id: '', status: '', mes: '' })}
              className="px-1 text-xs text-muted hover:text-grafite"
            >
              Limpar
            </button>
          ) : null}
        </div>

        {transactionsApi.loading ? <Loading label="Carregando extrato" rows={4} /> : null}
        {transactionsApi.error?.status === 503 ? (
          <UnavailableState
            title="Extrato indisponível"
            description="O servidor não conseguiu listar as transações agora."
            onRetry={transactionsApi.refetch}
          />
        ) : null}
        {transactionsApi.error && transactionsApi.error.status !== 503 ? (
          <ErrorState error={transactionsApi.error} onRetry={transactionsApi.refetch} />
        ) : null}
        {!transactionsApi.loading && !transactionsApi.error ? (
          <BankTxTable
            items={transactions}
            selected={selected}
            onToggle={toggle}
            onImport={setImportTx}
            onReconcile={openReconcile}
            onIgnore={ignore}
            onUnignore={unignore}
            busyId={busyId}
          />
        ) : null}
      </Section>

      {importTx ? (
        <ImportModal
          tx={importTx}
          categories={categories}
          onClose={() => setImportTx(null)}
          onImported={() => {
            setImportTx(null)
            refreshAll()
          }}
        />
      ) : null}

      {reconcileTx ? (
        <ReconcileModal
          tx={reconcileTx}
          onClose={() => setReconcileTx(null)}
          onReconciled={() => {
            setReconcileTx(null)
            refreshAll()
          }}
          onImport={() => {
            setReconcileTx(null)
            setImportTx(reconcileTx)
          }}
        />
      ) : null}

      {bulkOpen ? (
        <BulkImportModal
          transactions={selectedTransactions}
          categories={categories}
          onClose={() => setBulkOpen(false)}
          onDone={() => {
            setBulkOpen(false)
            setSelected(new Set())
            refreshAll()
          }}
        />
      ) : null}
    </div>
  )
}

function ImportModal({ tx, categories, onClose, onImported }) {
  const toast = useToast()
  const tipo = tx.tipo === 'credito' ? 'receita' : 'despesa'
  const [form, setForm] = useState({
    escopo: 'pessoal',
    category_id: '',
    valor: String(Math.abs(Number(tx.valor) || 0)),
    data: tx.data?.slice(0, 10) || todayISO(),
    descricao: tx.descricao || '',
  })
  const [suggestion, setSuggestion] = useState(null)
  const [classifyNote, setClassifyNote] = useState('')
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)
  const touched = useRef(false)

  useEffect(() => {
    let active = true
    apiFetch('/ai/classify', {
      method: 'POST',
      body: { descricao: tx.descricao || '', tipo },
    })
      .then((result) => {
        if (!active) return
        const match = categories.find(
          (category) =>
            category.id === result?.categoria_id && category.tipo === tipo && !category.oculta,
        )
        if (match && !touched.current) {
          setForm((current) => ({ ...current, category_id: match.id }))
          setSuggestion(result.categoria)
        }
      })
      .catch((err) => {
        if (active && err.status === 503) {
          setClassifyNote('Sugestão automática indisponível. Escolha a categoria.')
        }
      })
    return () => {
      active = false
    }
  }, [tx.descricao, tipo, categories])

  const filtered = categories.filter((category) => category.tipo === tipo && !category.oculta)

  function update(field) {
    return (event) => {
      setForm((current) => ({ ...current, [field]: event.target.value }))
      if (field === 'category_id') {
        touched.current = true
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
    setBusy(true)
    try {
      await apiFetch('/banking/import', {
        method: 'POST',
        body: {
          bank_transaction_id: tx.id,
          category_id: form.category_id,
          escopo: form.escopo,
          valor,
          data: form.data,
          descricao: form.descricao.trim() || null,
        },
      })
      toast.push('Transação importada.')
      onImported()
    } catch (err) {
      setError(errorMessage(err, 'Não foi possível importar a transação.'))
    } finally {
      setBusy(false)
    }
  }

  return (
    <Modal
      open
      onClose={onClose}
      title="Importar transação"
      description={`${tx.descricao || 'Transação'} · ${formatDate(tx.data)} · ${formatMoney(tx.valor)}`}
      size="lg"
    >
      <form onSubmit={submit} className="space-y-4" noValidate>
        <div className="flex flex-wrap gap-2">
          <Badge tone={tipo === 'receita' ? 'verde' : 'terracota'}>{TIPO_LABEL[tipo]}</Badge>
          {tx.categoria_bancaria ? <Badge>{tx.categoria_bancaria}</Badge> : null}
        </div>

        <div className="grid grid-cols-2 gap-3">
          <Field label="Valor" htmlFor="import-valor">
            <Input
              id="import-valor"
              inputMode="decimal"
              value={form.valor}
              onChange={update('valor')}
              required
            />
          </Field>
          <Field label="Data" htmlFor="import-data">
            <Input id="import-data" type="date" value={form.data} onChange={update('data')} required />
          </Field>
        </div>

        <Field label="Descrição" htmlFor="import-descricao">
          <Input id="import-descricao" value={form.descricao} onChange={update('descricao')} />
        </Field>

        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Categoria" htmlFor="import-categoria" hint={suggestion ? `Sugerido pela Jev: ${suggestion}` : classifyNote || undefined}>
            <Select id="import-categoria" value={form.category_id} onChange={update('category_id')} required>
              <option value="">Escolha uma categoria</option>
              {filtered.map((category) => (
                <option key={category.id} value={category.id}>
                  {category.nome}
                </option>
              ))}
            </Select>
          </Field>
          <Field label="Escopo" htmlFor="import-escopo" hint="Pessoal por padrão. A família pode ver o total.">
            <Select id="import-escopo" value={form.escopo} onChange={update('escopo')}>
              <option value="pessoal">Pessoal</option>
              <option value="familia">Família</option>
            </Select>
          </Field>
        </div>

        {error ? (
          <p className="rounded-control border border-terracota/30 bg-terracota/5 px-3 py-2 text-sm text-terracota-texto" role="alert">
            {error}
          </p>
        ) : null}

        <div className="flex justify-end gap-2">
          <Button variant="secondary" onClick={onClose}>
            Cancelar
          </Button>
          <Button type="submit" loading={busy}>
            Importar
          </Button>
        </div>
      </form>
    </Modal>
  )
}

function ReconcileModal({ tx, onClose, onReconciled, onImport }) {
  const toast = useToast()
  const [candidates, setCandidates] = useState(null)
  const [selectedId, setSelectedId] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    let active = true
    apiFetch(`/banking/reconcile-candidates?bank_transaction_id=${tx.id}`)
      .then((data) => {
        if (!active) return
        const list = asList(data, 'candidates')
        setCandidates(list)
        if (list.length) setSelectedId(list[0].transaction_id)
      })
      .catch((err) => {
        if (active) setError(errorMessage(err, 'Não foi possível buscar lançamentos parecidos.'))
      })
      .finally(() => {
        if (active) setLoading(false)
      })
    return () => {
      active = false
    }
  }, [tx.id])

  async function reconcile() {
    if (!selectedId) return
    setBusy(true)
    setError('')
    try {
      await apiFetch('/banking/reconcile', {
        method: 'POST',
        body: { bank_transaction_id: tx.id, transaction_id: selectedId },
      })
      toast.push('Transação reconciliada com o lançamento.')
      onReconciled()
    } catch (err) {
      setError(errorMessage(err, 'Não foi possível reconciliar.'))
    } finally {
      setBusy(false)
    }
  }

  return (
    <Modal
      open
      onClose={onClose}
      title="Reconciliar transação"
      description="Liga esta transação a um lançamento que já existe, sem duplicar."
      size="lg"
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            Cancelar
          </Button>
          {candidates?.length ? (
            <Button onClick={reconcile} loading={busy} disabled={!selectedId}>
              <Link2 size={15} aria-hidden="true" /> Vincular
            </Button>
          ) : (
            <Button onClick={onImport}>
              <Download size={15} aria-hidden="true" /> Importar como novo
            </Button>
          )}
        </>
      }
    >
      <p className="mb-3 text-sm text-muted">
        {tx.descricao || 'Transação'} · {formatDate(tx.data)} · {formatMoney(tx.valor)}
      </p>

      {loading ? <p className="py-3 text-sm text-muted">Buscando lançamentos parecidos…</p> : null}
      {error ? (
        <p className="rounded-control border border-terracota/30 bg-terracota/5 px-3 py-2 text-sm text-terracota-texto" role="alert">
          {error}
        </p>
      ) : null}

      {!loading && !error && candidates && candidates.length === 0 ? (
        <div className="py-3">
          <p className="text-sm text-muted">
            Nenhum lançamento parecido por aqui. Se ainda não lançou, importe como novo.
          </p>
        </div>
      ) : null}

      {candidates?.length ? (
        <fieldset>
          <legend className="mb-2 text-sm font-medium">Lançamentos parecidos</legend>
          <ul className="space-y-2">
            {candidates.map((candidate) => (
              <li key={candidate.transaction_id}>
                <label className="flex cursor-pointer items-start gap-3 rounded-control border border-linha p-3 text-sm transition-colors has-[:checked]:border-verde has-[:checked]:bg-verde-claro">
                  <input
                    type="radio"
                    name="candidate"
                    className="mt-1 h-4 w-4 accent-[var(--verde)]"
                    value={candidate.transaction_id}
                    checked={selectedId === candidate.transaction_id}
                    onChange={() => setSelectedId(candidate.transaction_id)}
                  />
                  <span className="flex-1">
                    <span className="flex flex-wrap items-baseline justify-between gap-2">
                      <span className="font-medium">{candidate.descricao || 'Lançamento manual'}</span>
                      <span className="num">{formatMoney(candidate.valor)}</span>
                    </span>
                    <span className="mt-0.5 block text-xs text-muted">
                      {formatDate(candidate.data)} · {candidate.categoria || 'Sem categoria'}
                    </span>
                  </span>
                </label>
              </li>
            ))}
          </ul>
        </fieldset>
      ) : null}
    </Modal>
  )
}

function tipoOf(tx) {
  return tx.tipo === 'credito' ? 'receita' : 'despesa'
}

function BulkImportModal({ transactions, categories, onClose, onDone }) {
  const toast = useToast()
  const [escopo, setEscopo] = useState('pessoal')
  const [categoryByTipo, setCategoryByTipo] = useState({})
  const [busy, setBusy] = useState(false)
  const [progress, setProgress] = useState(0)
  const [error, setError] = useState('')

  const tipos = [...new Set(transactions.map(tipoOf))]
  const optionsFor = (tipo) => categories.filter((category) => category.tipo === tipo && !category.oculta)

  async function submit(event) {
    event.preventDefault()
    const missing = tipos.find((tipo) => !categoryByTipo[tipo])
    if (missing) {
      setError(`Escolha uma categoria de ${missing === 'receita' ? 'receita' : 'despesa'}.`)
      return
    }
    setBusy(true)
    setError('')
    let ok = 0
    let failed = 0
    for (const tx of transactions) {
      try {
        await apiFetch('/banking/import', {
          method: 'POST',
          body: {
            bank_transaction_id: tx.id,
            category_id: categoryByTipo[tipoOf(tx)],
            escopo,
            valor: Math.abs(Number(tx.valor) || 0),
            data: tx.data,
            descricao: tx.descricao,
          },
        })
        ok += 1
      } catch {
        failed += 1
      }
      setProgress(ok + failed)
    }
    setBusy(false)
    if (failed) {
      toast.push(`${ok} importadas, ${failed} falharam. Tente as restantes de novo.`, 'error')
    } else {
      toast.push(`${ok} ${ok === 1 ? 'transação importada' : 'transações importadas'}.`)
    }
    onDone()
  }

  return (
    <Modal
      open
      onClose={onClose}
      title={`Importar ${transactions.length} transações`}
      description="Cada tipo recebe uma categoria. O escopo vale para todas; você pode ajustar depois em Lançamentos."
      size="md"
    >
      <form onSubmit={submit} className="space-y-4">
        <div className="max-h-40 overflow-y-auto border-y border-linha">
          <ul>
            {transactions.map((tx) => (
              <li key={tx.id} className="flex justify-between gap-3 border-b border-linha py-2 text-xs last:border-b-0">
                <span className="truncate">
                  {tx.descricao}
                  <span className="ml-1 text-muted">({tipoOf(tx) === 'receita' ? 'receita' : 'despesa'})</span>
                </span>
                <span className="num shrink-0">{formatMoney(tx.valor)}</span>
              </li>
            ))}
          </ul>
        </div>
        <div className="grid gap-4 sm:grid-cols-2">
          {tipos.map((tipo) => (
            <Field key={tipo} label={tipo === 'receita' ? 'Categoria das receitas' : 'Categoria das despesas'} htmlFor={`bulk-categoria-${tipo}`}>
              <Select
                id={`bulk-categoria-${tipo}`}
                value={categoryByTipo[tipo] || ''}
                onChange={(event) =>
                  setCategoryByTipo((current) => ({ ...current, [tipo]: event.target.value }))
                }
                required
              >
                <option value="">Escolha uma categoria</option>
                {optionsFor(tipo).map((category) => (
                  <option key={category.id} value={category.id}>
                    {category.nome}
                  </option>
                ))}
              </Select>
            </Field>
          ))}
          <Field label="Escopo" htmlFor="bulk-escopo">
            <Select id="bulk-escopo" value={escopo} onChange={(event) => setEscopo(event.target.value)}>
              <option value="pessoal">Pessoal</option>
              <option value="familia">Família</option>
            </Select>
          </Field>
        </div>

        {error ? (
          <p className="text-sm text-terracota-texto" role="alert">
            {error}
          </p>
        ) : null}

        {busy ? (
          <p className="text-xs text-muted" role="status">
            Importando {progress} de {transactions.length}…
          </p>
        ) : null}

        <div className="flex justify-end gap-2">
          <Button variant="secondary" onClick={onClose} disabled={busy}>
            Cancelar
          </Button>
          <Button type="submit" loading={busy}>
            Importar selecionadas
          </Button>
        </div>
      </form>
    </Modal>
  )
}
