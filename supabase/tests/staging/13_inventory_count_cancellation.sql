begin;
insert into auth.users(id,aud,role,email,created_at,updated_at) values
('a1111111-6666-4666-8666-111111111111','authenticated','authenticated','count-cancel-writer@coost.test',now(),now()),
('a1111111-7777-4777-8777-111111111111','authenticated','authenticated','count-cancel-reader@coost.test',now(),now());
insert into public.tenants(id,name,status) values
('a1111111-aaaa-4aaa-8aaa-111111111111','Inventory A','ACTIVE'),('a2222222-bbbb-4bbb-8bbb-222222222222','Inventory B','ACTIVE');
insert into public.memberships(id,tenant_id,user_id,status) values
('a1111111-1111-4111-8111-111111111111','a1111111-aaaa-4aaa-8aaa-111111111111','a1111111-6666-4666-8666-111111111111','ACTIVE'),
('a1111111-2222-4222-8222-111111111111','a1111111-aaaa-4aaa-8aaa-111111111111','a1111111-7777-4777-8777-111111111111','ACTIVE');
insert into public.roles(id,tenant_id,key,name) values
('a1111111-3333-4333-8333-111111111111','a1111111-aaaa-4aaa-8aaa-111111111111','inventory-writer','Inventory Writer'),
('a1111111-4444-4444-8444-111111111111','a1111111-aaaa-4aaa-8aaa-111111111111','inventory-reader','Inventory Reader');
insert into public.membership_roles(tenant_id,membership_id,role_id) values
('a1111111-aaaa-4aaa-8aaa-111111111111','a1111111-1111-4111-8111-111111111111','a1111111-3333-4333-8333-111111111111'),
('a1111111-aaaa-4aaa-8aaa-111111111111','a1111111-2222-4222-8222-111111111111','a1111111-4444-4444-8444-111111111111');
insert into public.role_permissions(tenant_id,role_id,permission_key)
select 'a1111111-aaaa-4aaa-8aaa-111111111111','a1111111-3333-4333-8333-111111111111',unnest(array['inventory.read','inventory.write','inventory.adjust','inventory.count','purchasing.read','purchasing.write']);
insert into public.role_permissions(tenant_id,role_id,permission_key) values ('a1111111-aaaa-4aaa-8aaa-111111111111','a1111111-4444-4444-8444-111111111111','inventory.read');
insert into public.tenant_modules(tenant_id,module_key,enabled)
select 'a1111111-aaaa-4aaa-8aaa-111111111111',unnest(array['inventory','purchasing','suppliers']),true;
insert into public.tenant_modules(tenant_id,module_key,enabled) values('a2222222-bbbb-4bbb-8bbb-222222222222','inventory',true);
insert into public.locations(id,tenant_id,name,status) values
('a1111111-aaaa-4aaa-8aaa-999999999991','a1111111-aaaa-4aaa-8aaa-111111111111','Merkez','ACTIVE'),
('a1111111-aaaa-4aaa-8aaa-999999999992','a1111111-aaaa-4aaa-8aaa-111111111111','Şube','ACTIVE'),
('a1111111-aaaa-4aaa-8aaa-999999999993','a1111111-aaaa-4aaa-8aaa-111111111111','Pasif','PASSIVE'),
('a2222222-bbbb-4bbb-8bbb-999999999991','a2222222-bbbb-4bbb-8bbb-222222222222','Other','ACTIVE');
insert into public.inventory_items(id,tenant_id,name,base_unit) values('a2222222-bbbb-4bbb-8bbb-888888888881','a2222222-bbbb-4bbb-8bbb-222222222222','Other Item','GRAM');
insert into public.inventory_counts(id,tenant_id,location_id,created_by) values('a2222222-bbbb-4bbb-8bbb-777777777771','a2222222-bbbb-4bbb-8bbb-222222222222','a2222222-bbbb-4bbb-8bbb-999999999991','a1111111-6666-4666-8666-111111111111');
insert into public.suppliers(id,tenant_id,name) values('a1111111-aaaa-4aaa-8aaa-888888888881','a1111111-aaaa-4aaa-8aaa-111111111111','Inventory Supplier');

