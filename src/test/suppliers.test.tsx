import { act, cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { SupplierPage } from '../modules/suppliers/pages/SupplierPage'
import { SupplierFormDialog, SupplierPaymentDialog } from '../modules/suppliers/pages/SupplierDialogs'
import { parseSupplierAmount, supplierTotals, type Supplier } from '../modules/suppliers/model/suppliers'

const { rpc, tenant } = vi.hoisted(() => ({
  rpc: vi.fn(), tenant: { tenantId: '71111111-aaaa-4aaa-8aaa-111111111111', context: {
    tenantId: '71111111-aaaa-4aaa-8aaa-111111111111', userId: '71111111-6666-4666-8666-111111111111', locationId: null,
    permissions: ['suppliers.read'], modules: ['suppliers'],
  } },
}))
vi.mock('../shared/supabase/client', () => ({ supabase: { rpc } }))
vi.mock('../shared/tenant/useTenant', () => ({ useTenant: () => tenant }))
const supplierId = '71111111-aaaa-4aaa-8aaa-888888888881'
const accountId = '71111111-aaaa-4aaa-8aaa-555555555551'
const euroId = '71111111-aaaa-4aaa-8aaa-555555555553'
const suppliers: Supplier[] = [
  { id: supplierId, name: 'Gıda Tedarik', taxNumber: '1234567890', phone: '555', email: 'info@example.com', notes: 'Not', status: 'ACTIVE',
    balances: [{ currencyCode: 'TRY', amount: 1000 }, { currencyCode: 'EUR', amount: 200 }] },
  { id: '71111111-aaaa-4aaa-8aaa-888888888882', name: 'Avans Tedarik', taxNumber: null, phone: null, email: null, notes: null, status: 'ACTIVE', balances: [{ currencyCode: 'TRY', amount: -50 }] },
  { id: '71111111-aaaa-4aaa-8aaa-888888888883', name: 'Pasif Tedarik', taxNumber: null, phone: null, email: null, notes: null, status: 'PASSIVE', balances: [] },
]
const paymentAccounts = [
  { id: accountId, name: 'Nakit Kasa', accountType: 'CASH', currencyCode: 'TRY', derivedBalance: 300 },
  { id: euroId, name: 'Euro Banka', accountType: 'BANK', currencyCode: 'EUR', derivedBalance: -20 },
]
beforeEach(() => {
  rpc.mockReset()
  tenant.context.permissions = ['suppliers.read']
  tenant.context.modules = ['suppliers']
  rpc.mockImplementation(async (name: string) => {
    if (name === 'get_supplier_overview') return { data: { tenantId: tenant.tenantId, suppliers, recentPayments: [] }, error: null }
    if (name === 'get_supplier_payment_context') return { data: { tenantId: tenant.tenantId, accounts: paymentAccounts }, error: null }
    return { data: supplierId, error: null }
  })
})
afterEach(cleanup)
function setup(mode: 'page' | 'create' | 'edit' | 'pay' | 'passive-pay' = 'page') {
  const client = new QueryClient({ defaultOptions: { mutations: { retry: false }, queries: { retry: false } } })
  const invalidate = vi.spyOn(client, 'invalidateQueries')
  const onClose = vi.fn()
  render(<QueryClientProvider client={client}>{mode === 'page' ? <SupplierPage /> :
    mode === 'create' || mode === 'edit' ? <SupplierFormDialog supplier={mode === 'edit' ? suppliers[0] : undefined} onClose={onClose} /> :
    <SupplierPaymentDialog suppliers={suppliers} initialSupplierId={mode === 'passive-pay' ? suppliers[2].id : supplierId} onClose={onClose} />}
  </QueryClientProvider>)
  return { user: userEvent.setup(), onClose, invalidate }
}
const commandCalls = () => rpc.mock.calls.filter(([name]) => !String(name).startsWith('get_'))
async function fillPayment(user: ReturnType<typeof userEvent.setup>) {
  await waitFor(() => expect(screen.getByLabelText('Ödeme hesabı')).not.toBeDisabled())
  await user.selectOptions(screen.getByLabelText('Ödeme hesabı'), accountId)
  await user.type(screen.getByLabelText('Tutar'), '1.200,00')
  await user.type(screen.getByLabelText(/^Açıklama/), '  Fatura ödemesi  ')
}

describe('supplier access and overview', () => {
  it('read-only UI has no create, edit or pay action', async () => {
    setup()
    await screen.findByText('Gıda Tedarik')
    expect(screen.getByText('Pasif Tedarik')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Yeni Tedarikçi' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /düzenle|ödeme yap/i })).not.toBeInTheDocument()
  })
  it('writer UI can create/edit but has no payment authority', async () => {
    tenant.context.permissions.push('suppliers.write')
    const { user } = setup()
    await screen.findByText('Gıda Tedarik')
    expect(screen.getByRole('button', { name: 'Gıda Tedarik düzenle' })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /ödeme yap/i })).not.toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Yeni Tedarikçi' }))
    expect(screen.getByRole('dialog', { name: 'Yeni Tedarikçi' })).toBeInTheDocument()
  })
  it.each([
    [['suppliers.read', 'suppliers.pay'], ['suppliers', 'finance'], false],
    [['suppliers.read', 'finance.write'], ['suppliers', 'finance'], false],
    [['suppliers.read', 'suppliers.pay', 'finance.write'], ['suppliers'], false],
    [['suppliers.read', 'suppliers.pay', 'finance.write'], ['suppliers', 'finance'], true],
  ])('pay combinations %j / %j => %s', async (permissions, modules, allowed) => {
    tenant.context.permissions = permissions as string[]
    tenant.context.modules = modules as string[]
    setup()
    await screen.findByText('Gıda Tedarik')
    expect(!!screen.queryByRole('button', { name: 'Gıda Tedarik ödeme yap' })).toBe(allowed)
    expect(screen.queryByRole('button', { name: 'Pasif Tedarik ödeme yap' })).not.toBeInTheDocument()
  })
  it('keeps debt and advances separated per currency', () => {
    expect(supplierTotals(suppliers)).toEqual([
      { currencyCode: 'EUR', debt: 200, advance: 0 }, { currencyCode: 'TRY', debt: 1000, advance: 50 },
    ])
  })
})

