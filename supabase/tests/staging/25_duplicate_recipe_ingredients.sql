begin;

-- Test-only: allow authenticated to execute pg_temp helpers created in this
-- transaction. ROLLBACK at the end restores the hardened production defaults.
alter default privileges for role postgres
  grant execute on functions to anon, authenticated;

create function pg_temp.ok(
  v boolean,
  m text
)
returns void
language plpgsql
as $$
begin
  if v is distinct from true then
    raise exception 'ASSERT: %',m;
  end if;
end;
$$;


create function pg_temp.t()
returns uuid
language sql
as $$
  select
    'e2511111-aaaa-4aaa-8aaa-111111111111'::uuid
$$;


create function pg_temp.id(k text)
returns uuid
language sql
as $$
  select current_setting('test.'||k)::uuid
$$;


create function pg_temp.rc(id uuid)
returns jsonb
language sql
as $$
  select r
  from jsonb_array_elements(
    public.get_recipe_costing_overview(
      pg_temp.t()
    )->'recipes'
  ) r
  where r->>'id'=id::text
$$;


create function pg_temp.import_payload()
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'schemaVersion',2,

    'inventoryItems',
      jsonb_build_array(
        jsonb_build_object(
          'sku','IMP-SALT-001',
          'name','Imported Duplicate Salt',
          'baseUnit','GRAM',
          'category','TEST',
          'status','ACTIVE'
        )
      ),

    'recipes',
      jsonb_build_array(
        jsonb_build_object(
          'code','IMP-REC-001',
          'name','Imported Duplicate Ingredient Recipe',
          'category','TEST',
          'currencyCode','TRY',
          'portions',1,
          'status','ACTIVE',
          'yieldQuantity',null,
          'yieldUnit',null,

          'lines',
            jsonb_build_array(
              jsonb_build_object(
                'inventorySku','IMP-SALT-001',
                'quantityBase',10,
                'notes','First stage'
              ),
              jsonb_build_object(
                'inventorySku','IMP-SALT-001',
                'quantityBase',5,
                'notes','Second stage'
              )
            ),

          'subrecipeLines',
            '[]'::jsonb
        )
      ),

    'menuProducts',
      '[]'::jsonb
  )
$$;


------------------------------------------------------------------
-- FIXTURE
------------------------------------------------------------------

insert into auth.users(
  id,
  aud,
  role,
  email
)
values(
  'e2511111-1111-4111-8111-111111111111',
  'authenticated',
  'authenticated',
  'duplicate-recipe-writer@coost.test'
);


insert into public.tenants(
  id,
  name,
  status
)
values(
  pg_temp.t(),
  'Duplicate Recipe Ingredient Test',
  'ACTIVE'
);


insert into public.memberships(
  id,
  tenant_id,
  user_id,
  status
)
values(
  'e2511111-3333-4333-8333-111111111111',
  pg_temp.t(),
  'e2511111-1111-4111-8111-111111111111',
  'ACTIVE'
);


insert into public.roles(
  id,
  tenant_id,
  key,
  name
)
values(
  'e2511111-5555-4555-8555-111111111111',
  pg_temp.t(),
  'owner',
  'Owner'
);


insert into public.membership_roles(
  tenant_id,
  membership_id,
  role_id
)
values(
  pg_temp.t(),
  'e2511111-3333-4333-8333-111111111111',
  'e2511111-5555-4555-8555-111111111111'
);


insert into public.role_permissions(
  tenant_id,
  role_id,
  permission_key
)
select
  pg_temp.t(),
  'e2511111-5555-4555-8555-111111111111',
  unnest(
    array[
      'inventory.read',
      'inventory.write',
      'inventory.adjust',
      'inventory.count',
      'purchasing.read',
      'purchasing.write',
      'suppliers.read',
      'suppliers.write',
      'food-service.costing.read',
      'food-service.costing.write'
    ]
  );


insert into public.tenant_modules(
  tenant_id,
  module_key,
  enabled
)
select
  pg_temp.t(),
  unnest(
    array[
      'inventory',
      'purchasing',
      'suppliers',
      'food-service'
    ]
  ),
  true;


insert into public.locations(
  id,
  tenant_id,
  name,
  status
)
values(
  'e2511111-7777-4777-8777-111111111111',
  pg_temp.t(),
  'Kitchen',
  'ACTIVE'
);


insert into public.suppliers(
  id,
  tenant_id,
  name
)
values(
  'e2511111-9999-4999-8999-111111111111',
  pg_temp.t(),
  'Duplicate Ingredient Supplier'
);


------------------------------------------------------------------
-- NORMAL RECIPE API
------------------------------------------------------------------

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'e2511111-1111-4111-8111-111111111111',
  true
);


