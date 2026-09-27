-- Purchase units are per-item conversions, not changes to canonical inventory base units.
create table public.inventory_purchase_units (
  id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete restrict,
  inventory_item_id uuid not null, name text not null check(name = trim(name) and char_length(name) between 1 and 30),
  conversion_to_base numeric(18,6) not null check(conversion_to_base > 0 and conversion_to_base <> 'NaN'::numeric),
  status text not null default 'ACTIVE' check(status in ('ACTIVE','PASSIVE')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(id,inventory_item_id,tenant_id), foreign key(inventory_item_id,tenant_id) references public.inventory_items(id,tenant_id) on delete restrict
);
create unique index inventory_purchase_units_name on public.inventory_purchase_units(tenant_id,inventory_item_id,lower(regexp_replace(trim(name),'[[:space:]]+',' ','g')));
alter table public.inventory_purchase_units enable row level security;
revoke all on public.inventory_purchase_units from public,anon,authenticated;
grant select on public.inventory_purchase_units to authenticated;
create policy inventory_purchase_units_read on public.inventory_purchase_units for select to authenticated
  using(private.is_module_enabled(tenant_id,'inventory') and private.has_permission(tenant_id,'inventory.read'));

-- No UPDATE/backfill of existing invoice rows; old invoices remain UNMAPPED and produce no receipt.
alter table public.purchase_invoice_lines
  add column inventory_tracking text not null default 'UNMAPPED' check(inventory_tracking in ('UNMAPPED','MAPPED','NON_STOCK')),
  add column inventory_purchase_unit_id uuid,
  add constraint purchase_line_mapping_check check(
    (inventory_tracking = 'MAPPED' and inventory_item_id is not null and inventory_purchase_unit_id is not null)
    or (inventory_tracking in ('UNMAPPED','NON_STOCK') and inventory_item_id is null and inventory_purchase_unit_id is null)),
  add constraint purchase_line_unit_item_tenant_fk foreign key(inventory_purchase_unit_id,inventory_item_id,tenant_id)
    references public.inventory_purchase_units(id,inventory_item_id,tenant_id) on delete restrict,
  add constraint purchase_line_source_identity unique(id,purchase_invoice_id,tenant_id);
create index purchase_line_unit_item on public.purchase_invoice_lines(inventory_purchase_unit_id,inventory_item_id,tenant_id) where inventory_purchase_unit_id is not null;
alter table public.inventory_movements add column source_line_id uuid,
  add constraint inventory_invoice_line_fk foreign key(source_line_id,source_id,tenant_id)
    references public.purchase_invoice_lines(id,purchase_invoice_id,tenant_id) on delete restrict,
  add constraint inventory_invoice_receipt_check check(source_type is distinct from 'PURCHASE_INVOICE'
    or (source_line_id is not null and source_id is not null and movement_type = 'RECEIPT' and quantity > 0));
create unique index inventory_invoice_receipt_line on public.inventory_movements(tenant_id,source_line_id) where source_type = 'PURCHASE_INVOICE';
comment on column public.purchase_invoice_lines.inventory_item_id is 'Explicit MAPPED line; invoice posting creates a base-unit receipt using its purchase unit.';

create function private.guard_inventory_purchase_unit() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'DELETE' then raise exception 'INVENTORY_HISTORY_IMMUTABLE' using errcode = '55000'; end if;
  if tg_op = 'UPDATE' and (new.id,new.tenant_id,new.inventory_item_id) is distinct from (old.id,old.tenant_id,old.inventory_item_id) then
    raise exception 'INVENTORY_PURCHASE_UNIT_IMMUTABLE' using errcode = '55000'; end if;
  perform 1 from public.inventory_items where id = new.inventory_item_id and tenant_id = new.tenant_id and status = 'ACTIVE' for share;
  if not found then raise exception 'INVENTORY_ITEM_NOT_AVAILABLE' using errcode = '22023'; end if;
  return new;
end; $$;
create trigger inventory_purchase_unit_guard before insert or update or delete on public.inventory_purchase_units for each row execute function private.guard_inventory_purchase_unit();
create function private.save_inventory_purchase_unit(p_tenant_id uuid,p_unit_id uuid,p_item_id uuid,p_name text,p_conversion numeric,p_status text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid := coalesce(p_unit_id,gen_random_uuid()); old public.inventory_purchase_units%rowtype; v_name text := trim(p_name);
begin
  perform private.require_inventory_access(p_tenant_id,'inventory.write');
  if v_name is null or char_length(v_name) not between 1 and 30 or p_conversion is null or p_conversion <= 0
    or p_conversion = 'NaN'::numeric or p_conversion > 999999999999.999999 or p_conversion <> round(p_conversion,6)
    or p_status is null or p_status not in ('ACTIVE','PASSIVE') then raise exception 'INVENTORY_PURCHASE_UNIT_INVALID' using errcode = '22023'; end if;
  -- Same item-before-unit lock order as invoice posting.
  perform 1 from public.inventory_items where id = p_item_id and tenant_id = p_tenant_id and status = 'ACTIVE' for update;
  if not found then raise exception 'INVENTORY_ITEM_NOT_AVAILABLE' using errcode = '22023'; end if;
  if p_unit_id is null then
    insert into public.inventory_purchase_units(id,tenant_id,inventory_item_id,name,conversion_to_base,status) values(v_id,p_tenant_id,p_item_id,v_name,p_conversion,p_status);
  else
    select * into old from public.inventory_purchase_units where id = p_unit_id and tenant_id = p_tenant_id and inventory_item_id = p_item_id for update;
    if not found then raise exception 'INVENTORY_PURCHASE_UNIT_NOT_AVAILABLE' using errcode = '22023'; end if;
    if (old.name,old.conversion_to_base,old.status) is not distinct from (v_name,p_conversion,p_status) then raise exception 'INVENTORY_NO_CHANGES' using errcode = '22023'; end if;
    update public.inventory_purchase_units set name = v_name,conversion_to_base = p_conversion,status = p_status,updated_at = now() where id = v_id;
  end if;
  insert into public.audit_logs(tenant_id,actor_user_id,action,entity_type,entity_id,metadata)
    values(p_tenant_id,auth.uid(),case when p_unit_id is null then 'INVENTORY_PURCHASE_UNIT_CREATED' else 'INVENTORY_PURCHASE_UNIT_UPDATED' end,
      'inventory_purchase_unit',v_id,jsonb_build_object('purchaseUnitId',v_id,'itemId',p_item_id,'name',v_name,'conversionToBase',p_conversion,'status',p_status));
  return v_id;
exception when unique_violation then raise exception 'INVENTORY_PURCHASE_UNIT_DUPLICATE' using errcode = '23505';
end; $$;
create function public.create_inventory_purchase_unit(p_tenant_id uuid,p_item_id uuid,p_name text,p_conversion_to_base numeric) returns uuid
language sql security definer set search_path = '' as $$ select private.save_inventory_purchase_unit(p_tenant_id,null,p_item_id,p_name,p_conversion_to_base,'ACTIVE'); $$;
create function public.update_inventory_purchase_unit(p_tenant_id uuid,p_purchase_unit_id uuid,p_name text,p_conversion_to_base numeric,p_status text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_item uuid;
begin
  perform private.require_inventory_access(p_tenant_id,'inventory.write');
  select inventory_item_id into v_item from public.inventory_purchase_units where id = p_purchase_unit_id and tenant_id = p_tenant_id;
  if not found then raise exception 'INVENTORY_PURCHASE_UNIT_NOT_AVAILABLE' using errcode = '22023'; end if;
  return private.save_inventory_purchase_unit(p_tenant_id,p_purchase_unit_id,v_item,p_name,p_conversion_to_base,p_status);
end; $$;
create function public.get_inventory_purchase_units(p_tenant_id uuid,p_item_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if private.has_permission(p_tenant_id,'inventory.read') then perform private.require_inventory_access(p_tenant_id,'inventory.read');
  else perform private.require_inventory_access(p_tenant_id,'inventory.write'); end if;
  if not exists(select 1 from public.inventory_items where id = p_item_id and tenant_id = p_tenant_id) then raise exception 'INVENTORY_ITEM_NOT_AVAILABLE' using errcode = '22023'; end if;
  return jsonb_build_object('tenantId',p_tenant_id,'itemId',p_item_id,'units',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'conversionToBase',conversion_to_base,'status',status) order by name,id),'[]') from public.inventory_purchase_units where tenant_id = p_tenant_id and inventory_item_id = p_item_id));
