import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { CostingPage } from '../modules/costing/pages/CostingPage'
import { RecipeDialog, MenuProductDialog } from '../modules/costing/pages/CostingDialogs'
import { recipePreview, menuPreview, recipeInputSchema, type Recipe, type MenuProduct } from '../modules/costing/model/costing'
import { hasAccess } from '../core/access/accessUtils'
import { appNavigation } from '../core/navigation/appNavigation'

const { rpc, tenant } = vi.hoisted(() => ({ rpc: vi.fn(), tenant: { tenantId: 'c1111111-aaaa-4aaa-8aaa-111111111111', context: { modules: ['food-service'], permissions: ['food-service.costing.read'] } } }))
vi.mock('../shared/supabase/client', () => ({ supabase: { rpc } }))
vi.mock('../shared/tenant/useTenant', () => ({ useTenant: () => tenant }))
const itemId = 'c1111111-1111-4111-8111-111111111111', recipeId = 'c1111111-2222-4222-8222-111111111111', productId = 'c1111111-3333-4333-8333-111111111111'
const recipe: Recipe = { id: recipeId, name: 'Plate', code: null, category: null, currencyCode: 'TRY', portions: 2, status: 'ACTIVE', costingComplete: true, missingCostItemCount: 0,
  yieldQuantity: null, yieldUnit: null, unresolvedLines: [], subrecipeLines: [], missingDirectCostItemCount: 0, missingPurchaseCostItemCount: 0,
  missingConversionItemCount: 0, missingSubrecipeCostCount: 0, directLineCount: 1, unresolvedLineCount: 0, subrecipeLineCount: 0, costStatus: 'READY',
  totalLastCost: 20, totalWeightedCost: 15, costPerPortionLast: 10, costPerPortionWeighted: 7.5,
  lines: [{ inventoryItemId: itemId, itemName: 'Meat', baseUnit: 'GRAM', itemStatus: 'ACTIVE', quantityBase: 100, notes: null, lastUnitCost: .2, weightedUnitCost: .15, lastLineCost: 20, weightedLineCost: 15, costStatus: 'READY' }] }
const product: MenuProduct = { id: productId, name: 'Menu', code: null, category: null, recipeId, recipeName: 'Plate', currencyCode: 'TRY', salePriceGross: 120, salesTaxRate: 20,
  targetFoodCostPct: 25, targetOperatingMarginPct: null, costMethod: 'WEIGHTED_PURCHASE', status: 'ACTIVE', costingComplete: true, missingCostItemCount: 0, salePriceNet: 100, recipeCostPerPortion: 7.5, foodCostPct: 7.5,
  contributionMargin: 92.5, suggestedNetPrice: 30, suggestedGrossPrice: 36, targetDifferencePp: -17.5 }
const item = { id: itemId, name: 'Meat', sku: 'M1', category: 'Meat', baseUnit: 'GRAM', lastPurchase: { unitCost: .2, invoiceDate: '2026-01-03', invoiceNumber: 'COST-3', supplierName: 'Supplier', receiptBaseQuantity: 1000 },
  previousPurchase: { unitCost: .15, invoiceDate: '2026-01-02' }, weightedPurchaseUnitCost: .15, purchaseReceiptCount: 3, purchasedBaseQuantity: 4000, purchaseNetTotal: 600, priceChangePct: 100 / 3, costStatus: 'READY' }
