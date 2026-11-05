import { Pencil, Trash2 } from 'lucide-react'
import { formatDate, formatMoney } from '../lib/format'
import { ESCOPO_LABEL, ORIGEM_LABEL, TIPO_LABEL } from '../lib/labels'
import Badge from './Badge'
import EmptyState from './EmptyState'

export default function TransactionTable({ items = [], onEdit, onDelete, busyId }) {
  if (!items.length) {
    return (
      <EmptyState
        title="Nenhum lançamento neste filtro"
        description="Ajuste o mês ou registre uma receita ou despesa para começar."
      />
    )
  }

  return (
    <>
      <table className="hidden w-full text-sm md:table">
        <caption className="sr-only">Lançamentos do período</caption>
        <thead>
          <tr className="border-b border-linha text-left text-xs text-muted">
            <th scope="col" className="py-2 pr-3 font-medium">Data</th>
            <th scope="col" className="py-2 pr-3 font-medium">Descrição</th>
            <th scope="col" className="py-2 pr-3 font-medium">Categoria</th>
            <th scope="col" className="py-2 pr-3 font-medium">Escopo</th>
            <th scope="col" className="py-2 pr-3 font-medium">Origem</th>
            <th scope="col" className="py-2 pr-3 text-right font-medium">Valor</th>
            <th scope="col" className="py-2 text-right font-medium">
              <span className="sr-only">Ações</span>
            </th>
          </tr>
        </thead>
        <tbody>
          {items.map((item) => (
            <tr key={item.id} className="border-b border-linha align-middle last:border-b-0">
              <td className="num whitespace-nowrap py-3 pr-3 text-xs text-muted">{formatDate(item.data)}</td>
              <td className="py-3 pr-3">
                <span className="font-medium">{item.descricao || TIPO_LABEL[item.tipo]}</span>
                {item.pago_por_nome ? (
                  <span className="block text-xs text-muted">Pago por {item.pago_por_nome}</span>
                ) : null}
              </td>
              <td className="py-3 pr-3 text-muted">{item.categoria || 'Sem categoria'}</td>
              <td className="py-3 pr-3">
                <Badge tone={item.escopo === 'familia' ? 'verde' : 'neutro'}>
                  {ESCOPO_LABEL[item.escopo] || item.escopo}
                </Badge>
              </td>
              <td className="py-3 pr-3 text-xs text-muted">{ORIGEM_LABEL[item.origem] || item.origem}</td>
              <td className="py-3 pr-3 text-right">
                <span className={`num ${item.tipo === 'receita' ? 'text-verde-texto' : 'text-terracota-texto'}`}>
                  {item.tipo === 'receita' ? '+' : '−'}
                  {formatMoney(item.valor)}
                </span>
              </td>
              <td className="py-3 text-right">
                <div className="flex justify-end gap-1">
                  <button
                    type="button"
                    className="btn-ghost p-1.5"
                    onClick={() => onEdit(item)}
                    aria-label={`Editar ${item.descricao || 'lançamento'}`}
                    disabled={busyId === item.id}
                  >
                    <Pencil size={15} aria-hidden="true" />
                  </button>
                  <button
                    type="button"
                    className="btn-ghost p-1.5 text-terracota-texto"
                    onClick={() => onDelete(item)}
                    aria-label={`Excluir ${item.descricao || 'lançamento'}`}
                    disabled={busyId === item.id}
                  >
                    <Trash2 size={15} aria-hidden="true" />
                  </button>
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      <ul className="md:hidden">
        {items.map((item) => (
          <li key={item.id} className="border-b border-linha py-3 last:border-b-0">
            <div className="flex items-start justify-between gap-3">
              <div className="min-w-0">
                <p className="truncate font-medium">{item.descricao || TIPO_LABEL[item.tipo]}</p>
                <p className="mt-0.5 flex flex-wrap gap-x-2 text-xs text-muted">
                  <span className="num">{formatDate(item.data)}</span>
                  <span>{item.categoria || 'Sem categoria'}</span>
                  <span>{ESCOPO_LABEL[item.escopo] || item.escopo}</span>
                  {item.origem === 'pluggy' ? <span>Banco</span> : null}
                </p>
              </div>
              <span className={`num shrink-0 text-sm ${item.tipo === 'receita' ? 'text-verde-texto' : 'text-terracota-texto'}`}>
                {item.tipo === 'receita' ? '+' : '−'}
                {formatMoney(item.valor)}
              </span>
            </div>
            <div className="mt-1 flex gap-1">
              <button
                type="button"
                className="inline-flex items-center gap-1 px-1 py-1 text-xs text-muted"
                onClick={() => onEdit(item)}
                disabled={busyId === item.id}
              >
                <Pencil size={12} aria-hidden="true" /> Editar
              </button>
              <button
                type="button"
                className="inline-flex items-center gap-1 px-1 py-1 text-xs text-terracota-texto"
                onClick={() => onDelete(item)}
                disabled={busyId === item.id}
              >
                <Trash2 size={12} aria-hidden="true" /> Excluir
              </button>
            </div>
          </li>
        ))}
      </ul>
    </>
  )
}
