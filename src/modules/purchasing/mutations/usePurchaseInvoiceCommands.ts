import { useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../../../shared/supabase/client'
import { useTenant } from '../../../shared/tenant/useTenant'
import { invoiceDraftSchema, purchaseError, type InvoiceDraftInput } from '../model/purchaseInvoices'

export function useSavePurchaseDraft() {
  const { tenantId } = useTenant()
  const client = useQueryClient()
  return useMutation({ mutationFn: async ({ invoiceId, input }: { invoiceId?: string; input: InvoiceDraftInput }) => {
    if (!tenantId) throw new Error('Aktif işletme bulunamadı.')
    const parsed = invoiceDraftSchema.safeParse(input)
    if (!parsed.success) throw new Error('Fatura alanlarını ve satırları kontrol edin.')
    const value = parsed.data
    const args = { p_tenant_id: tenantId, p_supplier_id: value.supplierId, p_invoice_number: value.invoiceNumber,
      p_invoice_date: value.invoiceDate, p_currency_code: value.currencyCode, p_lines: value.lines,
      p_location_id: value.locationId || undefined, p_due_date: value.dueDate || undefined, p_description: value.description || undefined }
    const { data, error } = invoiceId ? await supabase.rpc('update_purchase_invoice_draft', { ...args, p_invoice_id: invoiceId })
      : await supabase.rpc('create_purchase_invoice_draft', args)
    if (error) throw new Error(purchaseError(error.message))
    if (!data) throw new Error('Fatura kaydedilemedi.')
    return data
  }, onSuccess: async () => { await Promise.all(['purchase-invoice-overview', 'purchase-invoice-detail']
    .map((key) => client.invalidateQueries({ queryKey: [key, tenantId] }))) } })
}
export function usePostPurchaseInvoice() {
  const { tenantId } = useTenant()
  const client = useQueryClient()
  return useMutation({ mutationFn: async (invoiceId: string) => {
    if (!tenantId) throw new Error('Aktif işletme bulunamadı.')
    const { data, error } = await supabase.rpc('post_purchase_invoice', { p_tenant_id: tenantId, p_invoice_id: invoiceId })
    if (error) throw new Error(purchaseError(error.message))
    if (!data) throw new Error('Fatura işlenemedi.')
    return data
  }, onSuccess: async () => { await Promise.all(['purchase-invoice-overview', 'purchase-invoice-detail', 'supplier-overview']
    .map((key) => client.invalidateQueries({ queryKey: [key, tenantId] }))) } })
}
