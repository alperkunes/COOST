import { z } from 'zod'

export function parseInvoiceNumber(value: string, decimals = 4, allowZero = false): number | null {
  const input = value.trim()
  const pattern = new RegExp(`^(?:\\d+(?:[.,]\\d{1,${decimals}})?|\\d{1,3}(?:\\.\\d{3})+,\\d{1,${decimals}})$`)
  if (!pattern.test(input)) return null
  const number = Number(input.includes(',') ? input.replace(/\./g, '').replace(',', '.') : input)
  return Number.isFinite(number) && (allowZero ? number >= 0 : number > 0) && number < 1e12 ? number : null
}
const decimal = (digits: number, zero = false) => z.string().transform((value) => parseInvoiceNumber(value, digits, zero)).pipe(z.number())
export const invoiceLineInputSchema = z.object({
  description: z.string().trim().min(2).max(300), supplierProductCode: z.string().trim().max(100),
  unit: z.string().trim().min(1).max(30), quantity: decimal(4), unitPrice: decimal(4, true),
  priceIncludesTax: z.boolean(), taxRate: decimal(3, true).pipe(z.number().max(100)), inventoryItemId: z.uuid().nullable(),
})
export type InvoiceLineInput = z.input<typeof invoiceLineInputSchema>
export type CalculatedLineInput = z.output<typeof invoiceLineInputSchema>
export const invoiceDraftSchema = z.object({
  supplierId: z.uuid(), locationId: z.union([z.uuid(), z.literal('')]), invoiceNumber: z.string().trim().min(1).max(100),
  invoiceDate: z.iso.date(), dueDate: z.union([z.iso.date(), z.literal('')]), currencyCode: z.string().trim().toUpperCase().regex(/^[A-Z]{3}$/),
  description: z.string().trim().max(2000), lines: z.array(invoiceLineInputSchema).min(1).max(200),
}).refine((value) => !value.dueDate || value.dueDate >= value.invoiceDate, { message: 'Vade tarihi fatura tarihinden önce olamaz.', path: ['dueDate'] })
export type InvoiceDraftInput = z.input<typeof invoiceDraftSchema>
export function emptyInvoiceLine(): InvoiceLineInput {
  return { description: '', supplierProductCode: '', unit: 'adet', quantity: '1', unitPrice: '', priceIncludesTax: false, taxRate: '20', inventoryItemId: null }
}
// Integer arithmetic mirrors PostgreSQL numeric rounding; preview only, server is authoritative.
export function invoiceLineMath(line: CalculatedLineInput) {
  const scaled = (value: number, places: number) => BigInt(value.toFixed(places).replace('.', ''))
  const round = (n: bigint, d: bigint) => (n + d / 2n) / d
  const base = round(scaled(line.quantity, 4) * scaled(line.unitPrice, 4), 1000000n)
  const rate = scaled(line.taxRate, 3)
  const net = line.priceIncludesTax ? round(base * 100000n, 100000n + rate) : base
  const tax = line.priceIncludesTax ? base - net : round(net * rate, 100000n)
  return { netAmount: Number(net) / 100, taxAmount: Number(tax) / 100, grossAmount: Number(net + tax) / 100 }
}
export const invoiceHeaderSchema = z.object({
  id: z.uuid(), supplierId: z.uuid(), supplierName: z.string(), locationId: z.uuid().nullable(), locationName: z.string().nullable(),
  invoiceNumber: z.string(), invoiceDate: z.iso.date(), dueDate: z.iso.date().nullable(), currencyCode: z.string().regex(/^[A-Z]{3}$/),
  status: z.enum(['DRAFT', 'POSTED']), subtotal: z.number(), taxTotal: z.number(), grandTotal: z.number(),
  description: z.string().nullable(), lineCount: z.number().int(), postedAt: z.string().nullable(),
})
export type InvoiceHeader = z.infer<typeof invoiceHeaderSchema>
const lineSchema = z.object({
  id: z.uuid(), lineNo: z.number().int(), description: z.string(), supplierProductCode: z.string().nullable(), unit: z.string(),
  quantity: z.number(), unitPrice: z.number(), priceIncludesTax: z.boolean(), taxRate: z.number(),
  netAmount: z.number(), taxAmount: z.number(), grossAmount: z.number(), inventoryItemId: z.uuid().nullable(),
})
export const invoiceOverviewSchema = z.object({
  tenantId: z.uuid(), summary: z.object({ draftCount: z.number(), postedCount: z.number(),
    postedTotals: z.array(z.object({ currencyCode: z.string(), amount: z.number() })) }), invoices: z.array(invoiceHeaderSchema),
})
export const invoiceDetailSchema = z.object({ tenantId: z.uuid(), invoice: invoiceHeaderSchema, lines: z.array(lineSchema) })
export type InvoiceDetail = z.infer<typeof invoiceDetailSchema>
export const invoiceContextSchema = z.object({ tenantId: z.uuid(),
  suppliers: z.array(z.object({ id: z.uuid(), name: z.string() })), locations: z.array(z.object({ id: z.uuid(), name: z.string() })),
})
export function invoiceFormFromDetail(detail: InvoiceDetail): InvoiceDraftInput {
  return { supplierId: detail.invoice.supplierId, locationId: detail.invoice.locationId ?? '', invoiceNumber: detail.invoice.invoiceNumber,
    invoiceDate: detail.invoice.invoiceDate, dueDate: detail.invoice.dueDate ?? '', currencyCode: detail.invoice.currencyCode,
    description: detail.invoice.description ?? '', lines: detail.lines.map((line) => ({ ...line, supplierProductCode: line.supplierProductCode ?? '',
      quantity: String(line.quantity), unitPrice: String(line.unitPrice), taxRate: String(line.taxRate) })) }
}
const messages: Record<string, string> = {
  AUTHENTICATION_REQUIRED: 'Lütfen tekrar oturum açın.', PURCHASING_MODULE_NOT_AVAILABLE: 'Satınalma modülü kullanılamıyor.',
  PURCHASING_PERMISSION_DENIED: 'Bu işlem için satınalma yetkiniz yok.', SUPPLIERS_MODULE_NOT_AVAILABLE: 'Tedarikçiler modülü açık olmalıdır.',
  PURCHASE_INVOICE_NOT_AVAILABLE: 'Fatura bulunamadı veya bu işletmeye ait değil.', SUPPLIER_NOT_AVAILABLE: 'Tedarikçi aktif değil veya bu işletmeye ait değil.',
  PURCHASE_LOCATION_NOT_AVAILABLE: 'Lokasyon aktif değil veya bu işletmeye ait değil.', PURCHASE_HEADER_INVALID: 'Fatura başlık bilgilerini kontrol edin.',
  PURCHASE_DATES_INVALID: 'Tarihleri kontrol edin; vade fatura tarihinden önce olamaz.', PURCHASE_CURRENCY_INVALID: 'Para birimi üç harf olmalıdır (TRY, EUR).',
  PURCHASE_LINE_INVALID: 'Satır bilgilerini kontrol edin. Miktar pozitif, birim fiyat sıfır veya pozitif, KDV %0–100 olmalıdır.',
  PURCHASE_LINES_REQUIRED: 'Faturada 1–200 satır olmalıdır.', PURCHASE_AMOUNT_OVERFLOW: 'Fatura tutarı izin verilen sınırı aşıyor.',
  PURCHASE_INVOICE_NUMBER_EXISTS: 'Bu tedarikçi için aynı fatura numarası zaten var.', PURCHASE_INVOICE_NO_CHANGES: 'Faturada değişiklik yapılmadı.',
  PURCHASE_INVOICE_IMMUTABLE: 'İşlenmiş fatura değiştirilemez.', PURCHASE_INVOICE_ALREADY_POSTED: 'Bu fatura zaten işlenmiş.',
  PURCHASE_INVOICE_TOTAL_MUST_BE_POSITIVE: 'Faturayı işlemek için genel toplam sıfırdan büyük olmalıdır.',
}
export function purchaseError(message: string) { return messages[message] ?? message }
export function invoiceMoney(amount: number, currencyCode: string) {
  return new Intl.NumberFormat('tr-TR', { style: 'currency', currency: /^[A-Z]{3}$/.test(currencyCode) ? currencyCode : 'TRY' }).format(amount)
}
