import { useContext } from 'react'
import { TenantProviderContext } from './tenantContext'

export function useTenant() {
  const context = useContext(TenantProviderContext)

  if (!context) {
    throw new Error(
      'useTenant must be used inside TenantProvider',
    )
  }

  return context
}