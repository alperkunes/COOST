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
    'e2411111-aaaa-4aaa-8aaa-111111111111'::uuid
$$;


create function pg_temp.payload()
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'schemaVersion',2,

    'source',
      jsonb_build_object(
        'file',
        'test-master-data-v2.json',
        'status',
        'TEST'
      ),

    'summary',
      jsonb_build_object(
        'inventoryItems',3,
        'recipes',5,
        'recipeLines',5,
        'subrecipeLines',3
      ),

    'inventoryItems',
      jsonb_build_array(
        jsonb_build_object(
          'sku','MLZ001',
          'name','Test Child Ingredient',
          'baseUnit','GRAM',
          'category','TEST',
          'status','ACTIVE'
        ),

        jsonb_build_object(
          'sku','MLZ002',
          'name','Test Oil',
          'baseUnit','MILLILITER',
          'category','TEST',
          'status','ACTIVE'
        ),

        jsonb_build_object(
          'sku','MLZ003',
          'name','Test Greens',
          'baseUnit','GRAM',
          'category','TEST',
          'status','ACTIVE'
        )
      ),

    'recipes',
      jsonb_build_array(

        jsonb_build_object(
          'code','UR001',
          'name','Test Child Sauce',
          'category','ALT REÇETE / SOS',
          'currencyCode','TRY',
          'portions',1,
          'status','ACTIVE',
          'yieldQuantity',200,
          'yieldUnit','GRAM',

          'lines',
            jsonb_build_array(
              jsonb_build_object(
                'inventorySku','MLZ001',
                'quantityBase',100,
                'notes',null
              )
            ),

          'subrecipeLines',
            '[]'::jsonb
        ),

        jsonb_build_object(
          'code','UR002',
          'name','Test Parent Resolved',
          'category','ANA YEMEK',
          'currencyCode','TRY',
          'portions',1,
          'status','ACTIVE',
          'yieldQuantity',null,
          'yieldUnit',null,

          'lines',
            jsonb_build_array(
              jsonb_build_object(
                'inventorySku','MLZ002',
                'quantityBase',10,
                'notes',null
              )
            ),

          'subrecipeLines',
            jsonb_build_array(
              jsonb_build_object(
                'subrecipeCode','UR001',
                'quantity',50,
                'unit','GRAM',
                'notes','Resolved child usage'
              )
            )
        ),

        jsonb_build_object(
          'code','UR003',
          'name','Test Child Unknown Yield',
          'category','ALT REÇETE',
          'currencyCode','TRY',
          'portions',1,
          'status','ACTIVE',
          'yieldQuantity',null,
          'yieldUnit',null,

          'lines',
            jsonb_build_array(
              jsonb_build_object(
                'inventorySku','MLZ001',
                'quantityBase',20,
                'notes',null
              )
            ),

          'subrecipeLines',
            '[]'::jsonb
        ),

        jsonb_build_object(
          'code','UR004',
          'name','Test Parent Unresolved Usage',
          'category','SALATA',
          'currencyCode','TRY',
          'portions',1,
          'status','ACTIVE',
          'yieldQuantity',null,
          'yieldUnit',null,

          'lines',
            jsonb_build_array(
              jsonb_build_object(
                'inventorySku','MLZ003',
                'quantityBase',30,
                'notes',null
              )
            ),

          'subrecipeLines',
            jsonb_build_array(
              jsonb_build_object(
                'subrecipeCode','UR003',
                'quantity',null,
                'unit',null,
                'notes','Usage quantity unknown'
              )
            )
        ),

        jsonb_build_object(
          'code','UR005',
          'name','Test Parent Missing Child Yield',
          'category','SALATA',
          'currencyCode','TRY',
          'portions',1,
          'status','ACTIVE',
          'yieldQuantity',null,
          'yieldUnit',null,

          'lines',
            jsonb_build_array(
              jsonb_build_object(
                'inventorySku','MLZ003',
                'quantityBase',15,
                'notes',null
              )
            ),

          'subrecipeLines',
            jsonb_build_array(
              jsonb_build_object(
                'subrecipeCode','UR003',
                'quantity',5,
                'unit','GRAM',
                'notes','Known usage but child yield unknown'
              )
            )
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
values
(
  'e2411111-1111-4111-8111-111111111111',
  'authenticated',
  'authenticated',
  'master-v2-writer@coost.test'
),
(
  'e2411111-2222-4222-8222-111111111111',
  'authenticated',
  'authenticated',
  'master-v2-reader@coost.test'
);


insert into public.tenants(
  id,
  name,
  status
)
values(
  pg_temp.t(),
  'Master Data V2 Test',
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
  'e2411111-3333-4333-8333-111111111111',
  pg_temp.t(),
  'e2411111-1111-4111-8111-111111111111',
  'ACTIVE'
),
(
  'e2411111-4444-4444-8444-111111111111',
  pg_temp.t(),
  'e2411111-2222-4222-8222-111111111111',
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
  'e2411111-5555-4555-8555-111111111111',
  pg_temp.t(),
  'writer',
  'Writer'
),
(
  'e2411111-6666-4666-8666-111111111111',
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
  'e2411111-3333-4333-8333-111111111111',
  'e2411111-5555-4555-8555-111111111111'
),
(
  pg_temp.t(),
  'e2411111-4444-4444-8444-111111111111',
  'e2411111-6666-4666-8666-111111111111'
);


insert into public.role_permissions(
  tenant_id,
  role_id,
  permission_key
)
select
  pg_temp.t(),
  'e2411111-5555-4555-8555-111111111111',
  unnest(
    array[
      'inventory.write',
      'food-service.costing.write'
    ]
  );


insert into public.role_permissions(
  tenant_id,
  role_id,
  permission_key
)
values(
  pg_temp.t(),
  'e2411111-6666-4666-8666-111111111111',
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
      'inventory',
      'food-service'
    ]
  ),
  true;


------------------------------------------------------------------
-- DRY RUN
------------------------------------------------------------------

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'e2411111-1111-4111-8111-111111111111',
  true
);


