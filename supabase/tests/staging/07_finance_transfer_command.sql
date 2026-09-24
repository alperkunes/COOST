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
  '41111111-6666-4666-8666-111111111111',
  'authenticated',
  'authenticated',
  'transfer-writer@coost.test',
  now(),
  now()
),
(
  '41111111-7777-4777-8777-111111111111',
  'authenticated',
  'authenticated',
  'transfer-reader@coost.test',
  now(),
  now()
),
(
  '43333333-6666-4666-8666-333333333333',
  'authenticated',
  'authenticated',
  'transfer-disabled@coost.test',
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
  '41111111-aaaa-4aaa-8aaa-111111111111',
  'Transfer Tenant A',
  'ACTIVE'
),
(
  '42222222-bbbb-4bbb-8bbb-222222222222',
  'Transfer Tenant B',
  'ACTIVE'
),
(
  '43333333-cccc-4ccc-8ccc-333333333333',
  'Transfer Disabled Tenant',
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
  '41111111-1111-4111-8111-111111111111',
  '41111111-aaaa-4aaa-8aaa-111111111111',
  '41111111-6666-4666-8666-111111111111',
  'ACTIVE'
),
(
  '41111111-2222-4222-8222-111111111111',
  '41111111-aaaa-4aaa-8aaa-111111111111',
  '41111111-7777-4777-8777-111111111111',
  'ACTIVE'
),
(
  '43333333-1111-4111-8111-333333333333',
  '43333333-cccc-4ccc-8ccc-333333333333',
  '43333333-6666-4666-8666-333333333333',
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
  '41111111-3333-4333-8333-111111111111',
  '41111111-aaaa-4aaa-8aaa-111111111111',
  'finance-writer',
  'Finance Writer',
  true
),
(
  '41111111-4444-4444-8444-111111111111',
  '41111111-aaaa-4aaa-8aaa-111111111111',
  'finance-reader',
  'Finance Reader',
  true
),
(
  '43333333-3333-4333-8333-333333333333',
  '43333333-cccc-4ccc-8ccc-333333333333',
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
  '41111111-aaaa-4aaa-8aaa-111111111111',
  '41111111-1111-4111-8111-111111111111',
  '41111111-3333-4333-8333-111111111111'
),
(
  '41111111-aaaa-4aaa-8aaa-111111111111',
  '41111111-2222-4222-8222-111111111111',
  '41111111-4444-4444-8444-111111111111'
),
(
  '43333333-cccc-4ccc-8ccc-333333333333',
  '43333333-1111-4111-8111-333333333333',
  '43333333-3333-4333-8333-333333333333'
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
  '41111111-aaaa-4aaa-8aaa-111111111111',
  '41111111-3333-4333-8333-111111111111',
  'finance.read'
),
(
  '41111111-aaaa-4aaa-8aaa-111111111111',
  '41111111-3333-4333-8333-111111111111',
  'finance.write'
),
(
  '41111111-aaaa-4aaa-8aaa-111111111111',
  '41111111-4444-4444-8444-111111111111',
  'finance.read'
),
(
  '43333333-cccc-4ccc-8ccc-333333333333',
  '43333333-3333-4333-8333-333333333333',
  'finance.read'
),
(
  '43333333-cccc-4ccc-8ccc-333333333333',
  '43333333-3333-4333-8333-333333333333',
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
  '41111111-aaaa-4aaa-8aaa-111111111111',
  'finance',
  true
),
(
  '42222222-bbbb-4bbb-8bbb-222222222222',
  'finance',
  true
),
(
  '43333333-cccc-4ccc-8ccc-333333333333',
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
  account_type,
  currency_code
)
values
(
  '41111111-aaaa-4aaa-8aaa-555555555551',
  '41111111-aaaa-4aaa-8aaa-111111111111',
  'Tenant A Ziraat',
  'BANK',
  'TRY'
),
(
  '41111111-aaaa-4aaa-8aaa-555555555552',
  '41111111-aaaa-4aaa-8aaa-111111111111',
  'Tenant A Nakit',
  'CASH',
  'TRY'
),
(
  '41111111-aaaa-4aaa-8aaa-555555555553',
  '41111111-aaaa-4aaa-8aaa-111111111111',
  'Tenant A USD Bank',
  'BANK',
  'USD'
),
(
  '42222222-bbbb-4bbb-8bbb-555555555551',
  '42222222-bbbb-4bbb-8bbb-222222222222',
  'Tenant B Nakit',
  'CASH',
  'TRY'
),
(
  '43333333-cccc-4ccc-8ccc-555555555551',
  '43333333-cccc-4ccc-8ccc-333333333333',
  'Disabled Bank',
  'BANK',
  'TRY'
),
(
  '43333333-cccc-4ccc-8ccc-555555555552',
  '43333333-cccc-4ccc-8ccc-333333333333',
  'Disabled Cash',
  'CASH',
  'TRY'
);

