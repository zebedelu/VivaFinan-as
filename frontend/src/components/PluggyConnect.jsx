import { Landmark } from 'lucide-react'
import Button from './Button'

// The Pluggy widget and its credentials are not part of v1. Creating a
// connection without the widget would POST an empty body, so the real
// connection stays disabled until the backend exposes the handshake.
const REAL_CONNECTION_ENABLED = false

export default function PluggyConnect({ unavailable = false }) {
  return (
    <div className="rounded-card border border-dashed border-linha p-4">
      <div className="flex items-start gap-3">
        <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full border border-linha text-muted">
          <Landmark size={17} aria-hidden="true" />
        </span>
        <div className="min-w-0 flex-1">
          <p className="font-medium">Conectar uma conta</p>
          <p className="mt-0.5 text-xs text-muted">
            Leitura apenas. Você autoriza no ambiente do banco e o VivaFinanças não vê sua senha.
          </p>
          <p className="mt-2 rounded-control bg-dourado/10 px-3 py-2 text-xs text-grafite" role="status">
            {unavailable
              ? 'Integração bancária indisponível: o servidor respondeu 503 porque a chave da Pluggy não está configurada.'
              : 'A conexão bancária real ainda não está habilitada: falta o widget e a configuração da Pluggy no servidor (503 até lá).'}
            {' '}A conexão de demonstração continua disponível para importar e reconciliar.
          </p>
          <Button
            variant="secondary"
            className="mt-3 px-3 py-1.5 text-xs"
            disabled={!REAL_CONNECTION_ENABLED || unavailable}
            title="Disponível quando o widget da Pluggy estiver configurado no servidor."
          >
            Conectar banco
          </Button>
        </div>
      </div>
    </div>
  )
}
