import { useQuery } from '@tanstack/react-query'
import { z } from 'zod'
import { supabase } from '../../../shared/supabase/client'
import { useTenant } from '../../../shared/tenant/useTenant'
import { financeAccountManagementSchema } from '../model/financeAccountManagement'

export function useFinanceAccountManagement() {
  const { tenantId } = useTenant()
  return useQuery({
    queryKey: ['finance-account-management', tenantId],
    enabled: Boolean(tenantId),
    queryFn: async () => {
      if (!tenantId) throw new Error('Aktif işletme bulunamadı.')
      const { data, error } = await supabase.rpc('get_finance_account_management', { p_tenant_id: tenantId })
      if (error) throw new Error(error.message)
      const parsed = financeAccountManagementSchema.safeParse(data)
      if (!parsed.success || parsed.data.tenantId !== tenantId) throw new Error('Hesap yönetimi verileri doğrulanamadı.')
      return parsed.data
    },
  })
}

const locationsSchema = z.array(z.object({ id: z.uuid(), name: z.string() }))
export function useFinanceAccountLocations() {
  const { tenantId } = useTenant()
  return useQuery({
    queryKey: ['finance-account-locations', tenantId],
    enabled: Boolean(tenantId),
    queryFn: async () => {
      if (!tenantId) throw new Error('Aktif işletme bulunamadı.')
      // Read only: existing membership RLS limits visible locations.
      const { data, error } = await supabase.from('locations').select('id, name')
        .eq('tenant_id', tenantId).eq('status', 'ACTIVE').order('name')
      if (error) throw new Error(error.message)
      return locationsSchema.parse(data)
    },
  })
}
