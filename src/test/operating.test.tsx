import { act, cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { OperatingProfitability } from '../modules/costing/pages/OperatingProfitability'
import { ExpenseDialog, SalesDialog, VoidExpenseDialog } from '../modules/costing/pages/OperatingDialogs'
import { expenseInputSchema, periodSchema, salesInputSchema, type Expense, type OperatingData, type OperatingProduct, type Period } from '../modules/costing/model/operating'

const { rpc, tenant } = vi.hoisted(() => ({ rpc: vi.fn(), tenant: { tenantId: 'd1111111-aaaa-4aaa-8aaa-111111111111' } }))
vi.mock('../shared/supabase/client', () => ({ supabase: { rpc } }))
vi.mock('../shared/tenant/useTenant', () => ({ useTenant: () => tenant }))
const loc = 'd1111111-7777-4777-8777-111111111111', productId = 'd1111111-3333-4333-8333-111111111111', entryId = 'd1111111-4444-4444-8444-111111111111'
const period: Period = { startDate: '2026-01-01', endDate: '2026-01-31', currencyCode: 'TRY', locationId: '', allocationMethod: 'NET_SALES' }
const expense: Expense = { id: entryId, occurredOn: '2026-01-01', locationId: null, currencyCode: 'TRY', category: 'LABOR', amount: 60, description: 'Staff cost', status: 'ACTIVE', sourceType: 'MANUAL' }
const data: OperatingData = { ...period, tenantId: tenant.tenantId, locationId: null, locations: [{ id: loc, name: 'Kitchen' }], products: [{ id: productId, name: 'Alpha', currencyCode: 'TRY' }], sales: [{ id: entryId, saleDate: '2026-01-01', locationId: loc, productId, productName: 'Alpha', currencyCode: 'TRY', quantity: 2, grossSales: 120, netSales: 100, sourceType: 'MANUAL' }], expenses: [expense, { ...expense, id: productId, description: 'Cancelled cost', status: 'VOID' }] }
const product: OperatingProduct = { productId, productName: 'Alpha', category: null, quantitySold: 2, grossSales: 120, netSales: 100, recipeCostMethod: 'LAST_PURCHASE', recipeCostPerPortion: 10, costingComplete: true, estimatedRecipeCost: 20, directContribution: 80, directContributionPct: 80, allocationWeight: 1, allocatedFixedOverhead: 0, allocatedLabor: 60, allocatedPosCommission: 0, allocatedOtherVariable: 0, allocatedOperatingCost: 60, allocatedOperatingContribution: 20, allocatedOperatingMarginPct: 20, allocatedOperatingCostPerUnit: 30, targetOperatingMarginPct: 25, targetDifferencePp: -5, suggestedNetPriceAtTarget: 160 / 3, suggestedGrossPriceAtTarget: 64 }
let products: OperatingProduct[], status: 'READY' | 'NO_SALES' | 'ZERO_ALLOCATION_BASE'
beforeEach(() => {
  products = [product]; status = 'READY'; rpc.mockReset()
  rpc.mockImplementation(async (name: string, args: Record<string, string>) => {
    const scope = { tenantId: tenant.tenantId, startDate: args.p_start_date, endDate: args.p_end_date, currencyCode: args.p_currency_code, locationId: args.p_location_id ?? null }
    if (name === 'get_operating_data') return { data: { ...data, ...scope }, error: null }
    if (name === 'get_operating_profitability') return { data: { ...scope, allocationMethod: args.p_allocation_method, allocationStatus: status, products, summary: { totalQuantity: 2, grossSales: 120, netSales: 100, estimatedRecipeCost: products.some((p) => !p.costingComplete) ? null : 20, directContribution: 80, operatingCosts: { fixedOverhead: 0, labor: 60, posCommission: 0, otherVariable: 0, total: 60 }, allocatedOperatingContribution: 20, allocatedOperatingMarginPct: 20 } }, error: null }
    return { data: entryId, error: null }
  })
})
afterEach(cleanup)
const change = (label: string, value: string) => fireEvent.change(screen.getByLabelText(label), { target: { value } })
const commands = () => rpc.mock.calls.filter(([name]) => !String(name).startsWith('get_'))
function setup(mode: 'page' | 'sales' | 'edit-sales' | 'expense' | 'edit-expense' | 'void' = 'page', canWrite = true) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } }), close = vi.fn()
  const invalidate = vi.spyOn(client, 'invalidateQueries')
  render(<QueryClientProvider client={client}>{mode === 'page' ? <OperatingProfitability canWrite={canWrite} /> : mode === 'sales' || mode === 'edit-sales' ? <SalesDialog fact={mode === 'edit-sales' ? data.sales[0] : undefined} data={data} period={period} onClose={close} /> : mode === 'void' ? <VoidExpenseDialog expense={expense} onClose={close} /> : <ExpenseDialog expense={mode === 'edit-expense' ? expense : undefined} data={data} period={period} onClose={close} />}</QueryClientProvider>)
  return { user: userEvent.setup(), close, invalidate }
}
describe('operating validation', () => {
  it('bounds the inclusive period and currency', () => {
    expect(periodSchema.safeParse(period).success).toBe(true)
    for (const patch of [{ endDate: '2025-01-01' }, { endDate: '2027-01-02' }, { startDate: '2026-02-30' }, { currencyCode: 'TR' }]) expect(periodSchema.safeParse({ ...period, ...patch }).success).toBe(false)
  })
  it('validates sales without treating absent values as zero', () => {
    const input = { saleDate: '2026-01-01', locationId: loc, productId, quantity: '0', grossSales: '0', netSales: '0' }
    expect(salesInputSchema.safeParse(input).success).toBe(true)
    expect(salesInputSchema.safeParse({ ...input, quantity: '1' }).success).toBe(true)
    for (const patch of [{ quantity: '' }, { quantity: '-1' }, { quantity: '1.00001' }, { netSales: '1' }, { grossSales: '1' }]) expect(salesInputSchema.safeParse({ ...input, ...patch }).success).toBe(false)
  })
  it('rejects zero, negative, imprecise expenses and absent descriptions', () => {
    for (const amount of ['0', '-1', '1.001', '', 'NaN']) expect(expenseInputSchema.safeParse({ ...expense, locationId: '', amount }).success).toBe(false)
    expect(expenseInputSchema.safeParse({ ...expense, locationId: '', amount: '1' }).success).toBe(true)
  })
})
describe('operating report', () => {
  it('renders formulas from the read model, history and writer controls', async () => {
    setup()
    expect(await screen.findByText('Ürün Kârlılığı · TRY')).toBeInTheDocument()
    expect(screen.getByText('64,00 TRY')).toBeInTheDocument()
    expect(screen.getByText('-5,00')).toBeInTheDocument()
    expect(screen.getByText('İptal (VOID)')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Cancelled cost düzenle' })).not.toBeInTheDocument()
    expect(screen.queryByText('Net Kâr')).not.toBeInTheDocument()
  })
  it('hides write actions from read-only users', async () => {
    setup('page', false)
    await screen.findByText('Ürün Kârlılığı · TRY')
    expect(screen.queryByRole('button', { name: 'Satış Ekle' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Gider Ekle' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /düzenle|iptal et/ })).not.toBeInTheDocument()
  })
  it('sends all filter arguments and allocation methods', async () => {
    const { user } = setup()
    await screen.findByText('Ürün Kârlılığı · TRY')
    change('Başlangıç tarihi', '2026-01-01'); change('Bitiş tarihi', '2026-01-31')
    await screen.findByRole('option', { name: 'Kitchen' })
    await user.selectOptions(screen.getByLabelText('Lokasyon'), loc)
    change('Para birimi', 'EUR')
    for (const method of ['QUANTITY', 'EQUAL', 'NET_SALES']) {
      await user.selectOptions(screen.getByLabelText('Dağıtım yöntemi'), method)
      await waitFor(() => expect(rpc).toHaveBeenCalledWith('get_operating_profitability', { p_tenant_id: tenant.tenantId, p_start_date: period.startDate, p_end_date: period.endDate, p_currency_code: 'EUR', p_location_id: loc, p_allocation_method: method }))
    }
  })
  it('does not request an invalid period', async () => {
    setup(); await screen.findByText('Ürün Kârlılığı · TRY'); rpc.mockClear()
    change('Başlangıç tarihi', '2099-01-01')
    expect(screen.getByRole('alert')).toHaveTextContent('366')
    expect(rpc).not.toHaveBeenCalled()
  })
  it('shows incomplete costs as unavailable', async () => {
    products = [{ ...product, costingComplete: false, recipeCostPerPortion: null, estimatedRecipeCost: null, directContribution: null, allocatedOperatingContribution: null, allocatedOperatingMarginPct: null, targetDifferencePp: null, suggestedGrossPriceAtTarget: null, suggestedNetPriceAtTarget: null }]
    setup(); expect(await screen.findByText(/Reçete maliyeti eksik/)).toBeInTheDocument()
    expect(screen.queryByText('64,00 TRY')).not.toBeInTheDocument()
  })
  it.each(['NO_SALES', 'ZERO_ALLOCATION_BASE'] as const)('shows %s allocation status', async (value) => {
    status = value; setup(); expect(await screen.findByText(/Gider dağıtımı hesaplanmadı/)).toBeInTheDocument()
  })
  it('sorts numeric columns with nulls last in both directions', async () => {
    products = [product, { ...product, productId: loc, productName: 'Beta', netSales: 200 }, { ...product, productId: entryId, productName: 'Missing', directContribution: null }]
    const { user } = setup(); const table = await screen.findByRole('table', { name: 'Ürün Kârlılığı · TRY' })
    await user.click(within(table).getByRole('button', { name: 'Direkt Katkı' }))
    expect(within(table).getAllByRole('row').at(-1)).toHaveTextContent('Missing')
    await user.click(within(table).getByRole('button', { name: 'Direkt Katkı' }))
    expect(within(table).getAllByRole('row').at(-1)).toHaveTextContent('Missing')
  })
  it('rejects a mismatched tenant read model', async () => {
    rpc.mockResolvedValue({ data: { ...data, tenantId: loc }, error: null })
    setup(); await waitFor(() => expect(screen.getAllByRole('alert').length).toBeGreaterThan(0))
    expect(screen.queryByText('Ürün Kârlılığı · TRY')).not.toBeInTheDocument()
  })
})
describe('operating commands', () => {
  it('upserts manual sales with derived currency and invalidates both read models', async () => {
    const { user, close, invalidate } = setup('sales')
    change('Tarih', '2026-01-01'); change('Lokasyon', loc); change('Menü ürünü', productId); change('Satış adedi', '2'); change('Brüt satış', '120'); change('Net satış', '100')
    expect(screen.getByText(/mevcut toplamları güncellenecek/)).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    await waitFor(() => expect(close).toHaveBeenCalledOnce())
    expect(commands()[0]).toEqual(['upsert_menu_product_sales_fact', { p_tenant_id: tenant.tenantId, p_location_id: loc, p_sale_date: '2026-01-01', p_menu_product_id: productId, p_quantity: 2, p_gross_sales: 120, p_net_sales: 100 }])
    expect(invalidate).toHaveBeenCalledWith({ queryKey: ['operating-profitability', tenant.tenantId] })
    expect(invalidate).toHaveBeenCalledWith({ queryKey: ['operating-data', tenant.tenantId] })
  })
  it('locks sales identity and preserves errors for retry', async () => {
    const { user, close } = setup('edit-sales')
    expect(screen.getByLabelText('Tarih')).toBeDisabled(); expect(screen.getByLabelText('Lokasyon')).toBeDisabled(); expect(screen.getByLabelText('Menü ürünü')).toBeDisabled()
    rpc.mockResolvedValueOnce({ data: null, error: { message: 'COSTING_NO_CHANGES' } })
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    expect(await screen.findByRole('alert')).toBeInTheDocument(); expect(close).not.toHaveBeenCalled()
    change('Satış adedi', '3'); await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    await waitFor(() => expect(close).toHaveBeenCalledOnce())
  })
  it.each(['expense', 'edit-expense'] as const)('sends %s without finance mutations', async (mode) => {
    const { user, close } = setup(mode)
    change('Tutar', '90'); change('Açıklama', 'Rent')
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    await waitFor(() => expect(close).toHaveBeenCalledOnce())
    expect(commands()).toHaveLength(1)
    expect(commands()[0]).toEqual([mode === 'expense' ? 'create_operating_cost_entry' : 'update_operating_cost_entry', expect.objectContaining({ p_tenant_id: tenant.tenantId, p_location_id: undefined, p_amount: 90, p_description: 'Rent', ...(mode === 'edit-expense' ? { p_entry_id: entryId } : {}) })])
  })
  it('requires explicit void confirmation', async () => {
    const { user } = setup()
    await user.click(await screen.findByRole('button', { name: 'Staff cost iptal et' }))
    expect(commands()).toHaveLength(0)
    await user.click(screen.getByRole('button', { name: 'İptali Onayla' }))
    await waitFor(() => expect(commands()).toHaveLength(1))
    expect(commands()[0]).toEqual(['void_operating_cost_entry', { p_tenant_id: tenant.tenantId, p_entry_id: entryId }])
  })
  it.each(['edit-sales', 'edit-expense', 'void'] as const)('guards duplicate %s submits', async (mode) => {
    const { close } = setup(mode)
    let resolve!: (value: unknown) => void
    rpc.mockImplementationOnce(() => new Promise((done) => { resolve = done }))
    const button = screen.getByRole('button', { name: mode === 'void' ? 'İptali Onayla' : 'Kaydet' })
    const form = button.closest('form')!
    fireEvent.submit(form); fireEvent.submit(form)
    await waitFor(() => expect(commands()).toHaveLength(1))
    await act(async () => resolve({ data: entryId, error: null }))
    await waitFor(() => expect(close).toHaveBeenCalledOnce())
  })
})