create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERT: %',message; end if; end; $$;
create function pg_temp.expect_error(command text,state text,message text default null) returns void language plpgsql as $$
begin execute command; raise exception 'EXPECTED_ERROR_NOT_RAISED: %',command;
exception when others then if sqlstate <> state or (message is not null and sqlerrm <> message) then raise; end if; end; $$;
create function pg_temp.t() returns uuid language sql as $$ select 'a1111111-aaaa-4aaa-8aaa-111111111111'::uuid $$;
create function pg_temp.loc() returns uuid language sql as $$ select 'a1111111-aaaa-4aaa-8aaa-999999999991'::uuid $$;
create function pg_temp.item() returns uuid language sql as $$ select current_setting('test.item')::uuid $$;
create function pg_temp.cnt() returns uuid language sql as $$ select current_setting('test.count')::uuid $$;
create function pg_temp.move(kind text,q numeric,direction text default null) returns uuid language sql as $$
 select public.create_inventory_movement(pg_temp.t(),pg_temp.loc(),pg_temp.item(),kind,q,' Test movement ',direction) $$;
create function pg_temp.update_item(new_name text,new_status text) returns uuid language sql as $$
 select public.update_inventory_item(pg_temp.t(),pg_temp.item(),new_name,new_status,'SKU-1','Protein',5) $$;

set local role authenticated;
select set_config('request.jwt.claim.sub','a1111111-6666-4666-8666-111111111111',true);
select set_config('test.item',public.create_inventory_item(pg_temp.t(),'Count Item','EACH')::text,true);
select set_config('test.count',public.create_inventory_count(pg_temp.t(),pg_temp.loc(),'Cancel this')::text,true);
select pg_temp.expect_error($q$select public.create_inventory_count(pg_temp.t(),pg_temp.loc())$q$,'23505','INVENTORY_COUNT_ALREADY_OPEN');
select pg_temp.assert_true((select count(*) = 1 from public.inventory_counts where tenant_id = pg_temp.t()),'duplicate leaves no header');
select pg_temp.assert_true((select count(*) = 1 from public.inventory_count_lines where tenant_id = pg_temp.t()),'duplicate leaves no lines');
select public.update_inventory_count(pg_temp.t(),pg_temp.cnt(),jsonb_build_array(jsonb_build_object('itemId',pg_temp.item(),'countedQuantity',4)));
select public.cancel_inventory_count(pg_temp.t(),pg_temp.cnt());
select pg_temp.assert_true((select status = 'CANCELLED' and cancelled_at is not null and cancelled_by = auth.uid() and posted_at is null and posted_by is null from public.inventory_counts where id = pg_temp.cnt()),'cancel state');
select pg_temp.assert_true((select count(*) = 1 and min(counted_quantity) = 4 from public.inventory_count_lines where count_id = pg_temp.cnt()),'preserves lines and quantities');
select pg_temp.assert_true(not exists(select 1 from public.inventory_movements where tenant_id = pg_temp.t()),'cancel produces no movements');
select pg_temp.assert_true(public.get_inventory_count_detail(pg_temp.t(),pg_temp.cnt())->>'status' = 'CANCELLED','cancelled detail');
select pg_temp.assert_true((public.get_inventory_counts(pg_temp.t())->'counts'->0->>'cancelledBy')::uuid = auth.uid(),'cancellation metadata read');
select pg_temp.expect_error($q$select public.cancel_inventory_count(pg_temp.t(),pg_temp.cnt())$q$,'55000','INVENTORY_COUNT_IMMUTABLE');
select pg_temp.expect_error($q$select public.update_inventory_count(pg_temp.t(),pg_temp.cnt(),'[]')$q$,'55000');
select pg_temp.expect_error($q$select public.post_inventory_count(pg_temp.t(),pg_temp.cnt())$q$,'55000');
select set_config('test.posted',public.create_inventory_count(pg_temp.t(),pg_temp.loc())::text,true);
select public.update_inventory_count(pg_temp.t(),current_setting('test.posted')::uuid,jsonb_build_array(jsonb_build_object('itemId',pg_temp.item(),'countedQuantity',0)));
select public.post_inventory_count(pg_temp.t(),current_setting('test.posted')::uuid);
select pg_temp.expect_error($q$select public.cancel_inventory_count(pg_temp.t(),current_setting('test.posted')::uuid)$q$,'55000');
select set_config('test.draft',public.create_inventory_count(pg_temp.t(),pg_temp.loc())::text,true);
-- Different locations can have independent drafts.
select public.create_inventory_count(pg_temp.t(),'a1111111-aaaa-4aaa-8aaa-999999999992');
reset role;
select pg_temp.assert_true((select count(*) = 1 from public.audit_logs where tenant_id = pg_temp.t() and action = 'INVENTORY_COUNT_CANCELLED' and entity_id = pg_temp.cnt()
  and metadata = jsonb_build_object('countId',pg_temp.cnt(),'locationId',pg_temp.loc()) and actor_user_id = 'a1111111-6666-4666-8666-111111111111'),'exactly one cancellation audit');
