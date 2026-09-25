-- Quantities are base units. No current_stock column, cash movement or automatic invoice receipt.
create table public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  name text not null check (name = trim(name) and char_length(name) between 2 and 160),
  sku text check (char_length(sku) between 1 and 100 and sku = trim(sku)),
  category text check (char_length(category) <= 120),
  base_unit text not null check (base_unit in ('GRAM','MILLILITER','EACH')),
  critical_stock numeric(16,4) check (critical_stock >= 0 and critical_stock <> 'NaN'::numeric),
  status text not null default 'ACTIVE' check (status in ('ACTIVE','PASSIVE')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique (id,tenant_id)
);
create unique index inventory_items_name on public.inventory_items(tenant_id,lower(regexp_replace(trim(name),'[[:space:]]+',' ','g')));
create unique index inventory_items_sku on public.inventory_items(tenant_id,lower(sku)) where sku is not null;
create table public.inventory_movements (
  id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete restrict,
  location_id uuid not null, inventory_item_id uuid not null,
  movement_type text not null check (movement_type in ('RECEIPT','ISSUE','WASTE','COMPLIMENTARY','COUNT_ADJUSTMENT','MANUAL_ADJUSTMENT')),
  quantity numeric(16,4) not null check (quantity <> 0 and quantity <> 'NaN'::numeric),
  occurred_at timestamptz not null default now() check (isfinite(occurred_at)),
  description text not null check (char_length(trim(description)) between 2 and 500),
  source_type text, source_id uuid,
  created_by_user_id uuid not null references auth.users(id) on delete restrict, created_at timestamptz not null default now(),
  foreign key (inventory_item_id,tenant_id) references public.inventory_items(id,tenant_id) on delete restrict,
  foreign key (location_id,tenant_id) references public.locations(id,tenant_id) on delete restrict,
  check ((movement_type = 'RECEIPT' and quantity > 0) or (movement_type in ('ISSUE','WASTE','COMPLIMENTARY') and quantity < 0)
    or movement_type in ('COUNT_ADJUSTMENT','MANUAL_ADJUSTMENT')),
  check (movement_type <> 'COUNT_ADJUSTMENT' or (source_type = 'INVENTORY_COUNT' and source_id is not null))
);
create index inventory_movement_balance on public.inventory_movements(tenant_id,inventory_item_id,location_id);
create index inventory_movement_recent on public.inventory_movements(tenant_id,occurred_at desc,id desc);
create unique index inventory_count_movement on public.inventory_movements(tenant_id,source_id,inventory_item_id) where movement_type = 'COUNT_ADJUSTMENT';
create table public.inventory_counts (
  id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete restrict,
  location_id uuid not null, status text not null default 'DRAFT' check (status in ('DRAFT','POSTED')),
  counted_at timestamptz not null default now() check (isfinite(counted_at)), notes text check (char_length(notes) <= 2000),
  created_by uuid not null references auth.users(id) on delete restrict, created_at timestamptz not null default now(),
  posted_by uuid references auth.users(id) on delete restrict, posted_at timestamptz,
  unique(id,tenant_id), foreign key(location_id,tenant_id) references public.locations(id,tenant_id) on delete restrict,
  check ((status = 'DRAFT' and posted_at is null and posted_by is null) or (status = 'POSTED' and posted_at is not null and posted_by is not null))
);
create index inventory_counts_recent on public.inventory_counts(tenant_id,created_at desc,id desc);
create table public.inventory_count_lines (
  id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete restrict,
  count_id uuid not null, inventory_item_id uuid not null,
  system_quantity numeric(16,4) not null check (system_quantity <> 'NaN'::numeric),
  counted_quantity numeric(16,4) check (counted_quantity >= 0 and counted_quantity <> 'NaN'::numeric),
  difference numeric(16,4),
  unique(count_id,inventory_item_id),
  foreign key(count_id,tenant_id) references public.inventory_counts(id,tenant_id) on delete restrict,
  foreign key(inventory_item_id,tenant_id) references public.inventory_items(id,tenant_id) on delete restrict,
  check (difference is not distinct from (counted_quantity - system_quantity))
);
alter table public.purchase_invoice_lines add constraint purchase_invoice_inventory_item_tenant_fk
  foreign key(inventory_item_id,tenant_id) references public.inventory_items(id,tenant_id) on delete restrict;
