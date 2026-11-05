import { mkdirSync } from 'node:fs'
import { test, expect } from '@playwright/test'

const EMAIL = 'ana@demo.vivafinancas.app'
const PASSWORD = 'Demo@2026!'

async function login(page) {
  await page.goto('/login')
  await page.getByLabel('E-mail').fill(EMAIL)
  await page.getByLabel('Senha').fill(PASSWORD)
  await page.locator('form').getByRole('button', { name: 'Entrar' }).click()
  await expect(page).toHaveURL(/\/$/, { timeout: 45_000 })
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible({ timeout: 45_000 })
}

test.describe.serial('VivaFinancas v1', () => {
  test.describe.configure({ timeout: 180_000 })
  test.beforeAll(() => mkdirSync('e2e-artifacts', { recursive: true }))
  test.beforeEach(async ({ page }) => {
    await login(page)
  })

  test('painel e tema persistem', async ({ page }, testInfo) => {
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible({ timeout: 45_000 })
    await expect(page.getByText(/6\.913,00/).first()).toBeVisible({ timeout: 60_000 })
    await page.screenshot({ path: `e2e-artifacts/painel-${testInfo.project.name}.png`, fullPage: true })

    const before = await page.locator('html').getAttribute('data-theme')
    const toggle = page.getByRole('button', { name: /Ativar tema (escuro|claro)/ })
    await toggle.click()
    const after = await page.locator('html').getAttribute('data-theme')
    expect(after).not.toBe(before)
    await page.reload()
    await expect(page.locator('html')).toHaveAttribute('data-theme', after, { timeout: 45_000 })
    await page.screenshot({ path: `e2e-artifacts/painel-tema-${testInfo.project.name}.png`, fullPage: true })
  })

  test('cria um lançamento com categoria sugerida', async ({ page }, testInfo) => {
    await page.getByRole('link', { name: 'Lançamentos' }).click()
    await expect(page.getByRole('heading', { name: 'O que entrou e saiu' })).toBeVisible({ timeout: 45_000 })
    await page.getByRole('button', { name: 'Novo lançamento' }).click()
    const dialog = page.getByRole('dialog')
    const classificou = page
      .waitForResponse(
        (r) => r.url().includes('/api/ai/classify') && r.request().method() === 'POST',
        { timeout: 45_000 },
      )
      .catch(() => null)
    await dialog.getByLabel('Descrição').fill('Padaria E2E')
    await classificou
    const categoria = dialog.getByLabel('Categoria')
    await expect(categoria.locator('option')).not.toHaveCount(1, { timeout: 45_000 })
    await categoria.selectOption({ index: 1 })
    await dialog.getByLabel('Valor').fill('45,90')
    const salvar = dialog.getByRole('button', { name: 'Salvar lançamento' })
    await expect(salvar).toBeEnabled()
    await salvar.click()
    await expect(dialog).toBeHidden({ timeout: 60_000 })
    await expect(page.getByText('Padaria E2E').first()).toBeVisible({ timeout: 60_000 })
    await page.screenshot({ path: `e2e-artifacts/transacoes-${testInfo.project.name}.png`, fullPage: true })
  })

  test('confirma uma conta pendente', async ({ page }) => {
    await page.getByRole('link', { name: 'Recorrentes' }).click()
    await expect(page.getByRole('heading', { name: 'O que volta todo mês' })).toBeVisible({ timeout: 45_000 })
    const fila = page.getByRole('region', { name: 'Para confirmar' })
    await expect(fila).toBeVisible({ timeout: 45_000 })
    const primeiro = fila.locator('article').first()
    if ((await primeiro.count()) === 0) test.skip(true, 'sem conta pendente no demo')
    await primeiro.getByRole('button', { name: 'Confirmar', exact: true }).click()
    await expect(page.getByText('Conta confirmada.')).toBeVisible({ timeout: 60_000 })
  })

  test('importa, ignora e desfaz no extrato demo', async ({ page }, testInfo) => {
    await page.getByRole('link', { name: 'Extrato' }).click()
    await expect(page.getByRole('heading', { name: 'O que passou pelo banco' })).toBeVisible({ timeout: 45_000 })

    await page.getByRole('button', { name: /^Importar / }).first().click()
    const dialog = page.getByRole('dialog')
    const categoria = dialog.getByLabel('Categoria')
    await page.waitForTimeout(2500)
    if (!(await categoria.inputValue())) await categoria.selectOption({ index: 1 })
    await dialog.getByRole('button', { name: 'Importar', exact: true }).click()
    await expect(page.getByText('Transação importada.')).toBeVisible({ timeout: 60_000 })

    await page.getByRole('button', { name: /^Ignorar / }).first().click()
    await expect(page.getByText('Transação ignorada.')).toBeVisible({ timeout: 60_000 })

    await page.getByRole('button', { name: /^Desfazer ignorar / }).first().click()
    await expect(page.getByText('Transação voltou para a fila.')).toBeVisible({ timeout: 60_000 })
    await page.screenshot({ path: `e2e-artifacts/extrato-${testInfo.project.name}.png`, fullPage: true })
  })

  test('restaura a demonstração e volta ao login', async ({ page }) => {
    await page.getByRole('link', { name: 'Configurações', exact: true }).click()
    await expect(page.getByRole('heading', { name: 'A casa arrumada' })).toBeVisible({ timeout: 45_000 })
    await page.getByRole('button', { name: 'Restaurar demonstração' }).click()
    const dialog = page.getByRole('dialog')
    await dialog.getByRole('button', { name: 'Restaurar', exact: true }).click()
    await expect(page).toHaveURL(/\/login/, { timeout: 120_000 })
  })
})
