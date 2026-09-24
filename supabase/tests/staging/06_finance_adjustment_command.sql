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
  '11111111-6666-4666-8666-111111111111',
  'authenticated',
  'authenticated',
  'finance-writer-a@coost.test',
  now(),
  now()
),
(
  '11111111-7777-4777-8777-111111111111',
  'authenticated',
  'authenticated',
  'finance-reader-a-command@coost.test',
  now(),
  now()
),
(
  '33333333-6666-4666-8666-333333333333',
  'authenticated',
  'authenticated',
  'finance-disabled-writer@coost.test',
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
  '11111111-aaaa-4aaa-8aaa-111111111111',
  'Finance Command Tenant A',
  'ACTIVE'
),
(
  '22222222-bbbb-4bbb-8bbb-222222222222',
  'Finance Command Tenant B',
  'ACTIVE'
),
(
  '33333333-cccc-4ccc-8ccc-333333333333',
  'Finance Command Disabled',
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
  '11111111-1111-4111-8111-111111111111',
  '11111111-aaaa-4aaa-8aaa-111111111111',
  '11111111-6666-4666-8666-111111111111',
  'ACTIVE'
),
(
  '11111111-2222-4222-8222-111111111111',
  '11111111-aaaa-4aaa-8aaa-111111111111',
  '11111111-7777-4777-8777-111111111111',
  'ACTIVE'
),
(
  '33333333-1111-4111-8111-333333333333',
  '33333333-cccc-4ccc-8ccc-333333333333',
  '33333333-6666-4666-8666-333333333333',
  'ACTIVE'
);

-- ------------------------------------------------------------
-- ROLES
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
  '11111111-3333-4333-8333-111111111111',
  '11111111-aaaa-4aaa-8aaa-111111111111',
  'finance-writer',
  'Finance Writer',
  true
),
(
  '11111111-4444-4444-8444-111111111111',
  '11111111-aaaa-4aaa-8aaa-111111111111',
  'finance-reader',
  'Finance Reader',
  true
),
(
  '33333333-3333-4333-8333-333333333333',
  '33333333-cccc-4ccc-8ccc-333333333333',
  'finance-writer',
  'Finance Writer',
  true
);

insert into public.membership_roles (
  tenant_id,
  membership_id,
  role_id
)
values
(
  '11111111-aaaa-4aaa-8aaa-111111111111',
  '11111111-1111-4111-8111-111111111111',
  '11111111-3333-4333-8333-111111111111'
),
(
  '11111111-aaaa-4aaa-8aaa-111111111111',
  '11111111-2222-4222-8222-111111111111',
  '11111111-4444-4444-8444-111111111111'
),
(
  '33333333-cccc-4ccc-8ccc-333333333333',
  '33333333-1111-4111-8111-333333333333',
  '33333333-3333-4333-8333-333333333333'
);

-- ------------------------------------------------------------
-- PERMISSIONS
-- ------------------------------------------------------------

insert into public.role_permissions (
  tenant_id,
  role_id,
  permission_key
)
values
(
  '11111111-aaaa-4aaa-8aaa-111111111111',
  '11111111-3333-4333-8333-111111111111',
  'finance.read'
),
(
  '11111111-aaaa-4aaa-8aaa-111111111111',
  '11111111-3333-4333-8333-111111111111',
  'finance.write'
),
(
  '11111111-aaaa-4aaa-8aaa-111111111111',
  '11111111-4444-4444-8444-111111111111',
  'finance.read'
),
(
  '33333333-cccc-4ccc-8ccc-333333333333',
  '33333333-3333-4333-8333-333333333333',
  'finance.read'
),
(
  '33333333-cccc-4ccc-8ccc-333333333333',
  '33333333-3333-4333-8333-333333333333',
  'finance.write'
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
  '11111111-aaaa-4aaa-8aaa-111111111111',
  'finance',
  true
),
(
  '22222222-bbbb-4bbb-8bbb-222222222222',
  'finance',
  true
),
(
  '33333333-cccc-4ccc-8ccc-333333333333',
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
  '11111111-aaaa-4aaa-8aaa-555555555551',
  '11111111-aaaa-4aaa-8aaa-111111111111',
  'Tenant A Nakit',
  'CASH'
),
(
  '22222222-bbbb-4bbb-8bbb-555555555551',
  '22222222-bbbb-4bbb-8bbb-222222222222',
  'Tenant B Nakit',
  'CASH'
),
(
  '33333333-cccc-4ccc-8ccc-555555555551',
  '33333333-cccc-4ccc-8ccc-333333333333',
  'Disabled Tenant Nakit',
  'CASH'
);

