begin;

-- ------------------------------------------------------------
-- USERS
-- ------------------------------------------------------------

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
  'aaaaaaaa-6666-4666-8666-aaaaaaaaaaaa',
  'authenticated',
  'authenticated',
  'finance-overview-reader@coost.test',
  now(),
  now()
),
(
  'aaaaaaaa-7777-4777-8777-aaaaaaaaaaaa',
  'authenticated',
  'authenticated',
  'finance-overview-no-permission@coost.test',
  now(),
  now()
),
(
  'bbbbbbbb-6666-4666-8666-bbbbbbbbbbbb',
  'authenticated',
  'authenticated',
  'finance-overview-other-tenant@coost.test',
  now(),
  now()
),
(
  'cccccccc-6666-4666-8666-cccccccccccc',
  'authenticated',
  'authenticated',
  'finance-overview-disabled-module@coost.test',
  now(),
  now()
);

-- ------------------------------------------------------------
-- TENANTS
-- ------------------------------------------------------------

insert into public.tenants (
  id,
  name,
  status
)
values
(
  'aaaaaaaa-aaaa-4aaa-8aaa-111111111111',
  'Finance Overview Tenant A',
  'ACTIVE'
),
(
  'bbbbbbbb-bbbb-4bbb-8bbb-111111111111',
  'Finance Overview Tenant B',
  'ACTIVE'
),
(
  'cccccccc-cccc-4ccc-8ccc-111111111111',
  'Finance Overview Disabled',
  'ACTIVE'
);

-- ------------------------------------------------------------
-- MEMBERSHIPS
-- ------------------------------------------------------------

insert into public.memberships (
  id,
  tenant_id,
  user_id,
  status
)
values
(
  'aaaaaaaa-1111-4111-8111-222222222222',
  'aaaaaaaa-aaaa-4aaa-8aaa-111111111111',
  'aaaaaaaa-6666-4666-8666-aaaaaaaaaaaa',
  'ACTIVE'
),
(
  'aaaaaaaa-2222-4222-8222-222222222222',
  'aaaaaaaa-aaaa-4aaa-8aaa-111111111111',
  'aaaaaaaa-7777-4777-8777-aaaaaaaaaaaa',
  'ACTIVE'
),
(
  'bbbbbbbb-1111-4111-8111-222222222222',
  'bbbbbbbb-bbbb-4bbb-8bbb-111111111111',
  'bbbbbbbb-6666-4666-8666-bbbbbbbbbbbb',
  'ACTIVE'
),
(
  'cccccccc-1111-4111-8111-222222222222',
  'cccccccc-cccc-4ccc-8ccc-111111111111',
  'cccccccc-6666-4666-8666-cccccccccccc',
  'ACTIVE'
);

-- ------------------------------------------------------------
-- ROLES + PERMISSIONS
-- ------------------------------------------------------------

insert into public.roles (
  id,
  tenant_id,
  key,
  name,
  is_system
)
values
(
  'aaaaaaaa-3333-4333-8333-222222222222',
  'aaaaaaaa-aaaa-4aaa-8aaa-111111111111',
  'finance-reader',
  'Finance Reader',
  true
),
(
  'bbbbbbbb-3333-4333-8333-222222222222',
  'bbbbbbbb-bbbb-4bbb-8bbb-111111111111',
  'finance-reader',
  'Finance Reader',
  true
),
(
  'cccccccc-3333-4333-8333-222222222222',
  'cccccccc-cccc-4ccc-8ccc-111111111111',
  'finance-reader',
  'Finance Reader',
  true
);

insert into public.membership_roles (
  tenant_id,
  membership_id,
  role_id
)
values
(
  'aaaaaaaa-aaaa-4aaa-8aaa-111111111111',
  'aaaaaaaa-1111-4111-8111-222222222222',
  'aaaaaaaa-3333-4333-8333-222222222222'
),
(
  'bbbbbbbb-bbbb-4bbb-8bbb-111111111111',
  'bbbbbbbb-1111-4111-8111-222222222222',
  'bbbbbbbb-3333-4333-8333-222222222222'
),
(
  'cccccccc-cccc-4ccc-8ccc-111111111111',
  'cccccccc-1111-4111-8111-222222222222',
  'cccccccc-3333-4333-8333-222222222222'
);

insert into public.role_permissions (
  tenant_id,
  role_id,
  permission_key
)
values
(
  'aaaaaaaa-aaaa-4aaa-8aaa-111111111111',
  'aaaaaaaa-3333-4333-8333-222222222222',
  'finance.read'
),
(
  'bbbbbbbb-bbbb-4bbb-8bbb-111111111111',
  'bbbbbbbb-3333-4333-8333-222222222222',
  'finance.read'
),
(
  'cccccccc-cccc-4ccc-8ccc-111111111111',
  'cccccccc-3333-4333-8333-222222222222',
  'finance.read'
);

-- ------------------------------------------------------------
-- MODULES
-- ------------------------------------------------------------

