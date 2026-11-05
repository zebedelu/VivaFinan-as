import { Navigate, Outlet, useLocation } from 'react-router-dom'
import { useSession } from '../hooks/useSession'
import { InactiveAccount } from './StatePanels'

function FullPageLoading() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-3 bg-areia" role="status">
      <span className="font-display text-2xl">VivaFinanças</span>
      <span className="text-sm text-muted">Abrindo o caderno de contas…</span>
    </div>
  )
}

export default function ProtectedRoute() {
  const { session, profile, loading, profileError, signOut } = useSession()
  const location = useLocation()

  if (loading) return <FullPageLoading />

  if (!session) {
    const next = `${location.pathname}${location.search}`
    return <Navigate to={`/login?next=${encodeURIComponent(next)}`} replace />
  }

  if (profile?.status === 'inativo') {
    return <InactiveAccount onSignOut={signOut} />
  }

  if (!profile && !profileError && location.pathname !== '/onboarding') {
    return <Navigate to="/onboarding" replace />
  }

  return <Outlet />
}
