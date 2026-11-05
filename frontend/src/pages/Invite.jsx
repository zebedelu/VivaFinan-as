import { useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { Users } from 'lucide-react'
import AuthLayout from '../components/AuthLayout'
import Button from '../components/Button'
import { Field, Input } from '../components/FormField'
import { Loading } from '../components/Loading'
import { ErrorState } from '../components/StatePanels'
import { useApi } from '../hooks/useApi'
import { useSession } from '../hooks/useSession'
import { apiFetch, errorMessage } from '../services/api'

export default function Invite() {
  const { token } = useParams()
  const { session, loading: sessionLoading, profile, refresh, signOut } = useSession()
  const { data, loading, error, refetch } = useApi(session ? '/invites/mine' : null)
  const navigate = useNavigate()
  const [nome, setNome] = useState(profile?.nome || '')
  const [busy, setBusy] = useState(false)
  const [formError, setFormError] = useState('')
  const [done, setDone] = useState(false)

  const next = `/invite/${token}`

  if (sessionLoading) {
    return (
      <AuthLayout>
        <Loading label="Verificando seu acesso" rows={1} />
      </AuthLayout>
    )
  }

  if (!session) {
    return (
      <AuthLayout>
        <p className="text-sm text-muted">Convite de família</p>
        <h1 className="mt-1 font-display text-3xl">Entre para aceitar</h1>
        <p className="mt-2 text-sm text-muted">
          O convite vale para o e-mail que recebeu o link. Entre ou crie sua conta com esse e-mail e
          volte para cá.
        </p>
        <div className="mt-6 flex flex-wrap gap-2">
          <Link to={`/login?next=${encodeURIComponent(next)}`} className="btn-primary no-underline">
            Entrar
          </Link>
          <Link to={`/login?next=${encodeURIComponent(next)}&modo=criar`} className="btn-secondary no-underline">
            Criar conta
          </Link>
        </div>
        <p className="mt-6 text-xs text-muted">
          O convite é único. Se ele expirou, peça outro para quem administra a família.
        </p>
      </AuthLayout>
    )
  }

  const invite = data?.invite_id ? data : data && data.family_id ? data : null

  async function accept(event) {
    event.preventDefault()
    setFormError('')
    if (!nome.trim()) {
      setFormError('Diga como você quer ser chamado.')
      return
    }
    setBusy(true)
    try {
      await apiFetch('/invites/accept', {
        method: 'POST',
        body: { token: invite?.token || token, nome: nome.trim() },
      })
      setDone(true)
      await refresh()
      navigate('/', { replace: true })
    } catch (err) {
      if (err.status === 409) {
        setFormError('Você já faz parte de uma família.')
      } else {
        setFormError(errorMessage(err, 'Não foi possível aceitar o convite.'))
      }
    } finally {
      setBusy(false)
    }
  }

  return (
    <AuthLayout>
      <p className="text-sm text-muted">Convite de família</p>
      <h1 className="mt-1 font-display text-3xl">
        {invite ? invite.family_nome : 'Aceitar convite'}
      </h1>

      {loading ? <Loading label="Buscando o convite" rows={2} /> : null}

      {error ? (
        <div className="mt-5">
          <ErrorState error={error} title="Não foi possível abrir o convite" onRetry={refetch} />
        </div>
      ) : null}

      {!loading && !error && !invite ? (
        <div className="mt-5">
          <p className="text-sm text-muted">
            Nenhum convite pendente para {profile?.nome || 'este e-mail'}. Se o link já foi usado, sua
            família aparece no painel.
          </p>
          <div className="mt-5 flex flex-wrap gap-2">
            <Link to="/" className="btn-primary no-underline">
              Abrir o painel
            </Link>
            <button type="button" onClick={signOut} className="btn-secondary">
              Trocar de conta
            </button>
          </div>
        </div>
      ) : null}

      {!loading && !error && invite && !done ? (
        <form onSubmit={accept} className="mt-6 space-y-4">
          <div className="flex items-start gap-3 border-l-2 border-dourado pl-4">
            <Users size={18} className="mt-0.5 shrink-0 text-dourado-forte" aria-hidden="true" />
            <div>
              <p className="text-sm">Você entra como membro e vê o painel da família.</p>
              <p className="mt-0.5 text-xs text-muted">
                Seus lançamentos pessoais continuam visíveis só para você.
              </p>
            </div>
          </div>

          <Field label="Como você quer ser chamado" htmlFor="invite-nome">
            <Input
              id="invite-nome"
              value={nome}
              onChange={(event) => setNome(event.target.value)}
              autoComplete="name"
              placeholder="Seu nome"
              required
            />
          </Field>

          {formError ? (
            <p className="rounded-control border border-terracota/30 bg-terracota/5 px-3 py-2 text-sm text-terracota-texto" role="alert">
              {formError}
            </p>
          ) : null}

          <Button type="submit" loading={busy} className="w-full sm:w-auto">
            Aceitar convite
          </Button>
          {formError.includes('já faz parte') ? (
            <Link to="/" className="block text-sm link-quiet">
              Abrir o painel
            </Link>
          ) : null}
        </form>
      ) : null}
    </AuthLayout>
  )
}
