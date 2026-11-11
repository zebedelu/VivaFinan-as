import { act, render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, describe, expect, it, vi } from 'vitest'
import PluggyConnect from '../components/PluggyConnect'
import { ToastProvider } from '../components/Toast'
import { bankAccounts, bankConnections, bankTransactions, categories } from './fixtures'
import { findCall, json, mockApi, renderApp } from './utils'

function routes() {
  return {
    'GET /banking/connections': { connections: bankConnections },
    'GET /banking/accounts': { accounts: bankAccounts },
    'GET /banking/transactions': { items: bankTransactions, total: bankTransactions.length },
    'GET /categories': categories,
    'GET /alerts': { alertas: [] },
    'POST /ai/classify': { categoria_id: 'c-mercado', categoria: 'Mercado', mode: 'fallback' },
    'POST /banking/import': { ok: true },
    'POST /banking/ignore': { ok: true },
    'POST /banking/unignore': { ok: true },
    'POST /banking/reconcile': { ok: true },
    'GET /banking/reconcile-candidates': {
      candidates: [
        {
          transaction_id: 't9',
          valor: -23,
          data: '2026-11-03',
          descricao: 'Uber do trabalho',
          categoria: 'Transporte',
          categoria_id: 'c-transporte',
        },
      ],
    },
    'POST /banking/connect_token': { accessToken: 'tok-1', clientUserId: 'u-ana' },
    'POST /banking/connections': () =>
      json(503, { error: { code: 'pluggy_indisponivel', message: 'Sem chave' } }),
  }
}

afterEach(() => {
  delete window.PluggyConnect
})