select set_config(
  'test.master_v2_preview',
  public.import_foodservice_master_data_v2(
    pg_temp.t(),
    pg_temp.payload(),
    'DRY_RUN'
  )::text,
  true
);


select pg_temp.ok(
  (
    current_setting(
      'test.master_v2_preview'
    )::jsonb->>'canApply'
  )::boolean,
  'clean v2 payload can apply'
);


select pg_temp.ok(
  (
    current_setting(
      'test.master_v2_preview'
    )::jsonb->>'inventoryItemCount'
  )::integer=3
  and
  (
    current_setting(
      'test.master_v2_preview'
    )::jsonb->>'recipeCount'
  )::integer=5
  and
  (
    current_setting(
      'test.master_v2_preview'
    )::jsonb->>'recipeLineCount'
  )::integer=5,
  'v2 dry run reports base counts'
);


select pg_temp.ok(
  (
    current_setting(
      'test.master_v2_preview'
    )::jsonb->>'subrecipeLineCount'
  )::integer=3
  and
  (
    current_setting(
      'test.master_v2_preview'
    )::jsonb->>'unresolvedSubrecipeLineCount'
  )::integer=1,
  'v2 dry run reports subrecipe counts'
);


select pg_temp.ok(
  (
    current_setting(
      'test.master_v2_preview'
    )::jsonb->>'yieldRecipeCount'
  )::integer=1
  and
  (
    current_setting(
      'test.master_v2_preview'
    )::jsonb->>'referencedRecipeMissingYieldCount'
  )::integer=1,
  'v2 dry run reports yield completeness'
);


reset role;


select pg_temp.ok(
  not exists(
    select 1
    from public.inventory_items
    where tenant_id=pg_temp.t()
  )
  and not exists(
    select 1
    from public.recipes
    where tenant_id=pg_temp.t()
  )
  and not exists(
    select 1
    from public.recipe_subrecipe_lines
    where tenant_id=pg_temp.t()
  ),
  'v2 dry run writes no master data'
);


