begin;
insert into auth.users(id,aud,role,email,created_at,updated_at) values
('91111111-6666-4666-8666-111111111111','authenticated','authenticated','inventory-writer@coost.test',now(),now()),
('91111111-7777-4777-8777-111111111111','authenticated','authenticated','inventory-reader@coost.test',now(),now());
insert into public.tenants(id,name,status) values
('91111111-aaaa-4aaa-8aaa-111111111111','Inventory A','ACTIVE'),('92222222-bbbb-4bbb-8bbb-222222222222','Inventory B','ACTIVE');
insert into public.memberships(id,tenant_id,user_id,status) values
('91111111-1111-4111-8111-111111111111','91111111-aaaa-4aaa-8aaa-111111111111','91111111-6666-4666-8666-111111111111','ACTIVE'),
('91111111-2222-4222-8222-111111111111','91111111-aaaa-4aaa-8aaa-111111111111','91111111-7777-4777-8777-111111111111','ACTIVE');
insert into public.roles(id,tenant_id,key,name) values
('91111111-3333-4333-8333-111111111111','91111111-aaaa-4aaa-8aaa-111111111111','inventory-writer','Inventory Writer'),
('91111111-4444-4444-8444-111111111111','91111111-aaaa-4aaa-8aaa-111111111111','inventory-reader','Inventory Reader');
insert into public.membership_roles(tenant_id,membership_id,role_id) values
('91111111-aaaa-4aaa-8aaa-111111111111','91111111-1111-4111-8111-111111111111','91111111-3333-4333-8333-111111111111'),
('91111111-aaaa-4aaa-8aaa-111111111111','91111111-2222-4222-8222-111111111111','91111111-4444-4444-8444-111111111111');
insert into public.role_permissions(tenant_id,role_id,permission_key)
select '91111111-aaaa-4aaa-8aaa-111111111111','91111111-3333-4333-8333-111111111111',unnest(array['inventory.read','inventory.write','inventory.adjust','inventory.count','purchasing.read','purchasing.write']);
insert into public.role_permissions(tenant_id,role_id,permission_key) values ('91111111-aaaa-4aaa-8aaa-111111111111','91111111-4444-4444-8444-111111111111','inventory.read');
insert into public.tenant_modules(tenant_id,module_key,enabled)
select '91111111-aaaa-4aaa-8aaa-111111111111',unnest(array['inventory','purchasing','suppliers']),true;
insert into public.tenant_modules(tenant_id,module_key,enabled) values('92222222-bbbb-4bbb-8bbb-222222222222','inventory',true);
insert into public.locations(id,tenant_id,name,status) values
('91111111-aaaa-4aaa-8aaa-999999999991','91111111-aaaa-4aaa-8aaa-111111111111','Merkez','ACTIVE'),
('91111111-aaaa-4aaa-8aaa-999999999992','91111111-aaaa-4aaa-8aaa-111111111111','Şube','ACTIVE'),
('91111111-aaaa-4aaa-8aaa-999999999993','91111111-aaaa-4aaa-8aaa-111111111111','Pasif','PASSIVE'),
('92222222-bbbb-4bbb-8bbb-999999999991','92222222-bbbb-4bbb-8bbb-222222222222','Other','ACTIVE');
insert into public.inventory_items(id,tenant_id,name,base_unit) values('92222222-bbbb-4bbb-8bbb-888888888881','92222222-bbbb-4bbb-8bbb-222222222222','Other Item','GRAM');
insert into public.suppliers(id,tenant_id,name) values('91111111-aaaa-4aaa-8aaa-888888888881','91111111-aaaa-4aaa-8aaa-111111111111','Inventory Supplier');

