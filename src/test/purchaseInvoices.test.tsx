import { act, cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { PurchaseInvoicePage } from '../modules/purchasing/pages/PurchaseInvoicePage'
import { PurchaseInvoiceForm, PurchaseInvoicePostDialog } from '../modules/purchasing/pages/PurchaseInvoiceDialogs'
import { invoiceLineMath, parseInvoiceNumber, type InvoiceDetail, type CalculatedLineInput } from '../modules/purchasing/model/purchaseInvoices'

const { rpc, tenant } = vi.hoisted(() => ({ rpc: vi.fn(), tenant: {
  tenantId: '81111111-aaaa-4aaa-8aaa-111111111111', context: { modules: ['purchasing', 'suppliers'], permissions: ['purchasing.read'] },
} }))
vi.mock('../shared/supabase/client', () => ({ supabase: { rpc } }))
vi.mock('../shared/tenant/useTenant', () => ({ useTenant: () => tenant }))
const supplierId = '81111111-aaaa-4aaa-8aaa-888888888881'
const invoiceId = '81111111-aaaa-4aaa-8aaa-777777777771'
const postedId = '81111111-aaaa-4aaa-8aaa-777777777772'
const locationId = '81111111-aaaa-4aaa-8aaa-999999999991'
const detail: InvoiceDetail = { tenantId: tenant.tenantId, invoice: {
  id: invoiceId, supplierId, supplierName: 'Tedarikçi A', locationId: null, locationName: null, invoiceNumber: 'INV-1', invoiceDate: '2026-09-25',
  dueDate: null, currencyCode: 'TRY', status: 'DRAFT', subtotal: 101, taxTotal: 0, grandTotal: 101, description: 'Fatura notu', lineCount: 1, postedAt: null,
}, lines: [{ id: '81111111-aaaa-4aaa-8aaa-666666666661', lineNo: 1, description: 'Un alımı', supplierProductCode: 'SKU-1', unit: 'kg',
  quantity: 1, unitPrice: 101, priceIncludesTax: false, taxRate: 0, netAmount: 101, taxAmount: 0, grossAmount: 101, inventoryItemId: null }] }
const postedDetail: InvoiceDetail = { ...detail, invoice: { ...detail.invoice, id: postedId, invoiceNumber: 'INV-2', status: 'POSTED', postedAt: '2026-09-25T12:00:00Z' } }
beforeEach(() => {
  rpc.mockReset()
  tenant.context.permissions = ['purchasing.read']
  tenant.context.modules = ['purchasing', 'suppliers']
  rpc.mockImplementation(async (name: string, args: { p_invoice_id?: string }) => {
    if (name === 'get_purchase_invoice_context') return { data: { tenantId: tenant.tenantId, suppliers: [{ id: supplierId, name: 'Tedarikçi A' }], locations: [{ id: locationId, name: 'Merkez' }] }, error: null }
    if (name === 'get_purchase_invoice_overview') return { data: { tenantId: tenant.tenantId, summary: { draftCount: 1, postedCount: 1, postedTotals: [{ currencyCode: 'TRY', amount: 101 }] }, invoices: [detail.invoice, postedDetail.invoice] }, error: null }
    if (name === 'get_purchase_invoice_detail') return { data: args.p_invoice_id === postedId ? postedDetail : detail, error: null }
    return { data: invoiceId, error: null }
  })
})
afterEach(cleanup)
function setup(mode: 'page' | 'create' | 'edit' | 'posted' | 'post' = 'page') {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } })
  const invalidate = vi.spyOn(client, 'invalidateQueries')
  const onClose = vi.fn()
  render(<QueryClientProvider client={client}>{mode === 'page' ? <PurchaseInvoicePage /> : mode === 'post' ? <PurchaseInvoicePostDialog invoice={detail.invoice} onClose={onClose} /> :
    <PurchaseInvoiceForm detail={mode === 'edit' ? detail : mode === 'posted' ? postedDetail : undefined} onClose={onClose} />}</QueryClientProvider>)
  return { user: userEvent.setup(), onClose, invalidate }
}
const commands = () => rpc.mock.calls.filter(([name]) => !String(name).startsWith('get_'))
async function fill(user: ReturnType<typeof userEvent.setup>) {
  await screen.findByRole('option', { name: 'Tedarikçi A' })
  await user.selectOptions(screen.getByLabelText('Tedarikçi'), supplierId)
  await user.type(screen.getByLabelText('Fatura No'), ' NEW-1 ')
  fireEvent.change(screen.getByLabelText('Fatura Tarihi'), { target: { value: '2026-09-25' } })
  await user.type(screen.getByLabelText('Malzeme / Ürün Açıklaması 1'), 'Un alımı')
  fireEvent.change(screen.getByLabelText('Miktar 1'), { target: { value: '1,2345' } })
  await user.type(screen.getByLabelText('Birim Fiyat 1'), '10,00')
}

