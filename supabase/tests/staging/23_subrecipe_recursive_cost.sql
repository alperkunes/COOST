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


create function pg_temp.err(
  q text,
  s text,
  m text default null
)
returns void
language plpgsql
as $$
begin
  execute q;

  raise exception
    'EXPECTED_ERROR: %',
    q;

exception
  when others then
    if sqlstate <> s
      or (
        m is not null
        and sqlerrm <> m
      )
    then
      raise;
    end if;
end;
$$;


create function pg_temp.t()
returns uuid
language sql
as $$
  select
    'f2311111-aaaa-4aaa-8aaa-111111111111'::uuid
$$;


create function pg_temp.id(k text)
returns uuid
language sql
as $$
  select
    current_setting(
      'test.' || k
    )::uuid
$$;


create function pg_temp.lines(
  item uuid,
  q numeric
)
returns jsonb
language sql
as $$
  select jsonb_build_array(
    jsonb_build_object(
      'inventoryItemId',
        item,
      'quantityBase',
        q,
      'notes',
        'Test'
    )
  )
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


create function pg_temp.buy(
  invoice_no text,
  invoice_date date,
  item uuid,
  purchase_unit uuid,
  price numeric
)
returns uuid
language plpgsql
as $$
declare
  v_invoice uuid;
begin
  v_invoice :=
    public.create_purchase_invoice_draft(
      pg_temp.t(),
      'f2311111-9999-4999-8999-111111111111',
      invoice_no,
      invoice_date,
      'TRY',
      jsonb_build_array(
        jsonb_build_object(
          'description',
            'Recursive cost purchase',
          'unit',
            'KG',
          'quantity',
            1,
          'unitPrice',
            price,
          'priceIncludesTax',
            false,
          'taxRate',
            0,
          'inventoryTracking',
            'MAPPED',
          'inventoryItemId',
            item,
          'inventoryPurchaseUnitId',
            purchase_unit
        )
      ),
      'f2311111-7777-4777-8777-111111111111'
    );

  perform public.post_purchase_invoice(
    pg_temp.t(),
    v_invoice
  );

  return v_invoice;
end;
$$;


------------------------------------------------------------------
-- Fixture
------------------------------------------------------------------

insert into auth.users(
  id,
  aud,
  role,
  email
)
values
(
  'f2311111-1111-4111-8111-111111111111',
  'authenticated',
  'authenticated',
  'subrecipe-writer@coost.test'
),
(
  'f2311111-2222-4222-8222-111111111111',
  'authenticated',
  'authenticated',
  'subrecipe-reader@coost.test'
);


insert into public.tenants(
  id,
  name,
  status
)
values(
  pg_temp.t(),
  'Subrecipe Cost Test',
  'ACTIVE'
);


insert into public.memberships(
  id,
  tenant_id,
  user_id,
  status
)
values
(
  'f2311111-3333-4333-8333-111111111111',
  pg_temp.t(),
  'f2311111-1111-4111-8111-111111111111',
  'ACTIVE'
),
(
  'f2311111-4444-4444-8444-111111111111',
  pg_temp.t(),
  'f2311111-2222-4222-8222-111111111111',
  'ACTIVE'
);


insert into public.roles(
  id,
  tenant_id,
  key,
  name
)
values
(
  'f2311111-5555-4555-8555-111111111111',
  pg_temp.t(),
  'writer',
  'Writer'
),
(
  'f2311111-6666-4666-8666-111111111111',
  pg_temp.t(),
  'reader',
  'Reader'
);


insert into public.membership_roles(
  tenant_id,
  membership_id,
  role_id
)
values
(
  pg_temp.t(),
  'f2311111-3333-4333-8333-111111111111',
  'f2311111-5555-4555-8555-111111111111'
),
(
  pg_temp.t(),
  'f2311111-4444-4444-8444-111111111111',
  'f2311111-6666-4666-8666-111111111111'
);


