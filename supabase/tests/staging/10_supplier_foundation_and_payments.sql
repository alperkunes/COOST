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
  '71111111-6666-4666-8666-111111111111',
  'authenticated',
  'authenticated',
  'supplier-writer@coost.test',
  now(),
  now()
),
(
  '71111111-7777-4777-8777-111111111111',
  'authenticated',
  'authenticated',
  'supplier-reader@coost.test',
  now(),
  now()
),
(
  '73333333-6666-4666-8666-333333333333',
  'authenticated',
  'authenticated',
  'supplier-disabled@coost.test',
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
  '71111111-aaaa-4aaa-8aaa-111111111111',
  'Supplier Tenant A',
  'ACTIVE'
),
(
  '72222222-bbbb-4bbb-8bbb-222222222222',
  'Supplier Tenant B',
  'ACTIVE'
),
(
  '73333333-cccc-4ccc-8ccc-333333333333',
  'Supplier Disabled Tenant',
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
  '71111111-1111-4111-8111-111111111111',
  '71111111-aaaa-4aaa-8aaa-111111111111',
  '71111111-6666-4666-8666-111111111111',
  'ACTIVE'
),
(
  '71111111-2222-4222-8222-111111111111',
  '71111111-aaaa-4aaa-8aaa-111111111111',
  '71111111-7777-4777-8777-111111111111',
  'ACTIVE'
),
(
  '73333333-1111-4111-8111-333333333333',
  '73333333-cccc-4ccc-8ccc-333333333333',
  '73333333-6666-4666-8666-333333333333',
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
  '71111111-3333-4333-8333-111111111111',
  '71111111-aaaa-4aaa-8aaa-111111111111',
  'finance-writer',
  'Finance Writer',
  true
),
(
  '71111111-4444-4444-8444-111111111111',
  '71111111-aaaa-4aaa-8aaa-111111111111',
  'finance-reader',
  'Finance Reader',
  true
),
(
  '73333333-3333-4333-8333-333333333333',
  '73333333-cccc-4ccc-8ccc-333333333333',
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
  '71111111-aaaa-4aaa-8aaa-111111111111',
  '71111111-1111-4111-8111-111111111111',
  '71111111-3333-4333-8333-111111111111'
),
(
  '71111111-aaaa-4aaa-8aaa-111111111111',
  '71111111-2222-4222-8222-111111111111',
  '71111111-4444-4444-8444-111111111111'
),
(
  '73333333-cccc-4ccc-8ccc-333333333333',
  '73333333-1111-4111-8111-333333333333',
  '73333333-3333-4333-8333-333333333333'
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
  '71111111-aaaa-4aaa-8aaa-111111111111',
  '71111111-3333-4333-8333-111111111111',
  'finance.read'
),
(
  '71111111-aaaa-4aaa-8aaa-111111111111',
  '71111111-3333-4333-8333-111111111111',
  'finance.write'
),
(
  '71111111-aaaa-4aaa-8aaa-111111111111',
  '71111111-4444-4444-8444-111111111111',
  'finance.read'
),
(
  '73333333-cccc-4ccc-8ccc-333333333333',
  '73333333-3333-4333-8333-333333333333',
  'finance.read'
),
(
  '73333333-cccc-4ccc-8ccc-333333333333',
  '73333333-3333-4333-8333-333333333333',
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
  '71111111-aaaa-4aaa-8aaa-111111111111',
  'finance',
  true
),
(
  '72222222-bbbb-4bbb-8bbb-222222222222',
  'finance',
  true
),
(
  '73333333-cccc-4ccc-8ccc-333333333333',
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
  '71111111-aaaa-4aaa-8aaa-555555555551',
  '71111111-aaaa-4aaa-8aaa-111111111111',
  'Tenant A Ziraat',
  'BANK',
  'TRY'
),
(
  '71111111-aaaa-4aaa-8aaa-555555555552',
  '71111111-aaaa-4aaa-8aaa-111111111111',
  'Tenant A Nakit',
  'CASH',
  'TRY'
),
(
  '71111111-aaaa-4aaa-8aaa-555555555553',
  '71111111-aaaa-4aaa-8aaa-111111111111',
  'Tenant A USD Bank',
  'BANK',
  'USD'
),
(
  '72222222-bbbb-4bbb-8bbb-555555555551',
  '72222222-bbbb-4bbb-8bbb-222222222222',
  'Tenant B Nakit',
  'CASH',
  'TRY'
),
(
  '73333333-cccc-4ccc-8ccc-555555555551',
  '73333333-cccc-4ccc-8ccc-333333333333',
  'Disabled Bank',
  'BANK',
  'TRY'
),
(
  '73333333-cccc-4ccc-8ccc-555555555552',
  '73333333-cccc-4ccc-8ccc-333333333333',
  'Disabled Cash',
  'CASH',
  'TRY'
);

