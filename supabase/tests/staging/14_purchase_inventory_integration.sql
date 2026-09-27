begin;
insert into auth.users(id,aud,role,email,created_at,updated_at) values
('b1111111-6666-4666-8666-111111111111','authenticated','authenticated','purchase-stock-writer@coost.test',now(),now()),
('b1111111-7777-4777-8777-111111111111','authenticated','authenticated','purchase-stock-reader@coost.test',now(),now());
insert into public.tenants(id,name,status) values
('b1111111-aaaa-4aaa-8aaa-111111111111','Inventory A','ACTIVE'),('b2222222-bbbb-4bbb-8bbb-222222222222','Inventory B','ACTIVE');
insert into public.memberships(id,tenant_id,user_id,status) values
('b1111111-1111-4111-8111-111111111111','b1111111-aaaa-4aaa-8aaa-111111111111','b1111111-6666-4666-8666-111111111111','ACTIVE'),
('b1111111-2222-4222-8222-111111111111','b1111111-aaaa-4aaa-8aaa-111111111111','b1111111-7777-4777-8777-111111111111','ACTIVE');
insert into public.roles(id,tenant_id,key,name) values
('b1111111-3333-4333-8333-111111111111','b1111111-aaaa-4aaa-8aaa-111111111111','inventory-writer','Inventory Writer'),
('b1111111-4444-4444-8444-111111111111','b1111111-aaaa-4aaa-8aaa-111111111111','inventory-reader','Inventory Reader');
insert into public.membership_roles(tenant_id,membership_id,role_id) values
('b1111111-aaaa-4aaa-8aaa-111111111111','b1111111-1111-4111-8111-111111111111','b1111111-3333-4333-8333-111111111111'),
('b1111111-aaaa-4aaa-8aaa-111111111111','b1111111-2222-4222-8222-111111111111','b1111111-4444-4444-8444-111111111111');
insert into public.role_permissions(tenant_id,role_id,permission_key)
select 'b1111111-aaaa-4aaa-8aaa-111111111111','b1111111-3333-4333-8333-111111111111',unnest(array['inventory.read','inventory.write','inventory.adjust','inventory.count','purchasing.read','purchasing.write']);
insert into public.role_permissions(tenant_id,role_id,permission_key) values ('b1111111-aaaa-4aaa-8aaa-111111111111','b1111111-4444-4444-8444-111111111111','inventory.read');
insert into public.tenant_modules(tenant_id,module_key,enabled)
select 'b1111111-aaaa-4aaa-8aaa-111111111111',unnest(array['inventory','purchasing','suppliers']),true;
insert into public.tenant_modules(tenant_id,module_key,enabled) values('b2222222-bbbb-4bbb-8bbb-222222222222','inventory',true);
insert into public.locations(id,tenant_id,name,status) values
('b1111111-aaaa-4aaa-8aaa-999999999991','b1111111-aaaa-4aaa-8aaa-111111111111','Merkez','ACTIVE'),
('b1111111-aaaa-4aaa-8aaa-999999999992','b1111111-aaaa-4aaa-8aaa-111111111111','Şube','ACTIVE'),
('b1111111-aaaa-4aaa-8aaa-999999999993','b1111111-aaaa-4aaa-8aaa-111111111111','Pasif','PASSIVE'),
('b2222222-bbbb-4bbb-8bbb-999999999991','b2222222-bbbb-4bbb-8bbb-222222222222','Other','ACTIVE');
insert into public.inventory_items(id,tenant_id,name,base_unit) values('b2222222-bbbb-4bbb-8bbb-888888888881','b2222222-bbbb-4bbb-8bbb-222222222222','Other Item','GRAM');
insert into public.suppliers(id,tenant_id,name) values('b1111111-aaaa-4aaa-8aaa-888888888881','b1111111-aaaa-4aaa-8aaa-111111111111','Inventory Supplier');

