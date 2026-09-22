-- COOST Security Helper Functions v1
-- Architecture draft. Do not run against production yet.
--
-- Purpose:
-- Provide small, controlled helper functions for future RLS policies.
-- These functions intentionally run as SECURITY DEFINER to avoid
-- recursive RLS lookups on membership and permission tables.

create schema if not exists private;

revoke all on schema private from public;
grant usage on schema private to authenticated, service_role;

create or replace function private.is_tenant_member(
  p_tenant_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.memberships as m
    inner join public.tenants as t
      on t.id = m.tenant_id
    where m.tenant_id = p_tenant_id
      and m.user_id = auth.uid()
      and m.status = 'ACTIVE'
      and t.status = 'ACTIVE'
  );
$$;

create or replace function private.has_permission(
  p_tenant_id uuid,
  p_permission_key text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.memberships as m
    inner join public.tenants as t
      on t.id = m.tenant_id
    inner join public.membership_roles as mr
      on mr.tenant_id = m.tenant_id
     and mr.membership_id = m.id
    inner join public.role_permissions as rp
      on rp.tenant_id = mr.tenant_id
     and rp.role_id = mr.role_id
    where m.tenant_id = p_tenant_id
      and m.user_id = auth.uid()
      and m.status = 'ACTIVE'
      and t.status = 'ACTIVE'
      and rp.permission_key = p_permission_key
  );
$$;

create or replace function private.is_module_enabled(
  p_tenant_id uuid,
  p_module_key text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.memberships as m
    inner join public.tenants as t
      on t.id = m.tenant_id
    inner join public.tenant_modules as tm
      on tm.tenant_id = m.tenant_id
    where m.tenant_id = p_tenant_id
      and m.user_id = auth.uid()
      and m.status = 'ACTIVE'
      and t.status = 'ACTIVE'
      and tm.module_key = p_module_key
      and tm.enabled = true
  );
$$;

revoke all
  on function private.is_tenant_member(uuid)
  from public;

revoke all
  on function private.has_permission(uuid, text)
  from public;

revoke all
  on function private.is_module_enabled(uuid, text)
  from public;

grant execute
  on function private.is_tenant_member(uuid)
  to authenticated, service_role;

grant execute
  on function private.has_permission(uuid, text)
  to authenticated, service_role;

grant execute
  on function private.is_module_enabled(uuid, text)
  to authenticated, service_role;

comment on function private.is_tenant_member(uuid)
  is 'Returns true only when the current authenticated user has an ACTIVE membership in an ACTIVE tenant.';

comment on function private.has_permission(uuid, text)
  is 'Returns true only when the current authenticated user has the requested permission through an ACTIVE membership in an ACTIVE tenant.';

comment on function private.is_module_enabled(uuid, text)
  is 'Returns true only when the current authenticated user belongs to the ACTIVE tenant and the requested tenant module is enabled.';