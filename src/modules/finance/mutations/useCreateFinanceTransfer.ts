import { useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../../../shared/supabase/client'
import { useTenant } from '../../../shared/tenant/useTenant'
import type { FinanceOverviewAccount } from '../model/financeOverview'
import { canTransferBetween } from '../model/financeTransfer'

type CreateFinanceTransferInput = {
  fromAccount: FinanceOverviewAccount
  toAccount: FinanceOverviewAccount
  amount: number
  description: string
}

export function useCreateFinanceTransfer() {
  const { tenantId } = useTenant()
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async ({ fromAccount, toAccount, amount, description }: CreateFinanceTransferInput) => {
      if (!tenantId) throw new Error('Aktif işletme bulunamadı.')
      if (!canTransferBetween(fromAccount, toAccount)) {
        throw new Error('Aynı para biriminde iki farklı hesap seçin.')
      }
      if (!Number.isFinite(amount) || amount <= 0 || amount >= 100000000000000 || Math.abs(amount * 100 - Math.round(amount * 100)) > 0.001) {
        throw new Error('Geçerli, pozitif ve en fazla iki ondalıklı bir tutar girin.')
      }
      const cleanDescription = description.trim()
      if (cleanDescription.length < 2 || cleanDescription.length > 500) {
        throw new Error('Açıklama 2 ile 500 karakter arasında olmalıdır.')
      }
      const { data, error } = await supabase.rpc('create_finance_transfer', {
        p_tenant_id: tenantId,
        p_from_account_id: fromAccount.id,
        p_to_account_id: toAccount.id,
        p_amount: amount,
        p_description: cleanDescription,
      })
      if (error) throw new Error(error.message)
      if (!data) throw new Error('Transfer oluşturulamadı.')
      return data
    },
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ['finance-overview', tenantId] })
    },
  })
}
