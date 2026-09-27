import { useQuery } from '@tanstack/react-query'
import { useTenant } from '../../../shared/tenant/useTenant'
import { supabase } from '../../../shared/supabase/client'
import { costingError } from '../model/costing'
import { operatingError, periodSchema, profitabilitySchema, operatingDataSchema, type Period } from '../model/operating'

export function useOperating(period: Period) {
  const { tenantId } = useTenant()
  const valid = periodSchema.safeParse(period).success
  const args = { p_tenant_id: tenantId!, p_start_date: period.startDate, p_end_date: period.endDate, p_currency_code: period.currencyCode, p_location_id: period.locationId || undefined }
  function validateScope(value: { tenantId: string; startDate: string; endDate: string; currencyCode: string; locationId: string | null }) {
    if (value.tenantId !== tenantId || value.startDate !== period.startDate || value.endDate !== period.endDate || value.currencyCode !== period.currencyCode || value.locationId !== (period.locationId || null)) throw new Error('Dönem kapsamı doğrulanamadı.')
  }
  const report = useQuery({ queryKey: ['operating-profitability', tenantId, period], enabled: !!tenantId && valid, queryFn: async () => {
    const { data, error } = await supabase.rpc('get_operating_profitability', { ...args, p_allocation_method: period.allocationMethod })
    if (error) throw new Error(costingError(operatingError(error.message)))
    const result = profitabilitySchema.parse(data); validateScope(result)
    if (result.allocationMethod !== period.allocationMethod) throw new Error('Dağıtım yöntemi doğrulanamadı.')
    return result
  } })
  const data = useQuery({ queryKey: ['operating-data', tenantId, period.startDate, period.endDate, period.currencyCode, period.locationId], enabled: !!tenantId && valid, queryFn: async () => {
    const { data, error } = await supabase.rpc('get_operating_data', args)
    if (error) throw new Error(costingError(operatingError(error.message)))
    const result = operatingDataSchema.parse(data); validateScope(result); return result
  } })
  return { report, data, valid }
}
