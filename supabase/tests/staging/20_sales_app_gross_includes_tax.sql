begin;

create function pg_temp.ok(v boolean,m text)
returns void
language plpgsql
as $$
begin
  if v is distinct from true then
    raise exception 'ASSERT: %',m;
  end if;
end;
$$;

create function pg_temp.err(q text,s text)
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
  select 'f1111111-aaaa-4aaa-8aaa-111111111111'::uuid
$$;

create function pg_temp.loc()
returns uuid
language sql
as $$
  select 'f1111111-7777-4777-8777-111111111111'::uuid
$$;

create function pg_temp.overview()
returns jsonb
language sql
as $$
  select public.get_sales_app_integration_overview(
    pg_temp.t()
  )
$$;

create function pg_temp.mapping_id(ext text)
returns uuid
language sql
as $$
  select (m->>'id')::uuid
  from jsonb_array_elements(
    pg_temp.overview()->'mappings'
  ) m
  where m->>'externalProductId'=ext
  limit 1
$$;

insert into auth.users(
  id,
  aud,
  role,
  email
)
values(
  'f1111111-1111-4111-8111-111111111111',
  'authenticated',
  'authenticated',
  'sales-gross-writer@coost.test'
);

insert into public.tenants(
  id,
  name,
  status
)
values(
  pg_temp.t(),
  'Gross Sales Test',
  'ACTIVE'
);

insert into public.memberships(
  id,
  tenant_id,
  user_id,
  status
)
values(
  'f1111111-3333-4333-8333-111111111111',
  pg_temp.t(),
  'f1111111-1111-4111-8111-111111111111',
  'ACTIVE'
);

insert into public.roles(
  id,
  tenant_id,
  key,
  name
)
values(
  'f1111111-5555-4555-8555-111111111111',
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
  'f1111111-3333-4333-8333-111111111111',
  'f1111111-5555-4555-8555-111111111111'
);

insert into public.role_permissions(
  tenant_id,
  role_id,
  permission_key
)
select
  pg_temp.t(),
  'f1111111-5555-4555-8555-111111111111',
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
  pg_temp.loc(),
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
  'f1111111-9999-4999-8999-111111111111',
  pg_temp.t(),
  'KDV 10 Recipe',
  'TRY',
  1
),
(
  'f1111111-9999-4999-8999-222222222222',
  pg_temp.t(),
  'KDV 20 Recipe',
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
  'f1111111-abcd-4abc-8abc-111111111111',
  pg_temp.t(),
  'KDV 10 Ürün',
  'f1111111-9999-4999-8999-111111111111',
  'TRY',
  110,
  10
),
(
  'f1111111-abcd-4abc-8abc-222222222222',
  pg_temp.t(),
  'KDV 20 Ürün',
  'f1111111-9999-4999-8999-222222222222',
  'TRY',
  120,
  20
);

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'f1111111-1111-4111-8111-111111111111',
  true
);

select set_config(
  'test.gross_batch',
  public.import_sales_app_daily_gross_sales(
    pg_temp.t(),
    pg_temp.loc(),
    '2026-09-30',
    'GROSS-BATCH-1',
    'TRY',
    jsonb_build_array(
      jsonb_build_object(
        'externalProductId','NARPOS-A',
        'externalProductName','NarPOS Ürün A',
        'quantity',1,
        'grossSales',110
      ),
      jsonb_build_object(
        'externalProductId','NARPOS-B',
        'externalProductName','NarPOS Ürün B',
        'quantity',2,
        'grossSales',240
      )
    )
  )::text,
  true
);

reset role;

select pg_temp.ok(
  (
    select sales_amount_mode='GROSS_INCLUDES_TAX'
       and row_count=2
       and mapped_row_count=0
       and unmapped_row_count=2
    from public.sales_app_import_batches
    where id=current_setting(
      'test.gross_batch'
    )::uuid
  ),
  'gross import records its amount semantics'
);

select pg_temp.ok(
  not exists(
    select 1
    from public.menu_product_sales_facts
    where tenant_id=pg_temp.t()
      and sale_date='2026-09-30'
  ),
  'unmapped gross rows create no sales facts'
);

set local role authenticated;

select public.update_sales_app_product_mapping(
  pg_temp.t(),
  pg_temp.mapping_id('NARPOS-A'),
  'MAPPED',
  'f1111111-abcd-4abc-8abc-111111111111'
);