-- ------------------------------------------------------------
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

-- Writer deliberately has no finance.read: payment authority is explicit.
delete from public.role_permissions where role_id = '71111111-3333-4333-8333-111111111111' and permission_key = 'finance.read';
insert into public.role_permissions(tenant_id,role_id,permission_key)
select '71111111-aaaa-4aaa-8aaa-111111111111','71111111-3333-4333-8333-111111111111',p
from unnest(array['suppliers.read','suppliers.write','suppliers.pay']) p;
insert into public.role_permissions(tenant_id,role_id,permission_key)
values ('71111111-aaaa-4aaa-8aaa-111111111111','71111111-4444-4444-8444-111111111111','suppliers.read');
insert into public.tenant_modules(tenant_id,module_key,enabled) values
('71111111-aaaa-4aaa-8aaa-111111111111','suppliers',true),
('72222222-bbbb-4bbb-8bbb-222222222222','suppliers',true);
insert into public.locations(id,tenant_id,name) values('71111111-aaaa-4aaa-8aaa-999999999991','71111111-aaaa-4aaa-8aaa-111111111111','Merkez');
update public.finance_accounts set location_id = '71111111-aaaa-4aaa-8aaa-999999999991' where id = '71111111-aaaa-4aaa-8aaa-555555555551';
update public.finance_accounts set status = 'PASSIVE' where id = '71111111-aaaa-4aaa-8aaa-555555555552';
insert into public.suppliers(id,tenant_id,name) values('72222222-bbbb-4bbb-8bbb-888888888888','72222222-bbbb-4bbb-8bbb-222222222222','Other tenant');

set local role authenticated;
select set_config('request.jwt.claim.sub','71111111-6666-4666-8666-111111111111',true);
select set_config('test.supplier',public.create_supplier('71111111-aaaa-4aaa-8aaa-111111111111','  Test   Supplier  ','1234567890',' 555 ',' SALES@EXAMPLE.COM ',' note ')::text,true);
select set_config('test.passive',public.create_supplier('71111111-aaaa-4aaa-8aaa-111111111111','Passive Supplier')::text,true);
select set_config('test.positive',public.create_supplier('71111111-aaaa-4aaa-8aaa-111111111111','Positive Supplier')::text,true);
do $$
declare t uuid := '71111111-aaaa-4aaa-8aaa-111111111111'; s uuid := current_setting('test.supplier')::uuid; v text;
begin
  perform pg_temp.assert_true((select name = 'Test Supplier' and email = 'sales@example.com' and phone = '555' and notes = 'note' and status = 'ACTIVE' from public.suppliers where id = s),'supplier normalization');
  perform pg_temp.expect_error(format('select public.create_supplier(%L,'' test  supplier '')',t),'23505','SUPPLIER_NAME_EXISTS');
  foreach v in array array['','x',repeat('x',161),null] loop
    perform pg_temp.expect_error(format('select public.create_supplier(%L,%L)',t,v),'22023','SUPPLIER_NAME_INVALID');
  end loop;
  foreach v in array array['123','123456789A','123456789012'] loop
    perform pg_temp.expect_error(format('select public.create_supplier(%L,''Invalid tax'',%L)',t,v),'22023','SUPPLIER_TAX_NUMBER_INVALID');
  end loop;
  perform pg_temp.expect_error(format('select public.create_supplier(%L,''Invalid contact'',null,%L)',t,repeat('x',41)),'22023');
  perform pg_temp.expect_error(format('select public.create_supplier(%L,''Invalid contact'',null,null,''bad-email'')',t),'22023');
  perform public.update_supplier(t,s,'Renamed Supplier','12345678901','555','sales@example.com','note','ACTIVE');
  perform pg_temp.expect_error(format('select public.update_supplier(%L,%L,''Renamed Supplier'',''12345678901'',''555'',''sales@example.com'',''note'',''ACTIVE'')',t,s),'22023','SUPPLIER_NO_CHANGES');
  perform public.update_supplier(t,s,'Renamed Supplier','12345678901','555','sales@example.com','note','PASSIVE');
  perform public.update_supplier(t,s,'Renamed Supplier','12345678901','555','sales@example.com','note','ACTIVE');
  perform public.update_supplier(t,current_setting('test.passive')::uuid,'Passive Supplier',null,null,null,null,'PASSIVE');
  perform pg_temp.expect_error(format('select public.update_supplier(%L,''72222222-bbbb-4bbb-8bbb-888888888888'',''Wrong'',null,null,null,null,''ACTIVE'')',t),'22023');
  perform pg_temp.expect_error('select public.get_supplier_overview(''72222222-bbbb-4bbb-8bbb-222222222222'')','42501');
  perform pg_temp.assert_true(not private.has_permission(t,'finance.read'),'no finance.read');
  perform pg_temp.assert_true(jsonb_array_length(public.get_supplier_payment_context(t)->'accounts') = 2,'context active only without finance.read');
