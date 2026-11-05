import { useState } from 'react'
import { Bell } from 'lucide-react'
import { currentMonth } from '../lib/format'
import { useApi } from '../hooks/useApi'
import AlertList from './AlertList'
import Modal from './Modal'
import { UnavailableState } from './StatePanels'

export default function NotificationBell() {
  const [open, setOpen] = useState(false)
  const { data, loading, error, refetch } = useApi(`/alerts?mes=${currentMonth()}`)
  const alerts = data?.alertas || []
  const count = alerts.length

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="relative rounded-control p-2 text-muted transition-colors hover:bg-verde-claro hover:text-grafite"
        aria-label={count ? `Alertas: ${count} hoje` : 'Alertas'}
      >
        <Bell size={19} aria-hidden="true" />
        {count > 0 ? (
          <span className="absolute right-1 top-1 flex h-4 min-w-4 items-center justify-center rounded-full bg-terracota-texto px-1 text-[10px] font-semibold text-sobre-terracota">
            {count}
          </span>
        ) : null}
      </button>

      <Modal
        open={open}
        onClose={() => setOpen(false)}
        title="Alertas do dia"
        description="Calculados quando você abre o app. Nada fica guardado entre sessões."
      >
        {loading ? <p className="py-4 text-sm text-muted">Carregando alertas…</p> : null}
        {error?.status === 503 ? (
          <UnavailableState
            title="Alertas indisponíveis"
            description="O servidor não conseguiu calcular os alertas agora."
            onRetry={refetch}
          />
        ) : null}
        {error && error.status !== 503 ? (
          <p className="py-4 text-sm text-terracota-texto" role="alert">
            Não foi possível carregar os alertas. Tente de novo em instantes.
          </p>
        ) : null}
        {!loading && !error ? <AlertList alerts={alerts} compact /> : null}
      </Modal>
    </>
  )
}
