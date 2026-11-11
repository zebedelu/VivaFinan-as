import { beforeEach, afterEach, describe, expect, it, vi } from 'vitest'

const native = vi.hoisted(() => ({
  handler: null,
  remove: vi.fn(),
  addListener: vi.fn(async (_event, callback) => {
    native.handler = callback
    return { remove: native.remove }
  }),
}))

vi.mock('@capacitor/app', () => ({ App: { addListener: native.addListener } }))

import {
  RESET_PASSWORD_DEEP_LINK,
  routeFromAppUrl,
  resetPasswordRedirectUrl,
  subscribeToResetDeepLink,
} from '../lib/deepLink'

describe('deep link de recuperação de senha', () => {
  beforeEach(() => {
    native.handler = null
    native.remove.mockClear()
    native.addListener.mockClear()
  })

  afterEach(() => {
    delete window.Capacitor
  })

  it('no browser aponta para o /auth/confirm com o next', () => {
    expect(resetPasswordRedirectUrl('https://app.vivafinancas.app')).toBe(
      'https://app.vivafinancas.app/auth/confirm?next=/reset-password',
    )
  })

  it('no WebView nativo aponta para o esquema do app', () => {
    window.Capacitor = { isNativePlatform: () => true }

    expect(resetPasswordRedirectUrl()).toBe(RESET_PASSWORD_DEEP_LINK)
    expect(RESET_PASSWORD_DEEP_LINK).toBe('vivafinancas://reset-password')
  })

  it('mapeia apenas a URL do app para a rota de reset', () => {
    expect(routeFromAppUrl('vivafinancas://reset-password')).toBe('/reset-password')
    expect(routeFromAppUrl('vivafinancas://reset-password/')).toBe('/reset-password')
    expect(routeFromAppUrl('vivafinancas://reset-password?code=abc')).toBe('/reset-password')
    expect(routeFromAppUrl('vivafinancas://reset-password#access_token=abc')).toBe('/reset-password')
    expect(routeFromAppUrl('vivafinancas://outra-tela')).toBeNull()
    expect(routeFromAppUrl('https://app.vivafinancas.app/reset-password')).toBeNull()
    expect(routeFromAppUrl(undefined)).toBeNull()
  })

  it('não registra listener no browser', async () => {
    const onRoute = vi.fn()
    const stop = await subscribeToResetDeepLink(onRoute)

    expect(native.addListener).not.toHaveBeenCalled()
    expect(() => stop()).not.toThrow()
  })

  it('navega ao abrir a URL no app e remove o listener', async () => {
    window.Capacitor = { isNativePlatform: () => true }
    const onRoute = vi.fn()

    const stop = await subscribeToResetDeepLink(onRoute)
    expect(native.addListener).toHaveBeenCalledWith('appUrlOpen', expect.any(Function))

    native.handler({ url: 'vivafinancas://reset-password' })
    expect(onRoute).toHaveBeenCalledWith('/reset-password')

    native.handler({ url: 'https://app.vivafinancas.app/reset-password' })
    expect(onRoute).toHaveBeenCalledTimes(1)

    stop()
    expect(native.remove).toHaveBeenCalledTimes(1)
  })
})
