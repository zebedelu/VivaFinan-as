import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { goals } from './fixtures'
import { findCall, mockApi, renderApp } from './utils'

describe('Metas', () => {
  it('mostra progresso e registra uma contribuição', async () => {
    const user = userEvent.setup()
    const calls = mockApi({
      'GET /goals': { goals },
      'GET /alerts': { alertas: [] },
      'POST /goals/g1/contributions': { ok: true },
    })
    renderApp({ route: '/goals' })

    expect(await screen.findByText('Reserva de emergência')).toBeInTheDocument()
    expect(screen.getAllByText(/1\.200,00/).length).toBeGreaterThan(0)

    const card = screen.getByText('Reserva de emergência').closest('article')
    await user.click(within(card).getByRole('button', { name: 'Contribuir' }))

    const dialog = screen.getByRole('dialog')
    await user.type(within(dialog).getByLabelText('Valor'), '300')
    await user.click(within(dialog).getByRole('button', { name: 'Contribuir' }))

    await waitFor(() => {
      const call = findCall(calls, 'POST', '/goals/g1/contributions')
      expect(call?.body).toMatchObject({ valor: 300 })
      expect(call?.body.data).toMatch(/^\d{4}-\d{2}-\d{2}$/)
    })
  })

  it('trata progresso como percentual quando não há contribuições', async () => {
    mockApi({
      'GET /goals': {
        goals: [
          {
            id: 'g3',
            titulo: 'Meta sem contribuições',
            valor_alvo: 1000,
            prazo: null,
            status: 'em_andamento',
            descricao: null,
            member_id: null,
            member_nome: null,
            criado_por: 'u-ana',
            criado_por_nome: 'Ana Souza',
            progresso: 40,
          },
        ],
      },
      'GET /alerts': { alertas: [] },
    })
    renderApp({ route: '/goals' })

    expect(await screen.findByText('Meta sem contribuições')).toBeInTheDocument()
    expect(screen.getAllByText(/400,00/).length).toBeGreaterThan(0)
    expect(screen.getByText('40%')).toBeInTheDocument()
  })

  it('só mostra excluir para a pessoa que criou a meta', async () => {
    mockApi({
      'GET /goals': { goals },
      'GET /alerts': { alertas: [] },
    })
    renderApp({ route: '/goals' })

    await screen.findByText('Reserva de emergência')
    const own = screen.getByText('Reserva de emergência').closest('article')
    const other = screen.getByText('Viagem de fim de ano').closest('article')

    expect(within(own).getByRole('button', { name: 'Excluir' })).toBeInTheDocument()
    expect(within(other).queryByRole('button', { name: 'Excluir' })).not.toBeInTheDocument()
  })
})
