import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { bankConnections, categories } from './fixtures'
import { findCall, json, mockApi, renderApp } from './utils'

function baseRoutes(extra = {}) {
  return {
    'GET /categories': categories,
    'GET /banking/connections': { connections: bankConnections },
    'GET /alerts': { alertas: [] },
    ...extra,
  }
}

describe('Configurações e admin', () => {
  it('mostra a mensagem de Admin API indisponível', async () => {
    mockApi(
      baseRoutes({
        'GET /admin/members': () =>
          json(503, { error: { code: 'admin_indisponivel', message: 'Sem service role' } }),
        'GET /admin/invites': () =>
          json(503, { error: { code: 'admin_indisponivel', message: 'Sem service role' } }),
      }),
    )
    renderApp({ route: '/settings' })

    const messages = await screen.findAllByText(/configure SUPABASE_SERVICE_ROLE_KEY/)
    expect(messages.length).toBeGreaterThanOrEqual(2)
  })

  it('explica o 503 ao restaurar a demonstração', async () => {
    const user = userEvent.setup()
    mockApi(
      baseRoutes({
        'GET /admin/members': { members: [] },
        'GET /admin/invites': { invites: [] },
        'POST /demo/restore': () =>
          json(503, { error: { code: 'restore_indisponivel', message: 'Sem DB URL' } }),
      }),
    )
    renderApp({ route: '/settings' })

    await screen.findByRole('heading', { name: 'A casa arrumada' })
    await user.click(screen.getByRole('button', { name: 'Restaurar demonstração' }))

    const dialog = screen.getByRole('dialog')
    await user.click(within(dialog).getByRole('button', { name: 'Restaurar' }))

    expect(await screen.findByText(/configure SUPABASE_DB_URL/)).toBeInTheDocument()
  })

  it('não deixa o admin desativar a própria conta', async () => {
    const user = userEvent.setup()
    mockApi(
      baseRoutes({
        'GET /admin/members': {
          members: [
            { id: 'u-ana', nome: 'Ana Souza', papel: 'admin', status: 'ativo', criado_em: '2026-01-01' },
            { id: 'u-carlos', nome: 'Carlos Souza', papel: 'membro', status: 'ativo', criado_em: '2026-01-01' },
          ],
        },
        'GET /admin/invites': { invites: [] },
      }),
    )
    renderApp({ route: '/settings' })

    const membros = await screen.findByRole('region', { name: 'Membros' })
    const ana = within(membros).getByText('Ana Souza').closest('li')
    await user.click(within(ana).getByRole('button', { name: 'Editar' }))

    const dialog = screen.getByRole('dialog')
    expect(within(dialog).getByLabelText('Status')).toBeDisabled()
    expect(within(dialog).getByText('Sua conta precisa continuar ativa.')).toBeInTheDocument()
  })

  it('lista categorias ocultas nas configurações e permite mostrá-las', async () => {
    const user = userEvent.setup()
    const calls = mockApi(
      baseRoutes({
        'GET /admin/members': { members: [] },
        'GET /admin/invites': { invites: [] },
        'PATCH /categories/c-lazer': { ok: true },
      }),
    )
    renderApp({ route: '/settings' })

    const categorias = await screen.findByRole('region', { name: 'Categorias' })
    const lazer = within(categorias).getByText('Lazer').closest('li')
    await user.click(within(lazer).getByRole('button', { name: 'Mostrar' }))

    await waitFor(() =>
      expect(findCall(calls, 'PATCH', '/categories/c-lazer')?.body).toEqual({ oculta: false }),
    )
  })

  it('cria um convite e copia o link', async () => {
    const user = userEvent.setup()
    const writeText = vi.fn(async () => undefined)
    Object.defineProperty(navigator, 'clipboard', { value: { writeText }, configurable: true })

    mockApi(
      baseRoutes({
        'GET /admin/members': { members: [] },
        'GET /admin/invites': { invites: [] },
        'POST /admin/invites': { invite_id: 'i2', token: 'tok-2', email: 'bia@exemplo.com' },
      }),
    )
    renderApp({ route: '/settings' })

    await screen.findByRole('heading', { name: 'A casa arrumada' })
    await user.type(within(screen.getByRole('region', { name: 'Convites' })).getByLabelText('E-mail'), 'bia@exemplo.com')
    await user.click(screen.getByRole('button', { name: /Convidar/ }))

    await waitFor(() =>
      expect(screen.getByDisplayValue(/\/invite\/tok-2$/)).toBeInTheDocument(),
    )
    await user.click(screen.getByRole('button', { name: /Copiar/ }))
    await waitFor(() => expect(writeText).toHaveBeenCalled())
  })
})