select public.update_sales_app_product_mapping(
  pg_temp.t(),
  pg_temp.mapping_id('NARPOS-B'),
  'MAPPED',
  'f1111111-abcd-4abc-8abc-222222222222'
);

select public.reprocess_sales_app_import_batch(
  pg_temp.t(),
  current_setting('test.gross_batch')::uuid
);

reset role;

select pg_temp.ok(
  (
    select quantity=1
       and gross_sales=110
       and net_sales=100
       and source_type='SALES_APP'
    from public.menu_product_sales_facts
    where tenant_id=pg_temp.t()
      and location_id=pg_temp.loc()
      and sale_date='2026-09-30'
      and menu_product_id=
        'f1111111-abcd-4abc-8abc-111111111111'
  ),
  '10 percent tax is removed from realized gross sales'
);

select pg_temp.ok(
  (
    select quantity=2
       and gross_sales=240
       and net_sales=200
       and source_type='SALES_APP'
    from public.menu_product_sales_facts
    where tenant_id=pg_temp.t()
      and location_id=pg_temp.loc()
      and sale_date='2026-09-30'
      and menu_product_id=
        'f1111111-abcd-4abc-8abc-222222222222'
  ),
  '20 percent tax is removed from realized gross sales'
);

select pg_temp.ok(
  (
    select
      sum(gross_sales)=350
      and sum(net_sales)=300
    from public.menu_product_sales_facts
    where tenant_id=pg_temp.t()
      and location_id=pg_temp.loc()
      and sale_date='2026-09-30'
  ),
  'gross total is preserved while accounting net is derived'
);

select pg_temp.ok(
  exists(
    select 1
    from public.audit_logs
    where tenant_id=pg_temp.t()
      and action='SALES_APP_FACT_REPLACED'
      and metadata->>'salesAmountMode'
        ='GROSS_INCLUDES_TAX'
  ),
  'derived sales mode is audited'
);

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'f1111111-1111-4111-8111-111111111111',
  true
);

select set_config(
  'test.provided_batch',
  public.import_sales_app_daily_sales(
    pg_temp.t(),
    pg_temp.loc(),
    '2026-09-29',
    'PROVIDED-BATCH-1',
    'TRY',
    jsonb_build_array(
      jsonb_build_object(
        'externalProductId','NARPOS-A',
        'externalProductName','Provided Net A',
        'quantity',1,
        'grossSales',110,
        'netSales',97.25
      )
    )
  )::text,
  true
);

reset role;

select pg_temp.ok(
  (
    select sales_amount_mode='PROVIDED_NET'
    from public.sales_app_import_batches
    where id=current_setting(
      'test.provided_batch'
    )::uuid
  ),
  'existing imports remain PROVIDED_NET'
);

select pg_temp.ok(
  (
    select gross_sales=110
       and net_sales=97.25
    from public.menu_product_sales_facts
    where tenant_id=pg_temp.t()
      and location_id=pg_temp.loc()
      and sale_date='2026-09-29'
      and menu_product_id=
        'f1111111-abcd-4abc-8abc-111111111111'
  ),
  'existing provider net value remains authoritative'
);

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'f1111111-1111-4111-8111-111111111111',
  true
);

select pg_temp.err(
  $q$
  select public.import_sales_app_daily_gross_sales(
    pg_temp.t(),
    pg_temp.loc(),
    '2026-09-28',
    'BAD-GROSS-ZERO',
    'TRY',
    jsonb_build_array(
      jsonb_build_object(
        'externalProductId','BAD',
        'externalProductName','Bad Gross',
        'quantity',0,
        'grossSales',10
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
      'import_sales_app_daily_gross_sales';

  perform pg_temp.ok(
    f.prosecdef
    and 'search_path=""'=any(f.proconfig),
    'gross import is a secured definer function'
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
    'gross import RPC grants are restricted'
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
    where email='sales-gross-writer@coost.test'
  )
  or exists(
    select 1
    from public.tenants
    where id=
      'f1111111-aaaa-4aaa-8aaa-111111111111'
  )
  then
    raise exception 'RESIDUAL_FIXTURES';
  end if;
end
$$;

select
  'PASS - SALES APP GROSS INCLUDES TAX' result,
  (
    select count(*)
    from auth.users
    where email='sales-gross-writer@coost.test'
  ) residual_test_users,
  (
    select count(*)
    from public.tenants
    where id=
      'f1111111-aaaa-4aaa-8aaa-111111111111'
  ) residual_test_tenants;
