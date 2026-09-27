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
  select 'e1111111-aaaa-4aaa-8aaa-111111111111'::uuid
$$;

create function pg_temp.foreign_t()
returns uuid
language sql
as $$
  select 'e2222222-aaaa-4aaa-8aaa-111111111111'::uuid
$$;

create function pg_temp.loc()
returns uuid
language sql
as $$
  select 'e1111111-7777-4777-8777-111111111111'::uuid
$$;

create function pg_temp.foreign_loc()
returns uuid
language sql
as $$
  select 'e2222222-7777-4777-8777-111111111111'::uuid
$$;

create function pg_temp.id(k text)
returns uuid
language sql
as $$
  select current_setting('test.'||k)::uuid
$$;

insert into auth.users(id,aud,role,email)
values
(
  'e1111111-1111-4111-8111-111111111111',
  'authenticated',
  'authenticated',
  'sales-app-writer@coost.test'
),
(
  'e1111111-2222-4222-8222-111111111111',
  'authenticated',
  'authenticated',
  'sales-app-reader@coost.test'
);

insert into public.tenants(id,name,status)
values
(
  pg_temp.t(),
  'Sales App A',
  'ACTIVE'
),
(
  pg_temp.foreign_t(),
  'Sales App B',
  'ACTIVE'
);

insert into public.memberships(id,tenant_id,user_id,status)
values
(
  'e1111111-3333-4333-8333-111111111111',
  pg_temp.t(),
  'e1111111-1111-4111-8111-111111111111',
  'ACTIVE'
),
(
  'e1111111-4444-4444-8444-111111111111',
  pg_temp.t(),
  'e1111111-2222-4222-8222-111111111111',
  'ACTIVE'
);

insert into public.roles(id,tenant_id,key,name)
values
(
  'e1111111-5555-4555-8555-111111111111',
  pg_temp.t(),
  'owner',
  'Owner'
),
(
  'e1111111-6666-4666-8666-111111111111',
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
  'e1111111-3333-4333-8333-111111111111',
  'e1111111-5555-4555-8555-111111111111'
),
(
  pg_temp.t(),
  'e1111111-4444-4444-8444-111111111111',
  'e1111111-6666-4666-8666-111111111111'
);

insert into public.role_permissions(
  tenant_id,
  role_id,
  permission_key
)
select
  pg_temp.t(),
  'e1111111-5555-4555-8555-111111111111',
  unnest(array[
    'food-service.costing.read',
    'food-service.costing.write'
  ]);

insert into public.role_permissions(
  tenant_id,
  role_id,
  permission_key
)
values
(
  pg_temp.t(),
  'e1111111-6666-4666-8666-111111111111',
  'food-service.costing.read'
);

insert into public.tenant_modules(
  tenant_id,
  module_key,
  enabled
)
values
(
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
values
(
  pg_temp.loc(),
  pg_temp.t(),
  'Kitchen',
  'ACTIVE'
),
(
  'e1111111-8888-4888-8888-111111111111',
  pg_temp.t(),
  'Branch',
  'ACTIVE'
),
(
  pg_temp.foreign_loc(),
  pg_temp.foreign_t(),
  'Foreign',
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
  'e1111111-9999-4999-8999-111111111111',
  pg_temp.t(),
  'TRY Recipe',
  'TRY',
  1
),
(
  'e1111111-9999-4999-8999-222222222222',
  pg_temp.t(),
  'EUR Recipe',
  'EUR',
  1
),
(
  'e2222222-9999-4999-8999-111111111111',
  pg_temp.foreign_t(),
  'Foreign Recipe',
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
  'e1111111-abcd-4abc-8abc-111111111111',
  pg_temp.t(),
  'Menu A',
  'e1111111-9999-4999-8999-111111111111',
  'TRY',
  110,
  10
),
(
  'e1111111-abcd-4abc-8abc-222222222222',
  pg_temp.t(),
  'Menu B',
  'e1111111-9999-4999-8999-111111111111',
  'TRY',
  110,
  10
),
(
  'e1111111-abcd-4abc-8abc-333333333333',
  pg_temp.t(),
  'Menu EUR',
  'e1111111-9999-4999-8999-222222222222',
  'EUR',
  110,
  10
),
(
  'e2222222-abcd-4abc-8abc-111111111111',
  pg_temp.foreign_t(),
  'Foreign Menu',
  'e2222222-9999-4999-8999-111111111111',
  'TRY',
  110,
  10
);

create function pg_temp.overview()
returns jsonb
language sql
as $$
  select public.get_sales_app_integration_overview(pg_temp.t())
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

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'e1111111-1111-4111-8111-111111111111',
  true
);