create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERT: %',message; end if; end; $$;
create function pg_temp.expect_error(command text,state text,message text default null) returns void language plpgsql as $$
begin execute command; raise exception 'EXPECTED_ERROR_NOT_RAISED: %',command;
exception when others then if sqlstate <> state or (message is not null and sqlerrm <> message) then raise; end if; end; $$;
create function pg_temp.t() returns uuid language sql as $$ select 'b1111111-aaaa-4aaa-8aaa-111111111111'::uuid $$;
create function pg_temp.loc() returns uuid language sql as $$ select 'b1111111-aaaa-4aaa-8aaa-999999999991'::uuid $$;
create function pg_temp.item() returns uuid language sql as $$ select current_setting('test.item')::uuid $$;
create function pg_temp.cnt() returns uuid language sql as $$ select current_setting('test.count')::uuid $$;
create function pg_temp.move(kind text,q numeric,direction text default null) returns uuid language sql as $$
 select public.create_inventory_movement(pg_temp.t(),pg_temp.loc(),pg_temp.item(),kind,q,' Test movement ',direction) $$;
create function pg_temp.update_item(new_name text,new_status text) returns uuid language sql as $$
 select public.update_inventory_item(pg_temp.t(),pg_temp.item(),new_name,new_status,'SKU-1','Protein',5) $$;

create function pg_temp.line(item uuid default null,unit_id uuid default null,q numeric default 1,tracking text default 'MAPPED',label text default 'Invoice item') returns jsonb language sql as $$
  select jsonb_build_object('description',label,'unit','package','quantity',q,'unitPrice',10,'priceIncludesTax',false,'taxRate',0,
    'inventoryTracking',tracking,'inventoryItemId',item,'inventoryPurchaseUnitId',unit_id) $$;
create function pg_temp.draft(number text,lines jsonb,location uuid default pg_temp.loc()) returns uuid language sql as $$
  select public.create_purchase_invoice_draft(pg_temp.t(),'b1111111-aaaa-4aaa-8aaa-888888888881',number,'2026-09-25','TRY',lines,location) $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','b1111111-6666-4666-8666-111111111111',true);