describe('purchase line calculations', () => {
  const line: CalculatedLineInput = { description: 'Test line', supplierProductCode: '', unit: 'kg', quantity: 2, unitPrice: 10,
    priceIncludesTax: false, taxRate: 20, inventoryItemId: null }
  it('calculates tax-exclusive money', () => { expect(invoiceLineMath(line)).toEqual({ netAmount: 20, taxAmount: 4, grossAmount: 24 }) })
  it('calculates tax-inclusive money', () => { expect(invoiceLineMath({ ...line, unitPrice: 12, priceIncludesTax: true })).toEqual({ netAmount: 20, taxAmount: 4, grossAmount: 24 }) })
  it('rounds four-decimal quantity to cents at line level', () => { expect(invoiceLineMath({ ...line, quantity: 1.2345, taxRate: 0 })).toEqual({ netAmount: 12.35, taxAmount: 0, grossAmount: 12.35 }) })
  it('keeps net + tax = gross with half-cent rounding', () => { expect(invoiceLineMath({ ...line, quantity: 1, unitPrice: 0.045, taxRate: 10 })).toEqual({ netAmount: 0.05, taxAmount: 0.01, grossAmount: 0.06 }) })
  it.each([['1.234,56', 1234.56], ['12,50', 12.5], ['12.50', 12.5], ['1,2345', 1.2345]])('parses %s', (input, expected) => { expect(parseInvoiceNumber(String(input))).toBe(expected) })
  it.each(['0', '-1', '1e3', '1.2.3,45', '1,23456', 'Infinity', ''])('rejects quantity %s', (input) => { expect(parseInvoiceNumber(input)).toBeNull() })
  it('allows zero price but not zero quantity', () => { expect(parseInvoiceNumber('0', 4, true)).toBe(0); expect(parseInvoiceNumber('0')).toBeNull() })
})

