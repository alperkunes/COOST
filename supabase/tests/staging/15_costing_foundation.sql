begin;

-- Test-only: allow authenticated to execute pg_temp helpers created in this
-- transaction. ROLLBACK at the end restores the hardened production defaults.
alter default privileges for role postgres
  grant execute on functions to anon, authenticated;
create function pg_temp.ok(v boolean,m text) returns void language plpgsql as $$ begin if v is distinct from true then raise exception 'ASSERT: %',m; end if; end; $$;
create function pg_temp.err(q text,s text,m text default null) returns void language plpgsql as $$ begin execute q; raise exception 'EXPECTED_ERROR: %',q; exception when others then if sqlstate <> s or (m is not null and sqlerrm <> m) then raise; end if; end; $$;
create function pg_temp.t() returns uuid language sql as $$ select 'c1111111-aaaa-4aaa-8aaa-111111111111'::uuid $$;
create function pg_temp.id(k text) returns uuid language sql as $$ select current_setting('test.'||k)::uuid $$;
insert into auth.users(id,aud,role,email) values ('c1111111-1111-4111-8111-111111111111','authenticated','authenticated','costing-writer@coost.test'),('c1111111-2222-4222-8222-111111111111','authenticated','authenticated','costing-reader@coost.test');
insert into public.tenants(id,name,status) values(pg_temp.t(),'Costing A','ACTIVE'),('c2222222-aaaa-4aaa-8aaa-111111111111','Costing B','ACTIVE');
insert into public.memberships(id,tenant_id,user_id,status) values('c1111111-3333-4333-8333-111111111111',pg_temp.t(),'c1111111-1111-4111-8111-111111111111','ACTIVE'),('c1111111-4444-4444-8444-111111111111',pg_temp.t(),'c1111111-2222-4222-8222-111111111111','ACTIVE');
insert into public.roles(id,tenant_id,key,name) values('c1111111-5555-4555-8555-111111111111',pg_temp.t(),'owner','Owner'),('c1111111-6666-4666-8666-111111111111',pg_temp.t(),'reader','Reader');
insert into public.membership_roles(tenant_id,membership_id,role_id) values(pg_temp.t(),'c1111111-3333-4333-8333-111111111111','c1111111-5555-4555-8555-111111111111'),(pg_temp.t(),'c1111111-4444-4444-8444-111111111111','c1111111-6666-4666-8666-111111111111');
-- Repeating the exact owner grant remains idempotent and does not authorize other roles.
insert into public.role_permissions(tenant_id,role_id,permission_key)
select r.tenant_id,r.id,p.key from public.roles r cross join (values ('food-service.costing.read'),('food-service.costing.write')) p(key) where r.key='owner' on conflict do nothing;
insert into public.role_permissions(tenant_id,role_id,permission_key)
select r.tenant_id,r.id,p.key from public.roles r cross join (values ('food-service.costing.read'),('food-service.costing.write')) p(key) where r.key='owner' on conflict do nothing;
select pg_temp.ok((select count(*)=2 from public.role_permissions where role_id='c1111111-5555-4555-8555-111111111111'),'owner grants once');
select pg_temp.ok(not exists(select 1 from public.role_permissions where role_id='c1111111-6666-4666-8666-111111111111'),'other roles untouched');
insert into public.role_permissions(tenant_id,role_id,permission_key) values(pg_temp.t(),'c1111111-6666-4666-8666-111111111111','food-service.costing.read');
insert into public.role_permissions(tenant_id,role_id,permission_key) select pg_temp.t(),'c1111111-5555-4555-8555-111111111111',unnest(array['inventory.write','inventory.adjust','inventory.count','purchasing.write']);
insert into public.tenant_modules(tenant_id,module_key,enabled) select pg_temp.t(),unnest(array['food-service','inventory','purchasing','suppliers']),true;
insert into public.locations(id,tenant_id,name,status) values('c1111111-7777-4777-8777-111111111111',pg_temp.t(),'Kitchen','ACTIVE'),('c1111111-8888-4888-8888-111111111111',pg_temp.t(),'Branch','ACTIVE'),('c2222222-7777-4777-8777-111111111111','c2222222-aaaa-4aaa-8aaa-111111111111','Other','ACTIVE');
insert into public.suppliers(id,tenant_id,name) values('c1111111-9999-4999-8999-111111111111',pg_temp.t(),'Test Supplier');
insert into public.inventory_items(id,tenant_id,name,base_unit) values('c2222222-8888-4888-8888-111111111111','c2222222-aaaa-4aaa-8aaa-111111111111','Foreign','GRAM');
create function pg_temp.buy(n text,d date,c text,q numeric,price numeric,loc uuid,item uuid,unit uuid) returns uuid language plpgsql as $$ declare inv uuid; begin
  inv:=public.create_purchase_invoice_draft(pg_temp.t(),'c1111111-9999-4999-8999-111111111111',n,d,c,jsonb_build_array(jsonb_build_object('description','Test purchase','unit','KG','quantity',q,'unitPrice',price,'priceIncludesTax',false,'taxRate',20,'inventoryTracking','MAPPED','inventoryItemId',item,'inventoryPurchaseUnitId',unit)),loc);
  perform public.post_purchase_invoice(pg_temp.t(),inv); return inv;
