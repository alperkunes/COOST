import { useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../../../shared/supabase/client'
import { useTenant } from '../../../shared/tenant/useTenant'
import { costingError } from '../model/costing'
import { salesAppError, salesAppImportSchema, type SalesAppImport, type SalesAppMapping } from '../model/salesApp'

function useSalesAppCommand<T>(run: (tenantId: string, input: T) => PromiseLike<{ data: string | null; error: { message: string } | null }>) {
  const { tenantId } = useTenant(), client = useQueryClient()
  return useMutation({ mutationFn: async (input: T) => {
    if (!tenantId) throw new Error('Aktif işletme bulunamadı.')
    const { data, error } = await run(tenantId, input)
    if (error) throw new Error(costingError(salesAppError(error.message)))
    if (!data) throw new Error('İşlem tamamlanamadı.')
    return data
  }, onSuccess: async () => { await Promise.all(['sales-app', 'operating-data', 'operating-profitability'].map((key) => client.invalidateQueries({ queryKey: [key, tenantId] }))) } })
}
export function useImportSalesApp() {
  return useSalesAppCommand((tenantId, input: SalesAppImport) => {
    const v = salesAppImportSchema.parse(input)
    return supabase.rpc('import_sales_app_daily_sales', { p_tenant_id: tenantId, p_location_id: v.locationId, p_business_date: v.businessDate, p_external_batch_key: v.externalBatchKey, p_currency_code: v.currencyCode, p_rows: v.rows })
  })
}
export function useUpdateSalesAppMapping() {
  return useSalesAppCommand((tenantId, input: { id: string; status: SalesAppMapping['status']; productId: string | null }) => supabase.rpc('update_sales_app_product_mapping', { p_tenant_id: tenantId, p_mapping_id: input.id, p_status: input.status, p_menu_product_id: input.productId ?? undefined }))
}
export function useReprocessSalesApp() {
  return useSalesAppCommand((tenantId, batchId: string) => supabase.rpc('reprocess_sales_app_import_batch', { p_tenant_id: tenantId, p_batch_id: batchId }))
}