create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERT: %',message; end if; end; $$;
create function pg_temp.expect_error(command text,state text,message text default null) returns void language plpgsql as $$
begin execute command; raise exception 'EXPECTED_ERROR_NOT_RAISED: %',command;
exception when others then if sqlstate <> state or (message is not null and sqlerrm <> message) then raise; end if; end; $$;
create function pg_temp.t() returns uuid language sql as $$ select '91111111-aaaa-4aaa-8aaa-111111111111'::uuid $$;
create function pg_temp.loc() returns uuid language sql as $$ select '91111111-aaaa-4aaa-8aaa-999999999991'::uuid $$;
create function pg_temp.item() returns uuid language sql as $$ select current_setting('test.item')::uuid $$;
create function pg_temp.cnt() returns uuid language sql as $$ select current_setting('test.count')::uuid $$;
create function pg_temp.move(kind text,q numeric,direction text default null) returns uuid language sql as $$
 select public.create_inventory_movement(pg_temp.t(),pg_temp.loc(),pg_temp.item(),kind,q,' Test movement ',direction) $$;
create function pg_temp.update_item(new_name text,new_status text) returns uuid language sql as $$
 select public.update_inventory_item(pg_temp.t(),pg_temp.item(),new_name,new_status,'SKU-1','Protein',5) $$;

set local role authenticated;
select set_config('request.jwt.claim.sub','91111111-6666-4666-8666-111111111111',true);
select set_config('test.item',public.create_inventory_item(pg_temp.t(),'  Test Meat  ','GRAM',' SKU-1 ',' Protein ',5)::text,true);
select pg_temp.assert_true((select name = 'Test Meat' and sku = 'SKU-1' and critical_stock = 5 from public.inventory_items where id = pg_temp.item()),'create normalization');
select pg_temp.expect_error($q$select public.create_inventory_item(pg_temp.t(),'test   meat','EACH')$q$,'23505','INVENTORY_ITEM_DUPLICATE');
select pg_temp.expect_error($q$select public.create_inventory_item(pg_temp.t(),'Other','EACH','sku-1')$q$,'23505','INVENTORY_ITEM_DUPLICATE');
select pg_temp.expect_error($q$select public.create_inventory_item(pg_temp.t(),'Other','KG')$q$,'22023');
select pg_temp.expect_error($q$select public.create_inventory_item(pg_temp.t(),'Other','EACH',null,null,-1)$q$,'22023');
select pg_temp.expect_error($q$select public.create_inventory_item(pg_temp.t(),'Other','EACH',null,null,0.00001)$q$,'22023');
select pg_temp.expect_error($q$select public.create_inventory_item(pg_temp.t(),'Other','EACH',null,null,'NaN')$q$,'22023');
select pg_temp.update_item('Renamed Meat','PASSIVE');
select pg_temp.expect_error($q$select pg_temp.move('RECEIPT',1)$q$,'22023','INVENTORY_ITEM_NOT_AVAILABLE');
select pg_temp.update_item('Renamed Meat','ACTIVE');
select pg_temp.expect_error($q$select pg_temp.update_item('Renamed Meat','ACTIVE')$q$,'22023','INVENTORY_NO_CHANGES');
select set_config('test.zero',public.create_inventory_item(pg_temp.t(),'Zero Item','MILLILITER',null,null,0)::text,true);
select set_config('test.passive',public.create_inventory_item(pg_temp.t(),'Passive Item','EACH')::text,true);
select public.update_inventory_item(pg_temp.t(),current_setting('test.passive')::uuid,'Passive Item','PASSIVE');
select pg_temp.move('RECEIPT',10.1234);
select pg_temp.move('ISSUE',2);
select pg_temp.move('WASTE',1);
select pg_temp.move('COMPLIMENTARY',1);
select pg_temp.move('MANUAL_ADJUSTMENT',2,'INCREASE');
select pg_temp.move('MANUAL_ADJUSTMENT',10,'DECREASE');
select pg_temp.assert_true((select sum(quantity) = -1.8766 from public.inventory_movements where inventory_item_id = pg_temp.item()),'signed quantities / negative stock');
select pg_temp.assert_true((select bool_and(case when movement_type in ('ISSUE','WASTE','COMPLIMENTARY') then quantity < 0 when movement_type = 'RECEIPT' then quantity > 0 else true end) from public.inventory_movements where tenant_id = pg_temp.t()),'type signs');
select pg_temp.expect_error($q$select pg_temp.update_item('Renamed Meat','PASSIVE')$q$,'22023','INVENTORY_NONZERO_STOCK');
select pg_temp.expect_error($q$select pg_temp.move('COUNT_ADJUSTMENT',1)$q$,'22023');
select pg_temp.expect_error($q$select pg_temp.move('INVALID',1)$q$,'22023');
select pg_temp.expect_error($q$select pg_temp.move('RECEIPT',0)$q$,'22023');
select pg_temp.expect_error($q$select pg_temp.move('RECEIPT',-1)$q$,'22023');
select pg_temp.expect_error($q$select pg_temp.move('RECEIPT',0.00001)$q$,'22023');
select pg_temp.expect_error($q$select pg_temp.move('RECEIPT',1.00001)$q$,'22023');
select pg_temp.expect_error($q$select pg_temp.move('RECEIPT','NaN')$q$,'22023');
select pg_temp.expect_error($q$select pg_temp.move('RECEIPT',1,'DECREASE')$q$,'22023');
select pg_temp.expect_error($q$select pg_temp.move('MANUAL_ADJUSTMENT',1)$q$,'22023');
select pg_temp.expect_error($q$select public.create_inventory_movement(pg_temp.t(),pg_temp.loc(),pg_temp.item(),'RECEIPT',1,' ')$q$,'22023');
select pg_temp.expect_error($q$select public.create_inventory_movement(pg_temp.t(),pg_temp.loc(),'92222222-bbbb-4bbb-8bbb-888888888881','RECEIPT',1,'Denied')$q$,'22023');
select pg_temp.expect_error($q$select public.create_inventory_movement(pg_temp.t(),'92222222-bbbb-4bbb-8bbb-999999999991',pg_temp.item(),'RECEIPT',1,'Denied')$q$,'22023');
select pg_temp.expect_error($q$select public.create_inventory_movement(pg_temp.t(),'91111111-aaaa-4aaa-8aaa-999999999993',pg_temp.item(),'RECEIPT',1,'Denied')$q$,'22023');
select pg_temp.assert_true((public.get_inventory_overview(pg_temp.t(),pg_temp.loc())->'summary') = '{"activeItemCount":2,"criticalItemCount":2,"negativeItemCount":1}'::jsonb,'critical and negative summary');
select pg_temp.assert_true(jsonb_array_length(public.get_inventory_management(pg_temp.t())->'items') = 3,'active and passive management');
select pg_temp.assert_true(jsonb_array_length(public.get_inventory_context(pg_temp.t())->'items') = 2,'active context');
select public.create_inventory_movement(pg_temp.t(),'91111111-aaaa-4aaa-8aaa-999999999992',pg_temp.item(),'RECEIPT',1.8766,'Offset location');
select pg_temp.assert_true((select (v->>'quantity')::numeric = 0 from jsonb_array_elements(public.get_inventory_overview(pg_temp.t())->'items') v where v->>'id' = pg_temp.item()::text),'tenant total derived');
select pg_temp.expect_error($q$select pg_temp.update_item('Renamed Meat','PASSIVE')$q$,'22023','INVENTORY_NONZERO_STOCK');

