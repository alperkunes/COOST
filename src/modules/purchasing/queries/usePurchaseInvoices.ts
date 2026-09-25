import { useQuery } from '@tanstack/react-query'
import { supabase } from '../../../shared/supabase/client'
import { useTenant } from '../../../shared/tenant/useTenant'
import { invoiceOverviewSchema, invoiceDetailSchema, invoiceContextSchema, purchaseError } from '../model/purchaseInvoices'

export function usePurchaseInvoiceOverview() {
  const { tenantId } = useTenant()
  return useQuery({ queryKey: ['purchase-invoice-overview', tenantId], enabled: !!tenantId, queryFn: async () => {
    if (!tenantId) throw new Error('Aktif işletme bulunamadı.')
    const { data, error } = await supabase.rpc('get_purchase_invoice_overview', { p_tenant_id: tenantId, p_recent_limit: 50 })
    if (error) throw new Error(purchaseError(error.message))
    const parsed = invoiceOverviewSchema.safeParse(data)
    if (!parsed.success || parsed.data.tenantId !== tenantId) throw new Error('Fatura özeti doğrulanamadı.')
    return parsed.data
  } })
}
export function usePurchaseInvoiceDetail(invoiceId: string) {
  const { tenantId } = useTenant()
  return useQuery({ queryKey: ['purchase-invoice-detail', tenantId, invoiceId], enabled: !!tenantId && !!invoiceId, queryFn: async () => {
    if (!tenantId) throw new Error('Aktif işletme bulunamadı.')
    const { data, error } = await supabase.rpc('get_purchase_invoice_detail', { p_tenant_id: tenantId, p_invoice_id: invoiceId })
    if (error) throw new Error(purchaseError(error.message))
    const parsed = invoiceDetailSchema.safeParse(data)
    if (!parsed.success || parsed.data.tenantId !== tenantId || parsed.data.invoice.id !== invoiceId) throw new Error('Fatura detayı doğrulanamadı.')
    return parsed.data
  } })
}
export function usePurchaseInvoiceContext(enabled: boolean) {
  const { tenantId } = useTenant()
  return useQuery({ queryKey: ['purchase-invoice-context', tenantId], enabled: !!tenantId && enabled, queryFn: async () => {
    if (!tenantId) throw new Error('Aktif işletme bulunamadı.')
    const { data, error } = await supabase.rpc('get_purchase_invoice_context', { p_tenant_id: tenantId })
    if (error) throw new Error(purchaseError(error.message))
    const parsed = invoiceContextSchema.safeParse(data)
    if (!parsed.success || parsed.data.tenantId !== tenantId) throw new Error('Tedarikçi ve lokasyon bilgileri doğrulanamadı.')
    return parsed.data
  } })
}
