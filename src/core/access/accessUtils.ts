import type { ModuleKey } from './modules'
import type { PermissionKey } from './permissions'
import type { TenantContext } from '../tenant/tenantSchemas'

export function hasModule(
  context: TenantContext,
  module: ModuleKey,
): boolean {
  return context.modules.includes(module)
}

export function hasPermission(
  context: TenantContext,
  permission: PermissionKey,
): boolean {
  return context.permissions.includes(permission)
}