end;
$$;
reset role;
-- Simulate future invoice posting through trusted backend data, no public invoice RPC.
insert into public.supplier_ledger_entries(tenant_id,supplier_id,entry_type,currency_code,amount,occurred_at,description,source_type,created_by_user_id)
values
('71111111-aaaa-4aaa-8aaa-111111111111',current_setting('test.supplier')::uuid,'INVOICE','TRY',100,now(),'Invoice TRY','INVOICE','71111111-6666-4666-8666-111111111111'),
('71111111-aaaa-4aaa-8aaa-111111111111',current_setting('test.supplier')::uuid,'INVOICE','EUR',30,now(),'Invoice EUR','INVOICE','71111111-6666-4666-8666-111111111111'),
('71111111-aaaa-4aaa-8aaa-111111111111',current_setting('test.positive')::uuid,'INVOICE','TRY',50,now(),'Positive debt','INVOICE','71111111-6666-4666-8666-111111111111');
set local role authenticated;
select set_config('test.payment',public.create_supplier_payment('71111111-aaaa-4aaa-8aaa-111111111111',current_setting('test.supplier')::uuid,
'71111111-aaaa-4aaa-8aaa-555555555551',120.556,'  Supplier payment  ','2026-09-25T12:00:00Z')::text,true);
do $$
declare
  t uuid := '71111111-aaaa-4aaa-8aaa-111111111111'; s uuid := current_setting('test.supplier')::uuid;
  a uuid := '71111111-aaaa-4aaa-8aaa-555555555551'; n numeric; d text; model jsonb;
begin
  foreach n in array array[0,0.004,-1,-0.004,null,'NaN'::numeric,'Infinity'::numeric] loop
    perform pg_temp.expect_error(format('select public.create_supplier_payment(%L,%L,%L,%L,''Invalid amount'')',t,s,a,n),'22023');
  end loop;
  perform pg_temp.expect_error(format('select public.create_supplier_payment(%L,%L,%L,100000000000000,''Overflow'')',t,s,a),'22003');
  foreach d in array array['','x',repeat('x',501),null] loop
    perform pg_temp.expect_error(format('select public.create_supplier_payment(%L,%L,%L,1,%L)',t,s,a,d),'22023');
  end loop;
  perform pg_temp.expect_error(format('select public.create_supplier_payment(%L,''72222222-bbbb-4bbb-8bbb-888888888888'',%L,1,''Cross supplier'')',t,a),'22023');
  perform pg_temp.expect_error(format('select public.create_supplier_payment(%L,%L,''72222222-bbbb-4bbb-8bbb-555555555551'',1,''Cross account'')',t,s),'22023');
  perform pg_temp.expect_error(format('select public.create_supplier_payment(%L,%L,%L,1,''Passive supplier'')',t,current_setting('test.passive'),a),'22023');
  perform pg_temp.expect_error(format('select public.create_supplier_payment(%L,%L,''71111111-aaaa-4aaa-8aaa-555555555552'',1,''Passive account'')',t,s),'22023');
  perform pg_temp.expect_error(format('select public.update_supplier(%L,%L,''Renamed Supplier'',null,null,null,null,''PASSIVE'')',t,s),'22023','SUPPLIER_NON_ZERO_BALANCE');
  perform pg_temp.expect_error(format('select public.update_supplier(%L,%L,''Positive Supplier'',null,null,null,null,''PASSIVE'')',t,current_setting('test.positive')),'22023','SUPPLIER_NON_ZERO_BALANCE');
  model := public.get_supplier_overview(t);
  perform pg_temp.assert_true(jsonb_array_length(model->'suppliers') = 3,'all suppliers, no other tenant');
  perform pg_temp.assert_true(exists(select 1 from jsonb_array_elements(model->'suppliers') x, lateral jsonb_array_elements(x->'balances') b
    where x->>'id' = s::text and b->>'currencyCode' = 'TRY' and (b->>'amount')::numeric = -20.56),'advance supported');
  perform pg_temp.assert_true(exists(select 1 from jsonb_array_elements(model->'suppliers') x, lateral jsonb_array_elements(x->'balances') b
    where x->>'id' = s::text and b->>'currencyCode' = 'EUR' and (b->>'amount')::numeric = 30),'currencies separate');
  perform pg_temp.assert_true(exists(select 1 from jsonb_array_elements(model->'suppliers') x where x->>'status' = 'PASSIVE'),'passive read model');
  perform pg_temp.assert_true(model->'recentPayments'->0->>'supplierName' = 'Renamed Supplier'
    and model->'recentPayments'->0->>'financeAccountId' = a::text,'recent payments names and account');
  perform pg_temp.assert_true(exists(select 1 from jsonb_array_elements(public.get_supplier_payment_context(t)->'accounts') x
    where x->>'id' = a::text and (x->>'derivedBalance')::numeric = -120.56),'finance negative balance allowed');