select set_config(
  'test.batch1',
  public.import_sales_app_daily_sales(
    pg_temp.t(),
    pg_temp.loc(),
    '2026-09-27',
    'BATCH-1',
    'TRY',
    jsonb_build_array(
      jsonb_build_object(
        'externalProductId','EXT-1',
        'externalProductCode','A-1',
        'externalProductName','External Menu A',
        'quantity',10,
        'grossSales',1100,
        'netSales',1000
      ),
      jsonb_build_object(
        'externalProductId','EXT-2',
        'externalProductCode','SERVICE',
        'externalProductName','Service Fee',
        'quantity',1,
        'grossSales',100,
        'netSales',90
      )
    )
  )::text,
  true
);

select pg_temp.ok(
  (pg_temp.overview()->'summary'->>'unmappedProductCount')::int=2,
  'first import discovers unmapped products'
);

select pg_temp.ok(
  jsonb_array_length(
    public.get_operating_data(
      pg_temp.t(),
      '2026-09-27',
      '2026-09-27',
      'TRY',
      pg_temp.loc()
    )->'sales'
  )=0,
  'unmapped products create no sales facts'
);

select set_config(
  'test.map1',
  pg_temp.mapping_id('EXT-1')::text,
  true
);

select set_config(
  'test.map2',
  pg_temp.mapping_id('EXT-2')::text,
  true
);

select public.update_sales_app_product_mapping(
  pg_temp.t(),
  pg_temp.id('map1'),
  'MAPPED',
  'e1111111-abcd-4abc-8abc-111111111111'
);

select public.update_sales_app_product_mapping(
  pg_temp.t(),
  pg_temp.id('map2'),
  'IGNORED',
  null
);

select public.reprocess_sales_app_import_batch(
  pg_temp.t(),
  pg_temp.id('batch1')
);

reset role;

select pg_temp.ok(
  (
    select count(*)=1
    and max(quantity)=10
    and max(gross_sales)=1100
    and max(net_sales)=1000
    and max(source_type)='SALES_APP'
    from public.menu_product_sales_facts
    where tenant_id=pg_temp.t()
      and location_id=pg_temp.loc()
      and sale_date='2026-09-27'
  ),
  'mapped product creates one authoritative sales fact'
);

select pg_temp.ok(
  not exists(
    select 1
    from public.menu_product_sales_facts
    where tenant_id=pg_temp.t()
      and menu_product_id='e1111111-abcd-4abc-8abc-222222222222'
  ),
  'ignored product creates no sales fact'
);

select pg_temp.ok(
  (
    select mapping_status='UNMAPPED'
       and menu_product_id is null
    from public.sales_app_import_rows
    where batch_id=pg_temp.id('batch1')
      and external_product_id='EXT-1'
  ),
  'immutable import row keeps original mapping snapshot'
);

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'e1111111-1111-4111-8111-111111111111',
  true
);

select set_config(
  'test.batch2',
  public.import_sales_app_daily_sales(
    pg_temp.t(),
    pg_temp.loc(),
    '2026-09-27',
    'BATCH-2',
    'TRY',
    jsonb_build_array(
      jsonb_build_object(
        'externalProductId','EXT-1',
        'externalProductCode','A-1',
        'externalProductName','External Menu A',
        'quantity',12,
        'grossSales',1320,
        'netSales',1200
      ),
      jsonb_build_object(
        'externalProductId','EXT-2',
        'externalProductCode','SERVICE',
        'externalProductName','Service Fee',
        'quantity',1,
        'grossSales',100,
        'netSales',90
      ),
      jsonb_build_object(
        'externalProductId','EXT-3',
        'externalProductCode','NEW',
        'externalProductName','Unmapped Product',
        'quantity',2,
        'grossSales',220,
        'netSales',200
      )
    )
  )::text,
  true
);

reset role;

select pg_temp.ok(
  (
    select count(*)=1
       and max(quantity)=12
       and max(net_sales)=1200
    from public.menu_product_sales_facts
    where tenant_id=pg_temp.t()
      and location_id=pg_temp.loc()
      and sale_date='2026-09-27'
      and menu_product_id='e1111111-abcd-4abc-8abc-111111111111'
  ),
  'corrected daily import replaces instead of adds'
);

