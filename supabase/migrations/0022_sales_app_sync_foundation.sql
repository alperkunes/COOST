-- Sales App automatic synchronization foundation.
-- Provider credentials and provider-specific API behavior are intentionally
-- excluded from this migration.

create table public.sales_app_connections (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  location_id uuid not null,
  provider_key text not null default 'SALES_APP'
    check(provider_key ~ '^[A-Z][A-Z0-9_]{0,63}$'),
  adapter_key text
    check(
      adapter_key is null
      or (
        adapter_key=trim(adapter_key)
        and adapter_key ~ '^[A-Z][A-Z0-9_]{1,63}$'
      )
    ),
  external_location_id text
    check(
      external_location_id is null
      or (
        external_location_id=trim(external_location_id)
        and char_length(external_location_id) between 1 and 200
      )
    ),
  status text not null default 'DRAFT'
    check(status in ('DRAFT','ACTIVE','PAUSED')),
  sync_enabled boolean not null default false,
  sync_lookback_days smallint not null default 1
    check(sync_lookback_days between 1 and 31),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique(id,tenant_id),
  unique(id,tenant_id,location_id,provider_key),
  unique(tenant_id,provider_key,location_id),

  foreign key(location_id,tenant_id)
    references public.locations(id,tenant_id)
    on delete restrict,

  check(not sync_enabled or status='ACTIVE'),

  check(
    status<>'ACTIVE'
    or (
      adapter_key is not null
      and external_location_id is not null
    )
  )
);

create index sales_app_connection_location
  on public.sales_app_connections(location_id,tenant_id);

create index sales_app_connection_status
  on public.sales_app_connections(tenant_id,status,sync_enabled);

create table public.sales_app_sync_runs (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  connection_id uuid not null,
  location_id uuid not null,
  provider_key text not null default 'SALES_APP'
    check(provider_key ~ '^[A-Z][A-Z0-9_]{0,63}$'),

  trigger_type text not null
    check(trigger_type in ('MANUAL','SCHEDULED','RETRY')),

  status text not null default 'QUEUED'
    check(status in ('QUEUED','RUNNING','SUCCEEDED','FAILED','SKIPPED')),

  business_date_start date not null
    check(isfinite(business_date_start)),

  business_date_end date not null
    check(isfinite(business_date_end)),

  requested_by_user_id uuid references auth.users(id) on delete restrict,

  started_at timestamptz,
  finished_at timestamptz,

  import_batch_count integer not null default 0
    check(import_batch_count>=0),

  imported_row_count integer not null default 0
    check(imported_row_count>=0),

  error_code text
    check(
      error_code is null
      or char_length(error_code) between 1 and 120
    ),

  error_message text
    check(
      error_message is null
      or char_length(error_message) between 1 and 1000
    ),

  metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),

  unique(id,tenant_id),

  foreign key(
    connection_id,
    tenant_id,
    location_id,
    provider_key
  )
    references public.sales_app_connections(
      id,
      tenant_id,
      location_id,
      provider_key
    )
    on delete restrict,

  foreign key(location_id,tenant_id)
    references public.locations(id,tenant_id)
    on delete restrict,

  check(
    business_date_end>=business_date_start
    and business_date_end-business_date_start<=31
  ),

  check(
    (status='QUEUED' and started_at is null and finished_at is null)
    or
    (status='RUNNING' and started_at is not null and finished_at is null)
    or
    (status in ('SUCCEEDED','FAILED','SKIPPED') and finished_at is not null)
  ),

  check(
    status<>'SUCCEEDED'
    or (
      error_code is null
      and error_message is null
    )
  )
);

create index sales_app_sync_run_connection
  on public.sales_app_sync_runs(
    connection_id,
    created_at desc
  );

create index sales_app_sync_run_location
  on public.sales_app_sync_runs(
    tenant_id,
    location_id,
    created_at desc
  );

create index sales_app_sync_run_status
  on public.sales_app_sync_runs(
    tenant_id,
    status,
    created_at desc
  );

alter table public.sales_app_connections
  enable row level security;

alter table public.sales_app_sync_runs
  enable row level security;

revoke all
  on public.sales_app_connections,
     public.sales_app_sync_runs
  from public,anon,authenticated;