select pg_temp.ok(
  not exists(
    select 1
    from public.audit_logs
    where tenant_id=pg_temp.t()
      and action=
        'FOODSERVICE_MASTER_DATA_V2_IMPORTED'
  ),
  'v2 dry run writes no summary audit'
);


------------------------------------------------------------------
-- INVALID SCHEMA VERSION
------------------------------------------------------------------

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'e2411111-1111-4111-8111-111111111111',
  true
);


select pg_temp.err(
  $q$
    select public.import_foodservice_master_data_v2(
      pg_temp.t(),
      jsonb_set(
        pg_temp.payload(),
        '{schemaVersion}',
        '1'::jsonb
      ),
      'DRY_RUN'
    )
  $q$,
  '22023',
  'MASTER_DATA_V2_PAYLOAD_INVALID'
);


------------------------------------------------------------------
-- UNKNOWN CHILD RECIPE
------------------------------------------------------------------

select pg_temp.err(
  $q$
    select public.import_foodservice_master_data_v2(
      pg_temp.t(),
      jsonb_set(
        pg_temp.payload(),
        '{recipes,1,subrecipeLines,0,subrecipeCode}',
        '"UR999"'::jsonb
      ),
      'DRY_RUN'
    )
  $q$,
  '22023',
  'MASTER_DATA_V2_SUBRECIPE_NOT_IN_PAYLOAD'
);


------------------------------------------------------------------
-- UNIT MISMATCH
------------------------------------------------------------------

select pg_temp.err(
  $q$
    select public.import_foodservice_master_data_v2(
      pg_temp.t(),
      jsonb_set(
        pg_temp.payload(),
        '{recipes,1,subrecipeLines,0,unit}',
        '"MILLILITER"'::jsonb
      ),
      'DRY_RUN'
    )
  $q$,
  '22023',
  'MASTER_DATA_V2_SUBRECIPE_UNIT_MISMATCH'
);


------------------------------------------------------------------
-- PAYLOAD DEPENDENCY CYCLE
--
-- UR002 -> UR001 already exists.
-- Add UR001 -> UR002 and V2 must reject before APPLY.
------------------------------------------------------------------

select pg_temp.err(
  $q$
    select public.import_foodservice_master_data_v2(
      pg_temp.t(),
      jsonb_set(
        pg_temp.payload(),
        '{recipes,0,subrecipeLines}',
        jsonb_build_array(
          jsonb_build_object(
            'subrecipeCode','UR002',
            'quantity',10,
            'unit','GRAM',
            'notes','Creates cycle'
          )
        )
      ),
      'DRY_RUN'
    )
  $q$,
  '22023',
  'RECIPE_DEPENDENCY_CYCLE'
);


reset role;


select pg_temp.ok(
  not exists(
    select 1
    from public.inventory_items
    where tenant_id=pg_temp.t()
  )
  and not exists(
    select 1
    from public.recipes
    where tenant_id=pg_temp.t()
  ),
  'invalid dry runs leave no writes'
);


------------------------------------------------------------------
-- APPLY
------------------------------------------------------------------

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'e2411111-1111-4111-8111-111111111111',
  true
);


select set_config(
  'test.master_v2_apply',
  public.import_foodservice_master_data_v2(
    pg_temp.t(),
    pg_temp.payload(),
    'APPLY'
  )::text,
  true
);


select pg_temp.ok(
  (
    current_setting(
      'test.master_v2_apply'
    )::jsonb->>'applied'
  )::boolean,
  'v2 apply reports success'
);


reset role;


select pg_temp.ok(
  (
    select count(*)=3
    from public.inventory_items
    where tenant_id=pg_temp.t()
  ),
  'v2 apply creates inventory items'
);


select pg_temp.ok(
  (
    select count(*)=5
    from public.recipes
    where tenant_id=pg_temp.t()
  ),
  'v2 apply creates all recipes'
);


select pg_temp.ok(
  (
    select count(*)=5
    from public.recipe_lines
    where tenant_id=pg_temp.t()
  ),
  'v2 apply creates direct recipe lines'
);