beforeEach(() => {
  tenant.context.permissions = ['food-service.costing.read']
  rpc.mockReset()
  rpc.mockImplementation(async (name: string, args: { p_currency_code?: string; p_location_id?: string }) => {
    if (name === 'get_inventory_cost_overview') return { data: { tenantId: tenant.tenantId, currencyCode: args.p_currency_code, locationId: args.p_location_id ?? null, locations: [], items: [item] }, error: null }
    if (name === 'get_recipe_costing_overview') return { data: { tenantId: tenant.tenantId, locationId: args.p_location_id ?? null, recipes: [recipe] }, error: null }
    if (name === 'get_menu_costing_overview') return { data: { tenantId: tenant.tenantId, locationId: args.p_location_id ?? null, products: [product] }, error: null }
    return { data: recipeId, error: null }
  })
})
afterEach(cleanup)
function setup(mode: 'page' | 'recipe' | 'edit-recipe' | 'menu' | 'edit-menu' = 'page', recipes = [recipe]) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } })
  const invalidate = vi.spyOn(client, 'invalidateQueries'), onClose = vi.fn()
  render(<QueryClientProvider client={client}>{mode === 'page' ? <CostingPage /> : mode === 'recipe' || mode === 'edit-recipe' ? <RecipeDialog location="" recipe={mode === 'edit-recipe' ? recipe : undefined} onClose={onClose} /> : <MenuProductDialog product={mode === 'edit-menu' ? product : undefined} recipes={recipes} onClose={onClose} />}</QueryClientProvider>)
  return { user: userEvent.setup(), onClose, invalidate }
}
const change = (label: string, value: string) => fireEvent.change(screen.getByLabelText(label), { target: { value } })
const commands = () => rpc.mock.calls.filter(([name]) => !String(name).startsWith('get_'))