-- The future server-side adapter may read connection configuration
-- and create/update synchronization runs. Browser clients may not.
grant select
  on public.sales_app_connections
  to service_role;

grant select,insert,update
  on public.sales_app_sync_runs
  to service_role;

create function private.require_sales_app_access(
  p_tenant_id uuid,
  p_permission text,
  p_location_id uuid default null
)
returns void
language plpgsql
security definer
set search_path=''
as $$
begin
  if auth.uid() is null then
    raise exception 'AUTHENTICATION_REQUIRED'
      using errcode='42501';
  end if;

  if not private.is_module_enabled(
    p_tenant_id,
    'food-service'
  ) then
    raise exception 'SALES_APP_MODULE_NOT_AVAILABLE'
      using errcode='42501';
  end if;

  if not private.has_permission(
    p_tenant_id,
    p_permission
  ) then
    raise exception 'SALES_APP_PERMISSION_DENIED'
      using errcode='42501';
  end if;

  if p_location_id is not null
    and not exists(
      select 1
      from public.locations
      where id=p_location_id
        and tenant_id=p_tenant_id
        and status='ACTIVE'
    )
  then
    raise exception 'SALES_APP_LOCATION_NOT_AVAILABLE'
      using errcode='22023';
  end if;
end;
$$;

create function private.guard_sales_app_connection()
returns trigger
language plpgsql
set search_path=''
as $$
begin
  if tg_op='DELETE' then
    raise exception 'SALES_APP_CONNECTION_HARD_DELETE_FORBIDDEN'
      using errcode='55000';
  end if;

  if (
    new.id,
    new.tenant_id,
    new.location_id,
    new.provider_key,
    new.created_at
  )
  is distinct from (
    old.id,
    old.tenant_id,
    old.location_id,
    old.provider_key,
    old.created_at
  )
  then
    raise exception 'SALES_APP_CONNECTION_IDENTITY_IMMUTABLE'
      using errcode='55000';
  end if;

  return new;
end;
$$;

create trigger sales_app_connection_guard
before update or delete
on public.sales_app_connections
for each row
execute function private.guard_sales_app_connection();

create function private.guard_sales_app_sync_run()
returns trigger
language plpgsql
set search_path=''
as $$
begin
  if tg_op='DELETE' then
    raise exception 'SALES_APP_SYNC_HISTORY_IMMUTABLE'
      using errcode='55000';
  end if;

  if old.status in ('SUCCEEDED','FAILED','SKIPPED') then
    raise exception 'SALES_APP_SYNC_HISTORY_IMMUTABLE'
      using errcode='55000';
  end if;

  if (
    new.id,
    new.tenant_id,
    new.connection_id,
    new.location_id,
    new.provider_key,
    new.trigger_type,
    new.business_date_start,
    new.business_date_end,
    new.requested_by_user_id,
    new.created_at
  )
  is distinct from (
    old.id,
    old.tenant_id,
    old.connection_id,
    old.location_id,
    old.provider_key,
    old.trigger_type,
    old.business_date_start,
    old.business_date_end,
    old.requested_by_user_id,
    old.created_at
  )
  then
    raise exception 'SALES_APP_SYNC_IDENTITY_IMMUTABLE'
      using errcode='55000';
  end if;

  if old.status='QUEUED'
    and new.status not in (
      'QUEUED',
      'RUNNING',
      'FAILED',
      'SKIPPED'
    )
  then
    raise exception 'SALES_APP_SYNC_TRANSITION_INVALID'
      using errcode='55000';
  end if;

  if old.status='RUNNING'
    and new.status not in (
      'RUNNING',
      'SUCCEEDED',
      'FAILED'
    )
  then
    raise exception 'SALES_APP_SYNC_TRANSITION_INVALID'
      using errcode='55000';
  end if;

  return new;
end;
$$;

create trigger sales_app_sync_run_guard
before update or delete
on public.sales_app_sync_runs
for each row
execute function private.guard_sales_app_sync_run();

create function public.create_sales_app_connection(
  p_tenant_id uuid,
  p_location_id uuid,
  p_adapter_key text default null,
  p_external_location_id text default null,
  p_sync_lookback_days integer default 1
)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare
  v_id uuid;
