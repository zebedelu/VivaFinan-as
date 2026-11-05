import { screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { mockApi, renderApp } from './utils'

describe('ProtectedRoute', () => {
  it('manda para o login quando não há sessão', async () => {
    mockApi({})
    renderApp({ route: '/', session: null, profile: null, family: null })
    expect(await screen.findByRole('heading', { name: 'Bem-vindo de volta' })).toBeInTheDocument()
  })

  it('mostra conta desativada sem renderizar os dados', async () => {
    mockApi({})
    renderApp({
      profile: { id: 'u-ana', nome: 'Ana', papel: 'admin', status: 'inativo', tema: 'claro' },
    })
    expect(await screen.findByRole('heading', { name: 'Conta desativada' })).toBeInTheDocument()
    expect(screen.queryByText('Saldo do mês')).not.toBeInTheDocument()
  })
})
