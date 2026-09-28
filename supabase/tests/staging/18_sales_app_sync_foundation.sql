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

create function pg_temp.foreign_t()
returns uuid
language sql
as $$
  select 'f2222222-aaaa-4aaa-8aaa-111111111111'::uuid
$$;

create function pg_temp.loc()
returns uuid
language sql
as $$
  select 'f1111111-7777-4777-8777-111111111111'::uuid
$$;

create function pg_temp.foreign_loc()
returns uuid
language sql
as $$
  select 'f2222222-7777-4777-8777-111111111111'::uuid
$$;

create function pg_temp.id(k text)
returns uuid
language sql
as $$
  select current_setting('test.'||k)::uuid
$$;

-- Migration must have granted both new permissions to all
-- already-existing owner roles.
select pg_temp.ok(
  not exists(
    select 1
    from public.roles r
    where r.key='owner'
      and exists(
        select required.permission_key
        from (
          values
            ('food-service.costing.read'::text),
            ('food-service.costing.write'::text)
        ) required(permission_key)

        except

        select rp.permission_key
        from public.role_permissions rp
        where rp.tenant_id=r.tenant_id
          and rp.role_id=r.id
      )
  ),
  'existing owner roles receive sales app permissions'
);

insert into auth.users(id,aud,role,email)
values
(
  'f1111111-1111-4111-8111-111111111111',
  'authenticated',
  'authenticated',
  'sales-sync-manager@coost.test'
),
(
  'f1111111-2222-4222-8222-111111111111',
  'authenticated',
  'authenticated',
  'sales-sync-reader@coost.test'
);

insert into public.tenants(id,name,status)
values
(
  pg_temp.t(),
  'Sales Sync A',
  'ACTIVE'
),
(
  pg_temp.foreign_t(),
  'Sales Sync B',
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
  'f1111111-3333-4333-8333-111111111111',
  pg_temp.t(),
  'f1111111-1111-4111-8111-111111111111',
  'ACTIVE'
),
(
  'f1111111-4444-4444-8444-111111111111',
  pg_temp.t(),
  'f1111111-2222-4222-8222-111111111111',
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
  'f1111111-5555-4555-8555-111111111111',
  pg_temp.t(),
  'manager',
  'Manager'
),
(
  'f1111111-6666-4666-8666-111111111111',
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
  'f1111111-3333-4333-8333-111111111111',
  'f1111111-5555-4555-8555-111111111111'
),
(
  pg_temp.t(),
  'f1111111-4444-4444-8444-111111111111',
  'f1111111-6666-4666-8666-111111111111'
);

insert into public.role_permissions(
  tenant_id,
  role_id,
  permission_key
)
select
  pg_temp.t(),
  'f1111111-5555-4555-8555-111111111111',
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
  'f1111111-6666-4666-8666-111111111111',
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
  'Nazilli',
  'ACTIVE'
),
(
  'f1111111-8888-4888-8888-111111111111',
  pg_temp.t(),
  'Passive Branch',
  'PASSIVE'
),
(
  pg_temp.foreign_loc(),
  pg_temp.foreign_t(),
  'Foreign',
  'ACTIVE'
);

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'f1111111-1111-4111-8111-111111111111',
  true
);

select set_config(
  'test.connection',
  public.create_sales_app_connection(
    pg_temp.t(),
    pg_temp.loc(),
    null,
    null,
    1
  )::text,
  true
);

select pg_temp.ok(
  exists(
    select 1
    from jsonb_array_elements(
      public.get_sales_app_sync_overview(
        pg_temp.t()
      )->'connections'
    ) c
    where c->>'id'=pg_temp.id('connection')::text
      and c->>'locationId'=pg_temp.loc()::text
      and c->>'status'='DRAFT'
      and (c->>'syncEnabled')::boolean=false
      and (c->>'syncLookbackDays')::int=1
      and c->>'adapterKey' is null
      and c->>'externalLocationId' is null
  ),
  'draft connection created'
);
select public.update_sales_app_connection(
  pg_temp.t(),
  pg_temp.id('connection'),
  'GENERIC_TEST',
  'EXT-NAZILLI-01',
  'ACTIVE',
  true,
  3
);

select pg_temp.ok(
  exists(
    select 1
    from jsonb_array_elements(
      public.get_sales_app_sync_overview(
        pg_temp.t()
      )->'connections'
    ) c
    where c->>'id'=pg_temp.id('connection')::text
      and c->>'adapterKey'='GENERIC_TEST'
      and c->>'externalLocationId'='EXT-NAZILLI-01'
      and c->>'status'='ACTIVE'
      and (c->>'syncEnabled')::boolean=true
      and (c->>'syncLookbackDays')::int=3
  ),
  'connection activated'
);

