import { useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../../../shared/supabase/client'
import { useTenant } from '../../../shared/tenant/useTenant'
import { costingError, recipeInputSchema, productInputSchema, type RecipeInput, type ProductInput } from '../model/costing'

export function useSaveRecipe() {
  const { tenantId } = useTenant()
  const client = useQueryClient()
  return useMutation({ mutationFn: async ({ id, input }: { id?: string; input: RecipeInput }) => {
    if (!tenantId) throw new Error('Aktif işletme bulunamadı.')
    const v = recipeInputSchema.parse(input)
    const args = { p_tenant_id: tenantId, p_name: v.name, p_code: v.code || undefined, p_category: v.category || undefined,
      p_currency_code: v.currencyCode, p_portions: v.portions, p_lines: v.lines }
    const { data, error } = id ? await supabase.rpc('update_recipe', { ...args, p_recipe_id: id, p_status: v.status }) : await supabase.rpc('create_recipe', args)
    if (error) throw new Error(costingError(error.message))
    if (!data) throw new Error('Reçete kaydedilemedi.')
    return data
  }, onSuccess: async () => { await Promise.all(['operating-profitability', 'operating-data', 'recipe-costs', 'menu-costs'].map((key) => client.invalidateQueries({ queryKey: [key, tenantId] }))) } })
}
export function useSaveMenuProduct() {
  const { tenantId } = useTenant()
  const client = useQueryClient()
  return useMutation({ mutationFn: async ({ id, input }: { id?: string; input: ProductInput }) => {
    if (!tenantId) throw new Error('Aktif işletme bulunamadı.')
    const v = productInputSchema.parse(input)
    const args = { p_tenant_id: tenantId, p_name: v.name, p_code: v.code || undefined, p_category: v.category || undefined,
      p_recipe_id: v.recipeId, p_currency_code: v.currencyCode, p_sale_price_gross: v.salePriceGross, p_sales_tax_rate: v.salesTaxRate,
      p_cost_method: v.costMethod, p_target_food_cost_pct: v.targetFoodCostPct ?? undefined, p_target_operating_margin_pct: v.targetOperatingMarginPct ?? undefined }
    const { data, error } = id ? await supabase.rpc('update_menu_product', { ...args, p_product_id: id, p_status: v.status }) : await supabase.rpc('create_menu_product', args)
    if (error) throw new Error(costingError(error.message))
    if (!data) throw new Error('Menü ürünü kaydedilemedi.')
    return data
  }, onSuccess: async () => { await Promise.all(['menu-costs', 'operating-profitability', 'operating-data'].map((key) => client.invalidateQueries({ queryKey: [key, tenantId] }))) } })
}
