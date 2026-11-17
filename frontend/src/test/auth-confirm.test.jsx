import { screen } from '@testing-library/react'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const authMock = vi.hoisted(() => ({
  verifyOtp: vi.fn(async () => ({ data: { session: {} }, error: null })),
  getSession: vi.fn(async () => ({ data: { session: null } })),
  signOut: vi.fn(async () => ({ error: null })),
}))

vi.mock('../lib/supabase', () => ({
  supabase: { auth: authMock },
  isSupabaseConfigured: true,
  DEMO_ACCOUNTS: [],
  DEMO_PASSWORD: '',
  authConfirmUrl: (next = '/painel') => `http://localhost:5173/auth/confirm?next=${next}`,
}))

import { mockApi, renderApp } from './utils'

describe('Confirmação de e-mail', () => {
  beforeEach(() => {
    authMock.verifyOtp.mockClear()
    authMock.verifyOtp.mockResolvedValue({ data: { session: {} }, error: null })
  })

  it('confirma o link de recuperação uma vez e segue para a nova senha', async () => {
    mockApi({})
    renderApp({
      route: '/auth/confirm?token_hash=hash-recovery&type=recovery',
      session: null,
      profile: null,
      family: null,
    })

    expect(await screen.findByRole('heading', { name: 'Recuperar acesso' })).toBeInTheDocument()
    expect(authMock.verifyOtp).toHaveBeenCalledTimes(1)
    expect(authMock.verifyOtp).toHaveBeenCalledWith({
      token_hash: 'hash-recovery',
      type: 'recovery',
    })
  })

  it('mostra mensagem curta e link de login quando o link falha', async () => {
    authMock.verifyOtp.mockResolvedValueOnce({
      data: { session: null },
      error: { message: 'Token has expired or is invalid' },
    })
    mockApi({})
    renderApp({
      route: '/auth/confirm?token_hash=hash-expirado&type=signup',
      session: null,
      profile: null,
      family: null,
    })

    expect(await screen.findByRole('alert')).toHaveTextContent(/expirou ou já foi usado/i)
    expect(screen.getByRole('link', { name: 'Voltar para o login' })).toHaveAttribute(
      'href',
      '/login',
    )
    expect(authMock.verifyOtp).toHaveBeenCalledTimes(1)
  })

  it('trata link sem token_hash como erro, sem chamar a verificação', async () => {
    mockApi({})
    renderApp({
      route: '/auth/confirm?type=signup',
      session: null,
      profile: null,
      family: null,
    })

    expect(await screen.findByRole('alert')).toHaveTextContent(/link chegou incompleto/i)
    expect(authMock.verifyOtp).not.toHaveBeenCalled()
  })

  it('aceita a sessão devolvida no hash pelo template padrão do Supabase', async () => {
    authMock.setSession = vi.fn(async () => ({ data: { session: {} }, error: null }))
    mockApi({})
    renderApp({
      route: '/auth/confirm?next=/painel#access_token=abc&refresh_token=def&type=signup',
      session: null,
      profile: null,
      family: null,
    })

    await vi.waitFor(() =>
      expect(authMock.setSession).toHaveBeenCalledWith({
        access_token: 'abc',
        refresh_token: 'def',
      }),
    )
    expect(authMock.verifyOtp).not.toHaveBeenCalled()
  })

  it('explica link expirado quando o Supabase devolve erro no hash', async () => {
    mockApi({})
    renderApp({
      route:
        '/auth/confirm#error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid',
      session: null,
      profile: null,
      family: null,
    })

    expect(await screen.findByRole('alert')).toHaveTextContent(/expirou ou já foi usado/i)
    expect(authMock.verifyOtp).not.toHaveBeenCalled()
  })
})
