import {
  useCallback,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import {
  tenantContextSchema,
  type TenantContext,
} from '../../core/tenant/tenantSchemas'
import { useAuth } from '../auth/useAuth'
import { supabase } from '../supabase/client'
import {
  TenantProviderContext,
  type TenantProviderValue,
} from './tenantContext'

const ACTIVE_TENANT_STORAGE_KEY = 'coost.activeTenantId'

type TenantProviderProps = {
  children: ReactNode
}

export function TenantProvider({
  children,
}: TenantProviderProps) {
  const { user, loading: authLoading } = useAuth()

  const [tenantIds, setTenantIds] = useState<string[]>([])
  const [tenantId, setTenantId] = useState<string | null>(null)
  const [context, setContext] =
    useState<TenantContext | null>(null)
  const [membershipsLoading, setMembershipsLoading] =
    useState(true)
  const [contextLoading, setContextLoading] =
    useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false

    if (authLoading) {
      setMembershipsLoading(true)
      return () => {
        cancelled = true
      }
    }

    if (!user) {
      setTenantIds([])
      setTenantId(null)
      setContext(null)
      setError(null)
      setMembershipsLoading(false)

      return () => {
        cancelled = true
      }
    }

    setMembershipsLoading(true)
    setError(null)

    void supabase
      .from('memberships')
      .select('tenant_id')
      .eq('status', 'ACTIVE')
      .order('created_at', { ascending: true })
      .then(({ data, error: membershipsError }) => {
        if (cancelled) {
          return
        }

        if (membershipsError) {
          setTenantIds([])
          setTenantId(null)
          setContext(null)
          setError(membershipsError.message)
          setMembershipsLoading(false)
          return
        }

        const ids = Array.from(
          new Set(data.map((membership) => membership.tenant_id)),
        )

        setTenantIds(ids)

        const storedTenantId =
          window.localStorage.getItem(
            ACTIVE_TENANT_STORAGE_KEY,
          )

        const nextTenantId =
          storedTenantId && ids.includes(storedTenantId)
            ? storedTenantId
            : ids[0] ?? null

        setTenantId(nextTenantId)

        if (nextTenantId) {
          window.localStorage.setItem(
            ACTIVE_TENANT_STORAGE_KEY,
            nextTenantId,
          )
        } else {
          window.localStorage.removeItem(
            ACTIVE_TENANT_STORAGE_KEY,
          )
          setContext(null)
        }

        setMembershipsLoading(false)
      })

    return () => {
      cancelled = true
    }
  }, [authLoading, user])

  useEffect(() => {
    let cancelled = false

    if (!user || !tenantId) {
      setContext(null)
      setContextLoading(false)

      return () => {
        cancelled = true
      }
    }

    setContextLoading(true)
    setError(null)

    void supabase
      .rpc('get_my_tenant_context', {
        p_tenant_id: tenantId,
      })
      .then(({ data, error: contextError }) => {
        if (cancelled) {
          return
        }

        if (contextError) {
          setContext(null)
          setError(contextError.message)
          setContextLoading(false)
          return
        }

        if (data === null) {
          setContext(null)
          setError(
            'The selected tenant is not available for this user.',
          )
          setContextLoading(false)
          return
        }

        const parsed = tenantContextSchema.safeParse(data)

        if (!parsed.success) {
          setContext(null)
          setError(
            'The tenant context returned by the server is invalid.',
          )
          setContextLoading(false)
          return
        }

        setContext(parsed.data)
        setContextLoading(false)
      })

    return () => {
      cancelled = true
    }
  }, [tenantId, user])

  const selectTenant = useCallback(
    (nextTenantId: string) => {
      if (!tenantIds.includes(nextTenantId)) {
        throw new Error(
          'Cannot select a tenant outside the current user memberships.',
        )
      }

      window.localStorage.setItem(
        ACTIVE_TENANT_STORAGE_KEY,
        nextTenantId,
      )

      setTenantId(nextTenantId)
    },
    [tenantIds],
  )

  const value = useMemo<TenantProviderValue>(
    () => ({
      tenantIds,
      tenantId,
      context,
      loading:
        authLoading ||
        membershipsLoading ||
        contextLoading,
      error,
      selectTenant,
    }),
    [
      authLoading,
      membershipsLoading,
      contextLoading,
      tenantIds,
      tenantId,
      context,
      error,
      selectTenant,
    ],
  )

  return (
    <TenantProviderContext.Provider value={value}>
      {children}
    </TenantProviderContext.Provider>
  )
}