-- ------------------------------------------------------------
-- AUTHORIZED TRANSFER
-- ------------------------------------------------------------

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  '41111111-6666-4666-8666-111111111111',
  true
);

do $$
declare
  v_transaction_id uuid;
  v_overview jsonb;
  v_from_balance numeric;
  v_to_balance numeric;
begin
  v_transaction_id :=
    public.create_finance_transfer(
      '41111111-aaaa-4aaa-8aaa-111111111111',
      '41111111-aaaa-4aaa-8aaa-555555555551',
      '41111111-aaaa-4aaa-8aaa-555555555552',
      250.556,
      '  Ziraat to cash transfer  ',
      '2026-09-24 09:45:00+00'
    );

  if v_transaction_id is null then
    raise exception 'FINANCE_TRANSFER_ID_NULL';
  end if;

  v_overview := public.get_finance_overview(
    '41111111-aaaa-4aaa-8aaa-111111111111',
    20
  );

  select (item ->> 'balance')::numeric
  into v_from_balance
  from jsonb_array_elements(
    v_overview -> 'accounts'
  ) as item
  where item ->> 'id'
    = '41111111-aaaa-4aaa-8aaa-555555555551';

  select (item ->> 'balance')::numeric
  into v_to_balance
  from jsonb_array_elements(
    v_overview -> 'accounts'
  ) as item
  where item ->> 'id'
    = '41111111-aaaa-4aaa-8aaa-555555555552';

  if v_from_balance <> -250.56 then
    raise exception
      'FINANCE_TRANSFER_FROM_BALANCE_WRONG: %',
      v_from_balance;
  end if;

  if v_to_balance <> 250.56 then
    raise exception
      'FINANCE_TRANSFER_TO_BALANCE_WRONG: %',
      v_to_balance;
  end if;

  if (
    v_overview
      -> 'recentTransactions'
      -> 0
      ->> 'transactionType'
  ) <> 'TRANSFER' then
    raise exception 'FINANCE_TRANSFER_OVERVIEW_TYPE_WRONG';
  end if;

  if jsonb_array_length(
    v_overview
      -> 'recentTransactions'
      -> 0
      -> 'entries'
  ) <> 2 then
    raise exception 'FINANCE_TRANSFER_OVERVIEW_ENTRY_COUNT_WRONG';
  end if;

  -- Same source and destination must fail.
  begin
    perform public.create_finance_transfer(
      '41111111-aaaa-4aaa-8aaa-111111111111',
      '41111111-aaaa-4aaa-8aaa-555555555551',
      '41111111-aaaa-4aaa-8aaa-555555555551',
      10,
      'Same account forbidden',
      now()
    );

    raise exception 'SAME_ACCOUNT_TRANSFER_ALLOWED';
  exception
    when invalid_parameter_value then
      null;
  end;

  -- Zero amount must fail.
  begin
    perform public.create_finance_transfer(
      '41111111-aaaa-4aaa-8aaa-111111111111',
      '41111111-aaaa-4aaa-8aaa-555555555551',
      '41111111-aaaa-4aaa-8aaa-555555555552',
      0,
      'Zero transfer forbidden',
      now()
    );

    raise exception 'ZERO_TRANSFER_ALLOWED';
  exception
    when invalid_parameter_value then
      null;
  end;

  -- Negative amount must fail.
  begin
    perform public.create_finance_transfer(
      '41111111-aaaa-4aaa-8aaa-111111111111',
      '41111111-aaaa-4aaa-8aaa-555555555551',
      '41111111-aaaa-4aaa-8aaa-555555555552',
      -10,
      'Negative transfer forbidden',
      now()
    );

    raise exception 'NEGATIVE_TRANSFER_ALLOWED';
  exception
    when invalid_parameter_value then
      null;
  end;

  -- Amounts that round to zero must fail.
  begin
    perform public.create_finance_transfer(
      '41111111-aaaa-4aaa-8aaa-111111111111',
      '41111111-aaaa-4aaa-8aaa-555555555551',
      '41111111-aaaa-4aaa-8aaa-555555555552',
      0.004,
      'Rounded zero transfer forbidden',
      now()
    );

    raise exception 'ROUNDED_ZERO_TRANSFER_ALLOWED';
  exception
    when invalid_parameter_value then
      null;
  end;

  -- Different currencies must fail.
  begin
    perform public.create_finance_transfer(
      '41111111-aaaa-4aaa-8aaa-111111111111',
      '41111111-aaaa-4aaa-8aaa-555555555551',
      '41111111-aaaa-4aaa-8aaa-555555555553',
      10,
      'Currency mismatch forbidden',
      now()
    );

    raise exception 'CURRENCY_MISMATCH_TRANSFER_ALLOWED';
  exception
    when invalid_parameter_value then
      null;
  end;

  -- Cross-tenant request must fail.
  begin
    perform public.create_finance_transfer(
      '42222222-bbbb-4bbb-8bbb-222222222222',
      '42222222-bbbb-4bbb-8bbb-555555555551',
      '42222222-bbbb-4bbb-8bbb-555555555551',
      10,
      'Cross tenant forbidden',
      now()
    );

    raise exception 'CROSS_TENANT_TRANSFER_ALLOWED';
  exception
    when insufficient_privilege then
      null;
  end;

  -- Cross-tenant destination account must fail.
  begin
    perform public.create_finance_transfer(
      '41111111-aaaa-4aaa-8aaa-111111111111',
      '41111111-aaaa-4aaa-8aaa-555555555551',
      '42222222-bbbb-4bbb-8bbb-555555555551',
      10,
      'Wrong tenant destination',
      now()
    );

    raise exception 'CROSS_TENANT_DESTINATION_ALLOWED';
  exception
    when invalid_parameter_value then
      null;
  end;
