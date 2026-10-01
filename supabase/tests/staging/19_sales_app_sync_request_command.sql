begin;

-- Test-only: allow authenticated to execute pg_temp helpers created in this
-- transaction. ROLLBACK at the end restores the hardened production defaults.
alter default privileges for role postgres
  grant execute on functions to anon, authenticated;

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
  select 'f3333333-aaaa-4aaa-8aaa-111111111111'::uuid
$$;

create function pg_temp.loc()
returns uuid
language sql
as $$
  select 'f3333333-7777-4777-8777-111111111111'::uuid
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
  'f3333333-1111-4111-8111-111111111111',
  'authenticated',
  'authenticated',
  'sync-request-manager@coost.test'
),
(
  'f3333333-2222-4222-8222-111111111111',
  'authenticated',
  'authenticated',
  'sync-request-reader@coost.test'
);

insert into public.tenants(id,name,status)
values(
  pg_temp.t(),
  'Sales Sync Request Test',
  'ACTIVE'
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
  'Nazilli',
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
  'f3333333-3333-4333-8333-111111111111',
  pg_temp.t(),
  'f3333333-1111-4111-8111-111111111111',
  'ACTIVE'
),
(
  'f3333333-4444-4444-8444-111111111111',
  pg_temp.t(),
  'f3333333-2222-4222-8222-111111111111',
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
  'f3333333-5555-4555-8555-111111111111',
  pg_temp.t(),
  'manager',
  'Manager'
),
(
  'f3333333-6666-4666-8666-111111111111',
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
  'f3333333-3333-4333-8333-111111111111',
  'f3333333-5555-4555-8555-111111111111'
),
(
  pg_temp.t(),
  'f3333333-4444-4444-8444-111111111111',
  'f3333333-6666-4666-8666-111111111111'
);

insert into public.role_permissions(
  tenant_id,
  role_id,
  permission_key
)
select
  pg_temp.t(),
  'f3333333-5555-4555-8555-111111111111',
  unnest(array[
    'food-service.costing.read',
    'food-service.costing.write'
  ]);

insert into public.role_permissions(
  tenant_id,
  role_id,
  permission_key
)
values(
  pg_temp.t(),
  'f3333333-6666-4666-8666-111111111111',
  'food-service.costing.read'
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

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'f3333333-1111-4111-8111-111111111111',
  true
);

select set_config(
  'test.connection',
  public.create_sales_app_connection(
    pg_temp.t(),
    pg_temp.loc(),
    'GENERIC_TEST',
    'EXT-NAZILLI-01',
    1
  )::text,
  true
);

select public.update_sales_app_connection(
  pg_temp.t(),
  pg_temp.id('connection'),
  'GENERIC_TEST',
  'EXT-NAZILLI-01',
  'ACTIVE',
  false,
  1
);

select set_config(
  'test.run',
  public.request_sales_app_sync(
    pg_temp.t(),
    pg_temp.id('connection'),
    '2026-09-27',
    '2026-09-28'
  )::text,
  true
);

select pg_temp.ok(
  exists(
    select 1
    from jsonb_array_elements(
      public.get_sales_app_sync_overview(
        pg_temp.t()
      )->'recentRuns'
    ) r
    where r->>'id'=pg_temp.id('run')::text
      and r->>'status'='QUEUED'
      and r->>'triggerType'='MANUAL'
      and r->>'businessDateStart'='2026-09-27'
      and r->>'businessDateEnd'='2026-09-28'
  ),
  'manual sync request queued'
);

select pg_temp.err(
  format(
    'select public.request_sales_app_sync(%L,%L,%L,%L)',
    pg_temp.t(),
    pg_temp.id('connection'),
    '2026-09-27',
    '2026-09-28'
  ),
  '55000'
);

select pg_temp.err(
  format(
    'select public.request_sales_app_sync(%L,%L,%L,%L)',
    pg_temp.t(),
    pg_temp.id('connection'),
    '2026-09-29',
    '2026-09-28'
  ),
  '22023'
);

select pg_temp.err(
  format(
    'select public.request_sales_app_sync(%L,%L,%L,%L)',
    pg_temp.t(),
    pg_temp.id('connection'),
    '2026-08-01',
    '2026-09-28'
  ),
  '22023'
);

