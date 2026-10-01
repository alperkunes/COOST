begin;

-- Test-only visibility for structural assertions. ROLLBACK restores hardened RPC-only grants.
grant select on public.recipes, public.recipe_lines, public.recipe_subrecipe_lines, public.recipe_unresolved_lines to authenticated;

alter default privileges for role postgres
  grant execute on functions to anon, authenticated;

create function pg_temp.ok(v boolean, m text)
returns void
language plpgsql
as $$
begin
  if v is distinct from true then
    raise exception 'ASSERT: %',m;
  end if;
end;
$$;

create function pg_temp.err(q text, s text, m text default null)
returns void
language plpgsql
as $$
begin
  execute q;
  raise exception 'EXPECTED_ERROR: %',q;
exception
  when others then
    if sqlstate <> s
      or (m is not null and sqlerrm <> m)
    then
      raise;
    end if;
end;
$$;

create function pg_temp.t()
returns uuid
language sql
as $$
  select '33111111-aaaa-4aaa-8aaa-111111111111'::uuid
$$;

create function pg_temp.payload_v1()
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'schemaVersion',3,
    'source',jsonb_build_object('file','test-v3.json','revision',1),
    'summary',jsonb_build_object(
      'inventoryItems',2,
      'recipes',2,
      'resolvedDirectLines',3,
      'unresolvedDirectLines',1,
      'subrecipeLines',1
    ),
    'inventoryItems',jsonb_build_array(
      jsonb_build_object(
        'sku','V3-A',
        'name','V3 Gram Item',
        'baseUnit','GRAM',
        'category','TEST',
        'status','ACTIVE'
      ),
      jsonb_build_object(
        'sku','V3-B',
        'name','V3 Liquid Item',
        'baseUnit','MILLILITER',
        'category','TEST',
        'status','ACTIVE'
      )
    ),
    'recipes',jsonb_build_array(
      jsonb_build_object(
        'code','V3-CHILD',
        'name','V3 Child',
        'category','ALT REÇETE',
        'currencyCode','TRY',
        'portions',1,
        'status','ACTIVE',
        'lines',jsonb_build_array(
          jsonb_build_object(
            'sourceLineKey','V3-L1',
            'lineNo',1,
            'inventorySku','V3-A',
            'quantityBase',10,
            'notes',null
          )
        ),
        'unresolvedLines','[]'::jsonb,
        'subrecipeLines','[]'::jsonb
      ),
      jsonb_build_object(
        'code','V3-PARENT',
        'name','V3 Parent',
        'category','ANA YEMEK',
        'currencyCode','TRY',
        'portions',1,
        'status','ACTIVE',
        'lines',jsonb_build_array(
          jsonb_build_object(
            'sourceLineKey','V3-L2',
            'lineNo',1,
            'inventorySku','V3-A',
            'quantityBase',1,
            'notes','first use'
          ),
          jsonb_build_object(
            'sourceLineKey','V3-L3',
            'lineNo',2,
            'inventorySku','V3-A',
            'quantityBase',2,
            'notes','second use'
          )
        ),
        'unresolvedLines',jsonb_build_array(
          jsonb_build_object(
            'sourceLineKey','V3-L4',
            'lineNo',3,
            'inventorySku','V3-B',
            'sourceQuantity',3,
            'sourceUnit','GRAM',
            'reason','UNIT_CONVERSION_REQUIRED',
            'notes','density required'
          )
        ),
        'subrecipeLines',jsonb_build_array(
          jsonb_build_object(
            'sourceLineKey','V3-L5',
            'lineNo',4,
            'subrecipeCode','V3-CHILD',
            'quantity',null,
            'unit',null,
            'notes','usage required'
          )
        )
      )
    ),
    'menuProducts','[]'::jsonb
  )
$$;

create function pg_temp.payload_v2()
returns jsonb
language sql
as $$
  select jsonb_set(
    jsonb_set(
      jsonb_set(
        pg_temp.payload_v1(),
        '{source,revision}',
        '2'::jsonb
      ),
      '{recipes,1,name}',
      '"V3 Parent Reconciled"'::jsonb
    ),
    '{recipes,1,unresolvedLines,0,sourceQuantity}',
    '4'::jsonb
  )
