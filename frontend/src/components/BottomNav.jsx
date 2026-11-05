import { useState } from 'react'
import { NavLink } from 'react-router-dom'
import { ArrowLeftRight, Ellipsis, House, Landmark, Plus } from 'lucide-react'
import Modal from './Modal'

const MORE = [
  { to: '/individual', label: 'Meu espaço' },
  { to: '/recurring', label: 'Recorrentes' },
  { to: '/goals', label: 'Metas' },
  { to: '/forecast', label: 'Previsões' },
  { to: '/ai', label: 'Jev AI' },
  { to: '/settings', label: 'Configurações' },
]

export default function BottomNav() {
  const [open, setOpen] = useState(false)

  return (
    <>
      <nav
        className="pb-safe fixed inset-x-0 bottom-0 z-40 border-t border-linha bg-superficie md:hidden"
        aria-label="Navegação principal"
      >
        <div className="mx-auto grid max-w-md grid-cols-5 items-end px-2 pt-1.5">
          <NavLink
            to="/"
            end
            className={({ isActive }) => `mobile-nav-link ${isActive ? 'mobile-nav-link-active' : ''}`}
          >
            <House size={19} aria-hidden="true" />
            Início
          </NavLink>
          <NavLink
            to="/transactions"
            className={({ isActive }) => `mobile-nav-link ${isActive ? 'mobile-nav-link-active' : ''}`}
          >
            <ArrowLeftRight size={19} aria-hidden="true" />
            Lançamentos
          </NavLink>
          <NavLink
            to="/transactions?novo=1"
            className="flex flex-col items-center gap-1 text-2xs text-verde-texto"
            aria-label="Novo lançamento"
          >
            <span className="flex h-11 w-11 items-center justify-center rounded-full bg-verde text-sobre-verde shadow-discreta">
              <Plus size={21} aria-hidden="true" />
            </span>
            <span className="sr-only">Novo</span>
          </NavLink>
          <NavLink
            to="/banking"
            className={({ isActive }) => `mobile-nav-link ${isActive ? 'mobile-nav-link-active' : ''}`}
          >
            <Landmark size={19} aria-hidden="true" />
            Extrato
          </NavLink>
          <button type="button" className="mobile-nav-link" onClick={() => setOpen(true)}>
            <Ellipsis size={19} aria-hidden="true" />
            Mais
          </button>
        </div>
      </nav>

      <Modal open={open} onClose={() => setOpen(false)} title="Mais" size="sm">
        <ul className="divide-y divide-linha">
          {MORE.map((item) => (
            <li key={item.to}>
              <NavLink
                to={item.to}
                onClick={() => setOpen(false)}
                className="block py-3 text-sm text-grafite"
              >
                {item.label}
              </NavLink>
            </li>
          ))}
        </ul>
      </Modal>
    </>
  )
}
