-- Generic ingestion; preserve existing manual/import facts and normalize the legacy external source.
alter table public.menu_products add constraint menu_product_tenant_identity unique(id,tenant_id);
alter table public.menu_product_sales_facts drop constraint menu_product_sales_facts_source_type_check;
update public.menu_product_sales_facts set source_type='SALES_APP' where source_type not in ('MANUAL','IMPORT');
alter table public.menu_product_sales_facts add constraint menu_product_sales_facts_source_type_check check(source_type in ('MANUAL','SALES_APP','IMPORT'));

create table public.sales_app_product_mappings (
  id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id), location_id uuid,
  provider_key text not null default 'SALES_APP' check(provider_key ~ '^[A-Z][A-Z0-9_]{0,63}$'),
  external_product_id text not null check(external_product_id=trim(external_product_id) and char_length(external_product_id) between 1 and 200),
  external_product_code text check(char_length(external_product_code)<=200),
  external_product_name text not null check(external_product_name=trim(external_product_name) and char_length(external_product_name) between 1 and 200),
  menu_product_id uuid, status text not null default 'UNMAPPED' check(status in ('MAPPED','UNMAPPED','IGNORED')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check((status='MAPPED' and menu_product_id is not null) or (status<>'MAPPED' and menu_product_id is null)),
  unique nulls not distinct(tenant_id,provider_key,location_id,external_product_id),
  foreign key(location_id,tenant_id) references public.locations(id,tenant_id),
  foreign key(menu_product_id,tenant_id) references public.menu_products(id,tenant_id)
);
create index sales_app_mapping_location on public.sales_app_product_mappings(location_id,tenant_id);
create index sales_app_mapping_product on public.sales_app_product_mappings(menu_product_id,tenant_id);
create table public.sales_app_import_batches (
  id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id), location_id uuid not null,
  provider_key text not null default 'SALES_APP' check(provider_key ~ '^[A-Z][A-Z0-9_]{0,63}$'),
  business_date date not null check(isfinite(business_date)), currency_code text not null check(currency_code ~ '^[A-Z]{3}$'),
  external_batch_key text not null check(external_batch_key=trim(external_batch_key) and char_length(external_batch_key) between 1 and 200),
  status text not null check(status in ('PROCESSING','COMPLETED','FAILED')),
  row_count integer not null check(row_count between 1 and 5000), mapped_row_count integer not null default 0 check(mapped_row_count>=0),
  unmapped_row_count integer not null default 0 check(unmapped_row_count>=0),
  imported_at timestamptz not null default clock_timestamp(), created_by_user_id uuid not null references auth.users(id), metadata jsonb not null default '{}',
  unique(id,tenant_id), unique(tenant_id,provider_key,location_id,external_batch_key),
  foreign key(location_id,tenant_id) references public.locations(id,tenant_id)
);
create index sales_app_batch_day on public.sales_app_import_batches(tenant_id,location_id,business_date,currency_code,imported_at desc);
create index sales_app_batch_location on public.sales_app_import_batches(location_id,tenant_id);
create index sales_app_batch_actor on public.sales_app_import_batches(created_by_user_id);
create table public.sales_app_import_rows (
  id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id), batch_id uuid not null,
  external_product_id text not null check(external_product_id=trim(external_product_id) and char_length(external_product_id) between 1 and 200),
  external_product_code text check(char_length(external_product_code)<=200), external_product_name text not null check(char_length(external_product_name) between 1 and 200),
  quantity numeric(16,4) not null check(quantity>=0 and quantity<>'NaN'::numeric),
  gross_sales numeric(16,2) not null check(gross_sales>=0 and gross_sales<>'NaN'::numeric),
  net_sales numeric(16,2) not null check(net_sales>=0 and net_sales<>'NaN'::numeric),
  currency_code text not null check(currency_code ~ '^[A-Z]{3}$'),
  mapping_status text not null check(mapping_status in ('MAPPED','UNMAPPED','IGNORED')), menu_product_id uuid,
  created_at timestamptz not null default now(), unique(batch_id,external_product_id),
  check(quantity>0 or (gross_sales=0 and net_sales=0)),
  check((mapping_status='MAPPED' and menu_product_id is not null) or (mapping_status<>'MAPPED' and menu_product_id is null)),
  foreign key(batch_id,tenant_id) references public.sales_app_import_batches(id,tenant_id),
  foreign key(menu_product_id,tenant_id,currency_code) references public.menu_products(id,tenant_id,currency_code)
);
create index sales_app_row_tenant on public.sales_app_import_rows(tenant_id,batch_id);
create index sales_app_row_product on public.sales_app_import_rows(menu_product_id,tenant_id,currency_code);
alter table public.sales_app_product_mappings enable row level security;
alter table public.sales_app_import_batches enable row level security;
alter table public.sales_app_import_rows enable row level security;
revoke all on public.sales_app_product_mappings,public.sales_app_import_batches,public.sales_app_import_rows from public,anon,authenticated;
create trigger sales_app_mapping_guard before update or delete on public.sales_app_product_mappings for each row execute function private.guard_costing_record();
create trigger sales_app_batch_guard before update or delete on public.sales_app_import_batches for each row execute function private.guard_costing_record();
create function private.guard_sales_app_history() returns trigger language plpgsql set search_path='' as $$ begin raise exception 'SALES_APP_HISTORY_IMMUTABLE' using errcode='55000'; end; $$;
create trigger sales_app_row_guard before update or delete on public.sales_app_import_rows for each row execute function private.guard_sales_app_history();

