import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { categories, pendingOccurrences, rules } from './fixtures'
import { findCall, mockApi, renderApp } from './utils'

function routes() {
  return {
    'GET /recurring/pending': { items: pendingOccurrences },
    'GET /recurring/rules': { rules },
    'GET /categories': categories,
    'GET /alerts': { alertas: [] },
    'POST /recurring/occurrences/*/confirm': { ok: true },
    'POST /recurring/occurrences/*/ignore': { ok: true },
    'POST /recurring/rules': { id: 'r-new' },
    'PATCH /recurring/rules/*': { ok: true },
  }
}

describe('Recorrentes', () => {
  it('confirma e ignora uma conta pendente', async () => {
    const user = userEvent.setup()
    const calls = mockApi(routes())
    renderApp({ route: '/recurring' })

    const fila = await screen.findByRole('region', { name: 'Para confirmar' })
    const aluguel = within(fila).getByText('Aluguel').closest('article')
    await user.click(within(aluguel).getByRole('button', { name: 'Confirmar' }))
    await waitFor(() =>
      expect(findCall(calls, 'POST', '/recurring/occurrences/occ-1/confirm')).toBeTruthy(),
    )

    const internet = within(fila).getByText('Internet').closest('article')
    await user.click(within(internet).getByRole('button', { name: 'Ignorar' }))
    await waitFor(() =>
      expect(findCall(calls, 'POST', '/recurring/occurrences/occ-2/ignore')).toBeTruthy(),
    )
  })

  it('confirma com um valor diferente', async () => {
    const user = userEvent.setup()
    const calls = mockApi(routes())
    renderApp({ route: '/recurring' })

    const fila = await screen.findByRole('region', { name: 'Para confirmar' })
    const aluguel = within(fila).getByText('Aluguel').closest('article')
    await user.click(within(aluguel).getByRole('button', { name: 'Outro valor' }))

    const dialog = screen.getByRole('dialog')
    const valor = within(dialog).getByLabelText('Valor deste mês')
    await user.clear(valor)
    await user.type(valor, '2600')
    await user.click(within(dialog).getByRole('button', { name: 'Confirmar' }))

    await waitFor(() => {
      const call = findCall(calls, 'POST', '/recurring/occurrences/occ-1/confirm')
      expect(call?.body).toEqual({ valor: 2600 })
    })
  })

  it('esconde categorias ocultas e zera a categoria ao trocar o tipo', async () => {
    const user = userEvent.setup()
    mockApi(routes())
    renderApp({ route: '/recurring' })

    await screen.findByRole('heading', { name: 'O que volta todo mês' })
    await user.click(screen.getByRole('button', { name: 'Nova regra' }))
    const dialog = screen.getByRole('dialog')

    expect(within(dialog).queryByRole('option', { name: 'Lazer' })).not.toBeInTheDocument()
    await user.selectOptions(within(dialog).getByLabelText('Categoria'), 'c-mercado')
    await user.selectOptions(within(dialog).getByLabelText('Tipo'), 'receita')

    expect(within(dialog).getByLabelText('Categoria')).toHaveValue('')
    expect(within(dialog).getByRole('option', { name: 'Salário' })).toBeInTheDocument()
  })

  it('desativa uma regra sem apagar o histórico', async () => {
    const user = userEvent.setup()
    const calls = mockApi(routes())
    renderApp({ route: '/recurring' })

    const regra = within(await screen.findByRole('region', { name: 'Suas regras' }))
      .getByText('Aluguel')
      .closest('li')
    await user.click(within(regra).getByRole('button', { name: 'Desativar' }))

    await waitFor(() => {
      const call = findCall(calls, 'PATCH', '/recurring/rules/r1')
      expect(call?.body).toEqual({ ativo: false })
    })
    expect(screen.queryByText('Excluir')).not.toBeInTheDocument()
  })
})
