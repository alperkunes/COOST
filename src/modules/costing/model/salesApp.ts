import Papa from 'papaparse'
import { z } from 'zod'

export const mappingLabels = { MAPPED: 'Eşleştirildi', UNMAPPED: 'Eşleştirilmedi', IGNORED: 'Hariç Tutuldu' } as const
export const mappingStatus = z.enum(['MAPPED', 'UNMAPPED', 'IGNORED'])
export const salesSourceLabel = (source: string) => source === 'MANUAL' ? 'Manuel' : source === 'SALES_APP' ? 'Satış Uygulaması' : 'İçe Aktarım'
const currency = z.string().regex(/^[A-Z]{3}$/)
const MAX_QUANTITY = Number('999999999999.9999')
const MAX_MONEY = Number('99999999999999.99')
const mappingSchema = z.object({ id: z.uuid(), externalProductId: z.string(), externalProductCode: z.string().nullable(), externalProductName: z.string(), locationId: z.uuid().nullable(), locationName: z.string().nullable(), status: mappingStatus, menuProductId: z.uuid().nullable(), menuProductName: z.string().nullable() })
export type SalesAppMapping = z.infer<typeof mappingSchema>
export const salesAppOverviewSchema = z.object({ tenantId: z.uuid(), providerKey: z.literal('SALES_APP'),
  summary: z.object({ mappedProductCount: z.number(), unmappedProductCount: z.number(), ignoredProductCount: z.number(), lastImportAt: z.string().nullable(), lastImportBusinessDate: z.string().nullable() }),
  locations: z.array(z.object({ id: z.uuid(), name: z.string() })), menuProducts: z.array(z.object({ id: z.uuid(), name: z.string(), currencyCode: currency })), mappings: z.array(mappingSchema),
  recentImports: z.array(z.object({ id: z.uuid(), businessDate: z.iso.date(), locationId: z.uuid(), location: z.string(), currencyCode: currency, externalBatchKey: z.string(), status: z.enum(['PROCESSING', 'COMPLETED', 'FAILED']), rowCount: z.number(), mappedRowCount: z.number(), unmappedRowCount: z.number(), importedAt: z.string(), canReprocess: z.boolean() })) })