create index purchase_invoice_inventory_item on public.purchase_invoice_lines(inventory_item_id,tenant_id) where inventory_item_id is not null;
comment on column public.purchase_invoice_lines.inventory_item_id is 'Tenant-safe inventory mapping only. Invoice units require future purchase-unit conversions; posting does not create stock movements.';

alter table public.inventory_items enable row level security;
alter table public.inventory_movements enable row level security;
alter table public.inventory_counts enable row level security;
alter table public.inventory_count_lines enable row level security;
revoke all on public.inventory_items,public.inventory_movements,public.inventory_counts,public.inventory_count_lines from public,anon,authenticated;
grant select on public.inventory_items,public.inventory_movements,public.inventory_counts,public.inventory_count_lines to authenticated;
create policy inventory_items_read on public.inventory_items for select to authenticated using (private.is_module_enabled(tenant_id,'inventory') and private.has_permission(tenant_id,'inventory.read'));
create policy inventory_movements_read on public.inventory_movements for select to authenticated using (private.is_module_enabled(tenant_id,'inventory') and private.has_permission(tenant_id,'inventory.read'));
create policy inventory_counts_read on public.inventory_counts for select to authenticated using (private.is_module_enabled(tenant_id,'inventory') and private.has_permission(tenant_id,'inventory.read'));
create policy inventory_count_lines_read on public.inventory_count_lines for select to authenticated using (private.is_module_enabled(tenant_id,'inventory') and private.has_permission(tenant_id,'inventory.read'));

