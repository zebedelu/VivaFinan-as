import { test, expect } from '@playwright/test'

const EMAIL = 'ana@demo.vivafinancas.app'
const PASSWORD = 'Demo@2026!'

test('login demo abre o painel', async ({ page }) => {
  await page.goto('/login')
  await page.getByLabel('E-mail').fill(EMAIL)
  await page.getByLabel('Senha').fill(PASSWORD)
  await page.locator('form').getByRole('button', { name: 'Entrar' }).click()
  await expect(page).toHaveURL(/\/$/, { timeout: 25_000 })
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible({ timeout: 25_000 })
})
