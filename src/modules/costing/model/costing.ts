import { z } from 'zod'
import { baseUnitSchema, parseQuantity } from '../../inventory/model/inventory'

const nullableNumber = z.number().nullable()
const status = z.enum(['ACTIVE', 'PASSIVE'])
export const methodSchema = z.enum(['LAST_PURCHASE', 'WEIGHTED_PURCHASE'])
const currency = z.string().trim().toUpperCase().regex(/^[A-Z]{3}$/)
const purchase = z.object({ unitCost: z.number(), invoiceDate: z.string(), invoiceNumber: z.string(), supplierName: z.string(), receiptBaseQuantity: z.number() })
export const costItemSchema = z.object({ id: z.uuid(), name: z.string(), sku: z.string().nullable(), category: z.string().nullable(), baseUnit: baseUnitSchema,
  lastPurchase: purchase.nullable(), previousPurchase: purchase.pick({ unitCost: true, invoiceDate: true }).nullable(), weightedPurchaseUnitCost: nullableNumber,
  purchaseReceiptCount: z.number(), purchasedBaseQuantity: z.number(), purchaseNetTotal: z.number(), priceChangePct: nullableNumber, costStatus: z.enum(['READY', 'NO_PURCHASE_COST']) })
export type CostItem = z.infer<typeof costItemSchema>
export const inventoryCostsSchema = z.object({ tenantId: z.uuid(), currencyCode: currency, locationId: z.uuid().nullable(),
  locations: z.array(z.object({ id: z.uuid(), name: z.string() })), items: z.array(costItemSchema) })
const recipeLineSchema = z.object({ inventoryItemId: z.uuid(), itemName: z.string(), baseUnit: baseUnitSchema, itemStatus: status, quantityBase: z.number(), notes: z.string().nullable(),
  lastUnitCost: nullableNumber, weightedUnitCost: nullableNumber, lastLineCost: nullableNumber, weightedLineCost: nullableNumber, costStatus: z.enum(['READY', 'NO_PURCHASE_COST']) })
const unresolvedRecipeLineSchema = z.object({ unresolvedLineId: z.uuid(), inventoryItemId: z.uuid(), itemName: z.string(), baseUnit: baseUnitSchema, itemStatus: status,
  sourceLineKey: z.string().nullable(), sourceQuantity: z.number(), sourceUnit: z.string(), notes: z.string().nullable(), reason: z.literal('UNIT_CONVERSION_REQUIRED'),
  costStatus: z.literal('UNIT_CONVERSION_REQUIRED') })
const subrecipeLineSchema = z.object({ subrecipeId: z.uuid(), subrecipeName: z.string(), subrecipeCode: z.string().nullable(), quantity: nullableNumber,
  unit: baseUnitSchema.nullable(), yieldQuantity: nullableNumber, yieldUnit: baseUnitSchema.nullable(), notes: z.string().nullable(), childCostingComplete: z.boolean(),
  childTotalLastCost: nullableNumber, childTotalWeightedCost: nullableNumber, lastLineCost: nullableNumber, weightedLineCost: nullableNumber,
  costStatus: z.enum(['READY', 'MISSING_USAGE_QUANTITY', 'MISSING_CHILD_YIELD', 'UNIT_MISMATCH', 'CHILD_RECIPE_INACTIVE', 'CHILD_COST_INCOMPLETE']) })
export const recipeSchema = z.object({ id: z.uuid(), name: z.string(), code: z.string().nullable(), category: z.string().nullable(), currencyCode: currency, portions: z.number(), status,
  yieldQuantity: nullableNumber, yieldUnit: baseUnitSchema.nullable(), lines: z.array(recipeLineSchema), unresolvedLines: z.array(unresolvedRecipeLineSchema),
  subrecipeLines: z.array(subrecipeLineSchema), totalLastCost: nullableNumber, totalWeightedCost: nullableNumber, costPerPortionLast: nullableNumber, costPerPortionWeighted: nullableNumber,
  missingCostItemCount: z.number(), missingDirectCostItemCount: z.number(), missingPurchaseCostItemCount: z.number(), missingConversionItemCount: z.number(),
  missingSubrecipeCostCount: z.number(), directLineCount: z.number(), unresolvedLineCount: z.number(), subrecipeLineCount: z.number(),
  costStatus: z.enum(['READY', 'INCOMPLETE', 'DEPENDENCY_CYCLE']), costingComplete: z.boolean() })
export type Recipe = z.infer<typeof recipeSchema>
export const recipesSchema = z.object({ tenantId: z.uuid(), locationId: z.uuid().nullable(), recipes: z.array(recipeSchema) })
export const productSchema = z.object({ id: z.uuid(), name: z.string(), code: z.string().nullable(), category: z.string().nullable(), currencyCode: currency,
  targetOperatingMarginPct: nullableNumber.default(null),
  recipeId: z.uuid(), recipeName: z.string(), salePriceGross: z.number(), salesTaxRate: z.number(), targetFoodCostPct: nullableNumber, costMethod: methodSchema, status,
  costingComplete: z.boolean(), missingCostItemCount: z.number(), salePriceNet: z.number(), recipeCostPerPortion: nullableNumber, foodCostPct: nullableNumber,
  contributionMargin: nullableNumber, suggestedNetPrice: nullableNumber, suggestedGrossPrice: nullableNumber, targetDifferencePp: nullableNumber })
