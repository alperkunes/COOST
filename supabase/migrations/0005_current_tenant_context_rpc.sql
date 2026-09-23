-- COOST Current Tenant Context RPC v1
--
-- Purpose:
-- Return only the current authenticated user's effective
-- tenant modules and permissions without exposing role
-- administration tables to ordinary tenant members.

create or replace function private.get_my_tenant_context(
  p_tenant_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'tenantId',
    m.tenant_id,

    'locationId',
    null,

    'userId',
    m.user_id,

    'modules',
    coalesce(
      (
        select jsonb_agg(
          tm.module_key
          order by tm.module_key
        )
        from public.tenant_modules as tm
        where tm.tenant_id = m.tenant_id
          and tm.enabled = true
      ),
      '[]'::jsonb
    ),

    'permissions',
    coalesce(
      (
        select jsonb_agg(
          effective_permissions.permission_key
          order by effective_permissions.permission_key
        )
        from (
          select distinct rp.permission_key
          from public.membership_roles as mr
          inner join public.role_permissions as rp
            on rp.tenant_id = mr.tenant_id
           and rp.role_id = mr.role_id
          where mr.tenant_id = m.tenant_id
            and mr.membership_id = m.id
        ) as effective_permissions
      ),
      '[]'::jsonb
    )
  )
  from public.memberships as m
  inner join public.tenants as t
    on t.id = m.tenant_id
  where m.tenant_id = p_tenant_id
    and m.user_id = auth.uid()
    and m.status = 'ACTIVE'
    and t.status = 'ACTIVE'
  limit 1;
$$;

revoke all
  on function private.get_my_tenant_context(uuid)
  from public;

grant execute
  on function private.get_my_tenant_context(uuid)
  to authenticated, service_role;


create or replace function public.get_my_tenant_context(
  p_tenant_id uuid
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select private.get_my_tenant_context(p_tenant_id);
$$;

revoke all
  on function public.get_my_tenant_context(uuid)
  from public;

revoke all
  on function public.get_my_tenant_context(uuid)
  from anon;

grant execute
  on function public.get_my_tenant_context(uuid)
  to authenticated, service_role;

comment on function public.get_my_tenant_context(uuid)
  is 'Returns the current authenticated users effective modules and permissions for one ACTIVE tenant membership.';