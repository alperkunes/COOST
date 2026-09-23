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
  '66666666-6666-4666-8666-666666666666',
  'authenticated',
  'authenticated',
  'finance-reader-a@coost.test',
  now(),
  now()
),
(
  '77777777-7777-4777-8777-777777777777',
  'authenticated',
  'authenticated',
  'finance-no-permission-a@coost.test',
  now(),
  now()
),
(
  '88888888-8888-4888-8888-888888888888',
  'authenticated',
  'authenticated',
  'finance-reader-b@coost.test',
  now(),
  now()
),
(
  '99999999-9999-4999-8999-999999999999',
  'authenticated',
  'authenticated',
  'finance-disabled-module@coost.test',
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
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  'Finance Tenant A',
  'ACTIVE'
),
(
  'ffffffff-ffff-4fff-8fff-ffffffffffff',
  'Finance Tenant B',
  'ACTIVE'
),
(
  '99999999-aaaa-4aaa-8aaa-999999999999',
  'Finance Tenant Disabled',
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
  'eeeeeeee-1111-4111-8111-eeeeeeeeeeee',
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  '66666666-6666-4666-8666-666666666666',
  'ACTIVE'
),
(
  'eeeeeeee-2222-4222-8222-eeeeeeeeeeee',
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  '77777777-7777-4777-8777-777777777777',
  'ACTIVE'
),
(
  'ffffffff-1111-4111-8111-ffffffffffff',
  'ffffffff-ffff-4fff-8fff-ffffffffffff',
  '88888888-8888-4888-8888-888888888888',
  'ACTIVE'
),
(
  '99999999-1111-4111-8111-999999999999',
  '99999999-aaaa-4aaa-8aaa-999999999999',
  '99999999-9999-4999-8999-999999999999',
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
  'eeeeeeee-3333-4333-8333-eeeeeeeeeeee',
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  'finance-reader',
  'Finance Reader',
  true
),
(
  'ffffffff-3333-4333-8333-ffffffffffff',
  'ffffffff-ffff-4fff-8fff-ffffffffffff',
  'finance-reader',
  'Finance Reader',
  true
),
(
  '99999999-3333-4333-8333-999999999999',
  '99999999-aaaa-4aaa-8aaa-999999999999',
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
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  'eeeeeeee-1111-4111-8111-eeeeeeeeeeee',
  'eeeeeeee-3333-4333-8333-eeeeeeeeeeee'
),
(
  'ffffffff-ffff-4fff-8fff-ffffffffffff',
  'ffffffff-1111-4111-8111-ffffffffffff',
  'ffffffff-3333-4333-8333-ffffffffffff'
),
(
  '99999999-aaaa-4aaa-8aaa-999999999999',
  '99999999-1111-4111-8111-999999999999',
  '99999999-3333-4333-8333-999999999999'
);

insert into public.role_permissions (
  tenant_id,
  role_id,
  permission_key
)
values
(
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  'eeeeeeee-3333-4333-8333-eeeeeeeeeeee',
  'finance.read'
),
(
  'ffffffff-ffff-4fff-8fff-ffffffffffff',
  'ffffffff-3333-4333-8333-ffffffffffff',
  'finance.read'
),
(
  '99999999-aaaa-4aaa-8aaa-999999999999',
  '99999999-3333-4333-8333-999999999999',
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
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  'finance',
  true
),
(
  'ffffffff-ffff-4fff-8fff-ffffffffffff',
  'finance',
  true
),
(
  '99999999-aaaa-4aaa-8aaa-999999999999',
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
  'eeeeeeee-aaaa-4aaa-8aaa-eeeeeeee0001',
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  'Nakit',
  'CASH'
),
(
  'eeeeeeee-aaaa-4aaa-8aaa-eeeeeeee0002',
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  'Ziraat',
  'BANK'
),
(
  'ffffffff-aaaa-4aaa-8aaa-ffffffff0001',
  'ffffffff-ffff-4fff-8fff-ffffffffffff',
  'Tenant B Nakit',
  'CASH'
),
(
  '99999999-bbbb-4bbb-8bbb-999999999999',
  '99999999-aaaa-4aaa-8aaa-999999999999',
  'Disabled Tenant Nakit',
  'CASH'
);

