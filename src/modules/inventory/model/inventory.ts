import { z } from 'zod'

export const units = { GRAM: 'Gram', MILLILITER: 'Mililitre', EACH: 'Adet' } as const
export const countStatusLabels = { DRAFT: 'Taslak', POSTED: 'İşlendi', CANCELLED: 'İptal Edildi' } as const
export const movementNames = { RECEIPT: 'Giriş', ISSUE: 'Çıkış', WASTE: 'Fire', COMPLIMENTARY: 'İkram', MANUAL_ADJUSTMENT: 'Manuel Düzeltme', COUNT_ADJUSTMENT: 'Sayım Farkı' } as const
export function parseQuantity(value: string, allowZero = false): number | null {
  const input = value.trim()
  if (!/^(?:\d+(?:[.,]\d{1,4})?|\d{1,3}(?:\.\d{3})+,\d{1,4})$/.test(input)) return null
  const result = Number(input.includes(',') ? input.replace(/\./g, '').replace(',', '.') : input)
  return Number.isFinite(result) && result < 1e12 && (allowZero ? result >= 0 : result > 0) ? result : null
}
export const quantityText = (value: number) => new Intl.NumberFormat('tr-TR', { maximumFractionDigits: 4 }).format(value)
export const baseUnitSchema = z.enum(['GRAM', 'MILLILITER', 'EACH'])
export const itemInputSchema = z.object({ name: z.string().trim().min(2).max(160), sku: z.string().trim().max(100), category: z.string().trim().max(120),
  baseUnit: baseUnitSchema, status: z.enum(['ACTIVE', 'PASSIVE']),
  criticalStock: z.string().transform((value) => value.trim() === '' ? null : parseQuantity(value, true) ?? NaN).pipe(z.number().nullable()),
})
export type ItemInput = z.input<typeof itemInputSchema>
export const movementInputSchema = z.object({ itemId: z.uuid(), locationId: z.uuid(),
  movementType: z.enum(['RECEIPT', 'ISSUE', 'WASTE', 'COMPLIMENTARY', 'MANUAL_ADJUSTMENT']),
  direction: z.enum(['INCREASE', 'DECREASE']), quantity: z.string().transform((value) => parseQuantity(value)).pipe(z.number()),
  description: z.string().trim().min(2).max(500),
})
export type MovementInput = z.input<typeof movementInputSchema>
export function signedQuantity(type: MovementInput['movementType'], quantity: number, direction: MovementInput['direction']) {
  return quantity * (['ISSUE', 'WASTE', 'COMPLIMENTARY'].includes(type) || (type === 'MANUAL_ADJUSTMENT' && direction === 'DECREASE') ? -1 : 1)
}
export function countDifference(counted: number, system: number) { return Number((counted - system).toFixed(4)) }
export const itemSchema = z.object({ id: z.uuid(), name: z.string(), sku: z.string().nullable(), category: z.string().nullable(), baseUnit: baseUnitSchema,
  criticalStock: z.number().nullable(), status: z.enum(['ACTIVE', 'PASSIVE']), quantity: z.number(), isCritical: z.boolean(), isNegative: z.boolean() })
