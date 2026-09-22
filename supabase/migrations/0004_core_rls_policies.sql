-- COOST Core RLS Policies v1
-- Architecture draft. Do not run against production yet.
--
-- Default posture:
-- authenticated users receive only explicitly granted access.
-- Core administrative writes will be implemented through controlled
-- commands/RPCs instead of direct browser table mutations.

-- ------------------------------------------------------------
-- ENABLE RLS
-- ------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.tenants enable row level security;
alter table public.locations enable row level security;
alter table public.memberships enable row level security;
alter table public.roles enable row level security;
alter table public.membership_roles enable row level security;
alter table public.role_permissions enable row level security;
alter table public.tenant_modules enable row level security;
alter table public.membership_invitations enable row level security;
alter table public.membership_invitation_roles enable row level security;
alter table public.audit_logs enable row level security;
alter table public.outbox_events enable row level security;

-- ------------------------------------------------------------
-- TABLE PRIVILEGES
-- ------------------------------------------------------------

revoke all on table public.profiles from anon;
revoke all on table public.tenants from anon;
revoke all on table public.locations from anon;
revoke all on table public.memberships from anon;
revoke all on table public.roles from anon;
revoke all on table public.membership_roles from anon;
revoke all on table public.role_permissions from anon;
revoke all on table public.tenant_modules from anon;
revoke all on table public.membership_invitations from anon;
revoke all on table public.membership_invitation_roles from anon;
revoke all on table public.audit_logs from anon;
revoke all on table public.outbox_events from anon;

revoke insert, update, delete
  on table public.tenants,
           public.locations,
           public.memberships,
           public.roles,
           public.membership_roles,
           public.role_permissions,
           public.tenant_modules,
           public.membership_invitations,
           public.membership_invitation_roles,
           public.audit_logs,
           public.outbox_events
  from authenticated;

revoke all
  on table public.outbox_events
  from authenticated;

revoke insert, delete
  on table public.profiles
  from authenticated;

revoke update
  on table public.profiles
  from authenticated;

grant select
  on table public.profiles,
           public.tenants,
           public.locations,
           public.memberships,
           public.roles,
           public.membership_roles,
           public.role_permissions,
           public.tenant_modules,
           public.membership_invitations,
           public.membership_invitation_roles,
           public.audit_logs
  to authenticated;

grant update (
  display_name,
  avatar_url,
  locale,
  timezone
)
  on table public.profiles
  to authenticated;

-- outbox_events intentionally receives no browser grant.

-- ------------------------------------------------------------
-- PROFILES
-- ------------------------------------------------------------

drop policy if exists profiles_select_own
  on public.profiles;

create policy profiles_select_own
  on public.profiles
  for select
  to authenticated
  using (
    id = auth.uid()
  );

drop policy if exists profiles_update_own
  on public.profiles;

create policy profiles_update_own
  on public.profiles
  for update
  to authenticated
  using (
    id = auth.uid()
  )
  with check (
    id = auth.uid()
  );

-- ------------------------------------------------------------
-- TENANTS
-- ------------------------------------------------------------

drop policy if exists tenants_select_member
  on public.tenants;

create policy tenants_select_member
  on public.tenants
  for select
  to authenticated
  using (
    private.is_tenant_member(id)
  );

-- ------------------------------------------------------------
-- LOCATIONS
-- ------------------------------------------------------------

drop policy if exists locations_select_member
  on public.locations;

create policy locations_select_member
  on public.locations
  for select
  to authenticated
  using (
    private.is_tenant_member(tenant_id)
  );

-- ------------------------------------------------------------
-- MEMBERSHIPS
-- ------------------------------------------------------------

drop policy if exists memberships_select_allowed
  on public.memberships;

create policy memberships_select_allowed
  on public.memberships
  for select
  to authenticated
  using (
    user_id = auth.uid()
    or private.has_permission(
      tenant_id,
      'tenant.users.read'
    )
    or private.has_permission(
      tenant_id,
      'tenant.users.manage'
    )
  );

-- ------------------------------------------------------------
-- ROLES
-- ------------------------------------------------------------

drop policy if exists roles_select_managers
  on public.roles;

create policy roles_select_managers
  on public.roles
  for select
  to authenticated
  using (
    private.has_permission(
      tenant_id,
      'tenant.users.read'
    )
    or private.has_permission(
      tenant_id,
      'tenant.users.manage'
    )
  );

-- ------------------------------------------------------------
-- MEMBERSHIP ROLES
-- ------------------------------------------------------------

drop policy if exists membership_roles_select_managers
  on public.membership_roles;

create policy membership_roles_select_managers
  on public.membership_roles
  for select
  to authenticated
  using (
    private.has_permission(
      tenant_id,
      'tenant.users.read'
    )
    or private.has_permission(
      tenant_id,
      'tenant.users.manage'
    )
  );

-- ------------------------------------------------------------
-- ROLE PERMISSIONS
-- ------------------------------------------------------------

drop policy if exists role_permissions_select_managers
  on public.role_permissions;

create policy role_permissions_select_managers
  on public.role_permissions
  for select
  to authenticated
  using (
    private.has_permission(
      tenant_id,
      'tenant.users.read'
    )
    or private.has_permission(
      tenant_id,
      'tenant.users.manage'
    )
  );

-- ------------------------------------------------------------
-- TENANT MODULES
-- ------------------------------------------------------------

drop policy if exists tenant_modules_select_member
  on public.tenant_modules;

create policy tenant_modules_select_member
  on public.tenant_modules
  for select
  to authenticated
  using (
    private.is_tenant_member(tenant_id)
  );

-- ------------------------------------------------------------
-- MEMBERSHIP INVITATIONS
-- ------------------------------------------------------------

drop policy if exists membership_invitations_select_managers
  on public.membership_invitations;

create policy membership_invitations_select_managers
  on public.membership_invitations
  for select
  to authenticated
  using (
    private.has_permission(
      tenant_id,
      'tenant.users.read'
    )
    or private.has_permission(
      tenant_id,
      'tenant.users.manage'
    )
  );

-- ------------------------------------------------------------
-- MEMBERSHIP INVITATION ROLES
-- ------------------------------------------------------------

drop policy if exists membership_invitation_roles_select_managers
  on public.membership_invitation_roles;

create policy membership_invitation_roles_select_managers
  on public.membership_invitation_roles
  for select
  to authenticated
  using (
    private.has_permission(
      tenant_id,
      'tenant.users.read'
    )
    or private.has_permission(
      tenant_id,
      'tenant.users.manage'
    )
  );

-- ------------------------------------------------------------
-- AUDIT LOGS
-- ------------------------------------------------------------

drop policy if exists audit_logs_select_authorized
  on public.audit_logs;

create policy audit_logs_select_authorized
  on public.audit_logs
  for select
  to authenticated
  using (
    private.has_permission(
      tenant_id,
      'audit.read'
    )
  );

-- ------------------------------------------------------------
-- OUTBOX EVENTS
-- ------------------------------------------------------------

-- No authenticated policies are intentionally created.
-- RLS + absence of grants/policies means browser clients cannot
-- read or mutate outbox events.