end
$$;

-- ------------------------------------------------------------
-- STRUCTURAL / LEDGER / AUDIT CHECKS
-- ------------------------------------------------------------

reset role;

do $$
declare
  v_transaction_id uuid;
  v_entry_count bigint;
  v_entry_sum numeric;
begin
  select ft.id
  into v_transaction_id
  from public.finance_transactions as ft
  where ft.tenant_id =
      '41111111-aaaa-4aaa-8aaa-111111111111'
    and ft.transaction_type = 'TRANSFER'
    and ft.description = 'Ziraat to cash transfer';

  if v_transaction_id is null then
    raise exception 'FINANCE_TRANSFER_TRANSACTION_MISSING';
  end if;

  select
    count(*),
    coalesce(sum(fe.amount), 0)
  into
    v_entry_count,
    v_entry_sum
  from public.finance_entries as fe
  where fe.tenant_id =
      '41111111-aaaa-4aaa-8aaa-111111111111'
    and fe.transaction_id = v_transaction_id;

  if v_entry_count <> 2 then
    raise exception
      'FINANCE_TRANSFER_ENTRY_COUNT_WRONG: %',
      v_entry_count;
  end if;

  if v_entry_sum <> 0 then
    raise exception
      'FINANCE_TRANSFER_NOT_ZERO_SUM: %',
      v_entry_sum;
  end if;

  if (
    select count(*)
    from public.finance_entries as fe
    where fe.tenant_id =
        '41111111-aaaa-4aaa-8aaa-111111111111'
      and fe.transaction_id = v_transaction_id
      and fe.account_id =
        '41111111-aaaa-4aaa-8aaa-555555555551'
      and fe.amount = -250.56
  ) <> 1 then
    raise exception 'FINANCE_TRANSFER_SOURCE_ENTRY_WRONG';
  end if;

  if (
    select count(*)
    from public.finance_entries as fe
    where fe.tenant_id =
        '41111111-aaaa-4aaa-8aaa-111111111111'
      and fe.transaction_id = v_transaction_id
      and fe.account_id =
        '41111111-aaaa-4aaa-8aaa-555555555552'
      and fe.amount = 250.56
  ) <> 1 then
    raise exception 'FINANCE_TRANSFER_DESTINATION_ENTRY_WRONG';
  end if;

  if (
    select count(*)
    from public.finance_transactions as ft
    where ft.id = v_transaction_id
      and ft.tenant_id =
        '41111111-aaaa-4aaa-8aaa-111111111111'
      and ft.created_by_user_id =
        '41111111-6666-4666-8666-111111111111'
      and ft.source_type = 'MANUAL'
      and ft.description = 'Ziraat to cash transfer'
      and ft.occurred_at =
        '2026-09-24 09:45:00+00'::timestamptz
  ) <> 1 then
    raise exception 'FINANCE_TRANSFER_METADATA_WRONG';
  end if;

  if (
    select count(*)
    from public.audit_logs as al
    where al.tenant_id =
        '41111111-aaaa-4aaa-8aaa-111111111111'
      and al.action = 'FINANCE_TRANSFER_CREATED'
      and al.entity_type = 'finance_transaction'
      and al.entity_id = v_transaction_id
      and al.actor_user_id =
        '41111111-6666-4666-8666-111111111111'
      and al.metadata ->> 'fromAccountId'
        = '41111111-aaaa-4aaa-8aaa-555555555551'
      and al.metadata ->> 'toAccountId'
        = '41111111-aaaa-4aaa-8aaa-555555555552'
      and (al.metadata ->> 'amount')::numeric = 250.56
      and al.metadata ->> 'currencyCode' = 'TRY'
      and al.metadata ->> 'description'
        = 'Ziraat to cash transfer'
  ) <> 1 then
    raise exception 'FINANCE_TRANSFER_AUDIT_WRONG';
  end if;