select pg_temp.ok(
  (
    select mapped_row_count=1
       and unmapped_row_count=1
       and row_count=3
    from public.sales_app_import_batches
    where id=pg_temp.id('batch2')
  ),
  'batch counts mapped and unmapped rows'
);

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'e1111111-1111-4111-8111-111111111111',
  true
);

select pg_temp.ok(
  public.import_sales_app_daily_sales(
    pg_temp.t(),
    pg_temp.loc(),
    '2026-09-27',
    'BATCH-2',
    'TRY',
    jsonb_build_array(
      jsonb_build_object(
        'externalProductId','EXT-1',
        'externalProductCode','A-1',
        'externalProductName','External Menu A',
        'quantity',12,
        'grossSales',1320,
        'netSales',1200
      ),
      jsonb_build_object(
        'externalProductId','EXT-2',
        'externalProductCode','SERVICE',
        'externalProductName','Service Fee',
        'quantity',1,
        'grossSales',100,
        'netSales',90
      ),
      jsonb_build_object(
        'externalProductId','EXT-3',
        'externalProductCode','NEW',
        'externalProductName','Unmapped Product',
        'quantity',2,
        'grossSales',220,
        'netSales',200
      )
    )
  )=pg_temp.id('batch2'),
  'same batch payload is idempotent'
);

select pg_temp.err(
  $q$
  select public.import_sales_app_daily_sales(
    pg_temp.t(),
    pg_temp.loc(),
    '2026-09-27',
    'BATCH-2',
    'TRY',
    jsonb_build_array(
      jsonb_build_object(
        'externalProductId','EXT-1',
        'externalProductName','Changed',
        'quantity',99,
        'grossSales',99,
        'netSales',99
      )
    )
  )
  $q$,
  '22023'
);

select pg_temp.err(
  $q$
  select public.import_sales_app_daily_sales(
    pg_temp.t(),
    pg_temp.loc(),
    '2026-09-28',
    'BAD-DUP',
    'TRY',
    jsonb_build_array(
      jsonb_build_object(
        'externalProductId','DUP',
        'externalProductName','Duplicate',
        'quantity',1,
        'grossSales',10,
        'netSales',9
      ),
      jsonb_build_object(
        'externalProductId','DUP',
        'externalProductName','Duplicate Again',
        'quantity',1,
        'grossSales',10,
        'netSales',9
      )
    )
  )
  $q$,
  '22023'
);

select pg_temp.err(
  $q$
  select public.import_sales_app_daily_sales(
    pg_temp.t(),
    pg_temp.loc(),
    '2026-09-28',
    'BAD-NEG',
    'TRY',
    jsonb_build_array(
      jsonb_build_object(
        'externalProductId','NEG',
        'externalProductName','Negative',
        'quantity',-1,
        'grossSales',10,
        'netSales',9
      )
    )
  )
  $q$,
  '22023'
);

select pg_temp.err(
  $q$
  select public.import_sales_app_daily_sales(
    pg_temp.t(),
    pg_temp.loc(),
    '2026-09-28',
    'BAD-ZERO',
    'TRY',
    jsonb_build_array(
      jsonb_build_object(
        'externalProductId','ZERO',
        'externalProductName','Zero',
        'quantity',0,
        'grossSales',10,
        'netSales',9
      )
    )
  )
  $q$,
  '22023'
);

select pg_temp.err(
  $q$
  select public.import_sales_app_daily_sales(
    pg_temp.t(),
    pg_temp.loc(),
    '2026-09-28',
    'BAD-CURRENCY',
    'EUR',
    jsonb_build_array(
      jsonb_build_object(
        'externalProductId','EXT-1',
        'externalProductName','External Menu A',
        'quantity',1,
        'grossSales',10,
        'netSales',9
      )
    )
  )
  $q$,
  '22023'
);

select pg_temp.err(
  $q$
  select public.import_sales_app_daily_sales(
    pg_temp.t(),
    pg_temp.foreign_loc(),
    '2026-09-28',
    'BAD-LOCATION',
    'TRY',
    jsonb_build_array(
      jsonb_build_object(
        'externalProductId','X',
        'externalProductName','Foreign Location',
        'quantity',1,
        'grossSales',10,
        'netSales',9
      )
    )
  )
  $q$,
  '22023'
);

select set_config(
  'test.map3',
  pg_temp.mapping_id('EXT-3')::text,
  true
);

