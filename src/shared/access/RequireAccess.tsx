import type { ReactNode } from 'react'
import { Navigate } from 'react-router-dom'
import {
  hasAccess,
  type AccessRequirement,
} from '../../core/access/accessUtils'
import { useTenant } from '../tenant/useTenant'

type RequireAccessProps =
  AccessRequirement & {
    children: ReactNode
  }

export function RequireAccess({
  requiredModule,
  requiredPermission,
  children,
}: RequireAccessProps) {
  const { context } = useTenant()

  if (!context) {
    return null
  }

  const allowed = hasAccess(context, {
    requiredModule,
    requiredPermission,
  })

  if (!allowed) {
    return <Navigate to="/" replace />
  }

  return <>{children}</>
}