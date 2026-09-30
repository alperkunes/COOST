begin;

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
    'e2211111-aaaa-4aaa-8aaa-111111111111'::uuid
$$;

create function pg_temp.payload()
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'schemaVersion',1,
    'source',
      jsonb_build_object(
        'file',
        'test-master-data.json',
        'status',
        'TEST'
      ),
    'summary',
      jsonb_build_object(
        'safeInventoryItems',2,
        'safeRecipes',1,
        'safeRecipeLines',2
      ),
    'inventoryItems',
      jsonb_build_array(
        jsonb_build_object(
          'sku','MLZ001',
          'name','Dana Eti',
          'baseUnit','GRAM',
          'category','TEST',
          'status','ACTIVE'
        ),
        jsonb_build_object(
          'sku','MLZ002',
          'name','Zeytinyağı',
          'baseUnit','MILLILITER',
          'category','TEST',
          'status','ACTIVE'
        )
      ),
    'recipes',
      jsonb_build_array(
        jsonb_build_object(
          'code','UR001',
          'name','Test Tabak',
          'category','ANA YEMEK',
          'currencyCode','TRY',
          'portions',1,
          'status','ACTIVE',
          'lines',
            jsonb_build_array(
              jsonb_build_object(
                'inventorySku','MLZ001',
                'quantityBase',100,
                'notes',null
              ),
              jsonb_build_object(
                'inventorySku','MLZ002',
                'quantityBase',10,
                'notes','Pişirme'
              )
            )
        )
      ),
    'menuProducts',
      '[]'::jsonb
  )
$$;

insert into auth.users(
  id,
  aud,
  role,
  email
)
values
(
  'e2211111-1111-4111-8111-111111111111',
  'authenticated',
  'authenticated',
  'master-writer@coost.test'
),
(
  'e2211111-2222-4222-8222-111111111111',
  'authenticated',
  'authenticated',
  'master-reader@coost.test'
);

insert into public.tenants(
  id,
  name,
  status
)
values(
  pg_temp.t(),
  'Master Data Test',
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
  'e2211111-3333-4333-8333-111111111111',
  pg_temp.t(),
  'e2211111-1111-4111-8111-111111111111',
  'ACTIVE'
),
(
  'e2211111-4444-4444-8444-111111111111',
  pg_temp.t(),
  'e2211111-2222-4222-8222-111111111111',
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
  'e2211111-5555-4555-8555-111111111111',
  pg_temp.t(),
  'writer',
  'Writer'
),
(
  'e2211111-6666-4666-8666-111111111111',
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
  'e2211111-3333-4333-8333-111111111111',
  'e2211111-5555-4555-8555-111111111111'
),
(
  pg_temp.t(),
  'e2211111-4444-4444-8444-111111111111',
  'e2211111-6666-4666-8666-111111111111'
);

insert into public.role_permissions(
  tenant_id,
  role_id,
  permission_key
)
select
  pg_temp.t(),
  'e2211111-5555-4555-8555-111111111111',
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
  'e2211111-6666-4666-8666-111111111111',
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
-- DRY RUN: validates but writes nothing
------------------------------------------------------------------

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'e2211111-1111-4111-8111-111111111111',
  true
);

select set_config(
  'test.master_preview',
  public.import_foodservice_master_data(
    pg_temp.t(),
    pg_temp.payload(),
    'DRY_RUN'
  )::text,
  true
);

select pg_temp.ok(
  (
    current_setting(
      'test.master_preview'
    )::jsonb->>'canApply'
  )::boolean,
  'clean payload can apply'
);

select pg_temp.ok(
  (
    current_setting(
      'test.master_preview'
    )::jsonb->>'inventoryItemCount'
  )::integer=2
  and
  (
    current_setting(
      'test.master_preview'
    )::jsonb->>'recipeCount'
  )::integer=1
  and
  (
    current_setting(
      'test.master_preview'
    )::jsonb->>'recipeLineCount'
  )::integer=2,
  'dry run reports expected counts'
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
  'dry run writes no master data'
);

select pg_temp.ok(
  not exists(
    select 1
    from public.audit_logs
    where tenant_id=pg_temp.t()
      and action=
        'FOODSERVICE_MASTER_DATA_IMPORTED'
  ),
  'dry run writes no import audit'
);

------------------------------------------------------------------
-- APPLY
------------------------------------------------------------------

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'e2211111-1111-4111-8111-111111111111',
  true
);

select set_config(
  'test.master_apply',
  public.import_foodservice_master_data(
    pg_temp.t(),
    pg_temp.payload(),
    'APPLY'
  )::text,
  true
);

select pg_temp.ok(
  (
    current_setting(
      'test.master_apply'
    )::jsonb->>'applied'
  )::boolean,
  'apply reports success'
);

reset role;

select pg_temp.ok(
  (
    select count(*)=2
    from public.inventory_items
    where tenant_id=pg_temp.t()
  ),
  'apply creates inventory items'
);

select pg_temp.ok(
  (
    select count(*)=1
    from public.recipes
    where tenant_id=pg_temp.t()
      and code='UR001'
      and name='Test Tabak'
      and portions=1
      and currency_code='TRY'
  ),
  'apply creates recipe'
);

select pg_temp.ok(
  (
    select count(*)=2
    from public.recipe_lines rl
    join public.recipes r
      on r.id=rl.recipe_id
     and r.tenant_id=rl.tenant_id
    where rl.tenant_id=pg_temp.t()
      and r.code='UR001'
  ),
  'apply creates recipe lines'
);