describe('supplier form', () => {
  it('creates normalized supplier RPC args and invalidates overview', async () => {
    const { user, onClose, invalidate } = setup('create')
    await user.type(screen.getByLabelText(/^Ad \/ Ünvan/), '  Yeni   Tedarik  ')
    await user.type(screen.getByLabelText(/^VKN/), '12345678901')
    await user.type(screen.getByLabelText('Telefon'), ' 555 ')
    await user.type(screen.getByLabelText('E-posta'), ' SALES@EXAMPLE.COM ')
    await user.type(screen.getByLabelText('Not'), ' Not ')
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
    expect(commandCalls()).toEqual([['create_supplier', { p_tenant_id: tenant.tenantId, p_name: 'Yeni Tedarik',
      p_tax_number: '12345678901', p_phone: '555', p_email: 'sales@example.com', p_notes: 'Not' }]])
    expect(invalidate).toHaveBeenCalledWith({ queryKey: ['supplier-overview', tenant.tenantId] })
  })
  it('edits supplier with all RPC fields and status', async () => {
    const { user, onClose } = setup('edit')
    await user.clear(screen.getByLabelText(/^Ad \/ Ünvan/))
    await user.type(screen.getByLabelText(/^Ad \/ Ünvan/), 'Yeni Ünvan')
    await user.selectOptions(screen.getByLabelText(/^Durum/), 'PASSIVE')
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
    expect(commandCalls()).toEqual([['update_supplier', { p_tenant_id: tenant.tenantId, p_supplier_id: supplierId,
      p_name: 'Yeni Ünvan', p_tax_number: '1234567890', p_phone: '555', p_email: 'info@example.com', p_notes: 'Not', p_status: 'PASSIVE' }]])
  })
  it.each(['123', '123456789A'])('invalid tax number %s prevents RPC', async (tax) => {
    const { user } = setup('create')
    await user.type(screen.getByLabelText(/^Ad \/ Ünvan/), 'Valid Name')
    await user.type(screen.getByLabelText(/^VKN/), tax)
    fireEvent.submit(screen.getByRole('button', { name: 'Kaydet' }).closest('form')!)
    expect(commandCalls()).toHaveLength(0)
    expect(screen.getByLabelText(/^VKN/)).toHaveAttribute('aria-invalid', 'true')
  })
  it('preserves form and shows Turkish non-zero balance error', async () => {
    rpc.mockResolvedValueOnce({ data: null, error: { message: 'SUPPLIER_NON_ZERO_BALANCE' } })
    const { user, onClose } = setup('edit')
    await user.selectOptions(screen.getByLabelText(/^Durum/), 'PASSIVE')
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Borç veya avans bakiyesi olan tedarikçi pasife alınamaz')
    expect(screen.getByLabelText(/^Durum/)).toHaveValue('PASSIVE')
    expect(onClose).not.toHaveBeenCalled()
    await user.selectOptions(screen.getByLabelText(/^Durum/), 'ACTIVE')
    await user.type(screen.getByLabelText(/^Ad \/ Ünvan/), ' Yeni')
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
  })
  it('blocks duplicate supplier creates', async () => {
    let resolve!: (value: unknown) => void
    rpc.mockImplementationOnce(() => new Promise((done) => { resolve = done }))
    const { user, onClose } = setup('create')
    await user.type(screen.getByLabelText(/^Ad \/ Ünvan/), 'Yeni Tedarik')
    const form = screen.getByRole('button', { name: 'Kaydet' }).closest('form')!
    fireEvent.submit(form); fireEvent.submit(form)
    await waitFor(() => expect(commandCalls()).toHaveLength(1))
    expect(screen.getByRole('button', { name: 'Kapat' })).toBeDisabled()
    await act(async () => resolve({ data: supplierId, error: null }))
    await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
  })
})

