import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { categories, transactions } from './fixtures'
import { findCall, mockApi, renderApp } from './utils'

function baseRoutes() {
  return {
    'GET /transactions': { items: transactions, total: transactions.length },
    'GET /categories': categories,
    'GET /dashboard': { membros: [{ member_id: 'u-ana', nome: 'Ana Souza', papel: 'admin' }] },
    'GET /alerts': { alertas: [] },
    'POST /ai/classify': { categoria_id: 'c-mercado', categoria: 'Mercado', mode: 'fallback' },
    'POST /transactions': { id: 't-new' },
    'PATCH /transactions/*': { ok: true },
    'DELETE /transactions/*': { ok: true },
  }
}

describe('Lançamentos', () => {
  it('lista os lançamentos do mês', async () => {
    mockApi(baseRoutes())
    renderApp({ route: '/transactions' })

    expect(await screen.findByRole('heading', { name: 'O que entrou e saiu' })).toBeInTheDocument()
    expect(screen.getAllByText('Mercado').length).toBeGreaterThan(0)
    expect(screen.getAllByText('Freela').length).toBeGreaterThan(0)
    expect(screen.getAllByText(/210,50/).length).toBeGreaterThan(0)
  })

  it('cria um lançamento com a categoria sugerida pela Jev', async () => {
    const user = userEvent.setup()
    const calls = mockApi(baseRoutes())
    renderApp({ route: '/transactions' })

    await user.click(await screen.findByRole('button', { name: 'Novo lançamento' }))
    const dialog = screen.getByRole('dialog')

    await user.type(within(dialog).getByLabelText('Descrição'), 'Padaria')
    await waitFor(
      () => expect(within(dialog).getByLabelText('Categoria')).toHaveValue('c-mercado'),
      { timeout: 3000 },
    )
    await user.type(within(dialog).getByLabelText('Valor'), '45,90')
    await user.click(within(dialog).getByRole('button', { name: 'Salvar lançamento' }))

    await waitFor(() => {
      const call = findCall(calls, 'POST', '/transactions')
      expect(call).toBeTruthy()
      expect(call.body).toMatchObject({
        tipo: 'despesa',
        escopo: 'familia',
        valor: 45.9,
        descricao: 'Padaria',
        category_id: 'c-mercado',
      })
    })
    const classify = calls.find((call) => call.path === '/ai/classify')
    expect(classify?.body).toEqual({ descricao: 'Padaria', tipo: 'despesa' })
  })

  it('esconde categorias ocultas e zera a categoria ao trocar o tipo', async () => {
    const user = userEvent.setup()
    mockApi(baseRoutes())
    renderApp({ route: '/transactions' })

    await screen.findByRole('heading', { name: 'O que entrou e saiu' })
    const filtro = screen.getByLabelText('Categoria')
    expect(within(filtro).queryByRole('option', { name: 'Lazer' })).not.toBeInTheDocument()

    await user.click(screen.getAllByRole('button', { name: 'Editar Mercado' })[0])
    const dialog = screen.getByRole('dialog')

    // Members load on edit so "Pago por" keeps the current selection.
    expect(within(dialog).getByRole('option', { name: 'Ana Souza' })).toBeInTheDocument()
    expect(within(dialog).queryByRole('option', { name: 'Lazer' })).not.toBeInTheDocument()

    await user.selectOptions(within(dialog).getByLabelText('Tipo'), 'receita')
    expect(within(dialog).getByLabelText('Categoria')).toHaveValue('')
    expect(within(dialog).getByRole('option', { name: 'Salário' })).toBeInTheDocument()
  })

  it('edita e exclui um lançamento', async () => {
    const user = userEvent.setup()
    const calls = mockApi(baseRoutes())
    renderApp({ route: '/transactions' })

    await screen.findByRole('heading', { name: 'O que entrou e saiu' })
    await user.click(screen.getAllByRole('button', { name: 'Editar Mercado' })[0])
    let dialog = screen.getByRole('dialog')
    const valor = within(dialog).getByLabelText('Valor')
    await user.clear(valor)
    await user.type(valor, '300')
    await user.click(within(dialog).getByRole('button', { name: 'Salvar alterações' }))

    await waitFor(() => {
      const call = findCall(calls, 'PATCH', '/transactions/t1')
      expect(call?.body.valor).toBe(300)
    })

    await user.click(screen.getAllByRole('button', { name: 'Excluir Mercado' })[0])
    dialog = screen.getByRole('dialog')
    await user.click(within(dialog).getByRole('button', { name: 'Excluir' }))
    await waitFor(() => expect(findCall(calls, 'DELETE', '/transactions/t1')).toBeTruthy())
  })
})
