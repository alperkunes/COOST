import { useQuery } from '@tanstack/react-query'
import { supabase } from '../../../shared/supabase/client'
import { useTenant } from '../../../shared/tenant/useTenant'
import {
  financeOverviewSchema,
  type FinanceOverview,
} from '../model/financeOverview'

export function useFinanceOverview() {
  const { tenantId } = useTenant()

  return useQuery<FinanceOverview>({
    queryKey: ['finance-overview', tenantId],
    enabled: Boolean(tenantId),
    queryFn: async () => {
      if (!tenantId) {
        throw new Error('Tenant id is required')
      }

      const { data, error } = await supabase.rpc(
        'get_finance_overview',
        {
          p_tenant_id: tenantId,
          p_recent_limit: 20,
        },
      )

      if (error) {
        throw error
      }

      const parsed =
        financeOverviewSchema.safeParse(data)

      if (!parsed.success) {
        console.error(
          'Invalid finance overview payload',
          parsed.error,
        )

        throw new Error(
          'Finans özeti sunucudan beklenmeyen formatta döndü.',
        )
      }

      if (parsed.data.tenantId !== tenantId) {
        throw new Error(
          'Finans özeti aktif işletme ile eşleşmiyor.',
        )
      }

      return parsed.data
    },
  })
}