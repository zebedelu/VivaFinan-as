import { Link, Outlet, useLocation } from 'react-router-dom'
import { Moon, Sun } from 'lucide-react'
import { useSession } from '../hooks/useSession'
import { useTheme } from '../hooks/useTheme'
import { initials } from '../lib/format'
import BottomNav from './BottomNav'
import NotificationBell from './NotificationBell'
import Sidebar from './Sidebar'

const TITLES = {
  '/': 'Painel',
  '/individual': 'Meu espaço',
  '/transactions': 'Lançamentos',
  '/recurring': 'Recorrentes',
  '/goals': 'Metas',
  '/forecast': 'Previsões',
  '/ai': 'Jev AI',
  '/banking': 'Extrato',
  '/settings': 'Configurações',
}

export default function AppShell() {
  const { profile, family } = useSession()
  const { theme, toggle } = useTheme()
  const location = useLocation()
  const title = TITLES[location.pathname] || 'VivaFinanças'

  return (
    <div className="min-h-screen bg-areia">
      <Sidebar />
      <div className="md:pl-60">
        <header className="pt-safe sticky top-0 z-30 border-b border-linha bg-areia/95 backdrop-blur">
          <div className="mx-auto flex h-16 max-w-[1200px] items-center justify-between gap-3 px-4 md:px-8">
            <div className="flex min-w-0 items-center gap-3">
              <Link to="/" className="font-display text-lg leading-none no-underline md:hidden">
                VivaFinanças
              </Link>
              <div className="hidden min-w-0 md:block">
                <p className="font-display text-xl leading-tight">{title}</p>
                <p className="truncate text-2xs text-muted">{family?.nome || 'Sua família'}</p>
              </div>
            </div>

            <div className="flex items-center gap-0.5">
              <button
                type="button"
                onClick={toggle}
                className="rounded-control p-2 text-muted transition-colors hover:bg-verde-claro hover:text-grafite"
                aria-label={theme === 'claro' ? 'Ativar tema escuro' : 'Ativar tema claro'}
                title={theme === 'claro' ? 'Tema escuro' : 'Tema claro'}
              >
                {theme === 'claro' ? (
                  <Moon size={19} aria-hidden="true" />
                ) : (
                  <Sun size={19} aria-hidden="true" />
                )}
              </button>
              <NotificationBell />
              <Link
                to="/settings"
                className="ml-1 flex h-8 w-8 items-center justify-center rounded-full bg-verde text-2xs font-semibold text-sobre-verde no-underline"
                aria-label="Abrir configurações do perfil"
                title={profile?.nome || 'Perfil'}
              >
                {initials(profile?.nome || 'VF')}
              </Link>
            </div>
          </div>
        </header>

        <main className="mx-auto w-full max-w-[1200px] px-4 pb-28 pt-6 md:px-8 md:pb-12 md:pt-8">
          <div className="animate-page-in">
            <Outlet />
          </div>
        </main>
      </div>
      <BottomNav />
    </div>
  )
}