end; $$;
create function pg_temp.lines(item uuid,q numeric default 100) returns jsonb language sql as $$ select jsonb_build_array(jsonb_build_object('inventoryItemId',item,'quantityBase',q,'notes','Test')); $$;
create function pg_temp.recipe(n text,ls jsonb,p numeric default 2,c text default 'TRY') returns uuid language sql as $$ select public.create_recipe(pg_temp.t(),n,c,p,ls); $$;
create function pg_temp.cost(c text default 'TRY',loc uuid default null) returns jsonb language sql as $$ select i from jsonb_array_elements(public.get_inventory_cost_overview(pg_temp.t(),c,loc)->'items') i where i->>'id'=pg_temp.id('meat')::text; $$;
create function pg_temp.rc(id uuid) returns jsonb language sql as $$ select r from jsonb_array_elements(public.get_recipe_costing_overview(pg_temp.t())->'recipes') r where r->>'id'=id::text; $$;
create function pg_temp.mc(id uuid) returns jsonb language sql as $$ select p from jsonb_array_elements(public.get_menu_costing_overview(pg_temp.t())->'products') p where p->>'id'=id::text; $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','c1111111-1111-4111-8111-111111111111',true);
select set_config('test.meat',public.create_inventory_item(pg_temp.t(),'Meat','GRAM')::text,true);
select set_config('test.oil',public.create_inventory_item(pg_temp.t(),'Oil','MILLILITER')::text,true);
select set_config('test.passive',public.create_inventory_item(pg_temp.t(),'Passive','EACH')::text,true);
select public.update_inventory_item(pg_temp.t(),pg_temp.id('passive'),'Passive','PASSIVE');
select set_config('test.kg',public.create_inventory_purchase_unit(pg_temp.t(),pg_temp.id('meat'),'KG',1000)::text,true);
select set_config('test.litre',public.create_inventory_purchase_unit(pg_temp.t(),pg_temp.id('oil'),'Litre',1000)::text,true);
select pg_temp.buy('COST-1','2026-01-01','TRY',1,100,'c1111111-7777-4777-8777-111111111111',pg_temp.id('meat'),pg_temp.id('kg'));
select pg_temp.buy('COST-2','2026-01-02','TRY',2,150,'c1111111-7777-4777-8777-111111111111',pg_temp.id('meat'),pg_temp.id('kg'));
select pg_temp.buy('COST-3','2026-01-03','TRY',1,200,'c1111111-8888-4888-8888-111111111111',pg_temp.id('meat'),pg_temp.id('kg'));
select pg_temp.buy('COST-EUR','2026-01-04','EUR',1,5000,'c1111111-7777-4777-8777-111111111111',pg_temp.id('meat'),pg_temp.id('kg'));
select pg_temp.buy('OIL-EUR','2026-01-04','EUR',1,50,'c1111111-7777-4777-8777-111111111111',pg_temp.id('oil'),pg_temp.id('litre'));
select pg_temp.ok((pg_temp.cost()->'lastPurchase'->>'unitCost')::numeric=.2,'last net not gross');
select pg_temp.ok((pg_temp.cost()->'previousPurchase'->>'unitCost')::numeric=.15,'previous');
select pg_temp.ok((pg_temp.cost()->>'weightedPurchaseUnitCost')::numeric=.15,'weighted purchase');
select pg_temp.ok(abs((pg_temp.cost()->>'priceChangePct')::numeric-100::numeric/3)<0.00000001,'price change');
select pg_temp.ok((pg_temp.cost()->>'purchaseReceiptCount')::int=3 and (pg_temp.cost()->>'purchasedBaseQuantity')::numeric=4000 and (pg_temp.cost()->>'purchaseNetTotal')::numeric=600,'receipt aggregates');
select pg_temp.ok((pg_temp.cost('EUR')->'lastPurchase'->>'unitCost')::numeric=5,'currency separated');
select pg_temp.ok((pg_temp.cost('TRY','c1111111-7777-4777-8777-111111111111')->'lastPurchase'->>'unitCost')::numeric=.15 and abs((pg_temp.cost('TRY','c1111111-7777-4777-8777-111111111111')->>'weightedPurchaseUnitCost')::numeric-400::numeric/3000)<0.00000001,'location scope');
select pg_temp.ok(pg_temp.cost('EUR')->>'priceChangePct' is null,'no previous');
select set_config('test.cost_before',pg_temp.cost()::text,true);
select public.update_inventory_purchase_unit(pg_temp.t(),pg_temp.id('kg'),'KG',500,'ACTIVE');
select public.create_inventory_movement(pg_temp.t(),'c1111111-7777-4777-8777-111111111111',pg_temp.id('meat'),'RECEIPT',123,'Manual');
select public.create_inventory_movement(pg_temp.t(),'c1111111-7777-4777-8777-111111111111',pg_temp.id('meat'),'WASTE',1,'Waste');
select public.create_inventory_movement(pg_temp.t(),'c1111111-7777-4777-8777-111111111111',pg_temp.id('meat'),'ISSUE',1,'Issue');
select public.create_inventory_movement(pg_temp.t(),'c1111111-7777-4777-8777-111111111111',pg_temp.id('meat'),'COMPLIMENTARY',1,'Gift');
select set_config('test.count',public.create_inventory_count(pg_temp.t(),'c1111111-7777-4777-8777-111111111111')::text,true);
select public.update_inventory_count(pg_temp.t(),pg_temp.id('count'),jsonb_build_array(jsonb_build_object('itemId',pg_temp.id('meat'),'countedQuantity',10),jsonb_build_object('itemId',pg_temp.id('oil'),'countedQuantity',10)));
select public.post_inventory_count(pg_temp.t(),pg_temp.id('count'));
select pg_temp.ok(pg_temp.cost()=current_setting('test.cost_before')::jsonb,'conversion edit/manual/issue/waste/count do not change cost');
select set_config('test.recipe',pg_temp.recipe('Plate',pg_temp.lines(pg_temp.id('meat')))::text,true);
select pg_temp.ok((pg_temp.rc(pg_temp.id('recipe'))->>'totalLastCost')::numeric=20 and (pg_temp.rc(pg_temp.id('recipe'))->>'totalWeightedCost')::numeric=15,'recipe totals');
select pg_temp.ok((pg_temp.rc(pg_temp.id('recipe'))->>'costPerPortionLast')::numeric=10 and (pg_temp.rc(pg_temp.id('recipe'))->>'costPerPortionWeighted')::numeric=7.5,'per portion');
select set_config('test.missing',pg_temp.recipe('Missing',pg_temp.lines(pg_temp.id('meat'))||pg_temp.lines(pg_temp.id('oil')))::text,true);
select pg_temp.ok((pg_temp.rc(pg_temp.id('missing'))->>'costingComplete')::boolean=false and (pg_temp.rc(pg_temp.id('missing'))->>'missingCostItemCount')::int=1 and pg_temp.rc(pg_temp.id('missing'))->>'totalLastCost' is null and pg_temp.rc(pg_temp.id('missing'))->>'totalWeightedCost' is null,'missing currency ingredient never zero');
select pg_temp.err($q$select pg_temp.recipe(' plate ',pg_temp.lines(pg_temp.id('meat')))$q$,'23505');
select pg_temp.err($q$select pg_temp.recipe('Foreign',pg_temp.lines('c2222222-8888-4888-8888-111111111111'))$q$,'22023','COSTING_ITEM_NOT_AVAILABLE');
select pg_temp.err($q$select pg_temp.recipe('Passive',pg_temp.lines(pg_temp.id('passive')))$q$,'22023','COSTING_ITEM_NOT_AVAILABLE');
select pg_temp.err($q$select pg_temp.recipe('Bad',pg_temp.lines(pg_temp.id('meat'),0))$q$,'22023');
select pg_temp.err($q$select pg_temp.recipe('Bad',pg_temp.lines(pg_temp.id('meat'),0.00001))$q$,'22023');
select pg_temp.err($q$select pg_temp.recipe('Bad',pg_temp.lines(pg_temp.id('meat'),1000000000000))$q$,'22023');
select pg_temp.err($q$select pg_temp.recipe('Bad',pg_temp.lines(pg_temp.id('meat')),0)$q$,'22023');
select pg_temp.err($q$select pg_temp.recipe('Bad',pg_temp.lines(pg_temp.id('meat')),0.00001)$q$,'22023');
select pg_temp.err($q$select public.update_recipe(pg_temp.t(),pg_temp.id('recipe'),'Plate','TRY',2,'ACTIVE',pg_temp.lines(pg_temp.id('meat')))$q$,'22023','COSTING_NO_CHANGES');
select public.update_recipe(pg_temp.t(),pg_temp.id('recipe'),'Plate updated','TRY',4,'ACTIVE',pg_temp.lines(pg_temp.id('meat'),200),'PLATE','Main');
select pg_temp.ok((pg_temp.rc(pg_temp.id('recipe'))->>'portions')::numeric=4 and (pg_temp.rc(pg_temp.id('recipe'))->>'costPerPortionWeighted')::numeric=7.5,'recipe update');
select set_config('test.product',public.create_menu_product(pg_temp.t(),'Menu',pg_temp.id('recipe'),'TRY',120,20,'WEIGHTED_PURCHASE',25)::text,true);
select pg_temp.ok((pg_temp.mc(pg_temp.id('product'))->>'salePriceNet')::numeric=100 and (pg_temp.mc(pg_temp.id('product'))->>'foodCostPct')::numeric=7.5 and (pg_temp.mc(pg_temp.id('product'))->>'contributionMargin')::numeric=92.5,'net food cost margin');
select pg_temp.ok((pg_temp.mc(pg_temp.id('product'))->>'suggestedNetPrice')::numeric=30 and (pg_temp.mc(pg_temp.id('product'))->>'suggestedGrossPrice')::numeric=36,'suggested price');
select pg_temp.err($q$select public.create_menu_product(pg_temp.t(),'Mismatch',pg_temp.id('recipe'),'EUR',120,20)$q$,'22023','MENU_RECIPE_CURRENCY_MISMATCH');
select pg_temp.err($q$select public.update_menu_product(pg_temp.t(),pg_temp.id('product'),'Menu',pg_temp.id('recipe'),'TRY',120,20,'WEIGHTED_PURCHASE','ACTIVE',25)$q$,'22023','COSTING_NO_CHANGES');
select pg_temp.err($q$select public.update_recipe(pg_temp.t(),pg_temp.id('recipe'),'Plate updated','EUR',4,'ACTIVE',pg_temp.lines(pg_temp.id('meat'),200),'PLATE','Main')$q$,'22023','RECIPE_CURRENCY_IN_USE');
select public.update_menu_product(pg_temp.t(),pg_temp.id('product'),'Menu',pg_temp.id('recipe'),'TRY',120,20,'LAST_PURCHASE','ACTIVE',25);
select pg_temp.ok((pg_temp.mc(pg_temp.id('product'))->>'recipeCostPerPortion')::numeric=10 and (pg_temp.mc(pg_temp.id('product'))->>'suggestedGrossPrice')::numeric=48,'LAST method');
select public.update_menu_product(pg_temp.t(),pg_temp.id('product'),'Menu',pg_temp.id('recipe'),'TRY',0,10,'WEIGHTED_PURCHASE','PASSIVE');
select pg_temp.ok(pg_temp.mc(pg_temp.id('product'))->>'foodCostPct' is null and pg_temp.mc(pg_temp.id('product'))->>'suggestedGrossPrice' is null and (pg_temp.mc(pg_temp.id('product'))->>'contributionMargin')::numeric=-7.5,'zero price null target');
select set_config('test.incomplete_product',public.create_menu_product(pg_temp.t(),'Incomplete menu',pg_temp.id('missing'),'TRY',110,10)::text,true);
select pg_temp.ok(pg_temp.mc(pg_temp.id('incomplete_product'))->>'recipeCostPerPortion' is null and pg_temp.mc(pg_temp.id('incomplete_product'))->>'contributionMargin' is null and pg_temp.mc(pg_temp.id('incomplete_product'))->>'foodCostPct' is null,'incomplete menu');
-- Failed replacement preserves the recipe and its original lines.
select pg_temp.err($q$select public.update_recipe(pg_temp.t(),pg_temp.id('recipe'),'Broken','TRY',2,'ACTIVE',pg_temp.lines(pg_temp.id('passive')))$q$,'22023');
select pg_temp.ok(pg_temp.rc(pg_temp.id('recipe'))->>'name'='Plate updated','failed update atomic');
reset role;
select pg_temp.ok((select count(*)=2 from public.audit_logs where tenant_id=pg_temp.t() and action='RECIPE_CREATED'),'recipe create audit');
select pg_temp.ok((select count(*)=1 from public.audit_logs where tenant_id=pg_temp.t() and action='RECIPE_UPDATED'),'no-change no audit');
select pg_temp.ok(exists(select 1 from public.audit_logs where tenant_id=pg_temp.t() and action='RECIPE_UPDATED' and metadata @> jsonb_build_object('recipeId',pg_temp.id('recipe'),'name','Plate updated','portions',4,'currencyCode','TRY','lineCount',1)),'recipe audit metadata');
select pg_temp.ok((select count(*)=2 from public.audit_logs where tenant_id=pg_temp.t() and action='MENU_PRODUCT_CREATED') and (select count(*)=2 from public.audit_logs where tenant_id=pg_temp.t() and action='MENU_PRODUCT_UPDATED'),'menu audits');
select pg_temp.err($q$delete from public.recipes where id=pg_temp.id('recipe')$q$,'55000');
select pg_temp.err($q$delete from public.menu_products where id=pg_temp.id('product')$q$,'55000');
insert into public.recipes(id,tenant_id,name,currency_code,portions) values('c2222222-9999-4999-8999-111111111111','c2222222-aaaa-4aaa-8aaa-111111111111','Foreign recipe','TRY',1);
set local role authenticated;
select pg_temp.err($q$select public.create_menu_product(pg_temp.t(),'Foreign menu','c2222222-9999-4999-8999-111111111111','TRY',10,0)$q$,'22023','RECIPE_NOT_AVAILABLE');
select pg_temp.err($q$select public.update_recipe(pg_temp.t(),'c2222222-9999-4999-8999-111111111111','Foreign update','TRY',2,'ACTIVE',pg_temp.lines(pg_temp.id('meat')))$q$,'22023','RECIPE_NOT_AVAILABLE');
select pg_temp.err($q$select public.create_menu_product(pg_temp.t(),'Bad target',pg_temp.id('recipe'),'TRY',10,0,'WEIGHTED_PURCHASE',0)$q$,'22023');
select pg_temp.err($q$select public.create_menu_product(pg_temp.t(),'Bad tax',pg_temp.id('recipe'),'TRY',10,100.001)$q$,'22023');
select pg_temp.err($q$select public.create_menu_product(pg_temp.t(),'Bad price',pg_temp.id('recipe'),'TRY',1.001,0)$q$,'22023');
select pg_temp.err($q$select public.create_menu_product(pg_temp.t(),'menu',pg_temp.id('recipe'),'TRY',1,0)$q$,'23505');
select public.update_menu_product(pg_temp.t(),pg_temp.id('product'),'Menu',pg_temp.id('recipe'),'TRY',1,18,'LAST_PURCHASE','ACTIVE',30);
select pg_temp.ok(abs((pg_temp.mc(pg_temp.id('product'))->>'salePriceNet')::numeric-1::numeric/1.18)<0.00000000000001,'no early rounding');
-- Same invoice/date/posted_at: line_no decides last; a real zero previous cost gives null change.
select set_config('test.tie',public.create_purchase_invoice_draft(pg_temp.t(),'c1111111-9999-4999-8999-111111111111','TIE','2026-01-09','TRY',
  jsonb_build_array(jsonb_build_object('description','Free ingredient','unit','KG','quantity',1,'unitPrice',0,'priceIncludesTax',false,'taxRate',0,'inventoryTracking','MAPPED','inventoryItemId',pg_temp.id('meat'),'inventoryPurchaseUnitId',pg_temp.id('kg')),
    jsonb_build_object('description','Paid ingredient','unit','KG','quantity',1,'unitPrice',1,'priceIncludesTax',false,'taxRate',0,'inventoryTracking','MAPPED','inventoryItemId',pg_temp.id('meat'),'inventoryPurchaseUnitId',pg_temp.id('kg'))),'c1111111-7777-4777-8777-111111111111')::text,true);