end; $$;

create function private.validate_purchase_mapping(p_tenant_id uuid,p_lines jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare l jsonb;
begin
  if exists(select 1 from jsonb_array_elements(p_lines) x where x->>'inventoryTracking' = 'MAPPED') then
    if not private.is_module_enabled(p_tenant_id,'inventory') then raise exception 'INVENTORY_MODULE_NOT_AVAILABLE' using errcode = '42501'; end if;
    perform 1 from public.inventory_items i where i.tenant_id = p_tenant_id and i.id in
      (select (x->>'inventoryItemId')::uuid from jsonb_array_elements(p_lines) x where x->>'inventoryTracking' = 'MAPPED') order by i.id for share;
  end if;
  for l in select value from jsonb_array_elements(p_lines) where value->>'inventoryTracking' = 'MAPPED' loop
    if not exists(select 1 from public.inventory_items where id = (l->>'inventoryItemId')::uuid and tenant_id = p_tenant_id and status = 'ACTIVE') then
      raise exception 'INVENTORY_ITEM_NOT_AVAILABLE' using errcode = '22023'; end if;
    perform 1 from public.inventory_purchase_units where id = (l->>'inventoryPurchaseUnitId')::uuid and inventory_item_id = (l->>'inventoryItemId')::uuid and tenant_id = p_tenant_id and status = 'ACTIVE' for share;
    if not found then raise exception 'INVENTORY_PURCHASE_UNIT_NOT_AVAILABLE' using errcode = '22023'; end if;
  end loop;
end; $$;
create function private.purchase_inventory_quantity(p_quantity numeric,p_conversion numeric) returns numeric
language plpgsql immutable set search_path = '' as $$
declare q numeric := p_quantity * p_conversion;
begin
  if q is null or q = 'NaN'::numeric or q <= 0 or q > 999999999999.9999 then raise exception 'PURCHASE_INVENTORY_QUANTITY_OVERFLOW' using errcode = '22003'; end if;
  if q <> round(q,4) then raise exception 'PURCHASE_INVENTORY_QUANTITY_PRECISION' using errcode = '22023'; end if;
  return q;
end; $$;

revoke all on function private.guard_inventory_purchase_unit(),private.save_inventory_purchase_unit(uuid,uuid,uuid,text,numeric,text),
  private.validate_purchase_mapping(uuid,jsonb),private.purchase_inventory_quantity(numeric,numeric) from public,anon,authenticated;
revoke all on function public.create_inventory_purchase_unit(uuid,uuid,text,numeric),public.update_inventory_purchase_unit(uuid,uuid,text,numeric,text),public.get_inventory_purchase_units(uuid,uuid) from public,anon;
grant execute on function public.create_inventory_purchase_unit(uuid,uuid,text,numeric),public.update_inventory_purchase_unit(uuid,uuid,text,numeric,text),public.get_inventory_purchase_units(uuid,uuid) to authenticated,service_role;

create or replace function public.post_purchase_invoice(p_tenant_id uuid,p_invoice_id uuid) returns uuid
language plpgsql volatile security definer set search_path = '' as $$
declare inv public.purchase_invoices%rowtype; calc jsonb; l jsonb; line record; q numeric; receipts jsonb := '[]';
begin
  perform private.require_purchase_access(p_tenant_id,'purchasing.write',true);
  select * into inv from public.purchase_invoices where id = p_invoice_id and tenant_id = p_tenant_id for update;
  if not found then raise exception 'PURCHASE_INVOICE_NOT_AVAILABLE' using errcode = '22023'; end if;
  if inv.status <> 'DRAFT' then raise exception 'PURCHASE_INVOICE_ALREADY_POSTED' using errcode = '55000'; end if;
  perform private.check_purchase_header(p_tenant_id,inv.supplier_id,inv.location_id,inv.invoice_number,inv.invoice_date,inv.due_date,inv.currency_code,inv.description);
  calc := private.calculate_purchase_lines(private.purchase_line_data(p_invoice_id));
  if exists(select 1 from jsonb_array_elements(calc->'lines') x where x->>'inventoryTracking' = 'UNMAPPED') then
    raise exception 'PURCHASE_INVOICE_LINES_UNMAPPED' using errcode = '22023'; end if;
  if exists(select 1 from jsonb_array_elements(calc->'lines') x where x->>'inventoryTracking' = 'MAPPED') and inv.location_id is null then
    raise exception 'PURCHASE_INVOICE_LOCATION_REQUIRED_FOR_INVENTORY' using errcode = '22023'; end if;
  -- Serialize with stock counts, manual movements and purchase-unit edits, always in item order.
  perform 1 from public.inventory_items i where i.tenant_id = p_tenant_id and i.id in
    (select inventory_item_id from public.purchase_invoice_lines where purchase_invoice_id = p_invoice_id and inventory_tracking = 'MAPPED') order by i.id for update;
  perform private.validate_purchase_mapping(p_tenant_id,calc->'lines');
  if (calc->>'grandTotal')::numeric <= 0 then raise exception 'PURCHASE_INVOICE_TOTAL_MUST_BE_POSITIVE' using errcode = '22023'; end if;
  for l in select value from jsonb_array_elements(calc->'lines') loop
    update public.purchase_invoice_lines set net_amount = (l->>'netAmount')::numeric,tax_amount = (l->>'taxAmount')::numeric,
      gross_amount = (l->>'grossAmount')::numeric,updated_at = now() where tenant_id = p_tenant_id and purchase_invoice_id = p_invoice_id and line_no = (l->>'lineNo')::integer;
  end loop;
  insert into public.supplier_ledger_entries(tenant_id,supplier_id,entry_type,currency_code,amount,occurred_at,description,source_type,source_id,created_by_user_id)
    values(p_tenant_id,inv.supplier_id,'INVOICE',inv.currency_code,(calc->>'grandTotal')::numeric,inv.invoice_date::timestamptz,'Fatura: '||inv.invoice_number,'PURCHASE_INVOICE',p_invoice_id,auth.uid());
  for line in select pl.id,pl.inventory_item_id,pl.quantity,pl.description,u.conversion_to_base,i.base_unit
    from public.purchase_invoice_lines pl join public.inventory_purchase_units u on u.id = pl.inventory_purchase_unit_id and u.inventory_item_id = pl.inventory_item_id and u.tenant_id = pl.tenant_id
    join public.inventory_items i on i.id = pl.inventory_item_id and i.tenant_id = pl.tenant_id
    where pl.purchase_invoice_id = p_invoice_id and pl.tenant_id = p_tenant_id and pl.inventory_tracking = 'MAPPED' order by pl.line_no loop
    q := private.purchase_inventory_quantity(line.quantity,line.conversion_to_base);
    insert into public.inventory_movements(tenant_id,location_id,inventory_item_id,movement_type,quantity,occurred_at,description,source_type,source_id,source_line_id,created_by_user_id)
      values(p_tenant_id,inv.location_id,line.inventory_item_id,'RECEIPT',q,inv.invoice_date::timestamptz,'Fatura: '||inv.invoice_number||' · '||line.description,'PURCHASE_INVOICE',p_invoice_id,line.id,auth.uid());
    receipts := receipts || jsonb_build_array(jsonb_build_object('lineId',line.id,'itemId',line.inventory_item_id,'purchaseQuantity',line.quantity,
      'conversionToBase',line.conversion_to_base,'baseQuantity',q,'baseUnit',line.base_unit));
  end loop;
  update public.purchase_invoices set status = 'POSTED',posted_at = now(),posted_by_user_id = auth.uid(),updated_at = now(),
    subtotal = (calc->>'subtotal')::numeric,tax_total = (calc->>'taxTotal')::numeric,grand_total = (calc->>'grandTotal')::numeric where id = p_invoice_id and tenant_id = p_tenant_id;
  insert into public.audit_logs(tenant_id,location_id,actor_user_id,action,entity_type,entity_id,metadata)
    values(p_tenant_id,inv.location_id,auth.uid(),'PURCHASE_INVOICE_POSTED','purchase_invoice',p_invoice_id,
      jsonb_build_object('invoiceId',p_invoice_id,'supplierId',inv.supplier_id,'invoiceNumber',inv.invoice_number,'currencyCode',inv.currency_code,
      'subtotal',(calc->>'subtotal')::numeric,'taxTotal',(calc->>'taxTotal')::numeric,'grandTotal',(calc->>'grandTotal')::numeric,
      'lineCount',jsonb_array_length(calc->'lines'),'inventoryReceiptCount',jsonb_array_length(receipts),'inventoryReceipts',receipts));
  return p_invoice_id;
end; $$;

create or replace function public.get_purchase_invoice_context(p_tenant_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare enabled boolean;
begin
  perform private.require_purchase_access(p_tenant_id,'purchasing.write',true);
  enabled := private.is_module_enabled(p_tenant_id,'inventory');
  return jsonb_build_object('tenantId',p_tenant_id,'inventoryEnabled',enabled,
    'suppliers',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by name,id),'[]') from public.suppliers where tenant_id = p_tenant_id and status = 'ACTIVE'),
    'locations',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by name,id),'[]') from public.locations where tenant_id = p_tenant_id and status = 'ACTIVE'),
    'inventoryItems',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'baseUnit',base_unit) order by name,id),'[]') from public.inventory_items where tenant_id = p_tenant_id and status = 'ACTIVE' and enabled),
    'purchaseUnits',(select coalesce(jsonb_agg(jsonb_build_object('id',u.id,'itemId',u.inventory_item_id,'name',u.name,'conversionToBase',u.conversion_to_base) order by u.name,u.id),'[]')
      from public.inventory_purchase_units u join public.inventory_items i on i.id = u.inventory_item_id and i.tenant_id = u.tenant_id
      where u.tenant_id = p_tenant_id and u.status = 'ACTIVE' and i.status = 'ACTIVE' and enabled));
