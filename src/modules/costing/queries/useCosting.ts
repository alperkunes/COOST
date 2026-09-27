import { useQuery } from '@tanstack/react-query'
import { supabase } from '../../../shared/supabase/client'
import { useTenant } from '../../../shared/tenant/useTenant'
import { costingError, inventoryCostsSchema, recipesSchema, productsSchema } from '../model/costing'

export function useInventoryCosts(currency: string, location = '') {
  const { tenantId } = useTenant()
  return useQuery({ queryKey: ['inventory-costs', tenantId, currency, location], enabled: !!tenantId && /^[A-Z]{3}$/.test(currency), queryFn: async () => {
    const { data, error } = await supabase.rpc('get_inventory_cost_overview', { p_tenant_id: tenantId!, p_currency_code: currency, p_location_id: location || undefined })
    if (error) throw new Error(costingError(error.message))
    const result = inventoryCostsSchema.parse(data)
    if (result.tenantId !== tenantId || result.currencyCode !== currency || result.locationId !== (location || null)) throw new Error('Maliyet kapsamı doğrulanamadı.')
    return result
  } })
}
export function useRecipeCosts(location = '') {
  const { tenantId } = useTenant()
  return useQuery({ queryKey: ['recipe-costs', tenantId, location], enabled: !!tenantId, queryFn: async () => {
    const { data, error } = await supabase.rpc('get_recipe_costing_overview', { p_tenant_id: tenantId!, p_location_id: location || undefined })
    if (error) throw new Error(costingError(error.message))
    const result = recipesSchema.parse(data)
    if (result.tenantId !== tenantId || result.locationId !== (location || null)) throw new Error('Reçete kapsamı doğrulanamadı.')
    return result
  } })
}
export function useMenuCosts(location = '') {
  const { tenantId } = useTenant()
  return useQuery({ queryKey: ['menu-costs', tenantId, location], enabled: !!tenantId, queryFn: async () => {
    const { data, error } = await supabase.rpc('get_menu_costing_overview', { p_tenant_id: tenantId!, p_location_id: location || undefined })
    if (error) throw new Error(costingError(error.message))
    const result = productsSchema.parse(data)
    if (result.tenantId !== tenantId || result.locationId !== (location || null)) throw new Error('Menü kapsamı doğrulanamadı.')
    return result
  } })
}