-- Location-specific mappings override shared mappings, including explicit UNMAPPED/IGNORED overrides.
create function private.sales_app_resolved_rows(p_batch_id uuid) returns table(product_id uuid,mapping_status text,quantity numeric,gross numeric,net numeric,external_id text)
language sql stable set search_path='' as $$
  select m.menu_product_id,coalesce(m.status,'UNMAPPED'),r.quantity,r.gross_sales,r.net_sales,r.external_product_id
  from public.sales_app_import_rows r join public.sales_app_import_batches b on b.id=r.batch_id and b.tenant_id=r.tenant_id
  left join lateral (select m.* from public.sales_app_product_mappings m where m.tenant_id=b.tenant_id and m.provider_key=b.provider_key
    and m.external_product_id=r.external_product_id and (m.location_id=b.location_id or m.location_id is null) order by m.location_id nulls last limit 1) m on true
  where b.id=p_batch_id;
$$;
create function private.apply_sales_app_batch(p_batch_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare b public.sales_app_import_batches%rowtype; r record; old public.menu_product_sales_facts%rowtype; v_id uuid; n int:=0;
begin
  select * into strict b from public.sales_app_import_batches where id=p_batch_id;
  -- Import/mapping/reprocess hold the tenant lock first. Product locks also serialize manual sales and currency edits.
  perform 1 from public.menu_products where tenant_id=b.tenant_id order by id for update;
  if exists(select 1 from private.sales_app_resolved_rows(b.id) r join public.menu_products p on p.id=r.product_id and p.tenant_id=b.tenant_id where r.mapping_status='MAPPED' and p.currency_code<>b.currency_code) then raise exception 'SALES_APP_CURRENCY_MISMATCH' using errcode='22023'; end if;
  for r in
    with grouped as (select product_id,sum(quantity) quantity,sum(gross) gross,sum(net) net from private.sales_app_resolved_rows(b.id) where mapping_status='MAPPED' group by product_id),
    -- Missing products in a full replacement are zeroed, never hard-deleted. Unrelated manual facts are preserved.
    desired as (select * from grouped union all select f.menu_product_id,0,0,0 from public.menu_product_sales_facts f where f.tenant_id=b.tenant_id and f.location_id=b.location_id and f.sale_date=b.business_date and f.currency_code=b.currency_code and f.source_type='SALES_APP' and not exists(select 1 from grouped g where g.product_id=f.menu_product_id))
    select * from desired order by product_id
  loop
    if r.quantity>999999999999.9999 or r.gross>99999999999999.99 or r.net>99999999999999.99 then raise exception 'SALES_APP_TOTAL_OVERFLOW' using errcode='22023'; end if;
    select * into old from public.menu_product_sales_facts where tenant_id=b.tenant_id and location_id=b.location_id and sale_date=b.business_date and menu_product_id=r.product_id and currency_code=b.currency_code for update;
    if old.id is not null and (old.quantity,old.gross_sales,old.net_sales,old.source_type) is not distinct from (r.quantity,r.gross,r.net,'SALES_APP'::text) then continue; end if;
    insert into public.menu_product_sales_facts(tenant_id,location_id,sale_date,menu_product_id,currency_code,quantity,gross_sales,net_sales,source_type)
      values(b.tenant_id,b.location_id,b.business_date,r.product_id,b.currency_code,r.quantity,r.gross,r.net,'SALES_APP')
      on conflict(tenant_id,location_id,sale_date,menu_product_id,currency_code) do update set quantity=excluded.quantity,gross_sales=excluded.gross_sales,net_sales=excluded.net_sales,source_type='SALES_APP',updated_at=now() returning id into v_id;
    insert into public.audit_logs(tenant_id,location_id,actor_user_id,action,entity_type,entity_id,metadata) values(b.tenant_id,b.location_id,auth.uid(),'SALES_APP_FACT_REPLACED','menu_product_sales_fact',v_id,
      jsonb_build_object('batchId',b.id,'previousSourceType',old.source_type,'newSourceType','SALES_APP','old',case when old.id is null then null else to_jsonb(old) end,'new',jsonb_build_object('quantity',r.quantity,'grossSales',r.gross,'netSales',r.net)));
    n:=n+1;
  end loop;
  return jsonb_build_object('businessDate',b.business_date,'externalBatchKey',b.external_batch_key,'rowCount',b.row_count,
    'mappedRowCount',(select count(*) from private.sales_app_resolved_rows(b.id) where mapping_status='MAPPED'),
    'unmappedRowCount',(select count(*) from private.sales_app_resolved_rows(b.id) where mapping_status='UNMAPPED'),
    'salesFactCount',(select count(distinct product_id) from private.sales_app_resolved_rows(b.id) where mapping_status='MAPPED'),'changedFactCount',n);
end; $$;

create function public.import_sales_app_daily_sales(p_tenant_id uuid,p_location_id uuid,p_business_date date,p_external_batch_key text,p_currency_code text,p_rows jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare b public.sales_app_import_batches%rowtype; m public.sales_app_product_mappings%rowtype; r jsonb; normalized jsonb:='[]'; ext text; nm text; code text; q numeric; g numeric; n numeric; v_id uuid; fingerprint text; result jsonb;
begin
  perform private.require_costing_access(p_tenant_id,'food-service.costing.write',p_location_id);
  if p_location_id is null or not exists(select 1 from public.locations where id=p_location_id and tenant_id=p_tenant_id and status='ACTIVE') then raise exception 'COSTING_LOCATION_NOT_AVAILABLE' using errcode='22023'; end if;
  perform private.check_operating_period(p_business_date,p_business_date,p_currency_code);
  p_external_batch_key:=trim(p_external_batch_key);
  if p_external_batch_key is null or char_length(p_external_batch_key) not between 1 and 200 or jsonb_typeof(p_rows) is distinct from 'array' then raise exception 'SALES_APP_IMPORT_INVALID' using errcode='22023'; end if;
  if jsonb_array_length(p_rows) not between 1 and 5000 then raise exception 'SALES_APP_IMPORT_INVALID' using errcode='22023'; end if;
  for r in select value from jsonb_array_elements(p_rows) loop
    if jsonb_typeof(r) is distinct from 'object' or jsonb_typeof(r->'externalProductId') is distinct from 'string' or jsonb_typeof(r->'externalProductName') is distinct from 'string'
      or jsonb_typeof(r->'quantity') is distinct from 'number' or jsonb_typeof(r->'grossSales') is distinct from 'number' or jsonb_typeof(r->'netSales') is distinct from 'number'
      or (r ? 'externalProductCode' and jsonb_typeof(r->'externalProductCode') not in ('string','null')) then raise exception 'SALES_APP_ROW_INVALID' using errcode='22023'; end if;
    ext:=trim(r->>'externalProductId'); nm:=trim(r->>'externalProductName'); code:=nullif(trim(r->>'externalProductCode'),'');
    q:=(r->>'quantity')::numeric; g:=(r->>'grossSales')::numeric; n:=(r->>'netSales')::numeric;
    if char_length(ext) not between 1 and 200 or char_length(nm) not between 1 and 200 or char_length(code)>200
      or q<0 or q>999999999999.9999 or q<>round(q,4) or g<0 or g>99999999999999.99 or g<>round(g,2) or n<0 or n>99999999999999.99 or n<>round(n,2) or (q=0 and (g<>0 or n<>0)) then raise exception 'SALES_APP_ROW_INVALID' using errcode='22023'; end if;
    normalized:=normalized||jsonb_build_array(jsonb_build_object('externalProductId',ext,'externalProductCode',code,'externalProductName',nm,'quantity',q,'grossSales',g,'netSales',n));
  end loop;
  if exists(select 1 from jsonb_array_elements(normalized) r group by r->>'externalProductId' having count(*)>1) then raise exception 'SALES_APP_DUPLICATE_PRODUCT' using errcode='22023'; end if;
  select jsonb_agg(r order by r->>'externalProductId') into normalized from jsonb_array_elements(normalized) r;
  fingerprint:=md5(jsonb_build_object('date',p_business_date,'currency',p_currency_code,'rows',normalized)::text);
  perform 1 from public.tenants where id=p_tenant_id for update;
  select * into b from public.sales_app_import_batches where tenant_id=p_tenant_id and provider_key='SALES_APP' and location_id=p_location_id and external_batch_key=p_external_batch_key;
  if found then
    if b.metadata->>'payloadFingerprint' is distinct from fingerprint then raise exception 'SALES_APP_BATCH_KEY_CONFLICT' using errcode='22023'; end if;
    return b.id;
  end if;
  insert into public.sales_app_import_batches(tenant_id,location_id,business_date,currency_code,external_batch_key,status,row_count,created_by_user_id,metadata)
    values(p_tenant_id,p_location_id,p_business_date,p_currency_code,p_external_batch_key,'PROCESSING',jsonb_array_length(normalized),auth.uid(),jsonb_build_object('payloadFingerprint',fingerprint)) returning id into v_id;
  for r in select value from jsonb_array_elements(normalized) loop
    select * into m from public.sales_app_product_mappings where tenant_id=p_tenant_id and provider_key='SALES_APP' and external_product_id=r->>'externalProductId' and (location_id=p_location_id or location_id is null) order by location_id nulls last limit 1;
    if not found then
      insert into public.sales_app_product_mappings(tenant_id,location_id,external_product_id,external_product_code,external_product_name) values(p_tenant_id,p_location_id,r->>'externalProductId',r->>'externalProductCode',r->>'externalProductName') returning * into m;
    end if;
    if m.status='MAPPED' and exists(select 1 from public.menu_products where id=m.menu_product_id and tenant_id=p_tenant_id and currency_code<>p_currency_code) then raise exception 'SALES_APP_CURRENCY_MISMATCH' using errcode='22023'; end if;
    insert into public.sales_app_import_rows(tenant_id,batch_id,external_product_id,external_product_code,external_product_name,quantity,gross_sales,net_sales,currency_code,mapping_status,menu_product_id)
      values(p_tenant_id,v_id,r->>'externalProductId',r->>'externalProductCode',r->>'externalProductName',(r->>'quantity')::numeric,(r->>'grossSales')::numeric,(r->>'netSales')::numeric,p_currency_code,m.status,m.menu_product_id);
  end loop;
  result:=private.apply_sales_app_batch(v_id);
  update public.sales_app_import_batches set status='COMPLETED',mapped_row_count=(result->>'mappedRowCount')::int,unmapped_row_count=(result->>'unmappedRowCount')::int,metadata=metadata||result where id=v_id;
  insert into public.audit_logs(tenant_id,location_id,actor_user_id,action,entity_type,entity_id,metadata) values(p_tenant_id,p_location_id,auth.uid(),'SALES_APP_IMPORT_COMPLETED','sales_app_import_batch',v_id,result);
  return v_id;
end; $$;

create function public.update_sales_app_product_mapping(p_tenant_id uuid,p_mapping_id uuid,p_status text,p_menu_product_id uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare old public.sales_app_product_mappings%rowtype;
begin
  perform private.require_costing_access(p_tenant_id,'food-service.costing.write');
  if p_status is null or p_status not in ('MAPPED','UNMAPPED','IGNORED') or (p_status='MAPPED')<>(p_menu_product_id is not null) then raise exception 'SALES_APP_MAPPING_INVALID' using errcode='22023'; end if;
  perform 1 from public.tenants where id=p_tenant_id for update;
  select * into old from public.sales_app_product_mappings where id=p_mapping_id and tenant_id=p_tenant_id for update;
  if not found then raise exception 'SALES_APP_MAPPING_NOT_AVAILABLE' using errcode='22023'; end if;
  if p_menu_product_id is not null and not exists(select 1 from public.menu_products where tenant_id=p_tenant_id and id=p_menu_product_id) then raise exception 'MENU_PRODUCT_NOT_AVAILABLE' using errcode='22023'; end if;
  if (old.status,old.menu_product_id) is not distinct from (p_status,p_menu_product_id) then return old.id; end if;
  update public.sales_app_product_mappings set status=p_status,menu_product_id=p_menu_product_id,updated_at=now() where id=old.id;
  insert into public.audit_logs(tenant_id,location_id,actor_user_id,action,entity_type,entity_id,metadata) values(p_tenant_id,old.location_id,auth.uid(),'SALES_APP_PRODUCT_MAPPING_UPDATED','sales_app_product_mapping',old.id,jsonb_build_object('oldStatus',old.status,'newStatus',p_status,'oldMenuProductId',old.menu_product_id,'newMenuProductId',p_menu_product_id));
  return old.id;
end; $$;

create function public.reprocess_sales_app_import_batch(p_tenant_id uuid,p_batch_id uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare b public.sales_app_import_batches%rowtype; result jsonb; fingerprint text;
begin
  perform private.require_costing_access(p_tenant_id,'food-service.costing.write');
  perform 1 from public.tenants where id=p_tenant_id for update;
  select * into b from public.sales_app_import_batches where id=p_batch_id and tenant_id=p_tenant_id;
  if not found or b.status<>'COMPLETED' then raise exception 'SALES_APP_BATCH_NOT_AVAILABLE' using errcode='22023'; end if;
  if not exists(select 1 from public.locations where tenant_id=p_tenant_id and id=b.location_id and status='ACTIVE') then raise exception 'COSTING_LOCATION_NOT_AVAILABLE' using errcode='22023'; end if;
  if exists(select 1 from public.sales_app_import_batches where tenant_id=p_tenant_id and provider_key=b.provider_key and location_id=b.location_id and business_date=b.business_date and currency_code=b.currency_code and status='COMPLETED' and (imported_at,id)>(b.imported_at,b.id)) then raise exception 'SALES_APP_BATCH_SUPERSEDED' using errcode='55000'; end if;
  select md5(jsonb_agg(to_jsonb(r) order by external_id)::text) into fingerprint from private.sales_app_resolved_rows(b.id) r;
  if b.metadata->>'reprocessFingerprint'=fingerprint then return b.id; end if;
  result:=private.apply_sales_app_batch(b.id);
  update public.sales_app_import_batches set metadata=metadata||jsonb_build_object('reprocessFingerprint',fingerprint,'lastReprocessedAt',clock_timestamp()) where id=b.id;
  insert into public.audit_logs(tenant_id,location_id,actor_user_id,action,entity_type,entity_id,metadata) values(p_tenant_id,b.location_id,auth.uid(),'SALES_APP_IMPORT_REPROCESSED','sales_app_import_batch',b.id,result);
  return b.id;
end; $$;

create function public.get_sales_app_integration_overview(p_tenant_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  perform private.require_costing_access(p_tenant_id,'food-service.costing.read');
  return jsonb_build_object('tenantId',p_tenant_id,'providerKey','SALES_APP',
    'summary',(select jsonb_build_object('mappedProductCount',count(*) filter(where status='MAPPED'),'unmappedProductCount',count(*) filter(where status='UNMAPPED'),'ignoredProductCount',count(*) filter(where status='IGNORED'),
      'lastImportAt',(select max(imported_at) from public.sales_app_import_batches where tenant_id=p_tenant_id and provider_key='SALES_APP' and status='COMPLETED'),
      'lastImportBusinessDate',(select business_date from public.sales_app_import_batches where tenant_id=p_tenant_id and provider_key='SALES_APP' and status='COMPLETED' order by imported_at desc,id desc limit 1)) from public.sales_app_product_mappings where tenant_id=p_tenant_id and provider_key='SALES_APP'),
    'locations',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by name,id),'[]') from public.locations where tenant_id=p_tenant_id and status='ACTIVE'),
    'menuProducts',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'currencyCode',currency_code) order by name,id),'[]') from public.menu_products where tenant_id=p_tenant_id),
    'mappings',(select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'externalProductId',m.external_product_id,'externalProductCode',m.external_product_code,'externalProductName',m.external_product_name,'locationId',m.location_id,'locationName',l.name,'status',m.status,'menuProductId',m.menu_product_id,'menuProductName',p.name) order by m.external_product_name,m.id),'[]') from public.sales_app_product_mappings m left join public.locations l on l.id=m.location_id and l.tenant_id=m.tenant_id left join public.menu_products p on p.id=m.menu_product_id and p.tenant_id=m.tenant_id where m.tenant_id=p_tenant_id and m.provider_key='SALES_APP'),
    'recentImports',(select coalesce(jsonb_agg(v order by imported_at desc,id desc),'[]') from (select b.id,b.imported_at,jsonb_build_object('id',b.id,'businessDate',b.business_date,'locationId',b.location_id,'location',l.name,'currencyCode',b.currency_code,'externalBatchKey',b.external_batch_key,'status',b.status,'rowCount',b.row_count,'mappedRowCount',b.mapped_row_count,'unmappedRowCount',b.unmapped_row_count,'importedAt',b.imported_at,
      'canReprocess',b.status='COMPLETED' and not exists(select 1 from public.sales_app_import_batches newer where newer.tenant_id=b.tenant_id and newer.provider_key=b.provider_key and newer.location_id=b.location_id and newer.business_date=b.business_date and newer.currency_code=b.currency_code and newer.status='COMPLETED' and (newer.imported_at,newer.id)>(b.imported_at,b.id))) v from public.sales_app_import_batches b join public.locations l on l.id=b.location_id and l.tenant_id=b.tenant_id where b.tenant_id=p_tenant_id and b.provider_key='SALES_APP' order by b.imported_at desc,b.id desc limit 100) recent));
end; $$;
revoke all on function private.guard_sales_app_history(),private.sales_app_resolved_rows(uuid),private.apply_sales_app_batch(uuid) from public,anon,authenticated;
revoke all on function public.import_sales_app_daily_sales(uuid,uuid,date,text,text,jsonb),public.update_sales_app_product_mapping(uuid,uuid,text,uuid),public.reprocess_sales_app_import_batch(uuid,uuid),public.get_sales_app_integration_overview(uuid) from public,anon;
grant execute on function public.import_sales_app_daily_sales(uuid,uuid,date,text,text,jsonb),public.update_sales_app_product_mapping(uuid,uuid,text,uuid),public.reprocess_sales_app_import_batch(uuid,uuid),public.get_sales_app_integration_overview(uuid) to authenticated,service_role;