select pg_temp.ok(
  (
    select count(*)=3
    from public.recipe_subrecipe_lines
    where tenant_id=pg_temp.t()
  ),
  'v2 apply creates subrecipe dependencies'
);


------------------------------------------------------------------
-- YIELD
------------------------------------------------------------------

select pg_temp.ok(
  exists(
    select 1
    from public.recipes
    where tenant_id=pg_temp.t()
      and code='UR001'
      and yield_quantity=200
      and yield_unit='GRAM'
  ),
  'v2 apply creates child recipe yield'
);


select pg_temp.ok(
  exists(
    select 1
    from public.recipes
    where tenant_id=pg_temp.t()
      and code='UR003'
      and yield_quantity is null
      and yield_unit is null
  ),
  'unknown child yield remains null'
);


------------------------------------------------------------------
-- RESOLVED SUBRECIPE
------------------------------------------------------------------

select pg_temp.ok(
  exists(
    select 1
    from public.recipe_subrecipe_lines sl
    join public.recipes parent_recipe
      on parent_recipe.id=sl.recipe_id
     and parent_recipe.tenant_id=sl.tenant_id
    join public.recipes child_recipe
      on child_recipe.id=sl.subrecipe_id
     and child_recipe.tenant_id=sl.tenant_id
    where sl.tenant_id=pg_temp.t()
      and parent_recipe.code='UR002'
      and child_recipe.code='UR001'
      and sl.quantity=50
      and sl.unit='GRAM'
  ),
  'resolved subrecipe usage is preserved'
);


------------------------------------------------------------------
-- UNRESOLVED SUBRECIPE USAGE
------------------------------------------------------------------

select pg_temp.ok(
  exists(
    select 1
    from public.recipe_subrecipe_lines sl
    join public.recipes parent_recipe
      on parent_recipe.id=sl.recipe_id
     and parent_recipe.tenant_id=sl.tenant_id
    join public.recipes child_recipe
      on child_recipe.id=sl.subrecipe_id
     and child_recipe.tenant_id=sl.tenant_id
    where sl.tenant_id=pg_temp.t()
      and parent_recipe.code='UR004'
      and child_recipe.code='UR003'
      and sl.quantity is null
      and sl.unit is null
  ),
  'unknown subrecipe usage is preserved as null'
);


------------------------------------------------------------------
-- KNOWN USAGE + UNKNOWN CHILD YIELD
------------------------------------------------------------------

select pg_temp.ok(
  exists(
    select 1
    from public.recipe_subrecipe_lines sl
    join public.recipes parent_recipe
      on parent_recipe.id=sl.recipe_id
     and parent_recipe.tenant_id=sl.tenant_id
    join public.recipes child_recipe
      on child_recipe.id=sl.subrecipe_id
     and child_recipe.tenant_id=sl.tenant_id
    where sl.tenant_id=pg_temp.t()
      and parent_recipe.code='UR005'
      and child_recipe.code='UR003'
      and sl.quantity=5
      and sl.unit='GRAM'
      and child_recipe.yield_quantity is null
  ),
  'known usage with unknown child yield is preserved'
);


------------------------------------------------------------------
-- AUDITS
------------------------------------------------------------------

select pg_temp.ok(
  (
    select count(*)=1
    from public.audit_logs
    where tenant_id=pg_temp.t()
      and action=
        'FOODSERVICE_MASTER_DATA_V2_IMPORTED'
      and metadata @>
        jsonb_build_object(
          'schemaVersion',2,
          'inventoryItemCount',3,
          'recipeCount',5,
          'recipeLineCount',5,
          'subrecipeLineCount',3,
          'unresolvedSubrecipeLineCount',1,
          'yieldRecipeCount',1,
          'referencedRecipeMissingYieldCount',1,
          'menuProductCount',0
        )
  ),
  'v2 import summary is audited exactly once'
);


select pg_temp.ok(
  (
    select count(*)=1
    from public.audit_logs
    where tenant_id=pg_temp.t()
      and action='RECIPE_YIELD_UPDATED'
  ),
  'yield import is audited exactly once'
);