end; $$;

create or replace function private.calculate_purchase_lines(p_lines jsonb) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare
  l jsonb; result jsonb := '[]'; n integer := 0;
  q numeric; price numeric; rate numeric; net numeric; tax numeric; gross numeric;
  subtotal numeric := 0; tax_total numeric := 0; total numeric := 0;
  description text; unit text; code text; item_id uuid; includes boolean; tracking text; purchase_unit_id uuid;
begin
  if jsonb_typeof(p_lines) is distinct from 'array' then raise exception 'PURCHASE_LINES_REQUIRED' using errcode = '22023'; end if;
  if jsonb_array_length(p_lines) < 1 or jsonb_array_length(p_lines) > 200 then
    raise exception 'PURCHASE_LINES_REQUIRED' using errcode = '22023'; end if;
  for l in select value from jsonb_array_elements(p_lines) loop
    n := n + 1;
    if jsonb_typeof(l) <> 'object' or jsonb_typeof(l->'quantity') is distinct from 'number'
      or jsonb_typeof(l->'unitPrice') is distinct from 'number' or jsonb_typeof(l->'taxRate') is distinct from 'number'
      or jsonb_typeof(l->'priceIncludesTax') is distinct from 'boolean'
      or jsonb_typeof(l->'description') is distinct from 'string' or jsonb_typeof(l->'unit') is distinct from 'string' then
      raise exception 'PURCHASE_LINE_INVALID' using errcode = '22023'; end if;
    q := (l->>'quantity')::numeric; price := (l->>'unitPrice')::numeric; rate := (l->>'taxRate')::numeric;
    if q <= 0 or price < 0 or rate < 0 or rate > 100
      or q <> round(q,4) or price <> round(price,4) or rate <> round(rate,3) then
      raise exception 'PURCHASE_LINE_INVALID' using errcode = '22023'; end if;
    if q > 999999999999.9999 or price > 999999999999.9999 then
      raise exception 'PURCHASE_AMOUNT_OVERFLOW' using errcode = '22003'; end if;
    description := trim(l->>'description'); unit := trim(l->>'unit'); code := nullif(trim(l->>'supplierProductCode'),'');
    if char_length(description) not between 2 and 300 or char_length(unit) not between 1 and 30 or char_length(code) > 100 then
      raise exception 'PURCHASE_LINE_INVALID' using errcode = '22023'; end if;
    item_id := nullif(l->>'inventoryItemId','')::uuid;
    purchase_unit_id := nullif(l->>'inventoryPurchaseUnitId','')::uuid;
    tracking := case when l ? 'inventoryTracking' then l->>'inventoryTracking' else 'UNMAPPED' end;
    if tracking is null or tracking not in ('UNMAPPED','MAPPED','NON_STOCK')
      or (tracking = 'MAPPED' and (item_id is null or purchase_unit_id is null))
      or (tracking <> 'MAPPED' and (item_id is not null or purchase_unit_id is not null)) then
      raise exception 'PURCHASE_INVENTORY_MAPPING_INVALID' using errcode = '22023'; end if;
    includes := (l->>'priceIncludesTax')::boolean;
    if includes then
      gross := round(q * price,2); net := round(gross / (1 + rate / 100),2); tax := gross - net;
    else
      net := round(q * price,2); tax := round(net * rate / 100,2); gross := net + tax;
    end if;
    subtotal := subtotal + net; tax_total := tax_total + tax; total := total + gross;
    if total > 99999999999999.99 then raise exception 'PURCHASE_AMOUNT_OVERFLOW' using errcode = '22003'; end if;
    result := result || jsonb_build_array(jsonb_build_object('lineNo',n,'description',description,'supplierProductCode',code,
      'unit',unit,'quantity',q,'unitPrice',price,'priceIncludesTax',includes,'taxRate',rate,
      'netAmount',net,'taxAmount',tax,'grossAmount',gross,'inventoryItemId',item_id,'inventoryTracking',tracking,'inventoryPurchaseUnitId',purchase_unit_id));
  end loop;
  return jsonb_build_object('lines',result,'subtotal',subtotal,'taxTotal',tax_total,'grandTotal',total);