export type MenuProduct = z.infer<typeof productSchema>
export const productsSchema = z.object({ tenantId: z.uuid(), locationId: z.uuid().nullable(), products: z.array(productSchema) })
const decimal = (digits: number, zero = false) => z.string().transform((v) => parseQuantity(v, zero, digits)).pipe(z.number())
const commonInput = { name: z.string().trim().min(2).max(160), code: z.string().trim().max(100), category: z.string().trim().max(120), currencyCode: currency, status }
export const recipeInputSchema = z.object({ ...commonInput, portions: decimal(4).pipe(z.number().lt(1e8)),
  lines: z.array(z.object({ inventoryItemId: z.uuid(), quantityBase: decimal(4), notes: z.string().trim().max(500) })).min(1).max(200) })
export type RecipeInput = z.input<typeof recipeInputSchema>
export const productInputSchema = z.object({ ...commonInput, recipeId: z.uuid(), salePriceGross: decimal(2, true), salesTaxRate: decimal(3, true).pipe(z.number().max(100)),
  targetOperatingMarginPct: z.string().transform((v) => v.trim() === '' ? null : parseQuantity(v, false, 3) ?? NaN).pipe(z.number().lt(100).nullable()),
  targetFoodCostPct: z.string().transform((v) => v.trim() === '' ? null : parseQuantity(v, false, 3) ?? NaN).pipe(z.number().max(100).nullable()), costMethod: methodSchema })
export type ProductInput = z.input<typeof productInputSchema>
export function recipePreview(lines: { quantityBase: number; lastUnitCost: number | null; weightedUnitCost: number | null }[], portions: number) {
  const missing = lines.filter((l) => l.lastUnitCost === null || l.weightedUnitCost === null).length
  const complete = lines.length > 0 && missing === 0 && portions > 0
  const last = complete ? lines.reduce((s, l) => s + l.quantityBase * l.lastUnitCost!, 0) : null
  const weighted = complete ? lines.reduce((s, l) => s + l.quantityBase * l.weightedUnitCost!, 0) : null
  return { missing, complete, last, weighted, perLast: last === null ? null : last / portions, perWeighted: weighted === null ? null : weighted / portions }
}
export function menuPreview(gross: number, tax: number, cost: number | null, target: number | null) {
  const net = gross / (1 + tax / 100)
  return { net, foodCostPct: cost === null || net === 0 ? null : cost / net * 100, margin: cost === null ? null : net - cost,
    suggestedGross: cost === null || target === null || target <= 0 ? null : cost / (target / 100) * (1 + tax / 100) }
}
export const costNumber = (n: number | null, digits = 2) => n === null ? '—' : new Intl.NumberFormat('tr-TR', { maximumFractionDigits: digits, minimumFractionDigits: digits }).format(n)
export const costMoney = (n: number | null, code: string, digits = 2) => n === null ? '—' : `${costNumber(n, digits)} ${code}`
export const sourceUnitLabel = (unit: string) => ({ GRAM: 'g', MILLILITER: 'ml', EACH: 'adet', CLOVE: 'diş' }[unit] ?? unit)
export const subrecipeCostStatusLabel = (value: Recipe['subrecipeLines'][number]['costStatus']) => ({
  READY: 'Hazır',
  MISSING_USAGE_QUANTITY: 'Kullanım miktarı eksik',
  MISSING_CHILD_YIELD: 'Alt reçete verimi eksik',
  UNIT_MISMATCH: 'Birim uyumsuz',
  CHILD_RECIPE_INACTIVE: 'Alt reçete pasif',
  CHILD_COST_INCOMPLETE: 'Alt reçete maliyeti eksik',
}[value])
const messages: Record<string, string> = {
  MENU_OPERATING_TARGET_INVALID: 'Hedef faaliyet marjı sıfırdan büyük ve 100’den küçük olmalıdır.',
  COSTING_MODULE_NOT_AVAILABLE: 'Maliyet için yiyecek-içecek modülü açık olmalıdır.', COSTING_PERMISSION_DENIED: 'Maliyet işlemi için yetkiniz yok.',
  COSTING_LOCATION_NOT_AVAILABLE: 'Lokasyon bu işletmeye ait değil.', COSTING_CURRENCY_INVALID: 'Üç harfli para birimi girin.',
  COSTING_NO_CHANGES: 'Değişiklik yapılmadı.', RECIPE_INVALID: 'Reçete alanlarını ve porsiyon sayısını kontrol edin.',
  RECIPE_LINES_INVALID: 'Malzeme miktarları pozitif ve en fazla 4 ondalık olmalıdır.',
  RECIPE_DUPLICATE: 'Bu ad veya kodla reçete zaten var.', COSTING_ITEM_NOT_AVAILABLE: 'Malzeme aktif değil veya bu işletmeye ait değil.',
  RECIPE_NOT_AVAILABLE: 'Reçete bulunamadı.', RECIPE_CURRENCY_IN_USE: 'Menüye bağlı reçetenin para birimi değiştirilemez.',
  MENU_RECIPE_CURRENCY_MISMATCH: 'Menü ürünü ve reçete aynı para biriminde olmalıdır.', MENU_PRODUCT_INVALID: 'Fiyat, vergi ve hedef alanlarını kontrol edin.',
  MENU_PRODUCT_DUPLICATE: 'Bu ad veya kodla menü ürünü zaten var.', MENU_PRODUCT_NOT_AVAILABLE: 'Menü ürünü bulunamadı.',
}
export const costingError = (message: string) => messages[message] ?? message
