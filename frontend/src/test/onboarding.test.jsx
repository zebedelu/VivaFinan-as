import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { findCall, mockApi, renderApp } from './utils'

const invite = {
  invite_id: 'i1',
  family_id: 'fam-1',
  family_nome: 'Família Lima',
  nome: null,
  email: 'ana@demo.vivafinancas.app',
  token: 'tok-1',
}

describe('Onboarding', () => {
  it('aceita o convite existente antes de criar família', async () => {
    const user = userEvent.setup()
    const calls = mockApi({
      'GET /invites/mine': invite,
      'POST /invites/accept': { profile: { id: 'u-ana' } },
    })
    const { sessionValue } = renderApp({ route: '/onboarding', profile: null, family: null })

    expect(await screen.findByText('Família Lima')).toBeInTheDocument()
    await user.type(screen.getByLabelText('Como você quer ser chamado'), 'Ana Lima')
    await user.click(screen.getByRole('button', { name: 'Aceitar convite' }))

    await waitFor(() => {
      const call = findCall(calls, 'POST', '/invites/accept')
      expect(call?.body).toEqual({ token: 'tok-1', nome: 'Ana Lima' })
    })
    expect(sessionValue.refresh).toHaveBeenCalled()
    expect(calls.some((call) => call.path === '/onboarding')).toBe(false)
  })

  it('cria a família quando não há convite', async () => {
    const user = userEvent.setup()
    const calls = mockApi({
      'GET /invites/mine': null,
      'POST /onboarding': { profile: { id: 'u-ana' }, family: { id: 'fam-1' } },
    })
    renderApp({ route: '/onboarding', profile: null, family: null })

    expect(await screen.findByText('Vamos montar sua família')).toBeInTheDocument()
    await user.type(screen.getByLabelText('Seu nome'), 'Ana Souza')
    await user.type(screen.getByLabelText('Nome da família'), 'Família Souza')
    await user.click(screen.getByRole('button', { name: 'Criar família' }))

    await waitFor(() => {
      const call = findCall(calls, 'POST', '/onboarding')
      expect(call?.body).toEqual({ nome: 'Ana Souza', nome_familia: 'Família Souza' })
    })
  })
})