-- Count snapshot, inputs and stale balance: counted 5, snapshot -1.8766, current 0.1234 => adjustment 4.8766.
select set_config('test.count',public.create_inventory_count(pg_temp.t(),pg_temp.loc(),' Main count ')::text,true);
select pg_temp.assert_true((select system_quantity = -1.8766 and counted_quantity is null from public.inventory_count_lines where count_id = pg_temp.cnt() and inventory_item_id = pg_temp.item()),'snapshot');
select pg_temp.expect_error($q$select public.post_inventory_count(pg_temp.t(),pg_temp.cnt())$q$,'22023','INVENTORY_COUNT_INCOMPLETE');
select public.update_inventory_count(pg_temp.t(),pg_temp.cnt(),jsonb_build_array(jsonb_build_object('itemId',pg_temp.item(),'countedQuantity',5),jsonb_build_object('itemId',current_setting('test.zero'),'countedQuantity',0)));
select pg_temp.assert_true((select difference = 6.8766 from public.inventory_count_lines where count_id = pg_temp.cnt() and inventory_item_id = pg_temp.item()),'draft difference');
select pg_temp.expect_error($q$select public.update_inventory_count(pg_temp.t(),pg_temp.cnt(),'[]')$q$,'22023');
select pg_temp.expect_error($q$select public.update_inventory_count(pg_temp.t(),pg_temp.cnt(),jsonb_build_array(jsonb_build_object('itemId',pg_temp.item(),'countedQuantity',6),jsonb_build_object('itemId',current_setting('test.zero'),'countedQuantity',-1)))$q$,'22023');
select pg_temp.assert_true((select counted_quantity = 5 from public.inventory_count_lines where count_id = pg_temp.cnt() and inventory_item_id = pg_temp.item()),'failed update atomic');
select pg_temp.move('RECEIPT',2);
select public.post_inventory_count(pg_temp.t(),pg_temp.cnt());
select pg_temp.assert_true((select count(*) = 1 and sum(quantity) = 4.8766 from public.inventory_movements where source_id = pg_temp.cnt() and movement_type = 'COUNT_ADJUSTMENT'),'one nonzero count movement');
select pg_temp.assert_true((select sum(quantity) = 5 from public.inventory_movements where inventory_item_id = pg_temp.item() and location_id = pg_temp.loc()),'count reconciled current balance');
select pg_temp.assert_true((select system_quantity = 0.1234 and difference = 4.8766 from public.inventory_count_lines where count_id = pg_temp.cnt() and inventory_item_id = pg_temp.item()),'posted effective quantities');
select pg_temp.expect_error($q$select public.post_inventory_count(pg_temp.t(),pg_temp.cnt())$q$,'55000');
select pg_temp.expect_error($q$select public.update_inventory_count(pg_temp.t(),pg_temp.cnt(),'[]')$q$,'55000');
select pg_temp.assert_true(public.get_inventory_count_detail(pg_temp.t(),pg_temp.cnt())->>'status' = 'POSTED','posted read');
select pg_temp.assert_true(jsonb_array_length(public.get_inventory_counts(pg_temp.t())->'counts') = 1,'count list');
select set_config('test.draft',public.create_inventory_count(pg_temp.t(),pg_temp.loc())::text,true);
select public.update_inventory_count(pg_temp.t(),current_setting('test.draft')::uuid,jsonb_build_array(jsonb_build_object('itemId',pg_temp.item(),'countedQuantity',5),jsonb_build_object('itemId',current_setting('test.zero'),'countedQuantity',2)));