select pg_temp.ok(
  (
    select count(*)=3
    from public.audit_logs
    where tenant_id=pg_temp.t()
      and action=
        'RECIPE_SUBRECIPES_REPLACED'
  ),
  'subrecipe replacements are audited exactly once per parent'
);


------------------------------------------------------------------
-- REPEAT DRY RUN MUST EXPOSE CONFLICTS
------------------------------------------------------------------

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'e2411111-1111-4111-8111-111111111111',
  true
);


select set_config(
  'test.master_v2_conflict',
  public.import_foodservice_master_data_v2(
    pg_temp.t(),
    pg_temp.payload(),
    'DRY_RUN'
  )::text,
  true
);


select pg_temp.ok(
  not (
    current_setting(
      'test.master_v2_conflict'
    )::jsonb->>'canApply'
  )::boolean
  and
  jsonb_array_length(
    current_setting(
      'test.master_v2_conflict'
    )::jsonb->'inventoryConflicts'
  )=3
  and
  jsonb_array_length(
    current_setting(
      'test.master_v2_conflict'
    )::jsonb->'recipeConflicts'
  )=5,
  'repeat dry run exposes all existing conflicts'
);


select pg_temp.err(
  $q$
    select public.import_foodservice_master_data_v2(
      pg_temp.t(),
      pg_temp.payload(),
      'APPLY'
    )
  $q$,
  '23505',
  'MASTER_DATA_V2_CONFLICT'
);


reset role;


select pg_temp.ok(
  (
    select count(*)=3
    from public.inventory_items
    where tenant_id=pg_temp.t()
  )
  and
  (
    select count(*)=5
    from public.recipes
    where tenant_id=pg_temp.t()
  )
  and
  (
    select count(*)=3
    from public.recipe_subrecipe_lines
    where tenant_id=pg_temp.t()
  ),
  'failed repeat apply leaves master data unchanged'
);


------------------------------------------------------------------
-- READ-ONLY USER CANNOT IMPORT
------------------------------------------------------------------

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'e2411111-2222-4222-8222-111111111111',
  true
);


select pg_temp.err(
  $q$
    select public.import_foodservice_master_data_v2(
      pg_temp.t(),
      pg_temp.payload(),
      'DRY_RUN'
    )
  $q$,
  '42501'
);


reset role;


------------------------------------------------------------------
-- SECURITY / GRANTS
------------------------------------------------------------------

do $$
declare
  f record;
begin
  select p.*
  into strict f
  from pg_proc p
  join pg_namespace n
    on n.oid=p.pronamespace
  where n.nspname='public'
    and p.proname=
      'import_foodservice_master_data_v2';

  perform pg_temp.ok(
    f.prosecdef
    and 'search_path=""'=any(
      f.proconfig
    ),
    'v2 importer is secured definer'
  );

  perform pg_temp.ok(
    not has_function_privilege(
      'anon',
      f.oid,
      'EXECUTE'
    )
    and has_function_privilege(
      'authenticated',
      f.oid,
      'EXECUTE'
    )
    and has_function_privilege(
      'service_role',
      f.oid,
      'EXECUTE'
    ),
    'v2 importer grants are restricted'
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
    'PUBLIC execute is revoked from v2 importer'
  );
end
$$;


rollback;


------------------------------------------------------------------
-- RESIDUAL FIXTURE CHECK
------------------------------------------------------------------

do $$
begin
  if exists(
    select 1
    from auth.users
    where email like
      'master-v2-%@coost.test'
  )
  or exists(
    select 1
    from public.tenants
    where id=
      'e2411111-aaaa-4aaa-8aaa-111111111111'
  )
  then
    raise exception
      'RESIDUAL_FIXTURES';
  end if;
end
$$;


select
  'PASS - FOODSERVICE MASTER DATA IMPORT V2'
    as result,

  (
    select count(*)
    from auth.users
    where email like
      'master-v2-%@coost.test'
  ) as residual_test_users,

  (
    select count(*)
    from public.tenants
    where id=
      'e2411111-aaaa-4aaa-8aaa-111111111111'
  ) as residual_test_tenants;
