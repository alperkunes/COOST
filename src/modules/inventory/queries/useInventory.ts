import { useQuery } from '@tanstack/react-query'
import { supabase } from '../../../shared/supabase/client'
import { useTenant } from '../../../shared/tenant/useTenant'
import { overviewSchema, managementSchema, contextSchema, countsSchema, countDetailSchema, inventoryError } from '../model/inventory'

export function useInventoryOverview(locationId: string) {
  const { tenantId } = useTenant()
  return useQuery({ queryKey: ['inventory-overview', tenantId, locationId], enabled: !!tenantId, queryFn: async () => {
    const { data, error } = await supabase.rpc('get_inventory_overview', { p_tenant_id: tenantId!, p_location_id: locationId || undefined })
    if (error) throw new Error(inventoryError(error.message))
    const result = overviewSchema.parse(data)
    if (result.tenantId !== tenantId || result.locationId !== (locationId || null)) throw new Error('Stok özeti doğrulanamadı.')
    return result
  } })
}
export function useInventoryManagement(enabled: boolean) {
  const { tenantId } = useTenant()
  return useQuery({ queryKey: ['inventory-management', tenantId], enabled: !!tenantId && enabled, queryFn: async () => {
    const { data, error } = await supabase.rpc('get_inventory_management', { p_tenant_id: tenantId! })
    if (error) throw new Error(inventoryError(error.message))
    const result = managementSchema.parse(data)
    if (result.tenantId !== tenantId) throw new Error('Stok kartları doğrulanamadı.')
    return result
  } })
}
export function useInventoryContext() {
  const { tenantId } = useTenant()
  return useQuery({ queryKey: ['inventory-context', tenantId], enabled: !!tenantId, queryFn: async () => {
    const { data, error } = await supabase.rpc('get_inventory_context', { p_tenant_id: tenantId! })
    if (error) throw new Error(inventoryError(error.message))
    const result = contextSchema.parse(data)
    if (result.tenantId !== tenantId) throw new Error('Stok seçenekleri doğrulanamadı.')
    return result
  } })
}
export function useInventoryCounts() {
  const { tenantId } = useTenant()
  return useQuery({ queryKey: ['inventory-counts', tenantId], enabled: !!tenantId, queryFn: async () => {
    const { data, error } = await supabase.rpc('get_inventory_counts', { p_tenant_id: tenantId! })
    if (error) throw new Error(inventoryError(error.message))
    const result = countsSchema.parse(data)
    if (result.tenantId !== tenantId) throw new Error('Sayımlar doğrulanamadı.')
    return result
  } })
}
export function useInventoryCountDetail(countId: string) {
  const { tenantId } = useTenant()
  return useQuery({ queryKey: ['inventory-count-detail', tenantId, countId], enabled: !!tenantId && !!countId, queryFn: async () => {
    const { data, error } = await supabase.rpc('get_inventory_count_detail', { p_tenant_id: tenantId!, p_count_id: countId })
    if (error) throw new Error(inventoryError(error.message))
    const result = countDetailSchema.parse(data)
    if (result.tenantId !== tenantId || result.id !== countId) throw new Error('Sayım doğrulanamadı.')
    return result
  } })
}