select pg_temp.err(
  $q$
  select public.create_sales_app_connection(
    pg_temp.t(),
    pg_temp.loc(),
    null,
    null,
    1
  )
  $q$,
  '23505'
);

select pg_temp.err(
  $q$
  select public.create_sales_app_connection(
    pg_temp.t(),
    'f1111111-8888-4888-8888-111111111111',
    null,
    null,
    1
  )
  $q$,
  '22023'
);

select pg_temp.err(
  $q$
  select public.create_sales_app_connection(
    pg_temp.t(),
    pg_temp.foreign_loc(),
    null,
    null,
    1
  )
  $q$,
  '22023'
);

select pg_temp.err(
  format(
    'select public.update_sales_app_connection(%L,%L,%L,%L,%L,%L,%L)',
    pg_temp.t(),
    pg_temp.id('connection'),
    null,
    null,
    'ACTIVE',
    false,
    1
  ),
  '22023'
);

select pg_temp.err(
  format(
    'select public.update_sales_app_connection(%L,%L,%L,%L,%L,%L,%L)',
    pg_temp.t(),
    pg_temp.id('connection'),
    'GENERIC_TEST',
    'EXT-NAZILLI-01',
    'PAUSED',
    true,
    3
  ),
  '22023'
);

select pg_temp.err(
  format(
    'select public.update_sales_app_connection(%L,%L,%L,%L,%L,%L,%L)',
    pg_temp.foreign_t(),
    pg_temp.id('connection'),
    'GENERIC_TEST',
    'EXT-NAZILLI-01',
    'ACTIVE',
    true,
    3
  ),
  '42501'
);

-- Browser roles cannot read tables directly.
select pg_temp.err(
  $q$
  select *
  from public.sales_app_connections
  $q$,
  '42501'
);

select pg_temp.err(
  $q$
  select *
  from public.sales_app_sync_runs
  $q$,
  '42501'
);

-- Reader can read the overview but cannot manage connections.
select set_config(
  'request.jwt.claim.sub',
  'f1111111-2222-4222-8222-111111111111',
  true
);

select pg_temp.ok(
  public.get_sales_app_sync_overview(
    pg_temp.t()
  )->>'providerKey'='SALES_APP',
  'reader can read overview'
);

select pg_temp.err(
  $q$
  select public.create_sales_app_connection(
    pg_temp.t(),
    pg_temp.loc(),
    null,
    null,
    1
  )
  $q$,
  '42501'
);

select pg_temp.err(
  format(
    'select public.update_sales_app_connection(%L,%L,%L,%L,%L,%L,%L)',
    pg_temp.t(),
    pg_temp.id('connection'),
    'GENERIC_TEST',
    'EXT-NAZILLI-01',
    'ACTIVE',
    true,
    3
  ),
  '42501'
);

select pg_temp.err(
  $q$
  select public.get_sales_app_sync_overview(
    pg_temp.foreign_t()
  )
  $q$,
  '42501'
);

reset role;

-- Scheduled/server work is stored directly by the service layer.
insert into public.sales_app_sync_runs(
  id,
  tenant_id,
  connection_id,
  location_id,
  provider_key,
  trigger_type,
  status,
  business_date_start,
  business_date_end
)
values(
  'f1111111-bbbb-4bbb-8bbb-111111111111',
  pg_temp.t(),
  pg_temp.id('connection'),
  pg_temp.loc(),
  'SALES_APP',
  'SCHEDULED',
  'QUEUED',
  '2026-09-27',
  '2026-09-27'
);

update public.sales_app_sync_runs
set
  status='RUNNING',
  started_at=clock_timestamp()
where id='f1111111-bbbb-4bbb-8bbb-111111111111';

update public.sales_app_sync_runs
set
  status='SUCCEEDED',
  finished_at=clock_timestamp(),
  import_batch_count=1,
  imported_row_count=12
where id='f1111111-bbbb-4bbb-8bbb-111111111111';

select pg_temp.ok(
  (
    select
      status='SUCCEEDED'
      and import_batch_count=1
      and imported_row_count=12
      and finished_at is not null
    from public.sales_app_sync_runs
    where id='f1111111-bbbb-4bbb-8bbb-111111111111'
  ),
  'queued running succeeded transition'
);

select pg_temp.err(
  $q$
  update public.sales_app_sync_runs
  set imported_row_count=13
  where id='f1111111-bbbb-4bbb-8bbb-111111111111'
  $q$,
  '55000'
);

select pg_temp.err(
  $q$
  delete from public.sales_app_sync_runs
  where id='f1111111-bbbb-4bbb-8bbb-111111111111'
  $q$,
  '55000'
);

