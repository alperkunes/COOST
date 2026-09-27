import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useTenant } from '../../../shared/tenant/useTenant'
import { supabase } from '../../../shared/supabase/client'
import { costingError } from '../model/costing'
import { operatingError, salesInputSchema, expenseInputSchema, type SalesInput, type ExpenseInput } from '../model/operating'

function useOperatingCommand<T>(run: (tenantId: string, value: T) => PromiseLike<{ data: string | null; error: { message: string } | null }>) {
  const { tenantId } = useTenant(); const client = useQueryClient()
  return useMutation({ mutationFn: async (value: T) => {
    if (!tenantId) throw new Error('Aktif işletme bulunamadı.')
    const { data, error } = await run(tenantId, value)
    if (error) throw new Error(costingError(operatingError(error.message)))
    if (!data) throw new Error('İşlem tamamlanamadı.')
    return data
  }, onSuccess: async () => { await Promise.all(['operating-profitability', 'operating-data'].map((key) => client.invalidateQueries({ queryKey: [key, tenantId] }))) } })
}
export function useSaveSalesFact() {
  return useOperatingCommand((tenantId, input: SalesInput) => {
    const v = salesInputSchema.parse(input)
    return supabase.rpc('upsert_menu_product_sales_fact', { p_tenant_id: tenantId, p_location_id: v.locationId, p_sale_date: v.saleDate, p_menu_product_id: v.productId, p_quantity: v.quantity, p_gross_sales: v.grossSales, p_net_sales: v.netSales })
  })
}
export function useSaveOperatingCost() {
  return useOperatingCommand((tenantId, { id, input }: { id?: string; input: ExpenseInput }) => {
    const v = expenseInputSchema.parse(input)
    const args = { p_tenant_id: tenantId, p_location_id: v.locationId || undefined, p_occurred_on: v.occurredOn, p_currency_code: v.currencyCode, p_category: v.category, p_amount: v.amount, p_description: v.description }
    return id ? supabase.rpc('update_operating_cost_entry', { ...args, p_entry_id: id }) : supabase.rpc('create_operating_cost_entry', args)
  })
}
export function useVoidOperatingCost() {
  return useOperatingCommand((tenantId, id: string) => supabase.rpc('void_operating_cost_entry', { p_tenant_id: tenantId, p_entry_id: id }))
}