reset role;
-- DB protections apply even to privileged direct writes.
select pg_temp.expect_error($q$update public.inventory_items set base_unit = 'EACH' where id = pg_temp.item()$q$,'55000');
select pg_temp.expect_error($q$delete from public.inventory_items where id = pg_temp.item()$q$,'55000');
select pg_temp.expect_error($q$update public.inventory_movements set quantity = 100 where inventory_item_id = pg_temp.item()$q$,'55000');
select pg_temp.expect_error($q$delete from public.inventory_movements where inventory_item_id = pg_temp.item()$q$,'55000');
select pg_temp.expect_error($q$update public.inventory_counts set notes = 'Changed' where id = pg_temp.cnt()$q$,'55000');
select pg_temp.expect_error($q$delete from public.inventory_counts where id = pg_temp.cnt()$q$,'55000');
select pg_temp.expect_error($q$update public.inventory_count_lines set counted_quantity = 5 where count_id = pg_temp.cnt()$q$,'55000');
select pg_temp.expect_error($q$delete from public.inventory_count_lines where count_id = pg_temp.cnt()$q$,'55000');
select pg_temp.assert_true((select count(*) = 3 from public.audit_logs where tenant_id = pg_temp.t() and action = 'INVENTORY_ITEM_CREATED'),'item audits');
select pg_temp.assert_true((select count(*) = 3 from public.audit_logs where tenant_id = pg_temp.t() and action = 'INVENTORY_ITEM_UPDATED'),'updates and no-change audit');
select pg_temp.assert_true((select count(*) = 8 from public.audit_logs where tenant_id = pg_temp.t() and action = 'INVENTORY_MOVEMENT_CREATED'),'successful movement audits only');
select pg_temp.assert_true(exists(select 1 from public.audit_logs where tenant_id = pg_temp.t() and action = 'INVENTORY_MOVEMENT_CREATED' and metadata @> jsonb_build_object('itemId',pg_temp.item(),'locationId',pg_temp.loc(),'movementType','ISSUE','quantity',2,'signedQuantity',-2,'description','Test movement')),'movement metadata');
select pg_temp.assert_true((select count(*) = 2 from public.audit_logs where tenant_id = pg_temp.t() and action = 'INVENTORY_COUNT_CREATED'),'count create audit');
select pg_temp.assert_true((select count(*) = 1 from public.audit_logs where tenant_id = pg_temp.t() and action = 'INVENTORY_COUNT_POSTED' and metadata->>'movementCount' = '1'),'count post audit');
-- Inject a late audit failure to verify all count lines / movements / status roll back atomically.
create function pg_temp.fail_count_audit() returns trigger language plpgsql as $$ begin if new.action = 'INVENTORY_COUNT_POSTED' then raise exception 'TEST_FAILURE'; end if; return new; end; $$;
create trigger inventory_test_failure before insert on public.audit_logs for each row execute function pg_temp.fail_count_audit();
set local role authenticated;
select pg_temp.expect_error($q$select public.post_inventory_count(pg_temp.t(),current_setting('test.draft')::uuid)$q$,'P0001','TEST_FAILURE');
select pg_temp.assert_true((select status = 'DRAFT' from public.inventory_counts where id = current_setting('test.draft')::uuid),'post rollback status');
select pg_temp.assert_true(not exists(select 1 from public.inventory_movements where source_id = current_setting('test.draft')::uuid),'post rollback movements');
reset role;
drop trigger inventory_test_failure on public.audit_logs;

