import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import AuthLayout from '../components/AuthLayout'
import Button from '../components/Button'
import { Field, Input } from '../components/FormField'
import { useSession } from '../hooks/useSession'
import { supabase } from '../lib/supabase'
import { apiFetch, errorMessage } from '../services/api'

export default function ResetPassword() {
  const { session, loading, signOut } = useSession()
  const [email, setEmail] = useState('')
  const [senha, setSenha] = useState('')
  const [confirmar, setConfirmar] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const navigate = useNavigate()

  const urlError =
    typeof window !== 'undefined'
      ? new URLSearchParams(window.location.hash.replace(/^#/, '')).get('error_description') ||
        new URLSearchParams(window.location.search).get('error_description')
      : ''

  async function sendLink(event) {
    event.preventDefault()
    setError('')
    setNotice('')
    setBusy(true)
    try {
      const { error: authError } = await supabase.auth.resetPasswordForEmail(email.trim(), {
        redirectTo: `${window.location.origin}/reset-password`,
      })
      if (authError) {
        setError(
          /rate limit/i.test(authError.message)
            ? 'Muitos pedidos em pouco tempo. Espere alguns minutos e tente de novo.'
            : authError.message,
        )
        return
      }
      setNotice('Se existir uma conta com esse e-mail, o link de recuperação chegará em instantes. Confira também o spam.')
    } finally {
      setBusy(false)
    }
  }

  async function savePassword(event) {
    event.preventDefault()
    setError('')
    setNotice('')
    if (senha.length < 6) {
      setError('A senha precisa ter pelo menos 6 caracteres.')
      return
    }
    if (senha !== confirmar) {
      setError('As duas senhas precisam ser iguais.')
      return
    }
    setBusy(true)
    try {
      const { error: authError } = await supabase.auth.updateUser({ password: senha })
      if (authError) {
        setError(errorMessage(authError, 'Não foi possível salvar a nova senha.'))
        return
      }
      setNotice('Senha atualizada. Você já pode usar a nova senha.')
      setSenha('')
      setConfirmar('')
    } finally {
      setBusy(false)
    }
  }

  if (loading) {
    return (
      <AuthLayout>
        <p className="text-sm text-muted" role="status">
          Verificando o link…
        </p>
      </AuthLayout>
    )
  }

  return (
    <AuthLayout>
      <h1 className="font-display text-3xl">
        {session ? 'Defina uma nova senha' : 'Recuperar acesso'}
      </h1>
      <p className="mt-2 text-sm text-muted">
        {session
          ? 'Escolha uma senha nova para entrar no VivaFinanças.'
          : 'Informe o e-mail da sua conta e enviamos um link para criar outra senha.'}
      </p>

      {urlError ? (
        <p className="mt-4 rounded-control border border-terracota/30 bg-terracota/5 px-3 py-2 text-sm text-terracota-texto" role="alert">
          O link expirou ou já foi usado. Peça um novo abaixo.
        </p>
      ) : null}

      {session ? (
        <form onSubmit={savePassword} className="mt-6 space-y-4" noValidate>
          <Field label="Nova senha" htmlFor="nova-senha">
            <Input
              id="nova-senha"
              type="password"
              autoComplete="new-password"
              value={senha}
              onChange={(event) => setSenha(event.target.value)}
              placeholder="Pelo menos 6 caracteres"
              required
            />
          </Field>
          <Field label="Repita a nova senha" htmlFor="confirmar-senha">
            <Input
              id="confirmar-senha"
              type="password"
              autoComplete="new-password"
              value={confirmar}
              onChange={(event) => setConfirmar(event.target.value)}
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
            <button type="button" onClick={signOut} className="text-sm text-muted underline underline-offset-4">
              Sair desta conta
            </button>
            <Button type="submit" loading={busy}>
              Salvar senha
            </Button>
          </div>
          {notice ? (
            <Button variant="secondary" className="w-full" onClick={() => navigate('/')}>
              Ir para o painel
            </Button>
          ) : null}
        </form>
      ) : (
        <form onSubmit={sendLink} className="mt-6 space-y-4" noValidate>
          <Field label="E-mail" htmlFor="recuperar-email">
            <Input
              id="recuperar-email"
              type="email"
              inputMode="email"
              autoComplete="email"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              placeholder="voce@exemplo.com"
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

          <Button type="submit" loading={busy} className="w-full">
            Enviar link de recuperação
          </Button>
        </form>
      )}

      <p className="mt-8 text-sm text-muted">
        <Link to="/login" className="link-quiet">
          Voltar para o login
        </Link>
      </p>
    </AuthLayout>
  )
}
