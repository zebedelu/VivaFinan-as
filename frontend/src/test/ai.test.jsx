import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { suggestions } from './fixtures'
import { findCall, mockApi, renderApp } from './utils'

describe('Jev AI', () => {
  it('mostra o modo local e as sugestões com o quê, por quê e quanto', async () => {
    mockApi({
      'GET /ai/messages': { messages: [], mode: 'fallback' },
      'GET /ai/suggestions': { suggestions },
      'GET /alerts': { alertas: [] },
    })
    renderApp({ route: '/ai' })

    expect(await screen.findByText(/A Jev está em modo local/)).toBeInTheDocument()
    expect(screen.getByText('Revise as assinaturas')).toBeInTheDocument()
    expect(screen.getByText('O que fazer')).toBeInTheDocument()
    expect(screen.getByText('Por quê')).toBeInTheDocument()
    expect(screen.getByText('Quanto')).toBeInTheDocument()
    expect(screen.getByText('R$ 80 por mês')).toBeInTheDocument()
  })

  it('envia uma mensagem e marca a sugestão como lida', async () => {
    const user = userEvent.setup()
    const calls = mockApi({
      'GET /ai/messages': { messages: [], mode: 'fallback' },
      'GET /ai/suggestions': { suggestions },
      'GET /alerts': { alertas: [] },
      'POST /ai/messages': { messages: [], suggestions, mode: 'fallback' },
      'PATCH /ai/suggestions/*/read': { ok: true },
    })
    renderApp({ route: '/ai' })

    await screen.findByText('Revise as assinaturas')
    await user.type(screen.getByLabelText('Escreva para a Jev'), 'Como está o mês?')
    await user.click(screen.getByRole('button', { name: /Enviar/ }))

    await waitFor(() => {
      const call = findCall(calls, 'POST', '/ai/messages')
      expect(call?.body).toEqual({ content: 'Como está o mês?', escopo: 'familia' })
    })

    await user.click(screen.getByRole('button', { name: /Marcar como lida/ }))
    await waitFor(() =>
      expect(findCall(calls, 'PATCH', '/ai/suggestions/s1/read')?.body).toEqual({ lida: true }),
    )
  })
})