end;
$$;

-- Fault injection AFTER financial writes proves the whole command rolls back.
reset role;
create function pg_temp.fail_supplier_entry() returns trigger language plpgsql as $$
begin if new.description = 'Force rollback' then raise exception 'FORCED_FAILURE' using errcode = '22023'; end if; return new; end;
$$;
create trigger test_fail_supplier_entry before insert on public.supplier_ledger_entries for each row execute function pg_temp.fail_supplier_entry();
set local role authenticated;
select pg_temp.expect_error(format('select public.create_supplier_payment(%L,%L,%L,1,''Force rollback'')',
'71111111-aaaa-4aaa-8aaa-111111111111',current_setting('test.supplier'),'71111111-aaaa-4aaa-8aaa-555555555551'),'22023','FORCED_FAILURE');
reset role;
drop trigger test_fail_supplier_entry on public.supplier_ledger_entries;

-- Validate linkage, signs, metadata and immutable business events.
do $$
declare
  p public.supplier_payments%rowtype;
  signature text;
  tab text;
begin
  select * into strict p from public.supplier_payments where id = current_setting('test.payment')::uuid;
  perform pg_temp.assert_true(p.amount = 120.56 and p.currency_code = 'TRY' and p.description = 'Supplier payment'
    and p.occurred_at = '2026-09-25T12:00:00Z'::timestamptz,'payment rounding and metadata');
  perform pg_temp.assert_true((select count(*) = 1 from public.finance_transactions where id = p.finance_transaction_id
    and tenant_id = p.tenant_id and source_type = 'SUPPLIER_PAYMENT' and source_id = p.id and transaction_type = 'EXPENSE'
    and location_id = '71111111-aaaa-4aaa-8aaa-999999999991' and created_by_user_id = p.created_by_user_id),'finance source and location');
  perform pg_temp.assert_true((select count(*) = 1 from public.finance_entries where transaction_id = p.finance_transaction_id
    and account_id = p.finance_account_id and tenant_id = p.tenant_id and amount = -120.56),'finance sign');
  perform pg_temp.assert_true((select count(*) = 1 from public.supplier_ledger_entries where supplier_id = p.supplier_id
    and tenant_id = p.tenant_id and entry_type = 'PAYMENT' and source_type = 'SUPPLIER_PAYMENT' and source_id = p.id
    and amount = -120.56 and currency_code = p.currency_code and occurred_at = p.occurred_at),'supplier sign and source');
  perform pg_temp.assert_true((select count(*) = 1 from public.audit_logs where entity_id = p.id and action = 'SUPPLIER_PAYMENT_CREATED'
    and tenant_id = p.tenant_id and actor_user_id = p.created_by_user_id and metadata = jsonb_build_object(
      'paymentId',p.id,'supplierId',p.supplier_id,'financeAccountId',p.finance_account_id,'financeTransactionId',p.finance_transaction_id,
      'amount',p.amount,'currencyCode',p.currency_code,'description',p.description)),'payment audit');
  perform pg_temp.assert_true(exists(select 1 from public.audit_logs where entity_id = p.supplier_id and action = 'SUPPLIER_CREATED'
    and metadata->>'name' = 'Test Supplier' and metadata->>'taxNumber' = '1234567890' and metadata->>'email' = 'sales@example.com'),'create audit');
  perform pg_temp.assert_true(exists(select 1 from public.audit_logs where entity_id = p.supplier_id and action = 'SUPPLIER_UPDATED'
    and metadata->'old'->>'name' = 'Test Supplier' and metadata->'new'->>'name' = 'Renamed Supplier'),'update audit');
  perform pg_temp.assert_true((select count(*) = 3 from public.audit_logs where entity_id = p.supplier_id and action = 'SUPPLIER_UPDATED'),'no-changes no audit');
  perform pg_temp.assert_true((select count(*) = 1 from public.supplier_payments where tenant_id = p.tenant_id)
    and (select count(*) = 1 from public.finance_transactions where tenant_id = p.tenant_id)
    and (select count(*) = 1 from public.finance_entries where tenant_id = p.tenant_id)
    and (select count(*) = 4 from public.supplier_ledger_entries where tenant_id = p.tenant_id),'rejections leave no writes');
  perform pg_temp.expect_error(format('update public.supplier_payments set description = ''Changed'' where id = %L',p.id),'55000');
  perform pg_temp.expect_error(format('delete from public.supplier_payments where id = %L',p.id),'55000');
  perform pg_temp.expect_error(format('update public.supplier_ledger_entries set amount = -1 where source_id = %L',p.id),'55000');
  perform pg_temp.expect_error(format('delete from public.supplier_ledger_entries where source_id = %L',p.id),'55000');
  foreach tab in array array['suppliers','supplier_payments','supplier_ledger_entries'] loop
    perform pg_temp.assert_true((select relrowsecurity from pg_class where oid = ('public.'||tab)::regclass),'RLS enabled');
    perform pg_temp.assert_true(not has_table_privilege('authenticated','public.'||tab,'INSERT') and not has_table_privilege('authenticated','public.'||tab,'UPDATE')
      and not has_table_privilege('authenticated','public.'||tab,'DELETE')
      and not has_table_privilege('authenticated','public.'||tab,'TRUNCATE')
      and not has_table_privilege('authenticated','public.'||tab,'TRIGGER')
      and not has_table_privilege('anon','public.'||tab,'SELECT'),'browser writes and anon reads revoked');
  end loop;
  foreach signature in array array['public.create_supplier(uuid,text,text,text,text,text)','public.update_supplier(uuid,uuid,text,text,text,text,text,text)',
    'public.get_supplier_overview(uuid,integer)','public.get_supplier_payment_context(uuid)','public.create_supplier_payment(uuid,uuid,uuid,numeric,text,timestamptz)'] loop
    perform pg_temp.assert_true(not has_function_privilege('anon',signature,'EXECUTE') and has_function_privilege('authenticated',signature,'EXECUTE')
      and has_function_privilege('service_role',signature,'EXECUTE'),'RPC grants');
    perform pg_temp.assert_true((select prosecdef and proconfig @> array['search_path=""'] from pg_proc where oid = signature::regprocedure),'definer search path');
    perform pg_temp.assert_true(not exists(select 1 from pg_proc f,lateral aclexplode(coalesce(f.proacl,acldefault('f',f.proowner))) acl
      where f.oid = signature::regprocedure and acl.grantee = 0 and acl.privilege_type = 'EXECUTE'),'PUBLIC execute revoked');
  end loop;
