import { z } from 'zod'
import { financeAccountTypeSchema } from './financeOverview'

export const financeAccountStatusSchema = z.enum(['ACTIVE', 'PASSIVE'])
export const financeManagedAccountSchema = z.object({
  id: z.uuid(),
  name: z.string().min(2).max(120),
  accountType: financeAccountTypeSchema,
  currencyCode: z.string().regex(/^[A-Z]{3}$/),
  status: financeAccountStatusSchema,
  locationId: z.uuid().nullable(),
  locationName: z.string().nullable(),
  balance: z.number(),
})
export const financeAccountManagementSchema = z.object({
  tenantId: z.uuid(),
  accounts: z.array(financeManagedAccountSchema),
})
export type FinanceManagedAccount = z.infer<typeof financeManagedAccountSchema>

export const createFinanceAccountSchema = z.object({
  name: z.string().trim().min(2).max(120),
  accountType: financeAccountTypeSchema,
  currencyCode: z.string().trim().toUpperCase().regex(/^[A-Z]{3}$/),
  locationId: z.uuid().nullable(),
})
export const updateFinanceAccountSchema = z.object({
  accountId: z.uuid(),
  name: z.string().trim().min(2).max(120),
  status: financeAccountStatusSchema,
})
export type CreateFinanceAccountInput = z.infer<typeof createFinanceAccountSchema>
export type UpdateFinanceAccountInput = z.infer<typeof updateFinanceAccountSchema>

const accountErrors: Record<string, string> = {
  FINANCE_ACCOUNT_NON_ZERO_BALANCE: 'Bakiyesi sıfır olmayan hesap pasife alınamaz. Önce bakiyeyi transfer veya Düzelt akışıyla sıfırlayın.',
  FINANCE_ACCOUNT_NO_CHANGES: 'Hesap bilgilerinde değişiklik yapılmadı.',
  FINANCE_ACCOUNT_NAME_EXISTS: 'Bu işletmede aynı isimde bir hesap zaten var.',
  FINANCE_ACCOUNT_NAME_INVALID: 'Hesap adı 2–120 karakter olmalıdır.',
  FINANCE_ACCOUNT_CURRENCY_INVALID: 'Para birimi üç harften oluşmalıdır (örn. TRY, USD, EUR).',
  FINANCE_ACCOUNT_TYPE_INVALID: 'Geçerli bir hesap tipi seçin.',
  FINANCE_ACCOUNT_STATUS_INVALID: 'Geçerli bir durum seçin.',
  FINANCE_ACCOUNT_NOT_AVAILABLE: 'Hesap bulunamadı veya erişiminiz yok.',
  FINANCE_LOCATION_NOT_AVAILABLE: 'Lokasyon artık aktif değil veya bu işletmeye ait değil.',
  FINANCE_WRITE_FORBIDDEN: 'Hesap yönetimi için yazma yetkiniz yok.',
  FINANCE_MODULE_NOT_AVAILABLE: 'Finans modülü kullanılamıyor.',
  AUTHENTICATION_REQUIRED: 'Lütfen tekrar oturum açın.',
}
export function financeAccountError(message: string) {
  return accountErrors[message] ?? message
}
