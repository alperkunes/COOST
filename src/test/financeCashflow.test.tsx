import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { FinanceCashflowDialog } from '../modules/finance/pages/FinanceCashflowDialog'
import { parseCashflowAmount } from '../modules/finance/model/financeCashflow'
import type { FinanceOverviewAccount } from '../modules/finance/model/financeOverview'

const { rpc } = vi.hoisted(() => ({ rpc: vi.fn() }))
vi.mock('../shared/supabase/client', () => ({ supabase: { rpc } }))
vi.mock('../shared/tenant/useTenant', () => ({ useTenant: () => ({ tenantId: 'tenant-1' }) }))

const accounts: FinanceOverviewAccount[] = [
  { id: 'cash', name: 'Kasa', accountType: 'CASH', currencyCode: 'TRY', status: 'ACTIVE', balance: 2000 },
  { id: 'bank', name: 'Banka', accountType: 'BANK', currencyCode: 'TRY', status: 'ACTIVE', balance: 100 },
  { id: 'usd', name: 'Döviz', accountType: 'BANK', currencyCode: 'USD', status: 'ACTIVE', balance: 100 },
]

function setup() {
  const client = new QueryClient({ defaultOptions: { mutations: { retry: false }, queries: { retry: false } } })
  const invalidate = vi.spyOn(client, 'invalidateQueries')
  const onClose = vi.fn()
  render(<QueryClientProvider client={client}><FinanceCashflowDialog accounts={accounts} onClose={onClose} /></QueryClientProvider>)
  return { user: userEvent.setup(), onClose, invalidate }
}

async function fill(user: ReturnType<typeof userEvent.setup>) {
  await user.selectOptions(screen.getByLabelText('Hesap'), 'cash')
  await user.type(screen.getByLabelText('Tutar'), '1.234,56')
  await user.type(screen.getByLabelText(/^Açıklama/), '  Satış tahsilatı  ')
}

afterEach(cleanup)
beforeEach(() => { rpc.mockReset() })

describe('finance cashflow', () => {
  it.each(['', '0', '-1', '0,001', '1.234', '1e3', 'Infinity', '1,2,3', '1.2.3,45', '100000000000000'])('rejects invalid amount %s', (value) => {
    expect(parseCashflowAmount(value)).toBeNull()
  })

  it.each([['1.234,56', 1234.56], ['12,50', 12.5], ['12.50', 12.5], ['0,01', 0.01]])('parses %s', (value, expected) => {
    expect(parseCashflowAmount(String(value))).toBe(expected)
  })

  it.each(['INCOME', 'EXPENSE'])('calls %s RPC with positive amount, refreshes overview and closes', async (transactionType) => {
    rpc.mockResolvedValue({ data: 'transaction-id', error: null })
    const { user, onClose, invalidate } = setup()
    await fill(user)
    await user.selectOptions(screen.getByLabelText('İşlem türü'), transactionType)
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
    expect(rpc).toHaveBeenCalledExactlyOnceWith('create_finance_cashflow', {
      p_tenant_id: 'tenant-1', p_account_id: 'cash', p_transaction_type: transactionType,
      p_amount: 1234.56, p_description: 'Satış tahsilatı',
    })
    expect(invalidate).toHaveBeenCalledWith({ queryKey: ['finance-overview', 'tenant-1'] })
  })

  it.each(['', ' ', 'x'])('prevents invalid amount or short description %s submissions', async (description) => {
    const { user } = setup()
    await fill(user)
    await user.clear(screen.getByLabelText('Tutar'))
    await user.type(screen.getByLabelText('Tutar'), '0,001')
    fireEvent.submit(screen.getByRole('button', { name: 'Kaydet' }).closest('form')!)
    await user.clear(screen.getByLabelText('Tutar'))
    await user.type(screen.getByLabelText('Tutar'), '10')
    await user.clear(screen.getByLabelText(/^Açıklama/))
    fireEvent.change(screen.getByLabelText(/^Açıklama/), { target: { value: description } })
    fireEvent.submit(screen.getByRole('button', { name: 'Kaydet' }).closest('form')!)
    expect(rpc).not.toHaveBeenCalled()
  })

  it('preserves input on RPC error and permits retry', async () => {
    rpc.mockResolvedValueOnce({ data: null, error: { message: 'İşlem reddedildi' } })
    rpc.mockResolvedValueOnce({ data: 'transaction-id', error: null })
    const { user, onClose } = setup()
    await fill(user)
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('İşlem reddedildi')
    expect(screen.getByLabelText('Tutar')).toHaveValue('1.234,56')
    expect(screen.getByLabelText('Hesap')).toHaveValue('cash')
    expect(screen.getByLabelText('İşlem türü')).toHaveValue('INCOME')
    expect(screen.getByLabelText(/^Açıklama/)).toHaveValue('  Satış tahsilatı  ')
    expect(onClose).not.toHaveBeenCalled()
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
  })

  it('blocks duplicate submissions and closing while saving', async () => {
    let resolve!: (value: unknown) => void
    rpc.mockImplementation(() => new Promise((done) => { resolve = done }))
    const { user, onClose } = setup()
    await fill(user)
    const form = screen.getByRole('button', { name: 'Kaydet' }).closest('form')!
    fireEvent.submit(form)
    fireEvent.submit(form)
    await waitFor(() => expect(rpc).toHaveBeenCalledOnce())
    expect(screen.getByRole('button', { name: 'Kaydediliyor...' })).toBeDisabled()
    expect(screen.getByRole('button', { name: 'Kapat' })).toBeDisabled()
    expect(onClose).not.toHaveBeenCalled()
    await act(async () => resolve({ data: 'transaction-id', error: null }))
    await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
  })

  it('takes currency from the selected account and requires an account', async () => {
    const { user } = setup()
    expect(screen.getByRole('button', { name: 'Kaydet' })).toBeDisabled()
    await user.selectOptions(screen.getByLabelText('Hesap'), 'usd')
    expect(screen.getByText('USD', { selector: '.finance-money-input > span' })).toBeInTheDocument()
    await user.selectOptions(screen.getByLabelText('Hesap'), 'cash')
    expect(screen.getByText('TRY', { selector: '.finance-money-input > span' })).toBeInTheDocument()
  })
})
