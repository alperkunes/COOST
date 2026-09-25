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
  '61111111-6666-4666-8666-111111111111',
  'authenticated',
  'authenticated',
  'account-management-writer@coost.test',
  now(),
  now()
),
(
  '61111111-7777-4777-8777-111111111111',
  'authenticated',
  'authenticated',
  'account-management-reader@coost.test',
  now(),
  now()
),
(
  '63333333-6666-4666-8666-333333333333',
  'authenticated',
  'authenticated',
  'account-management-disabled@coost.test',
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
  '61111111-aaaa-4aaa-8aaa-111111111111',
  'Account Management Tenant A',
  'ACTIVE'
),
(
  '62222222-bbbb-4bbb-8bbb-222222222222',
  'Account Management Tenant B',
  'ACTIVE'
),
(
  '63333333-cccc-4ccc-8ccc-333333333333',
  'Account Management Disabled Tenant',
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
  '61111111-1111-4111-8111-111111111111',
  '61111111-aaaa-4aaa-8aaa-111111111111',
  '61111111-6666-4666-8666-111111111111',
  'ACTIVE'
),
(
  '61111111-2222-4222-8222-111111111111',
  '61111111-aaaa-4aaa-8aaa-111111111111',
  '61111111-7777-4777-8777-111111111111',
  'ACTIVE'
),
(
  '63333333-1111-4111-8111-333333333333',
  '63333333-cccc-4ccc-8ccc-333333333333',
  '63333333-6666-4666-8666-333333333333',
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
  '61111111-3333-4333-8333-111111111111',
  '61111111-aaaa-4aaa-8aaa-111111111111',
  'finance-writer',
  'Finance Writer',
  true
),
(
  '61111111-4444-4444-8444-111111111111',
  '61111111-aaaa-4aaa-8aaa-111111111111',
  'finance-reader',
  'Finance Reader',
  true
),
(
  '63333333-3333-4333-8333-333333333333',
  '63333333-cccc-4ccc-8ccc-333333333333',
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
  '61111111-aaaa-4aaa-8aaa-111111111111',
  '61111111-1111-4111-8111-111111111111',
  '61111111-3333-4333-8333-111111111111'
),
(
  '61111111-aaaa-4aaa-8aaa-111111111111',
  '61111111-2222-4222-8222-111111111111',
  '61111111-4444-4444-8444-111111111111'
),
(
  '63333333-cccc-4ccc-8ccc-333333333333',
  '63333333-1111-4111-8111-333333333333',
  '63333333-3333-4333-8333-333333333333'
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
  '61111111-aaaa-4aaa-8aaa-111111111111',
  '61111111-3333-4333-8333-111111111111',
  'finance.read'
),
(
  '61111111-aaaa-4aaa-8aaa-111111111111',
  '61111111-3333-4333-8333-111111111111',
  'finance.write'
),
(
  '61111111-aaaa-4aaa-8aaa-111111111111',
  '61111111-4444-4444-8444-111111111111',
  'finance.read'
),
(
  '63333333-cccc-4ccc-8ccc-333333333333',
  '63333333-3333-4333-8333-333333333333',
  'finance.read'
),
(
  '63333333-cccc-4ccc-8ccc-333333333333',
  '63333333-3333-4333-8333-333333333333',
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
  '61111111-aaaa-4aaa-8aaa-111111111111',
  'finance',
  true
),
(
  '62222222-bbbb-4bbb-8bbb-222222222222',
  'finance',
  true
),
(
  '63333333-cccc-4ccc-8ccc-333333333333',
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
  '61111111-aaaa-4aaa-8aaa-555555555551',
  '61111111-aaaa-4aaa-8aaa-111111111111',
  'Tenant A Ziraat',
  'BANK',
  'TRY'
),
(
  '61111111-aaaa-4aaa-8aaa-555555555552',
  '61111111-aaaa-4aaa-8aaa-111111111111',
  'Tenant A Nakit',
  'CASH',
  'TRY'
),
(
  '61111111-aaaa-4aaa-8aaa-555555555553',
  '61111111-aaaa-4aaa-8aaa-111111111111',
  'Tenant A USD Bank',
  'BANK',
  'USD'
),
(
  '62222222-bbbb-4bbb-8bbb-555555555551',
  '62222222-bbbb-4bbb-8bbb-222222222222',
  'Tenant B Nakit',
  'CASH',
  'TRY'
),
(
  '63333333-cccc-4ccc-8ccc-555555555551',
  '63333333-cccc-4ccc-8ccc-333333333333',
  'Disabled Bank',
  'BANK',
  'TRY'
),
(
  '63333333-cccc-4ccc-8ccc-555555555552',
  '63333333-cccc-4ccc-8ccc-333333333333',
  'Disabled Cash',
  'CASH',
  'TRY'
);