select pg_temp.err(
  format(
    'select public.update_sales_app_product_mapping(%L,%L,%L,%L)',
    pg_temp.t(),
    pg_temp.id('map3'),
    'MAPPED',
    'e2222222-abcd-4abc-8abc-111111111111'
  ),
  '22023'
);

select public.upsert_menu_product_sales_fact(
  pg_temp.t(),
  pg_temp.loc(),
  '2026-09-27',
  'e1111111-abcd-4abc-8abc-222222222222',
  3,
  330,
  300
);

select set_config(
  'test.batch3',
  public.import_sales_app_daily_sales(
    pg_temp.t(),
    pg_temp.loc(),
    '2026-09-27',
    'BATCH-3',
    'TRY',
    jsonb_build_array(
      jsonb_build_object(
        'externalProductId','EXT-1',
        'externalProductName','External Menu A',
        'quantity',14,
        'grossSales',1540,
        'netSales',1400
      ),
      jsonb_build_object(
        'externalProductId','EXT-4',
        'externalProductName','External Menu B',
        'quantity',5,
        'grossSales',550,
        'netSales',500
      )
    )
  )::text,
  true
);

select set_config(
  'test.map4',
  pg_temp.mapping_id('EXT-4')::text,
  true
);

select public.update_sales_app_product_mapping(
  pg_temp.t(),
  pg_temp.id('map4'),
  'MAPPED',
  'e1111111-abcd-4abc-8abc-222222222222'
);

select public.reprocess_sales_app_import_batch(
  pg_temp.t(),
  pg_temp.id('batch3')
);

select pg_temp.ok(
  public.reprocess_sales_app_import_batch(
    pg_temp.t(),
    pg_temp.id('batch3')
  )=pg_temp.id('batch3'),
  'reprocess is idempotent'
);

select pg_temp.err(
  format(
    'select public.reprocess_sales_app_import_batch(%L,%L)',
    pg_temp.t(),
    pg_temp.id('batch2')
  ),
  '55000'
);

reset role;

select pg_temp.ok(
  (
    select quantity=5
       and net_sales=500
       and source_type='SALES_APP'
    from public.menu_product_sales_facts
    where tenant_id=pg_temp.t()
      and location_id=pg_temp.loc()
      and sale_date='2026-09-27'
      and menu_product_id='e1111111-abcd-4abc-8abc-222222222222'
  ),
  'sales app replaces matching manual daily fact'
);

select pg_temp.ok(
  exists(
    select 1
    from public.audit_logs
    where tenant_id=pg_temp.t()
      and action='SALES_APP_FACT_REPLACED'
      and metadata->>'previousSourceType'='MANUAL'
      and metadata->>'newSourceType'='SALES_APP'
  ),
  'manual to sales app replacement is audited'
);

select pg_temp.ok(
  (
    select count(*)=3
    from public.audit_logs
    where tenant_id=pg_temp.t()
      and action='SALES_APP_PRODUCT_MAPPING_UPDATED'
  ),
  'mapping changes audited'
);

select pg_temp.ok(
  exists(
    select 1
    from public.audit_logs
    where tenant_id=pg_temp.t()
      and action='SALES_APP_IMPORT_COMPLETED'
  ),
  'import completion audited'
);

select pg_temp.ok(
  exists(
    select 1
    from public.audit_logs
    where tenant_id=pg_temp.t()
      and action='SALES_APP_IMPORT_REPROCESSED'
  ),
  'reprocess audited'
);

select pg_temp.err(
  $q$
  delete from public.sales_app_product_mappings
  where tenant_id=pg_temp.t()
  $q$,
  '55000'
);

select pg_temp.err(
  $q$
  delete from public.sales_app_import_batches
  where tenant_id=pg_temp.t()
  $q$,
  '55000'
);

select pg_temp.err(
  $q$
  update public.sales_app_import_rows
  set quantity=999
  where tenant_id=pg_temp.t()
  $q$,
  '55000'
);

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'e1111111-2222-4222-8222-111111111111',
  true
);

select pg_temp.ok(
  pg_temp.overview()->>'providerKey'='SALES_APP',
  'reader may read sales app overview'
);

select pg_temp.err(
  $q$
  select public.import_sales_app_daily_sales(
    pg_temp.t(),
    pg_temp.loc(),
    '2026-09-29',
    'READER-DENIED',
    'TRY',
    jsonb_build_array(
      jsonb_build_object(
        'externalProductId','R',
        'externalProductName','Reader',
        'quantity',1,
        'grossSales',10,
        'netSales',9
      )
    )
  )
  $q$,
  '42501'
);

