import type { ModuleKey } from './modules'
import type { PermissionKey } from './permissions'
import type { TenantContext } from '../tenant/tenantSchemas'

export type AccessRequirement = {
  requiredModule?: ModuleKey
  requiredPermission?: PermissionKey
}

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

export function hasAccess(
  context: TenantContext,
  requirement: AccessRequirement,
): boolean {
  const moduleAllowed =
    !requirement.requiredModule ||
    hasModule(context, requirement.requiredModule)

  const permissionAllowed =
    !requirement.requiredPermission ||
    hasPermission(
      context,
      requirement.requiredPermission,
    )

  return moduleAllowed && permissionAllowed
}