create function private.require_inventory_access(p_tenant_id uuid,p_permission text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501'; end if;
  if not private.is_module_enabled(p_tenant_id,'inventory') then raise exception 'INVENTORY_MODULE_NOT_AVAILABLE' using errcode = '42501'; end if;
  if not private.has_permission(p_tenant_id,p_permission) then raise exception 'INVENTORY_PERMISSION_DENIED' using errcode = '42501'; end if;
end; $$;
create function private.inventory_quantity(p_quantity numeric,p_zero boolean default false) returns numeric
language plpgsql immutable set search_path = '' as $$
begin
  if p_quantity is null or p_quantity = 'NaN'::numeric or p_quantity < 0 or (not p_zero and p_quantity = 0)
    or p_quantity > 999999999999.9999 or p_quantity <> round(p_quantity,4) then
    raise exception 'INVENTORY_QUANTITY_INVALID' using errcode = '22023'; end if;
  return p_quantity;
end; $$;
create function private.inventory_location(p_tenant_id uuid,p_location_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.locations where id = p_location_id and tenant_id = p_tenant_id and status = 'ACTIVE' for share;
  if not found then raise exception 'INVENTORY_LOCATION_NOT_AVAILABLE' using errcode = '22023'; end if;
end; $$;
create function private.guard_inventory_item() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'DELETE' then raise exception 'INVENTORY_HISTORY_IMMUTABLE' using errcode = '55000'; end if;
  if (new.id,new.tenant_id,new.base_unit) is distinct from (old.id,old.tenant_id,old.base_unit) then
    raise exception 'INVENTORY_BASE_UNIT_IMMUTABLE' using errcode = '55000'; end if;
  if new.status = 'PASSIVE' and old.status = 'ACTIVE' and exists(select 1 from public.inventory_movements
    where tenant_id = old.tenant_id and inventory_item_id = old.id group by location_id having sum(quantity) <> 0) then
    raise exception 'INVENTORY_NONZERO_STOCK' using errcode = '22023'; end if;
  return new;
end; $$;
create trigger inventory_item_guard before update or delete on public.inventory_items for each row execute function private.guard_inventory_item();
create function private.guard_inventory_movement() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op <> 'INSERT' then raise exception 'INVENTORY_HISTORY_IMMUTABLE' using errcode = '55000'; end if;
  -- Every insert locks its item, serializing movements, count posting and deactivation.
  perform 1 from public.inventory_items where id = new.inventory_item_id and tenant_id = new.tenant_id and status = 'ACTIVE' for update;
  if not found then raise exception 'INVENTORY_ITEM_NOT_AVAILABLE' using errcode = '22023'; end if;
  perform private.inventory_location(new.tenant_id,new.location_id);
  return new;
end; $$;
create trigger inventory_movement_guard before insert or update or delete on public.inventory_movements for each row execute function private.guard_inventory_movement();
create function private.guard_inventory_count() returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'DELETE' or old.status = 'POSTED' then raise exception 'INVENTORY_COUNT_IMMUTABLE' using errcode = '55000'; end if;
  if (new.id,new.tenant_id,new.location_id) is distinct from (old.id,old.tenant_id,old.location_id) then
    raise exception 'INVENTORY_COUNT_IMMUTABLE' using errcode = '55000'; end if;
  return new;
end; $$;
create trigger inventory_count_guard before update or delete on public.inventory_counts for each row execute function private.guard_inventory_count();
create function private.guard_inventory_count_line() returns trigger language plpgsql security definer set search_path = '' as $$
declare v_status text;
begin
  if tg_op = 'DELETE' then raise exception 'INVENTORY_COUNT_IMMUTABLE' using errcode = '55000'; end if;
  if tg_op = 'UPDATE' and (new.id,new.count_id,new.tenant_id,new.inventory_item_id) is distinct from (old.id,old.count_id,old.tenant_id,old.inventory_item_id) then
    raise exception 'INVENTORY_COUNT_IMMUTABLE' using errcode = '55000'; end if;
  select status into v_status from public.inventory_counts where id = new.count_id and tenant_id = new.tenant_id for update;
  if v_status = 'POSTED' then raise exception 'INVENTORY_COUNT_IMMUTABLE' using errcode = '55000'; end if;
  return new;
end; $$;
create trigger inventory_count_line_guard before insert or update or delete on public.inventory_count_lines for each row execute function private.guard_inventory_count_line();

create function public.create_inventory_item(p_tenant_id uuid,p_name text,p_base_unit text,p_sku text default null,p_category text default null,p_critical_stock numeric default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_name text := trim(p_name); v_sku text := nullif(trim(p_sku),''); v_category text := nullif(trim(p_category),'');
begin
  perform private.require_inventory_access(p_tenant_id,'inventory.write');
  if v_name is null or char_length(v_name) not between 2 and 160 or char_length(v_sku) > 100 or char_length(v_category) > 120
    or p_base_unit is null or p_base_unit not in ('GRAM','MILLILITER','EACH') then raise exception 'INVENTORY_ITEM_INVALID' using errcode = '22023'; end if;
  if p_critical_stock is not null then perform private.inventory_quantity(p_critical_stock,true); end if;
  insert into public.inventory_items(tenant_id,name,sku,category,base_unit,critical_stock)
    values(p_tenant_id,v_name,v_sku,v_category,p_base_unit,p_critical_stock) returning id into v_id;
  insert into public.audit_logs(tenant_id,actor_user_id,action,entity_type,entity_id,metadata)
    values(p_tenant_id,auth.uid(),'INVENTORY_ITEM_CREATED','inventory_item',v_id,jsonb_build_object('itemId',v_id,'name',v_name,'sku',v_sku,'baseUnit',p_base_unit,'category',v_category,'criticalStock',p_critical_stock));
  return v_id;
exception when unique_violation then raise exception 'INVENTORY_ITEM_DUPLICATE' using errcode = '23505';
end; $$;
create function public.update_inventory_item(p_tenant_id uuid,p_item_id uuid,p_name text,p_status text,p_sku text default null,p_category text default null,p_critical_stock numeric default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare old public.inventory_items%rowtype; v_name text := trim(p_name); v_sku text := nullif(trim(p_sku),''); v_category text := nullif(trim(p_category),'');
begin
  perform private.require_inventory_access(p_tenant_id,'inventory.write');
  select * into old from public.inventory_items where id = p_item_id and tenant_id = p_tenant_id for update;
  if not found then raise exception 'INVENTORY_ITEM_NOT_AVAILABLE' using errcode = '22023'; end if;
  if v_name is null or char_length(v_name) not between 2 and 160 or char_length(v_sku) > 100 or char_length(v_category) > 120
    or p_status is null or p_status not in ('ACTIVE','PASSIVE') then raise exception 'INVENTORY_ITEM_INVALID' using errcode = '22023'; end if;
  if p_critical_stock is not null then perform private.inventory_quantity(p_critical_stock,true); end if;
  if (old.name,old.sku,old.category,old.critical_stock,old.status) is not distinct from (v_name,v_sku,v_category,p_critical_stock,p_status) then
    raise exception 'INVENTORY_NO_CHANGES' using errcode = '22023'; end if;
  update public.inventory_items set name = v_name,sku = v_sku,category = v_category,critical_stock = p_critical_stock,status = p_status,updated_at = now() where id = p_item_id;
  insert into public.audit_logs(tenant_id,actor_user_id,action,entity_type,entity_id,metadata)
    values(p_tenant_id,auth.uid(),'INVENTORY_ITEM_UPDATED','inventory_item',p_item_id,jsonb_build_object('itemId',p_item_id,'name',v_name,'sku',v_sku,'category',v_category,'criticalStock',p_critical_stock,'status',p_status));
  return p_item_id;
exception when unique_violation then raise exception 'INVENTORY_ITEM_DUPLICATE' using errcode = '23505';
end; $$;
create function public.create_inventory_movement(p_tenant_id uuid,p_location_id uuid,p_item_id uuid,p_movement_type text,p_quantity numeric,p_description text,p_direction text default null,p_occurred_at timestamptz default now())
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_signed numeric; v_description text := trim(p_description);
begin
  perform private.require_inventory_access(p_tenant_id,'inventory.adjust');
  if p_movement_type is null or p_movement_type not in ('RECEIPT','ISSUE','WASTE','COMPLIMENTARY','MANUAL_ADJUSTMENT')
    or (p_movement_type = 'MANUAL_ADJUSTMENT' and (p_direction is null or p_direction not in ('INCREASE','DECREASE')))
    or (p_movement_type <> 'MANUAL_ADJUSTMENT' and p_direction is not null) then raise exception 'INVENTORY_MOVEMENT_INVALID' using errcode = '22023'; end if;
  perform private.inventory_quantity(p_quantity);
  if v_description is null or char_length(v_description) not between 2 and 500 or p_occurred_at is null or not isfinite(p_occurred_at) then
    raise exception 'INVENTORY_MOVEMENT_INVALID' using errcode = '22023'; end if;
  v_signed := p_quantity * case when p_movement_type in ('ISSUE','WASTE','COMPLIMENTARY') or p_direction = 'DECREASE' then -1 else 1 end;
  insert into public.inventory_movements(tenant_id,location_id,inventory_item_id,movement_type,quantity,description,occurred_at,source_type,created_by_user_id)
    values(p_tenant_id,p_location_id,p_item_id,p_movement_type,v_signed,v_description,p_occurred_at,'MANUAL',auth.uid()) returning id into v_id;
  insert into public.audit_logs(tenant_id,location_id,actor_user_id,action,entity_type,entity_id,metadata)
    values(p_tenant_id,p_location_id,auth.uid(),'INVENTORY_MOVEMENT_CREATED','inventory_movement',v_id,
      jsonb_build_object('itemId',p_item_id,'locationId',p_location_id,'movementType',p_movement_type,'quantity',p_quantity,'signedQuantity',v_signed,'description',v_description));
  return v_id;
end; $$;

create function public.create_inventory_count(p_tenant_id uuid,p_location_id uuid,p_notes text default null,p_counted_at timestamptz default now())
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  perform private.require_inventory_access(p_tenant_id,'inventory.count');
  if char_length(trim(p_notes)) > 2000 or p_counted_at is null or not isfinite(p_counted_at) then raise exception 'INVENTORY_COUNT_INVALID' using errcode = '22023'; end if;
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
end; $$;
create function public.update_inventory_count(p_tenant_id uuid,p_count_id uuid,p_lines jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare c public.inventory_counts%rowtype; l jsonb; q numeric; v_item uuid;
begin
  perform private.require_inventory_access(p_tenant_id,'inventory.count');
  select * into c from public.inventory_counts where id = p_count_id and tenant_id = p_tenant_id for update;
  if not found then raise exception 'INVENTORY_COUNT_NOT_AVAILABLE' using errcode = '22023'; end if;
  if c.status <> 'DRAFT' then raise exception 'INVENTORY_COUNT_IMMUTABLE' using errcode = '55000'; end if;
  if jsonb_typeof(p_lines) is distinct from 'array' then raise exception 'INVENTORY_COUNT_INVALID' using errcode = '22023'; end if;
  if jsonb_array_length(p_lines) = 0 or jsonb_array_length(p_lines) <> (select count(*) from public.inventory_count_lines where count_id = p_count_id)
    or (select count(distinct value->>'itemId') from jsonb_array_elements(p_lines)) <> jsonb_array_length(p_lines) then
    raise exception 'INVENTORY_COUNT_INVALID' using errcode = '22023'; end if;
  for l in select value from jsonb_array_elements(p_lines) loop
    if jsonb_typeof(l->'countedQuantity') is distinct from 'number' then raise exception 'INVENTORY_COUNT_INVALID' using errcode = '22023'; end if;
    q := private.inventory_quantity((l->>'countedQuantity')::numeric,true); v_item := (l->>'itemId')::uuid;
    update public.inventory_count_lines set counted_quantity = q,difference = q - system_quantity where count_id = p_count_id and tenant_id = p_tenant_id and inventory_item_id = v_item;
    if not found then raise exception 'INVENTORY_COUNT_INVALID' using errcode = '22023'; end if;
  end loop;
  return p_count_id;
exception when invalid_text_representation then raise exception 'INVENTORY_COUNT_INVALID' using errcode = '22023';
end; $$;
create function public.post_inventory_count(p_tenant_id uuid,p_count_id uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare c public.inventory_counts%rowtype; l public.inventory_count_lines%rowtype; v_current numeric; v_difference numeric; v_movements integer := 0;
begin
  perform private.require_inventory_access(p_tenant_id,'inventory.count');
  perform private.require_inventory_access(p_tenant_id,'inventory.adjust');
  select * into c from public.inventory_counts where id = p_count_id and tenant_id = p_tenant_id for update;
  if not found then raise exception 'INVENTORY_COUNT_NOT_AVAILABLE' using errcode = '22023'; end if;
  if c.status <> 'DRAFT' then raise exception 'INVENTORY_COUNT_IMMUTABLE' using errcode = '55000'; end if;
  perform 1 from public.inventory_items i join public.inventory_count_lines cl on cl.inventory_item_id = i.id and cl.tenant_id = i.tenant_id
    where cl.count_id = p_count_id order by i.id for update of i;
  if not found or exists(select 1 from public.inventory_count_lines where count_id = p_count_id and counted_quantity is null) then
    raise exception 'INVENTORY_COUNT_INCOMPLETE' using errcode = '22023'; end if;
  if exists(select 1 from public.inventory_count_lines cl join public.inventory_items i on i.id = cl.inventory_item_id where cl.count_id = p_count_id and i.status <> 'ACTIVE') then
    raise exception 'INVENTORY_ITEM_NOT_AVAILABLE' using errcode = '22023'; end if;
  perform private.inventory_location(p_tenant_id,c.location_id);
  for l in select * from public.inventory_count_lines where count_id = p_count_id order by inventory_item_id loop
    select coalesce(sum(quantity),0) into v_current from public.inventory_movements where tenant_id = p_tenant_id and location_id = c.location_id and inventory_item_id = l.inventory_item_id;
    v_difference := l.counted_quantity - v_current;
    update public.inventory_count_lines set system_quantity = v_current,difference = v_difference where id = l.id;
    if v_difference <> 0 then
      insert into public.inventory_movements(tenant_id,location_id,inventory_item_id,movement_type,quantity,occurred_at,description,source_type,source_id,created_by_user_id)
        values(p_tenant_id,c.location_id,l.inventory_item_id,'COUNT_ADJUSTMENT',v_difference,now(),'Sayım farkı','INVENTORY_COUNT',p_count_id,auth.uid());
      v_movements := v_movements + 1;
    end if;
  end loop;
  update public.inventory_counts set status = 'POSTED',posted_at = now(),posted_by = auth.uid() where id = p_count_id;
  insert into public.audit_logs(tenant_id,location_id,actor_user_id,action,entity_type,entity_id,metadata)
    values(p_tenant_id,c.location_id,auth.uid(),'INVENTORY_COUNT_POSTED','inventory_count',p_count_id,jsonb_build_object('countId',p_count_id,'locationId',c.location_id,'movementCount',v_movements));
  return p_count_id;
end; $$;

create function private.inventory_item_data(p_tenant_id uuid,p_location_id uuid) returns jsonb language sql stable set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'sku',sku,'category',category,'baseUnit',base_unit,'criticalStock',critical_stock,
    'status',status,'quantity',quantity,'isCritical',critical_stock is not null and quantity <= critical_stock,'isNegative',quantity < 0) order by name,id),'[]')
  from (select i.*,coalesce((select sum(m.quantity) from public.inventory_movements m where m.tenant_id = p_tenant_id and m.inventory_item_id = i.id and (p_location_id is null or m.location_id = p_location_id)),0) quantity
    from public.inventory_items i where i.tenant_id = p_tenant_id) s;
$$;
create function public.get_inventory_management(p_tenant_id uuid) returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_inventory_access(p_tenant_id,'inventory.read');
  return jsonb_build_object('tenantId',p_tenant_id,'items',private.inventory_item_data(p_tenant_id,null));
end; $$;
create function public.get_inventory_overview(p_tenant_id uuid,p_location_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_items jsonb; v_movements jsonb;
begin
  perform private.require_inventory_access(p_tenant_id,'inventory.read');
  if p_location_id is not null and not exists(select 1 from public.locations where id = p_location_id and tenant_id = p_tenant_id) then
    raise exception 'INVENTORY_LOCATION_NOT_AVAILABLE' using errcode = '22023'; end if;
  v_items := private.inventory_item_data(p_tenant_id,p_location_id);
  select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'itemId',m.inventory_item_id,'itemName',i.name,'locationId',m.location_id,'locationName',l.name,
    'movementType',m.movement_type,'quantity',m.quantity,'occurredAt',m.occurred_at,'description',m.description,'sourceType',m.source_type) order by m.occurred_at desc,m.id desc),'[]') into v_movements
    from (select * from public.inventory_movements where tenant_id = p_tenant_id and (p_location_id is null or location_id = p_location_id) order by occurred_at desc,id desc limit 50) m
    join public.inventory_items i on i.id = m.inventory_item_id join public.locations l on l.id = m.location_id;
  return jsonb_build_object('tenantId',p_tenant_id,'locationId',p_location_id,'items',v_items,'recentMovements',v_movements,
    'locations',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'status',status) order by name,id),'[]') from public.locations where tenant_id = p_tenant_id),
    'summary',(select jsonb_build_object('activeItemCount',count(*) filter(where value->>'status' = 'ACTIVE'),
      'criticalItemCount',count(*) filter(where value->>'status' = 'ACTIVE' and (value->>'isCritical')::boolean),
      'negativeItemCount',count(*) filter(where (value->>'isNegative')::boolean)) from jsonb_array_elements(v_items)));