select pg_temp.err(
  format(
    'select public.update_sales_app_product_mapping(%L,%L,%L,%L)',
    pg_temp.t(),
    pg_temp.id('map1'),
    'MAPPED',
    'e1111111-abcd-4abc-8abc-111111111111'
  ),
  '42501'
);

select pg_temp.err(
  $q$
  select *
  from public.sales_app_product_mappings
  $q$,
  '42501'
);

select pg_temp.err(
  $q$
  select *
  from public.sales_app_import_batches
  $q$,
  '42501'
);

select pg_temp.err(
  $q$
  select *
  from public.sales_app_import_rows
  $q$,
  '42501'
);

select pg_temp.err(
  $q$
  select public.get_sales_app_integration_overview(
    pg_temp.foreign_t()
  )
  $q$,
  '42501'
);

reset role;

update public.tenant_modules
set enabled=false
where tenant_id=pg_temp.t()
  and module_key='food-service';

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'e1111111-1111-4111-8111-111111111111',
  true
);

select pg_temp.err(
  $q$
  select public.get_sales_app_integration_overview(
    pg_temp.t()
  )
  $q$,
  '42501'
);

select pg_temp.err(
  $q$
  select public.import_sales_app_daily_sales(
    pg_temp.t(),
    pg_temp.loc(),
    '2026-09-29',
    'DISABLED',
    'TRY',
    jsonb_build_array(
      jsonb_build_object(
        'externalProductId','D',
        'externalProductName','Disabled',
        'quantity',1,
        'grossSales',10,
        'netSales',9
      )
    )
  )
  $q$,
  '42501'
);

select set_config(
  'request.jwt.claim.sub',
  '',
  true
);

select pg_temp.err(
  $q$
  select public.get_sales_app_integration_overview(
    pg_temp.t()
  )
  $q$,
  '42501'
);

set local role anon;

select pg_temp.err(
  $q$
  select public.get_sales_app_integration_overview(
    pg_temp.t()
  )
  $q$,
  '42501'
);

reset role;

do $$
declare
  t text;
  f record;
begin
  foreach t in array array[
    'sales_app_product_mappings',
    'sales_app_import_batches',
    'sales_app_import_rows'
  ]
  loop
    perform pg_temp.ok(
      (
        select relrowsecurity
        from pg_class
        where oid=('public.'||t)::regclass
      ),
      'RLS enabled '||t
    );

    perform pg_temp.ok(
      not has_table_privilege(
        'authenticated',
        'public.'||t,
        'SELECT,INSERT,UPDATE,DELETE,TRUNCATE'
      )
      and
      not has_table_privilege(
        'anon',
        'public.'||t,
        'SELECT,INSERT,UPDATE,DELETE,TRUNCATE'
      ),
      'direct grants revoked '||t
    );
  end loop;

  for f in
    select p.*
    from pg_proc p
    join pg_namespace n
      on n.oid=p.pronamespace
    where n.nspname='public'
      and p.proname in (
        'import_sales_app_daily_sales',
        'update_sales_app_product_mapping',
        'reprocess_sales_app_import_batch',
        'get_sales_app_integration_overview'
      )
  loop
    perform pg_temp.ok(
      f.prosecdef
      and 'search_path=""'=any(f.proconfig),
      'secure definer '||f.proname
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
      'RPC grants '||f.proname
    );

    perform pg_temp.ok(
      not exists(
        select 1
        from aclexplode(f.proacl)
        where grantee=0
          and privilege_type='EXECUTE'
      ),
      'PUBLIC revoked '||f.proname
    );
  end loop;
end
$$;

rollback;

do $$
begin
  if exists(
    select 1
    from auth.users
    where email like 'sales-app-%@coost.test'
  )
  or exists(
    select 1
    from public.tenants
    where id in (
      'e1111111-aaaa-4aaa-8aaa-111111111111',
      'e2222222-aaaa-4aaa-8aaa-111111111111'
    )
  )
  then
    raise exception 'RESIDUAL_FIXTURES';
  end if;
end
$$;

select
  'PASS - SALES APP INTEGRATION' result,
  (
    select count(*)
    from auth.users
    where email like 'sales-app-%@coost.test'
  ) residual_test_users,
  (
    select count(*)
    from public.tenants
    where id in (
      'e1111111-aaaa-4aaa-8aaa-111111111111',
      'e2222222-aaaa-4aaa-8aaa-111111111111'
    )
  ) residual_test_tenants;