describe('supplier payment', () => {
  it.each([['1.234,56', 1234.56], ['12,50', 12.5], ['12.50', 12.5]])('parses %s', (input, expected) => {
    expect(parseSupplierAmount(String(input))).toBe(expected)
  })
  it.each(['0', '-1', '0,001', '1.234', '1e3', '1.2.3,45', '', 'Infinity'])('rejects %s', (input) => {
    expect(parseSupplierAmount(input)).toBeNull()
  })
  it('uses payment context without finance.read, previews advance and sends positive RPC amount', async () => {
    const { user, onClose, invalidate } = setup('pay')
    await fillPayment(user)
    const preview = within(screen.getByLabelText('Ödeme sonrası bakiye'))
    expect(preview.getByText(/1\.000,00.*Borç/)).toBeInTheDocument()
    expect(preview.getByText(/200,00.*Avans \/ Alacak/)).toBeInTheDocument()
    expect(rpc).toHaveBeenCalledWith('get_supplier_payment_context', { p_tenant_id: tenant.tenantId })
    expect(rpc).not.toHaveBeenCalledWith('get_finance_overview', expect.anything())
    await user.click(screen.getByRole('button', { name: 'Ödemeyi Kaydet' }))
    await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
    expect(commandCalls()).toEqual([['create_supplier_payment', { p_tenant_id: tenant.tenantId,
      p_supplier_id: supplierId, p_finance_account_id: accountId, p_amount: 1200, p_description: 'Fatura ödemesi' }]])
    for (const key of ['supplier-overview', 'supplier-payment-context', 'finance-overview']) {
      expect(invalidate).toHaveBeenCalledWith({ queryKey: [key, tenant.tenantId] })
    }
  })
  it('changes preview to the selected currency and uses only context accounts', async () => {
    const { user } = setup('pay')
    await fillPayment(user)
    const select = screen.getByLabelText('Ödeme hesabı')
    expect(within(select).getAllByRole('option')).toHaveLength(3)
    await user.selectOptions(select, euroId)
    const preview = within(screen.getByLabelText('Ödeme sonrası bakiye'))
    expect(preview.getByText(/200,00.*Borç/)).toBeInTheDocument()
    expect(preview.getByText(/1\.000,00.*Avans/)).toBeInTheDocument()
    expect(screen.getByText('EUR', { selector: '.finance-money-input > span' })).toBeInTheDocument()
  })
  it.each(['0', '-10', '0.001', '1e2'])('invalid amount %s prevents payment', async (value) => {
    const { user } = setup('pay')
    await fillPayment(user)
    fireEvent.change(screen.getByLabelText('Tutar'), { target: { value } })
    fireEvent.submit(screen.getByRole('button', { name: 'Ödemeyi Kaydet' }).closest('form')!)
    expect(commandCalls()).toHaveLength(0)
  })
  it.each(['', ' ', 'x'])('short description %s prevents payment', async (value) => {
    const { user } = setup('pay')
    await fillPayment(user)
    fireEvent.change(screen.getByLabelText(/^Açıklama/), { target: { value } })
    fireEvent.submit(screen.getByRole('button', { name: 'Ödemeyi Kaydet' }).closest('form')!)
    expect(commandCalls()).toHaveLength(0)
  })
  it('does not allow passive supplier payment', async () => {
    const { user } = setup('passive-pay')
    await fillPayment(user)
    expect(screen.queryByRole('option', { name: 'Pasif Tedarik' })).not.toBeInTheDocument()
    fireEvent.submit(screen.getByRole('button', { name: 'Ödemeyi Kaydet' }).closest('form')!)
    expect(commandCalls()).toHaveLength(0)
  })
  it('preserves payment values on error and permits retry', async () => {
    const { user, onClose } = setup('pay')
    await fillPayment(user)
    rpc.mockResolvedValueOnce({ data: null, error: { message: 'FINANCE_ACCOUNT_NOT_AVAILABLE' } })
    await user.click(screen.getByRole('button', { name: 'Ödemeyi Kaydet' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Finans hesabı aktif değil')
    expect(screen.getByLabelText('Tutar')).toHaveValue('1.200,00')
    expect(screen.getByLabelText('Ödeme hesabı')).toHaveValue(accountId)
    expect(screen.getByLabelText('Tedarikçi')).toHaveValue(supplierId)
    expect(screen.getByLabelText(/^Açıklama/)).toHaveValue('  Fatura ödemesi  ')
    expect(onClose).not.toHaveBeenCalled()
    await user.click(screen.getByRole('button', { name: 'Ödemeyi Kaydet' }))
    await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
  })
  it('blocks duplicate payment submits', async () => {
    const { user, onClose } = setup('pay')
    await fillPayment(user)
    let resolve!: (value: unknown) => void
    rpc.mockImplementationOnce(() => new Promise((done) => { resolve = done }))
    const form = screen.getByRole('button', { name: 'Ödemeyi Kaydet' }).closest('form')!
    fireEvent.submit(form); fireEvent.submit(form)
    await waitFor(() => expect(commandCalls()).toHaveLength(1))
    expect(screen.getByRole('button', { name: 'Kaydediliyor...' })).toBeDisabled()
    expect(screen.getByRole('button', { name: 'Kapat' })).toBeDisabled()
    await act(async () => resolve({ data: supplierId, error: null }))
    await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
  })
})
