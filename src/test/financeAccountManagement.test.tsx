import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { FinanceAccountManagementDialog } from '../modules/finance/pages/FinanceAccountManagementDialog'
import { createFinanceAccountSchema } from '../modules/finance/model/financeAccountManagement'

const { rpc, from, select, eq, order } = vi.hoisted(() => ({
  rpc: vi.fn(), from: vi.fn(), select: vi.fn(), eq: vi.fn(), order: vi.fn(),
}))
const tenantId = '61111111-aaaa-4aaa-8aaa-111111111111'
const cashId = '61111111-aaaa-4aaa-8aaa-555555555551'
const passiveId = '61111111-aaaa-4aaa-8aaa-555555555552'
const locationId = '61111111-aaaa-4aaa-8aaa-999999999991'
vi.mock('../shared/supabase/client', () => ({ supabase: { rpc, from } }))
vi.mock('../shared/tenant/useTenant', () => ({ useTenant: () => ({ tenantId: '61111111-aaaa-4aaa-8aaa-111111111111' }) }))
const accounts = [
  { id: cashId, name: 'Merkez Kasa', accountType: 'CASH', currencyCode: 'TRY', status: 'ACTIVE', locationId, locationName: 'Merkez', balance: 50 },
  { id: passiveId, name: 'Eski Banka', accountType: 'BANK', currencyCode: 'USD', status: 'PASSIVE', locationId: null, locationName: null, balance: 0 },
]

beforeEach(() => {
  vi.resetAllMocks()
  from.mockReturnValue({ select })
  select.mockReturnValue({ eq })
  eq.mockReturnValue({ eq, order })
  order.mockResolvedValue({ data: [{ id: locationId, name: 'Merkez' }], error: null })
  rpc.mockImplementation(async (name: string) => name === 'get_finance_account_management'
    ? { data: { tenantId, accounts }, error: null } : { data: cashId, error: null })
})
afterEach(cleanup)

function setup() {
  const client = new QueryClient({ defaultOptions: { mutations: { retry: false }, queries: { retry: false } } })
  const invalidate = vi.spyOn(client, 'invalidateQueries')
  const onClose = vi.fn()
  render(<QueryClientProvider client={client}><FinanceAccountManagementDialog onClose={onClose} /></QueryClientProvider>)
  return { user: userEvent.setup(), invalidate, onClose }
}
async function createForm(user: ReturnType<typeof userEvent.setup>) {
  await user.click(screen.getByRole('button', { name: 'Yeni Hesap Ekle' }))
  await user.type(screen.getByLabelText(/^Hesap adı/), '  Yeni Hesap  ')
  await waitFor(() => expect(screen.getByLabelText('Lokasyon')).not.toBeDisabled())
}
function submit() { fireEvent.submit(screen.getByRole('button', { name: 'Kaydet' }).closest('form')!) }
function commandCalls() { return rpc.mock.calls.filter(([name]) => name !== 'get_finance_account_management') }

