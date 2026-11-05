import { supabase } from '../lib/supabase'

export const API_URL = (import.meta.env.VITE_API_URL || 'http://localhost:5000/api').replace(/\/+$/, '')

let tokenCache = null
try {
  supabase.auth.onAuthStateChange?.((_event, session) => {
    tokenCache = session?.access_token ?? null
  })
} catch {
  tokenCache = null
}

async function currentToken() {
  if (tokenCache) return tokenCache
  try {
    const { data } = await supabase.auth.getSession()
    tokenCache = data?.session?.access_token ?? null
  } catch {
    tokenCache = null
  }
  return tokenCache
}

export class ApiError extends Error {
  constructor(status, payload, path) {
    const message =
      payload?.error?.message ||
      payload?.message ||
      (status === 0
        ? 'Não foi possível falar com o servidor. Verifique sua conexão e tente de novo.'
        : 'Algo deu errado. Tente de novo.')
    super(message)
    this.name = 'ApiError'
    this.status = status
    this.code = payload?.error?.code || payload?.code || null
    this.details = payload?.error?.details || null
    this.path = path
  }

  get unavailable() {
    return this.status === 503
  }
}

function buildUrl(path) {
  if (/^https?:\/\//.test(path)) return path
  const normalized = path.startsWith('/') ? path : `/${path}`
  return `${API_URL}${normalized}`
}

async function readBody(res) {
  const text = await res.text()
  if (!text) return null
  try {
    return JSON.parse(text)
  } catch {
    return { message: text }
  }
}

export async function apiFetch(path, { method = 'GET', body, signal, headers = {} } = {}) {
  const token = await currentToken()

  let res
  try {
    res = await fetch(buildUrl(path), {
      method,
      signal,
      headers: {
        Accept: 'application/json',
        ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}),
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...headers,
      },
      ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
    })
  } catch (error) {
    if (error?.name === 'AbortError') throw error
    throw new ApiError(0, null, path)
  }

  const payload = res.status === 204 ? null : await readBody(res)

  if (res.status === 401) {
    try {
      await supabase.auth.signOut()
    } catch {
      // A 401 already invalidated the session; the redirect handles the rest.
    }
    throw new ApiError(401, payload, path)
  }

  if (!res.ok) throw new ApiError(res.status, payload, path)

  return payload
}

export function errorMessage(error, fallback = 'Não foi possível concluir agora. Tente de novo.') {
  if (!error) return fallback
  if (error.status === 503) return 'Este recurso está indisponível no servidor agora.'
  if (error.status === 403) return 'Você não tem permissão para isso.'
  if (error.status === 409) return error.message || 'Esse item já foi registrado.'
  if (error.status === 422) return error.message || 'Confira os campos e tente de novo.'
  if (error.status === 401) return 'Sua sessão expirou. Entre de novo.'
  return error.message || fallback
}
