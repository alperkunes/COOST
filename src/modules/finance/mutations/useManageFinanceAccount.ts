import { useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../../../shared/supabase/client'
import { useTenant } from '../../../shared/tenant/useTenant'
import {
  createFinanceAccountSchema, updateFinanceAccountSchema, financeAccountError,
  type CreateFinanceAccountInput, type UpdateFinanceAccountInput,
} from '../model/financeAccountManagement'

type AccountCommand = { kind: 'create'; input: CreateFinanceAccountInput }
  | { kind: 'update'; input: UpdateFinanceAccountInput }

export function useManageFinanceAccount() {
  const { tenantId } = useTenant()
  const client = useQueryClient()
  return useMutation({
    mutationFn: async (command: AccountCommand) => {
      if (!tenantId) throw new Error('Aktif işletme bulunamadı.')
      let result
      if (command.kind === 'create') {
        const input = createFinanceAccountSchema.parse(command.input)
        result = await supabase.rpc('create_finance_account', {
          p_tenant_id: tenantId, p_name: input.name, p_account_type: input.accountType,
          p_currency_code: input.currencyCode, p_location_id: input.locationId ?? undefined,
        })
      } else {
        const input = updateFinanceAccountSchema.parse(command.input)
        result = await supabase.rpc('update_finance_account', {
          p_tenant_id: tenantId, p_account_id: input.accountId, p_name: input.name, p_status: input.status,
        })
      }
      if (result.error) throw new Error(financeAccountError(result.error.message))
      if (!result.data) throw new Error('Hesap kaydedilemedi.')
      return result.data
    },
    onSuccess: async () => {
      await Promise.all([
        client.invalidateQueries({ queryKey: ['finance-overview', tenantId] }),
        client.invalidateQueries({ queryKey: ['finance-account-management', tenantId] }),
      ])
    },
  })
}
