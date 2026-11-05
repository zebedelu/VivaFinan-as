import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { categories, transactions } from './fixtures'
import { addMonths, clampNumber, currentMonth, goalProgress } from '../lib/format'
import { findCall, json, mockApi, renderApp } from './utils'

const alert = {
  tipo: 'conta_a_vencer',
  titulo: 'Internet vence amanhã',
  detalhe: 'Confirme para entrar no mês.',
  escopo: 'familia',
}

function baseRoutes(extra = {}) {
  return {
    'GET /transactions': { items: transactions, total: transactions.length },
    'GET /categories': categories,
    'GET /alerts': { alertas: [] },
    ...extra,
  }
}

describe('Parser monetário', () => {
  it('aceita os formatos brasileiros e o ponto decimal', () => {
    expect(clampNumber('1.234,56')).toBe(1234.56)
    expect(clampNumber('1.234')).toBe(1234)
    expect(clampNumber('1234,56')).toBe(1234.56)
    expect(clampNumber('1234.56')).toBe(1234.56)
    expect(clampNumber('R$ 2.500,00')).toBe(2500)
    expect(clampNumber('abc')).toBe(0)
  })

  it('calcula progresso como percentual quando só há progresso', () => {
    expect(goalProgress({ valor_alvo: 1000, progresso: 40 })).toEqual({ contribuido: 400, pct: 40 })
    expect(
      goalProgress({
        valor_alvo: 1000,
        progresso: 99,
        contribuicoes: [{ valor: 250 }],
      }),
    ).toEqual({ contribuido: 250, pct: 25 })
  })
})

describe('Navegação e sessão', () => {
  it('pede o mês seguinte ao avançar no seletor', async () => {
    const user = userEvent.setup()
    const calls = mockApi(baseRoutes())
    renderApp({ route: '/transactions' })

    await screen.findByRole('heading', { name: 'O que entrou e saiu' })
    await user.click(screen.getByRole('button', { name: 'Próximo mês' }))

    const next = addMonths(currentMonth(), 1)
    await waitFor(() => {
      expect(calls.some((call) => call.path === '/transactions' && call.url.includes(`mes=${next}`))).toBe(true)
    })
  })

  it('mostra a sessão expirada quando a API responde 401', async () => {
    mockApi(
      baseRoutes({
        'GET /transactions': () => json(401, { error: { code: 'nao_autorizado', message: 'Sessão inválida' } }),
      }),
    )
    renderApp({ route: '/transactions' })

    expect(await screen.findByText('Sua sessão expirou. Entre de novo.')).toBeInTheDocument()
  })

  it('abre o sino com os alertas do dia', async () => {
    const user = userEvent.setup()
    const calls = mockApi(baseRoutes({ 'GET /alerts': { alertas: [alert] } }))
    renderApp({ route: '/transactions' })

    const sino = await screen.findByRole('button', { name: 'Alertas: 1 hoje' })
    await user.click(sino)

    const dialog = screen.getByRole('dialog')
    expect(within(dialog).getByText(alert.titulo)).toBeInTheDocument()
    expect(calls.filter((call) => call.method === 'GET' && call.path === '/alerts')).toHaveLength(1)
  })
})

describe('Meu espaço', () => {
  it('usa o resumo e os alertas de /me/summary sem duplicar /alerts', async () => {
    const summary = {
      mes: currentMonth(),
      totais: { receitas: 5000, despesas: 1200, saldo: 3800 },
      categorias: [],
      metas: [
        {
          id: 'g9',
          titulo: 'Reserva',
          valor_alvo: 1000,
          prazo: null,
          status: 'em_andamento',
          descricao: null,
          member_id: 'u-ana',
          member_nome: 'Ana Souza',
          criado_por: 'u-ana',
          criado_por_nome: 'Ana Souza',
          progresso: 25,
        },
      ],
      recorrentes_pendentes: [],
      sugestoes: [],
      alertas: [alert],
      banco: { conexoes: 1, pendentes: 2, ultima_sync: null },
    }
    const calls = mockApi({ 'GET /me/summary': summary, 'GET /alerts': { alertas: [] } })
    renderApp({ route: '/individual' })

    await screen.findByText('Seu banco', undefined, { timeout: 3000 })
    expect(screen.getByRole('heading', { name: 'Olá, Ana!' })).toBeInTheDocument()
    expect(screen.getByText(alert.titulo)).toBeInTheDocument()
    expect(screen.getByText(/250,00/)).toBeInTheDocument()
    expect(screen.getByText('Contas conectadas')).toBeInTheDocument()
    expect(findCall(calls, 'GET', '/alerts')).toBeTruthy()
    expect(calls.filter((call) => call.method === 'GET' && call.path === '/alerts')).toHaveLength(1)
  })
})
