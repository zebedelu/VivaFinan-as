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
  token: 'tok-link',
}

describe('Convite', () => {
  it('pede login antes de aceitar', async () => {
    mockApi({})
    renderApp({ route: '/invite/tok-link', session: null, profile: null, family: null })
    expect(await screen.findByRole('heading', { name: 'Entre para aceitar' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Entrar' })).toHaveAttribute(
      'href',
      '/login?next=%2Finvite%2Ftok-link',
    )
  })

  it('aceita o convite com o token do link', async () => {
    const user = userEvent.setup()
    const calls = mockApi({
      'GET /invites/mine': invite,
      'POST /invites/accept': { profile: { id: 'u-ana' } },
    })
    const { sessionValue } = renderApp({ route: '/invite/tok-link' })

    expect(await screen.findByRole('heading', { name: 'Família Lima' })).toBeInTheDocument()
    const nameInput = screen.getByLabelText('Como você quer ser chamado')
    await user.clear(nameInput)
    await user.type(nameInput, 'Ana Lima')
    await user.click(screen.getByRole('button', { name: 'Aceitar convite' }))

    await waitFor(() => {
      const call = findCall(calls, 'POST', '/invites/accept')
      expect(call?.body).toEqual({ token: 'tok-link', nome: 'Ana Lima' })
    })
    expect(sessionValue.refresh).toHaveBeenCalled()
  })
})