select public.post_purchase_invoice(pg_temp.t(),pg_temp.id('tie'));
select pg_temp.ok((pg_temp.cost()->'lastPurchase'->>'unitCost')::numeric=.002 and (pg_temp.cost()->'previousPurchase'->>'unitCost')::numeric=0 and pg_temp.cost()->>'priceChangePct' is null,'line order and zero previous');
reset role;
delete from public.role_permissions where role_id='c1111111-5555-4555-8555-111111111111' and permission_key not like 'food-service.%';
set local role authenticated;
select pg_temp.ok(pg_temp.cost()->>'costStatus'='READY','no purchasing/inventory permission needed');
select pg_temp.recipe('Costing only',pg_temp.lines(pg_temp.id('meat')));
select set_config('request.jwt.claim.sub','c1111111-2222-4222-8222-111111111111',true);
select pg_temp.ok(jsonb_array_length(public.get_recipe_costing_overview(pg_temp.t())->'recipes')=3,'reader access');
select pg_temp.err($q$select pg_temp.recipe('Denied',pg_temp.lines(pg_temp.id('meat')))$q$,'42501');
select pg_temp.err($q$select public.update_recipe(pg_temp.t(),pg_temp.id('recipe'),'Denied','TRY',2,'ACTIVE',pg_temp.lines(pg_temp.id('meat')))$q$,'42501');
select pg_temp.err($q$select public.create_menu_product(pg_temp.t(),'Denied',pg_temp.id('recipe'),'TRY',1,0)$q$,'42501');
select pg_temp.err($q$select public.update_menu_product(pg_temp.t(),pg_temp.id('product'),'Denied',pg_temp.id('recipe'),'TRY',1,0,'LAST_PURCHASE','ACTIVE')$q$,'42501');
select pg_temp.err($q$select public.get_inventory_cost_overview('c2222222-aaaa-4aaa-8aaa-111111111111','TRY')$q$,'42501');
select pg_temp.err($q$select public.get_inventory_cost_overview(pg_temp.t(),'TRY','c2222222-7777-4777-8777-111111111111')$q$,'22023');
select pg_temp.err($q$select public.get_inventory_cost_overview(pg_temp.t(),'bad')$q$,'22023');
select pg_temp.err($q$select * from public.recipes$q$,'42501');
select pg_temp.err($q$update public.recipe_lines set quantity_base=1$q$,'42501');
reset role;
update public.tenant_modules set enabled=false where tenant_id=pg_temp.t() and module_key='food-service';
set local role authenticated;
select pg_temp.err($q$select public.get_inventory_cost_overview(pg_temp.t(),'TRY')$q$,'42501');
select pg_temp.err($q$select public.get_recipe_costing_overview(pg_temp.t())$q$,'42501');
select pg_temp.err($q$select public.get_menu_costing_overview(pg_temp.t())$q$,'42501');
select set_config('request.jwt.claim.sub','c1111111-1111-4111-8111-111111111111',true);
select pg_temp.err($q$select pg_temp.recipe('Disabled',pg_temp.lines(pg_temp.id('meat')))$q$,'42501');
select set_config('request.jwt.claim.sub','',true);
select pg_temp.err($q$select public.get_inventory_cost_overview(pg_temp.t(),'TRY')$q$,'42501');
set local role anon;
select pg_temp.err($q$select public.get_menu_costing_overview(pg_temp.t())$q$,'42501');
reset role;
do $$ declare t text; f record; begin
  foreach t in array array['recipes','recipe_lines','menu_products'] loop
    perform pg_temp.ok((select relrowsecurity from pg_class where oid=('public.'||t)::regclass),'RLS');
    perform pg_temp.ok(not has_table_privilege('authenticated','public.'||t,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE') and not has_table_privilege('anon','public.'||t,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE'),'direct access revoked');
  end loop;
  for f in select p.* from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('get_inventory_cost_overview','get_recipe_costing_overview','get_menu_costing_overview','create_recipe','update_recipe','create_menu_product','update_menu_product') loop
    perform pg_temp.ok(f.prosecdef and 'search_path=""'=any(f.proconfig),'secure definer');
    perform pg_temp.ok(not has_function_privilege('anon',f.oid,'EXECUTE') and has_function_privilege('authenticated',f.oid,'EXECUTE'),'RPC grants');
    perform pg_temp.ok(not exists(select 1 from aclexplode(f.proacl) where grantee=0 and privilege_type='EXECUTE'),'PUBLIC revoked');
  end loop;
end $$;
rollback;
do $$ begin if exists(select 1 from auth.users where email like 'costing-%@coost.test') or exists(select 1 from public.tenants where id in ('c1111111-aaaa-4aaa-8aaa-111111111111','c2222222-aaaa-4aaa-8aaa-111111111111')) then raise exception 'RESIDUAL_FIXTURES'; end if; end $$;
select 'PASS - COSTING FOUNDATION' result,(select count(*) from auth.users where email like 'costing-%@coost.test') residual_test_users,
  (select count(*) from public.tenants where id in ('c1111111-aaaa-4aaa-8aaa-111111111111','c2222222-aaaa-4aaa-8aaa-111111111111')) residual_test_tenants;