insert into public.role_permissions(
  tenant_id,
  role_id,
  permission_key
)
select
  pg_temp.t(),
  'f2311111-5555-4555-8555-111111111111',
  unnest(
    array[
      'food-service.costing.read',
      'food-service.costing.write',
      'inventory.write',
      'inventory.adjust',
      'purchasing.write'
    ]
  );


insert into public.role_permissions(
  tenant_id,
  role_id,
  permission_key
)
values(
  pg_temp.t(),
  'f2311111-6666-4666-8666-111111111111',
  'food-service.costing.read'
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
      'food-service',
      'inventory',
      'purchasing',
      'suppliers'
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
  'f2311111-7777-4777-8777-111111111111',
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
  'f2311111-9999-4999-8999-111111111111',
  pg_temp.t(),
  'Recursive Cost Supplier'
);


------------------------------------------------------------------
-- Writer context
------------------------------------------------------------------

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'f2311111-1111-4111-8111-111111111111',
  true
);


------------------------------------------------------------------
-- Inventory + purchase costs
------------------------------------------------------------------

select set_config(
  'test.child_item',
  public.create_inventory_item(
    pg_temp.t(),
    'Child Ingredient',
    'GRAM',
    'SUB-CHILD'
  )::text,
  true
);


select set_config(
  'test.direct_item',
  public.create_inventory_item(
    pg_temp.t(),
    'Direct Ingredient',
    'GRAM',
    'SUB-DIRECT'
  )::text,
  true
);


select set_config(
  'test.child_kg',
  public.create_inventory_purchase_unit(
    pg_temp.t(),
    pg_temp.id('child_item'),
    'KG',
    1000
  )::text,
  true
);


select set_config(
  'test.direct_kg',
  public.create_inventory_purchase_unit(
    pg_temp.t(),
    pg_temp.id('direct_item'),
    'KG',
    1000
  )::text,
  true
);


-- Child ingredient = 100 TRY / 1000 g = 0.10 TRY/g
select pg_temp.buy(
  'SUB-CHILD-1',
  '2026-09-01',
  pg_temp.id('child_item'),
  pg_temp.id('child_kg'),
  100
);


-- Direct ingredient = 200 TRY / 1000 g = 0.20 TRY/g
select pg_temp.buy(
  'SUB-DIRECT-1',
  '2026-09-01',
  pg_temp.id('direct_item'),
  pg_temp.id('direct_kg'),
  200
);


------------------------------------------------------------------
-- Child recipe:
-- 100 g child ingredient = 10 TRY batch cost
-- batch yield = 200 g
-- cost per produced g = 0.05 TRY
------------------------------------------------------------------

select set_config(
  'test.child_recipe',
  public.create_recipe(
    pg_temp.t(),
    'Test Sauce',
    'TRY',
    1,
    pg_temp.lines(
      pg_temp.id('child_item'),
      100
    ),
    'SUB-R001',
    'ALT REÇETE'
  )::text,
  true
);


select public.update_recipe_yield(
  pg_temp.t(),
  pg_temp.id('child_recipe'),
  200,
  'GRAM'
);


select pg_temp.ok(
  (
    pg_temp.rc(
      pg_temp.id('child_recipe')
    )->>'yieldQuantity'
  )::numeric=200
  and
  pg_temp.rc(
    pg_temp.id('child_recipe')
  )->>'yieldUnit'='GRAM',
  'child yield is exposed by costing overview'
);


------------------------------------------------------------------
-- Parent recipe:
-- 10 g direct ingredient = 2 TRY
-- 50 g child recipe = 50 / 200 * 10 = 2.5 TRY
-- total = 4.5 TRY
------------------------------------------------------------------

select set_config(
  'test.parent_recipe',
  public.create_recipe(
    pg_temp.t(),
    'Parent Plate',
    'TRY',
    1,
    pg_temp.lines(
      pg_temp.id('direct_item'),
      10
    ),
    'SUB-R002',
    'ANA YEMEK'
  )::text,
  true
);