-- Passive items invalidate pending counts; reactivation permits a negative count adjustment.
set local role authenticated;
select public.update_inventory_item(pg_temp.t(),current_setting('test.zero')::uuid,'Zero Item','PASSIVE',null,null,0);
select pg_temp.expect_error($q$select public.post_inventory_count(pg_temp.t(),current_setting('test.draft')::uuid)$q$,'22023','INVENTORY_ITEM_NOT_AVAILABLE');
select public.update_inventory_item(pg_temp.t(),current_setting('test.zero')::uuid,'Zero Item','ACTIVE',null,null,0);
select public.update_inventory_count(pg_temp.t(),current_setting('test.draft')::uuid,jsonb_build_array(jsonb_build_object('itemId',pg_temp.item(),'countedQuantity',3),jsonb_build_object('itemId',current_setting('test.zero'),'countedQuantity',0)));
select public.post_inventory_count(pg_temp.t(),current_setting('test.draft')::uuid);
select pg_temp.assert_true((select count(*) = 1 and sum(quantity) = -2 from public.inventory_movements where source_id = current_setting('test.draft')::uuid),'negative count adjustment');
-- Keep a fresh draft for permission checks below.
select set_config('test.draft',public.create_inventory_count(pg_temp.t(),pg_temp.loc())::text,true);
reset role;
select pg_temp.expect_error($q$insert into public.inventory_count_lines(tenant_id,count_id,inventory_item_id,system_quantity) values(pg_temp.t(),pg_temp.cnt(),current_setting('test.passive')::uuid,0)$q$,'55000');

-- Purchase mapping stays optional, tenant-safe and creates no stock movement on invoice post.
set local role authenticated;
select set_config('test.invoice',public.create_purchase_invoice_draft(pg_temp.t(),'91111111-aaaa-4aaa-8aaa-888888888881','STOCK-FK','2026-09-25','TRY',
  jsonb_build_array(jsonb_build_object('description','Mapped line','unit','kg','quantity',1,'unitPrice',10,'priceIncludesTax',false,'taxRate',0,'inventoryItemId',pg_temp.item()),
  jsonb_build_object('description','Unmapped line','unit','adet','quantity',1,'unitPrice',10,'priceIncludesTax',false,'taxRate',0)))::text,true);