-- ------------------------------------------------------------
-- AUTHORIZED WRITE
-- ------------------------------------------------------------

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  '11111111-6666-4666-8666-111111111111',
  true
);

do $$
declare
  v_transaction_id uuid;
  ctx jsonb;
  account_balance numeric;
begin
  v_transaction_id :=
    public.create_finance_adjustment(
      '11111111-aaaa-4aaa-8aaa-111111111111',
      '11111111-aaaa-4aaa-8aaa-555555555551',
      123.456,
      '  Opening balance  ',
      '2026-09-24 08:30:00+00'
    );

  if v_transaction_id is null then
    raise exception 'FINANCE_ADJUSTMENT_ID_NULL';
  end if;

  ctx := public.get_finance_overview(
    '11111111-aaaa-4aaa-8aaa-111111111111',
    20
  );

  select (item ->> 'balance')::numeric
  into account_balance
  from jsonb_array_elements(ctx -> 'accounts') as item
  where item ->> 'id'
    = '11111111-aaaa-4aaa-8aaa-555555555551';

  if account_balance <> 123.46 then
    raise exception
      'FINANCE_ADJUSTMENT_BALANCE_WRONG: %',
      account_balance;
  end if;

  if (
    ctx
      -> 'recentTransactions'
      -> 0
      ->> 'transactionType'
  ) <> 'ADJUSTMENT' then
    raise exception
      'FINANCE_ADJUSTMENT_OVERVIEW_TYPE_WRONG';
  end if;

  -- Zero amount must fail.
  begin
    perform public.create_finance_adjustment(
      '11111111-aaaa-4aaa-8aaa-111111111111',
      '11111111-aaaa-4aaa-8aaa-555555555551',
      0,
      'Zero adjustment',
      now()
    );

    raise exception 'ZERO_FINANCE_ADJUSTMENT_ALLOWED';
  exception
    when invalid_parameter_value then
      null;
  end;

  -- Amounts that round to zero must also fail.
  begin
    perform public.create_finance_adjustment(
      '11111111-aaaa-4aaa-8aaa-111111111111',
      '11111111-aaaa-4aaa-8aaa-555555555551',
      0.004,
      'Rounded zero adjustment',
      now()
    );

    raise exception 'ROUNDED_ZERO_FINANCE_ADJUSTMENT_ALLOWED';
  exception
    when invalid_parameter_value then
      null;
  end;

  -- Cross-tenant request must fail.
  begin
    perform public.create_finance_adjustment(
      '22222222-bbbb-4bbb-8bbb-222222222222',
      '22222222-bbbb-4bbb-8bbb-555555555551',
      50,
      'Cross tenant adjustment',
      now()
    );

    raise exception 'CROSS_TENANT_ADJUSTMENT_ALLOWED';
  exception
    when insufficient_privilege then
      null;
  end;

  -- Account from another tenant must not be accepted.
  begin
    perform public.create_finance_adjustment(
      '11111111-aaaa-4aaa-8aaa-111111111111',
      '22222222-bbbb-4bbb-8bbb-555555555551',
      50,
      'Wrong tenant account',
      now()
    );

    raise exception 'CROSS_TENANT_ACCOUNT_ALLOWED';
  exception
    when invalid_parameter_value then
      null;
  end;
end
$$;

-- Return to elevated session role for structural checks.

reset role;

do $$
declare
  v_transaction_id uuid;