$$;


insert into auth.users(id,aud,role,email)
values(
  '33111111-1111-4111-8111-111111111111',
  'authenticated',
  'authenticated',
  'master-v3-writer@coost.test'
);

insert into public.tenants(id,name,status)
values(
  pg_temp.t(),
  'Master Data V3 Test',
  'ACTIVE'
);

insert into public.memberships(id,tenant_id,user_id,status)
values(
  '33111111-2222-4222-8222-111111111111',
  pg_temp.t(),
  '33111111-1111-4111-8111-111111111111',
  'ACTIVE'
);

insert into public.roles(id,tenant_id,key,name)
values(
  '33111111-3333-4333-8333-111111111111',
  pg_temp.t(),
  'writer',
  'Writer'
);

insert into public.membership_roles(tenant_id,membership_id,role_id)
values(
  pg_temp.t(),
  '33111111-2222-4222-8222-111111111111',
  '33111111-3333-4333-8333-111111111111'
);

insert into public.role_permissions(tenant_id,role_id,permission_key)
select
  pg_temp.t(),
  '33111111-3333-4333-8333-111111111111',
  unnest(array[
    'inventory.write',
    'inventory.read',
    'food-service.costing.write',
    'food-service.costing.read'
  ]);

insert into public.tenant_modules(tenant_id,module_key,enabled)
select
  pg_temp.t(),
  unnest(array['inventory','food-service']),
  true;


set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  '33111111-1111-4111-8111-111111111111',
  true
);

select set_config(
  'test.v3.preview',
  public.import_foodservice_master_data_v3(
    pg_temp.t(),
    pg_temp.payload_v1(),
    'DRY_RUN'
  )::text,
  true
);

select pg_temp.ok(
  (
    current_setting('test.v3.preview')::jsonb->>'canApply'
  )::boolean,
  'clean v3 payload can apply'
);

select pg_temp.ok(
  (
    current_setting('test.v3.preview')::jsonb->>'inventoryCreateCount'
  )::integer=2
  and (
    current_setting('test.v3.preview')::jsonb->>'recipeCreateCount'
  )::integer=2
  and (
    current_setting('test.v3.preview')::jsonb->>'resolvedDirectLineCount'
  )::integer=3
  and (
    current_setting('test.v3.preview')::jsonb->>'unresolvedDirectLineCount'
  )::integer=1
  and (
    current_setting('test.v3.preview')::jsonb->>'subrecipeLineCount'
  )::integer=1,
  'v3 dry run reports create and line counts'
);

select public.import_foodservice_master_data_v3(
  pg_temp.t(),
  pg_temp.payload_v1(),
  'APPLY'
);

reset role;

select pg_temp.ok(
  (
    select count(*)
    from public.inventory_items
    where tenant_id=pg_temp.t()
  )=2,
  'v3 apply created inventory'
);

select pg_temp.ok(
  (
    select count(*)
    from public.recipes
    where tenant_id=pg_temp.t()
  )=2
  and (
    select count(*)
    from public.recipe_lines
    where tenant_id=pg_temp.t()
  )=3
  and (
    select count(*)
    from public.recipe_unresolved_lines
    where tenant_id=pg_temp.t()
  )=1
  and (
    select count(*)
    from public.recipe_subrecipe_lines
    where tenant_id=pg_temp.t()
  )=1,
  'v3 apply preserves resolved unresolved and subrecipe rows'
);

select pg_temp.ok(
  (
    select count(*)
    from public.recipe_lines rl
    join public.recipes r
      on r.id=rl.recipe_id
     and r.tenant_id=rl.tenant_id
    join public.inventory_items i
      on i.id=rl.inventory_item_id
     and i.tenant_id=rl.tenant_id
    where r.tenant_id=pg_temp.t()
      and r.code='V3-PARENT'
      and i.sku='V3-A'
  )=2,
  'duplicate ingredient stages are retained'
);

set local role authenticated;

select set_config(
  'test.v3.overview',
  public.get_recipe_costing_overview(
    pg_temp.t(),
    null
  )::text,
  true
);