select set_config(
  'test.salt',
  public.create_inventory_item(
    pg_temp.t(),
    'Test Salt',
    'GRAM',
    'TST-SALT-001',
    'TEST'
  )::text,
  true
);


select set_config(
  'test.kg',
  public.create_inventory_purchase_unit(
    pg_temp.t(),
    pg_temp.id('salt'),
    'KG',
    1000
  )::text,
  true
);


select set_config(
  'test.invoice',
  public.create_purchase_invoice_draft(
    pg_temp.t(),
    'e2511111-9999-4999-8999-111111111111',
    'DUP-COST-001',
    '2026-09-30',
    'TRY',

    jsonb_build_array(
      jsonb_build_object(
        'description','Test Salt',
        'unit','KG',
        'quantity',1,
        'unitPrice',100,
        'priceIncludesTax',false,
        'taxRate',0,
        'inventoryTracking','MAPPED',
        'inventoryItemId',pg_temp.id('salt'),
        'inventoryPurchaseUnitId',pg_temp.id('kg')
      )
    ),

    'e2511111-7777-4777-8777-111111111111'
  )::text,
  true
);


select public.post_purchase_invoice(
  pg_temp.t(),
  pg_temp.id('invoice')
);


select set_config(
  'test.recipe',

  public.create_recipe(
    pg_temp.t(),
    'Duplicate Ingredient Recipe',
    'TRY',
    1,

    jsonb_build_array(
      jsonb_build_object(
        'inventoryItemId',pg_temp.id('salt'),
        'quantityBase',30,
        'notes','Ana karışım'
      ),
      jsonb_build_object(
        'inventoryItemId',pg_temp.id('salt'),
        'quantityBase',20,
        'notes','Sunum aşaması'
      )
    ),

    'DUP-REC-001',
    'TEST'
  )::text,

  true
);


select pg_temp.ok(
  jsonb_array_length(
    pg_temp.rc(
      pg_temp.id('recipe')
    )->'lines'
  )=2,
  'same ingredient is preserved as two recipe lines'
);


select pg_temp.ok(
  (
    select sum(
      (x->>'quantityBase')::numeric
    )
    from jsonb_array_elements(
      pg_temp.rc(
        pg_temp.id('recipe')
      )->'lines'
    ) x
  )=50,
  'duplicate ingredient quantities remain additive'
);


select pg_temp.ok(
  (
    pg_temp.rc(
      pg_temp.id('recipe')
    )->>'totalLastCost'
  )::numeric=5
  and
  (
    pg_temp.rc(
      pg_temp.id('recipe')
    )->>'totalWeightedCost'
  )::numeric=5,
  'costing includes both repeated ingredient lines'
);


------------------------------------------------------------------
-- UPDATE PATH MUST ALSO PRESERVE DUPLICATES
------------------------------------------------------------------

select public.update_recipe(
  pg_temp.t(),
  pg_temp.id('recipe'),
  'Duplicate Ingredient Recipe Updated',
  'TRY',
  1,
  'ACTIVE',

  jsonb_build_array(
    jsonb_build_object(
      'inventoryItemId',pg_temp.id('salt'),
      'quantityBase',25,
      'notes','Hazırlık'
    ),
    jsonb_build_object(
      'inventoryItemId',pg_temp.id('salt'),
      'quantityBase',25,
      'notes','Final'
    )
  ),

  'DUP-REC-001',
  'TEST'
);


select pg_temp.ok(
  jsonb_array_length(
    pg_temp.rc(
      pg_temp.id('recipe')
    )->'lines'
  )=2
  and
  (
    pg_temp.rc(
      pg_temp.id('recipe')
    )->>'totalLastCost'
  )::numeric=5,
  'recipe update preserves repeated ingredient lines'
);


------------------------------------------------------------------
-- V2 IMPORTER DRY RUN
------------------------------------------------------------------

select set_config(
  'test.import_preview',

  public.import_foodservice_master_data_v2(
    pg_temp.t(),
    pg_temp.import_payload(),
    'DRY_RUN'
  )::text,

  true
);


select pg_temp.ok(
  (
    current_setting(
      'test.import_preview'
    )::jsonb->>'canApply'
  )::boolean
  and
  (
    current_setting(
      'test.import_preview'
    )::jsonb->>'recipeLineCount'
  )::integer=2,
  'v2 dry run accepts repeated inventory SKU'
);


------------------------------------------------------------------
-- V2 IMPORTER APPLY
------------------------------------------------------------------

select set_config(
  'test.import_apply',

  public.import_foodservice_master_data_v2(
    pg_temp.t(),
    pg_temp.import_payload(),
    'APPLY'
  )::text,

  true
);


select pg_temp.ok(
  (
    current_setting(
      'test.import_apply'
    )::jsonb->>'applied'
  )::boolean
  and
  (
    current_setting(
      'test.import_apply'
    )::jsonb->>'recipeLineCount'
  )::integer=2,
  'v2 apply accepts repeated inventory SKU'
);


