import { useEffect, useState } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import AuthLayout from '../components/AuthLayout'
import Button from '../components/Button'
import { Field, Input } from '../components/FormField'
import { useSession } from '../hooks/useSession'
import { DEMO_ACCOUNTS, DEMO_PASSWORD, isSupabaseConfigured } from '../lib/supabase'
import { apiFetch, errorMessage } from '../services/api'

function friendlyAuthError(error) {
  const message = error?.message || ''
  if (/invalid login credentials/i.test(message)) return 'E-mail ou senha incorretos. Confira e tente de novo.'
  if (/email not confirmed/i.test(message)) return 'Confirme seu e-mail antes de entrar. Procure a mensagem que enviamos.'
  if (/password should be at least/i.test(message)) return 'A senha precisa ter pelo menos 6 caracteres.'
  if (/rate limit|too many/i.test(message)) return 'Muitas tentativas em pouco tempo. Espere um minuto e tente de novo.'
  return message || 'Não foi possível entrar agora. Tente de novo.'
}

export default function Login() {
  const navigate = useNavigate()
  const [params] = useSearchParams()
  const { session, loading, signIn, signUp, refresh } = useSession()
  const [mode, setMode] = useState(params.get('modo') === 'criar' ? 'criar' : 'entrar')
  const [form, setForm] = useState({ email: '', senha: '', nome: '', nome_familia: '' })
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const [busy, setBusy] = useState(false)
  const [demoBusy, setDemoBusy] = useState('')

  const nextParam = params.get('next') || '/'
  const next = nextParam.startsWith('/') ? nextParam : '/'

  useEffect(() => {
    if (!loading && session) navigate(next, { replace: true })
  }, [loading, session, navigate, next])

  function update(field) {
    return (event) => setForm((current) => ({ ...current, [field]: event.target.value }))
  }

  async function submit(event) {
    event.preventDefault()
    setError('')
    setNotice('')
    setBusy(true)
    try {
      if (mode === 'entrar') {
        const { error: authError } = await signIn(form.email.trim(), form.senha)
        if (authError) {
          setError(friendlyAuthError(authError))
          return
        }
      } else {
        if (!form.nome.trim() || !form.nome_familia.trim()) {
          setError('Preencha seu nome e o nome da família.')
          return
        }
        if (form.senha.length < 6) {
          setError('A senha precisa ter pelo menos 6 caracteres.')
          return
        }
        const { data, error: authError } = await signUp(
          form.email.trim(),
          form.senha,
          form.nome.trim(),
        )
        if (authError) {
          setError(friendlyAuthError(authError))
          return
        }
        if (!data?.session) {
          setNotice('Cadastro recebido. Confirme o e-mail para entrar e concluir a criação da família.')
          return
        }
        try {
          const invite = await apiFetch('/invites/mine')
          if (invite?.token) {
            navigate(`/invite/${invite.token}`, { replace: true })
            return
          }
        } catch {
          setError('Sua conta foi criada, mas não conseguimos verificar convites agora. Conclua na próxima tela.')
          navigate('/onboarding', { replace: true })
          return
        }
        try {
          await apiFetch('/onboarding', {
            method: 'POST',
            body: { nome: form.nome.trim(), nome_familia: form.nome_familia.trim() },
          })
          await refresh()
          navigate(next, { replace: true })
        } catch (onboardingError) {
          setError(errorMessage(onboardingError, 'Sua conta foi criada, mas a família não. Tente de novo.'))
        }
      }
    } finally {
      setBusy(false)
    }
  }

  async function demo(account) {
    setError('')
    setNotice('')
    setDemoBusy(account.nome)
    try {
      const { error: authError } = await signIn(account.email, DEMO_PASSWORD)
      if (authError) setError(friendlyAuthError(authError))
    } finally {
      setDemoBusy('')
    }
  }

  return (
    <AuthLayout>
      <div className="flex items-baseline gap-5 border-b border-linha">
        <button
          type="button"
          onClick={() => {
            setMode('entrar')
            setError('')
          }}
          className={`-mb-px border-b-2 pb-3 font-display text-2xl transition-colors ${
            mode === 'entrar'
              ? 'border-verde-texto text-grafite'
              : 'border-transparent text-muted hover:text-grafite'
          }`}
          aria-pressed={mode === 'entrar'}
        >
          Entrar
        </button>
        <button
          type="button"
          onClick={() => {
            setMode('criar')
            setError('')
          }}
          className={`-mb-px border-b-2 pb-3 font-display text-2xl transition-colors ${
            mode === 'criar'
              ? 'border-verde-texto text-grafite'
              : 'border-transparent text-muted hover:text-grafite'
          }`}
          aria-pressed={mode === 'criar'}
        >
          Criar conta
        </button>
      </div>

      <h1 className="mt-6 font-display text-3xl">
        {mode === 'entrar' ? 'Bem-vindo de volta' : 'Comece pela sua família'}
      </h1>
      <p className="mt-2 text-sm text-muted">
        {mode === 'entrar'
          ? 'Entre para ver o mês, confirmar contas e registrar o que aconteceu.'
          : 'Uma conta para a família toda. Você será o administrador e poderá convidar os outros.'}
      </p>

      <form onSubmit={submit} className="mt-6 space-y-4" noValidate>
        {mode === 'criar' ? (
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Seu nome" htmlFor="nome">
              <Input
                id="nome"
                name="nome"
                autoComplete="name"
                value={form.nome}
                onChange={update('nome')}
                placeholder="Ana Souza"
                required
              />
            </Field>
            <Field label="Nome da família" htmlFor="nome_familia">
              <Input
                id="nome_familia"
                name="nome_familia"
                value={form.nome_familia}
                onChange={update('nome_familia')}
                placeholder="Família Souza"
                required
              />
            </Field>
          </div>
        ) : null}

        <Field label="E-mail" htmlFor="email">
          <Input
            id="email"
            name="email"
            type="email"
            inputMode="email"
            autoComplete="email"
            value={form.email}
            onChange={update('email')}
            placeholder="voce@exemplo.com"
            required
          />
        </Field>

        <Field label="Senha" htmlFor="senha">
          <Input
            id="senha"
            name="senha"
            type="password"
            autoComplete={mode === 'entrar' ? 'current-password' : 'new-password'}
            value={form.senha}
            onChange={update('senha')}
            placeholder="Sua senha"
            required
          />
        </Field>

        {error ? (
          <p className="rounded-control border border-terracota/30 bg-terracota/5 px-3 py-2 text-sm text-terracota-texto" role="alert">
            {error}
          </p>
        ) : null}
        {notice ? (
          <p className="rounded-control border border-verde/30 bg-verde-claro px-3 py-2 text-sm" role="status">
            {notice}
          </p>
        ) : null}

        <div className="flex flex-wrap items-center justify-between gap-3 pt-1">
          <Link to="/reset-password" className="text-sm text-muted underline decoration-linha underline-offset-4 hover:text-grafite">
            Esqueci minha senha
          </Link>
          <Button type="submit" loading={busy} className="min-w-[9rem]">
            {mode === 'entrar' ? 'Entrar' : 'Criar família'}
          </Button>
        </div>
      </form>

      <div className="mt-8 rule pt-5">
        <div className="flex items-center justify-between gap-3">
          <p className="text-sm font-medium">Entrar na família de demonstração</p>
          <span className="chip">Demo</span>
        </div>
        <p className="mt-1 text-xs text-muted">
          Seis meses de histórico, metas e extrato simulado. Nenhuma conexão bancária real.
        </p>
        <ul className="mt-3">
          {DEMO_ACCOUNTS.map((account) => (
            <li key={account.email} className="flex items-center justify-between gap-3 border-b border-linha py-2.5 last:border-b-0">
              <div className="min-w-0">
                <p className="text-sm">
                  {account.nome} <span className="text-xs text-muted">· {account.papel}</span>
                </p>
                <p className="truncate text-2xs text-muted">{account.email}</p>
              </div>
              <button
                type="button"
                onClick={() => demo(account)}
                className="shrink-0 text-sm text-verde-texto underline decoration-verde-texto/30 underline-offset-4 hover:decoration-verde-texto disabled:opacity-50"
                disabled={Boolean(demoBusy)}
              >
                {demoBusy === account.nome ? 'Entrando…' : `Entrar como ${account.nome}`}
              </button>
            </li>
          ))}
        </ul>
        {!isSupabaseConfigured ? (
          <p className="mt-3 text-2xs text-muted">
            Ambiente sem Supabase configurado. Defina VITE_SUPABASE_URL e VITE_SUPABASE_ANON_KEY em
            frontend/.env.local para entrar.
          </p>
        ) : null}
      </div>
    </AuthLayout>
  )
}
