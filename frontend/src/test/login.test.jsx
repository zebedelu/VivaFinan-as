import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { findCall, mockApi, renderApp } from './utils'

describe('Login', () => {
  it('entra como Ana pela credencial de demonstração', async () => {
    const user = userEvent.setup()
    mockApi({})
    const { sessionValue } = renderApp({ route: '/login', session: null, profile: null, family: null })

    expect(await screen.findByRole('heading', { name: 'Bem-vindo de volta' })).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Entrar como Ana' }))

    expect(sessionValue.signIn).toHaveBeenCalledWith('ana@demo.vivafinancas.app', 'Demo@2026!')
  })

  it('mostra erro claro quando a senha não confere', async () => {
    const user = userEvent.setup()
    mockApi({})
    const signIn = async () => ({ error: { message: 'Invalid login credentials' } })
    renderApp({
      route: '/login',
      session: null,
      profile: null,
      family: null,
      overrides: { signIn },
    })

    await user.type(await screen.findByLabelText('E-mail'), 'ana@exemplo.com')
    await user.type(screen.getByLabelText('Senha'), 'errada123')
    await user.keyboard('{Enter}')

    expect(await screen.findByRole('alert')).toHaveTextContent('E-mail ou senha incorretos')
  })

  it('cria a família depois do cadastro', async () => {
    const user = userEvent.setup()
    const calls = mockApi({
      'GET /invites/mine': null,
      'POST /onboarding': { profile: { id: 'u-nova' }, family: { id: 'fam-nova' } },
    })
    const { sessionValue } = renderApp({ route: '/login', session: null, profile: null, family: null })

    await user.click(await screen.findByRole('button', { name: 'Criar conta' }))
    await user.type(screen.getByLabelText('Seu nome'), 'Bia Lima')
    await user.type(screen.getByLabelText('Nome da família'), 'Família Lima')
    await user.type(screen.getByLabelText('E-mail'), 'bia@exemplo.com')
    await user.type(screen.getByLabelText('Senha'), 'segredo123')
    await user.click(screen.getByRole('button', { name: /Criar família/ }))

    const onboarding = await waitFor(() => {
      const call = findCall(calls, 'POST', '/onboarding')
      expect(call).toBeTruthy()
      return call
    })
    expect(onboarding.body).toEqual({ nome: 'Bia Lima', nome_familia: 'Família Lima' })
    expect(calls.some((call) => call.method === 'GET' && call.path === '/invites/mine')).toBe(true)
    expect(sessionValue.signUp).toHaveBeenCalledWith('bia@exemplo.com', 'segredo123', 'Bia Lima')
    expect(sessionValue.refresh).toHaveBeenCalled()
  })

  it('não cria família quando há convite pendente', async () => {
    const user = userEvent.setup()
    const calls = mockApi({
      'GET /invites/mine': {
        invite_id: 'i1',
        family_id: 'fam-1',
        family_nome: 'Família Lima',
        token: 'tok-1',
        email: 'bia@exemplo.com',
      },
      'POST /onboarding': { profile: { id: 'u-nova' } },
    })
    renderApp({ route: '/login', session: null, profile: null, family: null })

    await user.click(await screen.findByRole('button', { name: 'Criar conta' }))
    await user.type(screen.getByLabelText('Seu nome'), 'Bia Lima')
    await user.type(screen.getByLabelText('Nome da família'), 'Família Lima')
    await user.type(screen.getByLabelText('E-mail'), 'bia@exemplo.com')
    await user.type(screen.getByLabelText('Senha'), 'segredo123')
    await user.click(screen.getByRole('button', { name: /Criar família/ }))

    await screen.findByRole('heading', { name: 'Entre para aceitar' })
    expect(calls.some((call) => call.method === 'POST' && call.path === '/onboarding')).toBe(false)
  })
})
