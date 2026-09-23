import { createContext } from 'react'
import type { TenantContext } from '../../core/tenant/tenantSchemas'

export type TenantProviderValue = {
  tenantIds: string[]
  tenantId: string | null
  context: TenantContext | null
  loading: boolean
  error: string | null
  selectTenant: (tenantId: string) => void
}

export const TenantProviderContext =
  createContext<TenantProviderValue | null>(null)