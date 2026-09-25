import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { InventoryPage } from '../modules/inventory/pages/InventoryPage'
import { InventoryItemDialog, InventoryMovementDialog, InventoryCountStartDialog, InventoryCountForm } from '../modules/inventory/pages/InventoryDialogs'
import { parseQuantity, itemInputSchema, signedQuantity, countDifference, type InventoryItem, type CountDetail } from '../modules/inventory/model/inventory'

const { rpc, tenant } = vi.hoisted(() => ({ rpc: vi.fn(), tenant: {
  tenantId: '91111111-aaaa-4aaa-8aaa-111111111111', context: { modules: ['inventory'], permissions: ['inventory.read'] },
} }))
vi.mock('../shared/supabase/client', () => ({ supabase: { rpc } }))
vi.mock('../shared/tenant/useTenant', () => ({ useTenant: () => tenant }))
const itemId = '91111111-aaaa-4aaa-8aaa-888888888881'
const locationId = '91111111-aaaa-4aaa-8aaa-999999999991'
const countId = '91111111-aaaa-4aaa-8aaa-777777777771'
const item: InventoryItem = { id: itemId, name: 'Et', sku: 'ET-1', category: 'Protein', baseUnit: 'GRAM', criticalStock: 5, status: 'ACTIVE', quantity: -2, isCritical: true, isNegative: true }
const detail: CountDetail = { tenantId: tenant.tenantId, id: countId, locationId, status: 'DRAFT', countedAt: '2026-09-25T12:00:00Z', notes: null, postedAt: null,
  lines: [{ itemId, itemName: 'Et', baseUnit: 'GRAM', systemQuantity: -2, countedQuantity: 5, difference: 7 }] }
beforeEach(() => {
  tenant.context.permissions = ['inventory.read']
  tenant.context.modules = ['inventory']
  rpc.mockReset()
  rpc.mockImplementation(async (name: string, args: { p_location_id?: string }) => {
    if (name === 'get_inventory_context') return { data: { tenantId: tenant.tenantId, items: [{ id: itemId, name: 'Et', baseUnit: 'GRAM' }], locations: [{ id: locationId, name: 'Merkez' }] }, error: null }
    if (name === 'get_inventory_overview') return { data: { tenantId: tenant.tenantId, locationId: args.p_location_id ?? null, summary: { activeItemCount: 2, criticalItemCount: 2, negativeItemCount: 1 },
      items: [item, { ...item, id: countId, name: 'Yumurta', baseUnit: 'EACH', quantity: 3, isNegative: false }], locations: [{ id: locationId, name: 'Merkez', status: 'ACTIVE' }], recentMovements: [] }, error: null }
    if (name === 'get_inventory_management') return { data: { tenantId: tenant.tenantId, items: [item, { ...item, id: countId, name: 'Pasif Kart', status: 'PASSIVE', quantity: 0, isNegative: false }] }, error: null }
    if (name === 'get_inventory_counts') return { data: { tenantId: tenant.tenantId, counts: [{ id: countId, locationId, locationName: 'Merkez', status: 'DRAFT', countedAt: detail.countedAt, postedAt: null, notes: null }] }, error: null }
    if (name === 'get_inventory_count_detail') return { data: detail, error: null }
    return { data: countId, error: null }
  })
})
afterEach(cleanup)
function setup(mode: 'page' | 'item' | 'edit' | 'movement' | 'start' | 'count' | 'posted' | 'count-readonly' | 'count-only' = 'page') {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } })
  const invalidate = vi.spyOn(client, 'invalidateQueries')
  const onClose = vi.fn(), onCreated = vi.fn()
  render(<QueryClientProvider client={client}>{mode === 'page' ? <InventoryPage /> : mode === 'item' || mode === 'edit' ? <InventoryItemDialog item={mode === 'edit' ? item : undefined} onClose={onClose} /> : mode === 'movement' ? <InventoryMovementDialog onClose={onClose} /> : mode === 'start' ? <InventoryCountStartDialog onClose={onClose} onCreated={onCreated} /> :
    <InventoryCountForm detail={mode === 'posted' ? { ...detail, status: 'POSTED' } : detail} canCount={mode !== 'count-readonly'} canAdjust={mode !== 'count-only'} onClose={onClose} />}</QueryClientProvider>)
  return { user: userEvent.setup(), onClose, onCreated, invalidate }
}
const commands = () => rpc.mock.calls.filter(([name]) => !String(name).startsWith('get_'))
const change = (label: string, value: string) => fireEvent.change(screen.getByLabelText(label), { target: { value } })
async function movementFields(user: ReturnType<typeof userEvent.setup>) {
  await screen.findByRole('option', { name: 'Et · Gram' })
  await user.selectOptions(screen.getByLabelText('Stok Kartı'), itemId)
  await user.selectOptions(screen.getByLabelText('Lokasyon'), locationId)
  change('Miktar', '1.250,5000'); change('Açıklama', ' Manuel hareket ')
}