select pg_temp.assert_true((select count(*) = 1 from public.purchase_invoice_lines where purchase_invoice_id = current_setting('test.invoice')::uuid and inventory_item_id is null),'null mapping preserved');
select pg_temp.expect_error($q$select public.create_purchase_invoice_draft(pg_temp.t(),'91111111-aaaa-4aaa-8aaa-888888888881','BAD-FK','2026-09-25','TRY',jsonb_build_array(jsonb_build_object('description','Other tenant','unit','kg','quantity',1,'unitPrice',10,'priceIncludesTax',false,'taxRate',0,'inventoryItemId','92222222-bbbb-4bbb-8bbb-888888888881')))$q$,'23503');
select pg_temp.assert_true(not exists(select 1 from public.purchase_invoices where tenant_id = pg_temp.t() and invoice_number = 'BAD-FK'),'bad mapping rolls back invoice');
select set_config('test.movement_count',(select count(*)::text from public.inventory_movements where tenant_id = pg_temp.t()),true);
select public.post_purchase_invoice(pg_temp.t(),current_setting('test.invoice')::uuid);
select pg_temp.assert_true((select count(*) = current_setting('test.movement_count')::integer from public.inventory_movements where tenant_id = pg_temp.t()),'invoice post no stock');
reset role;
select pg_temp.expect_error($q$update public.purchase_invoice_lines set inventory_item_id = null where purchase_invoice_id = current_setting('test.invoice')::uuid$q$,'55000');
select pg_temp.assert_true(not exists(select 1 from public.finance_transactions where tenant_id = pg_temp.t()),'no finance side effect');

