# COOST Staging and RLS Test Plan v1

## Purpose

COOST database migrations and tenant security must be proven in an isolated staging environment before any production environment exists.

## Environment model

COOST will use separate environments:

1. Development
2. Staging
3. Production

Production will never be used for schema experiments.

Galata production data will not be connected during foundation development.

## Staging Supabase

A dedicated Supabase project will be created only for COOST staging.

It must not reuse:

- Co-Asist Supabase
- Galata production database
- production credentials
- production users
- real financial records

Suggested project purpose:

COOST-STAGING

## Environment secrets

Secrets must stay outside Git.

Expected local variables later:

VITE_SUPABASE_URL
VITE_SUPABASE_ANON_KEY

Server-only credentials such as service_role must never use a VITE_ prefix.

service_role must never be shipped to the browser.

## Migration order

Staging migrations must be applied in numerical order:

0001_core_tenant_foundation.sql
0002_auth_profiles_invitations.sql
0003_security_helpers.sql
0004_core_rls_policies.sql

A migration failure stops the process.

No later migration is manually skipped.

## Test identities

Staging security tests will use synthetic users only.

Minimum identities:

User A
- member of Tenant A

User B
- member of Tenant B

Manager A
- member of Tenant A
- tenant.users.read
- tenant.users.manage
- audit.read

Restricted A
- member of Tenant A
- no management permission

Suspended A
- SUSPENDED membership in Tenant A

## Test tenants

Tenant A
- ACTIVE

Tenant B
- ACTIVE

Tenant Suspended
- SUSPENDED

Each tenant will have at least one location.

## Mandatory tenant isolation tests

### Tenant visibility

User A can read Tenant A.

User A cannot read Tenant B.

User B cannot read Tenant A.

A member of Tenant Suspended cannot gain tenant access.

### Location visibility

User A can read Tenant A locations.

User A cannot read Tenant B locations.

Cross-tenant location relationships must fail.

### Membership visibility

User A can read their own Tenant A membership.

Restricted A cannot enumerate unrelated membership records.

Manager A can read permitted Tenant A membership records.

Manager A cannot read Tenant B membership records.

### Authorization structure

Restricted A cannot read protected role administration data.

Manager A can read authorized Tenant A role data.

Manager A cannot read Tenant B role data.

### Invitations

Restricted A cannot enumerate invitations.

Manager A can read Tenant A invitations.

Manager A cannot read Tenant B invitations.

Cross-tenant invitation-role relationships must fail.

### Modules

A tenant member can only evaluate modules belonging to their tenant.

Disabled modules must return false from the module security helper.

### Audit

A user without audit.read cannot read audit logs.

Manager A with audit.read can read Tenant A audit logs.

Manager A cannot read Tenant B audit logs.

Normal authenticated clients cannot update or delete audit records.

### Outbox

Authenticated browser users cannot:

- select
- insert
- update
- delete

outbox_events.

### Profile

A user can read their own profile.

A user cannot read another user's profile.

A user can update only allowed profile columns.

A user cannot change the profile primary key.

## Direct write policy

Core administrative tables are not directly writable from the browser.

Future writes will use controlled command / RPC boundaries.

This includes:

- tenant management
- membership management
- role management
- permissions
- tenant modules
- invitations
- audit generation
- outbox generation

## Cross-tenant invariant

For every new tenant-scoped domain table added to COOST, tests must prove:

Tenant A cannot read Tenant B data.

Tenant A cannot modify Tenant B data.

Tenant A cannot create a relationship pointing to Tenant B data.

This rule applies before a module is considered production-ready.

## Promotion rule

A migration can move toward production only when:

- migration applies cleanly to staging
- RLS tests pass
- cross-tenant tests pass
- rollback or forward-fix strategy is documented
- npm run verify passes
- Git working tree is clean
- migration is committed
- staging runtime has been manually smoke tested

## Next step

After this document is committed:

1. verify whether Supabase CLI is available
2. create a dedicated COOST staging project
3. connect only the staging project
4. apply migrations 0001-0004
5. seed synthetic tenants and users
6. execute real RLS isolation tests
7. fix any security failures before application integration