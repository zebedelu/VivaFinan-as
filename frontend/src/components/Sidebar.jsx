import { NavLink } from 'react-router-dom'
import {
  ArrowLeftRight,
  Landmark,
  LayoutDashboard,
  LogOut,
  Repeat,
  Settings,
  Sparkles,
  Target,
  TrendingUp,
  UserRound,
} from 'lucide-react'
import { useSession } from '../hooks/useSession'
import { initials } from '../lib/format'

const GROUPS = [
  {
    label: 'O mês',
    items: [
      { to: '/', label: 'Painel', icon: LayoutDashboard, end: true },
      { to: '/individual', label: 'Meu espaço', icon: UserRound },
    ],
  },
  {
    label: 'Registrar',
    items: [
      { to: '/transactions', label: 'Lançamentos', icon: ArrowLeftRight },
      { to: '/recurring', label: 'Recorrentes', icon: Repeat },
    ],
  },
  {
    label: 'Planejar',
    items: [
      { to: '/goals', label: 'Metas', icon: Target },
      { to: '/forecast', label: 'Previsões', icon: TrendingUp },
      { to: '/ai', label: 'Jev AI', icon: Sparkles },
    ],
  },
  {
    label: 'Contas',
    items: [
      { to: '/banking', label: 'Extrato', icon: Landmark },
      { to: '/settings', label: 'Configurações', icon: Settings },
    ],
  },
]

export default function Sidebar() {
  const { profile, family, signOut } = useSession()

  return (
    <aside className="fixed inset-y-0 left-0 z-40 hidden w-60 flex-col overflow-y-auto border-r border-white/10 bg-verde-forte px-4 py-6 text-sobre-verde md:flex">
      <NavLink to="/" className="mb-8 block px-2 no-underline">
        <span className="font-display text-[1.45rem] leading-none tracking-tight">VivaFinanças</span>
        <span className="mt-1.5 block text-2xs text-sobre-verde/70">O mês da família em uma página</span>
      </NavLink>

      <nav className="flex-1 space-y-6" aria-label="Navegação principal">
        {GROUPS.map((group) => (
          <div key={group.label}>
            <p className="mb-1.5 px-3 text-2xs text-sobre-verde/70">{group.label}</p>
            <ul className="space-y-0.5">
              {group.items.map((item) => (
                <li key={item.to}>
                  <NavLink
                    to={item.to}
                    end={item.end}
                    className={({ isActive }) => `nav-link ${isActive ? 'nav-link-active' : ''}`}
                  >
                    <item.icon size={16} aria-hidden="true" />
                    {item.label}
                  </NavLink>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </nav>

      <div className="mt-6 border-t border-white/15 pt-4">
        <div className="flex items-center gap-2.5 px-1">
          <span className="flex h-9 w-9 items-center justify-center rounded-full bg-dourado text-xs font-semibold text-verde-forte">
            {initials(profile?.nome || 'VF')}
          </span>
          <div className="min-w-0">
            <p className="truncate text-sm">{profile?.nome || 'Sua conta'}</p>
            <p className="truncate text-2xs text-sobre-verde/70">{family?.nome || 'Família'}</p>
          </div>
        </div>
        <button
          type="button"
          onClick={signOut}
          className="mt-3 flex w-full items-center gap-2 rounded-control px-3 py-2 text-xs text-sobre-verde/75 transition-colors hover:bg-white/10 hover:text-sobre-verde"
        >
          <LogOut size={14} aria-hidden="true" /> Sair
        </button>
      </div>
    </aside>
  )
}