-- ------------------------------------------------------------
-- TRANSACTIONS - TENANT A
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
  'eeeeeeee-bbbb-4bbb-8bbb-eeeeeeee0001',
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  'INCOME',
  now(),
  'Test income',
  '66666666-6666-4666-8666-666666666666'
),
(
  'eeeeeeee-bbbb-4bbb-8bbb-eeeeeeee0002',
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  'EXPENSE',
  now(),
  'Test expense',
  '66666666-6666-4666-8666-666666666666'
),
(
  'eeeeeeee-bbbb-4bbb-8bbb-eeeeeeee0003',
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  'TRANSFER',
  now(),
  'Cash to bank',
  '66666666-6666-4666-8666-666666666666'
);

insert into public.finance_entries (
  tenant_id,
  transaction_id,
  account_id,
  amount
)
values
(
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  'eeeeeeee-bbbb-4bbb-8bbb-eeeeeeee0001',
  'eeeeeeee-aaaa-4aaa-8aaa-eeeeeeee0001',
  1000.00
),
(
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  'eeeeeeee-bbbb-4bbb-8bbb-eeeeeeee0002',
  'eeeeeeee-aaaa-4aaa-8aaa-eeeeeeee0001',
  -300.00
),
(
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  'eeeeeeee-bbbb-4bbb-8bbb-eeeeeeee0003',
  'eeeeeeee-aaaa-4aaa-8aaa-eeeeeeee0001',
  -200.00
),
(
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  'eeeeeeee-bbbb-4bbb-8bbb-eeeeeeee0003',
  'eeeeeeee-aaaa-4aaa-8aaa-eeeeeeee0002',
  200.00
);

-- Tenant B data.

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
  'ffffffff-bbbb-4bbb-8bbb-ffffffff0001',
  'ffffffff-ffff-4fff-8fff-ffffffffffff',
  'INCOME',
  now(),
  'Tenant B income',
  '88888888-8888-4888-8888-888888888888'
);

insert into public.finance_entries (
  tenant_id,
  transaction_id,
  account_id,
  amount
)
values
(
  'ffffffff-ffff-4fff-8fff-ffffffffffff',
  'ffffffff-bbbb-4bbb-8bbb-ffffffff0001',
  'ffffffff-aaaa-4aaa-8aaa-ffffffff0001',
  900.00
);

-- Disabled-module tenant data.

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
  '99999999-cccc-4ccc-8ccc-999999999999',
  '99999999-aaaa-4aaa-8aaa-999999999999',
  'INCOME',
  now(),
  'Disabled module income',
  '99999999-9999-4999-8999-999999999999'
);

insert into public.finance_entries (
  tenant_id,
  transaction_id,
  account_id,
  amount
)
values
(
  '99999999-aaaa-4aaa-8aaa-999999999999',
  '99999999-cccc-4ccc-8ccc-999999999999',
  '99999999-bbbb-4bbb-8bbb-999999999999',
  500.00
);

-- ------------------------------------------------------------
-- RELATIONAL INTEGRITY
-- A transaction in Tenant A must not use an account in Tenant B.
-- ------------------------------------------------------------

do $$
begin
  begin
    insert into public.finance_entries (
      tenant_id,
      transaction_id,
      account_id,
      amount
    )
    values (
      'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
      'eeeeeeee-bbbb-4bbb-8bbb-eeeeeeee0001',
      'ffffffff-aaaa-4aaa-8aaa-ffffffff0001',
      1.00
    );

    raise exception 'CROSS_TENANT_FINANCE_ENTRY_ALLOWED';
  exception
    when foreign_key_violation then
      null;
  end;
end
$$;

-- ------------------------------------------------------------
-- READER A
-- ------------------------------------------------------------

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  '66666666-6666-4666-8666-666666666666',
  true
);

do $$
declare
  cash_balance numeric(16,2);
  bank_balance numeric(16,2);
begin
  if (
    select count(*)
    from public.finance_accounts
    where tenant_id = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'
  ) <> 2 then
    raise exception 'FINANCE_READER_A_CANNOT_READ_ACCOUNTS';
  end if;

  if (
    select count(*)
    from public.finance_transactions
    where tenant_id = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'
  ) <> 3 then
    raise exception 'FINANCE_READER_A_CANNOT_READ_TRANSACTIONS';
  end if;

  if (
    select count(*)
    from public.finance_entries
    where tenant_id = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'
  ) <> 4 then
    raise exception 'FINANCE_READER_A_CANNOT_READ_ENTRIES';
  end if;

  if (
    select count(*)
    from public.finance_accounts
    where tenant_id = 'ffffffff-ffff-4fff-8fff-ffffffffffff'
  ) <> 0 then
    raise exception 'FINANCE_READER_A_CAN_READ_TENANT_B';
  end if;

  select coalesce(sum(amount), 0)
  into cash_balance
  from public.finance_entries
  where account_id = 'eeeeeeee-aaaa-4aaa-8aaa-eeeeeeee0001';

  select coalesce(sum(amount), 0)
  into bank_balance
  from public.finance_entries
  where account_id = 'eeeeeeee-aaaa-4aaa-8aaa-eeeeeeee0002';

  if cash_balance <> 500.00 then
    raise exception 'FINANCE_CASH_BALANCE_WRONG: %', cash_balance;
  end if;

  if bank_balance <> 200.00 then
    raise exception 'FINANCE_BANK_BALANCE_WRONG: %', bank_balance;
  end if;

  begin
    insert into public.finance_accounts (
      tenant_id,
      name,
      account_type
    )
    values (
      'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
      'Forbidden Browser Account',
      'CASH'
    );

    raise exception 'FINANCE_BROWSER_DIRECT_WRITE_ALLOWED';
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
  '77777777-7777-4777-8777-777777777777',
  true
);