describe('Extrato bancário', () => {
  it('importa uma transação com a categoria sugerida', async () => {
    const user = userEvent.setup()
    const calls = mockApi(routes())
    renderApp({ route: '/banking' })

    expect((await screen.findAllByText('Padaria')).length).toBeGreaterThan(0)
    // Debit comes from `tipo`, not from the sign of `valor`.
    expect(screen.getAllByText(/−R\$\s45,90/).length).toBeGreaterThan(0)
    await user.click(screen.getAllByRole('button', { name: 'Importar Padaria' })[0])

    const dialog = screen.getByRole('dialog')
    await waitFor(
      () => expect(within(dialog).getByLabelText('Categoria')).toHaveValue('c-mercado'),
      { timeout: 3000 },
    )
    await user.click(within(dialog).getByRole('button', { name: 'Importar' }))

    await waitFor(() => {
      const call = findCall(calls, 'POST', '/banking/import')
      expect(call?.body).toMatchObject({
        bank_transaction_id: 'bt1',
        category_id: 'c-mercado',
        escopo: 'pessoal',
        valor: 45.9,
      })
    })
  })

  it('ignora e desfaz o ignorar de uma transação', async () => {
    const user = userEvent.setup()
    const calls = mockApi(routes())
    renderApp({ route: '/banking' })

    expect((await screen.findAllByText('Farmácia')).length).toBeGreaterThan(0)
    await user.click(screen.getAllByRole('button', { name: 'Ignorar Farmácia' })[0])
    await waitFor(() =>
      expect(findCall(calls, 'POST', '/banking/ignore')?.body).toEqual({
        bank_transaction_id: 'bt2',
      }),
    )

    await user.click(screen.getAllByRole('button', { name: 'Desfazer ignorar Mercado antigo' })[0])
    await waitFor(() =>
      expect(findCall(calls, 'POST', '/banking/unignore')?.body).toEqual({
        bank_transaction_id: 'bt4',
      }),
    )
  })

  it('reconcilia uma transação com um lançamento parecido', async () => {
    const user = userEvent.setup()
    const calls = mockApi(routes())
    renderApp({ route: '/banking' })

    expect((await screen.findAllByText('Uber')).length).toBeGreaterThan(0)
    await user.click(screen.getAllByRole('button', { name: 'Reconciliar Uber' })[0])

    const dialog = await screen.findByRole('dialog')
    expect(await within(dialog).findByText('Uber do trabalho')).toBeInTheDocument()
    await user.click(within(dialog).getByRole('button', { name: /Vincular/ }))

    await waitFor(() =>
      expect(findCall(calls, 'POST', '/banking/reconcile')?.body).toEqual({
        bank_transaction_id: 'bt3',
        transaction_id: 't9',
      }),
    )
  })

  it('importa um crédito usando categoria de receita', async () => {
    const user = userEvent.setup()
    const calls = mockApi(routes())
    renderApp({ route: '/banking' })

    expect((await screen.findAllByText('Salário')).length).toBeGreaterThan(0)
    await user.click(screen.getAllByRole('button', { name: 'Importar Salário' })[0])

    const dialog = screen.getByRole('dialog')
    const categoria = within(dialog).getByLabelText('Categoria')
    expect(within(categoria).getByRole('option', { name: 'Salário' })).toBeInTheDocument()
    expect(within(categoria).queryByRole('option', { name: 'Mercado' })).not.toBeInTheDocument()
    expect(within(categoria).queryByRole('option', { name: 'Lazer' })).not.toBeInTheDocument()

    await user.selectOptions(categoria, 'c-salario')
    await user.click(within(dialog).getByRole('button', { name: 'Importar' }))

    await waitFor(() => {
      const call = findCall(calls, 'POST', '/banking/import')
      expect(call?.body).toMatchObject({
        bank_transaction_id: 'bt5',
        category_id: 'c-salario',
        valor: 1500,
      })
    })
  })

  it('importa em lote separando a categoria por tipo', async () => {
    const user = userEvent.setup()
    const calls = mockApi(routes())
    renderApp({ route: '/banking' })

    expect((await screen.findAllByText('Padaria')).length).toBeGreaterThan(0)
    await user.click(screen.getAllByRole('checkbox', { name: 'Selecionar Padaria' })[0])
    await user.click(screen.getAllByRole('checkbox', { name: 'Selecionar Salário' })[0])
    await user.click(screen.getByRole('button', { name: /Importar selecionadas/ }))

    const dialog = screen.getByRole('dialog')
    await user.selectOptions(within(dialog).getByLabelText('Categoria das despesas'), 'c-mercado')
    await user.selectOptions(within(dialog).getByLabelText('Categoria das receitas'), 'c-salario')
    await user.click(within(dialog).getByRole('button', { name: 'Importar selecionadas' }))

    await waitFor(() => {
      const imports = calls.filter((call) => call.method === 'POST' && call.path === '/banking/import')
      expect(imports).toHaveLength(2)
      expect(imports.find((call) => call.body.bank_transaction_id === 'bt1')?.body.category_id).toBe('c-mercado')
      expect(imports.find((call) => call.body.bank_transaction_id === 'bt5')?.body.category_id).toBe('c-salario')
    })
  })

  it('habilita a conexão real quando o backend está configurado', async () => {
    mockApi(routes())
    renderApp({ route: '/banking' })

    expect((await screen.findAllByText('Padaria')).length).toBeGreaterThan(0)
    expect(screen.getByRole('button', { name: 'Conectar banco' })).toBeEnabled()
    expect(screen.queryByText(/ainda não está habilitada/i)).not.toBeInTheDocument()
    expect(screen.getByText(/A conexão de demonstração continua disponível/i)).toBeInTheDocument()
  })

  it('pede o token e abre o widget da Pluggy sem sandbox', async () => {
    const user = userEvent.setup()
    const calls = mockApi(routes())
    let widgetOptions
    window.PluggyConnect = vi.fn(function (options) {
      widgetOptions = options
    })
    renderApp({ route: '/banking' })

    expect((await screen.findAllByText('Padaria')).length).toBeGreaterThan(0)
    await user.click(screen.getByRole('button', { name: 'Conectar banco' }))

    await waitFor(() => expect(findCall(calls, 'POST', '/banking/connect_token')).toBeTruthy())
    await waitFor(() => expect(widgetOptions).toBeTruthy())
    expect(window.PluggyConnect).toHaveBeenCalledTimes(1)
    expect(widgetOptions.connectToken).toBe('tok-1')
    expect(widgetOptions.includeSandbox).toBe(false)
    expect(typeof widgetOptions.onSuccess).toBe('function')
    expect(typeof widgetOptions.onError).toBe('function')
    expect(typeof widgetOptions.onClose).toBe('function')
  })

  it('salva a conexão aprovada no widget e recarrega a lista', async () => {
    const user = userEvent.setup()
    const calls = mockApi({
      ...routes(),
      'POST /banking/connections': () => json(201, { connection: { id: 'bc2' } }),
    })
    let widgetOptions
    window.PluggyConnect = vi.fn(function (options) {
      widgetOptions = options
    })
    renderApp({ route: '/banking' })

    expect((await screen.findAllByText('Padaria')).length).toBeGreaterThan(0)
    const connectionsBefore = calls.filter(
      (call) => call.method === 'GET' && call.path === '/banking/connections',
    ).length

    await user.click(screen.getByRole('button', { name: 'Conectar banco' }))
    await waitFor(() => expect(widgetOptions).toBeTruthy())

    await act(async () => {
      await widgetOptions.onSuccess({
        item: { id: 'item-1', connector: { name: 'Banco Teste' } },
      })
    })

    expect(findCall(calls, 'POST', '/banking/connections')?.body).toEqual({
      pluggy_connection_id: 'item-1',
      institution_name: 'Banco Teste',
      account_type: null,
    })
    await waitFor(() => {
      const connectionsAfter = calls.filter(
        (call) => call.method === 'GET' && call.path === '/banking/connections',
      ).length
      expect(connectionsAfter).toBeGreaterThan(connectionsBefore)
    })
    expect(await screen.findByText(/Banco conectado: Banco Teste/i)).toBeInTheDocument()
  })

  it('mantém o botão desabilitado quando a integração está indisponível', () => {
    render(
      <ToastProvider>
        <PluggyConnect unavailable />
      </ToastProvider>,
    )

    expect(screen.getByRole('button', { name: 'Conectar banco' })).toBeDisabled()
    expect(screen.getByText(/Integração bancária indisponível/i)).toBeInTheDocument()
    expect(screen.getByText(/A conexão de demonstração continua disponível/i)).toBeInTheDocument()
  })

  it('mostra erro e libera o botão quando o CDN do widget falha', async () => {
    const user = userEvent.setup()
    mockApi(routes())
    const appendChild = document.head.appendChild.bind(document.head)
    let appendedScript
    vi.spyOn(document.head, 'appendChild').mockImplementation((node) => {
      if (node?.tagName === 'SCRIPT') {
        appendedScript = node
        node.dispatchEvent(new Event('error'))
        return node
      }
      return appendChild(node)
    })
    renderApp({ route: '/banking' })

    expect((await screen.findAllByText('Padaria')).length).toBeGreaterThan(0)
    await user.click(screen.getByRole('button', { name: 'Conectar banco' }))

    expect(await screen.findByRole('alert')).toHaveTextContent(/widget do banco/i)
    expect(screen.getByRole('button', { name: 'Conectar banco' })).toBeEnabled()
    expect(appendedScript?.src).toBe(
      'https://cdn.pluggy.ai/pluggy-connect/latest/pluggy-connect.js',
    )
  })
})
