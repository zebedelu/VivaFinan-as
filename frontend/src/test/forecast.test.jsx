import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { forecastPayload } from './fixtures'
import { mockApi, renderApp } from './utils'

describe('Previsões', () => {
  it('mostra a estimativa anual e o detalhamento mês a mês', async () => {
    mockApi({
      'GET /forecast': forecastPayload(),
      'GET /alerts': { alertas: [] },
    })
    renderApp({ route: '/forecast' })

    expect(await screen.findByRole('heading', { name: 'Os próximos doze meses' })).toBeInTheDocument()
    expect(screen.getByText('Estimativa')).toBeInTheDocument()
    expect(screen.getByText(/52\.800,00/)).toBeInTheDocument()
    expect(screen.getByText(/Como calculamos/)).toBeInTheDocument()
    expect(screen.getAllByText(/Receitas/).length).toBeGreaterThan(0)
  })

  it('troca para a previsão pessoal', async () => {
    const user = userEvent.setup()
    const calls = mockApi({
      'GET /forecast': forecastPayload(),
      'GET /alerts': { alertas: [] },
    })
    renderApp({ route: '/forecast' })

    await screen.findByRole('heading', { name: 'Os próximos doze meses' })
    await user.click(screen.getByRole('button', { name: 'Pessoal' }))

    await waitFor(() => {
      expect(calls.some((call) => call.url.includes('escopo=pessoal'))).toBe(true)
    })
  })
})