select public.replace_recipe_subrecipe_lines(
  pg_temp.t(),
  pg_temp.id('parent_recipe'),
  jsonb_build_array(
    jsonb_build_object(
      'subrecipeId',
        pg_temp.id('child_recipe'),
      'quantity',
        50,
      'unit',
        'GRAM',
      'notes',
        '50 g sauce'
    )
  )
);


select pg_temp.ok(
  (
    pg_temp.rc(
      pg_temp.id('parent_recipe')
    )->>'costingComplete'
  )::boolean,
  'recursive parent cost is complete'
);


select pg_temp.ok(
  (
    pg_temp.rc(
      pg_temp.id('parent_recipe')
    )->>'totalLastCost'
  )::numeric=4.5,
  'recursive last cost is correct'
);


select pg_temp.ok(
  (
    pg_temp.rc(
      pg_temp.id('parent_recipe')
    )->>'totalWeightedCost'
  )::numeric=4.5,
  'recursive weighted cost is correct'
);


select pg_temp.ok(
  (
    pg_temp.rc(
      pg_temp.id('parent_recipe')
    )->>'missingSubrecipeCostCount'
  )::integer=0
  and
  (
    pg_temp.rc(
      pg_temp.id('parent_recipe')
    )->>'subrecipeLineCount'
  )::integer=1,
  'recursive line counts are correct'
);


select pg_temp.ok(
  (
    pg_temp.rc(
      pg_temp.id('parent_recipe')
    )->'subrecipeLines'->0
      ->>'costStatus'
  )='READY'
  and
  (
    pg_temp.rc(
      pg_temp.id('parent_recipe')
    )->'subrecipeLines'->0
      ->>'lastLineCost'
  )::numeric=2.5,
  'subrecipe contribution is visible'
);


------------------------------------------------------------------
-- Child purchase cost changes:
--
-- second purchase 300 TRY/kg
-- last child unit cost = 0.30 TRY/g
-- weighted child unit cost = 0.20 TRY/g
--
-- child batch:
-- last = 30 TRY
-- weighted = 20 TRY
--
-- parent:
-- direct = 2 TRY
-- child last = 7.5
-- child weighted = 5
--
-- parent last = 9.5
-- parent weighted = 7
--
-- No recipe edit should be needed.
------------------------------------------------------------------

select pg_temp.buy(
  'SUB-CHILD-2',
  '2026-09-02',
  pg_temp.id('child_item'),
  pg_temp.id('child_kg'),
  300
);


select pg_temp.ok(
  (
    pg_temp.rc(
      pg_temp.id('child_recipe')
    )->>'totalLastCost'
  )::numeric=30
  and
  (
    pg_temp.rc(
      pg_temp.id('child_recipe')
    )->>'totalWeightedCost'
  )::numeric=20,
  'child recipe reacts to new purchase costs'
);


select pg_temp.ok(
  (
    pg_temp.rc(
      pg_temp.id('parent_recipe')
    )->>'totalLastCost'
  )::numeric=9.5
  and
  (
    pg_temp.rc(
      pg_temp.id('parent_recipe')
    )->>'totalWeightedCost'
  )::numeric=7,
  'parent automatically inherits changed child cost'
);


------------------------------------------------------------------
-- Missing child usage quantity is accepted as incomplete data.
-- It must NEVER silently calculate zero cost.
------------------------------------------------------------------

select set_config(
  'test.missing_usage_parent',
  public.create_recipe(
    pg_temp.t(),
    'Missing Usage Parent',
    'TRY',
    1,
    pg_temp.lines(
      pg_temp.id('direct_item'),
      1
    ),
    'SUB-R003',
    'TEST'
  )::text,
  true
);


select public.replace_recipe_subrecipe_lines(
  pg_temp.t(),
  pg_temp.id('missing_usage_parent'),
  jsonb_build_array(
    jsonb_build_object(
      'subrecipeId',
        pg_temp.id('child_recipe'),
      'quantity',
        null,
      'unit',
        null,
      'notes',
        'Source quantity missing'
    )
  )
);