begin
  perform private.require_sales_app_access(
    p_tenant_id,
    'food-service.costing.write',
    p_location_id
  );

  p_adapter_key :=
    nullif(upper(trim(p_adapter_key)),'');

  p_external_location_id :=
    nullif(trim(p_external_location_id),'');

  if p_sync_lookback_days is null
    or p_sync_lookback_days not between 1 and 31
    or (
      p_adapter_key is not null
      and p_adapter_key !~ '^[A-Z][A-Z0-9_]{1,63}$'
    )
    or char_length(p_external_location_id)>200
  then
    raise exception 'SALES_APP_CONNECTION_INVALID'
      using errcode='22023';
  end if;

  insert into public.sales_app_connections(
    tenant_id,
    location_id,
    adapter_key,
    external_location_id,
    status,
    sync_enabled,
    sync_lookback_days
  )
  values(
    p_tenant_id,
    p_location_id,
    p_adapter_key,
    p_external_location_id,
    'DRAFT',
    false,
    p_sync_lookback_days
  )
  returning id into v_id;

  insert into public.audit_logs(
    tenant_id,
    location_id,
    actor_user_id,
    action,
    entity_type,
    entity_id,
    metadata
  )
  values(
    p_tenant_id,
    p_location_id,
    auth.uid(),
    'SALES_APP_CONNECTION_CREATED',
    'sales_app_connection',
    v_id,
    jsonb_build_object(
      'providerKey','SALES_APP',
      'adapterConfigured',p_adapter_key is not null,
      'externalLocationConfigured',
        p_external_location_id is not null,
      'syncLookbackDays',p_sync_lookback_days
    )
  );

  return v_id;

exception
  when unique_violation then
    raise exception 'SALES_APP_CONNECTION_EXISTS'
      using errcode='23505';
end;
$$;

create function public.update_sales_app_connection(
  p_tenant_id uuid,
  p_connection_id uuid,
  p_adapter_key text,
  p_external_location_id text,
  p_status text,
  p_sync_enabled boolean,
  p_sync_lookback_days integer
)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare
  old public.sales_app_connections%rowtype;
  v_adapter_key text;
  v_external_location_id text;
begin
  perform private.require_sales_app_access(
    p_tenant_id,
    'food-service.costing.write'
  );

  select *
  into old
  from public.sales_app_connections
  where id=p_connection_id
    and tenant_id=p_tenant_id
  for update;

  if not found then
    raise exception 'SALES_APP_CONNECTION_NOT_AVAILABLE'
      using errcode='22023';
  end if;

  perform private.require_sales_app_access(
    p_tenant_id,
    'food-service.costing.write',
    old.location_id
  );

  v_adapter_key :=
    nullif(upper(trim(p_adapter_key)),'');

  v_external_location_id :=
    nullif(trim(p_external_location_id),'');

  if p_status is null
    or p_status not in ('DRAFT','ACTIVE','PAUSED')
    or p_sync_enabled is null
    or p_sync_lookback_days is null
    or p_sync_lookback_days not between 1 and 31
    or (
      v_adapter_key is not null
      and v_adapter_key !~ '^[A-Z][A-Z0-9_]{1,63}$'
    )
    or char_length(v_external_location_id)>200
    or (
      p_status='ACTIVE'
      and (
        v_adapter_key is null
        or v_external_location_id is null
      )
    )
    or (
      p_sync_enabled
      and p_status<>'ACTIVE'
    )
  then
    raise exception 'SALES_APP_CONNECTION_INVALID'
      using errcode='22023';
  end if;

  if (
    old.adapter_key,
    old.external_location_id,
    old.status,
    old.sync_enabled,
    old.sync_lookback_days
  )
  is not distinct from (
    v_adapter_key,
    v_external_location_id,
    p_status,
    p_sync_enabled,
    p_sync_lookback_days
  )
  then
    return old.id;
  end if;

  update public.sales_app_connections
  set
    adapter_key=v_adapter_key,
    external_location_id=v_external_location_id,
    status=p_status,
    sync_enabled=p_sync_enabled,
    sync_lookback_days=p_sync_lookback_days,
    updated_at=now()
  where id=old.id;

  insert into public.audit_logs(
    tenant_id,
    location_id,
    actor_user_id,
    action,
    entity_type,
    entity_id,
    metadata
  )
  values(
    p_tenant_id,
    old.location_id,
    auth.uid(),
    'SALES_APP_CONNECTION_UPDATED',
    'sales_app_connection',
    old.id,
    jsonb_build_object(
      'old',
        jsonb_build_object(
          'adapterConfigured',
            old.adapter_key is not null,
          'externalLocationConfigured',
            old.external_location_id is not null,
          'status',old.status,
          'syncEnabled',old.sync_enabled,
          'syncLookbackDays',old.sync_lookback_days
        ),
      'new',
        jsonb_build_object(
          'adapterConfigured',
            v_adapter_key is not null,
          'externalLocationConfigured',
            v_external_location_id is not null,
          'status',p_status,
          'syncEnabled',p_sync_enabled,
          'syncLookbackDays',p_sync_lookback_days
        )
    )
  );

  return old.id;