insert into public.sales_app_sync_runs(
  id,
  tenant_id,
  connection_id,
  location_id,
  provider_key,
  trigger_type,
  status,
  business_date_start,
  business_date_end,
  requested_by_user_id
)
values(
  'f1111111-bbbb-4bbb-8bbb-222222222222',
  pg_temp.t(),
  pg_temp.id('connection'),
  pg_temp.loc(),
  'SALES_APP',
  'MANUAL',
  'QUEUED',
  '2026-09-28',
  '2026-09-28',
  'f1111111-1111-4111-8111-111111111111'
);

select pg_temp.err(
  $q$
  update public.sales_app_sync_runs
  set status='SUCCEEDED',
      finished_at=clock_timestamp()
  where id='f1111111-bbbb-4bbb-8bbb-222222222222'
  $q$,
  '55000'
);

select pg_temp.err(
  $q$
  update public.sales_app_sync_runs
  set location_id='f1111111-8888-4888-8888-111111111111'
  where id='f1111111-bbbb-4bbb-8bbb-222222222222'
  $q$,
  '55000'
);

select pg_temp.err(
  $q$
  delete from public.sales_app_connections
  where id=pg_temp.id('connection')
  $q$,
  '55000'
);

select pg_temp.err(
  $q$
  update public.sales_app_connections
  set location_id='f1111111-8888-4888-8888-111111111111'
  where id=pg_temp.id('connection')
  $q$,
  '55000'
);

select pg_temp.ok(
  (
    select count(*)=1
    from public.audit_logs
    where tenant_id=pg_temp.t()
      and action='SALES_APP_CONNECTION_CREATED'
  ),
  'connection creation audited'
);

select pg_temp.ok(
  (
    select count(*)=1
    from public.audit_logs
    where tenant_id=pg_temp.t()
      and action='SALES_APP_CONNECTION_UPDATED'
  ),
  'connection update audited'
);

select pg_temp.ok(
  not exists(
    select 1
    from information_schema.columns
    where table_schema='public'
      and table_name='sales_app_connections'
      and lower(column_name) in (
        'secret',
        'password',
        'api_key',
        'api_token',
        'access_token',
        'refresh_token',
        'credential',
        'credentials'
      )
  ),
  'credentials are not stored in connection table'
);

do $$
declare
  t text;
  f record;
begin
  foreach t in array array[
    'sales_app_connections',
    'sales_app_sync_runs'
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
      'browser direct access revoked '||t
    );
  end loop;

  perform pg_temp.ok(
    has_table_privilege(
      'service_role',
      'public.sales_app_connections',
      'SELECT'
    ),
    'service role can read connection config'
  );

  perform pg_temp.ok(
    has_table_privilege(
      'service_role',
      'public.sales_app_sync_runs',
      'SELECT,INSERT,UPDATE'
    )
    and
    not has_table_privilege(
      'service_role',
      'public.sales_app_sync_runs',
      'DELETE'
    ),
    'service role sync run grants'
  );

  for f in
    select p.*
    from pg_proc p
    join pg_namespace n
      on n.oid=p.pronamespace
    where n.nspname='public'
      and p.proname in (
        'create_sales_app_connection',
        'update_sales_app_connection',
        'get_sales_app_sync_overview'
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

reset role;

update public.tenant_modules
set enabled=false
where tenant_id=pg_temp.t()
  and module_key='food-service';

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'f1111111-2222-4222-8222-111111111111',
  true
);

select pg_temp.err(
  $q$
  select public.get_sales_app_sync_overview(
    pg_temp.t()
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
  select public.get_sales_app_sync_overview(
    pg_temp.t()
  )
  $q$,
  '42501'
);

set local role anon;

select pg_temp.err(
  $q$
  select public.get_sales_app_sync_overview(
    pg_temp.t()
  )
  $q$,
  '42501'
);

reset role;

rollback;

do $$
begin
  if exists(
    select 1
    from auth.users
    where email like 'sales-sync-%@coost.test'
  )
  or exists(
    select 1
    from public.tenants
    where id in (
      'f1111111-aaaa-4aaa-8aaa-111111111111',
      'f2222222-aaaa-4aaa-8aaa-111111111111'
    )
  )
  then
    raise exception 'RESIDUAL_FIXTURES';
  end if;
end
$$;

select
  'PASS - SALES APP SYNC FOUNDATION' result,
  (
    select count(*)
    from auth.users
    where email like 'sales-sync-%@coost.test'
  ) residual_test_users,
  (
    select count(*)
    from public.tenants
    where id in (
      'f1111111-aaaa-4aaa-8aaa-111111111111',
      'f2222222-aaaa-4aaa-8aaa-111111111111'
    )
  ) residual_test_tenants;