describe('costing calculations', () => {
  it('calculates line costs, weighted batch and portions', () => {
    const value = recipePreview([{ quantityBase: 100, lastUnitCost: .2, weightedUnitCost: 600 / 4000 }], 2)
    expect(value).toEqual({ missing: 0, complete: true, last: 20, weighted: 15, perLast: 10, perWeighted: 7.5 })
  })
  it('never treats a missing ingredient as zero', () => {
    const value = recipePreview([{ quantityBase: 100, lastUnitCost: .2, weightedUnitCost: .15 }, { quantityBase: 5, lastUnitCost: null, weightedUnitCost: null }], 2)
    expect(value).toEqual({ missing: 1, complete: false, last: null, weighted: null, perLast: null, perWeighted: null })
  })
  it('treats a real zero purchase cost as complete', () => expect(recipePreview([{ quantityBase: 1, lastUnitCost: 0, weightedUnitCost: 0 }], 1)).toMatchObject({ complete: true, last: 0 }))
  it('calculates net sales, food cost, contribution and target reference without early rounding', () => {
    expect(menuPreview(120, 20, 7.5, 25)).toEqual({ net: 100, foodCostPct: 7.5, margin: 92.5, suggestedGross: 36 })
    expect(menuPreview(1, 18, .1, 30).net).toBeCloseTo(1 / 1.18, 12)
  })
  it('handles zero sale, absent target and incomplete cost', () => {
    expect(menuPreview(0, 10, 7.5, null)).toEqual({ net: 0, foodCostPct: null, margin: -7.5, suggestedGross: null })
    expect(menuPreview(120, 20, null, 25)).toEqual({ net: 100, foodCostPct: null, margin: null, suggestedGross: null })
  })
  it('validates quantities and portions while allowing duplicate ingredients', () => {
    const input = { name: 'Plate', code: '', category: '', currencyCode: 'TRY', portions: '2', status: 'ACTIVE', lines: [{ inventoryItemId: itemId, quantityBase: '100', notes: '' }] }
    expect(recipeInputSchema.safeParse(input).success).toBe(true)
    for (const portions of ['0', '-1', '100000000', '.00001']) expect(recipeInputSchema.safeParse({ ...input, portions }).success).toBe(false)
    expect(recipeInputSchema.safeParse({ ...input, lines: [...input.lines, ...input.lines] }).success).toBe(true)
  })
})
describe('costing read models', () => {
  it('shows last/previous, weighted cost and price change; switches currency', async () => {
    const { user } = setup()
    expect(await screen.findByText('0,200000 TRY')).toBeInTheDocument()
    expect(screen.getAllByText('0,150000 TRY')).toHaveLength(2)
    expect(screen.getByText('+33,33')).toBeInTheDocument()
    change('Para birimi filtresi', 'EUR')
    expect(await screen.findByText('0,200000 EUR')).toBeInTheDocument()
    expect(rpc).toHaveBeenCalledWith('get_inventory_cost_overview', { p_tenant_id: tenant.tenantId, p_currency_code: 'EUR', p_location_id: undefined })
    await user.click(screen.getByRole('tab', { name: 'Reçeteler' }))
    expect(screen.queryByRole('button', { name: 'Yeni Reçete' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Plate düzenle' })).not.toBeInTheDocument()
    await user.click(screen.getByRole('tab', { name: 'Menü Kârlılığı' }))
    expect(screen.queryByRole('button', { name: 'Yeni Menü Ürünü' })).not.toBeInTheDocument()
    expect(screen.getByText('92,50 TRY')).toBeInTheDocument()
  })
  it('gates the navigation by food-service and costing.read', () => {
    const requirement = appNavigation[0].items.find((i) => i.path === '/costing')!
    expect(requirement.requiredModule).toBe('food-service')
    expect(requirement.requiredPermission).toBe('food-service.costing.read')
    const context = { modules: ['food-service'], permissions: ['food-service.costing.read'] } as Parameters<typeof hasAccess>[0]
    expect(hasAccess(context, requirement)).toBe(true)
    expect(hasAccess({ ...context, modules: [] }, requirement)).toBe(false)
    expect(hasAccess({ ...context, permissions: [] }, requirement)).toBe(false)
  })
  it('writer gets create and edit controls', async () => {
    tenant.context.permissions.push('food-service.costing.write')
    const { user } = setup(); await screen.findByText('Meat')
    await user.click(screen.getByRole('tab', { name: 'Reçeteler' }))
    expect(screen.getByRole('button', { name: 'Yeni Reçete' })).toBeEnabled()
    await user.click(screen.getByRole('button', { name: 'Plate düzenle' }))
    expect(screen.getByRole('dialog')).toHaveAccessibleName('Reçeteyi Düzenle')
  })
})
describe('recipe commands', () => {
  it('sends create args and previews portion costs', async () => {
    const { user, onClose, invalidate } = setup('recipe')
    await screen.findByRole('option', { name: 'Meat' })
    change('Reçete adı', ' New plate '); change('Porsiyon sayısı', '2'); change('Baz miktar 1', '100')
    await user.selectOptions(screen.getByLabelText('Stok Kartı 1'), itemId)
    expect(screen.getByText('7,50 TRY')).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Reçeteyi Kaydet' }))
    await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
    expect(commands()).toEqual([['create_recipe', { p_tenant_id: tenant.tenantId, p_name: 'New plate', p_code: undefined, p_category: undefined, p_currency_code: 'TRY', p_portions: 2, p_lines: [{ inventoryItemId: itemId, quantityBase: 100, notes: '' }] }]])
    expect(invalidate).toHaveBeenCalledWith({ queryKey: ['menu-costs', tenant.tenantId] })
  })
  it('sends recipe update status, lines and identity', async () => {
    const { user, onClose } = setup('edit-recipe'); await screen.findByRole('option', { name: 'Meat' })
    change('Porsiyon sayısı', '4'); await user.selectOptions(screen.getByLabelText('Durum'), 'PASSIVE')
    await user.click(screen.getByRole('button', { name: 'Reçeteyi Kaydet' }))
    await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
    expect(commands()[0]).toEqual(['update_recipe', expect.objectContaining({ p_recipe_id: recipeId, p_portions: 4, p_status: 'PASSIVE' })])
  })
  it('blocks duplicate submits and retains recipe edits after errors for retry', async () => {
    const { user, onClose } = setup('edit-recipe'); await screen.findByRole('option', { name: 'Meat' })
    change('Reçete adı', 'Changed')
    let resolve!: (value: unknown) => void
    rpc.mockImplementationOnce(() => new Promise((done) => { resolve = done }))
    const form = screen.getByRole('button', { name: 'Reçeteyi Kaydet' }).closest('form')!
    act(() => { fireEvent.submit(form); fireEvent.submit(form) })
    await waitFor(() => expect(commands()).toHaveLength(1))
    expect(screen.getByRole('button', { name: 'Kapat' })).toBeDisabled()
    await act(async () => resolve({ data: null, error: { message: 'RECIPE_DUPLICATE' } }))
    expect(await screen.findByRole('alert')).toHaveTextContent('reçete zaten var')
    expect(screen.getByLabelText('Reçete adı')).toHaveValue('Changed')
    await user.click(screen.getByRole('button', { name: 'Reçeteyi Kaydet' }))
    await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
  })
})
describe('menu product commands', () => {
  it('sends create args and switches LAST/WEIGHTED preview', async () => {
    const { user, onClose } = setup('menu')
    change('Ürün adı', 'Menu new'); change('KDV dahil satış fiyatı', '120'); change('Satış KDV %', '20'); change('Hedef Food Cost %', '25'); change('Hedef Faaliyet Marjı %', '20')
    await user.selectOptions(screen.getByLabelText('Reçete'), recipeId)
    expect(screen.getByText('7,50 TRY')).toBeInTheDocument()
    await user.selectOptions(screen.getByLabelText('Cost yöntemi'), 'LAST_PURCHASE')
    expect(screen.getByText('10,00 TRY')).toBeInTheDocument()
    expect(screen.getByText('48,00 TRY')).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Ürünü Kaydet' }))
    await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
    expect(commands()[0]).toEqual(['create_menu_product', { p_tenant_id: tenant.tenantId, p_name: 'Menu new', p_code: undefined, p_category: undefined, p_recipe_id: recipeId, p_currency_code: 'TRY', p_sale_price_gross: 120, p_sales_tax_rate: 20, p_target_food_cost_pct: 25, p_target_operating_margin_pct: 20, p_cost_method: 'LAST_PURCHASE' }])
  })
  it('sends menu update and clears nullable target', async () => {
    const { user, onClose } = setup('edit-menu')
    change('Hedef Food Cost %', ''); await user.selectOptions(screen.getByLabelText('Durum'), 'PASSIVE')
    await user.click(screen.getByRole('button', { name: 'Ürünü Kaydet' }))
    await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
    expect(commands()[0]).toEqual(['update_menu_product', expect.objectContaining({ p_product_id: productId, p_target_food_cost_pct: undefined, p_target_operating_margin_pct: undefined, p_status: 'PASSIVE' })])
  })
  it('validates and updates the independent operating margin target', async () => {
    const { user, onClose } = setup('edit-menu')
    for (const value of ['0', '-1', '100', '20.0001']) {
      change('Hedef Faaliyet Marjı %', value)
      expect(screen.getByRole('button', { name: 'Ürünü Kaydet' })).toBeDisabled()
    }
    change('Hedef Faaliyet Marjı %', '30')
    await user.click(screen.getByRole('button', { name: 'Ürünü Kaydet' }))
    await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
    expect(commands()[0]).toEqual(['update_menu_product', expect.objectContaining({ p_target_food_cost_pct: 25, p_target_operating_margin_pct: 30 })])
  })
  it('blocks duplicate menu submit and retries failed RPC', async () => {
    const { user, onClose } = setup('edit-menu')
    let resolve!: (value: unknown) => void
    rpc.mockImplementationOnce(() => new Promise((done) => { resolve = done }))
    const form = screen.getByRole('button', { name: 'Ürünü Kaydet' }).closest('form')!
    act(() => { fireEvent.submit(form); fireEvent.submit(form) })
    await waitFor(() => expect(commands()).toHaveLength(1))
    await act(async () => resolve({ data: null, error: { message: 'MENU_RECIPE_CURRENCY_MISMATCH' } }))
    expect(await screen.findByRole('alert')).toHaveTextContent('aynı para biriminde')
    await user.click(screen.getByRole('button', { name: 'Ürünü Kaydet' }))
    await waitFor(() => expect(onClose).toHaveBeenCalledOnce())
  })
  it('shows missing ingredient warning and no invented profitability', async () => {
    const { user } = setup('menu', [{ ...recipe, costingComplete: false, missingCostItemCount: 1, costPerPortionLast: null, costPerPortionWeighted: null }])
    await user.selectOptions(screen.getByLabelText('Reçete'), recipeId)
    expect(screen.getByRole('status')).toHaveTextContent('1 malzemede alış maliyeti bulunmuyor')
    expect(screen.queryByText('0,00 TRY')).not.toBeInTheDocument()
  })
})
