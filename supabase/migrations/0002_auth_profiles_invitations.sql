-- COOST Auth Profiles and Invitations v1
-- Architecture draft. Do not run against production yet.

-- Membership represents a real authenticated user relationship.
-- Invitations are modeled separately.

alter table memberships
  drop constraint memberships_status_check;

alter table memberships
  add constraint memberships_status_check
  check (status in ('ACTIVE', 'SUSPENDED'));

alter table memberships
  add constraint memberships_user_fk
  foreign key (user_id)
  references auth.users(id)
  on delete cascade;

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  locale text not null default 'tr-TR',
  timezone text not null default 'Europe/Istanbul',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint profiles_display_name_check
    check (
      display_name is null
      or char_length(trim(display_name)) between 2 and 120
    ),

  constraint profiles_locale_check
    check (char_length(trim(locale)) between 2 and 20),

  constraint profiles_timezone_check
    check (char_length(trim(timezone)) between 2 and 80)
);

create table membership_invitations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  email text not null,
  status text not null default 'PENDING',
  invited_by_user_id uuid not null references auth.users(id) on delete restrict,
  expires_at timestamptz not null,
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint membership_invitations_email_check
    check (char_length(trim(email)) between 3 and 320),

  constraint membership_invitations_status_check
    check (status in ('PENDING', 'ACCEPTED', 'REVOKED', 'EXPIRED')),

  constraint membership_invitations_expiry_check
    check (expires_at > created_at),

  constraint membership_invitations_id_tenant_unique
    unique (id, tenant_id)
);

create unique index idx_membership_invitations_pending_email
  on membership_invitations (tenant_id, lower(trim(email)))
  where status = 'PENDING';

create index idx_membership_invitations_tenant_status
  on membership_invitations (tenant_id, status);

create table membership_invitation_roles (
  tenant_id uuid not null references tenants(id) on delete cascade,
  invitation_id uuid not null,
  role_id uuid not null,
  created_at timestamptz not null default now(),

  primary key (tenant_id, invitation_id, role_id),

  constraint membership_invitation_roles_invitation_fk
    foreign key (invitation_id, tenant_id)
    references membership_invitations(id, tenant_id)
    on delete cascade,

  constraint membership_invitation_roles_role_fk
    foreign key (role_id, tenant_id)
    references roles(id, tenant_id)
    on delete cascade
);

create index idx_membership_invitation_roles_invitation
  on membership_invitation_roles (tenant_id, invitation_id);