exception when invalid_text_representation then raise exception 'PURCHASE_LINE_INVALID' using errcode = '22023';
end;
$$;

create or replace function private.purchase_line_data(p_invoice_id uuid) returns jsonb language sql stable set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id',id,'lineNo',line_no,'description',description,
    'supplierProductCode',supplier_product_code,'unit',unit,'quantity',quantity,'unitPrice',unit_price,
    'priceIncludesTax',price_includes_tax,'taxRate',tax_rate,'netAmount',net_amount,'taxAmount',tax_amount,
    'grossAmount',gross_amount,'inventoryItemId',inventory_item_id,'inventoryTracking',inventory_tracking,'inventoryPurchaseUnitId',inventory_purchase_unit_id,
    'inventoryItemName',(select name from public.inventory_items where id = inventory_item_id),
    'inventoryBaseUnit',(select base_unit from public.inventory_items where id = inventory_item_id),
    'inventoryPurchaseUnitName',(select name from public.inventory_purchase_units where id = inventory_purchase_unit_id)) order by line_no),'[]'::jsonb)
  from public.purchase_invoice_lines where purchase_invoice_id = p_invoice_id;
$$;

create or replace function private.save_purchase_draft(p_tenant_id uuid,p_invoice_id uuid,p_supplier_id uuid,p_location_id uuid,
  p_invoice_number text,p_invoice_date date,p_due_date date,p_currency_code text,p_description text,p_lines jsonb)
