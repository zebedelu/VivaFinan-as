import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL || ''
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || ''

export const isSupabaseConfigured = Boolean(url && anonKey)

// Fallback keeps the app renderable in local demos and tests without .env.local.
// Requests are only made when a session exists.
export const supabase = createClient(url || 'http://localhost:54321', anonKey || 'public-anon-key', {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
})

// Links de e-mail do Supabase caem em /auth/confirm, onde o SPA chama verifyOtp.
export function authConfirmUrl(next = '/painel') {
  return `${window.location.origin}/auth/confirm?next=${next}`
}

export const DEMO_ACCOUNTS = [
  { nome: 'Ana', papel: 'Administradora', email: 'ana@demo.vivafinancas.app' },
  { nome: 'Carlos', papel: 'Membro', email: 'carlos@demo.vivafinancas.app' },
  { nome: 'Lucas', papel: 'Membro', email: 'lucas@demo.vivafinancas.app' },
]

export const DEMO_PASSWORD = 'Demo@2026!'
