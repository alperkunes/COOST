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
  s text
)
returns void
language plpgsql
as $$
begin
  execute q;
  raise exception 'EXPECTED_ERROR: %',q;
exception
  when others then
    if sqlstate <> s then
      raise;
    end if;
end;
$$;

create function pg_temp.t()
returns uuid
language sql
as $$
  select
    'a2111111-aaaa-4aaa-8aaa-111111111111'::uuid
$$;

insert into auth.users(
  id,
  aud,
  role,
  email
)
values(
  'a2111111-1111-4111-8111-111111111111',
  'authenticated',
  'authenticated',
  'bulk-mapping-writer@coost.test'
);

insert into public.tenants(
  id,
  name,
  status
)
values(
  pg_temp.t(),
  'Bulk Mapping Test',
  'ACTIVE'
);

insert into public.memberships(
  id,
  tenant_id,
  user_id,
  status
)
values(
  'a2111111-3333-4333-8333-111111111111',
  pg_temp.t(),
  'a2111111-1111-4111-8111-111111111111',
  'ACTIVE'
);

insert into public.roles(
  id,
  tenant_id,
  key,
  name
)
values(
  'a2111111-5555-4555-8555-111111111111',
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
  'a2111111-3333-4333-8333-111111111111',
  'a2111111-5555-4555-8555-111111111111'
);

insert into public.role_permissions(
  tenant_id,
  role_id,
  permission_key
)
select
  pg_temp.t(),
  'a2111111-5555-4555-8555-111111111111',
  unnest(
    array[
      'food-service.costing.read',
      'food-service.costing.write'
    ]
  );

insert into public.tenant_modules(
  tenant_id,
  module_key,
  enabled
)
values(
  pg_temp.t(),
  'food-service',
  true
);

insert into public.locations(
  id,
  tenant_id,
  name,
  status
)
values(
  'a2111111-7777-4777-8777-111111111111',
  pg_temp.t(),
  'Nazilli Test',
  'ACTIVE'
);

insert into public.recipes(
  id,
  tenant_id,
  name,
  currency_code,
  portions
)
values
(
  'a2111111-9999-4999-8999-111111111111',
  pg_temp.t(),
  'Recipe A',
  'TRY',
  1
),
(
  'a2111111-9999-4999-8999-222222222222',
  pg_temp.t(),
  'Recipe B',
  'TRY',
  1
);

insert into public.menu_products(
  id,
  tenant_id,
  name,
  recipe_id,
  currency_code,
  sale_price_gross,
  sales_tax_rate
)
values
(
  'a2111111-abcd-4abc-8abc-111111111111',
  pg_temp.t(),
  'Menu A',
  'a2111111-9999-4999-8999-111111111111',
  'TRY',
  110,
  10
),
(
  'a2111111-abcd-4abc-8abc-222222222222',
  pg_temp.t(),
  'Menu B',
  'a2111111-9999-4999-8999-222222222222',
  'TRY',
  120,
  20
);

insert into public.sales_app_product_mappings(
  id,
  tenant_id,
  location_id,
  external_product_id,
  external_product_name
)
values
(
  'a2111111-abcd-4abc-8abc-333333333333',
  pg_temp.t(),
  'a2111111-7777-4777-8777-111111111111',
  'NARPOS-A',
  'NarPOS A'
),
(
  'a2111111-abcd-4abc-8abc-444444444444',
  pg_temp.t(),
  'a2111111-7777-4777-8777-111111111111',
  'NARPOS-B',
  'NarPOS B'
);

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'a2111111-1111-4111-8111-111111111111',
  true
);

select pg_temp.ok(
  (
    public.bulk_update_sales_app_product_mappings(
      pg_temp.t(),
      jsonb_build_array(
        jsonb_build_object(
          'mappingId',
          'a2111111-abcd-4abc-8abc-333333333333',
          'status',
          'MAPPED',
          'menuProductId',
          'a2111111-abcd-4abc-8abc-111111111111'
        ),
        jsonb_build_object(
          'mappingId',
          'a2111111-abcd-4abc-8abc-444444444444',
          'status',
          'IGNORED',
          'menuProductId',
          null
        )
      )
    )->>'mappingCount'
  )::int=2,
  'bulk command accepts two mapping updates'
);