select pg_temp.assert_true((select count(*) = 4 from public.audit_logs where tenant_id = pg_temp.t() and action = 'INVENTORY_COUNT_CREATED'),'duplicate draft has no audit');
select pg_temp.expect_error($q$update public.inventory_counts set notes = 'Changed' where id = pg_temp.cnt()$q$,'55000');
select pg_temp.expect_error($q$update public.inventory_counts set status = 'DRAFT',cancelled_at = null,cancelled_by = null where id = pg_temp.cnt()$q$,'55000');
select pg_temp.expect_error($q$delete from public.inventory_counts where id = pg_temp.cnt()$q$,'55000');
select pg_temp.expect_error($q$update public.inventory_count_lines set counted_quantity = 0,difference = 0 where count_id = pg_temp.cnt()$q$,'55000');
select pg_temp.expect_error($q$delete from public.inventory_count_lines where count_id = pg_temp.cnt()$q$,'55000');
select pg_temp.expect_error($q$insert into public.inventory_count_lines(tenant_id,count_id,inventory_item_id,system_quantity) values(pg_temp.t(),pg_temp.cnt(),pg_temp.item(),0)$q$,'55000');
select pg_temp.expect_error($q$update public.inventory_counts set cancelled_at = now() where id = current_setting('test.draft')::uuid$q$,'23514');
select pg_temp.expect_error($q$update public.inventory_counts set status = 'CANCELLED',cancelled_at = now() where id = current_setting('test.draft')::uuid$q$,'23514');
select pg_temp.expect_error($q$update public.inventory_counts set status = 'POSTED',posted_at = now(),posted_by = auth.uid(),cancelled_at = now() where id = current_setting('test.draft')::uuid$q$,'23514');
-- Audit failure rolls back cancellation and keeps the unique draft slot occupied.
create function pg_temp.fail_cancel_audit() returns trigger language plpgsql as $$ begin if new.action = 'INVENTORY_COUNT_CANCELLED' then raise exception 'TEST_CANCEL_FAILURE'; end if; return new; end; $$;
create trigger cancel_test_failure before insert on public.audit_logs for each row execute function pg_temp.fail_cancel_audit();
set local role authenticated;
select pg_temp.expect_error($q$select public.cancel_inventory_count(pg_temp.t(),current_setting('test.draft')::uuid)$q$,'P0001','TEST_CANCEL_FAILURE');
select pg_temp.assert_true((select status = 'DRAFT' and cancelled_at is null and cancelled_by is null from public.inventory_counts where id = current_setting('test.draft')::uuid),'cancel rollback');
select pg_temp.expect_error($q$select public.create_inventory_count(pg_temp.t(),pg_temp.loc())$q$,'23505','INVENTORY_COUNT_ALREADY_OPEN');
reset role;
drop trigger cancel_test_failure on public.audit_logs;
-- Only inventory.count is required (no adjust/write/read).
delete from public.role_permissions where role_id = 'a1111111-3333-4333-8333-111111111111' and permission_key <> 'inventory.count';
set local role authenticated;
select public.cancel_inventory_count(pg_temp.t(),current_setting('test.draft')::uuid);
select set_config('test.draft',public.create_inventory_count(pg_temp.t(),pg_temp.loc())::text,true);
select pg_temp.expect_error($q$select public.cancel_inventory_count('a2222222-bbbb-4bbb-8bbb-222222222222',pg_temp.cnt())$q$,'42501');
select pg_temp.expect_error($q$select public.cancel_inventory_count(pg_temp.t(),'a2222222-bbbb-4bbb-8bbb-777777777771')$q$,'22023','INVENTORY_COUNT_NOT_AVAILABLE');
select pg_temp.expect_error($q$update public.inventory_counts set status = 'CANCELLED' where id = current_setting('test.draft')::uuid$q$,'42501');
select pg_temp.expect_error($q$delete from public.inventory_count_lines where count_id = current_setting('test.draft')::uuid$q$,'42501');
select set_config('request.jwt.claim.sub','a1111111-7777-4777-8777-111111111111',true);
select pg_temp.expect_error($q$select public.cancel_inventory_count(pg_temp.t(),current_setting('test.draft')::uuid)$q$,'42501');
select pg_temp.assert_true(public.get_inventory_count_detail(pg_temp.t(),pg_temp.cnt())->>'status' = 'CANCELLED','reader can view cancelled');
reset role;
update public.tenant_modules set enabled = false where tenant_id = pg_temp.t() and module_key = 'inventory';
set local role authenticated;
select set_config('request.jwt.claim.sub','a1111111-6666-4666-8666-111111111111',true);
select pg_temp.expect_error($q$select public.cancel_inventory_count(pg_temp.t(),current_setting('test.draft')::uuid)$q$,'42501','INVENTORY_MODULE_NOT_AVAILABLE');
reset role;
update public.tenant_modules set enabled = true where tenant_id = pg_temp.t() and module_key = 'inventory';
set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
select pg_temp.expect_error($q$select public.cancel_inventory_count(pg_temp.t(),current_setting('test.draft')::uuid)$q$,'42501','AUTHENTICATION_REQUIRED');
set local role anon;
select pg_temp.expect_error($q$select public.cancel_inventory_count(pg_temp.t(),current_setting('test.draft')::uuid)$q$,'42501');
reset role;
select pg_temp.assert_true(not has_function_privilege('anon','public.cancel_inventory_count(uuid,uuid)','EXECUTE'),'anon execute revoked');
select pg_temp.assert_true(has_function_privilege('authenticated','public.cancel_inventory_count(uuid,uuid)','EXECUTE') and has_function_privilege('service_role','public.cancel_inventory_count(uuid,uuid)','EXECUTE'),'allowed execute');
select pg_temp.assert_true((select prosecdef and 'search_path=""' = any(proconfig) from pg_proc where oid = 'public.cancel_inventory_count(uuid,uuid)'::regprocedure),'secdef search path');
select pg_temp.assert_true(not exists(select 1 from pg_proc p,lateral aclexplode(p.proacl) a where p.oid = 'public.cancel_inventory_count(uuid,uuid)'::regprocedure and a.grantee = 0 and a.privilege_type = 'EXECUTE'),'PUBLIC execute revoked');
select pg_temp.assert_true(not has_table_privilege('authenticated','public.inventory_counts','INSERT,UPDATE,DELETE,TRUNCATE') and not has_table_privilege('authenticated','public.inventory_count_lines','INSERT,UPDATE,DELETE,TRUNCATE'),'direct writes remain revoked');
select pg_temp.assert_true(not exists(select 1 from public.inventory_movements where tenant_id = pg_temp.t()),'no movement throughout zero-count and cancellations');
rollback;
do $$ begin
  if exists(select 1 from auth.users where email like 'count-cancel-%@coost.test') or exists(select 1 from public.tenants where id in ('a1111111-aaaa-4aaa-8aaa-111111111111','a2222222-bbbb-4bbb-8bbb-222222222222')) then raise exception 'RESIDUAL_FIXTURES'; end if;
end $$;
select 'PASS - INVENTORY COUNT CANCELLATION' result,(select count(*) from auth.users where email like 'count-cancel-%@coost.test') residual_test_users,
  (select count(*) from public.tenants where id in ('a1111111-aaaa-4aaa-8aaa-111111111111','a2222222-bbbb-4bbb-8bbb-222222222222')) residual_test_tenants;
