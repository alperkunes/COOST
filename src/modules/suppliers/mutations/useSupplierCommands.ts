import { useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../../../shared/supabase/client'
import { useTenant } from '../../../shared/tenant/useTenant'
import { supplierFormSchema, supplierError, parseSupplierAmount, type SupplierFormInput } from '../model/suppliers'

export function useSaveSupplier() {
  const { tenantId } = useTenant()
  const client = useQueryClient()
  return useMutation({
    mutationFn: async ({ supplierId, input }: { supplierId?: string; input: SupplierFormInput }) => {
      if (!tenantId) throw new Error('Aktif işletme bulunamadı.')
      const parsed = supplierFormSchema.safeParse(input)
      if (!parsed.success) throw new Error('Tedarikçi alanlarını kontrol edin.')
      const value = parsed.data
      const args = { p_tenant_id: tenantId, p_name: value.name, p_tax_number: value.taxNumber,
        p_phone: value.phone, p_email: value.email, p_notes: value.notes }
      const { data, error } = supplierId
        ? await supabase.rpc('update_supplier', { ...args, p_supplier_id: supplierId, p_status: value.status })
        : await supabase.rpc('create_supplier', args)
      if (error) throw new Error(supplierError(error.message))
      if (!data) throw new Error('Tedarikçi kaydedilemedi.')
      return data
    },
    onSuccess: async () => { await client.invalidateQueries({ queryKey: ['supplier-overview', tenantId] }) },
  })
}
export function useCreateSupplierPayment() {
  const { tenantId } = useTenant()
  const client = useQueryClient()
  return useMutation({
    mutationFn: async (input: { supplierId: string; financeAccountId: string; amount: number; description: string }) => {
      if (!tenantId) throw new Error('Aktif işletme bulunamadı.')
      if (!input.supplierId || !input.financeAccountId) throw new Error('Tedarikçi ve ödeme hesabı seçin.')
      if (parseSupplierAmount(String(input.amount)) === null) throw new Error('Pozitif, en fazla iki ondalıklı tutar girin.')
      const description = input.description.trim()
      if (description.length < 2 || description.length > 500) throw new Error('Açıklama 2–500 karakter olmalıdır.')
      const { data, error } = await supabase.rpc('create_supplier_payment', {
        p_tenant_id: tenantId, p_supplier_id: input.supplierId, p_finance_account_id: input.financeAccountId,
        p_amount: input.amount, p_description: description,
      })
      if (error) throw new Error(supplierError(error.message))
      if (!data) throw new Error('Ödeme kaydedilemedi.')
      return data
    },
    onSuccess: async () => {
      await Promise.all(['supplier-overview', 'supplier-payment-context', 'finance-overview']
        .map((key) => client.invalidateQueries({ queryKey: [key, tenantId] })))
    },
  })
}