select set_config('test.item',public.create_inventory_item(pg_temp.t(),'Meat','GRAM')::text,true);
select set_config('test.oil',public.create_inventory_item(pg_temp.t(),'Oil','MILLILITER')::text,true);
select set_config('test.egg',public.create_inventory_item(pg_temp.t(),'Egg','EACH')::text,true);
select set_config('test.passive',public.create_inventory_item(pg_temp.t(),'Passive','EACH')::text,true);
select public.update_inventory_item(pg_temp.t(),current_setting('test.passive')::uuid,'Passive','PASSIVE');
select set_config('test.kg',public.create_inventory_purchase_unit(pg_temp.t(),pg_temp.item(),' KG ',999)::text,true);
select public.update_inventory_purchase_unit(pg_temp.t(),current_setting('test.kg')::uuid,'KG',1000,'ACTIVE');
select pg_temp.expect_error($q$select public.update_inventory_purchase_unit(pg_temp.t(),current_setting('test.kg')::uuid,'KG',1000,'ACTIVE')$q$,'22023','INVENTORY_NO_CHANGES');
select set_config('test.litre',public.create_inventory_purchase_unit(pg_temp.t(),current_setting('test.oil')::uuid,'Litre',1000)::text,true);
select set_config('test.box',public.create_inventory_purchase_unit(pg_temp.t(),current_setting('test.egg')::uuid,'Koli 30',30)::text,true);
select set_config('test.tiny',public.create_inventory_purchase_unit(pg_temp.t(),pg_temp.item(),'Tiny',0.000001)::text,true);
select set_config('test.huge',public.create_inventory_purchase_unit(pg_temp.t(),pg_temp.item(),'Huge',100000)::text,true);
select pg_temp.expect_error($q$select public.create_inventory_purchase_unit(pg_temp.t(),pg_temp.item(),'kg',1)$q$,'23505','INVENTORY_PURCHASE_UNIT_DUPLICATE');
select pg_temp.expect_error($q$select public.create_inventory_purchase_unit(pg_temp.t(),pg_temp.item(),'Invalid',0)$q$,'22023');
select pg_temp.expect_error($q$select public.create_inventory_purchase_unit(pg_temp.t(),pg_temp.item(),'Invalid',-1)$q$,'22023');
select pg_temp.expect_error($q$select public.create_inventory_purchase_unit(pg_temp.t(),pg_temp.item(),'Invalid',0.0000001)$q$,'22023');
select pg_temp.expect_error($q$select public.create_inventory_purchase_unit(pg_temp.t(),pg_temp.item(),'Invalid','NaN')$q$,'22023');
select pg_temp.expect_error($q$select public.create_inventory_purchase_unit(pg_temp.t(),pg_temp.item(),'Invalid',1000000000000)$q$,'22023');
select pg_temp.expect_error($q$select public.create_inventory_purchase_unit(pg_temp.t(),current_setting('test.passive')::uuid,'Unit',1)$q$,'22023');
select pg_temp.expect_error($q$select public.create_inventory_purchase_unit(pg_temp.t(),'b2222222-bbbb-4bbb-8bbb-888888888881','Other',1)$q$,'22023');
select pg_temp.assert_true(jsonb_array_length(public.get_inventory_purchase_units(pg_temp.t(),pg_temp.item())->'units') = 3,'unit read model');
select pg_temp.expect_error($q$select pg_temp.draft('BAD-MISSING',jsonb_build_array(pg_temp.line()))$q$,'22023','PURCHASE_INVENTORY_MAPPING_INVALID');
select pg_temp.expect_error($q$select pg_temp.draft('BAD-ITEM',jsonb_build_array(pg_temp.line(current_setting('test.oil')::uuid,current_setting('test.kg')::uuid)))$q$,'22023','INVENTORY_PURCHASE_UNIT_NOT_AVAILABLE');
select pg_temp.expect_error($q$select pg_temp.draft('BAD-NON',jsonb_build_array(pg_temp.line(pg_temp.item(),current_setting('test.kg')::uuid,1,'NON_STOCK')))$q$,'22023');
select pg_temp.expect_error($q$select pg_temp.draft('BAD-UNMAPPED',jsonb_build_array(pg_temp.line(pg_temp.item(),null,1,'UNMAPPED')))$q$,'22023');
select pg_temp.expect_error($q$select pg_temp.draft('BAD-TENANT',jsonb_build_array(pg_temp.line('b2222222-bbbb-4bbb-8bbb-888888888881',current_setting('test.kg')::uuid)))$q$,'22023');
select public.update_inventory_purchase_unit(pg_temp.t(),current_setting('test.kg')::uuid,'KG',1000,'PASSIVE');
select pg_temp.expect_error($q$select pg_temp.draft('BAD-PASSIVE',jsonb_build_array(pg_temp.line(pg_temp.item(),current_setting('test.kg')::uuid)))$q$,'22023');
select pg_temp.assert_true(not exists(select 1 from jsonb_array_elements(public.get_purchase_invoice_context(pg_temp.t())->'purchaseUnits') u where u->>'id' = current_setting('test.kg')),'passive unit omitted');
select public.update_inventory_purchase_unit(pg_temp.t(),current_setting('test.kg')::uuid,'KG',1000,'ACTIVE');
-- Legacy JSON is still accepted for drafts, but omission is deliberately UNMAPPED.
select set_config('test.unmapped',pg_temp.draft('UNMAPPED','[{"description":"Legacy input","unit":"kg","quantity":1,"unitPrice":10,"priceIncludesTax":false,"taxRate":0}]')::text,true);
select pg_temp.expect_error($q$select public.post_purchase_invoice(pg_temp.t(),current_setting('test.unmapped')::uuid)$q$,'22023','PURCHASE_INVOICE_LINES_UNMAPPED');
select set_config('test.no_location',pg_temp.draft('NO-LOCATION',jsonb_build_array(pg_temp.line(pg_temp.item(),current_setting('test.kg')::uuid)),null)::text,true);
select pg_temp.expect_error($q$select public.post_purchase_invoice(pg_temp.t(),current_setting('test.no_location')::uuid)$q$,'22023','PURCHASE_INVOICE_LOCATION_REQUIRED_FOR_INVENTORY');
select set_config('test.precision',pg_temp.draft('PRECISION',jsonb_build_array(pg_temp.line(pg_temp.item(),current_setting('test.tiny')::uuid)))::text,true);
select pg_temp.expect_error($q$select public.post_purchase_invoice(pg_temp.t(),current_setting('test.precision')::uuid)$q$,'22023','PURCHASE_INVENTORY_QUANTITY_PRECISION');
select set_config('test.overflow',pg_temp.draft('OVERFLOW',jsonb_build_array(pg_temp.line(pg_temp.item(),current_setting('test.huge')::uuid,100000000)))::text,true);
select pg_temp.expect_error($q$select public.post_purchase_invoice(pg_temp.t(),current_setting('test.overflow')::uuid)$q$,'22003','PURCHASE_INVENTORY_QUANTITY_OVERFLOW');
select pg_temp.assert_true(not exists(select 1 from public.supplier_ledger_entries where tenant_id = pg_temp.t()),'rejected post leaves no supplier debt');
select set_config('test.mixed',jsonb_build_array(pg_temp.line(pg_temp.item(),current_setting('test.kg')::uuid,2.5,'MAPPED','Meat first'),
  pg_temp.line(pg_temp.item(),current_setting('test.kg')::uuid,1,'MAPPED','Meat repeat'),pg_temp.line(current_setting('test.oil')::uuid,current_setting('test.litre')::uuid,1.25),
  pg_temp.line(current_setting('test.egg')::uuid,current_setting('test.box')::uuid,2),pg_temp.line(null,null,1,'NON_STOCK','Service'))::text,true);