end; $$;
create function public.get_inventory_context(p_tenant_id uuid) returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if private.has_permission(p_tenant_id,'inventory.adjust') then perform private.require_inventory_access(p_tenant_id,'inventory.adjust');
  else perform private.require_inventory_access(p_tenant_id,'inventory.count'); end if;
  return jsonb_build_object('tenantId',p_tenant_id,'items',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'baseUnit',base_unit) order by name,id),'[]') from public.inventory_items where tenant_id = p_tenant_id and status = 'ACTIVE'),
    'locations',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by name,id),'[]') from public.locations where tenant_id = p_tenant_id and status = 'ACTIVE'));
end; $$;
create function public.get_inventory_counts(p_tenant_id uuid) returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if private.has_permission(p_tenant_id,'inventory.read') then perform private.require_inventory_access(p_tenant_id,'inventory.read');
  else perform private.require_inventory_access(p_tenant_id,'inventory.count'); end if;
  return jsonb_build_object('tenantId',p_tenant_id,'counts',(select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'locationId',c.location_id,'locationName',l.name,'status',c.status,'countedAt',c.counted_at,'notes',c.notes,'postedAt',c.posted_at) order by c.created_at desc,c.id desc),'[]')
    from (select * from public.inventory_counts where tenant_id = p_tenant_id order by created_at desc,id desc limit 50) c join public.locations l on l.id = c.location_id));
