begin;

insert into auth.users (
  id,
  aud,
  role,
  email,
  created_at,
  updated_at
)
values
(
  '33333333-3333-4333-8333-333333333333',
  'authenticated',
  'authenticated',
  'manager-a-context@coost.test',
  now(),
  now()
),
(
  '44444444-4444-4444-8444-444444444444',
  'authenticated',
  'authenticated',
  'restricted-a-context@coost.test',
  now(),
  now()
),
(
  '55555555-5555-4555-8555-555555555555',
  'authenticated',
  'authenticated',
  'user-b-context@coost.test',
  now(),
  now()
);

insert into public.profiles (
  id,
  display_name
)
values
(
  '33333333-3333-4333-8333-333333333333',
  'Context Manager A'
),
(
  '44444444-4444-4444-8444-444444444444',
  'Context Restricted A'
),
(
  '55555555-5555-4555-8555-555555555555',
  'Context User B'
);

insert into public.tenants (
  id,
  name,
  status
)
values
(
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  'Context Tenant A',
  'ACTIVE'
),
(
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  'Context Tenant B',
  'ACTIVE'
);

insert into public.memberships (
  id,
  tenant_id,
  user_id,
  status
)
values
(
  'cccccccc-1111-4111-8111-cccccccccccc',
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  '33333333-3333-4333-8333-333333333333',
  'ACTIVE'
),
(
  'cccccccc-2222-4222-8222-cccccccccccc',
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  '44444444-4444-4444-8444-444444444444',
  'ACTIVE'
),
(
  'dddddddd-1111-4111-8111-dddddddddddd',
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  '55555555-5555-4555-8555-555555555555',
  'ACTIVE'
);

insert into public.roles (
  id,
  tenant_id,
  key,
  name,
  is_system
)
values
(
  'cccccccc-3333-4333-8333-cccccccccccc',
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  'manager',
  'Manager',
  true
),
(
  'cccccccc-4444-4444-8444-cccccccccccc',
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  'restricted',
  'Restricted',
  true
);

insert into public.membership_roles (
  tenant_id,
  membership_id,
  role_id
)
values
(
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  'cccccccc-1111-4111-8111-cccccccccccc',
  'cccccccc-3333-4333-8333-cccccccccccc'
),
(
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  'cccccccc-2222-4222-8222-cccccccccccc',
  'cccccccc-4444-4444-8444-cccccccccccc'
);

insert into public.role_permissions (
  tenant_id,
  role_id,
  permission_key
)
values
(
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  'cccccccc-3333-4333-8333-cccccccccccc',
  'tenant.users.read'
),
(
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  'cccccccc-3333-4333-8333-cccccccccccc',
  'tenant.users.manage'
),
(
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  'cccccccc-3333-4333-8333-cccccccccccc',
  'audit.read'
),
(
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  'cccccccc-4444-4444-8444-cccccccccccc',
  'finance.read'
);

insert into public.tenant_modules (
  tenant_id,
  module_key,
  enabled
)
values
(
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  'finance',
  true
),
(
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  'inventory',
  false
),
(
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  'suppliers',
  true
);

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  '33333333-3333-4333-8333-333333333333',
  true
);

do $$
declare
  ctx jsonb;
begin
  ctx := public.get_my_tenant_context(
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
  );

  if ctx is null then
    raise exception 'MANAGER_CONTEXT_NULL';
  end if;

  if ctx ->> 'tenantId'
    <> 'cccccccc-cccc-4ccc-8ccc-cccccccccccc' then
    raise exception 'MANAGER_CONTEXT_WRONG_TENANT';
  end if;

  if ctx ->> 'userId'
    <> '33333333-3333-4333-8333-333333333333' then
    raise exception 'MANAGER_CONTEXT_WRONG_USER';
  end if;

  if ctx -> 'locationId' <> 'null'::jsonb then
    raise exception 'MANAGER_CONTEXT_LOCATION_NOT_NULL';
  end if;

  if ctx -> 'modules'
    <> '["finance"]'::jsonb then
    raise exception 'MANAGER_CONTEXT_MODULES_WRONG';
  end if;

  if ctx -> 'permissions'
    <> '["audit.read","tenant.users.manage","tenant.users.read"]'::jsonb then
    raise exception 'MANAGER_CONTEXT_PERMISSIONS_WRONG';
  end if;

  if public.get_my_tenant_context(
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd'
  ) is not null then
    raise exception 'MANAGER_CAN_READ_TENANT_B_CONTEXT';
  end if;
end
$$;

select set_config(
  'request.jwt.claim.sub',
  '44444444-4444-4444-8444-444444444444',
  true
);

do $$
declare
  ctx jsonb;
begin
  ctx := public.get_my_tenant_context(
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
  );

  if ctx is null then
    raise exception 'RESTRICTED_CONTEXT_NULL';
  end if;

  if ctx -> 'modules'
    <> '["finance"]'::jsonb then
    raise exception 'RESTRICTED_CONTEXT_MODULES_WRONG';
  end if;

  if ctx -> 'permissions'
    <> '["finance.read"]'::jsonb then
    raise exception 'RESTRICTED_CONTEXT_PERMISSIONS_WRONG';
  end if;

  if public.get_my_tenant_context(
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd'
  ) is not null then
    raise exception 'RESTRICTED_CAN_READ_TENANT_B_CONTEXT';
  end if;
end
$$;

select set_config(
  'request.jwt.claim.sub',
  '55555555-5555-4555-8555-555555555555',
  true
);

do $$
declare
  ctx jsonb;
begin
  ctx := public.get_my_tenant_context(
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd'
  );

  if ctx is null then
    raise exception 'USER_B_CONTEXT_NULL';
  end if;

  if ctx -> 'modules'
    <> '["suppliers"]'::jsonb then
    raise exception 'USER_B_CONTEXT_MODULES_WRONG';
  end if;

  if ctx -> 'permissions'
    <> '[]'::jsonb then
    raise exception 'USER_B_CONTEXT_PERMISSIONS_NOT_EMPTY';
  end if;

  if public.get_my_tenant_context(
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
  ) is not null then
    raise exception 'USER_B_CAN_READ_TENANT_A_CONTEXT';
  end if;
end
$$;

set local role anon;

do $$
begin
  perform public.get_my_tenant_context(
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
  );

  raise exception 'ANON_CAN_EXECUTE_CONTEXT_RPC';
exception
  when insufficient_privilege then
    null;
end
$$;

rollback;

select
  'PASS - CURRENT TENANT CONTEXT RPC' as result,
  (
    select count(*)
    from auth.users
    where id in (
      '33333333-3333-4333-8333-333333333333',
      '44444444-4444-4444-8444-444444444444',
      '55555555-5555-4555-8555-555555555555'
    )
  ) as residual_test_users,
  (
    select count(*)
    from public.tenants
    where id in (
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      'dddddddd-dddd-4ddd-8ddd-dddddddddddd'
    )
  ) as residual_test_tenants;