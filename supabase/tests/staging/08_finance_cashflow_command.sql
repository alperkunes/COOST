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
-- Make one account unavailable to exercise ACTIVE validation.
update public.finance_accounts set status = 'PASSIVE'
where id = '51111111-aaaa-4aaa-8aaa-555555555553';

set local role authenticated;
select set_config('request.jwt.claim.sub', '51111111-6666-4666-8666-111111111111', true);

do $$
declare
  v_id uuid;
  v_type text;
  v_amount numeric;
  v_description text;
  v_balance numeric;
  v_overview jsonb;
  v_tenant uuid := '51111111-aaaa-4aaa-8aaa-111111111111';
  v_account uuid := '51111111-aaaa-4aaa-8aaa-555555555551';
begin
  foreach v_type in array array['INCOME', 'EXPENSE'] loop
    v_id := public.create_finance_cashflow(v_tenant, v_account, v_type,
      case when v_type = 'INCOME' then 250.556 else 50.555 end,
      '  Cashflow ' || v_type || '  ', '2026-09-24 09:45:00+00');
    if v_id is null then raise exception 'CASHFLOW_ID_NULL'; end if;
    if (select count(*) from public.finance_entries where transaction_id = v_id
      and account_id = v_account and tenant_id = v_tenant
      and amount = case when v_type = 'INCOME' then 250.56 else -50.56 end) <> 1 then
      raise exception 'CASHFLOW_SIGN_OR_ROUNDING_WRONG: %', v_type;
    end if;
  end loop;

  v_overview := public.get_finance_overview(v_tenant, 20);
  select (item ->> 'balance')::numeric into v_balance
  from jsonb_array_elements(v_overview -> 'accounts') as item
  where item ->> 'id' = v_account::text;
  if v_balance is distinct from 200.00 then raise exception 'CASHFLOW_BALANCE_WRONG: %', v_balance; end if;

  foreach v_type in array array['INCOME', 'EXPENSE'] loop
    foreach v_amount in array array[0, 0.004, -1, -0.004, null, 'NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric] loop
      begin
        perform public.create_finance_cashflow(v_tenant, v_account, v_type, v_amount, 'Invalid amount');
        raise exception 'INVALID_CASHFLOW_AMOUNT_ALLOWED: % %', v_type, v_amount;
      exception when invalid_parameter_value then null;
      end;
    end loop;
    begin
      perform public.create_finance_cashflow(v_tenant, v_account, v_type, 100000000000000, 'Overflow');
      raise exception 'CASHFLOW_OVERFLOW_ALLOWED';
    exception when numeric_value_out_of_range then null;
    end;
  end loop;

  foreach v_type in array array['TRANSFER', 'ADJUSTMENT', 'income', '', null] loop
    begin
      perform public.create_finance_cashflow(v_tenant, v_account, v_type, 10, 'Invalid type');
      raise exception 'INVALID_CASHFLOW_TYPE_ALLOWED: %', v_type;
    exception when invalid_parameter_value then null;
    end;
  end loop;
  foreach v_description in array array['', ' ', 'x', repeat('x', 501), null] loop
    begin
      perform public.create_finance_cashflow(v_tenant, v_account, 'INCOME', 10, v_description);
      raise exception 'INVALID_CASHFLOW_DESCRIPTION_ALLOWED';
    exception when invalid_parameter_value then null;
    end;
  end loop;
  begin
    perform public.create_finance_cashflow('52222222-bbbb-4bbb-8bbb-222222222222',
      '52222222-bbbb-4bbb-8bbb-555555555551', 'INCOME', 10, 'Cross tenant');
    raise exception 'CROSS_TENANT_CASHFLOW_ALLOWED';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.create_finance_cashflow(v_tenant, '52222222-bbbb-4bbb-8bbb-555555555551', 'EXPENSE', 10, 'Other tenant account');
    raise exception 'OTHER_TENANT_ACCOUNT_ALLOWED';
  exception when invalid_parameter_value then null;
  end;
  begin
    perform public.create_finance_cashflow(v_tenant, '51111111-aaaa-4aaa-8aaa-555555555553', 'INCOME', 10, 'Passive account');
    raise exception 'PASSIVE_ACCOUNT_ALLOWED';
  exception when invalid_parameter_value then null;
  end;
end;
$$;

reset role;
do $$
declare
  v_type text;
  v_id uuid;
  v_amount numeric;
  v_signed numeric;
  v_signature text := 'public.create_finance_cashflow(uuid,uuid,text,numeric,text,timestamptz)';
begin
  foreach v_type in array array['INCOME', 'EXPENSE'] loop
    v_amount := case when v_type = 'INCOME' then 250.56 else 50.56 end;
    v_signed := case when v_type = 'INCOME' then v_amount else -v_amount end;
    select id into strict v_id from public.finance_transactions
    where tenant_id = '51111111-aaaa-4aaa-8aaa-111111111111'
      and transaction_type = v_type and source_type = 'MANUAL' and source_id is null
      and description = 'Cashflow ' || v_type
      and created_by_user_id = '51111111-6666-4666-8666-111111111111'
      and occurred_at = '2026-09-24 09:45:00+00'::timestamptz;
    if (select count(*) from public.finance_entries where transaction_id = v_id) <> 1 then
      raise exception 'CASHFLOW_ENTRY_COUNT_WRONG';
    end if;
    if (select count(*) from public.audit_logs
      where tenant_id = '51111111-aaaa-4aaa-8aaa-111111111111'
        and action = 'FINANCE_' || v_type || '_CREATED'
        and actor_user_id = '51111111-6666-4666-8666-111111111111'
        and entity_type = 'finance_transaction' and entity_id = v_id
        and metadata = jsonb_build_object('accountId', '51111111-aaaa-4aaa-8aaa-555555555551',
          'transactionType', v_type, 'amount', v_amount, 'signedAmount', v_signed, 'description', 'Cashflow ' || v_type)
    ) <> 1 then raise exception 'CASHFLOW_AUDIT_WRONG: %', v_type; end if;
  end loop;
  if (select count(*) from public.finance_transactions where tenant_id = '51111111-aaaa-4aaa-8aaa-111111111111') <> 2
    or (select count(*) from public.audit_logs where tenant_id = '51111111-aaaa-4aaa-8aaa-111111111111' and action like 'FINANCE_%_CREATED') <> 2 then
    raise exception 'REJECTED_CASHFLOW_LEFT_RESIDUAL_WRITES';
  end if;
  if has_function_privilege('anon', v_signature, 'EXECUTE')
    or not has_function_privilege('authenticated', v_signature, 'EXECUTE')
    or not has_function_privilege('service_role', v_signature, 'EXECUTE') then
    raise exception 'CASHFLOW_EXECUTE_GRANTS_WRONG';
  end if;
  if exists (select 1 from pg_proc p, lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
    where p.oid = v_signature::regprocedure and a.grantee = 0 and a.privilege_type = 'EXECUTE') then
    raise exception 'PUBLIC_CASHFLOW_EXECUTE_ALLOWED';
  end if;
  if not (select prosecdef and proconfig @> array['search_path=""'] from pg_proc where oid = v_signature::regprocedure) then
    raise exception 'CASHFLOW_SECURITY_DEFINER_CONFIG_WRONG';
  end if;
end;
$$;

set local role authenticated;
select set_config('request.jwt.claim.sub', '51111111-7777-4777-8777-111111111111', true);
do $$
begin
  begin
    perform public.create_finance_cashflow('51111111-aaaa-4aaa-8aaa-111111111111',
      '51111111-aaaa-4aaa-8aaa-555555555551', 'INCOME', 10, 'Read only');
    raise exception 'READ_ONLY_CASHFLOW_ALLOWED';
  exception when insufficient_privilege then null;
  end;
end;
$$;

select set_config('request.jwt.claim.sub', '53333333-6666-4666-8666-333333333333', true);
do $$
begin
  begin
    perform public.create_finance_cashflow('53333333-cccc-4ccc-8ccc-333333333333',
      '53333333-cccc-4ccc-8ccc-555555555551', 'EXPENSE', 10, 'Disabled module');
    raise exception 'DISABLED_MODULE_CASHFLOW_ALLOWED';
  exception when insufficient_privilege then null;
  end;
end;
$$;

select set_config('request.jwt.claim.sub', '', true);
do $$
begin
  begin
    perform public.create_finance_cashflow('51111111-aaaa-4aaa-8aaa-111111111111',
      '51111111-aaaa-4aaa-8aaa-555555555551', 'INCOME', 10, 'Missing auth uid');
    raise exception 'UNAUTHENTICATED_CASHFLOW_ALLOWED';
  exception when insufficient_privilege then null;
  end;
end;
$$;

set local role anon;
do $$
begin
  begin
    perform public.create_finance_cashflow('51111111-aaaa-4aaa-8aaa-111111111111',
      '51111111-aaaa-4aaa-8aaa-555555555551', 'INCOME', 10, 'Anonymous');
    raise exception 'ANON_CASHFLOW_ALLOWED';
  exception when insufficient_privilege then null;
  end;
end;
$$;
rollback;

do $$
begin
  if exists (select 1 from auth.users where id in ('51111111-6666-4666-8666-111111111111', '51111111-7777-4777-8777-111111111111', '53333333-6666-4666-8666-333333333333'))
    or exists (select 1 from public.tenants where id in ('51111111-aaaa-4aaa-8aaa-111111111111', '52222222-bbbb-4bbb-8bbb-222222222222', '53333333-cccc-4ccc-8ccc-333333333333')) then
    raise exception 'CASHFLOW_ROLLBACK_RESIDUALS';
  end if;
end;
$$;
select 'PASS - FINANCE CASHFLOW COMMAND' as result,
  (select count(*) from auth.users where id in ('51111111-6666-4666-8666-111111111111', '51111111-7777-4777-8777-111111111111', '53333333-6666-4666-8666-333333333333')) as residual_test_users,
  (select count(*) from public.tenants where id in ('51111111-aaaa-4aaa-8aaa-111111111111', '52222222-bbbb-4bbb-8bbb-222222222222', '53333333-cccc-4ccc-8ccc-333333333333')) as residual_test_tenants;