end; $$;
create function public.get_inventory_count_detail(p_tenant_id uuid,p_count_id uuid) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare c public.inventory_counts%rowtype;
begin
  if private.has_permission(p_tenant_id,'inventory.read') then perform private.require_inventory_access(p_tenant_id,'inventory.read');
  else perform private.require_inventory_access(p_tenant_id,'inventory.count'); end if;
  select * into c from public.inventory_counts where id = p_count_id and tenant_id = p_tenant_id;
  if not found then raise exception 'INVENTORY_COUNT_NOT_AVAILABLE' using errcode = '22023'; end if;
  return jsonb_build_object('tenantId',p_tenant_id,'id',c.id,'locationId',c.location_id,'status',c.status,'countedAt',c.counted_at,'notes',c.notes,'postedAt',c.posted_at,
    'lines',(select coalesce(jsonb_agg(jsonb_build_object('itemId',i.id,'itemName',i.name,'baseUnit',i.base_unit,'systemQuantity',l.system_quantity,'countedQuantity',l.counted_quantity,'difference',l.difference) order by i.name,i.id),'[]')
      from public.inventory_count_lines l join public.inventory_items i on i.id = l.inventory_item_id where l.count_id = p_count_id));
end; $$;

revoke all on function private.require_inventory_access(uuid,text),private.inventory_quantity(numeric,boolean),private.inventory_location(uuid,uuid),
  private.guard_inventory_item(),private.guard_inventory_movement(),private.guard_inventory_count(),private.guard_inventory_count_line(),private.inventory_item_data(uuid,uuid) from public,anon,authenticated;
