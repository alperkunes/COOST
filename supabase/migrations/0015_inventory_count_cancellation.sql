-- Keep all count lines/history. Cancellation never writes to the movement ledger.
alter table public.inventory_counts
  add column cancelled_at timestamptz,
  add column cancelled_by uuid references auth.users(id) on delete restrict,
  drop constraint inventory_counts_status_check,
  drop constraint inventory_counts_check,
  add constraint inventory_counts_status_check check (status in ('DRAFT','POSTED','CANCELLED')),
  add constraint inventory_counts_state_check check (
    (status = 'DRAFT' and posted_at is null and posted_by is null and cancelled_at is null and cancelled_by is null)
    or (status = 'POSTED' and posted_at is not null and posted_by is not null and cancelled_at is null and cancelled_by is null)
    or (status = 'CANCELLED' and cancelled_at is not null and cancelled_by is not null and posted_at is null and posted_by is null)
  );
-- Fail safely on existing duplicate drafts; never silently cancel or delete user data.
create unique index inventory_counts_one_draft on public.inventory_counts(tenant_id,location_id) where status = 'DRAFT';

create or replace function private.guard_inventory_count() returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'DELETE' or old.status <> 'DRAFT' then raise exception 'INVENTORY_COUNT_IMMUTABLE' using errcode = '55000'; end if;
  if (new.id,new.tenant_id,new.location_id) is distinct from (old.id,old.tenant_id,old.location_id) then
    raise exception 'INVENTORY_COUNT_IMMUTABLE' using errcode = '55000'; end if;
  return new;
end; $$;
create or replace function private.guard_inventory_count_line() returns trigger language plpgsql security definer set search_path = '' as $$
declare v_status text;
begin
  if tg_op = 'DELETE' then raise exception 'INVENTORY_COUNT_IMMUTABLE' using errcode = '55000'; end if;
  if tg_op = 'UPDATE' and (new.id,new.count_id,new.tenant_id,new.inventory_item_id) is distinct from (old.id,old.count_id,old.tenant_id,old.inventory_item_id) then
    raise exception 'INVENTORY_COUNT_IMMUTABLE' using errcode = '55000'; end if;
  select status into v_status from public.inventory_counts where id = new.count_id and tenant_id = new.tenant_id for update;
  if v_status <> 'DRAFT' then raise exception 'INVENTORY_COUNT_IMMUTABLE' using errcode = '55000'; end if;
  return new;
end; $$;

