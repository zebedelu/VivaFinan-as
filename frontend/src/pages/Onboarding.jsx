import { useState } from 'react'
import { Link, Navigate, useNavigate } from 'react-router-dom'
import { Users } from 'lucide-react'
import Button from '../components/Button'
import { Field, Input } from '../components/FormField'
import { Loading } from '../components/Loading'
import { ErrorState } from '../components/StatePanels'
import { useApi } from '../hooks/useApi'
import { useSession } from '../hooks/useSession'
import { apiFetch, errorMessage } from '../services/api'

export default function Onboarding() {
  const { profile, loading: sessionLoading, refresh, signOut } = useSession()
  const { data, loading, error, refetch } = useApi('/invites/mine')
  const navigate = useNavigate()
  const [nome, setNome] = useState(profile?.nome || '')
  const [nomeFamilia, setNomeFamilia] = useState('')
  const [busy, setBusy] = useState(false)
  const [formError, setFormError] = useState('')

  if (sessionLoading) return <Loading label="Abrindo sua conta" />
  if (profile) return <Navigate to="/" replace />

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
        body: { token: invite.token, nome: nome.trim() },
      })
      await refresh()
      navigate('/', { replace: true })
    } catch (err) {
      if (err.status === 409) {
        setFormError('Você já faz parte de uma família. Abra o painel para continuar.')
      } else {
        setFormError(errorMessage(err, 'Não foi possível aceitar o convite.'))
      }
    } finally {
      setBusy(false)
    }
  }

  async function createFamily(event) {
    event.preventDefault()
    setFormError('')
    if (!nome.trim() || !nomeFamilia.trim()) {
      setFormError('Preencha seu nome e o nome da família.')
      return
    }
    setBusy(true)
    try {
      await apiFetch('/onboarding', {
        method: 'POST',
        body: { nome: nome.trim(), nome_familia: nomeFamilia.trim() },
      })
      await refresh()
      navigate('/', { replace: true })
    } catch (err) {
      setFormError(errorMessage(err, 'Não foi possível criar a família.'))
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="min-h-screen bg-areia">
      <header className="border-b border-linha px-5 py-5 sm:px-8">
        <div className="mx-auto flex max-w-3xl items-center justify-between">
          <Link to="/" className="font-display text-xl no-underline">
            VivaFinanças
          </Link>
          <button type="button" onClick={signOut} className="text-sm text-muted underline underline-offset-4">
            Sair
          </button>
        </div>
      </header>

      <main className="mx-auto w-full max-w-3xl px-5 py-10 sm:px-8">
        <p className="text-sm text-muted">Primeiro acesso</p>
        <h1 className="mt-1 font-display text-4xl leading-tight">
          {invite ? 'Você foi convidado' : 'Vamos montar sua família'}
        </h1>
        <p className="mt-3 max-w-xl text-sm text-muted">
          {invite
            ? 'Confirme seu nome para entrar na família. A partir daí, cada um vê o próprio detalhe e o painel mostra só os totais.'
            : 'Crie o espaço da família. Você vira administrador e pode convidar as outras pessoas depois, em Configurações.'}
        </p>

        <div className="mt-8 rule pt-8">
          {loading ? <Loading label="Verificando convites" rows={2} /> : null}

          {error ? (
            <ErrorState
              error={error}
              title="Não foi possível verificar seu convite"
              onRetry={refetch}
            />
          ) : null}

          {!loading && !error && invite ? (
            <form onSubmit={accept} className="max-w-md space-y-4">
              <div className="flex items-start gap-3 border-l-2 border-dourado pl-4">
                <Users size={18} className="mt-0.5 shrink-0 text-dourado-forte" aria-hidden="true" />
                <div>
                  <p className="font-display text-xl">{invite.family_nome}</p>
                  <p className="mt-0.5 text-sm text-muted">Convite pendente para {invite.email || 'seu e-mail'}</p>
                </div>
              </div>

              <Field label="Como você quer ser chamado" htmlFor="convite-nome">
                <Input
                  id="convite-nome"
                  value={nome}
                  onChange={(event) => setNome(event.target.value)}
                  placeholder="Seu nome"
                  autoComplete="name"
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

          {!loading && !error && !invite ? (
            <form onSubmit={createFamily} className="max-w-md space-y-4">
              <div className="grid gap-4 sm:grid-cols-2">
                <Field label="Seu nome" htmlFor="onboarding-nome">
                  <Input
                    id="onboarding-nome"
                    value={nome}
                    onChange={(event) => setNome(event.target.value)}
                    placeholder="Ana Souza"
                    autoComplete="name"
                    required
                  />
                </Field>
                <Field label="Nome da família" htmlFor="onboarding-familia">
                  <Input
                    id="onboarding-familia"
                    value={nomeFamilia}
                    onChange={(event) => setNomeFamilia(event.target.value)}
                    placeholder="Família Souza"
                    required
                  />
                </Field>
              </div>
              <p className="text-xs text-muted">
                Doze categorias padrão entram junto com a família. Você pode ocultar ou criar outras
                em Configurações.
              </p>

              {formError ? (
                <p className="rounded-control border border-terracota/30 bg-terracota/5 px-3 py-2 text-sm text-terracota-texto" role="alert">
                  {formError}
                </p>
              ) : null}

              <Button type="submit" loading={busy}>
                Criar família
              </Button>
            </form>
          ) : null}
        </div>
      </main>
    </div>
  )
}