insert into public.tenant_modules (
  tenant_id,
  module_key,
  enabled
)
values
(
  'aaaaaaaa-aaaa-4aaa-8aaa-111111111111',
  'finance',
  true
),
(
  'bbbbbbbb-bbbb-4bbb-8bbb-111111111111',
  'finance',
  true
),
(
  'cccccccc-cccc-4ccc-8ccc-111111111111',
  'finance',
  false
);

-- ------------------------------------------------------------
-- ACCOUNTS
-- ------------------------------------------------------------

insert into public.finance_accounts (
  id,
  tenant_id,
  name,
  account_type
)
values
(
  'aaaaaaaa-aaaa-4aaa-8aaa-333333333331',
  'aaaaaaaa-aaaa-4aaa-8aaa-111111111111',
  'Nakit',
  'CASH'
),
(
  'aaaaaaaa-aaaa-4aaa-8aaa-333333333332',
  'aaaaaaaa-aaaa-4aaa-8aaa-111111111111',
  'Ziraat',
  'BANK'
),
(
  'bbbbbbbb-bbbb-4bbb-8bbb-333333333331',
  'bbbbbbbb-bbbb-4bbb-8bbb-111111111111',
  'Tenant B Bank',
  'BANK'
);

-- ------------------------------------------------------------
-- TRANSACTIONS + ENTRIES - TENANT A
-- ------------------------------------------------------------

insert into public.finance_transactions (
  id,
  tenant_id,
  transaction_type,
  occurred_at,
  description,
  created_by_user_id
)
values
(
  'aaaaaaaa-aaaa-4aaa-8aaa-444444444441',
  'aaaaaaaa-aaaa-4aaa-8aaa-111111111111',
  'INCOME',
  '2026-09-24 08:00:00+00',
  'Opening income',
  'aaaaaaaa-6666-4666-8666-aaaaaaaaaaaa'
),
(
  'aaaaaaaa-aaaa-4aaa-8aaa-444444444442',
  'aaaaaaaa-aaaa-4aaa-8aaa-111111111111',
  'EXPENSE',
  '2026-09-24 09:00:00+00',
  'Test expense',
  'aaaaaaaa-6666-4666-8666-aaaaaaaaaaaa'
),
(
  'aaaaaaaa-aaaa-4aaa-8aaa-444444444443',
  'aaaaaaaa-aaaa-4aaa-8aaa-111111111111',
  'TRANSFER',
  '2026-09-24 10:00:00+00',
  'Cash to Ziraat',
  'aaaaaaaa-6666-4666-8666-aaaaaaaaaaaa'
);

insert into public.finance_entries (
  tenant_id,
  transaction_id,
  account_id,
  amount
)
values
(
  'aaaaaaaa-aaaa-4aaa-8aaa-111111111111',
  'aaaaaaaa-aaaa-4aaa-8aaa-444444444441',
  'aaaaaaaa-aaaa-4aaa-8aaa-333333333331',
  1000.00
),
(
  'aaaaaaaa-aaaa-4aaa-8aaa-111111111111',
  'aaaaaaaa-aaaa-4aaa-8aaa-444444444442',
  'aaaaaaaa-aaaa-4aaa-8aaa-333333333331',
  -300.00
),
(
  'aaaaaaaa-aaaa-4aaa-8aaa-111111111111',
  'aaaaaaaa-aaaa-4aaa-8aaa-444444444443',
  'aaaaaaaa-aaaa-4aaa-8aaa-333333333331',
  -200.00
),
(
  'aaaaaaaa-aaaa-4aaa-8aaa-111111111111',
  'aaaaaaaa-aaaa-4aaa-8aaa-444444444443',
  'aaaaaaaa-aaaa-4aaa-8aaa-333333333332',
  200.00
);

-- Tenant B data proves isolation.

insert into public.finance_transactions (
  id,
  tenant_id,
  transaction_type,
  occurred_at,
  description,
  created_by_user_id
)
values
(
  'bbbbbbbb-bbbb-4bbb-8bbb-444444444441',
  'bbbbbbbb-bbbb-4bbb-8bbb-111111111111',
  'INCOME',
  '2026-09-24 11:00:00+00',
  'Tenant B income',
  'bbbbbbbb-6666-4666-8666-bbbbbbbbbbbb'
);

insert into public.finance_entries (
  tenant_id,
  transaction_id,
  account_id,
  amount
)
values
(
  'bbbbbbbb-bbbb-4bbb-8bbb-111111111111',
  'bbbbbbbb-bbbb-4bbb-8bbb-444444444441',
  'bbbbbbbb-bbbb-4bbb-8bbb-333333333331',
  9000.00
);

-- ------------------------------------------------------------
-- AUTHORIZED USER
-- ------------------------------------------------------------

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'aaaaaaaa-6666-4666-8666-aaaaaaaaaaaa',
  true
);

do $$
declare
  ctx jsonb;
  cash_balance numeric;
  bank_balance numeric;