end;
$$;

create function public.get_sales_app_sync_overview(
  p_tenant_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  perform private.require_sales_app_access(
    p_tenant_id,
    'food-service.costing.read'
  );

  return jsonb_build_object(
    'tenantId',p_tenant_id,
    'providerKey','SALES_APP',

    'locations',
      (
        select coalesce(
          jsonb_agg(
            jsonb_build_object(
              'id',l.id,
              'name',l.name
            )
            order by l.name,l.id
          ),
          '[]'::jsonb
        )
        from public.locations l
        where l.tenant_id=p_tenant_id
          and l.status='ACTIVE'
      ),

    'connections',
      (
        select coalesce(
          jsonb_agg(
            jsonb_build_object(
              'id',c.id,
              'locationId',c.location_id,
              'locationName',l.name,
              'providerKey',c.provider_key,
              'adapterKey',c.adapter_key,
              'externalLocationId',c.external_location_id,
              'status',c.status,
              'syncEnabled',c.sync_enabled,
              'syncLookbackDays',c.sync_lookback_days,
              'createdAt',c.created_at,
              'updatedAt',c.updated_at
            )
            order by l.name,c.id
          ),
          '[]'::jsonb
        )
        from public.sales_app_connections c
        join public.locations l
          on l.id=c.location_id
         and l.tenant_id=c.tenant_id
        where c.tenant_id=p_tenant_id
          and c.provider_key='SALES_APP'
      ),

    'recentRuns',
      (
        select coalesce(
          jsonb_agg(
            jsonb_build_object(
              'id',r.id,
              'connectionId',r.connection_id,
              'locationId',r.location_id,
              'locationName',l.name,
              'triggerType',r.trigger_type,
              'status',r.status,
              'businessDateStart',r.business_date_start,
              'businessDateEnd',r.business_date_end,
              'startedAt',r.started_at,
              'finishedAt',r.finished_at,
              'importBatchCount',r.import_batch_count,
              'importedRowCount',r.imported_row_count,
              'errorCode',r.error_code,
              'errorMessage',r.error_message,
              'createdAt',r.created_at
            )
            order by r.created_at desc,r.id desc
          ),
          '[]'::jsonb
        )
        from (
          select *
          from public.sales_app_sync_runs
          where tenant_id=p_tenant_id
            and provider_key='SALES_APP'
          order by created_at desc,id desc
          limit 100
        ) r
        join public.locations l
          on l.id=r.location_id
         and l.tenant_id=r.tenant_id
      )
  );
end;
$$;

revoke all
  on function private.require_sales_app_access(uuid,text,uuid),
     private.guard_sales_app_connection(),
     private.guard_sales_app_sync_run()
  from public,anon,authenticated;

revoke all
  on function public.create_sales_app_connection(
       uuid,uuid,text,text,integer
     ),
     public.update_sales_app_connection(
       uuid,uuid,text,text,text,boolean,integer
     ),
     public.get_sales_app_sync_overview(uuid)
  from public,anon;

grant execute
  on function public.create_sales_app_connection(
       uuid,uuid,text,text,integer
     ),
     public.update_sales_app_connection(
       uuid,uuid,text,text,text,boolean,integer
     ),
     public.get_sales_app_sync_overview(uuid)
  to authenticated,service_role;