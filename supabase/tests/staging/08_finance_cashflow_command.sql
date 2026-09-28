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
  '51111111-6666-4666-8666-111111111111',
  'authenticated',
  'authenticated',
  'cashflow-writer@coost.test',
  now(),
  now()
),
(
  '51111111-7777-4777-8777-111111111111',
  'authenticated',
  'authenticated',
  'cashflow-reader@coost.test',
  now(),
  now()
),
(
  '53333333-6666-4666-8666-333333333333',
  'authenticated',
  'authenticated',
  'cashflow-disabled@coost.test',
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
  '51111111-aaaa-4aaa-8aaa-111111111111',
  'Cashflow Tenant A',
  'ACTIVE'
),
(
  '52222222-bbbb-4bbb-8bbb-222222222222',
  'Cashflow Tenant B',
  'ACTIVE'
),
(
  '53333333-cccc-4ccc-8ccc-333333333333',
  'Cashflow Disabled Tenant',
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
  '51111111-1111-4111-8111-111111111111',
  '51111111-aaaa-4aaa-8aaa-111111111111',
  '51111111-6666-4666-8666-111111111111',
  'ACTIVE'
),
(
  '51111111-2222-4222-8222-111111111111',
  '51111111-aaaa-4aaa-8aaa-111111111111',
  '51111111-7777-4777-8777-111111111111',
  'ACTIVE'
),
(
  '53333333-1111-4111-8111-333333333333',
  '53333333-cccc-4ccc-8ccc-333333333333',
  '53333333-6666-4666-8666-333333333333',
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
  '51111111-3333-4333-8333-111111111111',
  '51111111-aaaa-4aaa-8aaa-111111111111',
  'finance-writer',
  'Finance Writer',
  true
),
(
  '51111111-4444-4444-8444-111111111111',
  '51111111-aaaa-4aaa-8aaa-111111111111',
  'finance-reader',
  'Finance Reader',
  true
),
(
  '53333333-3333-4333-8333-333333333333',
  '53333333-cccc-4ccc-8ccc-333333333333',
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
  '51111111-aaaa-4aaa-8aaa-111111111111',
  '51111111-1111-4111-8111-111111111111',
  '51111111-3333-4333-8333-111111111111'
),
(
  '51111111-aaaa-4aaa-8aaa-111111111111',
  '51111111-2222-4222-8222-111111111111',
  '51111111-4444-4444-8444-111111111111'
),
(
  '53333333-cccc-4ccc-8ccc-333333333333',
  '53333333-1111-4111-8111-333333333333',
  '53333333-3333-4333-8333-333333333333'
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
  '51111111-aaaa-4aaa-8aaa-111111111111',
  '51111111-3333-4333-8333-111111111111',
  'finance.read'
),
(
  '51111111-aaaa-4aaa-8aaa-111111111111',
  '51111111-3333-4333-8333-111111111111',
  'finance.write'
),
(
  '51111111-aaaa-4aaa-8aaa-111111111111',
  '51111111-4444-4444-8444-111111111111',
  'finance.read'
),
(
  '53333333-cccc-4ccc-8ccc-333333333333',
  '53333333-3333-4333-8333-333333333333',
  'finance.read'
),
(
  '53333333-cccc-4ccc-8ccc-333333333333',
  '53333333-3333-4333-8333-333333333333',
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
  '51111111-aaaa-4aaa-8aaa-111111111111',
  'finance',
  true
),
(
  '52222222-bbbb-4bbb-8bbb-222222222222',
  'finance',
  true
),
(
  '53333333-cccc-4ccc-8ccc-333333333333',
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
  '51111111-aaaa-4aaa-8aaa-555555555551',
  '51111111-aaaa-4aaa-8aaa-111111111111',
  'Tenant A Ziraat',
  'BANK',
  'TRY'
),
(
  '51111111-aaaa-4aaa-8aaa-555555555552',
  '51111111-aaaa-4aaa-8aaa-111111111111',
  'Tenant A Nakit',
  'CASH',
  'TRY'
),
(
  '51111111-aaaa-4aaa-8aaa-555555555553',
  '51111111-aaaa-4aaa-8aaa-111111111111',
  'Tenant A USD Bank',
  'BANK',
  'USD'
),
(
  '52222222-bbbb-4bbb-8bbb-555555555551',
  '52222222-bbbb-4bbb-8bbb-222222222222',
  'Tenant B Nakit',
  'CASH',
  'TRY'
),
(
  '53333333-cccc-4ccc-8ccc-555555555551',
  '53333333-cccc-4ccc-8ccc-333333333333',
  'Disabled Bank',
  'BANK',
  'TRY'
),
(
  '53333333-cccc-4ccc-8ccc-555555555552',
  '53333333-cccc-4ccc-8ccc-333333333333',
  'Disabled Cash',
  'CASH',
  'TRY'
);

