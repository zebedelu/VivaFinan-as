import { useState } from 'react'
import { Landmark } from 'lucide-react'
import Button from './Button'
import { useToast } from './Toast'
import { apiFetch, errorMessage } from '../services/api'

const PLUGGY_SCRIPT_URL = 'https://cdn.pluggy.ai/pluggy-connect/latest/pluggy-connect.js'
const GENERIC_ERROR = 'Não foi possível abrir o widget do banco. Verifique sua conexão e tente de novo.'

// One <script> per page: concurrent clicks share the pending promise, and the
// resolved global short-circuits later loads. A failed load resets the cache
// so the user can retry without reloading.
let pendingScript = null

function loadPluggyScript() {
  if (window.PluggyConnect) return Promise.resolve(window.PluggyConnect)
  if (pendingScript) return pendingScript

  pendingScript = new Promise((resolve, reject) => {
    const script = document.createElement('script')
    script.src = PLUGGY_SCRIPT_URL
    script.async = true
    script.addEventListener('load', () => {
      pendingScript = null
      if (window.PluggyConnect) resolve(window.PluggyConnect)
      else reject(new Error('Widget da Pluggy indisponível.'))
    })
    script.addEventListener('error', () => {
      pendingScript = null
      script.remove()
      reject(new Error('Falha ao carregar o widget da Pluggy.'))
    })
    document.head.appendChild(script)
  })

  return pendingScript
}

export default function PluggyConnect({ unavailable = false, onCreated }) {
  const toast = useToast()
  const [opening, setOpening] = useState(false)
  const [error, setError] = useState('')

  async function saveConnection(item) {
    if (!item?.id) {
      setError('O banco autorizou a conexão, mas não devolveu o identificador. Tente de novo.')
      return
    }
    try {
      await apiFetch('/banking/connections', {
        method: 'POST',
        body: {
          pluggy_connection_id: item.id,
          institution_name: item.connector?.name || 'Banco conectado',
          account_type: null,
        },
      })
      toast.push(
        item.connector?.name
          ? `Banco conectado: ${item.connector.name}. Sincronize para ver o extrato.`
          : 'Banco conectado. Sincronize para ver o extrato.',
      )
      onCreated?.()
    } catch (err) {
      setError(
        err?.status === 503
          ? 'Integração bancária indisponível: a chave da Pluggy não está configurada no servidor.'
          : errorMessage(err, 'O banco foi autorizado, mas não foi possível salvar a conexão. Tente de novo.'),
      )
    }
  }

  async function connect() {
    if (opening || unavailable) return
    setOpening(true)
    setError('')
    try {
      const token = await apiFetch('/banking/connect_token', { method: 'POST', body: {} })
      if (!token?.accessToken) {
        setError('O servidor não devolveu o token da conexão. Tente de novo.')
        return
      }
      const Widget = await loadPluggyScript()
      const widget = new Widget({
        connectToken: token.accessToken,
        includeSandbox: false,
        onSuccess: ({ item } = {}) => saveConnection(item),
        onError: () => setError('Não foi possível concluir a conexão com o banco. Tente de novo.'),
        onClose: () => {},
      })
      // O construtor só monta a instância; é o init() que abre o widget.
      widget.init()
    } catch (err) {
      if (err?.status === 503) {
        setError('Integração bancária indisponível: a chave da Pluggy não está configurada no servidor.')
      } else if (err?.status) {
        setError(errorMessage(err, GENERIC_ERROR))
      } else {
        setError(GENERIC_ERROR)
      }
    } finally {
      setOpening(false)
    }
  }

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
              ? 'Integração bancária indisponível: o servidor respondeu 503 porque a chave da Pluggy não está configurada. A conexão de demonstração continua disponível para importar e reconciliar.'
              : 'A conexão de demonstração continua disponível para importar e reconciliar.'}
          </p>
          {error ? (
            <p
              className="mt-2 rounded-control border border-terracota/30 bg-terracota/5 px-3 py-2 text-xs text-terracota-texto"
              role="alert"
            >
              {error}
            </p>
          ) : null}
          <Button
            variant="secondary"
            className="mt-3 px-3 py-1.5 text-xs"
            disabled={unavailable}
            loading={opening}
            onClick={connect}
            title={
              unavailable
                ? 'Disponível quando o servidor tiver a chave da Pluggy configurada.'
                : 'Abrir o ambiente seguro da Pluggy para autorizar seu banco.'
            }
          >
            Conectar banco
          </Button>
        </div>
      </div>
    </div>
  )
}