select pg_temp.ok(
  exists(
    select 1
    from jsonb_array_elements(
      current_setting('test.v3.overview')::jsonb->'recipes'
    ) recipe
    where recipe->>'code'='V3-PARENT'
      and (recipe->>'costingComplete')::boolean=false
      and (recipe->>'missingConversionItemCount')::integer=1
      and jsonb_array_length(recipe->'unresolvedLines')=1
      and recipe->'unresolvedLines'->0->>'sourceUnit'='GRAM'
      and recipe->'unresolvedLines'->0->>'baseUnit'='MILLILITER'
  ),
  'unresolved conversion is visible and never costed as zero'
);

reset role;

select pg_temp.err(
  $q$
    update public.inventory_items
    set status='PASSIVE'
    where tenant_id='33111111-aaaa-4aaa-8aaa-111111111111'
      and sku='V3-B'
  $q$,
  '22023',
  'INVENTORY_ITEM_IN_ACTIVE_RECIPE'
);

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  '33111111-1111-4111-8111-111111111111',
  true
);

select set_config(
  'test.v3.preview2',
  public.import_foodservice_master_data_v3(
    pg_temp.t(),
    pg_temp.payload_v2(),
    'DRY_RUN'
  )::text,
  true
);

select pg_temp.ok(
  (
    current_setting('test.v3.preview2')::jsonb->>'inventoryCreateCount'
  )::integer=0
  and (
    current_setting('test.v3.preview2')::jsonb->>'inventoryReconcileCount'
  )::integer=2
  and (
    current_setting('test.v3.preview2')::jsonb->>'recipeCreateCount'
  )::integer=0
  and (
    current_setting('test.v3.preview2')::jsonb->>'recipeReconcileCount'
  )::integer=2,
  'second dry run is reconcile not duplicate creation'
);

select public.import_foodservice_master_data_v3(
  pg_temp.t(),
  pg_temp.payload_v2(),
  'APPLY'
);

reset role;

select pg_temp.ok(
  (
    select name='V3 Parent Reconciled'
    from public.recipes
    where tenant_id=pg_temp.t()
      and code='V3-PARENT'
  ),
  'existing recipe identity is reconciled'
);

select pg_temp.ok(
  (
    select source_quantity=4
    from public.recipe_unresolved_lines ul
    join public.recipes r
      on r.id=ul.recipe_id
     and r.tenant_id=ul.tenant_id
    where r.tenant_id=pg_temp.t()
      and r.code='V3-PARENT'
  ),
  'unresolved source quantity is reconciled exactly'
);

select pg_temp.ok(
  (
    select count(*)
    from public.recipe_lines rl
    join public.recipes r
      on r.id=rl.recipe_id
     and r.tenant_id=rl.tenant_id
    where r.tenant_id=pg_temp.t()
      and r.code='V3-PARENT'
  )=2
  and (
    select count(*)
    from public.recipe_unresolved_lines ul
    join public.recipes r
      on r.id=ul.recipe_id
     and r.tenant_id=ul.tenant_id
    where r.tenant_id=pg_temp.t()
      and r.code='V3-PARENT'
  )=1
  and (
    select count(*)
    from public.recipe_subrecipe_lines sl
    join public.recipes r
      on r.id=sl.recipe_id
     and r.tenant_id=sl.tenant_id
    where r.tenant_id=pg_temp.t()
      and r.code='V3-PARENT'
  )=1,
  'reconcile replaces recipe graph without duplicate residue'
);

reset role;

select pg_temp.err(
  'truncate table public.recipe_unresolved_lines',
  '55000',
  'COSTING_MASTER_DATA_TRUNCATE_FORBIDDEN'
);

rollback;

do $$
begin
  if exists(
    select 1
    from auth.users
    where id='33111111-1111-4111-8111-111111111111'
  )
  or exists(
    select 1
    from public.tenants
    where id='33111111-aaaa-4aaa-8aaa-111111111111'
  )
  then
    raise exception 'MASTER_DATA_V3_TEST_RESIDUALS';
  end if;
end
$$;

select 'PASS - FOODSERVICE MASTER DATA V3 RECONCILE' as result;