-- ------------------------------------------------------------
insert into public.locations (id, tenant_id, name, status) values
('61111111-aaaa-4aaa-8aaa-999999999991', '61111111-aaaa-4aaa-8aaa-111111111111', 'Merkez', 'ACTIVE'),
('61111111-aaaa-4aaa-8aaa-999999999992', '61111111-aaaa-4aaa-8aaa-111111111111', 'Kapalı', 'PASSIVE'),
('62222222-bbbb-4bbb-8bbb-999999999991', '62222222-bbbb-4bbb-8bbb-222222222222', 'Diğer işletme', 'ACTIVE');

create function pg_temp.assert_true(ok boolean, label text) returns void language plpgsql as $$
begin
  if ok is distinct from true then raise exception 'ASSERT_FAILED: %', label; end if;
end;
$$;
create function pg_temp.expect_error(command text, expected_state text, expected_message text default null)
returns void language plpgsql as $$
begin
  execute command;
  raise exception 'EXPECTED_ERROR_NOT_RAISED: %', command;
exception when others then
  if sqlstate <> expected_state or (expected_message is not null and sqlerrm <> expected_message) then raise; end if;
end;
$$;

set local role authenticated;
select set_config('request.jwt.claim.sub', '61111111-6666-4666-8666-111111111111', true);
select set_config('test.cash_id', public.create_finance_account('61111111-aaaa-4aaa-8aaa-111111111111', '  Yeni Kasa  ', 'CASH', ' try ')::text, true);
select set_config('test.bank_id', public.create_finance_account('61111111-aaaa-4aaa-8aaa-111111111111', 'Yeni Banka', 'BANK', ' usd ', '61111111-aaaa-4aaa-8aaa-999999999991')::text, true);

do $$
declare
  t uuid := '61111111-aaaa-4aaa-8aaa-111111111111';
  c uuid := current_setting('test.cash_id')::uuid;
  b uuid := current_setting('test.bank_id')::uuid;
  value text;
  loc uuid;
  model jsonb;
  overview jsonb;