select pg_temp.ok(
  exists(
    select 1
    from public.recipe_lines rl
    join public.recipes r
      on r.id=rl.recipe_id
     and r.tenant_id=rl.tenant_id
    join public.inventory_items i
      on i.id=rl.inventory_item_id
     and i.tenant_id=rl.tenant_id
    where rl.tenant_id=pg_temp.t()
      and r.code='UR001'
      and i.sku='MLZ001'
      and rl.quantity_base=100
  )
  and
  exists(
    select 1
    from public.recipe_lines rl
    join public.recipes r
      on r.id=rl.recipe_id
     and r.tenant_id=rl.tenant_id
    join public.inventory_items i
      on i.id=rl.inventory_item_id
     and i.tenant_id=rl.tenant_id
    where rl.tenant_id=pg_temp.t()
      and r.code='UR001'
      and i.sku='MLZ002'
      and rl.quantity_base=10
      and rl.notes='Pişirme'
  ),
  'recipe lines resolve inventory SKU correctly'
);

select pg_temp.ok(
  (
    select count(*)=1
    from public.audit_logs
    where tenant_id=pg_temp.t()
      and action=
        'FOODSERVICE_MASTER_DATA_IMPORTED'
      and metadata @>
        jsonb_build_object(
          'schemaVersion',1,
          'inventoryItemCount',2,
          'recipeCount',1,
          'recipeLineCount',2,
          'menuProductCount',0
        )
  ),
  'master import summary is audited'
);

------------------------------------------------------------------
-- Existing-data conflict preview + APPLY rejection
------------------------------------------------------------------

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'e2211111-1111-4111-8111-111111111111',
  true
);

select set_config(
  'test.master_conflict',
  public.import_foodservice_master_data(
    pg_temp.t(),
    pg_temp.payload(),
    'DRY_RUN'
  )::text,
  true
);

select pg_temp.ok(
  not (
    current_setting(
      'test.master_conflict'
    )::jsonb->>'canApply'
  )::boolean
  and
  jsonb_array_length(
    current_setting(
      'test.master_conflict'
    )::jsonb->'inventoryConflicts'
  )=2
  and
  jsonb_array_length(
    current_setting(
      'test.master_conflict'
    )::jsonb->'recipeConflicts'
  )=1,
  'dry run exposes existing-data conflicts'
);

select pg_temp.err(
  $q$
    select public.import_foodservice_master_data(
      pg_temp.t(),
      pg_temp.payload(),
      'APPLY'
    )
  $q$,
  '23505',
  'MASTER_DATA_CONFLICT'
);

reset role;

select pg_temp.ok(
  (
    select count(*)=2
    from public.inventory_items
    where tenant_id=pg_temp.t()
  )
  and
  (
    select count(*)=1
    from public.recipes
    where tenant_id=pg_temp.t()
  )
  and
  (
    select count(*)=2
    from public.recipe_lines
    where tenant_id=pg_temp.t()
  ),
  'failed repeat apply leaves existing data unchanged'
);

------------------------------------------------------------------
-- Invalid payload protections
------------------------------------------------------------------

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'e2211111-1111-4111-8111-111111111111',
  true
);

select pg_temp.err(
  $q$
    select public.import_foodservice_master_data(
      pg_temp.t(),
      jsonb_build_object(
        'schemaVersion',1,
        'inventoryItems','[]'::jsonb,
        'recipes','[]'::jsonb,
        'menuProducts','[]'::jsonb
      ),
      'DRY_RUN'
    )
  $q$,
  '22023',
  'MASTER_DATA_PAYLOAD_INVALID'
);

select pg_temp.err(
  $q$
    select public.import_foodservice_master_data(
      pg_temp.t(),
      pg_temp.payload() ||
        jsonb_build_object(
          'menuProducts',
          jsonb_build_array(
            jsonb_build_object(
              'name',
              'Not supported yet'
            )
          )
        ),
      'DRY_RUN'
    )
  $q$,
  '22023',
  'MASTER_DATA_PAYLOAD_INVALID'
);

------------------------------------------------------------------
-- Read-only user cannot import
------------------------------------------------------------------

select set_config(
  'request.jwt.claim.sub',
  'e2211111-2222-4222-8222-111111111111',
  true
);

select pg_temp.err(
  $q$
    select public.import_foodservice_master_data(
      pg_temp.t(),
      pg_temp.payload(),
      'DRY_RUN'
    )
  $q$,
  '42501'
);

reset role;

------------------------------------------------------------------
-- Security / grants
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
      'import_foodservice_master_data';

  perform pg_temp.ok(
    f.prosecdef
    and 'search_path=""'=any(
      f.proconfig
    ),
    'master import is secured definer'
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
    ),
    'master import grants are restricted'
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
end
$$;

rollback;

do $$
begin
  if exists(
    select 1
    from auth.users
    where email like
      'master-%@coost.test'
  )
  or exists(
    select 1
    from public.tenants
    where id=
      'e2211111-aaaa-4aaa-8aaa-111111111111'
  )
  then
    raise exception
      'RESIDUAL_FIXTURES';
  end if;
end
$$;

select
  'PASS - FOODSERVICE MASTER DATA IMPORT' result,
  (
    select count(*)
    from auth.users
    where email like
      'master-%@coost.test'
  ) residual_test_users,
  (
    select count(*)
    from public.tenants
    where id=
      'e2211111-aaaa-4aaa-8aaa-111111111111'
  ) residual_test_tenants;
