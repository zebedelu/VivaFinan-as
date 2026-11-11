// Deep link do app Capacitor. No browser nada disto é registrado: o link do
// e-mail continua caindo em /auth/confirm, que troca o token_hash por sessão.

const RESET_PASSWORD_PATH = 'reset-password'

export const RESET_PASSWORD_ROUTE = `/${RESET_PASSWORD_PATH}`
export const RESET_PASSWORD_DEEP_LINK = `vivafinancas://${RESET_PASSWORD_PATH}`

export function isNativePlatform() {
  return Boolean(globalThis?.Capacitor?.isNativePlatform?.())
}

// No WebView o Supabase devolve para o esquema do app; no browser o link do
// e-mail precisa passar pelo /auth/confirm para verificar o token_hash.
export function resetPasswordRedirectUrl(origin = globalThis?.window?.location?.origin) {
  if (isNativePlatform()) return RESET_PASSWORD_DEEP_LINK
  return `${origin}/auth/confirm?next=${RESET_PASSWORD_ROUTE}`
}

export function routeFromAppUrl(url) {
  if (typeof url !== 'string' || !url.startsWith('vivafinancas://')) return null
  const [path] = url.slice('vivafinancas://'.length).split(/[?#]/)
  return path.replace(/\/+$/, '') === RESET_PASSWORD_PATH ? RESET_PASSWORD_ROUTE : null
}

// Só registra no nativo; no browser devolve um unsubscribe vazio sem tocar no
// plugin. O handle do Capacitor só existe depois do await, então o retorno é
// assíncrono.
export async function subscribeToResetDeepLink(onRoute) {
  if (!isNativePlatform()) return () => {}

  const { App } = await import('@capacitor/app')
  const handle = await App.addListener('appUrlOpen', (event) => {
    const route = routeFromAppUrl(event?.url)
    if (route) onRoute(route)
  })
  return () => {
    handle?.remove?.()
  }
}