create function public.cancel_inventory_count(p_tenant_id uuid,p_count_id uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare c public.inventory_counts%rowtype;
begin
  perform private.require_inventory_access(p_tenant_id,'inventory.count');
  select * into c from public.inventory_counts where id = p_count_id and tenant_id = p_tenant_id for update;
  if not found then raise exception 'INVENTORY_COUNT_NOT_AVAILABLE' using errcode = '22023'; end if;
  if c.status <> 'DRAFT' then raise exception 'INVENTORY_COUNT_IMMUTABLE' using errcode = '55000'; end if;
  update public.inventory_counts set status = 'CANCELLED',cancelled_at = now(),cancelled_by = auth.uid() where id = p_count_id;
  insert into public.audit_logs(tenant_id,location_id,actor_user_id,action,entity_type,entity_id,metadata)
    values(p_tenant_id,c.location_id,auth.uid(),'INVENTORY_COUNT_CANCELLED','inventory_count',p_count_id,
      jsonb_build_object('countId',p_count_id,'locationId',c.location_id));
  return p_count_id;
end; $$;
revoke all on function public.cancel_inventory_count(uuid,uuid) from public,anon;
grant execute on function public.cancel_inventory_count(uuid,uuid) to authenticated,service_role;

create or replace function public.create_inventory_count(p_tenant_id uuid,p_location_id uuid,p_notes text default null,p_counted_at timestamptz default now())
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_constraint text;
begin
  perform private.require_inventory_access(p_tenant_id,'inventory.count');
  if char_length(trim(p_notes)) > 2000 or p_counted_at is null or not isfinite(p_counted_at) then raise exception 'INVENTORY_COUNT_INVALID' using errcode = '22023'; end if;
  if exists(select 1 from public.inventory_counts where tenant_id = p_tenant_id and location_id = p_location_id and status = 'DRAFT') then
    raise exception 'INVENTORY_COUNT_ALREADY_OPEN' using errcode = '23505'; end if;
  -- Consistent lock order with posting. New cards created afterwards belong to a later count.
  perform 1 from public.inventory_items where tenant_id = p_tenant_id and status = 'ACTIVE' order by id for update;
  if not found then raise exception 'INVENTORY_ITEMS_REQUIRED' using errcode = '22023'; end if;
  perform private.inventory_location(p_tenant_id,p_location_id);
  insert into public.inventory_counts(tenant_id,location_id,notes,counted_at,created_by)
    values(p_tenant_id,p_location_id,nullif(trim(p_notes),''),p_counted_at,auth.uid()) returning id into v_id;
  insert into public.inventory_count_lines(tenant_id,count_id,inventory_item_id,system_quantity)
    select p_tenant_id,v_id,i.id,coalesce((select sum(m.quantity) from public.inventory_movements m where m.tenant_id = p_tenant_id and m.location_id = p_location_id and m.inventory_item_id = i.id),0)
    from public.inventory_items i where i.tenant_id = p_tenant_id and i.status = 'ACTIVE';
  insert into public.audit_logs(tenant_id,location_id,actor_user_id,action,entity_type,entity_id,metadata)
    values(p_tenant_id,p_location_id,auth.uid(),'INVENTORY_COUNT_CREATED','inventory_count',v_id,jsonb_build_object('countId',v_id,'locationId',p_location_id,'lineCount',(select count(*) from public.inventory_count_lines where count_id = v_id)));
  return v_id;
exception when unique_violation then
  get stacked diagnostics v_constraint = constraint_name;
  if v_constraint = 'inventory_counts_one_draft' then raise exception 'INVENTORY_COUNT_ALREADY_OPEN' using errcode = '23505'; end if;
  raise;
end; $$;

create or replace function public.get_inventory_counts(p_tenant_id uuid) returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if private.has_permission(p_tenant_id,'inventory.read') then perform private.require_inventory_access(p_tenant_id,'inventory.read');
  else perform private.require_inventory_access(p_tenant_id,'inventory.count'); end if;
  return jsonb_build_object('tenantId',p_tenant_id,'counts',(select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'locationId',c.location_id,'locationName',l.name,'status',c.status,'countedAt',c.counted_at,'notes',c.notes,'postedAt',c.posted_at,'cancelledAt',c.cancelled_at,'cancelledBy',c.cancelled_by) order by c.created_at desc,c.id desc),'[]')
    from (select * from public.inventory_counts where tenant_id = p_tenant_id order by created_at desc,id desc limit 50) c join public.locations l on l.id = c.location_id));
end; $$;

create or replace function public.get_inventory_count_detail(p_tenant_id uuid,p_count_id uuid) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare c public.inventory_counts%rowtype;
begin
  if private.has_permission(p_tenant_id,'inventory.read') then perform private.require_inventory_access(p_tenant_id,'inventory.read');
  else perform private.require_inventory_access(p_tenant_id,'inventory.count'); end if;
  select * into c from public.inventory_counts where id = p_count_id and tenant_id = p_tenant_id;
  if not found then raise exception 'INVENTORY_COUNT_NOT_AVAILABLE' using errcode = '22023'; end if;
  return jsonb_build_object('tenantId',p_tenant_id,'id',c.id,'locationId',c.location_id,'status',c.status,'countedAt',c.counted_at,'notes',c.notes,'postedAt',c.posted_at,'cancelledAt',c.cancelled_at,'cancelledBy',c.cancelled_by,
    'lines',(select coalesce(jsonb_agg(jsonb_build_object('itemId',i.id,'itemName',i.name,'baseUnit',i.base_unit,'systemQuantity',l.system_quantity,'countedQuantity',l.counted_quantity,'difference',l.difference) order by i.name,i.id),'[]')
      from public.inventory_count_lines l join public.inventory_items i on i.id = l.inventory_item_id where l.count_id = p_count_id));
end; $$;
