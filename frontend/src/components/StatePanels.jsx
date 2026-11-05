import { AlertCircle, CloudOff, Lock } from 'lucide-react'
import Button from './Button'
import { errorMessage } from '../services/api'

export function ErrorState({ error, title = 'Não foi possível carregar', onRetry }) {
  return (
    <div className="card p-6" role="alert">
      <div className="flex items-start gap-3">
        <AlertCircle size={20} className="mt-0.5 shrink-0 text-terracota-texto" aria-hidden="true" />
        <div>
          <p className="font-display text-xl">{title}</p>
          <p className="mt-1 text-sm text-muted">{errorMessage(error)}</p>
          {onRetry ? (
            <Button variant="secondary" className="mt-4" onClick={onRetry}>
              Tentar de novo
            </Button>
          ) : null}
        </div>
      </div>
    </div>
  )
}

export function UnavailableState({ title, description, onRetry }) {
  return (
    <div className="card p-6" role="status">
      <div className="flex items-start gap-3">
        <CloudOff size={20} className="mt-0.5 shrink-0 text-dourado-forte" aria-hidden="true" />
        <div>
          <p className="font-display text-xl">{title}</p>
          <p className="mt-1 text-sm text-muted">{description}</p>
          {onRetry ? (
            <Button variant="secondary" className="mt-4" onClick={onRetry}>
              Tentar de novo
            </Button>
          ) : null}
        </div>
      </div>
    </div>
  )
}

export function InactiveAccount({ onSignOut }) {
  return (
    <main className="flex min-h-screen items-center justify-center bg-areia px-6">
      <div className="max-w-md text-center">
        <span className="mx-auto flex h-12 w-12 items-center justify-center rounded-full border border-linha text-muted">
          <Lock size={20} aria-hidden="true" />
        </span>
        <h1 className="mt-5 font-display text-3xl">Conta desativada</h1>
        <p className="mt-3 text-sm text-muted">
          Seu acesso foi desativado por um administrador da família. Se precisar voltar, fale com quem
          administra a conta.
        </p>
        <Button variant="secondary" className="mt-6" onClick={onSignOut}>
          Sair
        </Button>
      </div>
    </main>
  )
}
