import { useEffect, useRef, useState } from 'react'
import { Send, Sparkles } from 'lucide-react'
import Badge from '../components/Badge'
import Button from '../components/Button'
import { Loading } from '../components/Loading'
import Section from '../components/Section'
import SegmentedControl from '../components/SegmentedControl'
import { ErrorState, UnavailableState } from '../components/StatePanels'
import SuggestionCard from '../components/SuggestionCard'
import { useToast } from '../components/Toast'
import { useApi } from '../hooks/useApi'
import { useSession } from '../hooks/useSession'
import { firstName } from '../lib/format'
import { apiFetch, errorMessage } from '../services/api'

const PROMPTS = [
  'Como está o mês da família?',
  'Onde dá para economizar sem cortar o que importa?',
  'Estou perto de alguma meta?',
]

function asMessages(data) {
  if (Array.isArray(data)) return data
  return data?.messages || []
}

export default function JevAI() {
  const { profile } = useSession()
  const toast = useToast()
  const [escopo, setEscopo] = useState('familia')
  const messagesApi = useApi(`/ai/messages?escopo=${escopo}`)
  const suggestionsApi = useApi(`/ai/suggestions?escopo=${escopo}`)
  const [suggestions, setSuggestions] = useState([])
  const [mode, setMode] = useState(null)
  const [composer, setComposer] = useState('')
  const [sending, setSending] = useState(false)
  const [sendError, setSendError] = useState('')
  const listRef = useRef(null)

  const messages = asMessages(messagesApi.data)

  useEffect(() => {
    if (suggestionsApi.data) {
      const list = Array.isArray(suggestionsApi.data)
        ? suggestionsApi.data
        : suggestionsApi.data.suggestions || []
      setSuggestions(list)
    }
  }, [suggestionsApi.data])

  useEffect(() => {
    const nextMode = messagesApi.data?.mode || suggestionsApi.data?.mode
    if (nextMode) setMode(nextMode)
  }, [messagesApi.data, suggestionsApi.data])

  useEffect(() => {
    if (listRef.current) listRef.current.scrollTop = listRef.current.scrollHeight
  }, [messages.length])

  async function send(event) {
    event?.preventDefault()
    const content = composer.trim()
    if (!content) return
    setSendError('')
    setSending(true)
    try {
      const result = await apiFetch('/ai/messages', {
        method: 'POST',
        body: { content, escopo },
      })
      if (result?.mode) setMode(result.mode)
      if (Array.isArray(result?.suggestions)) setSuggestions(result.suggestions)
      setComposer('')
      messagesApi.refetch()
      suggestionsApi.refetch()
    } catch (err) {
      setSendError(errorMessage(err, 'A Jev não conseguiu responder agora.'))
    } finally {
      setSending(false)
    }
  }

  async function markRead(suggestion) {
    setSuggestions((current) =>
      current.map((item) => (item.id === suggestion.id ? { ...item, lida: true } : item)),
    )
    try {
      await apiFetch(`/ai/suggestions/${suggestion.id}/read`, {
        method: 'PATCH',
        body: { lida: true },
      })
    } catch (err) {
      toast.push(errorMessage(err, 'Não foi possível marcar a sugestão como lida.'), 'error')
      suggestionsApi.refetch()
    }
  }

  const unavailable = messagesApi.error?.status === 503 || suggestionsApi.error?.status === 503

  return (
    <div>
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="text-sm text-muted">Jev AI</p>
          <h1 className="mt-1 font-display text-3xl">Uma segunda opinião sobre o mês</h1>
          <p className="mt-2 max-w-xl text-sm text-muted">
            A Jev lê os números que você já tem e devolve sugestões com o que fazer, por quê e quanto.
            Ela não mexe em nada sozinha.
          </p>
        </div>
        <div className="flex items-center gap-2">
          {mode && mode !== 'jev' ? <Badge tone="dourado">Modo local</Badge> : null}
          <SegmentedControl
            label="Escopo da conversa"
            value={escopo}
            onChange={setEscopo}
            options={[
              { value: 'familia', label: 'Família' },
              { value: 'pessoal', label: 'Pessoal' },
            ]}
          />
        </div>
      </div>

      {mode && mode !== 'jev' ? (
        <p className="mt-5 rounded-control border border-dourado/40 bg-dourado-forte/10 px-4 py-3 text-sm">
          A Jev está em modo local: as respostas vêm de regras sobre os seus dados, sem IA externa.
          Tudo o que aparece aqui continua válido como ponto de partida.
        </p>
      ) : null}

      {unavailable ? (
        <div className="mt-6">
          <UnavailableState
            title="Jev AI indisponível"
            description="O servidor não conseguiu abrir a conversa agora. Seus lançamentos continuam intactos."
            onRetry={() => {
              messagesApi.refetch()
              suggestionsApi.refetch()
            }}
          />
        </div>
      ) : null}

      {!unavailable ? (
        <div className="mt-8 grid gap-10 lg:grid-cols-[1.25fr_0.75fr]">
          <section aria-labelledby="conversa" className="flex min-h-[26rem] flex-col">
            <h2 id="conversa" className="section-title">
              Conversa
            </h2>
            <div className="mt-3 flex-1 rounded-card border border-linha bg-superficie">
              <div ref={listRef} className="max-h-[48vh] min-h-[18rem] space-y-4 overflow-y-auto p-4 sm:p-5">
                {messagesApi.loading ? <Loading label="Abrindo a conversa" rows={2} /> : null}

                {!messagesApi.loading && messages.length === 0 ? (
                  <div className="py-8">
                    <Sparkles size={18} className="text-dourado-forte" aria-hidden="true" />
                    <p className="mt-3 font-display text-xl">
                      Olá, {firstName(profile?.nome) || 'tudo bem'}.
                    </p>
                    <p className="mt-1 max-w-sm text-sm text-muted">
                      Posso olhar o mês, as categorias e as metas. Escolha uma pergunta para começar
                      ou escreva a sua.
                    </p>
                    <div className="mt-4 flex flex-wrap gap-2">
                      {PROMPTS.map((prompt) => (
                        <button
                          key={prompt}
                          type="button"
                          onClick={() => setComposer(prompt)}
                          className="rounded-full border border-linha px-3 py-1.5 text-left text-xs text-muted transition-colors hover:border-verde hover:text-grafite"
                        >
                          {prompt}
                        </button>
                      ))}
                    </div>
                  </div>
                ) : null}

                {messages.map((message) => {
                  const fromUser = message.role === 'user'
                  return (
                    <div key={message.id} className={`flex ${fromUser ? 'justify-end' : 'justify-start'}`}>
                      <div
                        className={`max-w-[88%] rounded-card px-3.5 py-2.5 text-sm leading-relaxed ${
                          fromUser
                            ? 'bg-verde text-sobre-verde'
                            : 'border border-linha bg-areia text-grafite'
                        }`}
                      >
                        <p className="whitespace-pre-wrap">{message.content}</p>
                      </div>
                    </div>
                  )
                })}
              </div>

              <form onSubmit={send} className="border-t border-linha p-3 sm:p-4">
                <label htmlFor="jev-composer" className="sr-only">
                  Escreva para a Jev
                </label>
                <div className="flex items-end gap-2">
                  <textarea
                    id="jev-composer"
                    className="field min-h-[44px] resize-none py-2.5"
                    rows={1}
                    value={composer}
                    onChange={(event) => setComposer(event.target.value)}
                    placeholder="Pergunte sobre o mês, uma categoria, uma meta…"
                    onKeyDown={(event) => {
                      if (event.key === 'Enter' && !event.shiftKey) {
                        event.preventDefault()
                        send(event)
                      }
                    }}
                  />
                  <Button type="submit" loading={sending} disabled={!composer.trim()} className="shrink-0">
                    <Send size={15} aria-hidden="true" /> Enviar
                  </Button>
                </div>
                {sendError ? (
                  <p className="mt-2 text-xs text-terracota-texto" role="alert">
                    {sendError}
                  </p>
                ) : null}
                <p className="mt-2 text-2xs text-muted">
                  {escopo === 'familia'
                    ? 'Na família, a Jev usa só os totais. Nenhum detalhe individual é exposto.'
                    : 'No modo pessoal, a Jev usa apenas as suas transações e metas.'}
                </p>
              </form>
            </div>
          </section>

          <Section
            id="sugestoes-jev"
            title="Sugestões"
            description={
              suggestions.length
                ? `${suggestions.filter((item) => !item.lida).length} não lidas`
                : 'Aparecem quando há padrão suficiente.'
            }
          >
            {suggestionsApi.loading ? <Loading label="Carregando sugestões" rows={2} /> : null}
            {suggestionsApi.error && suggestionsApi.error.status !== 503 ? (
              <ErrorState error={suggestionsApi.error} onRetry={suggestionsApi.refetch} />
            ) : null}
            {!suggestionsApi.loading && !suggestionsApi.error && suggestions.length === 0 ? (
              <p className="py-4 text-sm text-muted">
                Nada por aqui ainda. Converse com a Jev para pedir uma análise do mês.
              </p>
            ) : null}
            {suggestions.map((suggestion) => (
              <SuggestionCard key={suggestion.id} suggestion={suggestion} onRead={markRead} />
            ))}
          </Section>
        </div>
      ) : null}
    </div>
  )
}
