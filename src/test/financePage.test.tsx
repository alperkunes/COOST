import { cleanup, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import { FinancePage } from '../modules/finance/pages/FinancePage'

const { tenant, overview } = vi.hoisted(() => ({
  tenant: { tenantId: 'tenant-1', context: { modules: ['finance'], permissions: ['finance.read'] } },
  overview: { accounts: [{ id: 'cash', name: 'Kasa', accountType: 'CASH', currencyCode: 'TRY', status: 'ACTIVE', balance: 100 }], recentTransactions: [] },
}))
vi.mock('../shared/tenant/useTenant', () => ({ useTenant: () => tenant }))
vi.mock('../shared/supabase/client', () => ({ supabase: { rpc: vi.fn() } }))
vi.mock('../modules/finance/queries/useFinanceOverview', () => ({
  useFinanceOverview: () => ({ data: overview, isPending: false, isError: false, isFetching: false }),
}))

afterEach(cleanup)
beforeEach(() => {
  tenant.context.permissions = ['finance.read']
  tenant.context.modules = ['finance']
})

function setup() {
  render(<QueryClientProvider client={new QueryClient()}><FinancePage /></QueryClientProvider>)
}

it('hides cashflow, adjustment and transfer actions for read-only users', () => {
  setup()
  expect(screen.queryByRole('button', { name: 'Gelir / Gider Ekle' })).not.toBeInTheDocument()
  expect(screen.queryByRole('button', { name: 'Transfer Yap' })).not.toBeInTheDocument()
  expect(screen.queryByRole('button', { name: 'Düzelt' })).not.toBeInTheDocument()
  expect(screen.queryByRole('button', { name: 'Hesapları Yönet' })).not.toBeInTheDocument()
})

it('opens and closes cashflow for a finance writer', async () => {
  tenant.context.permissions.push('finance.write')
  setup()
  const user = userEvent.setup()
  await user.click(screen.getByRole('button', { name: 'Gelir / Gider Ekle' }))
  expect(screen.getByRole('dialog', { name: 'Gelir / Gider Ekle' })).toBeInTheDocument()
  await user.click(screen.getByRole('button', { name: 'Kapat' }))
  expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
})

it('hides cashflow when finance is disabled even with write permission', () => {
  tenant.context.permissions.push('finance.write')
  tenant.context.modules = []
  setup()
  expect(screen.queryByRole('button', { name: 'Gelir / Gider Ekle' })).not.toBeInTheDocument()
  expect(screen.queryByRole('button', { name: 'Hesapları Yönet' })).not.toBeInTheDocument()
})

it('excludes passive accounts from overview totals and transaction selections', async () => {
  tenant.context.permissions.push('finance.write')
  overview.accounts.push({ id: 'passive', name: 'Kapalı Kasa', accountType: 'CASH', currencyCode: 'TRY', status: 'PASSIVE', balance: 900 })
  try {
    setup()
    expect(screen.queryByText('Kapalı Kasa')).not.toBeInTheDocument()
    expect(screen.queryByText(/1\.000,00/)).not.toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Transfer Yap' })).toBeDisabled()
    const user = userEvent.setup()
    await user.click(screen.getByRole('button', { name: 'Gelir / Gider Ekle' }))
    expect(screen.queryByRole('option', { name: /Kapalı Kasa/ })).not.toBeInTheDocument()
    expect(screen.getByRole('option', { name: /Kasa \(TRY\)/ })).toBeInTheDocument()
  } finally {
    overview.accounts.pop()
  }
})