select pg_temp.ok(
  not (
    pg_temp.rc(
      pg_temp.id('missing_usage_parent')
    )->>'costingComplete'
  )::boolean
  and
  pg_temp.rc(
    pg_temp.id('missing_usage_parent')
  )->>'totalLastCost' is null
  and
  (
    pg_temp.rc(
      pg_temp.id('missing_usage_parent')
    )->>'missingSubrecipeCostCount'
  )::integer=1
  and
  (
    pg_temp.rc(
      pg_temp.id('missing_usage_parent')
    )->'subrecipeLines'->0
      ->>'costStatus'
  )='MISSING_USAGE_QUANTITY',
  'missing usage quantity produces incomplete cost'
);


------------------------------------------------------------------
-- Missing child yield is also incomplete, never zero.
------------------------------------------------------------------

select set_config(
  'test.no_yield_child',
  public.create_recipe(
    pg_temp.t(),
    'No Yield Child',
    'TRY',
    1,
    pg_temp.lines(
      pg_temp.id('child_item'),
      10
    ),
    'SUB-R004',
    'ALT REÇETE'
  )::text,
  true
);


select set_config(
  'test.no_yield_parent',
  public.create_recipe(
    pg_temp.t(),
    'No Yield Parent',
    'TRY',
    1,
    pg_temp.lines(
      pg_temp.id('direct_item'),
      1
    ),
    'SUB-R005',
    'TEST'
  )::text,
  true
);


select public.replace_recipe_subrecipe_lines(
  pg_temp.t(),
  pg_temp.id('no_yield_parent'),
  jsonb_build_array(
    jsonb_build_object(
      'subrecipeId',
        pg_temp.id('no_yield_child'),
      'quantity',
        50,
      'unit',
        'GRAM'
    )
  )
);


select pg_temp.ok(
  not (
    pg_temp.rc(
      pg_temp.id('no_yield_parent')
    )->>'costingComplete'
  )::boolean
  and
  pg_temp.rc(
    pg_temp.id('no_yield_parent')
  )->>'totalWeightedCost' is null
  and
  (
    pg_temp.rc(
      pg_temp.id('no_yield_parent')
    )->'subrecipeLines'->0
      ->>'costStatus'
  )='MISSING_CHILD_YIELD',
  'missing child yield produces incomplete cost'
);


------------------------------------------------------------------
-- Unit mismatch protection
------------------------------------------------------------------

select set_config(
  'test.cycle_a',
  public.create_recipe(
    pg_temp.t(),
    'Cycle A',
    'TRY',
    1,
    pg_temp.lines(
      pg_temp.id('direct_item'),
      1
    ),
    'SUB-R006',
    'ALT REÇETE'
  )::text,
  true
);


select set_config(
  'test.cycle_b',
  public.create_recipe(
    pg_temp.t(),
    'Cycle B',
    'TRY',
    1,
    pg_temp.lines(
      pg_temp.id('direct_item'),
      1
    ),
    'SUB-R007',
    'ALT REÇETE'
  )::text,
  true
);


select public.update_recipe_yield(
  pg_temp.t(),
  pg_temp.id('cycle_a'),
  1,
  'EACH'
);


select public.update_recipe_yield(
  pg_temp.t(),
  pg_temp.id('cycle_b'),
  1,
  'EACH'
);


select pg_temp.err(
  $q$
    select public.replace_recipe_subrecipe_lines(
      pg_temp.t(),
      pg_temp.id('cycle_a'),
      jsonb_build_array(
        jsonb_build_object(
          'subrecipeId',
            pg_temp.id('cycle_b'),
          'quantity',
            1,
          'unit',
            'GRAM'
        )
      )
    )
  $q$,
  '22023',
  'RECIPE_SUBRECIPE_UNIT_MISMATCH'
);


reset role;

select pg_temp.ok(
  not exists(
    select 1
    from public.recipe_subrecipe_lines
    where tenant_id=pg_temp.t()
      and recipe_id=
        pg_temp.id('cycle_a')
  ),
  'failed unit mismatch writes nothing'
);

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'f2311111-1111-4111-8111-111111111111',
  true
);