select set_config('test.invoice',pg_temp.draft('MIXED',current_setting('test.mixed')::jsonb)::text,true);
-- No inventory permissions needed for trusted purchasing POST or context.
reset role;
delete from public.role_permissions where role_id = 'b1111111-3333-4333-8333-111111111111' and permission_key like 'inventory.%';
set local role authenticated;
select pg_temp.assert_true(jsonb_array_length(public.get_purchase_invoice_context(pg_temp.t())->'inventoryItems') = 3,'purchasing-only context');
select public.post_purchase_invoice(pg_temp.t(),current_setting('test.invoice')::uuid);
select pg_temp.expect_error($q$select public.post_purchase_invoice(pg_temp.t(),current_setting('test.invoice')::uuid)$q$,'55000');
select pg_temp.expect_error($q$select public.update_purchase_invoice_draft(pg_temp.t(),current_setting('test.invoice')::uuid,'b1111111-aaaa-4aaa-8aaa-888888888881','MIXED','2026-09-25','TRY',current_setting('test.mixed')::jsonb,pg_temp.loc())$q$,'55000');
reset role;
select pg_temp.assert_true((select count(*) = 4 from public.inventory_movements where source_id = current_setting('test.invoice')::uuid),'four receipts incl repeated same item');
select pg_temp.assert_true((select sum(quantity) = 3500 from public.inventory_movements where source_id = current_setting('test.invoice')::uuid and inventory_item_id = pg_temp.item()),'kg to gram');
select pg_temp.assert_true((select quantity = 1250 from public.inventory_movements where source_id = current_setting('test.invoice')::uuid and inventory_item_id = current_setting('test.oil')::uuid),'litre conversion');
select pg_temp.assert_true((select quantity = 60 from public.inventory_movements where source_id = current_setting('test.invoice')::uuid and inventory_item_id = current_setting('test.egg')::uuid),'box conversion');
select pg_temp.assert_true((select bool_and(m.source_type = 'PURCHASE_INVOICE' and m.movement_type = 'RECEIPT' and m.location_id = pg_temp.loc() and m.quantity > 0 and m.inventory_item_id = l.inventory_item_id and m.source_id = l.purchase_invoice_id and m.description = 'Fatura: MIXED · '||l.description) from public.inventory_movements m join public.purchase_invoice_lines l on l.id = m.source_line_id where m.tenant_id = pg_temp.t()),'source invoice + line and description');
select pg_temp.assert_true((select count(*) = 1 and sum(amount) = 77.5 from public.supplier_ledger_entries where tenant_id = pg_temp.t()),'supplier debt preserved');
select pg_temp.assert_true(not exists(select 1 from public.finance_transactions where tenant_id = pg_temp.t()) and not exists(select 1 from public.finance_entries where tenant_id = pg_temp.t()),'no finance movement');
select pg_temp.assert_true((select (metadata->>'inventoryReceiptCount')::int = 4 and jsonb_array_length(metadata->'inventoryReceipts') = 4 and not (metadata ? 'inventoryBaseQuantityTotal')
  from public.audit_logs where entity_id = current_setting('test.invoice')::uuid and action = 'PURCHASE_INVOICE_POSTED'),'per-line audit no mixed totals');
