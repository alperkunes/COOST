import { useQuery } from '@tanstack/react-query'
import { supabase } from '../../../shared/supabase/client'
import { useTenant } from '../../../shared/tenant/useTenant'
import { supplierOverviewSchema, supplierPaymentContextSchema, supplierError } from '../model/suppliers'

export function useSupplierOverview() {
  const { tenantId } = useTenant()
  return useQuery({
    queryKey: ['supplier-overview', tenantId], enabled: !!tenantId,
    queryFn: async () => {
      if (!tenantId) throw new Error('Aktif işletme bulunamadı.')
      const { data, error } = await supabase.rpc('get_supplier_overview', { p_tenant_id: tenantId, p_recent_limit: 20 })
      if (error) throw new Error(supplierError(error.message))
      const parsed = supplierOverviewSchema.safeParse(data)
      if (!parsed.success || parsed.data.tenantId !== tenantId) throw new Error('Tedarikçi verileri doğrulanamadı.')
      return parsed.data
    },
  })
}
export function useSupplierPaymentContext() {
  const { tenantId } = useTenant()
  return useQuery({
    queryKey: ['supplier-payment-context', tenantId], enabled: !!tenantId,
    queryFn: async () => {
      if (!tenantId) throw new Error('Aktif işletme bulunamadı.')
      const { data, error } = await supabase.rpc('get_supplier_payment_context', { p_tenant_id: tenantId })
      if (error) throw new Error(supplierError(error.message))
      const parsed = supplierPaymentContextSchema.safeParse(data)
      if (!parsed.success || parsed.data.tenantId !== tenantId) throw new Error('Ödeme hesapları doğrulanamadı.')
      return parsed.data
    },
  })
}