begin
  perform pg_temp.assert_true((select name = 'Yeni Kasa' and account_type = 'CASH' and currency_code = 'TRY'
    and status = 'ACTIVE' and location_id is null from public.finance_accounts where id = c), 'cash create normalization');
  perform pg_temp.assert_true((select account_type = 'BANK' and currency_code = 'USD'
    and location_id = '61111111-aaaa-4aaa-8aaa-999999999991' from public.finance_accounts where id = b), 'bank create');
  perform pg_temp.assert_true((select count(*) = 0 from public.finance_entries where account_id in (c, b)), 'no opening entries');
  foreach value in array array['', ' ', 'x', repeat('x',121), null] loop
    perform pg_temp.expect_error(format('select public.create_finance_account(%L,%L,''CASH'',''TRY'')',t,value), '22023', 'FINANCE_ACCOUNT_NAME_INVALID');
    perform pg_temp.expect_error(format('select public.update_finance_account(%L,%L,%L,''ACTIVE'')',t,c,value), '22023', 'FINANCE_ACCOUNT_NAME_INVALID');
  end loop;
  foreach value in array array['INVALID', 'cash', '', null] loop
    perform pg_temp.expect_error(format('select public.create_finance_account(%L,''Invalid type'',%L,''TRY'')',t,value), '22023', 'FINANCE_ACCOUNT_TYPE_INVALID');
  end loop;
  foreach value in array array['', 'TR', 'TRYY', '12X', 'T R', null] loop
    perform pg_temp.expect_error(format('select public.create_finance_account(%L,''Invalid currency'',''CASH'',%L)',t,value), '22023', 'FINANCE_ACCOUNT_CURRENCY_INVALID');
  end loop;
  foreach loc in array array['61111111-aaaa-4aaa-8aaa-999999999992'::uuid, '62222222-bbbb-4bbb-8bbb-999999999991'::uuid, '61111111-aaaa-4aaa-8aaa-999999999999'::uuid] loop
    perform pg_temp.expect_error(format('select public.create_finance_account(%L,''Invalid location'',''CASH'',''TRY'',%L)',t,loc), '22023', 'FINANCE_LOCATION_NOT_AVAILABLE');
  end loop;
  perform pg_temp.expect_error(format('select public.create_finance_account(%L,'' Yeni Kasa '',''BANK'',''EUR'')',t), '23505', 'FINANCE_ACCOUNT_NAME_EXISTS');
  perform pg_temp.expect_error(format('select public.update_finance_account(%L,%L,''Yeni Banka'',''ACTIVE'')',t,c), '23505', 'FINANCE_ACCOUNT_NAME_EXISTS');
  perform pg_temp.expect_error(format('select public.update_finance_account(%L,%L,'' Yeni Kasa '',''ACTIVE'')',t,c), '22023', 'FINANCE_ACCOUNT_NO_CHANGES');
  foreach value in array array['INVALID', 'active', '', null] loop
    perform pg_temp.expect_error(format('select public.update_finance_account(%L,%L,''Yeni Kasa'',%L)',t,c,value), '22023', 'FINANCE_ACCOUNT_STATUS_INVALID');
  end loop;
  perform pg_temp.expect_error(format('select public.update_finance_account(%L,''62222222-bbbb-4bbb-8bbb-555555555551'',''Cross tenant'',''ACTIVE'')',t), '22023', 'FINANCE_ACCOUNT_NOT_AVAILABLE');
  perform pg_temp.expect_error('select public.create_finance_account(''62222222-bbbb-4bbb-8bbb-222222222222'',''Cross tenant'',''CASH'',''TRY'')', '42501');
  perform pg_temp.expect_error('select public.get_finance_account_management(''62222222-bbbb-4bbb-8bbb-222222222222'')', '42501');

  perform public.update_finance_account(t, c, '  Ana Kasa  ', 'ACTIVE');
  perform public.update_finance_account(t, c, 'Ana Kasa', 'PASSIVE');
  perform public.update_finance_account(t, c, 'Ana Kasa', 'ACTIVE');
  perform public.update_finance_account(t, c, 'Ana Kasa', 'PASSIVE');
  perform public.create_finance_adjustment(t, b, 80, 'Opening adjustment');
  perform public.create_finance_cashflow(t, b, 'EXPENSE', 20, 'Expense after creation');
  perform pg_temp.expect_error(format('select public.update_finance_account(%L,%L,''Yeni Banka'',''PASSIVE'')',t,b), '22023', 'FINANCE_ACCOUNT_NON_ZERO_BALANCE');
  -- Negative balances must also block deactivation.
  perform public.create_finance_adjustment(t, '61111111-aaaa-4aaa-8aaa-555555555551', -10, 'Negative balance');
  perform pg_temp.expect_error(format('select public.update_finance_account(%L,''61111111-aaaa-4aaa-8aaa-555555555551'',''Negative'',''PASSIVE'')',t), '22023', 'FINANCE_ACCOUNT_NON_ZERO_BALANCE');
  -- Existing command validation must continue to reject passive accounts.
  perform pg_temp.expect_error(format('select public.create_finance_cashflow(%L,%L,''INCOME'',10,''Passive cashflow'')',t,c), '22023');
  perform pg_temp.expect_error(format('select public.create_finance_adjustment(%L,%L,10,''Passive adjustment'')',t,c), '22023');
  perform pg_temp.expect_error(format('select public.create_finance_transfer(%L,%L,''61111111-aaaa-4aaa-8aaa-555555555552'',10,''Passive transfer'')',t,c), '22023');

  model := public.get_finance_account_management(t);
  perform pg_temp.assert_true(model->>'tenantId' = t::text, 'management tenant');
  perform pg_temp.assert_true(jsonb_array_length(model->'accounts') = 5, 'all accounts returned');
  perform pg_temp.assert_true(exists(select 1 from jsonb_array_elements(model->'accounts') a where a->>'id' = c::text
    and a->>'name' = 'Ana Kasa' and a->>'status' = 'PASSIVE' and (a->>'balance')::numeric = 0
    and a->'locationId' = 'null'::jsonb), 'passive zero account in management');
  perform pg_temp.assert_true(exists(select 1 from jsonb_array_elements(model->'accounts') a where a->>'id' = b::text
    and a->>'status' = 'ACTIVE' and (a->>'balance')::numeric = 60
    and a->>'accountType' = 'BANK' and a->>'currencyCode' = 'USD'
    and a->>'locationId' = '61111111-aaaa-4aaa-8aaa-999999999991' and a->>'locationName' = 'Merkez'), 'derived balance and immutable fields');
  overview := public.get_finance_overview(t);
  perform pg_temp.assert_true(not exists(select 1 from jsonb_array_elements(overview->'accounts') a where a->>'id' = c::text), 'passive excluded from overview');
  perform pg_temp.assert_true((select status = 'ACTIVE' and name = 'Yeni Banka' from public.finance_accounts where id = b), 'rejected update atomic');
  -- Browser account writes remain revoked.
  perform pg_temp.assert_true(not has_table_privilege('authenticated','public.finance_accounts','INSERT')
    and not has_table_privilege('authenticated','public.finance_accounts','UPDATE')
    and not has_table_privilege('authenticated','public.finance_accounts','DELETE'), 'no direct browser writes or delete');