select pg_temp.assert_true(exists(select 1 from public.audit_logs a,lateral jsonb_array_elements(a.metadata->'inventoryReceipts') r where a.entity_id = current_setting('test.invoice')::uuid and r @> jsonb_build_object('itemId',pg_temp.item(),'purchaseQuantity',2.5,'conversionToBase',1000,'baseQuantity',2500,'baseUnit','GRAM') and r->>'lineId' is not null),'conversion snapshot audit');
select pg_temp.assert_true((select count(*) = 5 from public.audit_logs where tenant_id = pg_temp.t() and action = 'INVENTORY_PURCHASE_UNIT_CREATED'),'create unit audit');
select pg_temp.assert_true((select count(*) = 3 from public.audit_logs where tenant_id = pg_temp.t() and action = 'INVENTORY_PURCHASE_UNIT_UPDATED'),'update unit audit / no-change');
select pg_temp.expect_error($q$delete from public.inventory_purchase_units where id = current_setting('test.kg')::uuid$q$,'55000');
select pg_temp.expect_error($q$update public.purchase_invoice_lines set inventory_tracking = 'NON_STOCK',inventory_item_id = null,inventory_purchase_unit_id = null where purchase_invoice_id = current_setting('test.invoice')::uuid$q$,'55000');
select pg_temp.expect_error($q$insert into public.inventory_movements(tenant_id,location_id,inventory_item_id,movement_type,quantity,description,source_type,source_id,source_line_id,created_by_user_id)
  select tenant_id,location_id,inventory_item_id,movement_type,quantity,description,source_type,source_id,source_line_id,created_by_user_id from public.inventory_movements where tenant_id = pg_temp.t() limit 1$q$,'23505');