end;
$$;

-- Permission boundaries.
set local role authenticated;
select set_config('request.jwt.claim.sub','71111111-7777-4777-8777-111111111111',true);
select pg_temp.expect_error('select public.create_supplier(''71111111-aaaa-4aaa-8aaa-111111111111'',''Unauthorized'')','42501');
select pg_temp.expect_error('select public.update_supplier(''71111111-aaaa-4aaa-8aaa-111111111111'',current_setting(''test.supplier'')::uuid,''Unauthorized'',null,null,null,null,''ACTIVE'')','42501');
select pg_temp.expect_error('select public.create_supplier_payment(''71111111-aaaa-4aaa-8aaa-111111111111'',current_setting(''test.supplier'')::uuid,''71111111-aaaa-4aaa-8aaa-555555555551'',1,''Unauthorized'')','42501');
select pg_temp.expect_error('select public.get_supplier_payment_context(''71111111-aaaa-4aaa-8aaa-111111111111'')','42501');
select pg_temp.assert_true(jsonb_array_length(public.get_supplier_overview('71111111-aaaa-4aaa-8aaa-111111111111')->'suppliers') = 3,'reader overview');
select pg_temp.assert_true((select count(*) = 3 from public.suppliers),'supplier RLS tenant isolation');
reset role;
delete from public.role_permissions where role_id = '71111111-3333-4333-8333-111111111111' and permission_key = 'suppliers.write';
set local role authenticated;
select set_config('request.jwt.claim.sub','71111111-6666-4666-8666-111111111111',true);
select pg_temp.expect_error('select public.create_supplier(''71111111-aaaa-4aaa-8aaa-111111111111'',''Unauthorized'')','42501');
select pg_temp.expect_error('select public.update_supplier(''71111111-aaaa-4aaa-8aaa-111111111111'',current_setting(''test.supplier'')::uuid,''Unauthorized'',null,null,null,null,''ACTIVE'')','42501');
reset role;
insert into public.role_permissions(tenant_id,role_id,permission_key) values('71111111-aaaa-4aaa-8aaa-111111111111','71111111-3333-4333-8333-111111111111','suppliers.write');
delete from public.role_permissions where role_id = '71111111-3333-4333-8333-111111111111' and permission_key = 'suppliers.read';
set local role authenticated;
select set_config('request.jwt.claim.sub','71111111-6666-4666-8666-111111111111',true);
select pg_temp.expect_error('select public.get_supplier_overview(''71111111-aaaa-4aaa-8aaa-111111111111'')','42501');
reset role;
insert into public.role_permissions(tenant_id,role_id,permission_key) values('71111111-aaaa-4aaa-8aaa-111111111111','71111111-3333-4333-8333-111111111111','suppliers.read');
delete from public.role_permissions where role_id = '71111111-3333-4333-8333-111111111111' and permission_key = 'suppliers.pay';
set local role authenticated;
select set_config('request.jwt.claim.sub','71111111-6666-4666-8666-111111111111',true);
select pg_temp.expect_error('select public.create_supplier_payment(''71111111-aaaa-4aaa-8aaa-111111111111'',current_setting(''test.supplier'')::uuid,''71111111-aaaa-4aaa-8aaa-555555555551'',1,''Unauthorized'')','42501');
select pg_temp.expect_error('select public.get_supplier_payment_context(''71111111-aaaa-4aaa-8aaa-111111111111'')','42501');
reset role;
insert into public.role_permissions(tenant_id,role_id,permission_key) values('71111111-aaaa-4aaa-8aaa-111111111111','71111111-3333-4333-8333-111111111111','suppliers.pay');
delete from public.role_permissions where role_id = '71111111-3333-4333-8333-111111111111' and permission_key = 'finance.write';
set local role authenticated;
select set_config('request.jwt.claim.sub','71111111-6666-4666-8666-111111111111',true);
select pg_temp.expect_error('select public.create_supplier_payment(''71111111-aaaa-4aaa-8aaa-111111111111'',current_setting(''test.supplier'')::uuid,''71111111-aaaa-4aaa-8aaa-555555555551'',1,''Unauthorized'')','42501');
select pg_temp.expect_error('select public.get_supplier_payment_context(''71111111-aaaa-4aaa-8aaa-111111111111'')','42501');
reset role;
insert into public.role_permissions(tenant_id,role_id,permission_key) values('71111111-aaaa-4aaa-8aaa-111111111111','71111111-3333-4333-8333-111111111111','finance.write');
update public.tenant_modules set enabled = false where tenant_id = '71111111-aaaa-4aaa-8aaa-111111111111' and module_key = 'suppliers';
set local role authenticated;
select pg_temp.expect_error('select public.create_supplier(''71111111-aaaa-4aaa-8aaa-111111111111'',''Unauthorized'')','42501');
select pg_temp.expect_error('select public.update_supplier(''71111111-aaaa-4aaa-8aaa-111111111111'',current_setting(''test.supplier'')::uuid,''Unauthorized'',null,null,null,null,''ACTIVE'')','42501');
select pg_temp.expect_error('select public.get_supplier_overview(''71111111-aaaa-4aaa-8aaa-111111111111'')','42501');
select pg_temp.expect_error('select public.create_supplier_payment(''71111111-aaaa-4aaa-8aaa-111111111111'',current_setting(''test.supplier'')::uuid,''71111111-aaaa-4aaa-8aaa-555555555551'',1,''Unauthorized'')','42501');
select pg_temp.expect_error('select public.get_supplier_payment_context(''71111111-aaaa-4aaa-8aaa-111111111111'')','42501');
reset role;
update public.tenant_modules set enabled = true where tenant_id = '71111111-aaaa-4aaa-8aaa-111111111111' and module_key = 'suppliers';
update public.tenant_modules set enabled = false where tenant_id = '71111111-aaaa-4aaa-8aaa-111111111111' and module_key = 'finance';
set local role authenticated;
select pg_temp.expect_error('select public.create_supplier_payment(''71111111-aaaa-4aaa-8aaa-111111111111'',current_setting(''test.supplier'')::uuid,''71111111-aaaa-4aaa-8aaa-555555555551'',1,''Unauthorized'')','42501');
select pg_temp.expect_error('select public.get_supplier_payment_context(''71111111-aaaa-4aaa-8aaa-111111111111'')','42501');
reset role;
update public.tenant_modules set enabled = true where tenant_id = '71111111-aaaa-4aaa-8aaa-111111111111' and module_key = 'finance';
set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
select pg_temp.expect_error('select public.create_supplier(''71111111-aaaa-4aaa-8aaa-111111111111'',''Unauthorized'')','42501');
select pg_temp.expect_error('select public.update_supplier(''71111111-aaaa-4aaa-8aaa-111111111111'',current_setting(''test.supplier'')::uuid,''Unauthorized'',null,null,null,null,''ACTIVE'')','42501');
select pg_temp.expect_error('select public.get_supplier_overview(''71111111-aaaa-4aaa-8aaa-111111111111'')','42501');
select pg_temp.expect_error('select public.get_supplier_payment_context(''71111111-aaaa-4aaa-8aaa-111111111111'')','42501');
select pg_temp.expect_error('select public.create_supplier_payment(''71111111-aaaa-4aaa-8aaa-111111111111'',current_setting(''test.supplier'')::uuid,''71111111-aaaa-4aaa-8aaa-555555555551'',1,''Unauthorized'')','42501');
set local role anon;
select pg_temp.expect_error('select public.create_supplier(''71111111-aaaa-4aaa-8aaa-111111111111'',''Unauthorized'')','42501');
select pg_temp.expect_error('select public.update_supplier(''71111111-aaaa-4aaa-8aaa-111111111111'',current_setting(''test.supplier'')::uuid,''Unauthorized'',null,null,null,null,''ACTIVE'')','42501');
select pg_temp.expect_error('select public.get_supplier_overview(''71111111-aaaa-4aaa-8aaa-111111111111'')','42501');
select pg_temp.expect_error('select public.get_supplier_payment_context(''71111111-aaaa-4aaa-8aaa-111111111111'')','42501');
select pg_temp.expect_error('select public.create_supplier_payment(''71111111-aaaa-4aaa-8aaa-111111111111'',current_setting(''test.supplier'')::uuid,''71111111-aaaa-4aaa-8aaa-555555555551'',1,''Unauthorized'')','42501');
rollback;
do $$ begin
 if exists(select 1 from auth.users where id in ('71111111-6666-4666-8666-111111111111','71111111-7777-4777-8777-111111111111','73333333-6666-4666-8666-333333333333'))
 or exists(select 1 from public.tenants where id in ('71111111-aaaa-4aaa-8aaa-111111111111','72222222-bbbb-4bbb-8bbb-222222222222','73333333-cccc-4ccc-8ccc-333333333333')) then raise exception 'SUPPLIER_ROLLBACK_RESIDUALS'; end if;
end; $$;
select 'PASS - SUPPLIER FOUNDATION AND PAYMENTS' as result,
 (select count(*) from auth.users where id in ('71111111-6666-4666-8666-111111111111','71111111-7777-4777-8777-111111111111','73333333-6666-4666-8666-333333333333')) as residual_test_users,
 (select count(*) from public.tenants where id in ('71111111-aaaa-4aaa-8aaa-111111111111','72222222-bbbb-4bbb-8bbb-222222222222','73333333-cccc-4ccc-8ccc-333333333333')) as residual_test_tenants;