end;
$$;

reset role;
do $$
declare
  c uuid := current_setting('test.cash_id')::uuid;
  b uuid := current_setting('test.bank_id')::uuid;
  signature text;
begin
  perform pg_temp.assert_true((select count(*) = 2 from public.audit_logs where tenant_id = '61111111-aaaa-4aaa-8aaa-111111111111' and action = 'FINANCE_ACCOUNT_CREATED'), 'create audit count');
  perform pg_temp.assert_true((select count(*) = 1 from public.audit_logs where entity_id = c and action = 'FINANCE_ACCOUNT_CREATED'
    and entity_type = 'finance_account' and actor_user_id = '61111111-6666-4666-8666-111111111111'
    and metadata = jsonb_build_object('accountId', c, 'name', 'Yeni Kasa', 'accountType','CASH','currencyCode','TRY','locationId',null)), 'cash audit metadata');
  perform pg_temp.assert_true((select count(*) = 1 from public.audit_logs where entity_id = b and action = 'FINANCE_ACCOUNT_CREATED'
    and location_id = '61111111-aaaa-4aaa-8aaa-999999999991'
    and metadata = jsonb_build_object('accountId',b,'name','Yeni Banka','accountType','BANK','currencyCode','USD','locationId','61111111-aaaa-4aaa-8aaa-999999999991')), 'bank audit metadata');
  perform pg_temp.assert_true((select count(*) = 4 from public.audit_logs where entity_id = c and action = 'FINANCE_ACCOUNT_UPDATED'), 'no redundant audits');
  perform pg_temp.assert_true((select count(*) = 0 from public.audit_logs where entity_id = b and action = 'FINANCE_ACCOUNT_UPDATED'), 'failed update no audit');
  perform pg_temp.assert_true(exists(select 1 from public.audit_logs where entity_id = c and action = 'FINANCE_ACCOUNT_UPDATED'
    and actor_user_id = '61111111-6666-4666-8666-111111111111' and entity_type = 'finance_account'
    and metadata = jsonb_build_object('accountId',c,'oldName','Yeni Kasa','newName','Ana Kasa','oldStatus','ACTIVE','newStatus','ACTIVE')), 'rename audit');
  perform pg_temp.assert_true(exists(select 1 from public.audit_logs where entity_id = c and action = 'FINANCE_ACCOUNT_UPDATED'
    and metadata = jsonb_build_object('accountId',c,'oldName','Ana Kasa','newName','Ana Kasa','oldStatus','PASSIVE','newStatus','ACTIVE')), 'reactivation audit');
  perform pg_temp.assert_true((select account_type = 'CASH' and currency_code = 'TRY' and location_id is null from public.finance_accounts where id = c), 'immutable fields after updates');
  -- Even a writer that validated ACTIVE before deactivation must be rejected
  -- at ledger insertion; the trigger's shared lock serializes with the update.
  perform pg_temp.expect_error(format(
    'insert into public.finance_entries(tenant_id,transaction_id,account_id,amount) values(%L,%L,%L,1)',
    '61111111-aaaa-4aaa-8aaa-111111111111',
    (select id from public.finance_transactions where tenant_id = '61111111-aaaa-4aaa-8aaa-111111111111' limit 1), c
  ), '22023', 'FINANCE_ACCOUNT_NOT_AVAILABLE');
  foreach signature in array array['public.create_finance_account(uuid,text,text,text,uuid)', 'public.update_finance_account(uuid,uuid,text,text)', 'public.get_finance_account_management(uuid)'] loop
    perform pg_temp.assert_true(not has_function_privilege('anon',signature,'EXECUTE')
      and has_function_privilege('authenticated',signature,'EXECUTE') and has_function_privilege('service_role',signature,'EXECUTE'), 'RPC role grants');
    perform pg_temp.assert_true(not exists(select 1 from pg_proc p, lateral aclexplode(coalesce(p.proacl, acldefault('f',p.proowner))) a
      where p.oid = signature::regprocedure and a.grantee = 0 and a.privilege_type = 'EXECUTE'), 'PUBLIC revoked');
    perform pg_temp.assert_true((select prosecdef and proconfig @> array['search_path=""'] from pg_proc where oid = signature::regprocedure), 'security definer config');
  end loop;
