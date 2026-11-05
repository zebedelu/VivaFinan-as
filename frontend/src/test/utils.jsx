import { render } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { vi } from 'vitest'
import AppRoutes from '../App'
import { ToastProvider } from '../components/Toast'
import { SessionContext } from '../hooks/useSession'
import { ThemeProvider } from '../hooks/useTheme'
import { demoFamily, demoProfile, demoSession } from './fixtures'

export function json(status, body) {
  return {
    ok: status >= 200 && status < 300,
    status,
    text: async () => JSON.stringify(body),
    json: async () => body,
  }
}

function routeFor(method, path, routes) {
  const exact = routes[`${method} ${path}`]
  if (exact !== undefined) return exact

  for (const [key, value] of Object.entries(routes)) {
    const [routeMethod, pattern] = key.split(' ')
    if (routeMethod !== method || !pattern?.includes('*')) continue
    const source = pattern
      .split('*')
      .map((part) => part.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'))
      .join('[^/]+')
    if (new RegExp(`^${source}$`).test(path)) return value
  }
  return undefined
}

export function mockApi(routes = {}) {
  const calls = []
  globalThis.fetch = vi.fn(async (input, init = {}) => {
    const url = typeof input === 'string' ? input : input.url
    const parsed = new URL(url, 'http://localhost')
    const path = parsed.pathname.replace(/^\/api/, '')
    const method = (init.method || 'GET').toUpperCase()
    let body
    if (init.body) {
      try {
        body = JSON.parse(init.body)
      } catch {
        body = init.body
      }
    }
    calls.push({ method, path, url, body, headers: init.headers })

    const handler = routeFor(method, path, routes)
    if (typeof handler === 'function') {
      const result = await handler({ body, url: parsed, method, path, headers: init.headers })
      if (result && typeof result.status === 'number' && typeof result.text === 'function') return result
      return json(200, result ?? null)
    }
    if (handler !== undefined) return json(200, handler)
    return json(404, { error: { code: 'not_found', message: `Sem mock para ${method} ${path}` } })
  })
  return calls
}

export function findCall(calls, method, path) {
  return calls.find((call) => call.method === method && call.path === path)
}

export function renderApp({
  route = '/',
  session = demoSession,
  profile = demoProfile,
  family = demoFamily,
  overrides = {},
} = {}) {
  const value = {
    session,
    user: session?.user || null,
    profile,
    family,
    loading: false,
    profileError: null,
    signIn: vi.fn(async () => ({ error: null })),
    signUp: vi.fn(async () => ({ data: { session: {} }, error: null })),
    signOut: vi.fn(async () => {}),
    updateProfile: vi.fn(async () => ({})),
    refresh: vi.fn(async () => {}),
    setSession: vi.fn(),
    ...overrides,
  }

  const result = render(
    <MemoryRouter initialEntries={[route]}>
      <SessionContext.Provider value={value}>
        <ThemeProvider>
          <ToastProvider>
            <AppRoutes />
          </ToastProvider>
        </ThemeProvider>
      </SessionContext.Provider>
    </MemoryRouter>,
  )

  return { ...result, sessionValue: value }
}