revoke all on function public.create_inventory_item(uuid,text,text,text,text,numeric),public.update_inventory_item(uuid,uuid,text,text,text,text,numeric),
  public.create_inventory_movement(uuid,uuid,uuid,text,numeric,text,text,timestamptz),public.create_inventory_count(uuid,uuid,text,timestamptz),
  public.update_inventory_count(uuid,uuid,jsonb),public.post_inventory_count(uuid,uuid),public.get_inventory_overview(uuid,uuid),public.get_inventory_management(uuid),
  public.get_inventory_context(uuid),public.get_inventory_counts(uuid),public.get_inventory_count_detail(uuid,uuid) from public,anon;
grant execute on function public.create_inventory_item(uuid,text,text,text,text,numeric),public.update_inventory_item(uuid,uuid,text,text,text,text,numeric),
  public.create_inventory_movement(uuid,uuid,uuid,text,numeric,text,text,timestamptz),public.create_inventory_count(uuid,uuid,text,timestamptz),
  public.update_inventory_count(uuid,uuid,jsonb),public.post_inventory_count(uuid,uuid),public.get_inventory_overview(uuid,uuid),public.get_inventory_management(uuid),
  public.get_inventory_context(uuid),public.get_inventory_counts(uuid),public.get_inventory_count_detail(uuid,uuid) to authenticated,service_role;