export type InventoryItem = z.infer<typeof itemSchema>
const locationSchema = z.object({ id: z.uuid(), name: z.string() })
export const overviewSchema = z.object({ tenantId: z.uuid(), locationId: z.uuid().nullable(), items: z.array(itemSchema),
  locations: z.array(locationSchema.extend({ status: z.enum(['ACTIVE', 'PASSIVE']) })),
  summary: z.object({ activeItemCount: z.number(), criticalItemCount: z.number(), negativeItemCount: z.number() }),
  recentMovements: z.array(z.object({ id: z.uuid(), itemId: z.uuid(), itemName: z.string(), locationId: z.uuid(), locationName: z.string(),
    movementType: z.enum(['RECEIPT', 'ISSUE', 'WASTE', 'COMPLIMENTARY', 'MANUAL_ADJUSTMENT', 'COUNT_ADJUSTMENT']), quantity: z.number(), occurredAt: z.string(), description: z.string(), sourceType: z.string().nullable() })),
})
export const managementSchema = z.object({ tenantId: z.uuid(), items: z.array(itemSchema) })
export const contextSchema = z.object({ tenantId: z.uuid(), locations: z.array(locationSchema), items: z.array(z.object({ id: z.uuid(), name: z.string(), baseUnit: baseUnitSchema })) })
export const countsSchema = z.object({ tenantId: z.uuid(), counts: z.array(z.object({ id: z.uuid(), locationId: z.uuid(), locationName: z.string(),
  status: z.enum(['DRAFT', 'POSTED', 'CANCELLED']), countedAt: z.string(), notes: z.string().nullable(), postedAt: z.string().nullable(), cancelledAt: z.string().nullable(), cancelledBy: z.uuid().nullable() })) })
export const countDetailSchema = z.object({ tenantId: z.uuid(), id: z.uuid(), locationId: z.uuid(), status: z.enum(['DRAFT', 'POSTED', 'CANCELLED']),
  countedAt: z.string(), notes: z.string().nullable(), postedAt: z.string().nullable(), cancelledAt: z.string().nullable(), cancelledBy: z.uuid().nullable(),
  lines: z.array(z.object({ itemId: z.uuid(), itemName: z.string(), baseUnit: baseUnitSchema, systemQuantity: z.number(), countedQuantity: z.number().nullable(), difference: z.number().nullable() })) })
export type CountDetail = z.infer<typeof countDetailSchema>
const messages: Record<string, string> = {
  AUTHENTICATION_REQUIRED: 'Lütfen tekrar oturum açın.', INVENTORY_MODULE_NOT_AVAILABLE: 'Stok modülü kullanılamıyor.',
  INVENTORY_PERMISSION_DENIED: 'Bu işlem için stok yetkiniz yok.', INVENTORY_QUANTITY_INVALID: 'Miktarı en fazla 4 ondalıkla, geçerli bir pozitif sayı olarak girin.',
  INVENTORY_ITEM_INVALID: 'Stok kartı alanlarını kontrol edin.', INVENTORY_ITEM_DUPLICATE: 'Bu ad veya SKU ile bir stok kartı zaten var.',
  INVENTORY_ITEM_NOT_AVAILABLE: 'Stok kartı aktif değil veya bu işletmeye ait değil.', INVENTORY_LOCATION_NOT_AVAILABLE: 'Lokasyon kullanılamıyor.',
  INVENTORY_NONZERO_STOCK: 'Kartı pasif yapmak için tüm lokasyonlardaki stok bakiyesi sıfır olmalıdır.', INVENTORY_NO_CHANGES: 'Değişiklik yapılmadı.',
  INVENTORY_BASE_UNIT_IMMUTABLE: 'Baz birim değiştirilemez.', INVENTORY_HISTORY_IMMUTABLE: 'Stok hareketi değiştirilemez.',
  INVENTORY_MOVEMENT_INVALID: 'Hareket tipini, yönünü ve açıklamasını kontrol edin.', INVENTORY_COUNT_INVALID: 'Sayım miktarlarını kontrol edin.',
  INVENTORY_COUNT_INCOMPLETE: 'Tüm ürünler için sayılan miktarı girin.', INVENTORY_COUNT_IMMUTABLE: 'İşlenmiş veya iptal edilmiş sayım değiştirilemez.',
  INVENTORY_COUNT_ALREADY_OPEN: 'Bu lokasyonda açık bir taslak sayım var. Mevcut sayımı açın veya iptal edin.',
  INVENTORY_COUNT_NOT_AVAILABLE: 'Sayım bulunamadı.', INVENTORY_ITEMS_REQUIRED: 'Sayım için en az bir aktif stok kartı gerekir.',
}
export function inventoryError(message: string) { return messages[message] ?? message }
