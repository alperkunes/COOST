import { z } from 'zod'
import { parseQuantity } from '../../inventory/model/inventory'

export const allocationLabels = { NET_SALES: 'Net Satış Tutarına Göre', QUANTITY: 'Satış Adedine Göre', EQUAL: 'Eşit' } as const
export const expenseLabels = { FIXED_OVERHEAD: 'Sabit Gider', LABOR: 'Personel', POS_COMMISSION: 'POS Komisyonu', OTHER_VARIABLE: 'Diğer Değişken Gider' } as const
export const allocationSchema = z.enum(['NET_SALES', 'QUANTITY', 'EQUAL'])
const category = z.enum(['FIXED_OVERHEAD', 'LABOR', 'POS_COMMISSION', 'OTHER_VARIABLE'])
const currency = z.string().trim().toUpperCase().regex(/^[A-Z]{3}$/)
const nullable = z.number().nullable()
export const periodSchema = z.object({ startDate: z.iso.date(), endDate: z.iso.date(), currencyCode: currency, locationId: z.union([z.uuid(), z.literal('')]), allocationMethod: allocationSchema })
  .refine((v) => v.endDate >= v.startDate && (Date.parse(v.endDate) - Date.parse(v.startDate)) / 86400000 <= 365)
export type Period = z.infer<typeof periodSchema>
const decimal = (digits: number, zero = false) => z.string().transform((v) => parseQuantity(v, zero, digits)).pipe(z.number())
export const salesInputSchema = z.object({ saleDate: z.iso.date(), locationId: z.uuid(), productId: z.uuid(), quantity: decimal(4, true), grossSales: decimal(2, true), netSales: decimal(2, true) })
  .refine((v) => v.quantity > 0 || (v.grossSales === 0 && v.netSales === 0))
export type SalesInput = z.input<typeof salesInputSchema>
export const expenseInputSchema = z.object({ occurredOn: z.iso.date(), locationId: z.union([z.uuid(), z.literal('')]), currencyCode: currency, category, amount: decimal(2), description: z.string().trim().min(2).max(500) })
export type ExpenseInput = z.input<typeof expenseInputSchema>
export const salesFactSchema = z.object({ id: z.uuid(), saleDate: z.iso.date(), locationId: z.uuid(), productId: z.uuid(), productName: z.string(), currencyCode: currency,
  quantity: z.number(), grossSales: z.number(), netSales: z.number(), sourceType: z.enum(['MANUAL', 'SALES_APP', 'IMPORT']) })
export type SalesFact = z.infer<typeof salesFactSchema>
export const expenseSchema = z.object({ id: z.uuid(), locationId: z.uuid().nullable(), occurredOn: z.iso.date(), currencyCode: currency, category, amount: z.number(), description: z.string(),
  sourceType: z.enum(['MANUAL', 'FINANCE', 'STAFF', 'POS']), status: z.enum(['ACTIVE', 'VOID']) })
export type Expense = z.infer<typeof expenseSchema>
const scope = { tenantId: z.uuid(), startDate: z.iso.date(), endDate: z.iso.date(), currencyCode: currency, locationId: z.uuid().nullable() }
export const operatingDataSchema = z.object({ ...scope, locations: z.array(z.object({ id: z.uuid(), name: z.string() })), products: z.array(z.object({ id: z.uuid(), name: z.string(), currencyCode: currency })), sales: z.array(salesFactSchema), expenses: z.array(expenseSchema) })
export type OperatingData = z.infer<typeof operatingDataSchema>
export const operatingProductSchema = z.object({ productId: z.uuid(), productName: z.string(), category: z.string().nullable(), quantitySold: z.number(), grossSales: z.number(), netSales: z.number(),
  recipeCostMethod: z.enum(['LAST_PURCHASE', 'WEIGHTED_PURCHASE']), recipeCostPerPortion: nullable, costingComplete: z.boolean(), estimatedRecipeCost: nullable, directContribution: nullable, directContributionPct: nullable,
  allocationWeight: nullable, allocatedFixedOverhead: nullable, allocatedLabor: nullable, allocatedPosCommission: nullable, allocatedOtherVariable: nullable, allocatedOperatingCost: nullable,
  allocatedOperatingContribution: nullable, allocatedOperatingMarginPct: nullable, allocatedOperatingCostPerUnit: nullable, targetOperatingMarginPct: nullable, targetDifferencePp: nullable, suggestedNetPriceAtTarget: nullable, suggestedGrossPriceAtTarget: nullable })
export type OperatingProduct = z.infer<typeof operatingProductSchema>
export const profitabilitySchema = z.object({ ...scope, allocationMethod: allocationSchema, allocationStatus: z.enum(['READY', 'NO_SALES', 'ZERO_ALLOCATION_BASE']),
  summary: z.object({ totalQuantity: z.number(), grossSales: z.number(), netSales: z.number(), estimatedRecipeCost: nullable, directContribution: nullable,
    operatingCosts: z.object({ fixedOverhead: z.number(), labor: z.number(), posCommission: z.number(), otherVariable: z.number(), total: z.number() }), allocatedOperatingContribution: nullable, allocatedOperatingMarginPct: nullable }), products: z.array(operatingProductSchema) })
const messages: Record<string, string> = { MENU_SALES_INVALID: 'Satış miktarı ve tutarlarını kontrol edin. Sıfır adet için satış tutarı sıfır olmalıdır.', MENU_SALES_SOURCE_LOCKED: 'Bu satış kaydı dış kaynaktan geliyor ve manuel değiştirilemez.',
  OPERATING_PERIOD_INVALID: 'Başlangıç ve bitiş sırasını kontrol edin; dönem en fazla 366 gün olabilir.', OPERATING_ALLOCATION_INVALID: 'Gider dağıtım yöntemi geçersiz.',
  OPERATING_COST_INVALID: 'Pozitif gider tutarı, tarih, para birimi ve açıklamayı kontrol edin.', OPERATING_COST_NOT_AVAILABLE: 'Gider kaydı bulunamadı.', OPERATING_COST_IMMUTABLE: 'İptal edilmiş veya dış kaynaklı gider değiştirilemez.' }
export const operatingError = (message: string) => messages[message] ?? message