describe('finance account management', () => {
  it('shows active and passive accounts, balances and locations without delete', async () => {
    setup()
    expect(await screen.findByText('Merkez Kasa')).toBeInTheDocument()
    expect(screen.getByText('Eski Banka')).toBeInTheDocument()
    expect(screen.getByText('Pasif')).toBeInTheDocument()
    expect(screen.getByText('İşletme geneli')).toBeInTheDocument()
    expect(screen.getByText(/50,00/)).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /sil|delete/i })).not.toBeInTheDocument()
  })

  it.each([null, locationId])('creates via RPC with location %s and invalidates both models', async (location) => {
    const { user, invalidate } = setup()
    await createForm(user)
    await user.selectOptions(screen.getByLabelText('Hesap tipi'), 'BANK')
    await user.clear(screen.getByLabelText(/^Para birimi/))
    await user.type(screen.getByLabelText(/^Para birimi/), ' usd ')
    if (location) await user.selectOptions(screen.getByLabelText('Lokasyon'), location)
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    await screen.findByText('Hesap kaydedildi.')
    expect(commandCalls()).toEqual([['create_finance_account', {
      p_tenant_id: tenantId, p_name: 'Yeni Hesap', p_account_type: 'BANK', p_currency_code: 'USD', p_location_id: location ?? undefined,
    }]])
    expect(invalidate).toHaveBeenCalledWith({ queryKey: ['finance-overview', tenantId] })
    expect(invalidate).toHaveBeenCalledWith({ queryKey: ['finance-account-management', tenantId] })
    expect(from).toHaveBeenCalledWith('locations')
    expect(eq).toHaveBeenCalledWith('tenant_id', tenantId)
    expect(eq).toHaveBeenCalledWith('status', 'ACTIVE')
  })

  it('allows returning from a selected location to tenant-wide', async () => {
    const { user } = setup()
    await createForm(user)
    await user.selectOptions(screen.getByLabelText('Lokasyon'), locationId)
    await user.selectOptions(screen.getByLabelText('Lokasyon'), '')
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    await screen.findByText('Hesap kaydedildi.')
    expect(commandCalls()[0][1].p_location_id).toBeUndefined()
  })

  it.each(['', ' ', 'x'])('rejects invalid name %s without RPC', async (name) => {
    const { user } = setup()
    await createForm(user)
    fireEvent.change(screen.getByLabelText(/^Hesap adı/), { target: { value: name } })
    expect(screen.getByRole('button', { name: 'Kaydet' })).toBeDisabled()
    submit()
    expect(commandCalls()).toHaveLength(0)
  })
  it.each(['', 'TR', 'TRYY', 'T1Y'])('rejects invalid currency %s without RPC', async (currency) => {
    const { user } = setup()
    await createForm(user)
    fireEvent.change(screen.getByLabelText(/^Para birimi/), { target: { value: currency } })
    submit()
    expect(commandCalls()).toHaveLength(0)
  })
  it('rejects overlong names at the command boundary', () => {
    expect(createFinanceAccountSchema.safeParse({ name: 'x'.repeat(121), accountType: 'CASH', currencyCode: 'TRY', locationId: null }).success).toBe(false)
  })

  it('renames with immutable fields displayed read-only and no-change submit disabled', async () => {
    const { user } = setup()
    await user.click(await screen.findByRole('button', { name: 'Merkez Kasa hesabını düzenle' }))
    expect(screen.getByRole('button', { name: 'Kaydet' })).toBeDisabled()
    expect(screen.queryByRole('combobox', { name: 'Hesap tipi' })).not.toBeInTheDocument()
    expect(screen.queryByRole('textbox', { name: /Para birimi/ })).not.toBeInTheDocument()
    expect(screen.queryByRole('combobox', { name: 'Lokasyon' })).not.toBeInTheDocument()
    await user.clear(screen.getByLabelText(/^Hesap adı/))
    await user.type(screen.getByLabelText(/^Hesap adı/), ' Yeni isim ')
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    await screen.findByText('Hesap kaydedildi.')
    expect(commandCalls()).toEqual([['update_finance_account', { p_tenant_id: tenantId, p_account_id: cashId, p_name: 'Yeni isim', p_status: 'ACTIVE' }]])
  })

  it.each([
    ['Merkez Kasa', cashId, 'PASSIVE'], ['Eski Banka', passiveId, 'ACTIVE'],
  ])('updates %s status to %s', async (name, id, status) => {
    const { user } = setup()
    await user.click(await screen.findByRole('button', { name: `${name} hesabını düzenle` }))
    await user.selectOptions(screen.getByLabelText(/^Durum/), status)
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    await screen.findByText('Hesap kaydedildi.')
    expect(commandCalls()).toEqual([['update_finance_account', { p_tenant_id: tenantId, p_account_id: id, p_name: name, p_status: status }]])
  })

  it('preserves a rejected non-zero passive change and permits correction/retry', async () => {
    const { user } = setup()
    await user.click(await screen.findByRole('button', { name: 'Merkez Kasa hesabını düzenle' }))
    await user.selectOptions(screen.getByLabelText(/^Durum/), 'PASSIVE')
    rpc.mockResolvedValueOnce({ data: null, error: { message: 'FINANCE_ACCOUNT_NON_ZERO_BALANCE' } })
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Bakiyesi sıfır olmayan hesap pasife alınamaz')
    expect(screen.getByLabelText(/^Durum/)).toHaveValue('PASSIVE')
    expect(screen.getByLabelText(/^Hesap adı/)).toHaveValue('Merkez Kasa')
    await user.selectOptions(screen.getByLabelText(/^Durum/), 'ACTIVE')
    await user.type(screen.getByLabelText(/^Hesap adı/), ' Yeni')
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    await screen.findByText('Hesap kaydedildi.')
    expect(commandCalls()).toHaveLength(2)
  })

  it('preserves create form on RPC error and retries', async () => {
    const { user } = setup()
    await createForm(user)
    await user.selectOptions(screen.getByLabelText('Lokasyon'), locationId)
    rpc.mockResolvedValueOnce({ data: null, error: { message: 'Bağlantı hatası' } })
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Bağlantı hatası')
    expect(screen.getByLabelText(/^Hesap adı/)).toHaveValue('  Yeni Hesap  ')
    expect(screen.getByLabelText('Lokasyon')).toHaveValue(locationId)
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    await screen.findByText('Hesap kaydedildi.')
    expect(commandCalls()).toHaveLength(2)
  })

  it('blocks duplicate submit and closing during save', async () => {
    const { user, onClose } = setup()
    await createForm(user)
    let resolve!: (value: unknown) => void
    rpc.mockImplementationOnce(() => new Promise((done) => { resolve = done }))
    const form = screen.getByRole('button', { name: 'Kaydet' }).closest('form')!
    fireEvent.submit(form)
    fireEvent.submit(form)
    await waitFor(() => expect(commandCalls()).toHaveLength(1))
    expect(screen.getByRole('button', { name: 'Kapat' })).toBeDisabled()
    expect(screen.getByRole('button', { name: 'Geri' })).toBeDisabled()
    expect(onClose).not.toHaveBeenCalled()
    await act(async () => resolve({ data: cashId, error: null }))
    await screen.findByText('Hesap kaydedildi.')
  })
})