-- ------------------------------------------------------------

-- Authorized income and expense, rounded amounts and overview balance.
set local role authenticated;
select set_config('request.jwt.claim.sub', '51111111-6666-4666-8666-111111111111', true);
do $$
declare
  v_income uuid;
  v_expense uuid;
  v_overview jsonb;
  v_balance numeric;
  v_bad_amount numeric;
  v_bad_type text;
  v_bad_description text;
begin
  v_income := public.create_finance_cashflow(
    '51111111-aaaa-4aaa-8aaa-111111111111', '51111111-aaaa-4aaa-8aaa-555555555551',
    'INCOME', 250.556, '  Cash income  ', '2026-09-24 10:00:00+00');
  v_overview := public.get_finance_overview('51111111-aaaa-4aaa-8aaa-111111111111', 20);
  select (item->>'balance')::numeric into v_balance
  from jsonb_array_elements(v_overview->'accounts') item
  where item->>'id' = '51111111-aaaa-4aaa-8aaa-555555555551';
  if v_balance is distinct from 250.56 then raise exception 'INCOME_BALANCE_WRONG: %', v_balance; end if;

  v_expense := public.create_finance_cashflow(
    '51111111-aaaa-4aaa-8aaa-111111111111', '51111111-aaaa-4aaa-8aaa-555555555551',
    'EXPENSE', 50.554, '  Cash expense  ');
  if v_income is null or v_expense is null or v_income = v_expense then raise exception 'CASHFLOW_IDS_INVALID'; end if;
  v_overview := public.get_finance_overview('51111111-aaaa-4aaa-8aaa-111111111111', 20);
  select (item->>'balance')::numeric into v_balance
  from jsonb_array_elements(v_overview->'accounts') item
  where item->>'id' = '51111111-aaaa-4aaa-8aaa-555555555551';
  if v_balance is distinct from 200.01 then raise exception 'EXPENSE_BALANCE_WRONG: %', v_balance; end if;
  if (select count(*) from jsonb_array_elements(v_overview->'recentTransactions') item
      where (item->>'id' = v_income::text and item->>'transactionType' = 'INCOME' and (item->'entries'->0->>'amount')::numeric = 250.56)
         or (item->>'id' = v_expense::text and item->>'transactionType' = 'EXPENSE' and (item->'entries'->0->>'amount')::numeric = -50.55)) <> 2
  then raise exception 'OVERVIEW_CASHFLOW_ENTRIES_WRONG'; end if;

  foreach v_bad_amount in array array[0, 0.004, -10, null, 'NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric] loop
    begin
      perform public.create_finance_cashflow('51111111-aaaa-4aaa-8aaa-111111111111', '51111111-aaaa-4aaa-8aaa-555555555551', 'INCOME', v_bad_amount, 'Invalid amount');
      raise exception 'INVALID_AMOUNT_ALLOWED: %', v_bad_amount;
    exception when invalid_parameter_value then null;
    end;
  end loop;
  begin
    perform public.create_finance_cashflow('51111111-aaaa-4aaa-8aaa-111111111111', '51111111-aaaa-4aaa-8aaa-555555555551', 'EXPENSE', 100000000000000, 'Overflow amount');
    raise exception 'OVERFLOW_ALLOWED';
  exception when numeric_value_out_of_range then null;
  end;
  foreach v_bad_type in array array['TRANSFER', 'ADJUSTMENT', 'income', '', null] loop
    begin
      perform public.create_finance_cashflow('51111111-aaaa-4aaa-8aaa-111111111111', '51111111-aaaa-4aaa-8aaa-555555555551', v_bad_type, 10, 'Invalid type');
      raise exception 'INVALID_TYPE_ALLOWED: %', v_bad_type;
    exception when invalid_parameter_value then null;
    end;
  end loop;
  foreach v_bad_description in array array['', '  ', ' x ', repeat('x', 501), null] loop
    begin
      perform public.create_finance_cashflow('51111111-aaaa-4aaa-8aaa-111111111111', '51111111-aaaa-4aaa-8aaa-555555555551', 'INCOME', 10, v_bad_description);
      raise exception 'INVALID_DESCRIPTION_ALLOWED';
    exception when invalid_parameter_value then null;
    end;
  end loop;
  begin
    perform public.create_finance_cashflow('52222222-bbbb-4bbb-8bbb-222222222222', '52222222-bbbb-4bbb-8bbb-555555555551', 'INCOME', 10, 'Cross tenant');
    raise exception 'CROSS_TENANT_ALLOWED';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.create_finance_cashflow('51111111-aaaa-4aaa-8aaa-111111111111', '52222222-bbbb-4bbb-8bbb-555555555551', 'EXPENSE', 10, 'Other tenant account');
    raise exception 'OTHER_TENANT_ACCOUNT_ALLOWED';
  exception when invalid_parameter_value then null;
  end;
end;
$$;

reset role;
update public.finance_accounts set status = 'PASSIVE' where id = '51111111-aaaa-4aaa-8aaa-555555555552';
set local role authenticated;
do $$
begin
  begin
    perform public.create_finance_cashflow('51111111-aaaa-4aaa-8aaa-111111111111', '51111111-aaaa-4aaa-8aaa-555555555552', 'INCOME', 10, 'Passive account');
    raise exception 'PASSIVE_ACCOUNT_ALLOWED';
  exception when invalid_parameter_value then null;
  end;
end;
$$;

-- Verify ledger, transaction metadata and exact audit payloads as database owner.
reset role;
do $$
declare
  v_transaction record;
  v_amount numeric;
  v_signed numeric;
  v_signature text := 'public.create_finance_cashflow(uuid,uuid,text,numeric,text,timestamptz)';
begin
  if (select count(*) from public.finance_transactions where tenant_id = '51111111-aaaa-4aaa-8aaa-111111111111') <> 2 then
    raise exception 'FAILED_CALLS_CREATED_TRANSACTIONS';
  end if;
  for v_transaction in select * from public.finance_transactions where tenant_id = '51111111-aaaa-4aaa-8aaa-111111111111' loop
    v_amount := case when v_transaction.transaction_type = 'INCOME' then 250.56 else 50.55 end;
    v_signed := case when v_transaction.transaction_type = 'INCOME' then v_amount else -v_amount end;
    if v_transaction.transaction_type not in ('INCOME', 'EXPENSE')
       or v_transaction.source_type is distinct from 'MANUAL'
       or v_transaction.source_id is not null
       or v_transaction.created_by_user_id is distinct from '51111111-6666-4666-8666-111111111111'::uuid
       or v_transaction.location_id is not null
       or v_transaction.description is distinct from (case when v_transaction.transaction_type = 'INCOME' then 'Cash income' else 'Cash expense' end)
       or v_transaction.occurred_at is distinct from (case when v_transaction.transaction_type = 'INCOME' then '2026-09-24 10:00:00+00'::timestamptz else now() end)
    then raise exception 'TRANSACTION_METADATA_WRONG'; end if;
    if (select count(*) from public.finance_entries where transaction_id = v_transaction.id) <> 1
       or (select count(*) from public.finance_entries where transaction_id = v_transaction.id
         and tenant_id = v_transaction.tenant_id and account_id = '51111111-aaaa-4aaa-8aaa-555555555551' and amount = v_signed) <> 1
    then raise exception 'CASHFLOW_ENTRY_WRONG'; end if;
    if (select count(*) from public.audit_logs where entity_id = v_transaction.id
      and tenant_id = v_transaction.tenant_id and location_id is null
      and actor_user_id = v_transaction.created_by_user_id and entity_type = 'finance_transaction'
      and action = case when v_transaction.transaction_type = 'INCOME' then 'FINANCE_INCOME_CREATED' else 'FINANCE_EXPENSE_CREATED' end
      and metadata = jsonb_build_object('accountId', '51111111-aaaa-4aaa-8aaa-555555555551'::uuid,
        'transactionType', v_transaction.transaction_type, 'amount', v_amount, 'signedAmount', v_signed, 'description', v_transaction.description)) <> 1
    then raise exception 'CASHFLOW_AUDIT_WRONG'; end if;
  end loop;
  if has_function_privilege('anon', v_signature, 'EXECUTE')
     or not has_function_privilege('authenticated', v_signature, 'EXECUTE')
     or not has_function_privilege('service_role', v_signature, 'EXECUTE') then
    raise exception 'CASHFLOW_EXECUTE_GRANTS_WRONG';
  end if;
  if exists (select 1 from pg_proc p, lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
    where p.oid = v_signature::regprocedure and a.grantee = 0 and a.privilege_type = 'EXECUTE') then
    raise exception 'PUBLIC_CAN_EXECUTE_CASHFLOW';
  end if;
  if not exists (select 1 from pg_proc where oid = v_signature::regprocedure and prosecdef and 'search_path=""' = any(proconfig)) then
    raise exception 'CASHFLOW_SECURITY_CONFIGURATION_WRONG';
  end if;
  if has_table_privilege('authenticated', 'public.finance_entries', 'INSERT')
     or has_table_privilege('authenticated', 'public.finance_transactions', 'INSERT') then
    raise exception 'BROWSER_LEDGER_WRITE_ALLOWED';
  end if;
end;
$$;

-- Read-only, disabled module, missing authentication and anonymous access.
set local role authenticated;
select set_config('request.jwt.claim.sub', '51111111-7777-4777-8777-111111111111', true);
do $$
begin
  begin
    perform public.create_finance_cashflow('51111111-aaaa-4aaa-8aaa-111111111111', '51111111-aaaa-4aaa-8aaa-555555555551', 'EXPENSE', 10, 'Read only');
    raise exception 'READ_ONLY_WRITE_ALLOWED';
  exception when insufficient_privilege then null;
  end;
end;
$$;
select set_config('request.jwt.claim.sub', '53333333-6666-4666-8666-333333333333', true);
do $$
begin
  begin
    perform public.create_finance_cashflow('53333333-cccc-4ccc-8ccc-333333333333', '53333333-cccc-4ccc-8ccc-555555555551', 'INCOME', 10, 'Disabled module');
    raise exception 'DISABLED_MODULE_WRITE_ALLOWED';
  exception when insufficient_privilege then null;
  end;
end;
$$;
select set_config('request.jwt.claim.sub', '', true);
do $$
begin
  begin
    perform public.create_finance_cashflow('51111111-aaaa-4aaa-8aaa-111111111111', '51111111-aaaa-4aaa-8aaa-555555555551', 'INCOME', 10, 'Missing authentication');
    raise exception 'UNAUTHENTICATED_WRITE_ALLOWED';
  exception when insufficient_privilege then null;
  end;
end;
$$;
set local role anon;
do $$
begin
  begin
    perform public.create_finance_cashflow('51111111-aaaa-4aaa-8aaa-111111111111', '51111111-aaaa-4aaa-8aaa-555555555551', 'INCOME', 10, 'Anonymous');
    raise exception 'ANON_EXECUTE_ALLOWED';
  exception when insufficient_privilege then null;
  end;
end;
$$;
rollback;

do $$
begin
  if exists (select 1 from auth.users where id in ('51111111-6666-4666-8666-111111111111', '51111111-7777-4777-8777-111111111111', '53333333-6666-4666-8666-333333333333'))
     or exists (select 1 from public.tenants where id in ('51111111-aaaa-4aaa-8aaa-111111111111', '52222222-bbbb-4bbb-8bbb-222222222222', '53333333-cccc-4ccc-8ccc-333333333333')) then
    raise exception 'CASHFLOW_RESIDUAL_TEST_DATA';
  end if;
end;
$$;
select 'PASS - FINANCE CASHFLOW COMMAND' as result,
  (select count(*) from auth.users where id in ('51111111-6666-4666-8666-111111111111', '51111111-7777-4777-8777-111111111111', '53333333-6666-4666-8666-333333333333')) as residual_test_users,
  (select count(*) from public.tenants where id in ('51111111-aaaa-4aaa-8aaa-111111111111', '52222222-bbbb-4bbb-8bbb-222222222222', '53333333-cccc-4ccc-8ccc-333333333333')) as residual_test_tenants;
