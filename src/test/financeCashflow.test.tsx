import { act, cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { FinanceCashflowDialog } from '../modules/finance/pages/FinanceCashflowDialog'
import { FinancePage } from '../modules/finance/pages/FinancePage'
import { parseCashflowAmount } from '../modules/finance/model/financeCashflow'
import type { FinanceOverviewAccount } from '../modules/finance/model/financeOverview'

const mocks = vi.hoisted(() => ({ rpc: vi.fn(), useTenant: vi.fn(), useFinanceOverview: vi.fn() }))
vi.mock('../shared/supabase/client', () => ({ supabase: { rpc: mocks.rpc } }))
vi.mock('../shared/tenant/useTenant', () => ({ useTenant: mocks.useTenant }))
vi.mock('../modules/finance/queries/useFinanceOverview', () => ({ useFinanceOverview: mocks.useFinanceOverview }))

const accounts: FinanceOverviewAccount[] = [
  { id: 'cash', name: 'Kasa', accountType: 'CASH', currencyCode: 'TRY', status: 'ACTIVE', balance: 200 },
  { id: 'bank', name: 'Banka', accountType: 'BANK', currencyCode: 'USD', status: 'ACTIVE', balance: 100 },
]

function setup(page = false) {
  const client = new QueryClient({ defaultOptions: { mutations: { retry: false }, queries: { retry: false } } })
  const invalidate = vi.spyOn(client, 'invalidateQueries')
  const onClose = vi.fn()
  render(<QueryClientProvider client={client}>{page ? <FinancePage /> : <FinanceCashflowDialog accounts={accounts} onClose={onClose} />}</QueryClientProvider>)
  return { user: userEvent.setup(), onClose, invalidate }
}

async function fill(user: ReturnType<typeof userEvent.setup>, type = 'INCOME') {
  await user.selectOptions(screen.getByLabelText('İşlem türü'), type)
  await user.selectOptions(screen.getByLabelText('Hesap'), 'cash')
  await user.type(screen.getByLabelText('Tutar'), '1.234,56')
  await user.type(screen.getByLabelText('Açıklama'), '  Nakit hareketi  ')
}

beforeEach(() => {
  mocks.rpc.mockReset()
  mocks.useTenant.mockReturnValue({ tenantId: 'tenant-1', context: { modules: ['finance'], permissions: ['finance.read', 'finance.write'] } })
  mocks.useFinanceOverview.mockReturnValue({ data: { accounts, recentTransactions: [] }, isPending: false, isError: false, isFetching: false })
})
afterEach(cleanup)

describe('finance cashflow', () => {
  it.each(['', '0', '-1', '+1', '0,001', '1.234', '1e3', 'NaN', 'Infinity', '1,2,3', '1.2.3,45', '100000000000000'])('rejects invalid amount %s', (value) => {
    expect(parseCashflowAmount(value)).toBeNull()
  })
  it.each([['1.234,56', 1234.56], ['12,50', 12.5], ['12.50', 12.5], ['0,01', 0.01]])('parses %s', (value, expected) => {
    expect(parseCashflowAmount(String(value))).toBe(expected)
  })

  it.each(['INCOME', 'EXPENSE'])('sends positive %s RPC params, refreshes and closes', async (type) => {
    mocks.rpc.mockResolvedValue({ data: 'transaction-id', error: null })
    const { user, onClose, invalidate } = setup()
    await fill(user, type)
    await user.click(screen.getByRole('button', { name: type === 'INCOME' ? 'Geliri Kaydet' : 'Gideri Kaydet' }))
    await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
    expect(mocks.rpc).toHaveBeenCalledExactlyOnceWith('create_finance_cashflow', {
      p_tenant_id: 'tenant-1', p_account_id: 'cash', p_transaction_type: type,
      p_amount: 1234.56, p_description: 'Nakit hareketi',
    })
    expect(invalidate).toHaveBeenCalledWith({ queryKey: ['finance-overview', 'tenant-1'] })
  })

  it('shows the selected account currency', async () => {
    const { user } = setup()
    await user.selectOptions(screen.getByLabelText('Hesap'), 'cash')
    expect(screen.getByText('TRY', { selector: '.finance-money-input > span' })).toBeVisible()
    await user.selectOptions(screen.getByLabelText('Hesap'), 'bank')
    expect(screen.getByText('USD', { selector: '.finance-money-input > span' })).toBeVisible()
  })

  it.each(['0', '-50', '0,001', 'abc'])('blocks form submission for amount %s', async (amount) => {
    const { user } = setup()
    await fill(user)
    fireEvent.change(screen.getByLabelText('Tutar'), { target: { value: amount } })
    const button = screen.getByRole('button', { name: 'Geliri Kaydet' })
    expect(button).toBeDisabled()
    fireEvent.submit(button.closest('form')!)
    expect(mocks.rpc).not.toHaveBeenCalled()
  })

  it.each(['', '   ', ' x ', 'x'.repeat(501)])('blocks invalid description (%s)', async (description) => {
    const { user } = setup()
    await fill(user)
    fireEvent.change(screen.getByLabelText('Açıklama'), { target: { value: description } })
    const button = screen.getByRole('button', { name: 'Geliri Kaydet' })
    expect(button).toBeDisabled()
    fireEvent.submit(button.closest('form')!)
    expect(mocks.rpc).not.toHaveBeenCalled()
  })

  it('requires an account', async () => {
    const { user } = setup()
    await fill(user)
    await user.selectOptions(screen.getByLabelText('Hesap'), '')
    const button = screen.getByRole('button', { name: 'Geliri Kaydet' })
    expect(button).toBeDisabled()
    fireEvent.submit(button.closest('form')!)
    expect(mocks.rpc).not.toHaveBeenCalled()
  })

  it('preserves all input after RPC error and permits retry', async () => {
    mocks.rpc.mockResolvedValueOnce({ data: null, error: { message: 'Kayıt reddedildi' } })
    mocks.rpc.mockResolvedValueOnce({ data: 'transaction-id', error: null })
    const { user, onClose, invalidate } = setup()
    await fill(user, 'EXPENSE')
    await user.click(screen.getByRole('button', { name: 'Gideri Kaydet' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Kayıt reddedildi')
    expect(screen.getByLabelText('İşlem türü')).toHaveValue('EXPENSE')
    expect(screen.getByLabelText('Hesap')).toHaveValue('cash')
    expect(screen.getByLabelText('Tutar')).toHaveValue('1.234,56')
    expect(screen.getByLabelText('Açıklama')).toHaveValue('  Nakit hareketi  ')
    expect(onClose).not.toHaveBeenCalled()
    expect(invalidate).not.toHaveBeenCalled()
    await user.click(screen.getByRole('button', { name: 'Gideri Kaydet' }))
    await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
    expect(mocks.rpc).toHaveBeenCalledTimes(2)
  })

  it('blocks duplicate submit and closing while saving', async () => {
    let resolve!: (value: unknown) => void
    mocks.rpc.mockImplementation(() => new Promise((done) => { resolve = done }))
    const { user, onClose } = setup()
    await fill(user)
    const form = screen.getByRole('button', { name: 'Geliri Kaydet' }).closest('form')!
    fireEvent.submit(form)
    fireEvent.submit(form)
    await waitFor(() => expect(mocks.rpc).toHaveBeenCalledOnce())
    expect(screen.getByRole('button', { name: 'Kaydediliyor...' })).toBeDisabled()
    expect(screen.getByRole('button', { name: 'Kapat' })).toBeDisabled()
    expect(screen.getByLabelText('Tutar')).toBeDisabled()
    await user.keyboard('{Escape}')
    fireEvent.mouseDown(screen.getByRole('presentation'))
    expect(onClose).not.toHaveBeenCalled()
    await act(async () => resolve({ data: 'transaction-id', error: null }))
    await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
  })

  it('hides all write actions from read-only users', () => {
    mocks.useTenant.mockReturnValue({ tenantId: 'tenant-1', context: { modules: ['finance'], permissions: ['finance.read'] } })
    setup(true)
    expect(screen.queryByRole('button', { name: 'Gelir / Gider Ekle' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Transfer Yap' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Düzelt' })).not.toBeInTheDocument()
    expect(screen.getByText('Salt okunur')).toBeVisible()
  })

  it('hides cashflow when the module is disabled', () => {
    mocks.useTenant.mockReturnValue({ tenantId: 'tenant-1', context: { modules: [], permissions: ['finance.write'] } })
    setup(true)
    expect(screen.queryByRole('button', { name: 'Gelir / Gider Ekle' })).not.toBeInTheDocument()
  })

  it('opens the dialog for writers and restores focus on Escape', async () => {
    const { user } = setup(true)
    const trigger = screen.getByRole('button', { name: 'Gelir / Gider Ekle' })
    await user.click(trigger)
    expect(screen.getByRole('dialog')).toBeVisible()
    expect(screen.getByLabelText('İşlem türü')).toHaveFocus()
    await user.keyboard('{Escape}')
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
    expect(trigger).toHaveFocus()
  })

  it('disables adding cashflow without accounts', () => {
    mocks.useFinanceOverview.mockReturnValue({ data: { accounts: [], recentTransactions: [] }, isPending: false, isError: false })
    setup(true)
    expect(screen.getByRole('button', { name: 'Gelir / Gider Ekle' })).toBeDisabled()
  })

  it('renders recent income and expense with the ledger signs', () => {
    mocks.useFinanceOverview.mockReturnValue({ data: { accounts, recentTransactions: [
      { id: 'income', transactionType: 'INCOME', occurredAt: '2026-09-24T10:00:00Z', description: 'Satış tahsilatı', entries: [{ amount: 250.56, currencyCode: 'TRY', accountName: 'Kasa' }] },
      { id: 'expense', transactionType: 'EXPENSE', occurredAt: '2026-09-24T11:00:00Z', description: 'Malzeme ödemesi', entries: [{ amount: -50.55, currencyCode: 'TRY', accountName: 'Kasa' }] },
    ] }, isPending: false, isError: false })
    setup(true)
    const income = screen.getByText('Satış tahsilatı').closest('article')!
    const expense = screen.getByText('Malzeme ödemesi').closest('article')!
    const format = (amount: number) => new Intl.NumberFormat('tr-TR', { style: 'currency', currency: 'TRY' }).format(amount)
    expect(within(income).getByText(format(250.56))).toBeVisible()
    expect(within(expense).getByText(format(-50.55))).toBeVisible()
    expect(within(income).getByText('Gelir')).toBeVisible()
    expect(within(expense).getByText('Gider')).toBeVisible()
  })
})