-- A privileged historical fixture uses UNMAPPED just like rows that predate integration.
set local role authenticated;
select set_config('test.old',pg_temp.draft('OLD-POSTED',jsonb_build_array(pg_temp.line(null,null,1,'UNMAPPED')))::text,true);
reset role;
update public.purchase_invoices set status = 'POSTED',posted_at = now(),posted_by_user_id = 'b1111111-6666-4666-8666-111111111111' where id = current_setting('test.old')::uuid;
select set_config('test.old_snapshot',(select to_jsonb(i)::text from public.purchase_invoices i where id = current_setting('test.old')::uuid),true);
-- A second receipt fails after the first succeeds: the entire command must roll back.
create function pg_temp.fail_receipt() returns trigger language plpgsql as $$ begin if new.source_type = 'PURCHASE_INVOICE' and new.description like '%Meat repeat' then raise exception 'TEST_RECEIPT_FAILURE'; end if; return new; end; $$;
create trigger test_receipt_failure before insert on public.inventory_movements for each row execute function pg_temp.fail_receipt();
set local role authenticated;
select set_config('test.fail',pg_temp.draft('FAIL',current_setting('test.mixed')::jsonb)::text,true);
select pg_temp.expect_error($q$select public.post_purchase_invoice(pg_temp.t(),current_setting('test.fail')::uuid)$q$,'P0001','TEST_RECEIPT_FAILURE');
select pg_temp.assert_true((select status = 'DRAFT' and posted_at is null from public.purchase_invoices where id = current_setting('test.fail')::uuid),'rollback invoice');
reset role;
select pg_temp.assert_true(not exists(select 1 from public.inventory_movements where source_id = current_setting('test.fail')::uuid) and not exists(select 1 from public.supplier_ledger_entries where source_id = current_setting('test.fail')::uuid),'rollback both ledgers');
select pg_temp.assert_true(not exists(select 1 from public.audit_logs where entity_id = current_setting('test.fail')::uuid and action = 'PURCHASE_INVOICE_POSTED'),'rollback post audit');
drop trigger test_receipt_failure on public.inventory_movements;
-- Revalidate active unit/item at POST, not only when the draft was saved.
update public.inventory_purchase_units set status = 'PASSIVE' where id = current_setting('test.kg')::uuid;
set local role authenticated;
select pg_temp.expect_error($q$select public.post_purchase_invoice(pg_temp.t(),current_setting('test.fail')::uuid)$q$,'22023','INVENTORY_PURCHASE_UNIT_NOT_AVAILABLE');
reset role;
update public.inventory_purchase_units set status = 'ACTIVE' where id = current_setting('test.kg')::uuid;
-- Invoice item with zero stock can be made passive after draft entry.
update public.inventory_items set status = 'ACTIVE' where id = current_setting('test.passive')::uuid;
insert into public.inventory_purchase_units(id,tenant_id,inventory_item_id,name,conversion_to_base) values('b1111111-aaaa-4aaa-8aaa-777777777779',pg_temp.t(),current_setting('test.passive')::uuid,'Each',1);
set local role authenticated;
select set_config('test.passive_invoice',pg_temp.draft('PASSIVE-AT-POST',jsonb_build_array(pg_temp.line(current_setting('test.passive')::uuid,'b1111111-aaaa-4aaa-8aaa-777777777779')))::text,true);
reset role;
update public.inventory_items set status = 'PASSIVE' where id = current_setting('test.passive')::uuid;
set local role authenticated;
select pg_temp.expect_error($q$select public.post_purchase_invoice(pg_temp.t(),current_setting('test.passive_invoice')::uuid)$q$,'22023','INVENTORY_ITEM_NOT_AVAILABLE');
select pg_temp.expect_error($q$select pg_temp.draft('PASSIVE-DRAFT',jsonb_build_array(pg_temp.line(current_setting('test.passive')::uuid,'b1111111-aaaa-4aaa-8aaa-777777777779')))$q$,'22023','INVENTORY_ITEM_NOT_AVAILABLE');
select set_config('test.exact',pg_temp.draft('EXACT',jsonb_build_array(pg_temp.line(pg_temp.item(),current_setting('test.tiny')::uuid,100)))::text,true);
select public.post_purchase_invoice(pg_temp.t(),current_setting('test.exact')::uuid);
reset role;
select pg_temp.assert_true((select quantity = 0.0001 from public.inventory_movements where source_id = current_setting('test.exact')::uuid),'exact four-decimal base quantity');
select pg_temp.expect_error($q$update public.purchase_invoice_lines set inventory_tracking = 'MAPPED',inventory_item_id = current_setting('test.oil')::uuid,inventory_purchase_unit_id = current_setting('test.kg')::uuid where purchase_invoice_id = current_setting('test.unmapped')::uuid$q$,'23503');
select pg_temp.expect_error($q$update public.purchase_invoice_lines set inventory_tracking = 'NON_STOCK',inventory_item_id = pg_temp.item() where purchase_invoice_id = current_setting('test.unmapped')::uuid$q$,'23514');
-- Inventory disabled: no selectors and no mapped writes, but explicit non-stock invoices still post.
update public.tenant_modules set enabled = false where tenant_id = pg_temp.t() and module_key = 'inventory';
set local role authenticated;
select pg_temp.assert_true(public.get_purchase_invoice_context(pg_temp.t())->'inventoryItems' = '[]'::jsonb and public.get_purchase_invoice_context(pg_temp.t())->'purchaseUnits' = '[]'::jsonb,'disabled context');
select pg_temp.expect_error($q$select pg_temp.draft('DISABLED',current_setting('test.mixed')::jsonb)$q$,'42501','INVENTORY_MODULE_NOT_AVAILABLE');
select pg_temp.expect_error($q$select public.post_purchase_invoice(pg_temp.t(),current_setting('test.fail')::uuid)$q$,'42501','INVENTORY_MODULE_NOT_AVAILABLE');
select set_config('test.nonstock',pg_temp.draft('NON-STOCK',jsonb_build_array(pg_temp.line(null,null,1,'NON_STOCK')),null)::text,true);
select public.post_purchase_invoice(pg_temp.t(),current_setting('test.nonstock')::uuid);
reset role;
select pg_temp.assert_true(not exists(select 1 from public.inventory_movements where source_id = current_setting('test.nonstock')::uuid),'non-stock no receipt');
update public.tenant_modules set enabled = true where tenant_id = pg_temp.t() and module_key = 'inventory';
select pg_temp.assert_true((select to_jsonb(i) = current_setting('test.old_snapshot')::jsonb from public.purchase_invoices i where id = current_setting('test.old')::uuid)
  and not exists(select 1 from public.inventory_movements where source_id = current_setting('test.old')::uuid),'old posted remains unchanged');