end
$$;

-- ------------------------------------------------------------
-- READ-ONLY USER CANNOT TRANSFER
-- ------------------------------------------------------------

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  '41111111-7777-4777-8777-111111111111',
  true
);

do $$
begin
  begin
    perform public.create_finance_transfer(
      '41111111-aaaa-4aaa-8aaa-111111111111',
      '41111111-aaaa-4aaa-8aaa-555555555551',
      '41111111-aaaa-4aaa-8aaa-555555555552',
      25,
      'Read only forbidden',
      now()
    );

    raise exception 'FINANCE_READ_ONLY_USER_CAN_TRANSFER';
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
  '43333333-6666-4666-8666-333333333333',
  true
);

do $$
begin
  begin
    perform public.create_finance_transfer(
      '43333333-cccc-4ccc-8ccc-333333333333',
      '43333333-cccc-4ccc-8ccc-555555555551',
      '43333333-cccc-4ccc-8ccc-555555555552',
      25,
      'Disabled module forbidden',
      now()
    );

    raise exception 'DISABLED_FINANCE_MODULE_CAN_TRANSFER';
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
    perform public.create_finance_transfer(
      '41111111-aaaa-4aaa-8aaa-111111111111',
      '41111111-aaaa-4aaa-8aaa-555555555551',
      '41111111-aaaa-4aaa-8aaa-555555555552',
      25,
      'Anonymous forbidden',
      now()
    );

    raise exception 'ANON_CAN_EXECUTE_FINANCE_TRANSFER';
  exception
    when insufficient_privilege then
      null;
  end;
end
$$;

rollback;

select
  'PASS - FINANCE TRANSFER COMMAND' as result,
  (
    select count(*)
    from auth.users
    where id in (
      '41111111-6666-4666-8666-111111111111',
      '41111111-7777-4777-8777-111111111111',
      '43333333-6666-4666-8666-333333333333'
    )
  ) as residual_test_users,
  (
    select count(*)
    from public.tenants
    where id in (
      '41111111-aaaa-4aaa-8aaa-111111111111',
      '42222222-bbbb-4bbb-8bbb-222222222222',
      '43333333-cccc-4ccc-8ccc-333333333333'
    )
  ) as residual_test_tenants;