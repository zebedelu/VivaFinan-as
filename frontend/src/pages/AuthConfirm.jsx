import { useEffect, useRef, useState } from 'react'
import { Link, useLocation, useNavigate, useSearchParams } from 'react-router-dom'
import AuthLayout from '../components/AuthLayout'
import { supabase } from '../lib/supabase'

// Só aceita destinos do próprio app; links externos caem no painel.
function safeNext(value) {
  if (!value) return ''
  try {
    const url = new URL(value, window.location.origin)
    if (url.origin !== window.location.origin) return ''
    return `${url.pathname}${url.search}${url.hash}`
  } catch {
    return ''
  }
}

export default function AuthConfirm() {
  const [params] = useSearchParams()
  const location = useLocation()
  const navigate = useNavigate()
  const started = useRef(false)
  const [error, setError] = useState('')

  useEffect(() => {
    if (started.current) return
    started.current = true

    const tokenHash = params.get('token_hash')
    const type = params.get('type') || 'email'
    const hash = new URLSearchParams(location.hash.replace(/^#/, ''))
    const destination = type === 'recovery' ? '/reset-password' : safeNext(params.get('next')) || '/painel'

    // Template padrão do Supabase ({{ .ConfirmationURL }}) consome o token no /verify
    // e devolve a sessão no hash. O template com {{ .TokenHash }} manda token_hash.
    const accessToken = hash.get('access_token')
    const refreshToken = hash.get('refresh_token')
    const code = params.get('code')

    if (!tokenHash && accessToken && refreshToken) {
      supabase.auth
        .setSession({ access_token: accessToken, refresh_token: refreshToken })
        .then(({ error: sessionError }) => {
          if (sessionError) {
            setError('O link expirou ou já foi usado. Peça um novo e-mail e tente de novo.')
            return
          }
          navigate(destination, { replace: true })
        })
        .catch(() => setError('Não foi possível confirmar o link agora. Tente de novo em instantes.'))
      return
    }

    if (!tokenHash && code) {
      supabase.auth
        .exchangeCodeForSession(code)
        .then(({ error: exchangeError }) => {
          if (exchangeError) {
            setError('O link expirou ou já foi usado. Peça um novo e-mail e tente de novo.')
            return
          }
          navigate(destination, { replace: true })
        })
        .catch(() => setError('Não foi possível confirmar o link agora. Tente de novo em instantes.'))
      return
    }

    if (!tokenHash) {
      const hashError = hash.get('error_description') || hash.get('error_code')
      setError(
        hashError
          ? 'O link expirou ou já foi usado. Peça um novo e-mail e tente de novo.'
          : 'O link chegou incompleto: falta o código de confirmação. Peça um novo e-mail.',
      )
      return
    }

    supabase.auth
      .verifyOtp({ token_hash: tokenHash, type })
      .then(({ error: authError }) => {
        if (authError) {
          setError('O link expirou ou já foi usado. Peça um novo e-mail e tente de novo.')
          return
        }
        navigate(destination, { replace: true })
      })
      .catch(() => {
        setError('Não foi possível confirmar o link agora. Tente de novo em instantes.')
      })
  }, [navigate, params, location.hash])

  return (
    <AuthLayout>
      <h1 className="font-display text-3xl">Confirmar e-mail</h1>
      {error ? (
        <>
          <p
            className="mt-4 rounded-control border border-terracota/30 bg-terracota/5 px-3 py-2 text-sm text-terracota-texto"
            role="alert"
          >
            {error}
          </p>
          <p className="mt-8 text-sm text-muted">
            <Link to="/login" className="link-quiet">
              Voltar para o login
            </Link>
          </p>
        </>
      ) : (
        <p className="mt-2 text-sm text-muted" role="status">
          Confirmando seu link…
        </p>
      )}
    </AuthLayout>
  )
}