export type SalesAppOverview = z.infer<typeof salesAppOverviewSchema>
export const salesAppRowSchema = z.object({ externalProductId: z.string().trim().min(1).max(200), externalProductCode: z.string().trim().max(200).nullable(), externalProductName: z.string().trim().min(1).max(200), quantity: z.number().nonnegative().max(MAX_QUANTITY), grossSales: z.number().nonnegative().max(MAX_MONEY), netSales: z.number().nonnegative().max(MAX_MONEY) }).refine((r) => r.quantity > 0 || (r.grossSales === 0 && r.netSales === 0))
export type SalesAppRow = z.infer<typeof salesAppRowSchema>
export const salesAppImportSchema = z.object({ locationId: z.uuid(), businessDate: z.iso.date(), externalBatchKey: z.string().min(1).max(200), currencyCode: currency, rows: z.array(salesAppRowSchema).min(1).max(5000) })
export type SalesAppImport = z.infer<typeof salesAppImportSchema>
const columns = ['product_id', 'product_code', 'product_name', 'quantity', 'gross_sales', 'net_sales', 'currency']
function decimal(value: string, scale: number) {
  const v = value.trim()
  if (!new RegExp(`^\\d+(?:\\.\\d{1,${scale}})?$`).test(v) || !Number.isFinite(Number(v))) throw new Error('Miktar ve tutarlar negatif olamaz; ondalık ayırıcı nokta olmalıdır.')
  return Number(v)
}
export function normalizeSalesAppCsv(text: string): { rows: SalesAppRow[]; currencyCode: string } {
  const parsed = Papa.parse<string[]>(text.replace(/^\uFEFF/, ''), { skipEmptyLines: 'greedy' })
  if (parsed.errors.length || parsed.data.length < 2 || parsed.data.length > 5001) throw new Error('Geçerli CSV ve 1–5000 veri satırı gereklidir.')
  const headers = parsed.data[0].map((h) => h.trim())
  if (new Set(headers).size !== headers.length || columns.some((c) => !headers.includes(c)) || headers.length !== columns.length) throw new Error(`CSV kolonları: ${columns.join(', ')}`)
  const ids = new Set<string>(), currencies = new Set<string>()
  const rows = parsed.data.slice(1).map((cells, index) => {
    if (cells.length !== headers.length) throw new Error(`Satır ${index + 2}: kolon sayısı geçersiz.`)
    const r = Object.fromEntries(headers.map((h, i) => [h, cells[i].trim()]))
    currencies.add(r.currency.toUpperCase())
    const row = salesAppRowSchema.safeParse({ externalProductId: r.product_id, externalProductCode: r.product_code || null, externalProductName: r.product_name, quantity: decimal(r.quantity, 4), grossSales: decimal(r.gross_sales, 2), netSales: decimal(r.net_sales, 2) })
    if (!row.success) throw new Error(`Satır ${index + 2}: ürün, miktar veya satış tutarı geçersiz.`)
    if (ids.has(row.data.externalProductId)) throw new Error(`Yinelenen harici ürün kimliği: ${row.data.externalProductId}`)
    ids.add(row.data.externalProductId)
    return row.data
  })
  const currencyCode = [...currencies][0]
  if (currencies.size !== 1 || !currency.safeParse(currencyCode).success) throw new Error('Dosyada tek bir geçerli para birimi bulunmalıdır.')
  return { rows, currencyCode }
}
export function salesAppPreview(rows: SalesAppRow[], mappings: SalesAppMapping[], locationId: string) {
  const counts = { MAPPED: 0, UNMAPPED: 0, IGNORED: 0 }
  const resolved = rows.map((row) => {
    const matches = mappings.filter((m) => m.externalProductId === row.externalProductId)
    const mapping = matches.find((m) => m.locationId === locationId) ?? matches.find((m) => m.locationId === null)
    const status = mapping?.status ?? 'UNMAPPED'
    counts[status]++
    return { ...row, status, menuProductId: mapping?.menuProductId ?? null }
  })
  return { counts, rows: resolved }
}
export async function salesAppBatchKey(input: Omit<SalesAppImport, 'externalBatchKey'>) {
  const canonical = { locationId: input.locationId, businessDate: input.businessDate, currencyCode: input.currencyCode, rows: [...input.rows].sort((a, b) => a.externalProductId < b.externalProductId ? -1 : a.externalProductId > b.externalProductId ? 1 : 0) }
  const hash = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(JSON.stringify(canonical)))
  return `csv:${Array.from(new Uint8Array(hash), (v) => v.toString(16).padStart(2, '0')).join('')}`
}
const errors: Record<string, string> = {
  SALES_APP_IMPORT_INVALID: 'İş günü, lokasyon, batch anahtarı ve satır sayısını kontrol edin.', SALES_APP_ROW_INVALID: 'Satış satırındaki ürün, miktar veya tutar geçersiz.',
  SALES_APP_DUPLICATE_PRODUCT: 'Dosyada aynı harici ürün kimliği birden fazla kez bulunamaz.', SALES_APP_BATCH_KEY_CONFLICT: 'Bu batch anahtarı farklı bir veri için kullanılmış.',
  SALES_APP_MAPPING_INVALID: 'Eşleştirme durumunu ve menü ürününü kontrol edin.', SALES_APP_MAPPING_NOT_AVAILABLE: 'Eşleştirme bulunamadı.',
  SALES_APP_BATCH_NOT_AVAILABLE: 'İçe aktarım bulunamadı.', SALES_APP_BATCH_SUPERSEDED: 'Bu gün için daha yeni bir içe aktarım var. En son içe aktarımı yeniden işleyin.',
  SALES_APP_CURRENCY_MISMATCH: 'Eşleştirilen menü ürünü ile dosyanın para birimi aynı olmalıdır.', SALES_APP_TOTAL_OVERFLOW: 'Ürün toplamı desteklenen tutarı aşıyor.',
}
export const salesAppError = (message: string) => errors[message] ?? message