begin
  select ft.id
  into v_transaction_id
  from public.finance_transactions as ft
  where ft.tenant_id =
      '11111111-aaaa-4aaa-8aaa-111111111111'
    and ft.transaction_type = 'ADJUSTMENT'
    and ft.description = 'Opening balance';

  if v_transaction_id is null then
    raise exception 'FINANCE_ADJUSTMENT_TRANSACTION_MISSING';
  end if;

  if (
    select count(*)
    from public.finance_transactions
    where tenant_id =
      '11111111-aaaa-4aaa-8aaa-111111111111'
      and transaction_type = 'ADJUSTMENT'
  ) <> 1 then
    raise exception 'FINANCE_ADJUSTMENT_TRANSACTION_COUNT_WRONG';
  end if;

  if (
    select count(*)
    from public.finance_entries
    where tenant_id =
      '11111111-aaaa-4aaa-8aaa-111111111111'
      and transaction_id = v_transaction_id
      and account_id =
        '11111111-aaaa-4aaa-8aaa-555555555551'
      and amount = 123.46
  ) <> 1 then
    raise exception 'FINANCE_ADJUSTMENT_ENTRY_WRONG';
  end if;

  if (
    select count(*)
    from public.finance_transactions
    where id = v_transaction_id
      and created_by_user_id =
        '11111111-6666-4666-8666-111111111111'
      and source_type = 'MANUAL'
      and occurred_at =
        '2026-09-24 08:30:00+00'::timestamptz
  ) <> 1 then
    raise exception 'FINANCE_ADJUSTMENT_METADATA_WRONG';
  end if;

  if (
    select count(*)
    from public.audit_logs
    where tenant_id =
        '11111111-aaaa-4aaa-8aaa-111111111111'
      and action = 'FINANCE_ADJUSTMENT_CREATED'
      and entity_type = 'finance_transaction'
      and entity_id = v_transaction_id
      and actor_user_id =
        '11111111-6666-4666-8666-111111111111'
      and metadata ->> 'accountId'
        = '11111111-aaaa-4aaa-8aaa-555555555551'
      and (metadata ->> 'amount')::numeric = 123.46
      and metadata ->> 'description' = 'Opening balance'
  ) <> 1 then
    raise exception 'FINANCE_ADJUSTMENT_AUDIT_WRONG';
  end if;
end
$$;

-- ------------------------------------------------------------
-- READ-ONLY USER CANNOT WRITE
-- ------------------------------------------------------------

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  '11111111-7777-4777-8777-111111111111',
  true
);

do $$
begin
  begin
    perform public.create_finance_adjustment(
      '11111111-aaaa-4aaa-8aaa-111111111111',
      '11111111-aaaa-4aaa-8aaa-555555555551',
      25,
      'Read only forbidden',
      now()
    );

    raise exception 'FINANCE_READ_ONLY_USER_CAN_WRITE';
  exception
    when insufficient_privilege then
      null;
  end;
end
$$;

-- ------------------------------------------------------------
-- MODULE DISABLED
-- ------------------------------------------------------------

select set_config(
  'request.jwt.claim.sub',
  '33333333-6666-4666-8666-333333333333',
  true
);

do $$
begin
  begin
    perform public.create_finance_adjustment(
      '33333333-cccc-4ccc-8ccc-333333333333',
      '33333333-cccc-4ccc-8ccc-555555555551',
      25,
      'Disabled module forbidden',
      now()
    );

    raise exception 'DISABLED_FINANCE_MODULE_CAN_WRITE';
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
    perform public.create_finance_adjustment(
      '11111111-aaaa-4aaa-8aaa-111111111111',
      '11111111-aaaa-4aaa-8aaa-555555555551',
      25,
      'Anonymous forbidden',
      now()
    );

    raise exception 'ANON_CAN_EXECUTE_FINANCE_ADJUSTMENT';
  exception
    when insufficient_privilege then
      null;
  end;
end
$$;

rollback;

select
  'PASS - FINANCE ADJUSTMENT COMMAND' as result,
  (
    select count(*)
    from auth.users
    where id in (
      '11111111-6666-4666-8666-111111111111',
      '11111111-7777-4777-8777-111111111111',
      '33333333-6666-4666-8666-333333333333'
    )
  ) as residual_test_users,
  (
    select count(*)
    from public.tenants
    where id in (
      '11111111-aaaa-4aaa-8aaa-111111111111',
      '22222222-bbbb-4bbb-8bbb-222222222222',
      '33333333-cccc-4ccc-8ccc-333333333333'
    )
  ) as residual_test_tenants;