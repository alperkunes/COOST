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
  '11111111-1111-4111-8111-111111111111',
  'authenticated',
  'authenticated',
  'rls-user-a@coost.test',
  now(),
  now()
),
(
  '22222222-2222-4222-8222-222222222222',
  'authenticated',
  'authenticated',
  'rls-user-b@coost.test',
  now(),
  now()
);

insert into public.profiles (
  id,
  display_name
)
values
(
  '11111111-1111-4111-8111-111111111111',
  'RLS User A'
),
(
  '22222222-2222-4222-8222-222222222222',
  'RLS User B'
);

insert into public.tenants (
  id,
  name,
  status
)
values
(
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'RLS Tenant A',
  'ACTIVE'
),
(
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  'RLS Tenant B',
  'ACTIVE'
);

insert into public.locations (
  id,
  tenant_id,
  name,
  status
)
values
(
  'aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'RLS Location A',
  'ACTIVE'
),
(
  'bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  'RLS Location B',
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
  'aaaaaaaa-3333-4333-8333-aaaaaaaaaaaa',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  '11111111-1111-4111-8111-111111111111',
  'ACTIVE'
),
(
  'bbbbbbbb-4444-4444-8444-bbbbbbbbbbbb',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  '22222222-2222-4222-8222-222222222222',
  'ACTIVE'
);

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  '11111111-1111-4111-8111-111111111111',
  true
);

do $$
begin
  if (
    select count(*)
    from public.tenants
    where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  ) <> 1 then
    raise exception 'USER_A_OWN_TENANT_NOT_VISIBLE';
  end if;

  if (
    select count(*)
    from public.tenants
    where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
  ) <> 0 then
    raise exception 'USER_A_CAN_SEE_TENANT_B';
  end if;

  if (
    select count(*)
    from public.locations
    where tenant_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  ) <> 1 then
    raise exception 'USER_A_OWN_LOCATION_NOT_VISIBLE';
  end if;

  if (
    select count(*)
    from public.locations
    where tenant_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
  ) <> 0 then
    raise exception 'USER_A_CAN_SEE_LOCATION_B';
  end if;

  if (
    select count(*)
    from public.profiles
    where id = '11111111-1111-4111-8111-111111111111'
  ) <> 1 then
    raise exception 'USER_A_OWN_PROFILE_NOT_VISIBLE';
  end if;

  if (
    select count(*)
    from public.profiles
    where id = '22222222-2222-4222-8222-222222222222'
  ) <> 0 then
    raise exception 'USER_A_CAN_SEE_PROFILE_B';
  end if;

  if (
    select count(*)
    from public.memberships
    where user_id = '11111111-1111-4111-8111-111111111111'
  ) <> 1 then
    raise exception 'USER_A_OWN_MEMBERSHIP_NOT_VISIBLE';
  end if;

  if (
    select count(*)
    from public.memberships
    where user_id = '22222222-2222-4222-8222-222222222222'
  ) <> 0 then
    raise exception 'USER_A_CAN_SEE_MEMBERSHIP_B';
  end if;

  if private.is_tenant_member(
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  ) is not true then
    raise exception 'USER_A_TENANT_HELPER_FALSE';
  end if;

  if private.is_tenant_member(
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
  ) is not false then
    raise exception 'USER_A_CROSS_TENANT_HELPER_TRUE';
  end if;

  begin
    insert into public.tenants (name)
    values ('AUTHENTICATED WRITE MUST FAIL');

    raise exception 'AUTHENTICATED_DIRECT_TENANT_INSERT_ALLOWED';
  exception
    when insufficient_privilege then
      null;
  end;
end
$$;

select set_config(
  'request.jwt.claim.sub',
  '22222222-2222-4222-8222-222222222222',
  true
);

do $$
begin
  if (
    select count(*)
    from public.tenants
    where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
  ) <> 1 then
    raise exception 'USER_B_OWN_TENANT_NOT_VISIBLE';
  end if;

  if (
    select count(*)
    from public.tenants
    where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  ) <> 0 then
    raise exception 'USER_B_CAN_SEE_TENANT_A';
  end if;

  if (
    select count(*)
    from public.locations
    where tenant_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
  ) <> 1 then
    raise exception 'USER_B_OWN_LOCATION_NOT_VISIBLE';
  end if;

  if (
    select count(*)
    from public.locations
    where tenant_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  ) <> 0 then
    raise exception 'USER_B_CAN_SEE_LOCATION_A';
  end if;

  if (
    select count(*)
    from public.profiles
    where id = '22222222-2222-4222-8222-222222222222'
  ) <> 1 then
    raise exception 'USER_B_OWN_PROFILE_NOT_VISIBLE';
  end if;

  if (
    select count(*)
    from public.profiles
    where id = '11111111-1111-4111-8111-111111111111'
  ) <> 0 then
    raise exception 'USER_B_CAN_SEE_PROFILE_A';
  end if;

  if private.is_tenant_member(
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
  ) is not true then
    raise exception 'USER_B_TENANT_HELPER_FALSE';
  end if;

  if private.is_tenant_member(
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  ) is not false then
    raise exception 'USER_B_CROSS_TENANT_HELPER_TRUE';
  end if;
end
$$;

rollback;

select
  'PASS - TENANT ISOLATION' as result,
  (
    select count(*)
    from auth.users
    where id in (
      '11111111-1111-4111-8111-111111111111',
      '22222222-2222-4222-8222-222222222222'
    )
  ) as residual_test_users,
  (
    select count(*)
    from public.tenants
    where id in (
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
    )
  ) as residual_test_tenants;