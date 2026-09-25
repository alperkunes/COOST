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
  '81111111-6666-4666-8666-111111111111',
  'authenticated',
  'authenticated',
  'purchase-writer@coost.test',
  now(),
  now()
),
(
  '81111111-7777-4777-8777-111111111111',
  'authenticated',
  'authenticated',
  'purchase-reader@coost.test',
  now(),
  now()
),
(
  '83333333-6666-4666-8666-333333333333',
  'authenticated',
  'authenticated',
  'purchase-disabled@coost.test',
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
  '81111111-aaaa-4aaa-8aaa-111111111111',
  'Supplier Tenant A',
  'ACTIVE'
),
(
  '82222222-bbbb-4bbb-8bbb-222222222222',
  'Supplier Tenant B',
  'ACTIVE'
),
(
  '83333333-cccc-4ccc-8ccc-333333333333',
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
  '81111111-1111-4111-8111-111111111111',
  '81111111-aaaa-4aaa-8aaa-111111111111',
  '81111111-6666-4666-8666-111111111111',
  'ACTIVE'
),
(
  '81111111-2222-4222-8222-111111111111',
  '81111111-aaaa-4aaa-8aaa-111111111111',
  '81111111-7777-4777-8777-111111111111',
  'ACTIVE'
),
(
  '83333333-1111-4111-8111-333333333333',
  '83333333-cccc-4ccc-8ccc-333333333333',
  '83333333-6666-4666-8666-333333333333',
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
  '81111111-3333-4333-8333-111111111111',
  '81111111-aaaa-4aaa-8aaa-111111111111',
  'finance-writer',
  'Finance Writer',
  true
),
(
  '81111111-4444-4444-8444-111111111111',
  '81111111-aaaa-4aaa-8aaa-111111111111',
  'finance-reader',
  'Finance Reader',
  true
),
(
  '83333333-3333-4333-8333-333333333333',
  '83333333-cccc-4ccc-8ccc-333333333333',
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
  '81111111-aaaa-4aaa-8aaa-111111111111',
  '81111111-1111-4111-8111-111111111111',
  '81111111-3333-4333-8333-111111111111'
),
(
  '81111111-aaaa-4aaa-8aaa-111111111111',
  '81111111-2222-4222-8222-111111111111',
  '81111111-4444-4444-8444-111111111111'
),
(
  '83333333-cccc-4ccc-8ccc-333333333333',
  '83333333-1111-4111-8111-333333333333',
  '83333333-3333-4333-8333-333333333333'
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
  '81111111-aaaa-4aaa-8aaa-111111111111',
  '81111111-3333-4333-8333-111111111111',
  'finance.read'
),
(
  '81111111-aaaa-4aaa-8aaa-111111111111',
  '81111111-3333-4333-8333-111111111111',
  'finance.write'
),
(
  '81111111-aaaa-4aaa-8aaa-111111111111',
  '81111111-4444-4444-8444-111111111111',
  'finance.read'
),
(
  '83333333-cccc-4ccc-8ccc-333333333333',
  '83333333-3333-4333-8333-333333333333',
  'finance.read'
),
(
  '83333333-cccc-4ccc-8ccc-333333333333',
  '83333333-3333-4333-8333-333333333333',
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
  '81111111-aaaa-4aaa-8aaa-111111111111',
  'finance',
  true
),
(
  '82222222-bbbb-4bbb-8bbb-222222222222',
  'finance',
  true
),
(
  '83333333-cccc-4ccc-8ccc-333333333333',
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
  '81111111-aaaa-4aaa-8aaa-555555555551',
  '81111111-aaaa-4aaa-8aaa-111111111111',
  'Tenant A Ziraat',
  'BANK',
  'TRY'
),
(
  '81111111-aaaa-4aaa-8aaa-555555555552',
  '81111111-aaaa-4aaa-8aaa-111111111111',
  'Tenant A Nakit',
  'CASH',
  'TRY'
),
(
  '81111111-aaaa-4aaa-8aaa-555555555553',
  '81111111-aaaa-4aaa-8aaa-111111111111',
  'Tenant A USD Bank',
  'BANK',
  'USD'
),
(
  '82222222-bbbb-4bbb-8bbb-555555555551',
  '82222222-bbbb-4bbb-8bbb-222222222222',
  'Tenant B Nakit',
  'CASH',
  'TRY'
),
(
  '83333333-cccc-4ccc-8ccc-555555555551',
  '83333333-cccc-4ccc-8ccc-333333333333',
  'Disabled Bank',
  'BANK',
  'TRY'
),
(
  '83333333-cccc-4ccc-8ccc-555555555552',
  '83333333-cccc-4ccc-8ccc-333333333333',
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

-- Purchasing writer needs no supplier write/pay or finance permissions.
delete from public.role_permissions where role_id in ('81111111-3333-4333-8333-111111111111','81111111-4444-4444-8444-111111111111');
insert into public.role_permissions(tenant_id,role_id,permission_key) values
('81111111-aaaa-4aaa-8aaa-111111111111','81111111-3333-4333-8333-111111111111','purchasing.read'),
('81111111-aaaa-4aaa-8aaa-111111111111','81111111-3333-4333-8333-111111111111','purchasing.write'),
('81111111-aaaa-4aaa-8aaa-111111111111','81111111-4444-4444-8444-111111111111','purchasing.read');
insert into public.tenant_modules(tenant_id,module_key,enabled) values
('81111111-aaaa-4aaa-8aaa-111111111111','purchasing',true),('81111111-aaaa-4aaa-8aaa-111111111111','suppliers',true),
('82222222-bbbb-4bbb-8bbb-222222222222','purchasing',true),('82222222-bbbb-4bbb-8bbb-222222222222','suppliers',true);
insert into public.suppliers(id,tenant_id,name,status) values
('81111111-aaaa-4aaa-8aaa-888888888881','81111111-aaaa-4aaa-8aaa-111111111111','Supplier A','ACTIVE'),
('81111111-aaaa-4aaa-8aaa-888888888882','81111111-aaaa-4aaa-8aaa-111111111111','Supplier B','ACTIVE'),
('81111111-aaaa-4aaa-8aaa-888888888883','81111111-aaaa-4aaa-8aaa-111111111111','Passive Supplier','PASSIVE'),
('82222222-bbbb-4bbb-8bbb-888888888881','82222222-bbbb-4bbb-8bbb-222222222222','Other supplier','ACTIVE');
insert into public.locations(id,tenant_id,name,status) values
('81111111-aaaa-4aaa-8aaa-999999999991','81111111-aaaa-4aaa-8aaa-111111111111','Merkez','ACTIVE'),
('81111111-aaaa-4aaa-8aaa-999999999992','81111111-aaaa-4aaa-8aaa-111111111111','Kapalı','PASSIVE'),
('82222222-bbbb-4bbb-8bbb-999999999991','82222222-bbbb-4bbb-8bbb-222222222222','Other location','ACTIVE');
insert into public.supplier_ledger_entries(tenant_id,supplier_id,entry_type,currency_code,amount,occurred_at,description,source_type,created_by_user_id)
values('81111111-aaaa-4aaa-8aaa-111111111111','81111111-aaaa-4aaa-8aaa-888888888881','ADJUSTMENT','TRY',-1,now(),'Existing advance','TEST','81111111-6666-4666-8666-111111111111');
select set_config('test.lines','[{"description":"Exclusive line","unit":"adet","quantity":2,"unitPrice":10,"priceIncludesTax":false,"taxRate":20,"netAmount":99999},{"description":"Inclusive line","unit":"kg","quantity":1,"unitPrice":12,"priceIncludesTax":true,"taxRate":20},{"description":"Fractional line","unit":"kg","quantity":1.2345,"unitPrice":10,"priceIncludesTax":false,"taxRate":0}]',true);
select set_config('test.single','[{"description":"Invoice line","supplierProductCode":"SKU-1","unit":"adet","quantity":1,"unitPrice":101,"priceIncludesTax":false,"taxRate":0}]',true);
set local role authenticated;
select set_config('request.jwt.claim.sub','81111111-6666-4666-8666-111111111111',true);
select set_config('test.invoice',public.create_purchase_invoice_draft('81111111-aaaa-4aaa-8aaa-111111111111','81111111-aaaa-4aaa-8aaa-888888888881',
' INV-1 ','2026-09-25',' try ',current_setting('test.lines')::jsonb,'81111111-aaaa-4aaa-8aaa-999999999991','2026-10-25','  Invoice note  ')::text,true);
select set_config('test.other_invoice',public.create_purchase_invoice_draft('81111111-aaaa-4aaa-8aaa-111111111111','81111111-aaaa-4aaa-8aaa-888888888882',
'INV-1','2026-09-25','TRY',current_setting('test.single')::jsonb)::text,true);

do $$
declare
  t uuid := '81111111-aaaa-4aaa-8aaa-111111111111'; s uuid := '81111111-aaaa-4aaa-8aaa-888888888881';
  inv uuid := current_setting('test.invoice')::uuid; l jsonb := current_setting('test.single')::jsonb;
  detail jsonb; ctx jsonb; v text; n numeric; bad jsonb;
begin
  detail := public.get_purchase_invoice_detail(t,inv);
  perform pg_temp.assert_true(detail->'invoice'->>'status' = 'DRAFT' and (detail->'invoice'->>'subtotal')::numeric = 42.35
    and (detail->'invoice'->>'taxTotal')::numeric = 6 and (detail->'invoice'->>'grandTotal')::numeric = 48.35,'multiline totals ignore supplied money');
  perform pg_temp.assert_true(detail->'invoice'->>'invoiceNumber' = 'INV-1' and detail->'invoice'->>'currencyCode' = 'TRY'
    and detail->'invoice'->>'description' = 'Invoice note','header normalization');
  perform pg_temp.assert_true((detail->'lines'->0->>'netAmount')::numeric = 20 and (detail->'lines'->0->>'taxAmount')::numeric = 4,'exclusive tax');
  perform pg_temp.assert_true((detail->'lines'->1->>'netAmount')::numeric = 10 and (detail->'lines'->1->>'taxAmount')::numeric = 2,'inclusive tax');
  perform pg_temp.assert_true((detail->'lines'->2->>'quantity')::numeric = 1.2345 and (detail->'lines'->2->>'grossAmount')::numeric = 12.35,'four decimal quantity and rounding');
  ctx := public.get_purchase_invoice_context(t);
  perform pg_temp.assert_true(jsonb_array_length(ctx->'suppliers') = 2 and jsonb_array_length(ctx->'locations') = 1,'context active same tenant without supplier permissions');
  perform pg_temp.assert_true(not private.has_permission(t,'suppliers.write') and not private.has_permission(t,'suppliers.pay'),'independent purchasing write');
  perform pg_temp.expect_error(format('select public.create_purchase_invoice_draft(%L,%L,''INV-1'',''2026-09-25'',''TRY'',%L)',t,s,l),'23505','PURCHASE_INVOICE_NUMBER_EXISTS');
  foreach v in array array['81111111-aaaa-4aaa-8aaa-888888888883','82222222-bbbb-4bbb-8bbb-888888888881','81111111-aaaa-4aaa-8aaa-888888888889',null] loop
    perform pg_temp.expect_error(format('select public.create_purchase_invoice_draft(%L,%L,''Invalid supplier'',''2026-09-25'',''TRY'',%L)',t,v,l),'22023','SUPPLIER_NOT_AVAILABLE');
  end loop;
  foreach v in array array['81111111-aaaa-4aaa-8aaa-999999999992','82222222-bbbb-4bbb-8bbb-999999999991','81111111-aaaa-4aaa-8aaa-999999999999'] loop
    perform pg_temp.expect_error(format('select public.create_purchase_invoice_draft(%L,%L,''Invalid location'',''2026-09-25'',''TRY'',%L,%L)',t,s,l,v),'22023','PURCHASE_LOCATION_NOT_AVAILABLE');
  end loop;
  foreach v in array array['TR','TR12','',null] loop
    perform pg_temp.expect_error(format('select public.create_purchase_invoice_draft(%L,%L,''Invalid currency'',''2026-09-25'',%L,%L)',t,s,v,l),'22023','PURCHASE_CURRENCY_INVALID');
  end loop;
  perform pg_temp.expect_error(format('select public.create_purchase_invoice_draft(%L,%L,''Invalid due'',''2026-09-25'',''TRY'',%L,null,''2026-09-24'')',t,s,l),'22023','PURCHASE_DATES_INVALID');
  perform pg_temp.expect_error(format('select public.create_purchase_invoice_draft(%L,%L,''Invalid date'',null,''TRY'',%L)',t,s,l),'22023','PURCHASE_DATES_INVALID');
  foreach v in array array['[]','null','{}'] loop
    perform pg_temp.expect_error(format('select public.create_purchase_invoice_draft(%L,%L,''No lines'',''2026-09-25'',''TRY'',%L)',t,s,v),'22023');
  end loop;
  foreach n in array array[0,-1,0.00001] loop
    bad := jsonb_set(l,'{0,quantity}',to_jsonb(n));
    perform pg_temp.expect_error(format('select public.create_purchase_invoice_draft(%L,%L,''Invalid qty'',''2026-09-25'',''TRY'',%L)',t,s,bad),'22023');
  end loop;
  foreach v in array array['unitPrice','taxRate'] loop
    bad := jsonb_set(l,array['0',v],'-1'::jsonb);
    perform pg_temp.expect_error(format('select public.create_purchase_invoice_draft(%L,%L,''Invalid line'',''2026-09-25'',''TRY'',%L)',t,s,bad),'22023');
  end loop;
  bad := jsonb_set(l,'{0,taxRate}','101'::jsonb);
  perform pg_temp.expect_error(format('select public.create_purchase_invoice_draft(%L,%L,''Invalid tax'',''2026-09-25'',''TRY'',%L)',t,s,bad),'22023');
  bad := jsonb_set(l,'{0,quantity}','999999999999'::jsonb);
  perform pg_temp.expect_error(format('select public.create_purchase_invoice_draft(%L,%L,''Overflow'',''2026-09-25'',''TRY'',%L)',t,s,bad),'22003');
  perform public.update_purchase_invoice_draft(t,inv,s,'INV-1','2026-09-25','TRY',l);
  perform pg_temp.assert_true(jsonb_array_length(public.get_purchase_invoice_detail(t,inv)->'lines') = 1,'draft lines replaced');
  perform pg_temp.expect_error(format('select public.update_purchase_invoice_draft(%L,%L,%L,''INV-1'',''2026-09-25'',''TRY'',%L)',t,inv,s,l),'22023','PURCHASE_INVOICE_NO_CHANGES');
  perform pg_temp.expect_error(format('select public.update_purchase_invoice_draft(%L,%L,%L,''INV-1'',''2026-09-25'',''TRY'',''[]'')',t,inv,s),'22023');
  perform pg_temp.assert_true((public.get_purchase_invoice_detail(t,inv)->'invoice'->>'grandTotal')::numeric = 101,'rejected update preserves draft');
end;
$$;
reset role;
select pg_temp.assert_true((select count(*) = 1 from public.supplier_ledger_entries where tenant_id = '81111111-aaaa-4aaa-8aaa-111111111111'),'draft has no ledger effect');
-- Tamper stored draft totals; posting must recalculate from quantity/price/rate.
update public.purchase_invoices set subtotal = 999,tax_total = 0,grand_total = 999 where id = current_setting('test.invoice')::uuid;
update public.purchase_invoice_lines set net_amount = 999,tax_amount = 0,gross_amount = 999 where purchase_invoice_id = current_setting('test.invoice')::uuid;
set local role authenticated;
select public.post_purchase_invoice('81111111-aaaa-4aaa-8aaa-111111111111',current_setting('test.invoice')::uuid);
select pg_temp.expect_error(format('select public.post_purchase_invoice(%L,%L)','81111111-aaaa-4aaa-8aaa-111111111111',current_setting('test.invoice')),'55000','PURCHASE_INVOICE_ALREADY_POSTED');
select pg_temp.expect_error(format('select public.update_purchase_invoice_draft(%L,%L,%L,''INV-1'',''2026-09-25'',''TRY'',%L)',
'81111111-aaaa-4aaa-8aaa-111111111111',current_setting('test.invoice'),'81111111-aaaa-4aaa-8aaa-888888888881',current_setting('test.single')),'55000','PURCHASE_INVOICE_IMMUTABLE');
reset role;
do $$
declare t uuid := '81111111-aaaa-4aaa-8aaa-111111111111'; inv uuid := current_setting('test.invoice')::uuid;
begin
  perform pg_temp.assert_true((select status = 'POSTED' and grand_total = 101 and posted_at is not null
    and posted_by_user_id = '81111111-6666-4666-8666-111111111111' from public.purchase_invoices where id = inv),'posted header');
  perform pg_temp.assert_true((select count(*) = 1 and sum(amount) = 101 from public.supplier_ledger_entries
    where tenant_id = t and source_id = inv and entry_type = 'INVOICE' and source_type = 'PURCHASE_INVOICE' and currency_code = 'TRY'),'exactly one positive invoice entry');
  perform pg_temp.assert_true((select sum(amount) = 100 from public.supplier_ledger_entries
    where tenant_id = t and supplier_id = '81111111-aaaa-4aaa-8aaa-888888888881' and currency_code = 'TRY'),'minus one advance plus 101 invoice equals 100 debt');
  perform pg_temp.assert_true((select count(*) = 0 from public.finance_transactions where tenant_id = t)
    and (select count(*) = 0 from public.finance_entries where tenant_id = t),'no finance writes');
  perform pg_temp.expect_error(format('update public.purchase_invoices set description = ''Edited'' where id = %L',inv),'55000');
  perform pg_temp.expect_error(format('delete from public.purchase_invoices where id = %L',inv),'55000');
  perform pg_temp.expect_error(format('update public.purchase_invoice_lines set unit_price = 1 where purchase_invoice_id = %L',inv),'55000');
  perform pg_temp.expect_error(format('delete from public.purchase_invoice_lines where purchase_invoice_id = %L',inv),'55000');
  perform pg_temp.expect_error(format('insert into public.purchase_invoice_lines(tenant_id,purchase_invoice_id,line_no,description,unit,quantity,unit_price,price_includes_tax,tax_rate,net_amount,tax_amount,gross_amount) values(%L,%L,2,''Extra line'',''kg'',1,1,false,0,1,0,1)',t,inv),'55000');
  perform pg_temp.assert_true((select count(*) = 1 from public.audit_logs where entity_id = inv and action = 'PURCHASE_INVOICE_DRAFT_CREATED'
    and metadata->>'invoiceNumber' = 'INV-1' and (metadata->>'lineCount')::int = 3 and (metadata->>'grandTotal')::numeric = 48.35),'draft audit');
  perform pg_temp.assert_true((select count(*) = 1 from public.audit_logs where entity_id = inv and action = 'PURCHASE_INVOICE_DRAFT_UPDATED'
    and (metadata->>'lineCount')::int = 1 and (metadata->>'grandTotal')::numeric = 101),'update audit no redundant events');
  perform pg_temp.assert_true((select count(*) = 1 from public.audit_logs where entity_id = inv and action = 'PURCHASE_INVOICE_POSTED'
    and actor_user_id = '81111111-6666-4666-8666-111111111111' and metadata = jsonb_build_object('invoiceId',inv,
      'supplierId','81111111-aaaa-4aaa-8aaa-888888888881','invoiceNumber','INV-1','currencyCode','TRY','subtotal',101,'taxTotal',0,'grandTotal',101,'lineCount',1)),'post audit');
  perform pg_temp.assert_true((select count(*) = 2 from public.purchase_invoices where tenant_id = t)
    and (select count(*) = 2 from public.purchase_invoice_lines where tenant_id = t),'rejected creates leave no partial state');
end;
$$;
-- Reject posting if supplier/location is no longer active.
update public.suppliers set status = 'PASSIVE' where id = '81111111-aaaa-4aaa-8aaa-888888888882';
set local role authenticated;
select pg_temp.expect_error(format('select public.post_purchase_invoice(%L,%L)','81111111-aaaa-4aaa-8aaa-111111111111',current_setting('test.other_invoice')),'22023','SUPPLIER_NOT_AVAILABLE');
reset role;
update public.suppliers set status = 'ACTIVE' where id = '81111111-aaaa-4aaa-8aaa-888888888882';
update public.purchase_invoices set location_id = '81111111-aaaa-4aaa-8aaa-999999999991' where id = current_setting('test.other_invoice')::uuid;
update public.locations set status = 'PASSIVE' where id = '81111111-aaaa-4aaa-8aaa-999999999991';
set local role authenticated;
select pg_temp.expect_error(format('select public.post_purchase_invoice(%L,%L)','81111111-aaaa-4aaa-8aaa-111111111111',current_setting('test.other_invoice')),'22023','PURCHASE_LOCATION_NOT_AVAILABLE');
reset role;
update public.locations set status = 'ACTIVE' where id = '81111111-aaaa-4aaa-8aaa-999999999991';
-- Force ledger failure after invoice status update; all posting changes must roll back.
create function pg_temp.fail_invoice_post() returns trigger language plpgsql as $$
begin raise exception 'FORCED_POST_FAILURE' using errcode = '22023'; end;
$$;
create trigger test_invoice_post_failure before insert on public.supplier_ledger_entries for each row execute function pg_temp.fail_invoice_post();
set local role authenticated;
select pg_temp.expect_error(format('select public.post_purchase_invoice(%L,%L)','81111111-aaaa-4aaa-8aaa-111111111111',current_setting('test.other_invoice')),'22023','FORCED_POST_FAILURE');
reset role;
drop trigger test_invoice_post_failure on public.supplier_ledger_entries;
select pg_temp.assert_true((select status = 'DRAFT' and posted_at is null from public.purchase_invoices where id = current_setting('test.other_invoice')::uuid),'failed post preserves draft');
select pg_temp.assert_true((select count(*) = 0 from public.supplier_ledger_entries where source_id = current_setting('test.other_invoice')::uuid),'failed post leaves no ledger');
select pg_temp.assert_true((select count(*) = 0 from public.audit_logs where entity_id = current_setting('test.other_invoice')::uuid and action = 'PURCHASE_INVOICE_POSTED'),'failed post leaves no audit');
set local role authenticated;
select set_config('test.eur',public.create_purchase_invoice_draft('81111111-aaaa-4aaa-8aaa-111111111111','81111111-aaaa-4aaa-8aaa-888888888882',
'EUR-1','2026-09-25','EUR',current_setting('test.single')::jsonb)::text,true);
select public.post_purchase_invoice('81111111-aaaa-4aaa-8aaa-111111111111',current_setting('test.eur')::uuid);
do $$
declare model jsonb;
begin
 model := public.get_purchase_invoice_overview('81111111-aaaa-4aaa-8aaa-111111111111',1);
 perform pg_temp.assert_true(jsonb_array_length(model->'invoices') = 1 and (model->'summary'->>'postedCount')::int = 2
   and (model->'summary'->>'draftCount')::int = 1,'summary not limited by recent limit');
 perform pg_temp.assert_true(jsonb_array_length(model->'summary'->'postedTotals') = 2,'currency totals separate');
 perform pg_temp.assert_true(not (model->'invoices'->0 ? 'lines'),'overview excludes lines');
end;
$$;
reset role;
do $$
declare tab text; signature text;
begin
 foreach tab in array array['purchase_invoices','purchase_invoice_lines'] loop
  perform pg_temp.assert_true((select relrowsecurity from pg_class where oid = ('public.'||tab)::regclass),'RLS enabled');
  perform pg_temp.assert_true(not has_table_privilege('authenticated','public.'||tab,'INSERT') and not has_table_privilege('authenticated','public.'||tab,'UPDATE')
   and not has_table_privilege('authenticated','public.'||tab,'DELETE') and not has_table_privilege('authenticated','public.'||tab,'TRUNCATE')
   and not has_table_privilege('anon','public.'||tab,'SELECT'),'browser writes and anon reads revoked');
 end loop;
 foreach signature in array array['public.create_purchase_invoice_draft(uuid,uuid,text,date,text,jsonb,uuid,date,text)',
 'public.update_purchase_invoice_draft(uuid,uuid,uuid,text,date,text,jsonb,uuid,date,text)','public.post_purchase_invoice(uuid,uuid)',
 'public.get_purchase_invoice_overview(uuid,integer)','public.get_purchase_invoice_detail(uuid,uuid)','public.get_purchase_invoice_context(uuid)'] loop
  perform pg_temp.assert_true(not has_function_privilege('anon',signature,'EXECUTE') and has_function_privilege('authenticated',signature,'EXECUTE')
   and has_function_privilege('service_role',signature,'EXECUTE'),'RPC grants');
  perform pg_temp.assert_true((select prosecdef and proconfig @> array['search_path=""'] from pg_proc where oid = signature::regprocedure),'security definer config');
  perform pg_temp.assert_true(not exists(select 1 from pg_proc f,lateral aclexplode(coalesce(f.proacl,acldefault('f',f.proowner))) a
    where f.oid=signature::regprocedure and a.grantee=0 and a.privilege_type='EXECUTE'),'PUBLIC execute revoked');
 end loop;
end;
$$;

set local role authenticated;
select set_config('request.jwt.claim.sub','81111111-7777-4777-8777-111111111111',true);
select pg_temp.expect_error('select public.create_purchase_invoice_draft(''81111111-aaaa-4aaa-8aaa-111111111111'',''81111111-aaaa-4aaa-8aaa-888888888881'',''Denied'',''2026-09-25'',''TRY'',current_setting(''test.single'')::jsonb)','42501');
select pg_temp.expect_error('select public.update_purchase_invoice_draft(''81111111-aaaa-4aaa-8aaa-111111111111'',current_setting(''test.other_invoice'')::uuid,''81111111-aaaa-4aaa-8aaa-888888888881'',''Denied'',''2026-09-25'',''TRY'',current_setting(''test.single'')::jsonb)','42501');
select pg_temp.expect_error('select public.post_purchase_invoice(''81111111-aaaa-4aaa-8aaa-111111111111'',current_setting(''test.other_invoice'')::uuid)','42501');
select pg_temp.expect_error('select public.get_purchase_invoice_context(''81111111-aaaa-4aaa-8aaa-111111111111'')','42501');
select pg_temp.assert_true(jsonb_array_length(public.get_purchase_invoice_overview('81111111-aaaa-4aaa-8aaa-111111111111')->'invoices')=3,'read-only overview');
select pg_temp.assert_true(jsonb_array_length(public.get_purchase_invoice_detail('81111111-aaaa-4aaa-8aaa-111111111111',current_setting('test.other_invoice')::uuid)->'lines')=1,'read-only detail');
reset role;
delete from public.role_permissions where role_id='81111111-3333-4333-8333-111111111111' and permission_key='purchasing.read';
set local role authenticated;
select set_config('request.jwt.claim.sub','81111111-6666-4666-8666-111111111111',true);
select pg_temp.expect_error('select public.get_purchase_invoice_overview(''81111111-aaaa-4aaa-8aaa-111111111111'')','42501');
select pg_temp.expect_error('select public.get_purchase_invoice_detail(''81111111-aaaa-4aaa-8aaa-111111111111'',current_setting(''test.other_invoice'')::uuid)','42501');
select pg_temp.assert_true(jsonb_array_length(public.get_purchase_invoice_context('81111111-aaaa-4aaa-8aaa-111111111111')->'suppliers')=2,'writer context without read');
reset role;
insert into public.role_permissions(tenant_id,role_id,permission_key) values('81111111-aaaa-4aaa-8aaa-111111111111','81111111-3333-4333-8333-111111111111','purchasing.read');
update public.tenant_modules set enabled=false where tenant_id='81111111-aaaa-4aaa-8aaa-111111111111' and module_key='purchasing';
set local role authenticated;
select pg_temp.expect_error('select public.create_purchase_invoice_draft(''81111111-aaaa-4aaa-8aaa-111111111111'',''81111111-aaaa-4aaa-8aaa-888888888881'',''Denied'',''2026-09-25'',''TRY'',current_setting(''test.single'')::jsonb)','42501');
select pg_temp.expect_error('select public.update_purchase_invoice_draft(''81111111-aaaa-4aaa-8aaa-111111111111'',current_setting(''test.other_invoice'')::uuid,''81111111-aaaa-4aaa-8aaa-888888888881'',''Denied'',''2026-09-25'',''TRY'',current_setting(''test.single'')::jsonb)','42501');
select pg_temp.expect_error('select public.post_purchase_invoice(''81111111-aaaa-4aaa-8aaa-111111111111'',current_setting(''test.other_invoice'')::uuid)','42501');
select pg_temp.expect_error('select public.get_purchase_invoice_overview(''81111111-aaaa-4aaa-8aaa-111111111111'')','42501');
select pg_temp.expect_error('select public.get_purchase_invoice_detail(''81111111-aaaa-4aaa-8aaa-111111111111'',current_setting(''test.other_invoice'')::uuid)','42501');
select pg_temp.expect_error('select public.get_purchase_invoice_context(''81111111-aaaa-4aaa-8aaa-111111111111'')','42501');
reset role;
update public.tenant_modules set enabled=true where tenant_id='81111111-aaaa-4aaa-8aaa-111111111111' and module_key='purchasing';
update public.tenant_modules set enabled=false where tenant_id='81111111-aaaa-4aaa-8aaa-111111111111' and module_key='suppliers';
set local role authenticated;
select pg_temp.expect_error('select public.create_purchase_invoice_draft(''81111111-aaaa-4aaa-8aaa-111111111111'',''81111111-aaaa-4aaa-8aaa-888888888881'',''Denied'',''2026-09-25'',''TRY'',current_setting(''test.single'')::jsonb)','42501');
select pg_temp.expect_error('select public.update_purchase_invoice_draft(''81111111-aaaa-4aaa-8aaa-111111111111'',current_setting(''test.other_invoice'')::uuid,''81111111-aaaa-4aaa-8aaa-888888888881'',''Denied'',''2026-09-25'',''TRY'',current_setting(''test.single'')::jsonb)','42501');
select pg_temp.expect_error('select public.post_purchase_invoice(''81111111-aaaa-4aaa-8aaa-111111111111'',current_setting(''test.other_invoice'')::uuid)','42501');
select pg_temp.expect_error('select public.get_purchase_invoice_context(''81111111-aaaa-4aaa-8aaa-111111111111'')','42501');
reset role;
update public.tenant_modules set enabled=true where tenant_id='81111111-aaaa-4aaa-8aaa-111111111111' and module_key='suppliers';
set local role authenticated;
select pg_temp.expect_error('select public.update_purchase_invoice_draft(''82222222-bbbb-4bbb-8bbb-222222222222'',current_setting(''test.other_invoice'')::uuid,''81111111-aaaa-4aaa-8aaa-888888888881'',''Denied'',''2026-09-25'',''TRY'',current_setting(''test.single'')::jsonb)','42501');
select pg_temp.expect_error('select public.post_purchase_invoice(''82222222-bbbb-4bbb-8bbb-222222222222'',current_setting(''test.other_invoice'')::uuid)','42501');
select pg_temp.expect_error('select public.get_purchase_invoice_detail(''82222222-bbbb-4bbb-8bbb-222222222222'',current_setting(''test.other_invoice'')::uuid)','42501');
select set_config('request.jwt.claim.sub','',true);
select pg_temp.expect_error('select public.create_purchase_invoice_draft(''81111111-aaaa-4aaa-8aaa-111111111111'',''81111111-aaaa-4aaa-8aaa-888888888881'',''Denied'',''2026-09-25'',''TRY'',current_setting(''test.single'')::jsonb)','42501');
select pg_temp.expect_error('select public.update_purchase_invoice_draft(''81111111-aaaa-4aaa-8aaa-111111111111'',current_setting(''test.other_invoice'')::uuid,''81111111-aaaa-4aaa-8aaa-888888888881'',''Denied'',''2026-09-25'',''TRY'',current_setting(''test.single'')::jsonb)','42501');
select pg_temp.expect_error('select public.post_purchase_invoice(''81111111-aaaa-4aaa-8aaa-111111111111'',current_setting(''test.other_invoice'')::uuid)','42501');
select pg_temp.expect_error('select public.get_purchase_invoice_overview(''81111111-aaaa-4aaa-8aaa-111111111111'')','42501');
select pg_temp.expect_error('select public.get_purchase_invoice_detail(''81111111-aaaa-4aaa-8aaa-111111111111'',current_setting(''test.other_invoice'')::uuid)','42501');
select pg_temp.expect_error('select public.get_purchase_invoice_context(''81111111-aaaa-4aaa-8aaa-111111111111'')','42501');
set local role anon;
select pg_temp.expect_error('select public.create_purchase_invoice_draft(''81111111-aaaa-4aaa-8aaa-111111111111'',''81111111-aaaa-4aaa-8aaa-888888888881'',''Denied'',''2026-09-25'',''TRY'',current_setting(''test.single'')::jsonb)','42501');
select pg_temp.expect_error('select public.update_purchase_invoice_draft(''81111111-aaaa-4aaa-8aaa-111111111111'',current_setting(''test.other_invoice'')::uuid,''81111111-aaaa-4aaa-8aaa-888888888881'',''Denied'',''2026-09-25'',''TRY'',current_setting(''test.single'')::jsonb)','42501');
select pg_temp.expect_error('select public.post_purchase_invoice(''81111111-aaaa-4aaa-8aaa-111111111111'',current_setting(''test.other_invoice'')::uuid)','42501');
select pg_temp.expect_error('select public.get_purchase_invoice_overview(''81111111-aaaa-4aaa-8aaa-111111111111'')','42501');
select pg_temp.expect_error('select public.get_purchase_invoice_detail(''81111111-aaaa-4aaa-8aaa-111111111111'',current_setting(''test.other_invoice'')::uuid)','42501');
select pg_temp.expect_error('select public.get_purchase_invoice_context(''81111111-aaaa-4aaa-8aaa-111111111111'')','42501');
rollback;
do $$ begin
 if exists(select 1 from auth.users where id in ('81111111-6666-4666-8666-111111111111','81111111-7777-4777-8777-111111111111','83333333-6666-4666-8666-333333333333'))
 or exists(select 1 from public.tenants where id in ('81111111-aaaa-4aaa-8aaa-111111111111','82222222-bbbb-4bbb-8bbb-222222222222','83333333-cccc-4ccc-8ccc-333333333333')) then raise exception 'PURCHASE_ROLLBACK_RESIDUALS'; end if;
end; $$;
select 'PASS - PURCHASE INVOICE FOUNDATION' as result,
 (select count(*) from auth.users where id in ('81111111-6666-4666-8666-111111111111','81111111-7777-4777-8777-111111111111','83333333-6666-4666-8666-333333333333')) as residual_test_users,
 (select count(*) from public.tenants where id in ('81111111-aaaa-4aaa-8aaa-111111111111','82222222-bbbb-4bbb-8bbb-222222222222','83333333-cccc-4ccc-8ccc-333333333333')) as residual_test_tenants;
