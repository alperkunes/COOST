import { useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../../../shared/supabase/client'
import { useTenant } from '../../../shared/tenant/useTenant'
import { itemInputSchema, movementInputSchema, inventoryError, type ItemInput, type MovementInput } from '../model/inventory'

function useInventoryCommand<T>(command: (tenantId: string, input: T) => PromiseLike<{ data: string | null; error: { message: string } | null }>) {
  const { tenantId } = useTenant()
  const client = useQueryClient()
  return useMutation({ mutationFn: async (input: T) => {
    if (!tenantId) throw new Error('Aktif işletme bulunamadı.')
    const { data, error } = await command(tenantId, input)
    if (error) throw new Error(inventoryError(error.message))
    if (!data) throw new Error('İşlem tamamlanamadı.')
    return data
  }, onSuccess: async () => { await Promise.all(['inventory-overview', 'inventory-management', 'inventory-context', 'inventory-counts', 'inventory-count-detail']
    .map((key) => client.invalidateQueries({ queryKey: [key, tenantId] }))) } })
}
export function useSaveInventoryItem() {
  return useInventoryCommand((tenantId, { itemId, input }: { itemId?: string; input: ItemInput }) => {
    const value = itemInputSchema.parse(input)
    const args = { p_tenant_id: tenantId, p_name: value.name, p_sku: value.sku || undefined, p_category: value.category || undefined, p_critical_stock: value.criticalStock ?? undefined }
    return itemId ? supabase.rpc('update_inventory_item', { ...args, p_item_id: itemId, p_status: value.status })
      : supabase.rpc('create_inventory_item', { ...args, p_base_unit: value.baseUnit })
  })
}
export function useCreateInventoryMovement() {
  return useInventoryCommand((tenantId, input: MovementInput) => {
    const value = movementInputSchema.parse(input)
    return supabase.rpc('create_inventory_movement', { p_tenant_id: tenantId, p_item_id: value.itemId, p_location_id: value.locationId,
      p_movement_type: value.movementType, p_quantity: value.quantity, p_description: value.description,
      p_direction: value.movementType === 'MANUAL_ADJUSTMENT' ? value.direction : undefined })
  })
}
export function useCreateInventoryCount() {
  return useInventoryCommand((tenantId, input: { locationId: string; notes: string }) => supabase.rpc('create_inventory_count', { p_tenant_id: tenantId, p_location_id: input.locationId, p_notes: input.notes.trim() || undefined }))
}
export function useUpdateInventoryCount() {
  return useInventoryCommand((tenantId, input: { countId: string; lines: { itemId: string; countedQuantity: number }[] }) => supabase.rpc('update_inventory_count', { p_tenant_id: tenantId, p_count_id: input.countId, p_lines: input.lines }))
}
export function usePostInventoryCount() {
  return useInventoryCommand((tenantId, countId: string) => supabase.rpc('post_inventory_count', { p_tenant_id: tenantId, p_count_id: countId }))
}