-- Table grants, RLS, anon/PUBLIC and SECURITY DEFINER configuration.
do $$ declare name text; f record; begin
  foreach name in array array['inventory_items','inventory_movements','inventory_counts','inventory_count_lines'] loop
    perform pg_temp.assert_true((select relrowsecurity from pg_class where oid = ('public.'||name)::regclass),'RLS '||name);
    perform pg_temp.assert_true(not has_table_privilege('anon','public.'||name,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE'),'anon table '||name);
    perform pg_temp.assert_true(not has_table_privilege('authenticated','public.'||name,'INSERT,UPDATE,DELETE,TRUNCATE'),'browser writes '||name);
  end loop;
  for f in select p.oid,p.prosecdef,p.proconfig from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname in
    ('create_inventory_item','update_inventory_item','create_inventory_movement','create_inventory_count','update_inventory_count','post_inventory_count','get_inventory_overview','get_inventory_management','get_inventory_context','get_inventory_counts','get_inventory_count_detail') loop
    perform pg_temp.assert_true(f.prosecdef and 'search_path=""' = any(f.proconfig),'secdef path');
    perform pg_temp.assert_true(not has_function_privilege('anon',f.oid,'EXECUTE'),'anon RPC');
    perform pg_temp.assert_true(has_function_privilege('authenticated',f.oid,'EXECUTE') and has_function_privilege('service_role',f.oid,'EXECUTE'),'RPC roles');
    perform pg_temp.assert_true(not exists(select 1 from pg_proc p,lateral aclexplode(p.proacl) a where p.oid = f.oid and a.grantee = 0 and a.privilege_type = 'EXECUTE'),'PUBLIC RPC');
  end loop;
end $$;
-- Each permission independently removed; unrelated permissions do not substitute.
create temporary table inventory_permission_cases(permission text,command text);
insert into inventory_permission_cases values
('inventory.read','select public.get_inventory_overview(pg_temp.t())'),('inventory.read','select public.get_inventory_management(pg_temp.t())'),
('inventory.write',$q$select public.create_inventory_item(pg_temp.t(),'Denied','GRAM')$q$),('inventory.write',$q$select pg_temp.update_item('Denied','ACTIVE')$q$),
('inventory.adjust',$q$select pg_temp.move('RECEIPT',1)$q$),('inventory.adjust',$q$select public.post_inventory_count(pg_temp.t(),current_setting('test.draft')::uuid)$q$),
('inventory.count','select public.create_inventory_count(pg_temp.t(),pg_temp.loc())'),('inventory.count',$q$select public.update_inventory_count(pg_temp.t(),current_setting('test.draft')::uuid,'[]')$q$),
('inventory.count',$q$select public.post_inventory_count(pg_temp.t(),current_setting('test.draft')::uuid)$q$);
do $$ declare c record; begin
  for c in select * from inventory_permission_cases loop
    delete from public.role_permissions where role_id = '91111111-3333-4333-8333-111111111111' and permission_key = c.permission;
    perform pg_temp.expect_error(c.command,'42501','INVENTORY_PERMISSION_DENIED');
    insert into public.role_permissions(tenant_id,role_id,permission_key) values(pg_temp.t(),'91111111-3333-4333-8333-111111111111',c.permission);
  end loop;
end $$;
update public.tenant_modules set enabled = false where tenant_id = pg_temp.t() and module_key = 'inventory';
do $$ declare c record; begin for c in select * from inventory_permission_cases loop perform pg_temp.expect_error(c.command,'42501','INVENTORY_MODULE_NOT_AVAILABLE'); end loop; end $$;
update public.tenant_modules set enabled = true where tenant_id = pg_temp.t() and module_key = 'inventory';
set local role authenticated;
select set_config('request.jwt.claim.sub','91111111-7777-4777-8777-111111111111',true);
select pg_temp.assert_true(jsonb_array_length(public.get_inventory_overview(pg_temp.t())->'items') = 3,'readonly overview');
select pg_temp.expect_error($q$select pg_temp.move('RECEIPT',1)$q$,'42501');
select pg_temp.expect_error($q$select public.create_inventory_item(pg_temp.t(),'Denied','EACH')$q$,'42501');
select pg_temp.expect_error($q$select public.create_inventory_count(pg_temp.t(),pg_temp.loc())$q$,'42501');
select pg_temp.expect_error($q$select public.get_inventory_context(pg_temp.t())$q$,'42501');
select pg_temp.expect_error($q$insert into public.inventory_items(tenant_id,name,base_unit) values(pg_temp.t(),'Direct','GRAM')$q$,'42501');
select pg_temp.expect_error($q$insert into public.inventory_movements(tenant_id,location_id,inventory_item_id,movement_type,quantity,description,created_by_user_id) values(pg_temp.t(),pg_temp.loc(),pg_temp.item(),'COUNT_ADJUSTMENT',1,'Direct',auth.uid())$q$,'42501');
select pg_temp.assert_true(not exists(select 1 from public.inventory_items where tenant_id <> pg_temp.t()),'RLS tenant isolation');
select pg_temp.expect_error($q$select public.get_inventory_overview('92222222-bbbb-4bbb-8bbb-222222222222')$q$,'42501');
select set_config('request.jwt.claim.sub','91111111-6666-4666-8666-111111111111',true);
select pg_temp.expect_error($q$select public.update_inventory_item(pg_temp.t(),'92222222-bbbb-4bbb-8bbb-888888888881','Denied','ACTIVE')$q$,'22023');
select pg_temp.expect_error($q$select public.get_inventory_overview(pg_temp.t(),'92222222-bbbb-4bbb-8bbb-999999999991')$q$,'22023');
select pg_temp.expect_error($q$select public.post_inventory_count('92222222-bbbb-4bbb-8bbb-222222222222',pg_temp.cnt())$q$,'42501');
select set_config('request.jwt.claim.sub','',true);
select pg_temp.expect_error($q$select public.get_inventory_overview(pg_temp.t())$q$,'42501');
select pg_temp.expect_error($q$select pg_temp.move('RECEIPT',1)$q$,'42501');
set local role anon;
select pg_temp.expect_error($q$select public.get_inventory_overview(pg_temp.t())$q$,'42501');
select pg_temp.expect_error($q$select pg_temp.move('RECEIPT',1)$q$,'42501');
select pg_temp.expect_error($q$select * from public.inventory_items$q$,'42501');
reset role;
rollback;
do $$ begin
  if exists(select 1 from auth.users where email like 'inventory-%@coost.test') or exists(select 1 from public.tenants where id in ('91111111-aaaa-4aaa-8aaa-111111111111','92222222-bbbb-4bbb-8bbb-222222222222')) then raise exception 'RESIDUAL_FIXTURES'; end if;
end $$;
select 'PASS - INVENTORY FOUNDATION' result,(select count(*) from auth.users where email like 'inventory-%@coost.test') residual_test_users,
  (select count(*) from public.tenants where id in ('91111111-aaaa-4aaa-8aaa-111111111111','92222222-bbbb-4bbb-8bbb-222222222222')) residual_test_tenants;
