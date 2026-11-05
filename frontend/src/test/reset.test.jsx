import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const authMock = vi.hoisted(() => ({
  resetPasswordForEmail: vi.fn(async () => ({ error: null })),
  updateUser: vi.fn(async () => ({ error: null })),
  getSession: vi.fn(async () => ({ data: { session: null } })),
  signOut: vi.fn(async () => ({ error: null })),
}))

vi.mock('../lib/supabase', () => ({
  supabase: { auth: authMock },
  isSupabaseConfigured: true,
  DEMO_ACCOUNTS: [],
  DEMO_PASSWORD: '',
}))

import { mockApi, renderApp } from './utils'

describe('Recuperação de senha', () => {
  beforeEach(() => {
    authMock.resetPasswordForEmail.mockClear()
    authMock.updateUser.mockClear()
  })

  it('envia o link de recuperação para o e-mail informado', async () => {
    const user = userEvent.setup()
    mockApi({})
    renderApp({ route: '/reset-password', session: null, profile: null, family: null })

    expect(await screen.findByRole('heading', { name: 'Recuperar acesso' })).toBeInTheDocument()
    await user.type(screen.getByLabelText('E-mail'), 'ana@exemplo.com')
    await user.click(screen.getByRole('button', { name: 'Enviar link de recuperação' }))

    await waitFor(() =>
      expect(authMock.resetPasswordForEmail).toHaveBeenCalledWith('ana@exemplo.com', {
        redirectTo: 'http://localhost:5173/reset-password',
      }),
    )
    expect(await screen.findByText(/link de recuperação chegará/)).toBeInTheDocument()
  })

  it('valida a confirmação e salva a nova senha', async () => {
    const user = userEvent.setup()
    mockApi({})
    renderApp({ route: '/reset-password' })

    expect(await screen.findByRole('heading', { name: 'Defina uma nova senha' })).toBeInTheDocument()
    await user.type(screen.getByLabelText('Nova senha'), 'segredo123')
    await user.type(screen.getByLabelText('Repita a nova senha'), 'segredo124')
    await user.click(screen.getByRole('button', { name: 'Salvar senha' }))

    expect(await screen.findByText('As duas senhas precisam ser iguais.')).toBeInTheDocument()
    expect(authMock.updateUser).not.toHaveBeenCalled()

    await user.clear(screen.getByLabelText('Repita a nova senha'))
    await user.type(screen.getByLabelText('Repita a nova senha'), 'segredo123')
    await user.click(screen.getByRole('button', { name: 'Salvar senha' }))

    await waitFor(() =>
      expect(authMock.updateUser).toHaveBeenCalledWith({ password: 'segredo123' }),
    )
    expect(await screen.findByText(/Senha atualizada/)).toBeInTheDocument()
  })
})
