import { useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../../../shared/supabase/client'
import { useTenant } from '../../../shared/tenant/useTenant'
import { parseCashflowAmount, type FinanceCashflowType } from '../model/financeCashflow'

type CreateFinanceCashflowInput = {
  accountId: string
  transactionType: FinanceCashflowType
  amount: number
  description: string
}

export function useCreateFinanceCashflow() {
  const { tenantId } = useTenant()
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async ({ accountId, transactionType, amount, description }: CreateFinanceCashflowInput) => {
      if (!tenantId) throw new Error('Aktif işletme bulunamadı.')
      if (!accountId) throw new Error('Hesap seçin.')
      if (transactionType !== 'INCOME' && transactionType !== 'EXPENSE') throw new Error('Geçerli bir işlem türü seçin.')
      if (parseCashflowAmount(String(amount)) === null) throw new Error('Geçerli, pozitif ve en fazla iki ondalıklı bir tutar girin.')
      const cleanDescription = description.trim()
      if (cleanDescription.length < 2 || cleanDescription.length > 500) throw new Error('Açıklama 2 ile 500 karakter arasında olmalıdır.')
      const { data, error } = await supabase.rpc('create_finance_cashflow', {
        p_tenant_id: tenantId,
        p_account_id: accountId,
        p_transaction_type: transactionType,
        p_amount: amount,
        p_description: cleanDescription,
      })
      if (error) throw new Error(error.message)
      if (!data) throw new Error('Gelir / gider oluşturulamadı.')
      return data
    },
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ['finance-overview', tenantId] })
    },
  })
}
