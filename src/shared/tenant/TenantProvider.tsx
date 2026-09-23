import { useQuery } from '@tanstack/react-query'
import {
  useCallback,
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

function getStoredTenantId() {
  if (typeof window === 'undefined') {
    return null
  }

  return window.localStorage.getItem(
    ACTIVE_TENANT_STORAGE_KEY,
  )
}

export function TenantProvider({
  children,
}: TenantProviderProps) {
  const { user, loading: authLoading } = useAuth()

  const [selectedTenantId, setSelectedTenantId] =
    useState<string | null>(getStoredTenantId)

  const membershipsQuery = useQuery({
    queryKey: ['memberships', user?.id],
    enabled: Boolean(user) && !authLoading,
    queryFn: async () => {
      const { data, error } = await supabase
        .from('memberships')
        .select('tenant_id')
        .eq('status', 'ACTIVE')
        .order('created_at', { ascending: true })

      if (error) {
        throw error
      }

      return Array.from(
        new Set(
          data.map(
            (membership) => membership.tenant_id,
          ),
        ),
      )
    },
  })

  const tenantIds = useMemo(
    () =>
      user
        ? membershipsQuery.data ?? []
        : [],
    [user, membershipsQuery.data],
  )

  const tenantId =
    selectedTenantId &&
    tenantIds.includes(selectedTenantId)
      ? selectedTenantId
      : tenantIds[0] ?? null

  const tenantQuery = useQuery({
    queryKey: ['tenant', user?.id, tenantId],
    enabled: Boolean(user && tenantId),
    queryFn: async () => {
      if (!tenantId) {
        throw new Error('Tenant id is required')
      }

      const { data, error } = await supabase
        .from('tenants')
        .select('id, name')
        .eq('id', tenantId)
        .single()

      if (error) {
        throw error
      }

      return data
    },
  })

  const contextQuery = useQuery<TenantContext>({
    queryKey: [
      'tenant-context',
      user?.id,
      tenantId,
    ],
    enabled: Boolean(user && tenantId),
    queryFn: async () => {
      if (!tenantId) {
        throw new Error('Tenant id is required')
      }

      const { data, error } = await supabase.rpc(
        'get_my_tenant_context',
        {
          p_tenant_id: tenantId,
        },
      )

      if (error) {
        throw error
      }

      if (data === null) {
        throw new Error(
          'The selected tenant is not available for this user.',
        )
      }

      const parsed =
        tenantContextSchema.safeParse(data)

      if (!parsed.success) {
        throw new Error(
          'The tenant context returned by the server is invalid.',
        )
      }

      return parsed.data
    },
  })

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

      setSelectedTenantId(nextTenantId)
    },
    [tenantIds],
  )

  const membershipsLoading =
    Boolean(user) && membershipsQuery.isPending

  const tenantLoading =
    Boolean(user && tenantId) &&
    tenantQuery.isPending

  const contextLoading =
    Boolean(user && tenantId) &&
    contextQuery.isPending

  const error =
    membershipsQuery.error?.message ??
    tenantQuery.error?.message ??
    contextQuery.error?.message ??
    null

  const value = useMemo<TenantProviderValue>(
    () => ({
      tenantIds,
      tenantId,
      tenantName: tenantQuery.data?.name ?? null,
      context: contextQuery.data ?? null,
      loading:
        authLoading ||
        membershipsLoading ||
        tenantLoading ||
        contextLoading,
      error,
      selectTenant,
    }),
    [
      authLoading,
      membershipsLoading,
      tenantLoading,
      contextLoading,
      tenantIds,
      tenantId,
      tenantQuery.data,
      contextQuery.data,
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