returns uuid language plpgsql volatile security definer set search_path = '' as $$
declare
  v_id uuid := coalesce(p_invoice_id,gen_random_uuid()); old public.purchase_invoices%rowtype;
  calc jsonb; l jsonb; v_number text := trim(p_invoice_number); v_currency text := upper(trim(p_currency_code));
  v_description text := nullif(trim(p_description),'');
begin
  perform private.require_purchase_access(p_tenant_id,'purchasing.write',true);
  if p_invoice_id is not null then
    select * into old from public.purchase_invoices where id = p_invoice_id and tenant_id = p_tenant_id for update;
    if not found then raise exception 'PURCHASE_INVOICE_NOT_AVAILABLE' using errcode = '22023'; end if;
    if old.status <> 'DRAFT' then raise exception 'PURCHASE_INVOICE_IMMUTABLE' using errcode = '55000'; end if;
  end if;
  perform private.check_purchase_header(p_tenant_id,p_supplier_id,p_location_id,v_number,p_invoice_date,p_due_date,v_currency,v_description);
  calc := private.calculate_purchase_lines(p_lines);
  perform private.validate_purchase_mapping(p_tenant_id,calc->'lines');
  if p_invoice_id is not null and (old.supplier_id,old.location_id,old.invoice_number,old.invoice_date,old.due_date,old.currency_code,old.description)
    is not distinct from (p_supplier_id,p_location_id,v_number,p_invoice_date,p_due_date,v_currency,v_description)
    and private.calculate_purchase_lines(private.purchase_line_data(v_id)) = calc then
    raise exception 'PURCHASE_INVOICE_NO_CHANGES' using errcode = '22023';
  end if;
  begin
    if p_invoice_id is null then
      insert into public.purchase_invoices(id,tenant_id,supplier_id,location_id,invoice_number,invoice_date,due_date,currency_code,
        description,subtotal,tax_total,grand_total,created_by_user_id)
      values(v_id,p_tenant_id,p_supplier_id,p_location_id,v_number,p_invoice_date,p_due_date,v_currency,v_description,
        (calc->>'subtotal')::numeric,(calc->>'taxTotal')::numeric,(calc->>'grandTotal')::numeric,auth.uid());
    else
      update public.purchase_invoices set supplier_id = p_supplier_id,location_id = p_location_id,invoice_number = v_number,
        invoice_date = p_invoice_date,due_date = p_due_date,currency_code = v_currency,description = v_description,
        subtotal = (calc->>'subtotal')::numeric,tax_total = (calc->>'taxTotal')::numeric,grand_total = (calc->>'grandTotal')::numeric,updated_at = now()
      where id = v_id and tenant_id = p_tenant_id;
      delete from public.purchase_invoice_lines where purchase_invoice_id = v_id and tenant_id = p_tenant_id;
    end if;
  exception when unique_violation then raise exception 'PURCHASE_INVOICE_NUMBER_EXISTS' using errcode = '23505'; end;
  for l in select value from jsonb_array_elements(calc->'lines') loop
    insert into public.purchase_invoice_lines(tenant_id,purchase_invoice_id,line_no,description,supplier_product_code,unit,quantity,unit_price,
      price_includes_tax,tax_rate,net_amount,tax_amount,gross_amount,inventory_item_id,inventory_tracking,inventory_purchase_unit_id)
    values(p_tenant_id,v_id,(l->>'lineNo')::integer,l->>'description',l->>'supplierProductCode',l->>'unit',(l->>'quantity')::numeric,
      (l->>'unitPrice')::numeric,(l->>'priceIncludesTax')::boolean,(l->>'taxRate')::numeric,(l->>'netAmount')::numeric,
      (l->>'taxAmount')::numeric,(l->>'grossAmount')::numeric,(l->>'inventoryItemId')::uuid,l->>'inventoryTracking',(l->>'inventoryPurchaseUnitId')::uuid);
  end loop;
  insert into public.audit_logs(tenant_id,location_id,actor_user_id,action,entity_type,entity_id,metadata)
  values(p_tenant_id,p_location_id,auth.uid(),case when p_invoice_id is null then 'PURCHASE_INVOICE_DRAFT_CREATED' else 'PURCHASE_INVOICE_DRAFT_UPDATED' end,
    'purchase_invoice',v_id,jsonb_build_object('invoiceId',v_id,'supplierId',p_supplier_id,'invoiceNumber',v_number,'currencyCode',v_currency,
      'lineCount',jsonb_array_length(calc->'lines'),'grandTotal',(calc->>'grandTotal')::numeric));
  return v_id;
end;
$$;
