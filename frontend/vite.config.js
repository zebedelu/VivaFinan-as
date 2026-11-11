import { defineConfig } from 'vitest/config'
import { loadEnv } from 'vite'
import react from '@vitejs/plugin-react'

const REQUIRED_VITE_ENV = ['VITE_SUPABASE_URL', 'VITE_SUPABASE_ANON_KEY', 'VITE_API_URL']

function assertBuildEnv(mode) {
  const env = { ...loadEnv(mode, process.cwd(), ''), ...process.env }
  const missing = REQUIRED_VITE_ENV.filter((key) => !(env[key] || '').trim())
  if (!missing.length) return

  const message = `VITE_* obrigatórias ausentes: ${missing.join(', ')}. Defina no .env.local (dev) ou nas envs do projeto na Vercel (deploy).`
  const guard = (process.env.VITE_ENV_GUARD || '').toLowerCase()

  if (guard === 'off') {
    console.warn(`[env-guard] ${message} (ignorado por VITE_ENV_GUARD=off)`)
    return
  }
  // Vercel define VERCEL=1; CI cobre runners de build. Build local sem credenciais
  // continua possível, mas avisa: o bundle não autentica.
  if (guard === 'strict' || process.env.VERCEL || process.env.CI) {
    throw new Error(`[env-guard] ${message}`)
  }
  console.warn(`[env-guard] ${message} Build local segue; o deploy falha sem elas.`)
}

export default defineConfig(({ command, mode }) => {
  if (command === 'build') assertBuildEnv(mode)

  return {
    plugins: [react()],
    server: { port: 5173 },
    test: {
      environment: 'jsdom',
      environmentOptions: { jsdom: { url: 'http://localhost:5173' } },
      globals: true,
      setupFiles: './src/test/setup.js',
      restoreMocks: true,
      css: false,
      exclude: ['e2e/**', '**/node_modules/**', '**/dist/**'],
    },
  }
})
