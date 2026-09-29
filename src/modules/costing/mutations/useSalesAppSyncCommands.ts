import {
  useMutation,
  useQueryClient,
} from '@tanstack/react-query'

import { supabase } from '../../../shared/supabase/client'
import { useTenant } from '../../../shared/tenant/useTenant'
import { costingError } from '../model/costing'
import {
  salesAppConnectionCreateSchema,
  salesAppConnectionUpdateSchema,
  salesAppSyncCommandError,
  salesAppSyncFailureSchema,
  salesAppSyncRequestSchema,
  salesAppSyncResultSchema,
  type SalesAppConnectionCreate,
  type SalesAppConnectionUpdate,
  type SalesAppSyncRequest,
} from '../model/salesAppSync'

async function functionErrorMessage(
  error: unknown,
) {
  if (
    error &&
    typeof error === 'object' &&
    'context' in error
  ) {
    const context = (
      error as {
        context?: unknown
      }
    ).context

    if (
      typeof Response !== 'undefined' &&
      context instanceof Response
    ) {
      try {
        const body =
          await context.clone().json()

        const parsed =
          salesAppSyncFailureSchema.safeParse(
            body,
          )

        if (parsed.success) {
          return parsed.data.error.message
        }
      } catch {
        // Fall back to the SDK error below.
      }
    }
  }

  if (
    error instanceof Error &&
    error.message
  ) {
    return error.message
  }

  return 'Senkronizasyon tamamlanamadı.'
}

function commandError(message: string) {
  return costingError(
    salesAppSyncCommandError(message),
  )
}

export function useCreateSalesAppConnection() {
  const { tenantId } = useTenant()
  const client = useQueryClient()

  return useMutation({
    mutationFn: async (
      input: SalesAppConnectionCreate,
    ) => {
      if (!tenantId) {
        throw new Error(
          'Aktif işletme bulunamadı.',
        )
      }

      const value =
        salesAppConnectionCreateSchema.parse(
          input,
        )

      const adapterKey =
        value.adapterKey
          .trim()
          .toUpperCase()

      const externalLocationId =
        value.externalLocationId.trim()

      const { data, error } =
        await supabase.rpc(
          'create_sales_app_connection',
          {
            p_tenant_id: tenantId,
            p_location_id:
              value.locationId,
            p_adapter_key:
              adapterKey || undefined,
            p_external_location_id:
              externalLocationId || undefined,
            p_sync_lookback_days:
              value.syncLookbackDays,
          },
        )

      if (error) {
        throw new Error(
          commandError(error.message),
        )
      }

      if (!data) {
        throw new Error(
          'Bağlantı oluşturulamadı.',
        )
      }

      return data
    },

    onSuccess: async () => {
      await client.invalidateQueries({
        queryKey: [
          'sales-app-sync',
          tenantId,
        ],
      })
    },
  })
}

export function useUpdateSalesAppConnection() {
  const { tenantId } = useTenant()
  const client = useQueryClient()

  return useMutation({
    mutationFn: async (
      input: SalesAppConnectionUpdate,
    ) => {
      if (!tenantId) {
        throw new Error(
          'Aktif işletme bulunamadı.',
        )
      }

      const value =
        salesAppConnectionUpdateSchema.parse(
          input,
        )

      const adapterKey =
        value.adapterKey
          .trim()
          .toUpperCase()

      const externalLocationId =
        value.externalLocationId.trim()

      const { data, error } =
        await supabase.rpc(
          'update_sales_app_connection',
          {
            p_tenant_id: tenantId,
            p_connection_id:
              value.connectionId,
            p_adapter_key:
              adapterKey,
            p_external_location_id:
              externalLocationId,
            p_status:
              value.status,
            p_sync_enabled:
              value.syncEnabled,
            p_sync_lookback_days:
              value.syncLookbackDays,
          },
        )

      if (error) {
        throw new Error(
          commandError(error.message),
        )
      }

      if (!data) {
        throw new Error(
          'Bağlantı güncellenemedi.',
        )
      }

      return data
    },

    onSuccess: async () => {
      await client.invalidateQueries({
        queryKey: [
          'sales-app-sync',
          tenantId,
        ],
      })
    },
  })
}

export function useRunSalesAppSync() {
  const { tenantId } = useTenant()
  const client = useQueryClient()

  return useMutation({
    mutationFn: async (
      input: SalesAppSyncRequest,
    ) => {
      if (!tenantId) {
        throw new Error(
          'Aktif işletme bulunamadı.',
        )
      }

      const request =
        salesAppSyncRequestSchema.parse(
          input,
        )

      const { data, error } =
        await supabase.functions.invoke(
          'sales-app-sync',
          {
            body: {
              tenantId,
              connectionId:
                request.connectionId,
              businessDateStart:
                request.businessDateStart,
              businessDateEnd:
                request.businessDateEnd,
            },
          },
        )

      if (error) {
        throw new Error(
          await functionErrorMessage(
            error,
          ),
        )
      }

      const failure =
        salesAppSyncFailureSchema.safeParse(
          data,
        )

      if (failure.success) {
        throw new Error(
          failure.data.error.message,
        )
      }

      const result =
        salesAppSyncResultSchema.safeParse(
          data,
        )

      if (!result.success) {
        throw new Error(
          'Senkronizasyon yanıtı doğrulanamadı.',
        )
      }

      return result.data
    },

    onSuccess: async () => {
      await Promise.all([
        client.invalidateQueries({
          queryKey: [
            'sales-app',
            tenantId,
          ],
        }),
        client.invalidateQueries({
          queryKey: [
            'operating-data',
            tenantId,
          ],
        }),
        client.invalidateQueries({
          queryKey: [
            'operating-profitability',
            tenantId,
          ],
        }),
      ])
    },

    onSettled: async () => {
      await client.invalidateQueries({
        queryKey: [
          'sales-app-sync',
          tenantId,
        ],
      })
    },
  })
}
