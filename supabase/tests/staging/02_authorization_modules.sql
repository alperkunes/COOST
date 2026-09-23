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
  'manager-a@coost.test',
  now(),
  now()
),
(
  '44444444-4444-4444-8444-444444444444',
  'authenticated',
  'authenticated',
  'restricted-a@coost.test',
  now(),
  now()
);

insert into public.profiles (id, display_name)
values
(
  '33333333-3333-4333-8333-333333333333',
  'Manager A'
),
(
  '44444444-4444-4444-8444-444444444444',
  'Restricted A'
);

insert into public.tenants (
  id,
  name,
  status
)
values
(
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  'RLS Permission Tenant A',
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
);

insert into public.audit_logs (
  tenant_id,
  actor_user_id,
  action,
  entity_type,
  metadata
)
values
(
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  '33333333-3333-4333-8333-333333333333',
  'RLS_TEST',
  'tenant',
  '{"source":"coost-security-test"}'::jsonb
);

insert into public.outbox_events (
  tenant_id,
  event_type,
  aggregate_type,
  payload
)
values
(
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  'RLS_TEST_EVENT',
  'tenant',
  '{"source":"coost-security-test"}'::jsonb
);

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  '33333333-3333-4333-8333-333333333333',
  true
);

do $$
begin
  if private.has_permission(
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    'tenant.users.read'
  ) is not true then
    raise exception 'MANAGER_USERS_READ_PERMISSION_FALSE';
  end if;

  if private.has_permission(
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    'tenant.users.manage'
  ) is not true then
    raise exception 'MANAGER_USERS_MANAGE_PERMISSION_FALSE';
  end if;

  if private.has_permission(
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    'audit.read'
  ) is not true then
    raise exception 'MANAGER_AUDIT_PERMISSION_FALSE';
  end if;

  if private.is_module_enabled(
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    'finance'
  ) is not true then
    raise exception 'MANAGER_FINANCE_MODULE_FALSE';
  end if;

  if private.is_module_enabled(
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    'inventory'
  ) is not false then
    raise exception 'MANAGER_DISABLED_INVENTORY_MODULE_TRUE';
  end if;

  if (
    select count(*)
    from public.roles
    where tenant_id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
  ) <> 2 then
    raise exception 'MANAGER_CANNOT_READ_ROLES';
  end if;

  if (
    select count(*)
    from public.membership_roles
    where tenant_id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
  ) <> 2 then
    raise exception 'MANAGER_CANNOT_READ_MEMBERSHIP_ROLES';
  end if;

  if (
    select count(*)
    from public.role_permissions
    where tenant_id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
  ) <> 4 then
    raise exception 'MANAGER_CANNOT_READ_ROLE_PERMISSIONS';
  end if;

  if (
    select count(*)
    from public.audit_logs
    where tenant_id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
  ) <> 1 then
    raise exception 'MANAGER_CANNOT_READ_AUDIT';
  end if;

  if (
    select count(*)
    from public.tenant_modules
    where tenant_id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
  ) <> 2 then
    raise exception 'MANAGER_CANNOT_READ_MODULES';
  end if;

  begin
    perform 1
    from public.outbox_events
    limit 1;

    raise exception 'MANAGER_CAN_READ_OUTBOX';
  exception
    when insufficient_privilege then
      null;
  end;

  begin
    insert into public.audit_logs (
      tenant_id,
      action,
      entity_type
    )
    values (
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      'FORBIDDEN',
      'tenant'
    );

    raise exception 'MANAGER_CAN_WRITE_AUDIT';
  exception
    when insufficient_privilege then
      null;
  end;
end
$$;

select set_config(
  'request.jwt.claim.sub',
  '44444444-4444-4444-8444-444444444444',
  true
);

do $$
begin
  if private.has_permission(
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    'tenant.users.read'
  ) is not false then
    raise exception 'RESTRICTED_USERS_READ_PERMISSION_TRUE';
  end if;

  if private.has_permission(
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    'audit.read'
  ) is not false then
    raise exception 'RESTRICTED_AUDIT_PERMISSION_TRUE';
  end if;

  if private.has_permission(
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    'finance.read'
  ) is not true then
    raise exception 'RESTRICTED_FINANCE_READ_PERMISSION_FALSE';
  end if;

  if private.is_module_enabled(
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    'finance'
  ) is not true then
    raise exception 'RESTRICTED_FINANCE_MODULE_FALSE';
  end if;

  if private.is_module_enabled(
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    'inventory'
  ) is not false then
    raise exception 'RESTRICTED_DISABLED_INVENTORY_MODULE_TRUE';
  end if;

  if (
    select count(*)
    from public.roles
    where tenant_id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
  ) <> 0 then
    raise exception 'RESTRICTED_CAN_READ_ROLES';
  end if;

  if (
    select count(*)
    from public.membership_roles
    where tenant_id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
  ) <> 0 then
    raise exception 'RESTRICTED_CAN_READ_MEMBERSHIP_ROLES';
  end if;

  if (
    select count(*)
    from public.role_permissions
    where tenant_id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
  ) <> 0 then
    raise exception 'RESTRICTED_CAN_READ_ROLE_PERMISSIONS';
  end if;

  if (
    select count(*)
    from public.audit_logs
    where tenant_id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
  ) <> 0 then
    raise exception 'RESTRICTED_CAN_READ_AUDIT';
  end if;

  if (
    select count(*)
    from public.tenant_modules
    where tenant_id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
  ) <> 2 then
    raise exception 'RESTRICTED_CANNOT_READ_MODULES';
  end if;

  begin
    perform 1
    from public.outbox_events
    limit 1;

    raise exception 'RESTRICTED_CAN_READ_OUTBOX';
  exception
    when insufficient_privilege then
      null;
  end;
end
$$;

rollback;

select
  'PASS - AUTHORIZATION AND MODULES' as result,
  (
    select count(*)
    from auth.users
    where id in (
      '33333333-3333-4333-8333-333333333333',
      '44444444-4444-4444-8444-444444444444'
    )
  ) as residual_test_users,
  (
    select count(*)
    from public.tenants
    where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
  ) as residual_test_tenants;