begin
  ctx := public.get_finance_overview(
    'aaaaaaaa-aaaa-4aaa-8aaa-111111111111',
    2
  );

  if ctx ->> 'tenantId'
    <> 'aaaaaaaa-aaaa-4aaa-8aaa-111111111111' then
    raise exception 'FINANCE_OVERVIEW_WRONG_TENANT';
  end if;

  if jsonb_array_length(ctx -> 'accounts') <> 2 then
    raise exception 'FINANCE_OVERVIEW_ACCOUNT_COUNT_WRONG';
  end if;

  select (item ->> 'balance')::numeric
  into cash_balance
  from jsonb_array_elements(ctx -> 'accounts') as item
  where item ->> 'name' = 'Nakit';

  select (item ->> 'balance')::numeric
  into bank_balance
  from jsonb_array_elements(ctx -> 'accounts') as item
  where item ->> 'name' = 'Ziraat';

  if cash_balance <> 500.00 then
    raise exception
      'FINANCE_OVERVIEW_CASH_BALANCE_WRONG: %',
      cash_balance;
  end if;

  if bank_balance <> 200.00 then
    raise exception
      'FINANCE_OVERVIEW_BANK_BALANCE_WRONG: %',
      bank_balance;
  end if;

  if jsonb_array_length(
    ctx -> 'recentTransactions'
  ) <> 2 then
    raise exception 'FINANCE_OVERVIEW_LIMIT_WRONG';
  end if;

  if (
    ctx
      -> 'recentTransactions'
      -> 0
      ->> 'transactionType'
  ) <> 'TRANSFER' then
    raise exception 'FINANCE_OVERVIEW_ORDER_WRONG';
  end if;

  if jsonb_array_length(
    ctx
      -> 'recentTransactions'
      -> 0
      -> 'entries'
  ) <> 2 then
    raise exception 'FINANCE_OVERVIEW_TRANSFER_ENTRIES_WRONG';
  end if;

  -- Limit 0 must be clamped to 1.
  ctx := public.get_finance_overview(
    'aaaaaaaa-aaaa-4aaa-8aaa-111111111111',
    0
  );

  if jsonb_array_length(
    ctx -> 'recentTransactions'
  ) <> 1 then
    raise exception 'FINANCE_OVERVIEW_MIN_LIMIT_NOT_CLAMPED';
  end if;

  -- Cross-tenant request must fail.
  begin
    perform public.get_finance_overview(
      'bbbbbbbb-bbbb-4bbb-8bbb-111111111111',
      20
    );

    raise exception 'FINANCE_OVERVIEW_CROSS_TENANT_ALLOWED';
  exception
    when insufficient_privilege then
      null;
  end;
end
$$;

-- ------------------------------------------------------------
-- SAME TENANT, NO finance.read
-- ------------------------------------------------------------

select set_config(
  'request.jwt.claim.sub',
  'aaaaaaaa-7777-4777-8777-aaaaaaaaaaaa',
  true
);

do $$
begin
  begin
    perform public.get_finance_overview(
      'aaaaaaaa-aaaa-4aaa-8aaa-111111111111',
      20
    );

    raise exception 'FINANCE_OVERVIEW_NO_PERMISSION_ALLOWED';
  exception
    when insufficient_privilege then
      null;
  end;
end
$$;

-- ------------------------------------------------------------
-- PERMISSION EXISTS BUT MODULE DISABLED
-- ------------------------------------------------------------

select set_config(
  'request.jwt.claim.sub',
  'cccccccc-6666-4666-8666-cccccccccccc',
  true
);

do $$
begin
  begin
    perform public.get_finance_overview(
      'cccccccc-cccc-4ccc-8ccc-111111111111',
      20
    );

    raise exception 'FINANCE_OVERVIEW_DISABLED_MODULE_ALLOWED';
  exception
    when insufficient_privilege then
      null;
  end;
end
$$;

-- ------------------------------------------------------------
-- ANON CANNOT EXECUTE
-- ------------------------------------------------------------

set local role anon;

do $$
begin
  begin
    perform public.get_finance_overview(
      'aaaaaaaa-aaaa-4aaa-8aaa-111111111111',
      20
    );

    raise exception 'ANON_CAN_EXECUTE_FINANCE_OVERVIEW';
  exception
    when insufficient_privilege then
      null;
  end;
end
$$;

rollback;

select
  'PASS - FINANCE OVERVIEW RPC' as result,
  (
    select count(*)
    from auth.users
    where id in (
      'aaaaaaaa-6666-4666-8666-aaaaaaaaaaaa',
      'aaaaaaaa-7777-4777-8777-aaaaaaaaaaaa',
      'bbbbbbbb-6666-4666-8666-bbbbbbbbbbbb',
      'cccccccc-6666-4666-8666-cccccccccccc'
    )
  ) as residual_test_users,
  (
    select count(*)
    from public.tenants
    where id in (
      'aaaaaaaa-aaaa-4aaa-8aaa-111111111111',
      'bbbbbbbb-bbbb-4bbb-8bbb-111111111111',
      'cccccccc-cccc-4ccc-8ccc-111111111111'
    )
  ) as residual_test_tenants;