end;
$$;

-- Read-only, disabled module and missing-auth callers cannot write.
set local role authenticated;
do $$
declare
  u uuid;
  t uuid;
  a uuid;
begin
  foreach u in array array['61111111-7777-4777-8777-111111111111'::uuid, '63333333-6666-4666-8666-333333333333'::uuid, null::uuid] loop
    perform set_config('request.jwt.claim.sub',coalesce(u::text,''),true);
    t := case when u = '63333333-6666-4666-8666-333333333333' then '63333333-cccc-4ccc-8ccc-333333333333'::uuid else '61111111-aaaa-4aaa-8aaa-111111111111'::uuid end;
    a := case when u = '63333333-6666-4666-8666-333333333333' then '63333333-cccc-4ccc-8ccc-555555555551'::uuid else current_setting('test.cash_id')::uuid end;
    perform pg_temp.expect_error(format('select public.create_finance_account(%L,''Unauthorized'',''CASH'',''TRY'')',t), '42501');
    perform pg_temp.expect_error(format('select public.update_finance_account(%L,%L,''Unauthorized'',''ACTIVE'')',t,a), '42501');
    if u = '61111111-7777-4777-8777-111111111111' then
      perform pg_temp.assert_true(jsonb_array_length(public.get_finance_account_management(t)->'accounts') = 5, 'read-only read allowed');
    else
      perform pg_temp.expect_error(format('select public.get_finance_account_management(%L)',t), '42501');
    end if;
  end loop;
end;
$$;
set local role anon;
select pg_temp.expect_error('select public.create_finance_account(''61111111-aaaa-4aaa-8aaa-111111111111'',''Anonymous'',''CASH'',''TRY'')','42501');
select pg_temp.expect_error('select public.update_finance_account(''61111111-aaaa-4aaa-8aaa-111111111111'',''61111111-aaaa-4aaa-8aaa-555555555551'',''Anonymous'',''ACTIVE'')','42501');
select pg_temp.expect_error('select public.get_finance_account_management(''61111111-aaaa-4aaa-8aaa-111111111111'')','42501');
rollback;

do $$
begin
  if exists(select 1 from auth.users where id in ('61111111-6666-4666-8666-111111111111','61111111-7777-4777-8777-111111111111','63333333-6666-4666-8666-333333333333'))
    or exists(select 1 from public.tenants where id in ('61111111-aaaa-4aaa-8aaa-111111111111','62222222-bbbb-4bbb-8bbb-222222222222','63333333-cccc-4ccc-8ccc-333333333333')) then
    raise exception 'ACCOUNT_MANAGEMENT_ROLLBACK_RESIDUALS';
  end if;
end;
$$;
select 'PASS - FINANCE ACCOUNT MANAGEMENT' as result,
  (select count(*) from auth.users where id in ('61111111-6666-4666-8666-111111111111','61111111-7777-4777-8777-111111111111','63333333-6666-4666-8666-333333333333')) as residual_test_users,
  (select count(*) from public.tenants where id in ('61111111-aaaa-4aaa-8aaa-111111111111','62222222-bbbb-4bbb-8bbb-222222222222','63333333-cccc-4ccc-8ccc-333333333333')) as residual_test_tenants;
