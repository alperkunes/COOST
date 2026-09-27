import { useQuery } from '@tanstack/react-query'
import { supabase } from '../../../shared/supabase/client'
import { useTenant } from '../../../shared/tenant/useTenant'
import { salesAppError, salesAppOverviewSchema } from '../model/salesApp'
import { costingError } from '../model/costing'

export function useSalesApp() {
  const { tenantId } = useTenant()
  return useQuery({ queryKey: ['sales-app', tenantId], enabled: !!tenantId, queryFn: async () => {
    const { data, error } = await supabase.rpc('get_sales_app_integration_overview', { p_tenant_id: tenantId! })
    if (error) throw new Error(costingError(salesAppError(error.message)))
    const parsed = salesAppOverviewSchema.parse(data)
    if (parsed.tenantId !== tenantId) throw new Error('İşletme kapsamı doğrulanamadı.')
    return parsed
  } })
}
