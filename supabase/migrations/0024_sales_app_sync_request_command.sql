-- User-authorized manual Sales App synchronization request command.
-- Provider-specific API calls remain in the Edge Function adapter layer.

alter table public.sales_app_sync_runs
  add constraint sales_app_sync_manual_actor_check
  check(
    trigger_type <> 'MANUAL'
    or requested_by_user_id is not null
  );

create unique index sales_app_sync_one_active_run
  on public.sales_app_sync_runs(
    tenant_id,
    connection_id
  )
  where status in ('QUEUED','RUNNING');

create function public.request_sales_app_sync(
  p_tenant_id uuid,
  p_connection_id uuid,
  p_business_date_start date,
  p_business_date_end date
)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare
  c public.sales_app_connections%rowtype;
  v_id uuid;
begin
  perform private.require_sales_app_access(
    p_tenant_id,
    'food-service.costing.write'
  );

  if p_business_date_start is null
    or p_business_date_end is null
    or not isfinite(p_business_date_start)
    or not isfinite(p_business_date_end)
    or p_business_date_end < p_business_date_start
    or p_business_date_end - p_business_date_start > 31
  then
    raise exception 'SALES_APP_SYNC_PERIOD_INVALID'
      using errcode='22023';
  end if;

  perform 1
  from public.tenants
  where id=p_tenant_id
  for update;

  select *
  into c
  from public.sales_app_connections
  where id=p_connection_id
    and tenant_id=p_tenant_id
  for share;

  if not found then
    raise exception 'SALES_APP_CONNECTION_NOT_AVAILABLE'
      using errcode='22023';
  end if;

  perform private.require_sales_app_access(
    p_tenant_id,
    'food-service.costing.write',
    c.location_id
  );

  if c.provider_key <> 'SALES_APP'
    or c.status <> 'ACTIVE'
    or c.adapter_key is null
    or c.external_location_id is null
  then
    raise exception 'SALES_APP_CONNECTION_NOT_READY'
      using errcode='22023';
  end if;

  insert into public.sales_app_sync_runs(
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
    p_tenant_id,
    c.id,
    c.location_id,
    c.provider_key,
    'MANUAL',
    'QUEUED',
    p_business_date_start,
    p_business_date_end,
    auth.uid()
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
    c.location_id,
    auth.uid(),
    'SALES_APP_SYNC_REQUESTED',
    'sales_app_sync_run',
    v_id,
    jsonb_build_object(
      'connectionId',c.id,
      'providerKey',c.provider_key,
      'adapterKey',c.adapter_key,
      'businessDateStart',p_business_date_start,
      'businessDateEnd',p_business_date_end,
      'triggerType','MANUAL'
    )
  );

  return v_id;

exception
  when unique_violation then
    raise exception 'SALES_APP_SYNC_ALREADY_ACTIVE'
      using errcode='55000';
end;
$$;

revoke all
  on function public.request_sales_app_sync(
    uuid,uuid,date,date
  )
  from public,anon;

grant execute
  on function public.request_sales_app_sync(
    uuid,uuid,date,date
  )
  to authenticated;