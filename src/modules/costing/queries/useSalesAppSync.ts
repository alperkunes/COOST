import { useQuery } from '@tanstack/react-query'

import { supabase } from '../../../shared/supabase/client'
import { useTenant } from '../../../shared/tenant/useTenant'
import { costingError } from '../model/costing'
import { salesAppError } from '../model/salesApp'
import {
  salesAppSyncOverviewSchema,
} from '../model/salesAppSync'

export function useSalesAppSync() {
  const { tenantId } = useTenant()

  return useQuery({
    queryKey: [
      'sales-app-sync',
      tenantId,
    ],

    enabled: Boolean(tenantId),

    queryFn: async () => {
      if (!tenantId) {
        throw new Error(
          'Aktif işletme bulunamadı.',
        )
      }

      const { data, error } =
        await supabase.rpc(
          'get_sales_app_sync_overview',
          {
            p_tenant_id: tenantId,
          },
        )

      if (error) {
        throw new Error(
          costingError(
            salesAppError(
              error.message,
            ),
          ),
        )
      }

      const parsed =
        salesAppSyncOverviewSchema.parse(
          data,
        )

      if (
        parsed.tenantId !== tenantId
      ) {
        throw new Error(
          'İşletme kapsamı doğrulanamadı.',
        )
      }

      return parsed
    },
  })
}
