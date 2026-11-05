import { ArrowDownLeft, ArrowUpRight, Link2, RotateCcw, Ban, Download } from 'lucide-react'
import { formatDate, formatSignedMoney } from '../lib/format'
import { BANK_STATUS } from '../lib/labels'
import Badge from './Badge'
import EmptyState from './EmptyState'

export default function BankTxTable({
  items = [],
  selected = new Set(),
  onToggle,
  onImport,
  onReconcile,
  onIgnore,
  onUnignore,
  busyId,
}) {
  if (!items.length) {
    return (
      <EmptyState
        title="Nenhuma transação neste filtro"
        description="Sincronize a conta ou troque o mês e o status para ver o extrato."
      />
    )
  }

  return (
    <>
      <table className="hidden w-full text-sm md:table">
        <caption className="sr-only">Transações bancárias</caption>
        <thead>
          <tr className="border-b border-linha text-left text-xs text-muted">
            <th scope="col" className="py-2 pr-2 font-medium">
              <span className="sr-only">Selecionar</span>
            </th>
            <th scope="col" className="py-2 pr-3 font-medium">Data</th>
            <th scope="col" className="py-2 pr-3 font-medium">Descrição</th>
            <th scope="col" className="py-2 pr-3 font-medium">Categoria do banco</th>
            <th scope="col" className="py-2 pr-3 font-medium">Status</th>
            <th scope="col" className="py-2 pr-3 text-right font-medium">Valor</th>
            <th scope="col" className="py-2 text-right font-medium">
              <span className="sr-only">Ações</span>
            </th>
          </tr>
        </thead>
        <tbody>
          {items.map((tx) => {
            const status = BANK_STATUS[tx.status] || BANK_STATUS.pendente_importacao
            const pending = tx.status === 'pendente_importacao'
            const ignored = tx.status === 'ignorada'
            const receita = tx.tipo === 'credito'
            return (
              <tr key={tx.id} className="border-b border-linha align-middle last:border-b-0">
                <td className="py-3 pr-2">
                  {pending ? (
                    <input
                      type="checkbox"
                      className="h-4 w-4 accent-[var(--verde)]"
                      checked={selected.has(tx.id)}
                      onChange={() => onToggle(tx.id)}
                      aria-label={`Selecionar ${tx.descricao}`}
                    />
                  ) : null}
                </td>
                <td className="num whitespace-nowrap py-3 pr-3 text-xs text-muted">{formatDate(tx.data)}</td>
                <td className="py-3 pr-3">
                  <span className="flex items-center gap-1.5">
                    {receita ? (
                      <ArrowUpRight size={13} className="text-verde-texto" aria-hidden="true" />
                    ) : (
                      <ArrowDownLeft size={13} className="text-terracota-texto" aria-hidden="true" />
                    )}
                    {tx.descricao || 'Transação'}
                  </span>
                </td>
                <td className="py-3 pr-3 text-xs text-muted">{tx.categoria_bancaria || '—'}</td>
                <td className="py-3 pr-3">
                  <Badge tone={status.tone}>{status.label}</Badge>
                </td>
                <td className="py-3 pr-3 text-right">
                  <span className={`num ${receita ? 'text-verde-texto' : 'text-terracota-texto'}`}>
                    {formatSignedMoney(tx.valor, receita ? 'receita' : 'despesa')}
                  </span>
                </td>
                <td className="py-3">
                  <div className="flex flex-wrap justify-end gap-1">
                    {pending ? (
                      <>
                        <button
                          type="button"
                          className="btn-ghost p-1.5"
                          onClick={() => onImport(tx)}
                          disabled={busyId === tx.id}
                          aria-label={`Importar ${tx.descricao}`}
                          title="Importar"
                        >
                          <Download size={15} aria-hidden="true" />
                        </button>
                        <button
                          type="button"
                          className="btn-ghost p-1.5"
                          onClick={() => onReconcile(tx)}
                          disabled={busyId === tx.id}
                          aria-label={`Reconciliar ${tx.descricao}`}
                          title="Reconciliar"
                        >
                          <Link2 size={15} aria-hidden="true" />
                        </button>
                        <button
                          type="button"
                          className="btn-ghost p-1.5"
                          onClick={() => onIgnore(tx)}
                          disabled={busyId === tx.id}
                          aria-label={`Ignorar ${tx.descricao}`}
                          title="Ignorar"
                        >
                          <Ban size={15} aria-hidden="true" />
                        </button>
                      </>
                    ) : null}
                    {ignored ? (
                      <button
                        type="button"
                        className="btn-ghost p-1.5"
                        onClick={() => onUnignore(tx)}
                        disabled={busyId === tx.id}
                        aria-label={`Desfazer ignorar ${tx.descricao}`}
                        title="Desfazer"
                      >
                        <RotateCcw size={15} aria-hidden="true" />
                      </button>
                    ) : null}
                  </div>
                </td>
              </tr>
            )
          })}
        </tbody>
      </table>

      <ul className="md:hidden">
        {items.map((tx) => {
          const status = BANK_STATUS[tx.status] || BANK_STATUS.pendente_importacao
          const pending = tx.status === 'pendente_importacao'
          const ignored = tx.status === 'ignorada'
          const receita = tx.tipo === 'credito'
          return (
            <li key={tx.id} className="border-b border-linha py-3 last:border-b-0">
              <div className="flex items-start gap-3">
                {pending ? (
                  <input
                    type="checkbox"
                    className="mt-1 h-4 w-4 accent-[var(--verde)]"
                    checked={selected.has(tx.id)}
                    onChange={() => onToggle(tx.id)}
                    aria-label={`Selecionar ${tx.descricao}`}
                  />
                ) : null}
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-medium">{tx.descricao || 'Transação'}</p>
                  <p className="mt-0.5 flex flex-wrap items-center gap-x-2 text-xs text-muted">
                    <span className="num">{formatDate(tx.data)}</span>
                    <span>{tx.categoria_bancaria || 'Sem categoria'}</span>
                    <Badge tone={status.tone}>{status.label}</Badge>
                  </p>
                </div>
                <span className={`num shrink-0 text-sm ${receita ? 'text-verde-texto' : 'text-terracota-texto'}`}>
                  {formatSignedMoney(tx.valor, receita ? 'receita' : 'despesa')}
                </span>
              </div>
              {pending || ignored ? (
                <div className="mt-2 flex flex-wrap gap-2 pl-0">
                  {pending ? (
                    <>
                      <button type="button" className="text-xs text-verde-texto" onClick={() => onImport(tx)}>
                        Importar
                      </button>
                      <button type="button" className="text-xs text-muted" onClick={() => onReconcile(tx)}>
                        Reconciliar
                      </button>
                      <button type="button" className="text-xs text-muted" onClick={() => onIgnore(tx)}>
                        Ignorar
                      </button>
                    </>
                  ) : (
                    <button type="button" className="text-xs text-muted" onClick={() => onUnignore(tx)}>
                      Desfazer
                    </button>
                  )}
                </div>
              ) : null}
            </li>
          )
        })}
      </ul>
    </>
  )
}