------------------------------------------------------------------
-- A -> B is allowed
------------------------------------------------------------------

select public.replace_recipe_subrecipe_lines(
  pg_temp.t(),
  pg_temp.id('cycle_a'),
  jsonb_build_array(
    jsonb_build_object(
      'subrecipeId',
        pg_temp.id('cycle_b'),
      'quantity',
        1,
      'unit',
        'EACH'
    )
  )
);


reset role;

select pg_temp.ok(
  (
    select count(*)=1
    from public.recipe_subrecipe_lines
    where tenant_id=pg_temp.t()
      and recipe_id=
        pg_temp.id('cycle_a')
      and subrecipe_id=
        pg_temp.id('cycle_b')
  ),
  'one-way dependency is accepted'
);

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'f2311111-1111-4111-8111-111111111111',
  true
);


------------------------------------------------------------------
-- B -> A would create A -> B -> A and must fail atomically.
------------------------------------------------------------------

select pg_temp.err(
  $q$
    select public.replace_recipe_subrecipe_lines(
      pg_temp.t(),
      pg_temp.id('cycle_b'),
      jsonb_build_array(
        jsonb_build_object(
          'subrecipeId',
            pg_temp.id('cycle_a'),
          'quantity',
            1,
          'unit',
            'EACH'
        )
      )
    )
  $q$,
  '22023',
  'RECIPE_DEPENDENCY_CYCLE'
);


reset role;

select pg_temp.ok(
  not exists(
    select 1
    from public.recipe_subrecipe_lines
    where tenant_id=pg_temp.t()
      and recipe_id=
        pg_temp.id('cycle_b')
  ),
  'failed cycle replacement is atomic'
);

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'f2311111-1111-4111-8111-111111111111',
  true
);


------------------------------------------------------------------
-- Used child cannot silently change to incompatible yield unit.
------------------------------------------------------------------

select pg_temp.err(
  $q$
    select public.update_recipe_yield(
      pg_temp.t(),
      pg_temp.id('cycle_b'),
      1,
      'GRAM'
    )
  $q$,
  '22023',
  'RECIPE_YIELD_UNIT_IN_USE'
);


------------------------------------------------------------------
-- Used child cannot be made passive through existing recipe RPC.
------------------------------------------------------------------

select pg_temp.err(
  $q$
    select public.update_recipe(
      pg_temp.t(),
      pg_temp.id('cycle_b'),
      'Cycle B',
      'TRY',
      1,
      'PASSIVE',
      pg_temp.lines(
        pg_temp.id('direct_item'),
        1
      ),
      'SUB-R007',
      'ALT REÇETE'
    )
  $q$,
  '22023',
  'RECIPE_SUBRECIPE_IN_USE'
);


------------------------------------------------------------------
-- Audit
------------------------------------------------------------------

reset role;


select pg_temp.ok(
  (
    select count(*) = 3
    from public.audit_logs
    where tenant_id=pg_temp.t()
      and action=
        'RECIPE_YIELD_UPDATED'
  ),
  'successful yield changes are audited exactly once'
);


select pg_temp.ok(
  exists(
    select 1
    from public.audit_logs
    where tenant_id=pg_temp.t()
      and action=
        'RECIPE_SUBRECIPES_REPLACED'
      and entity_id=
        pg_temp.id('parent_recipe')
      and metadata @>
        jsonb_build_object(
          'lineCount',1,
          'resolvedLineCount',1,
          'unresolvedLineCount',0
        )
  ),
  'resolved subrecipe replacement is audited'
);


select pg_temp.ok(
  exists(
    select 1
    from public.audit_logs
    where tenant_id=pg_temp.t()
      and action=
        'RECIPE_SUBRECIPES_REPLACED'
      and entity_id=
        pg_temp.id('missing_usage_parent')
      and metadata @>
        jsonb_build_object(
          'lineCount',1,
          'resolvedLineCount',0,
          'unresolvedLineCount',1
        )
  ),
  'unresolved source quantity is audited explicitly'
);


