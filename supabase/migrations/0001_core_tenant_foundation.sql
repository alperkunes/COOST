-- COOST Core SaaS Schema v1.1
-- Architecture draft. Do not run against production yet.
-- Cross-tenant relational integrity is enforced at schema level.

create extension if not exists pgcrypto;

create table tenants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  status text not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint tenants_name_check
    check (char_length(trim(name)) between 2 and 120),

  constraint tenants_status_check
    check (status in ('ACTIVE', 'SUSPENDED', 'ARCHIVED'))
);

create table locations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  name text not null,
  status text not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint locations_name_check
    check (char_length(trim(name)) between 2 and 120),

  constraint locations_status_check
    check (status in ('ACTIVE', 'PASSIVE')),

  constraint locations_tenant_name_unique
    unique (tenant_id, name),

  constraint locations_id_tenant_unique
    unique (id, tenant_id)
);

create table memberships (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  user_id uuid not null,
  status text not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint memberships_status_check
    check (status in ('ACTIVE', 'INVITED', 'SUSPENDED')),

  constraint memberships_tenant_user_unique
    unique (tenant_id, user_id),

  constraint memberships_id_tenant_unique
    unique (id, tenant_id)
);

create table roles (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  key text not null,
  name text not null,
  is_system boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint roles_key_check
    check (char_length(trim(key)) between 2 and 80),

  constraint roles_name_check
    check (char_length(trim(name)) between 2 and 120),

  constraint roles_tenant_key_unique
    unique (tenant_id, key),

  constraint roles_id_tenant_unique
    unique (id, tenant_id)
);

create table membership_roles (
  tenant_id uuid not null references tenants(id) on delete cascade,
  membership_id uuid not null,
  role_id uuid not null,
  created_at timestamptz not null default now(),

  primary key (tenant_id, membership_id, role_id),

  constraint membership_roles_membership_fk
    foreign key (membership_id, tenant_id)
    references memberships(id, tenant_id)
    on delete cascade,

  constraint membership_roles_role_fk
    foreign key (role_id, tenant_id)
    references roles(id, tenant_id)
    on delete cascade
);

create table role_permissions (
  tenant_id uuid not null references tenants(id) on delete cascade,
  role_id uuid not null,
  permission_key text not null,
  created_at timestamptz not null default now(),

  primary key (tenant_id, role_id, permission_key),

  constraint role_permissions_role_fk
    foreign key (role_id, tenant_id)
    references roles(id, tenant_id)
    on delete cascade
);

create table tenant_modules (
  tenant_id uuid not null references tenants(id) on delete cascade,
  module_key text not null,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  primary key (tenant_id, module_key)
);

create table audit_logs (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete restrict,
  location_id uuid,
  actor_user_id uuid,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint audit_logs_location_fk
    foreign key (location_id, tenant_id)
    references locations(id, tenant_id)
    on delete restrict
);

create table outbox_events (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  event_type text not null,
  aggregate_type text not null,
  aggregate_id uuid,
  payload jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  processed_at timestamptz,
  attempts integer not null default 0,

  constraint outbox_events_attempts_check
    check (attempts >= 0)
);

create index idx_locations_tenant_id
  on locations(tenant_id);

create index idx_memberships_tenant_id
  on memberships(tenant_id);

create index idx_memberships_user_id
  on memberships(user_id);

create index idx_roles_tenant_id
  on roles(tenant_id);

create index idx_membership_roles_membership
  on membership_roles(tenant_id, membership_id);

create index idx_role_permissions_role
  on role_permissions(tenant_id, role_id);

create index idx_audit_logs_tenant_created_at
  on audit_logs(tenant_id, created_at desc);

create index idx_outbox_events_unprocessed
  on outbox_events(occurred_at)
  where processed_at is null;