describe('inventory quantity and item rules', () => {
  it.each([['1', 1], ['1,5', 1.5], ['1.250,5000', 1250.5], ['1.5', 1.5], ['0,0001', 0.0001]])('parses %s', (input, expected) => expect(parseQuantity(String(input))).toBe(expected))
  it.each(['0', '-1', '1e3', '1E2', '1.2.3,45', '12.50,0', '1234.567,8', '1,12345', '1.23456', 'Infinity', 'NaN', '', '1,', '+1'])('rejects %s', (input) => expect(parseQuantity(input)).toBeNull())
  it('permits zero count and critical stock', () => expect(parseQuantity('0', true)).toBe(0))
  it('validates item fields and optional critical level', () => {
    const input = { name: ' Et ', sku: '', category: '', baseUnit: 'GRAM', status: 'ACTIVE', criticalStock: '' }
    expect(itemInputSchema.parse(input)).toMatchObject({ name: 'Et', criticalStock: null })
    for (const patch of [{ name: 'x' }, { baseUnit: 'KG' }, { criticalStock: '-1' }, { criticalStock: '1.00001' }, { category: 'x'.repeat(121) }]) expect(itemInputSchema.safeParse({ ...input, ...patch }).success).toBe(false)
  })
  it.each(['ISSUE', 'WASTE', 'COMPLIMENTARY'] as const)('maps %s negative', (type) => expect(signedQuantity(type, 5, 'INCREASE')).toBe(-5))
  it('maps receipt and controlled manual direction', () => {
    expect(signedQuantity('RECEIPT', 5, 'DECREASE')).toBe(5)
    expect(signedQuantity('MANUAL_ADJUSTMENT', 5, 'INCREASE')).toBe(5)
    expect(signedQuantity('MANUAL_ADJUSTMENT', 5, 'DECREASE')).toBe(-5)
    expect(countDifference(5, -1.8766)).toBe(6.8766)
  })
})
describe('inventory page access and balances', () => {
  it('shows negative and critical cards; hides all mutation controls for readers', async () => {
    setup()
    expect(await screen.findByText('Et')).toBeInTheDocument()
    expect(screen.getByText('-2 Gram')).toBeInTheDocument()
    expect(screen.getByText('3 Adet')).toBeInTheDocument()
    expect(screen.getByText('Et').closest('article')).toHaveClass('inventory-negative')
    expect(screen.getByText('Yumurta').closest('article')).toHaveClass('inventory-critical')
    for (const name of ['Yeni Stok Kartı', 'Hareket Ekle', 'Sayım Başlat', 'Düzenle']) expect(screen.queryByRole('button', { name })).not.toBeInTheDocument()
  })
  it.each([['inventory.write', 'Yeni Stok Kartı'], ['inventory.adjust', 'Hareket Ekle'], ['inventory.count', 'Sayım Başlat']])('shows only %s controls', async (permission, label) => {
    tenant.context.permissions.push(permission)
    setup()
    expect(await screen.findByRole('button', { name: label })).toBeInTheDocument()
    for (const name of ['Yeni Stok Kartı', 'Hareket Ekle', 'Sayım Başlat'].filter((name) => name !== label)) expect(screen.queryByRole('button', { name })).not.toBeInTheDocument()
  })
  it('filters locations and fetches passive cards only when requested', async () => {
    const { user } = setup()
    await screen.findByText('Et')
    expect(rpc).not.toHaveBeenCalledWith('get_inventory_management', expect.anything())
    await user.selectOptions(screen.getByLabelText('Lokasyon Filtresi'), locationId)
    await waitFor(() => expect(rpc).toHaveBeenCalledWith('get_inventory_overview', { p_tenant_id: tenant.tenantId, p_location_id: locationId }))
    await user.click(screen.getByLabelText('Pasif kartları da yönet'))
    expect(await screen.findByText('Pasif Kart')).toBeInTheDocument()
  })
})
describe('item commands', () => {
  it('sends normalized create args', async () => {
    const { user, onClose, invalidate } = setup('item')
    change('Ad', ' Un '); change('SKU', ' UN-1 '); change('Kategori', ' Gıda '); change('Kritik Stok', '1.250,5000')
    await user.selectOptions(screen.getByLabelText('Baz Birim'), 'GRAM')
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
    expect(commands()).toEqual([['create_inventory_item', { p_tenant_id: tenant.tenantId, p_name: 'Un', p_sku: 'UN-1', p_category: 'Gıda', p_base_unit: 'GRAM', p_critical_stock: 1250.5 }]])
    expect(invalidate).toHaveBeenCalledWith({ queryKey: ['inventory-overview', tenant.tenantId] })
    expect(invalidate).not.toHaveBeenCalledWith({ queryKey: ['finance-overview', tenant.tenantId] })
  })
  it('updates item without base unit, permits clearing optional fields', async () => {
    const { user } = setup('edit')
    expect(screen.getByLabelText('Baz Birim')).toBeDisabled()
    change('Ad', 'Dana Eti'); change('SKU', ''); change('Kategori', ''); change('Kritik Stok', '')
    await user.selectOptions(screen.getByLabelText('Durum'), 'PASSIVE')
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    await waitFor(() => expect(commands()).toHaveLength(1))
    expect(commands()[0]).toEqual(['update_inventory_item', { p_tenant_id: tenant.tenantId, p_item_id: itemId, p_name: 'Dana Eti', p_status: 'PASSIVE', p_sku: undefined, p_category: undefined, p_critical_stock: undefined }])
  })
  it('blocks invalid item submission', () => { setup('item'); change('Ad', 'x'); change('Kritik Stok', '-1'); fireEvent.submit(screen.getByRole('button', { name: 'Kaydet' }).closest('form')!); expect(commands()).toHaveLength(0) })
  it('preserves failed edits and permits retry with Turkish nonzero error', async () => {
    const { user, onClose } = setup('edit')
    rpc.mockResolvedValueOnce({ data: null, error: { message: 'INVENTORY_NONZERO_STOCK' } })
    change('Ad', 'Dana Eti')
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('tüm lokasyonlardaki stok bakiyesi sıfır')
    expect(screen.getByLabelText('Ad')).toHaveValue('Dana Eti')
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
  })
  it('blocks duplicate submit and close during pending item save', async () => {
    const { onClose } = setup('item')
    let resolve!: (value: { data: string; error: null }) => void
    rpc.mockReturnValueOnce(new Promise((done) => { resolve = done }))
    change('Ad', 'Un')
    const form = screen.getByRole('button', { name: 'Kaydet' }).closest('form')!
    act(() => { fireEvent.submit(form); fireEvent.submit(form) })
    await waitFor(() => expect(commands()).toHaveLength(1))
    expect(screen.getByRole('button', { name: 'Kapat' })).toBeDisabled()
    await act(async () => { resolve({ data: itemId, error: null }) })
    expect(onClose).toHaveBeenCalledOnce()
  })
})
describe('movement commands', () => {
  it.each(['RECEIPT', 'ISSUE', 'WASTE', 'COMPLIMENTARY', 'MANUAL_ADJUSTMENT'] as const)('sends positive quantity for %s', async (type) => {
    const { user, onClose } = setup('movement'); await movementFields(user)
    await user.selectOptions(screen.getByLabelText('Hareket Tipi'), type)
    if (type === 'MANUAL_ADJUSTMENT') await user.selectOptions(screen.getByLabelText('Yön'), 'DECREASE')
    expect(screen.queryByRole('option', { name: 'Sayım Farkı' })).not.toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
    expect(commands()).toEqual([['create_inventory_movement', { p_tenant_id: tenant.tenantId, p_item_id: itemId, p_location_id: locationId, p_movement_type: type,
      p_quantity: 1250.5, p_description: 'Manuel hareket', p_direction: type === 'MANUAL_ADJUSTMENT' ? 'DECREASE' : undefined }]])
  })
  it('allows manual increase and blocks invalid amounts / descriptions', async () => {
    const { user } = setup('movement'); await movementFields(user)
    for (const quantity of ['-1', '0', '1,00001']) { change('Miktar', quantity); expect(screen.getByRole('button', { name: 'Kaydet' })).toBeDisabled() }
    change('Miktar', '2'); change('Açıklama', 'x'); expect(screen.getByRole('button', { name: 'Kaydet' })).toBeDisabled()
    change('Açıklama', 'Stok düzeltme'); await user.selectOptions(screen.getByLabelText('Hareket Tipi'), 'MANUAL_ADJUSTMENT')
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    await waitFor(() => expect(commands()).toHaveLength(1))
    expect(commands()[0][1]).toMatchObject({ p_direction: 'INCREASE', p_quantity: 2 })
  })
  it('preserves movement on RPC error and retries', async () => {
    const { user, onClose } = setup('movement'); await movementFields(user)
    rpc.mockResolvedValueOnce({ data: null, error: { message: 'Geçici hata' } })
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Geçici hata')
    expect(screen.getByLabelText('Miktar')).toHaveValue('1.250,5000')
    await user.click(screen.getByRole('button', { name: 'Kaydet' })); await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
  })
})
describe('inventory counts', () => {
  it('starts count with selected location', async () => {
    const { user, onCreated } = setup('start')
    await screen.findByRole('option', { name: 'Merkez' }); await user.selectOptions(screen.getByLabelText('Lokasyon'), locationId); change('Notlar', ' Sabah ')
    await user.click(screen.getByRole('button', { name: 'Sayımı Başlat' }))
    await waitFor(() => expect(onCreated).toHaveBeenCalledWith(countId))
    expect(commands()[0]).toEqual(['create_inventory_count', { p_tenant_id: tenant.tenantId, p_location_id: locationId, p_notes: 'Sabah' }])
  })
  it('saves zero quantities, previews difference and requires saving before post', async () => {
    const { user } = setup('count')
    change('Sayılan · Et', '0')
    expect(screen.getByText('Fark: 2')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Sayımı İşle' })).toBeDisabled()
    await user.click(screen.getByRole('button', { name: 'Sayımı Kaydet' }))
    await waitFor(() => expect(screen.getByRole('button', { name: 'Sayımı İşle' })).toBeEnabled())
    expect(commands()[0]).toEqual(['update_inventory_count', { p_tenant_id: tenant.tenantId, p_count_id: countId, p_lines: [{ itemId, countedQuantity: 0 }] }])
  })
  it('requires explicit post confirmation and invalidates inventory only', async () => {
    const { user, onClose, invalidate } = setup('count')
    await user.click(screen.getByRole('button', { name: 'Sayımı İşle' }))
    expect(screen.getByText(/Sayım farkları stok hareketi olarak işlenecektir/)).toBeInTheDocument()
    expect(commands()).toHaveLength(0)
    await user.click(screen.getByRole('button', { name: 'Onayla ve İşle' }))
    await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
    expect(commands()).toEqual([['post_inventory_count', { p_tenant_id: tenant.tenantId, p_count_id: countId }]])
    expect(invalidate).toHaveBeenCalledWith({ queryKey: ['inventory-count-detail', tenant.tenantId] })
    expect(invalidate).not.toHaveBeenCalledWith({ queryKey: ['finance-overview', tenant.tenantId] })
  })
  it.each(['posted', 'count-readonly'] as const)('keeps %s immutable in UI', (mode) => {
    setup(mode)
    expect(screen.getByLabelText('Sayılan · Et')).toBeDisabled()
    expect(screen.queryByRole('button', { name: 'Sayımı Kaydet' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Sayımı İşle' })).not.toBeInTheDocument()
  })
  it('count permission alone can save but cannot post', () => {
    setup('count-only'); expect(screen.getByLabelText('Sayılan · Et')).toBeEnabled(); expect(screen.queryByRole('button', { name: 'Sayımı İşle' })).not.toBeInTheDocument()
  })
  it('keeps failed count inputs, blocks duplicates and retries post', async () => {
    const { user, onClose } = setup('count')
    change('Sayılan · Et', '6')
    rpc.mockResolvedValueOnce({ data: null, error: { message: 'Kaydetme hatası' } })
    await user.click(screen.getByRole('button', { name: 'Sayımı Kaydet' })); expect(await screen.findByRole('alert')).toHaveTextContent('Kaydetme hatası')
    expect(screen.getByLabelText('Sayılan · Et')).toHaveValue('6')
    await user.click(screen.getByRole('button', { name: 'Sayımı Kaydet' })); await waitFor(() => expect(screen.getByRole('button', { name: 'Sayımı İşle' })).toBeEnabled())
    await user.click(screen.getByRole('button', { name: 'Sayımı İşle' }))
    let resolve!: (value: { data: null; error: { message: string } }) => void
    rpc.mockReturnValueOnce(new Promise((done) => { resolve = done }))
    const button = screen.getByRole('button', { name: 'Onayla ve İşle' })
    act(() => { fireEvent.click(button); fireEvent.click(button) })
    await waitFor(() => expect(commands().filter(([name]) => name === 'post_inventory_count')).toHaveLength(1))
    await act(async () => { resolve({ data: null, error: { message: 'Geçici hata' } }) })
    expect(await screen.findByRole('alert')).toHaveTextContent('Geçici hata')
    await user.click(screen.getByRole('button', { name: 'Onayla ve İşle' })); await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
  })
})