do $$
begin
  if (
    select count(*)
    from public.finance_accounts
    where tenant_id = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'
  ) <> 0 then
    raise exception 'NO_PERMISSION_USER_CAN_READ_FINANCE_ACCOUNTS';
  end if;

  if (
    select count(*)
    from public.finance_transactions
    where tenant_id = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'
  ) <> 0 then
    raise exception 'NO_PERMISSION_USER_CAN_READ_FINANCE_TRANSACTIONS';
  end if;

  if (
    select count(*)
    from public.finance_entries
    where tenant_id = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'
  ) <> 0 then
    raise exception 'NO_PERMISSION_USER_CAN_READ_FINANCE_ENTRIES';
  end if;
end
$$;

-- ------------------------------------------------------------
-- READER B - PROVE TENANT ISOLATION IN THE OTHER DIRECTION
-- ------------------------------------------------------------

select set_config(
  'request.jwt.claim.sub',
  '88888888-8888-4888-8888-888888888888',
  true
);

do $$
begin
  if (
    select count(*)
    from public.finance_accounts
    where tenant_id = 'ffffffff-ffff-4fff-8fff-ffffffffffff'
  ) <> 1 then
    raise exception 'FINANCE_READER_B_CANNOT_READ_OWN_ACCOUNT';
  end if;

  if (
    select count(*)
    from public.finance_accounts
    where tenant_id = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'
  ) <> 0 then
    raise exception 'FINANCE_READER_B_CAN_READ_TENANT_A';
  end if;
end
$$;

-- ------------------------------------------------------------
-- PERMISSION EXISTS BUT MODULE IS DISABLED
-- ------------------------------------------------------------

select set_config(
  'request.jwt.claim.sub',
  '99999999-9999-4999-8999-999999999999',
  true
);

do $$
begin
  if private.has_permission(
    '99999999-aaaa-4aaa-8aaa-999999999999',
    'finance.read'
  ) is not true then
    raise exception 'DISABLED_MODULE_USER_PERMISSION_MISSING';
  end if;

  if private.is_module_enabled(
    '99999999-aaaa-4aaa-8aaa-999999999999',
    'finance'
  ) is not false then
    raise exception 'FINANCE_MODULE_SHOULD_BE_DISABLED';
  end if;

  if (
    select count(*)
    from public.finance_accounts
    where tenant_id = '99999999-aaaa-4aaa-8aaa-999999999999'
  ) <> 0 then
    raise exception 'DISABLED_MODULE_USER_CAN_READ_FINANCE';
  end if;
end
$$;

-- ------------------------------------------------------------
-- ANON MUST HAVE NO TABLE ACCESS
-- ------------------------------------------------------------

set local role anon;

do $$
begin
  begin
    perform 1
    from public.finance_accounts
    limit 1;

    raise exception 'ANON_CAN_READ_FINANCE_ACCOUNTS';
  exception
    when insufficient_privilege then
      null;
  end;
end
$$;

rollback;

select
  'PASS - FINANCE FOUNDATION' as result,
  (
    select count(*)
    from auth.users
    where id in (
      '66666666-6666-4666-8666-666666666666',
      '77777777-7777-4777-8777-777777777777',
      '88888888-8888-4888-8888-888888888888',
      '99999999-9999-4999-8999-999999999999'
    )
  ) as residual_test_users,
  (
    select count(*)
    from public.tenants
    where id in (
      'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
      'ffffffff-ffff-4fff-8fff-ffffffffffff',
      '99999999-aaaa-4aaa-8aaa-999999999999'
    )
  ) as residual_test_tenants;