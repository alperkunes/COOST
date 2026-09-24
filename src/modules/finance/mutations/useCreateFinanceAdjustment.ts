import {
  useMutation,
  useQueryClient,
} from '@tanstack/react-query'
import { supabase } from '../../../shared/supabase/client'
import { useTenant } from '../../../shared/tenant/useTenant'

type CreateFinanceAdjustmentInput = {
  accountId: string
  amount: number
  description: string
  occurredAt?: string
}

export function useCreateFinanceAdjustment() {
  const { tenantId } = useTenant()
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async ({
      accountId,
      amount,
      description,
      occurredAt,
    }: CreateFinanceAdjustmentInput) => {
      if (!tenantId) {
        throw new Error(
          'Aktif işletme bulunamadı.',
        )
      }

      if (!Number.isFinite(amount) || amount === 0) {
        throw new Error(
          'Düzeltme tutarı sıfırdan farklı olmalıdır.',
        )
      }

      const cleanDescription = description.trim()

      if (
        cleanDescription.length < 2 ||
        cleanDescription.length > 500
      ) {
        throw new Error(
          'Açıklama 2 ile 500 karakter arasında olmalıdır.',
        )
      }

      const args = {
        p_tenant_id: tenantId,
        p_account_id: accountId,
        p_amount: amount,
        p_description: cleanDescription,
        ...(occurredAt
          ? { p_occurred_at: occurredAt }
          : {}),
      }

      const { data, error } = await supabase.rpc(
        'create_finance_adjustment',
        args,
      )

      if (error) {
        throw error
      }

      if (!data) {
        throw new Error(
          'Finans düzeltmesi oluşturulamadı.',
        )
      }

      return data
    },

    onSuccess: async () => {
      await queryClient.invalidateQueries({
        queryKey: ['finance-overview', tenantId],
      })
    },
  })
}