select set_config(
  'request.jwt.claim.sub',
  'f3333333-2222-4222-8222-111111111111',
  true
);

select pg_temp.err(
  format(
    'select public.request_sales_app_sync(%L,%L,%L,%L)',
    pg_temp.t(),
    pg_temp.id('connection'),
    '2026-09-27',
    '2026-09-28'
  ),
  '42501'
);

reset role;

select pg_temp.ok(
  (
    select
      status='QUEUED'
      and trigger_type='MANUAL'
      and requested_by_user_id=
        'f3333333-1111-4111-8111-111111111111'::uuid
    from public.sales_app_sync_runs
    where id=pg_temp.id('run')
  ),
  'queued run preserves requesting user'
);

select pg_temp.ok(
  (
    select count(*)=1
    from public.audit_logs
    where tenant_id=pg_temp.t()
      and action='SALES_APP_SYNC_REQUESTED'
      and entity_id=pg_temp.id('run')
  ),
  'manual sync request audited'
);

update public.sales_app_sync_runs
set
  status='FAILED',
  finished_at=clock_timestamp(),
  error_code='TEST_FAILURE',
  error_message='Expected test failure'
where id=pg_temp.id('run');

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'f3333333-1111-4111-8111-111111111111',
  true
);

select set_config(
  'test.second_run',
  public.request_sales_app_sync(
    pg_temp.t(),
    pg_temp.id('connection'),
    '2026-09-28',
    '2026-09-28'
  )::text,
  true
);

select pg_temp.ok(
  pg_temp.id('second_run') <> pg_temp.id('run'),
  'new run allowed after terminal state'
);

select public.update_sales_app_connection(
  pg_temp.t(),
  pg_temp.id('connection'),
  'GENERIC_TEST',
  'EXT-NAZILLI-01',
  'PAUSED',
  false,
  1
);

reset role;

update public.sales_app_sync_runs
set
  status='FAILED',
  finished_at=clock_timestamp(),
  error_code='TEST_FINISHED',
  error_message='Expected test terminal state'
where id=pg_temp.id('second_run');

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'f3333333-1111-4111-8111-111111111111',
  true
);

select pg_temp.err(
  format(
    'select public.request_sales_app_sync(%L,%L,%L,%L)',
    pg_temp.t(),
    pg_temp.id('connection'),
    '2026-09-28',
    '2026-09-28'
  ),
  '22023'
);

reset role;

do $$
declare
  f record;
begin
  select p.*
  into f
  from pg_proc p
  join pg_namespace n
    on n.oid=p.pronamespace
  where n.nspname='public'
    and p.proname='request_sales_app_sync';

  perform pg_temp.ok(
    f.prosecdef
    and 'search_path=""'=any(f.proconfig),
    'request RPC is secure definer'
  );

  perform pg_temp.ok(
    has_function_privilege(
      'authenticated',
      f.oid,
      'EXECUTE'
    ),
    'authenticated may execute request RPC'
  );

  perform pg_temp.ok(
    not has_function_privilege(
      'anon',
      f.oid,
      'EXECUTE'
    ),
    'anon cannot execute request RPC'
  );

  perform pg_temp.ok(
    not exists(
      select 1
      from aclexplode(f.proacl)
      where grantee=0
        and privilege_type='EXECUTE'
    ),
    'PUBLIC execute revoked'
  );
end
$$;

rollback;

do $$
begin
  if exists(
    select 1
    from auth.users
    where email like 'sync-request-%@coost.test'
  )
  or exists(
    select 1
    from public.tenants
    where id=
      'f3333333-aaaa-4aaa-8aaa-111111111111'
  )
  then
    raise exception 'RESIDUAL_FIXTURES';
  end if;
end
$$;

select
  'PASS - SALES APP SYNC REQUEST COMMAND' result,
  (
    select count(*)
    from auth.users
    where email like 'sync-request-%@coost.test'
  ) residual_test_users,
  (
    select count(*)
    from public.tenants
    where id=
      'f3333333-aaaa-4aaa-8aaa-111111111111'
  ) residual_test_tenants;