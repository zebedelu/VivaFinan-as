import { screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { dashboardPayload } from './fixtures'
import { json, mockApi, renderApp } from './utils'

describe('Painel', () => {
  it('mostra saldo, acumulado, categorias, metas e pendências', async () => {
    const payload = dashboardPayload()
    mockApi({
      'GET /dashboard': payload,
      'GET /alerts': { alertas: payload.alertas },
    })

    renderApp({ route: '/' })

    expect(await screen.findByText('Saldo do mês')).toBeInTheDocument()
    expect(screen.getByText(/4\.200,00/)).toBeInTheDocument()
    expect(await screen.findByRole('heading', { name: 'Família Souza' })).toBeInTheDocument()
    expect(screen.getByText('Moradia')).toBeInTheDocument()
    expect(screen.getByText('Reserva de emergência')).toBeInTheDocument()
    expect(screen.getByText('Aluguel')).toBeInTheDocument()
    expect(screen.getByText('Revise as assinaturas')).toBeInTheDocument()
    expect(screen.getByText('Aluguel vence em 2 dias')).toBeInTheDocument()
    expect(screen.getByRole('img', { name: /Receitas e despesas nos últimos 6 meses/ })).toBeInTheDocument()
  })

  it('explica o estado 503 do painel', async () => {
    mockApi({
      'GET /dashboard': () =>
        json(503, { error: { code: 'servico_indisponivel', message: 'Indisponível' } }),
      'GET /alerts': { alertas: [] },
    })

    renderApp({ route: '/' })

    expect(await screen.findByText('Painel indisponível')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Tentar de novo' })).toBeInTheDocument()
  })
})