select pg_temp.assert_true(not exists(select 1 from public.inventory_movements m join public.purchase_invoices i on i.id = m.source_id where m.source_type = 'PURCHASE_INVOICE' and i.invoice_number = 'STG-PI-001'),'no historical backfill');
-- Unit command permissions / RLS and source visibility.
set local role authenticated;
select pg_temp.expect_error($q$select public.create_inventory_purchase_unit(pg_temp.t(),pg_temp.item(),'Denied',1)$q$,'42501');
select pg_temp.expect_error($q$select public.update_inventory_purchase_unit(pg_temp.t(),current_setting('test.kg')::uuid,'Denied',1,'ACTIVE')$q$,'42501');
select set_config('request.jwt.claim.sub','b1111111-7777-4777-8777-111111111111',true);
select pg_temp.assert_true(exists(select 1 from jsonb_array_elements(public.get_inventory_overview(pg_temp.t())->'recentMovements') m where m->>'sourceType' = 'PURCHASE_INVOICE'),'receipt source in read model');
select pg_temp.expect_error($q$select pg_temp.draft('READER',current_setting('test.mixed')::jsonb)$q$,'42501');
select pg_temp.expect_error($q$select public.post_purchase_invoice(pg_temp.t(),current_setting('test.fail')::uuid)$q$,'42501');
select pg_temp.expect_error($q$insert into public.inventory_purchase_units(tenant_id,inventory_item_id,name,conversion_to_base) values(pg_temp.t(),pg_temp.item(),'Direct',1)$q$,'42501');
select pg_temp.expect_error($q$update public.purchase_invoice_lines set inventory_tracking = 'NON_STOCK' where purchase_invoice_id = current_setting('test.unmapped')::uuid$q$,'42501');
reset role;
insert into public.role_permissions(tenant_id,role_id,permission_key) values(pg_temp.t(),'b1111111-3333-4333-8333-111111111111','inventory.write');
update public.tenant_modules set enabled = false where tenant_id = pg_temp.t() and module_key = 'inventory';
set local role authenticated;
select set_config('request.jwt.claim.sub','b1111111-6666-4666-8666-111111111111',true);
select pg_temp.expect_error($q$select public.create_inventory_purchase_unit(pg_temp.t(),pg_temp.item(),'Disabled',1)$q$,'42501');
reset role;
update public.tenant_modules set enabled = true where tenant_id = pg_temp.t() and module_key = 'inventory';
insert into public.inventory_purchase_units(id,tenant_id,inventory_item_id,name,conversion_to_base) values('b2222222-bbbb-4bbb-8bbb-777777777771','b2222222-bbbb-4bbb-8bbb-222222222222','b2222222-bbbb-4bbb-8bbb-888888888881','Other unit',1);
set local role authenticated;
select pg_temp.expect_error($q$select public.update_inventory_purchase_unit(pg_temp.t(),'b2222222-bbbb-4bbb-8bbb-777777777771','Other',1,'ACTIVE')$q$,'22023');
select pg_temp.expect_error($q$select pg_temp.draft('CROSS-UNIT',jsonb_build_array(pg_temp.line(pg_temp.item(),'b2222222-bbbb-4bbb-8bbb-777777777771')))$q$,'22023');
select pg_temp.expect_error($q$select public.get_inventory_purchase_units(pg_temp.t(),'b2222222-bbbb-4bbb-8bbb-888888888881')$q$,'22023');
select set_config('request.jwt.claim.sub','',true);
select pg_temp.expect_error($q$select public.create_inventory_purchase_unit(pg_temp.t(),pg_temp.item(),'NoAuth',1)$q$,'42501');
set local role anon;
select pg_temp.expect_error($q$select public.create_inventory_purchase_unit(pg_temp.t(),pg_temp.item(),'Anon',1)$q$,'42501');
select pg_temp.expect_error($q$select public.get_inventory_purchase_units(pg_temp.t(),pg_temp.item())$q$,'42501');
reset role;
select pg_temp.assert_true(not has_table_privilege('authenticated','public.inventory_purchase_units','INSERT,UPDATE,DELETE,TRUNCATE') and not has_table_privilege('anon','public.inventory_purchase_units','SELECT,INSERT,UPDATE,DELETE,TRUNCATE'),'unit direct access');
select pg_temp.assert_true((select relrowsecurity from pg_class where oid = 'public.inventory_purchase_units'::regclass),'unit RLS');
do $$ declare f record; begin
  for f in select * from pg_proc where oid in ('public.create_inventory_purchase_unit(uuid,uuid,text,numeric)'::regprocedure,'public.update_inventory_purchase_unit(uuid,uuid,text,numeric,text)'::regprocedure,'public.get_inventory_purchase_units(uuid,uuid)'::regprocedure) loop
    perform pg_temp.assert_true(f.prosecdef and 'search_path=""' = any(f.proconfig),'function security');
    perform pg_temp.assert_true(not has_function_privilege('anon',f.oid,'EXECUTE') and has_function_privilege('authenticated',f.oid,'EXECUTE') and has_function_privilege('service_role',f.oid,'EXECUTE'),'function grants');
    perform pg_temp.assert_true(not exists(select 1 from aclexplode(f.proacl) where grantee = 0 and privilege_type = 'EXECUTE'),'PUBLIC revoked');
  end loop;
end $$;
rollback;
do $$ begin
  if exists(select 1 from auth.users where email like 'purchase-stock-%@coost.test') or exists(select 1 from public.tenants where id in ('b1111111-aaaa-4aaa-8aaa-111111111111','b2222222-bbbb-4bbb-8bbb-222222222222')) then raise exception 'RESIDUAL_FIXTURES'; end if;
end $$;
select 'PASS - PURCHASE INVENTORY INTEGRATION' result,(select count(*) from auth.users where email like 'purchase-stock-%@coost.test') residual_test_users,
  (select count(*) from public.tenants where id in ('b1111111-aaaa-4aaa-8aaa-111111111111','b2222222-bbbb-4bbb-8bbb-222222222222')) residual_test_tenants;