reset role;

select pg_temp.ok(
  (
    select
      status='MAPPED'
      and menu_product_id=
        'a2111111-abcd-4abc-8abc-111111111111'
    from public.sales_app_product_mappings
    where id=
      'a2111111-abcd-4abc-8abc-333333333333'
  ),
  'first mapping is mapped'
);

select pg_temp.ok(
  (
    select
      status='IGNORED'
      and menu_product_id is null
    from public.sales_app_product_mappings
    where id=
      'a2111111-abcd-4abc-8abc-444444444444'
  ),
  'second mapping is ignored'
);

select pg_temp.ok(
  (
    select count(*)=2
    from public.audit_logs
    where tenant_id=pg_temp.t()
      and action=
        'SALES_APP_PRODUCT_MAPPING_UPDATED'
  ),
  'each bulk mapping change is audited'
);

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'a2111111-1111-4111-8111-111111111111',
  true
);

select pg_temp.err(
  $q$
  select public.bulk_update_sales_app_product_mappings(
    pg_temp.t(),
    jsonb_build_array(
      jsonb_build_object(
        'mappingId',
        'a2111111-abcd-4abc-8abc-333333333333',
        'status',
        'UNMAPPED',
        'menuProductId',
        null
      ),
      jsonb_build_object(
        'mappingId',
        'a2111111-abcd-4abc-8abc-999999999999',
        'status',
        'MAPPED',
        'menuProductId',
        'a2111111-abcd-4abc-8abc-222222222222'
      )
    )
  )
  $q$,
  '22023'
);

reset role;

select pg_temp.ok(
  (
    select
      status='MAPPED'
      and menu_product_id=
        'a2111111-abcd-4abc-8abc-111111111111'
    from public.sales_app_product_mappings
    where id=
      'a2111111-abcd-4abc-8abc-333333333333'
  ),
  'failed bulk command rolls back earlier changes atomically'
);

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'a2111111-1111-4111-8111-111111111111',
  true
);

select pg_temp.err(
  $q$
  select public.bulk_update_sales_app_product_mappings(
    pg_temp.t(),
    jsonb_build_array(
      jsonb_build_object(
        'mappingId',
        'a2111111-abcd-4abc-8abc-333333333333',
        'status',
        'MAPPED',
        'menuProductId',
        'a2111111-abcd-4abc-8abc-111111111111'
      ),
      jsonb_build_object(
        'mappingId',
        'a2111111-abcd-4abc-8abc-333333333333',
        'status',
        'MAPPED',
        'menuProductId',
        'a2111111-abcd-4abc-8abc-111111111111'
      )
    )
  )
  $q$,
  '22023'
);

reset role;

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
      'bulk_update_sales_app_product_mappings';

  perform pg_temp.ok(
    f.prosecdef
    and 'search_path=""'=any(f.proconfig),
    'bulk mapping is a secured definer function'
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
    'bulk mapping RPC grants are restricted'
  );

  perform pg_temp.ok(
    not exists(
      select 1
      from aclexplode(f.proacl)
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
    where email=
      'bulk-mapping-writer@coost.test'
  )
  or exists(
    select 1
    from public.tenants
    where id=
      'a2111111-aaaa-4aaa-8aaa-111111111111'
  )
  then
    raise exception 'RESIDUAL_FIXTURES';
  end if;
end
$$;

select
  'PASS - SALES APP BULK MAPPING' result,
  (
    select count(*)
    from auth.users
    where email=
      'bulk-mapping-writer@coost.test'
  ) residual_test_users,
  (
    select count(*)
    from public.tenants
    where id=
      'a2111111-aaaa-4aaa-8aaa-111111111111'
  ) residual_test_tenants;
