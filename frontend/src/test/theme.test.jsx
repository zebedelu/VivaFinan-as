import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { bankConnections, categories } from './fixtures'
import { mockApi, renderApp } from './utils'

describe('Tema', () => {
  it('aplica e persiste o tema escuro ao escolher no perfil', async () => {
    const user = userEvent.setup()
    mockApi({
      'GET /admin/members': { members: [] },
      'GET /admin/invites': { invites: [] },
      'GET /categories': categories,
      'GET /banking/connections': { connections: bankConnections },
    })
    const updateProfile = vi.fn(async () => ({}))
    const { sessionValue } = renderApp({
      route: '/settings',
      overrides: { updateProfile },
    })

    expect(await screen.findByRole('heading', { name: 'A casa arrumada' })).toBeInTheDocument()
    expect(document.documentElement.dataset.theme).toBe('claro')

    await user.click(screen.getByRole('button', { name: 'Escuro' }))

    await waitFor(() => {
      expect(document.documentElement.dataset.theme).toBe('escuro')
    })
    expect(window.localStorage.getItem('vf-tema')).toBe('escuro')
    expect(sessionValue.updateProfile).toHaveBeenCalledWith({ tema: 'escuro' })
  })
})
