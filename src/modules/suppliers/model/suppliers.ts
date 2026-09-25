import { z } from 'zod'
import type { TenantContext } from '../../../core/tenant/tenantSchemas'
import { hasAccess } from '../../../core/access/accessUtils'
export { parseCashflowAmount as parseSupplierAmount } from '../../finance/model/financeCashflow'

const currency = z.string().regex(/^[A-Z]{3}$/)
export const supplierSchema = z.object({
  id: z.uuid(), name: z.string(), taxNumber: z.string().nullable(), phone: z.string().nullable(),
  email: z.string().nullable(), notes: z.string().nullable(), status: z.enum(['ACTIVE', 'PASSIVE']),
  balances: z.array(z.object({ currencyCode: currency, amount: z.number() })),
})
export const supplierOverviewSchema = z.object({
  tenantId: z.uuid(), suppliers: z.array(supplierSchema),
  recentPayments: z.array(z.object({
    id: z.uuid(), supplierId: z.uuid(), supplierName: z.string(), financeAccountId: z.uuid(),
    financeAccountName: z.string(), amount: z.number().positive(), currencyCode: currency,
    occurredAt: z.string(), description: z.string(),
  })),
})
export const supplierPaymentContextSchema = z.object({
  tenantId: z.uuid(), accounts: z.array(z.object({
    id: z.uuid(), name: z.string(), accountType: z.enum(['CASH', 'BANK']), currencyCode: currency, derivedBalance: z.number(),
  })),
})
export type Supplier = z.infer<typeof supplierSchema>
export const supplierFormSchema = z.object({
  name: z.string().transform((value) => value.replace(/\s+/g, ' ').trim()).pipe(z.string().min(2).max(160)),
  taxNumber: z.string().trim().regex(/^(?:[0-9]{10,11})?$/),
  phone: z.string().trim().max(40),
  email: z.string().trim().toLowerCase().max(254).refine((value) => !value || /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)),
  notes: z.string().trim().max(2000),
  status: z.enum(['ACTIVE', 'PASSIVE']),
})
export type SupplierFormInput = z.infer<typeof supplierFormSchema>
export function canPaySupplier(context: TenantContext | null) {
  return !!context && hasAccess(context, { requiredModule: 'suppliers', requiredPermission: 'suppliers.pay' })
    && hasAccess(context, { requiredModule: 'finance', requiredPermission: 'finance.write' })
}
export function supplierTotals(suppliers: Supplier[]) {
  const totals = new Map<string, { currencyCode: string; debt: number; advance: number }>()
  for (const supplier of suppliers) for (const balance of supplier.balances) {
    const total = totals.get(balance.currencyCode) ?? { currencyCode: balance.currencyCode, debt: 0, advance: 0 }
    if (balance.amount > 0) total.debt += balance.amount
    else total.advance -= balance.amount
    totals.set(balance.currencyCode, total)
  }
  return [...totals.values()].sort((a, b) => a.currencyCode.localeCompare(b.currencyCode))
}
export function money(amount: number, currencyCode: string) {
  return new Intl.NumberFormat('tr-TR', { style: 'currency', currency: currencyCode }).format(amount)
}
export function balanceLabel(amount: number, currencyCode: string) {
  return `${money(Math.abs(amount), currencyCode)} ${amount < 0 ? 'Avans / Alacak' : 'Borç'}`
}
const messages: Record<string, string> = {
  AUTHENTICATION_REQUIRED: 'Lütfen tekrar oturum açın.',
  SUPPLIERS_MODULE_NOT_AVAILABLE: 'Tedarikçiler modülü kullanılamıyor.',
  FINANCE_MODULE_NOT_AVAILABLE: 'Finans modülü kullanılamıyor.',
  SUPPLIER_PERMISSION_DENIED: 'Bu işlem için tedarikçi yetkiniz yok.',
  FINANCE_WRITE_FORBIDDEN: 'Ödeme için finans yazma yetkisi gerekiyor.',
  SUPPLIER_NAME_INVALID: 'Ad / Ünvan 2–160 karakter olmalıdır.',
  SUPPLIER_NAME_EXISTS: 'Bu işletmede aynı isimde bir tedarikçi zaten var.',
  SUPPLIER_TAX_NUMBER_INVALID: 'VKN/TCKN yalnızca 10 veya 11 rakamdan oluşmalıdır.',
  SUPPLIER_CONTACT_INVALID: 'İletişim bilgilerini ve uzunluk sınırlarını kontrol edin.',
  SUPPLIER_STATUS_INVALID: 'Geçerli bir durum seçin.',
  SUPPLIER_NO_CHANGES: 'Tedarikçi bilgilerinde değişiklik yapılmadı.',
  SUPPLIER_NON_ZERO_BALANCE: 'Borç veya avans bakiyesi olan tedarikçi pasife alınamaz. Tüm para birimlerinde bakiye sıfır olmalıdır.',
  SUPPLIER_NOT_AVAILABLE: 'Tedarikçi aktif değil veya bu işletmeye ait değil.',
  FINANCE_ACCOUNT_NOT_AVAILABLE: 'Finans hesabı aktif değil veya bu işletmeye ait değil.',
  SUPPLIER_PAYMENT_AMOUNT_INVALID: 'Sıfırdan büyük bir ödeme tutarı girin.',
  SUPPLIER_PAYMENT_AMOUNT_OVERFLOW: 'Ödeme tutarı izin verilen üst sınırı aşıyor.',
  SUPPLIER_PAYMENT_DESCRIPTION_INVALID: 'Açıklama 2–500 karakter olmalıdır.',
  SUPPLIER_HISTORY_IMMUTABLE: 'Ödeme ve borç hareketleri değiştirilemez veya silinemez.',
}
export function supplierError(message: string) { return messages[message] ?? message }