describe('invoice drafts', () => {
  it('creates correct RPC args without browser totals and uses purchasing supplier context', async () => {
    const { user, onClose, invalidate } = setup('create')
    await fill(user)
    await user.selectOptions(screen.getByLabelText('Lokasyon'), locationId)
    await user.click(screen.getByRole('button', { name: 'Taslağı Kaydet' }))
    await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
    expect(commands()).toEqual([['create_purchase_invoice_draft', {
      p_tenant_id: tenant.tenantId, p_supplier_id: supplierId, p_invoice_number: 'NEW-1', p_invoice_date: '2026-09-25',
      p_currency_code: 'TRY', p_location_id: locationId, p_due_date: undefined, p_description: undefined,
      p_lines: [{ description: 'Un alımı', supplierProductCode: '', unit: 'adet', quantity: 1.2345, unitPrice: 10, priceIncludesTax: false, taxRate: 20, inventoryItemId: null }],
    }]])
    expect(rpc).toHaveBeenCalledWith('get_purchase_invoice_context', { p_tenant_id: tenant.tenantId })
    expect(rpc).not.toHaveBeenCalledWith('get_supplier_overview', expect.anything())
    expect(invalidate).toHaveBeenCalledWith({ queryKey: ['purchase-invoice-overview', tenant.tenantId] })
    expect(invalidate).not.toHaveBeenCalledWith({ queryKey: ['finance-overview', tenant.tenantId] })
  })
  it('updates the draft with replaced lines', async () => {
    const { user, onClose } = setup('edit')
    await user.clear(screen.getByLabelText('Fatura No'))
    await user.type(screen.getByLabelText('Fatura No'), 'INV-NEW')
    await user.click(screen.getByRole('button', { name: 'Taslağı Kaydet' }))
    await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
    expect(commands()[0]).toEqual(['update_purchase_invoice_draft', expect.objectContaining({ p_invoice_id: invoiceId, p_invoice_number: 'INV-NEW',
      p_lines: [expect.objectContaining({ quantity: 1, unitPrice: 101, supplierProductCode: 'SKU-1' })] })])
  })
  it('adds/removes lines and retains at least one', async () => {
    const { user } = setup('create')
    expect(screen.getByRole('button', { name: 'Satır 1 kaldır' })).toBeDisabled()
    await user.click(screen.getByRole('button', { name: 'Satır Ekle' }))
    expect(screen.getByLabelText('Miktar 2')).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Satır 2 kaldır' }))
    expect(screen.queryByLabelText('Miktar 2')).not.toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Satır 1 kaldır' })).toBeDisabled()
  })
  it.each([['Miktar 1', '0'], ['Miktar 1', '1,23456'], ['Birim Fiyat 1', '-1'], ['KDV % 1', '101'], ['Malzeme / Ürün Açıklaması 1', 'x'], ['Para Birimi', 'TR']])('invalid %s=%s blocks save', async (field, value) => {
    const { user } = setup('create'); await fill(user)
    fireEvent.change(screen.getByLabelText(field), { target: { value } })
    expect(screen.getByRole('button', { name: 'Taslağı Kaydet' })).toBeDisabled()
    fireEvent.submit(screen.getByRole('button', { name: 'Taslağı Kaydet' }).closest('form')!)
    expect(commands()).toHaveLength(0)
  })
  it('rejects due date before invoice date', async () => {
    const { user } = setup('create'); await fill(user)
    fireEvent.change(screen.getByLabelText('Vade Tarihi'), { target: { value: '2026-09-24' } })
    expect(screen.getByRole('button', { name: 'Taslağı Kaydet' })).toBeDisabled()
  })
  it('retains form on RPC error and retries', async () => {
    const { user, onClose } = setup('create'); await fill(user)
    rpc.mockResolvedValueOnce({ data: null, error: { message: 'PURCHASE_INVOICE_NUMBER_EXISTS' } })
    await user.click(screen.getByRole('button', { name: 'Taslağı Kaydet' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('aynı fatura numarası zaten var')
    expect(screen.getByLabelText('Fatura No')).toHaveValue(' NEW-1 ')
    expect(screen.getByLabelText('Miktar 1')).toHaveValue('1,2345')
    expect(onClose).not.toHaveBeenCalled()
    await user.click(screen.getByRole('button', { name: 'Taslağı Kaydet' }))
    await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
  })
  it('blocks duplicate submits and close while saving', async () => {
    const { user, onClose } = setup('create'); await fill(user)
    let resolve!: (value: unknown) => void
    rpc.mockImplementationOnce(() => new Promise((done) => { resolve = done }))
    const form = screen.getByRole('button', { name: 'Taslağı Kaydet' }).closest('form')!
    fireEvent.submit(form); fireEvent.submit(form)
    await waitFor(() => expect(commands()).toHaveLength(1))
    expect(screen.getByRole('button', { name: 'Kapat' })).toBeDisabled()
    await act(async () => resolve({ data: invoiceId, error: null }))
    await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
  })
})

describe('invoice access and posting', () => {
  it('read-only page exposes view only, fetching lines only for selected detail', async () => {
    const { user } = setup()
    await screen.findByRole('button', { name: 'INV-1 görüntüle' })
    expect(screen.queryByRole('button', { name: /düzenle|faturayı işle|Yeni Fatura/ })).not.toBeInTheDocument()
    expect(rpc).not.toHaveBeenCalledWith('get_purchase_invoice_detail', expect.anything())
    await user.click(screen.getByRole('button', { name: 'INV-1 görüntüle' }))
    expect(await screen.findByLabelText('Fatura No')).toBeDisabled()
    expect(screen.queryByRole('button', { name: 'Taslağı Kaydet' })).not.toBeInTheDocument()
    expect(rpc).not.toHaveBeenCalledWith('get_purchase_invoice_context', expect.anything())
  })
  it('writer has draft controls while posted invoice is view-only', async () => {
    tenant.context.permissions.push('purchasing.write'); setup()
    expect(await screen.findByRole('button', { name: 'Yeni Fatura' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'INV-1 düzenle' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'INV-1 faturayı işle' })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'INV-2 düzenle' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'INV-2 faturayı işle' })).not.toBeInTheDocument()
  })
  it('POSTED form is readonly even if requested for editing', () => {
    setup('posted')
    expect(screen.getByLabelText('Fatura No')).toBeDisabled()
    expect(screen.getByLabelText('Birim Fiyat 1')).toBeDisabled()
    expect(screen.getByLabelText('KDV Dahil 1')).toBeDisabled()
    expect(screen.queryByRole('button', { name: 'Taslağı Kaydet' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Satır Ekle' })).not.toBeInTheDocument()
    expect(rpc).not.toHaveBeenCalled()
  })
  it('requires confirmation before post and invalidates supplier, not finance', async () => {
    tenant.context.permissions.push('purchasing.write')
    const { user, invalidate } = setup()
    await user.click(await screen.findByRole('button', { name: 'INV-1 faturayı işle' }))
    const dialog = within(screen.getByRole('dialog', { name: 'Faturayı İşle' }))
    expect(dialog.getByText(/tedarikçi borcunu artıracaktır/)).toBeInTheDocument()
    expect(commands()).toHaveLength(0)
    await user.click(dialog.getByRole('button', { name: 'Onayla ve İşle' }))
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
    expect(commands()).toEqual([['post_purchase_invoice', { p_tenant_id: tenant.tenantId, p_invoice_id: invoiceId }]])
    for (const key of ['purchase-invoice-overview', 'purchase-invoice-detail', 'supplier-overview']) expect(invalidate).toHaveBeenCalledWith({ queryKey: [key, tenant.tenantId] })
    expect(invalidate).not.toHaveBeenCalledWith({ queryKey: ['finance-overview', tenant.tenantId] })
  })
  it('cancelling confirmation makes no post call', async () => {
    const { user, onClose } = setup('post')
    await user.click(screen.getByRole('button', { name: 'Vazgeç' }))
    expect(onClose).toHaveBeenCalledOnce(); expect(commands()).toHaveLength(0)
  })
  it('blocks duplicate post requests', async () => {
    const { onClose } = setup('post')
    let resolve!: (value: unknown) => void
    rpc.mockImplementationOnce(() => new Promise((done) => { resolve = done }))
    const form = screen.getByRole('button', { name: 'Onayla ve İşle' }).closest('form')!
    fireEvent.submit(form); fireEvent.submit(form)
    await waitFor(() => expect(commands()).toHaveLength(1))
    await act(async () => resolve({ data: invoiceId, error: null }))
    await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
  })
  it('keeps confirmation after backend post failure for retry', async () => {
    const { user, onClose } = setup('post')
    rpc.mockResolvedValueOnce({ data: null, error: { message: 'SUPPLIER_NOT_AVAILABLE' } })
    await user.click(screen.getByRole('button', { name: 'Onayla ve İşle' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Tedarikçi aktif değil')
    expect(onClose).not.toHaveBeenCalled()
    await user.click(screen.getByRole('button', { name: 'Onayla ve İşle' }))
    await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
  })
})