------------------------------------------------------------------
-- Read-only user
------------------------------------------------------------------

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'f2311111-2222-4222-8222-111111111111',
  true
);


select pg_temp.ok(
  jsonb_array_length(
    public.get_recipe_costing_overview(
      pg_temp.t()
    )->'recipes'
  ) >= 7,
  'read-only user can read recursive costing'
);


select pg_temp.err(
  $q$
    select public.update_recipe_yield(
      pg_temp.t(),
      pg_temp.id('child_recipe'),
      250,
      'GRAM'
    )
  $q$,
  '42501'
);


select pg_temp.err(
  $q$
    select public.replace_recipe_subrecipe_lines(
      pg_temp.t(),
      pg_temp.id('parent_recipe'),
      '[]'::jsonb
    )
  $q$,
  '42501'
);


------------------------------------------------------------------
-- Security
------------------------------------------------------------------

reset role;


select pg_temp.ok(
  (
    select relrowsecurity
    from pg_class
    where oid=
      'public.recipe_subrecipe_lines'::regclass
  ),
  'subrecipe table has RLS enabled'
);


select pg_temp.ok(
  not has_table_privilege(
    'authenticated',
    'public.recipe_subrecipe_lines',
    'SELECT,INSERT,UPDATE,DELETE,TRUNCATE'
  )
  and
  not has_table_privilege(
    'anon',
    'public.recipe_subrecipe_lines',
    'SELECT,INSERT,UPDATE,DELETE,TRUNCATE'
  ),
  'direct subrecipe table access is revoked'
);


do $$
declare
  f record;
begin
  for f in
    select p.*
    from pg_proc p
    join pg_namespace n
      on n.oid=p.pronamespace
    where n.nspname='public'
      and p.proname in (
        'update_recipe_yield',
        'replace_recipe_subrecipe_lines'
      )
  loop
    perform pg_temp.ok(
      f.prosecdef
      and 'search_path=""'=any(
        f.proconfig
      ),
      'public subrecipe RPC uses secure definer'
    );

    perform pg_temp.ok(
      not has_function_privilege(
        'anon',
        f.oid,
        'EXECUTE'
      )
      and
      has_function_privilege(
        'authenticated',
        f.oid,
        'EXECUTE'
      ),
      'subrecipe RPC grants are restricted'
    );

    perform pg_temp.ok(
      not exists(
        select 1
        from aclexplode(
          f.proacl
        )
        where grantee=0
          and privilege_type='EXECUTE'
      ),
      'PUBLIC execute is revoked'
    );
  end loop;
end
$$;


do $$
declare
  f record;
begin
  for f in
    select p.*
    from pg_proc p
    join pg_namespace n
      on n.oid=p.pronamespace
    where n.nspname='private'
      and p.proname in (
        'recipe_dependency_would_cycle',
        'validate_recipe_subrecipe_line',
        'guard_recipe_dependency_update',
        'recipe_cost_node'
      )
  loop
    perform pg_temp.ok(
      not has_function_privilege(
        'authenticated',
        f.oid,
        'EXECUTE'
      )
      and
      not has_function_privilege(
        'anon',
        f.oid,
        'EXECUTE'
      ),
      'private recursive helper is not executable by clients'
    );
  end loop;
end
$$;


rollback;


------------------------------------------------------------------
-- No fixture residue
------------------------------------------------------------------

do $$
begin
  if exists(
    select 1
    from auth.users
    where email like
      'subrecipe-%@coost.test'
  )
  or exists(
    select 1
    from public.tenants
    where id=
      'f2311111-aaaa-4aaa-8aaa-111111111111'
  )
  then
    raise exception
      'RESIDUAL_FIXTURES';
  end if;
end
$$;


select
  'PASS - SUBRECIPE RECURSIVE COST' result,

  (
    select count(*)
    from auth.users
    where email like
      'subrecipe-%@coost.test'
  )
    residual_test_users,

  (
    select count(*)
    from public.tenants
    where id=
      'f2311111-aaaa-4aaa-8aaa-111111111111'
  )
    residual_test_tenants;