reset role;


------------------------------------------------------------------
-- DATABASE CONSTRAINTS
------------------------------------------------------------------

select pg_temp.ok(
  not exists(
    select 1
    from pg_constraint c
    join pg_class t
      on t.oid=c.conrelid
    join pg_namespace n
      on n.oid=t.relnamespace
    where n.nspname='public'
      and t.relname='recipe_lines'
      and c.conname=
        'recipe_lines_recipe_id_inventory_item_id_key'
  ),
  'recipe ingredient uniqueness constraint is removed'
);


select pg_temp.ok(
  exists(
    select 1
    from pg_constraint c
    join pg_class t
      on t.oid=c.conrelid
    join pg_namespace n
      on n.oid=t.relnamespace
    where n.nspname='public'
      and t.relname='recipe_lines'
      and c.conname=
        'recipe_lines_recipe_id_line_no_key'
  ),
  'recipe line number uniqueness remains'
);


------------------------------------------------------------------
-- STORED NORMAL RECIPE LINES
------------------------------------------------------------------

select pg_temp.ok(
  (
    select count(*)=2
    from public.recipe_lines
    where tenant_id=pg_temp.t()
      and recipe_id=pg_temp.id('recipe')
  )
  and
  (
    select count(
      distinct inventory_item_id
    )=1
    from public.recipe_lines
    where tenant_id=pg_temp.t()
      and recipe_id=pg_temp.id('recipe')
  )
  and
  (
    select array_agg(
      line_no
      order by line_no
    )=array[1,2]
    from public.recipe_lines
    where tenant_id=pg_temp.t()
      and recipe_id=pg_temp.id('recipe')
  ),
  'same ingredient is stored twice with distinct line numbers'
);


------------------------------------------------------------------
-- STORED IMPORTED RECIPE LINES
------------------------------------------------------------------

select pg_temp.ok(
  (
    select count(*)=2
    from public.recipe_lines rl
    join public.recipes r
      on r.id=rl.recipe_id
     and r.tenant_id=rl.tenant_id
    where rl.tenant_id=pg_temp.t()
      and r.code='IMP-REC-001'
  )
  and
  (
    select count(
      distinct rl.inventory_item_id
    )=1
    from public.recipe_lines rl
    join public.recipes r
      on r.id=rl.recipe_id
     and r.tenant_id=rl.tenant_id
    where rl.tenant_id=pg_temp.t()
      and r.code='IMP-REC-001'
  ),
  'v2 importer stores repeated SKU as separate lines'
);


------------------------------------------------------------------
-- AUDIT
------------------------------------------------------------------

select pg_temp.ok(
  exists(
    select 1
    from public.audit_logs
    where tenant_id=pg_temp.t()
      and action='RECIPE_CREATED'
      and entity_id=pg_temp.id('recipe')
      and metadata @>
        jsonb_build_object(
          'lineCount',2
        )
  ),
  'normal recipe duplicate-line create is audited'
);


select pg_temp.ok(
  exists(
    select 1
    from public.audit_logs
    where tenant_id=pg_temp.t()
      and action='RECIPE_UPDATED'
      and entity_id=pg_temp.id('recipe')
      and metadata @>
        jsonb_build_object(
          'lineCount',2
        )
  ),
  'normal recipe duplicate-line update is audited'
);


select pg_temp.ok(
  exists(
    select 1
    from public.audit_logs
    where tenant_id=pg_temp.t()
      and action=
        'FOODSERVICE_MASTER_DATA_V2_IMPORTED'
      and metadata @>
        jsonb_build_object(
          'schemaVersion',2,
          'inventoryItemCount',1,
          'recipeCount',1,
          'recipeLineCount',2,
          'menuProductCount',0
        )
  ),
  'v2 repeated ingredient import is audited'
);


rollback;


------------------------------------------------------------------
-- RESIDUAL FIXTURE CHECK
------------------------------------------------------------------

do $$
begin
  if exists(
    select 1
    from auth.users
    where email=
      'duplicate-recipe-writer@coost.test'
  )
  or exists(
    select 1
    from public.tenants
    where id=
      'e2511111-aaaa-4aaa-8aaa-111111111111'
  )
  then
    raise exception 'RESIDUAL_FIXTURES';
  end if;
end
$$;


select
  'PASS - DUPLICATE RECIPE INGREDIENTS'
    as result,

  (
    select count(*)
    from auth.users
    where email=
      'duplicate-recipe-writer@coost.test'
  ) as residual_test_users,

  (
    select count(*)
    from public.tenants
    where id=
      'e2511111-aaaa-4aaa-8aaa-111111111111'
  ) as residual_test_tenants;
