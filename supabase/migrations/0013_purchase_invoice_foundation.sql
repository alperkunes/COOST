-- Drafts have no ledger effect. Posting increases supplier debt, never cash or inventory.
create table public.purchase_invoices (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  supplier_id uuid not null,
  location_id uuid,
  invoice_number text not null check (invoice_number = trim(invoice_number) and char_length(invoice_number) between 1 and 100),
  invoice_date date not null check (isfinite(invoice_date)),
  due_date date check (isfinite(due_date)),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  status text not null default 'DRAFT' check (status in ('DRAFT','POSTED')),
  subtotal numeric(16,2) not null check (subtotal >= 0 and subtotal <> 'NaN'::numeric),
  tax_total numeric(16,2) not null check (tax_total >= 0 and tax_total <> 'NaN'::numeric),
  grand_total numeric(16,2) not null check (grand_total = subtotal + tax_total),
  description text check (char_length(description) <= 2000),
  created_by_user_id uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  posted_at timestamptz,
  posted_by_user_id uuid references auth.users(id) on delete restrict,
  unique (id,tenant_id),
  unique (tenant_id,supplier_id,invoice_number),
  foreign key (supplier_id,tenant_id) references public.suppliers(id,tenant_id) on delete restrict,
  foreign key (location_id,tenant_id) references public.locations(id,tenant_id) on delete restrict,
  check (due_date is null or due_date >= invoice_date),
  check ((status = 'DRAFT' and posted_at is null and posted_by_user_id is null)
    or (status = 'POSTED' and posted_at is not null and posted_by_user_id is not null and grand_total > 0))
);
create index purchase_invoices_recent on public.purchase_invoices(tenant_id,invoice_date desc,id desc);
create table public.purchase_invoice_lines (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  purchase_invoice_id uuid not null,
  line_no integer not null check (line_no > 0),
  description text not null check (char_length(trim(description)) between 2 and 300),
  supplier_product_code text check (char_length(supplier_product_code) <= 100),
  unit text not null check (char_length(trim(unit)) between 1 and 30),
  quantity numeric(16,4) not null check (quantity > 0 and quantity <> 'NaN'::numeric),
  unit_price numeric(16,4) not null check (unit_price >= 0 and unit_price <> 'NaN'::numeric),
  price_includes_tax boolean not null,
  tax_rate numeric(6,3) not null check (tax_rate between 0 and 100),
  net_amount numeric(16,2) not null check (net_amount >= 0 and net_amount <> 'NaN'::numeric),
  tax_amount numeric(16,2) not null check (tax_amount >= 0 and tax_amount <> 'NaN'::numeric),
  gross_amount numeric(16,2) not null check (gross_amount = net_amount + tax_amount),
  inventory_item_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id,purchase_invoice_id,line_no),
  foreign key (purchase_invoice_id,tenant_id) references public.purchase_invoices(id,tenant_id) on delete restrict
);
comment on column public.purchase_invoice_lines.inventory_item_id
  is 'Nullable placeholder for future inventory item mapping; no FK or stock movement in v1.';
create unique index supplier_ledger_purchase_invoice_source on public.supplier_ledger_entries(tenant_id,source_id)
  where source_type = 'PURCHASE_INVOICE' and entry_type = 'INVOICE';
alter table public.purchase_invoices enable row level security;
alter table public.purchase_invoice_lines enable row level security;
revoke all on public.purchase_invoices,public.purchase_invoice_lines from public,anon,authenticated;
grant select on public.purchase_invoices,public.purchase_invoice_lines to authenticated;
create policy purchase_invoices_read on public.purchase_invoices for select to authenticated
  using (private.is_module_enabled(tenant_id,'purchasing') and private.has_permission(tenant_id,'purchasing.read'));
create policy purchase_invoice_lines_read on public.purchase_invoice_lines for select to authenticated
  using (private.is_module_enabled(tenant_id,'purchasing') and private.has_permission(tenant_id,'purchasing.read'));

create function private.guard_purchase_invoice() returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'DELETE' or old.status = 'POSTED' then
    raise exception 'PURCHASE_INVOICE_IMMUTABLE' using errcode = '55000';
  end if;
  if new.id <> old.id or new.tenant_id <> old.tenant_id then
    raise exception 'PURCHASE_INVOICE_IMMUTABLE' using errcode = '55000';
  end if;
  return new;
end;
$$;
create trigger purchase_invoice_guard before update or delete on public.purchase_invoices
  for each row execute function private.guard_purchase_invoice();
create function private.guard_purchase_invoice_line() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_status text;
begin
  if tg_op = 'UPDATE' and (new.purchase_invoice_id <> old.purchase_invoice_id or new.tenant_id <> old.tenant_id) then
    raise exception 'PURCHASE_INVOICE_IMMUTABLE' using errcode = '55000';
  end if;
  if tg_op = 'DELETE' then
    select status into v_status from public.purchase_invoices where id = old.purchase_invoice_id and tenant_id = old.tenant_id for update;
  else
    select status into v_status from public.purchase_invoices where id = new.purchase_invoice_id and tenant_id = new.tenant_id for update;
  end if;
  if v_status = 'POSTED' then raise exception 'PURCHASE_INVOICE_IMMUTABLE' using errcode = '55000'; end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;
create trigger purchase_invoice_line_guard before insert or update or delete on public.purchase_invoice_lines
  for each row execute function private.guard_purchase_invoice_line();

create function private.require_purchase_access(p_tenant_id uuid,p_permission text,p_entry boolean default false)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501'; end if;
  if not private.is_module_enabled(p_tenant_id,'purchasing') then
    raise exception 'PURCHASING_MODULE_NOT_AVAILABLE' using errcode = '42501'; end if;
  if not private.has_permission(p_tenant_id,p_permission) then
    raise exception 'PURCHASING_PERMISSION_DENIED' using errcode = '42501'; end if;
  if p_entry and not private.is_module_enabled(p_tenant_id,'suppliers') then
    raise exception 'SUPPLIERS_MODULE_NOT_AVAILABLE' using errcode = '42501'; end if;
end;
$$;

-- Round each line's anchor amount first (net if exclusive, gross if inclusive).
-- Derive the remainder so net + tax always equals gross to the cent.
create function private.calculate_purchase_lines(p_lines jsonb) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare
  l jsonb; result jsonb := '[]'; n integer := 0;
  q numeric; price numeric; rate numeric; net numeric; tax numeric; gross numeric;
  subtotal numeric := 0; tax_total numeric := 0; total numeric := 0;
  description text; unit text; code text; item_id uuid; includes boolean;
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
      'netAmount',net,'taxAmount',tax,'grossAmount',gross,'inventoryItemId',item_id));
  end loop;
  return jsonb_build_object('lines',result,'subtotal',subtotal,'taxTotal',tax_total,'grandTotal',total);
exception when invalid_text_representation then raise exception 'PURCHASE_LINE_INVALID' using errcode = '22023';
end;
$$;

create function private.check_purchase_header(p_tenant_id uuid,p_supplier_id uuid,p_location_id uuid,
  p_number text,p_date date,p_due date,p_currency text,p_description text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if p_number is null or char_length(p_number) not between 1 and 100 or char_length(p_description) > 2000 then
    raise exception 'PURCHASE_HEADER_INVALID' using errcode = '22023'; end if;
  if p_date is null or not isfinite(p_date) or (p_due is not null and (not isfinite(p_due) or p_due < p_date)) then
    raise exception 'PURCHASE_DATES_INVALID' using errcode = '22023'; end if;
  if p_currency is null or p_currency !~ '^[A-Z]{3}$' then raise exception 'PURCHASE_CURRENCY_INVALID' using errcode = '22023'; end if;
  perform 1 from public.suppliers where id = p_supplier_id and tenant_id = p_tenant_id and status = 'ACTIVE' for share;
  if not found then raise exception 'SUPPLIER_NOT_AVAILABLE' using errcode = '22023'; end if;
  if p_location_id is not null then
    perform 1 from public.locations where id = p_location_id and tenant_id = p_tenant_id and status = 'ACTIVE' for share;
    if not found then raise exception 'PURCHASE_LOCATION_NOT_AVAILABLE' using errcode = '22023'; end if;
  end if;
end;
$$;

create function private.purchase_line_data(p_invoice_id uuid) returns jsonb language sql stable set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id',id,'lineNo',line_no,'description',description,
    'supplierProductCode',supplier_product_code,'unit',unit,'quantity',quantity,'unitPrice',unit_price,
    'priceIncludesTax',price_includes_tax,'taxRate',tax_rate,'netAmount',net_amount,'taxAmount',tax_amount,
    'grossAmount',gross_amount,'inventoryItemId',inventory_item_id) order by line_no),'[]'::jsonb)
  from public.purchase_invoice_lines where purchase_invoice_id = p_invoice_id;
$$;

create function private.save_purchase_draft(p_tenant_id uuid,p_invoice_id uuid,p_supplier_id uuid,p_location_id uuid,
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
      price_includes_tax,tax_rate,net_amount,tax_amount,gross_amount,inventory_item_id)
    values(p_tenant_id,v_id,(l->>'lineNo')::integer,l->>'description',l->>'supplierProductCode',l->>'unit',(l->>'quantity')::numeric,
      (l->>'unitPrice')::numeric,(l->>'priceIncludesTax')::boolean,(l->>'taxRate')::numeric,(l->>'netAmount')::numeric,
      (l->>'taxAmount')::numeric,(l->>'grossAmount')::numeric,(l->>'inventoryItemId')::uuid);
  end loop;
  insert into public.audit_logs(tenant_id,location_id,actor_user_id,action,entity_type,entity_id,metadata)
  values(p_tenant_id,p_location_id,auth.uid(),case when p_invoice_id is null then 'PURCHASE_INVOICE_DRAFT_CREATED' else 'PURCHASE_INVOICE_DRAFT_UPDATED' end,
    'purchase_invoice',v_id,jsonb_build_object('invoiceId',v_id,'supplierId',p_supplier_id,'invoiceNumber',v_number,'currencyCode',v_currency,
      'lineCount',jsonb_array_length(calc->'lines'),'grandTotal',(calc->>'grandTotal')::numeric));
  return v_id;
end;
$$;

create function public.create_purchase_invoice_draft(p_tenant_id uuid,p_supplier_id uuid,p_invoice_number text,p_invoice_date date,
  p_currency_code text,p_lines jsonb,p_location_id uuid default null,p_due_date date default null,p_description text default null)
returns uuid language sql volatile security definer set search_path = '' as $$
  select private.save_purchase_draft(p_tenant_id,null,p_supplier_id,p_location_id,p_invoice_number,p_invoice_date,p_due_date,p_currency_code,p_description,p_lines);
$$;
create function public.update_purchase_invoice_draft(p_tenant_id uuid,p_invoice_id uuid,p_supplier_id uuid,p_invoice_number text,p_invoice_date date,
  p_currency_code text,p_lines jsonb,p_location_id uuid default null,p_due_date date default null,p_description text default null)
returns uuid language plpgsql volatile security definer set search_path = '' as $$
begin
  if p_invoice_id is null then raise exception 'PURCHASE_INVOICE_NOT_AVAILABLE' using errcode = '22023'; end if;
  return private.save_purchase_draft(p_tenant_id,p_invoice_id,p_supplier_id,p_location_id,p_invoice_number,p_invoice_date,p_due_date,p_currency_code,p_description,p_lines);
end;
$$;

create function public.post_purchase_invoice(p_tenant_id uuid,p_invoice_id uuid) returns uuid
language plpgsql volatile security definer set search_path = '' as $$
declare inv public.purchase_invoices%rowtype; calc jsonb; l jsonb;
begin
  perform private.require_purchase_access(p_tenant_id,'purchasing.write',true);
  select * into inv from public.purchase_invoices where id = p_invoice_id and tenant_id = p_tenant_id for update;
  if not found then raise exception 'PURCHASE_INVOICE_NOT_AVAILABLE' using errcode = '22023'; end if;
  if inv.status <> 'DRAFT' then raise exception 'PURCHASE_INVOICE_ALREADY_POSTED' using errcode = '55000'; end if;
  perform private.check_purchase_header(p_tenant_id,inv.supplier_id,inv.location_id,inv.invoice_number,inv.invoice_date,inv.due_date,inv.currency_code,inv.description);
  calc := private.calculate_purchase_lines(private.purchase_line_data(p_invoice_id));
  if (calc->>'grandTotal')::numeric <= 0 then raise exception 'PURCHASE_INVOICE_TOTAL_MUST_BE_POSITIVE' using errcode = '22023'; end if;
  for l in select value from jsonb_array_elements(calc->'lines') loop
    update public.purchase_invoice_lines set net_amount = (l->>'netAmount')::numeric,tax_amount = (l->>'taxAmount')::numeric,
      gross_amount = (l->>'grossAmount')::numeric,updated_at = now()
    where tenant_id = p_tenant_id and purchase_invoice_id = p_invoice_id and line_no = (l->>'lineNo')::integer;
  end loop;
  update public.purchase_invoices set status = 'POSTED',posted_at = now(),posted_by_user_id = auth.uid(),updated_at = now(),
    subtotal = (calc->>'subtotal')::numeric,tax_total = (calc->>'taxTotal')::numeric,grand_total = (calc->>'grandTotal')::numeric
  where id = p_invoice_id and tenant_id = p_tenant_id;
  insert into public.supplier_ledger_entries(tenant_id,supplier_id,entry_type,currency_code,amount,occurred_at,description,source_type,source_id,created_by_user_id)
  values(p_tenant_id,inv.supplier_id,'INVOICE',inv.currency_code,(calc->>'grandTotal')::numeric,inv.invoice_date::timestamptz,
    'Fatura: ' || inv.invoice_number,'PURCHASE_INVOICE',p_invoice_id,auth.uid());
  insert into public.audit_logs(tenant_id,location_id,actor_user_id,action,entity_type,entity_id,metadata)
  values(p_tenant_id,inv.location_id,auth.uid(),'PURCHASE_INVOICE_POSTED','purchase_invoice',p_invoice_id,
    jsonb_build_object('invoiceId',p_invoice_id,'supplierId',inv.supplier_id,'invoiceNumber',inv.invoice_number,'currencyCode',inv.currency_code,
      'subtotal',(calc->>'subtotal')::numeric,'taxTotal',(calc->>'taxTotal')::numeric,'grandTotal',(calc->>'grandTotal')::numeric,
      'lineCount',jsonb_array_length(calc->'lines')));
  return p_invoice_id;
end;
$$;

create function private.purchase_header_data(p_invoice_id uuid) returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object('id',i.id,'supplierId',i.supplier_id,'supplierName',s.name,'locationId',i.location_id,'locationName',l.name,
    'invoiceNumber',i.invoice_number,'invoiceDate',i.invoice_date,'dueDate',i.due_date,'currencyCode',i.currency_code,'status',i.status,
    'subtotal',i.subtotal,'taxTotal',i.tax_total,'grandTotal',i.grand_total,'description',i.description,'postedAt',i.posted_at,
    'lineCount',(select count(*) from public.purchase_invoice_lines where purchase_invoice_id = i.id and tenant_id = i.tenant_id))
  from public.purchase_invoices i join public.suppliers s on s.id = i.supplier_id and s.tenant_id = i.tenant_id
  left join public.locations l on l.id = i.location_id and l.tenant_id = i.tenant_id where i.id = p_invoice_id;
$$;
create function public.get_purchase_invoice_overview(p_tenant_id uuid,p_recent_limit integer default 50)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare invoices jsonb; totals jsonb; drafts bigint; posted bigint;
begin
  perform private.require_purchase_access(p_tenant_id,'purchasing.read');
  select coalesce(jsonb_agg(private.purchase_header_data(i.id) order by i.invoice_date desc,i.id desc),'[]'::jsonb) into invoices
  from (select id,invoice_date from public.purchase_invoices where tenant_id = p_tenant_id
    order by invoice_date desc,id desc limit least(greatest(coalesce(p_recent_limit,50),1),100)) i;
  select count(*) filter (where status = 'DRAFT'),count(*) filter (where status = 'POSTED') into drafts,posted
    from public.purchase_invoices where tenant_id = p_tenant_id;
  select coalesce(jsonb_agg(jsonb_build_object('currencyCode',currency_code,'amount',amount) order by currency_code),'[]'::jsonb) into totals
    from (select currency_code,sum(grand_total) amount from public.purchase_invoices where tenant_id = p_tenant_id and status = 'POSTED' group by currency_code) t;
  return jsonb_build_object('tenantId',p_tenant_id,'summary',jsonb_build_object('draftCount',drafts,'postedCount',posted,'postedTotals',totals),'invoices',invoices);
end;
$$;
create function public.get_purchase_invoice_detail(p_tenant_id uuid,p_invoice_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_purchase_access(p_tenant_id,'purchasing.read');
  if not exists(select 1 from public.purchase_invoices where id = p_invoice_id and tenant_id = p_tenant_id) then
    raise exception 'PURCHASE_INVOICE_NOT_AVAILABLE' using errcode = '22023'; end if;
  return jsonb_build_object('tenantId',p_tenant_id,'invoice',private.purchase_header_data(p_invoice_id),'lines',private.purchase_line_data(p_invoice_id));
end;
$$;
create function public.get_purchase_invoice_context(p_tenant_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_purchase_access(p_tenant_id,'purchasing.write',true);
  return jsonb_build_object('tenantId',p_tenant_id,
    'suppliers',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by name,id),'[]'::jsonb) from public.suppliers where tenant_id = p_tenant_id and status = 'ACTIVE'),
    'locations',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by name,id),'[]'::jsonb) from public.locations where tenant_id = p_tenant_id and status = 'ACTIVE'));
end;
$$;

revoke all on function private.guard_purchase_invoice(),private.guard_purchase_invoice_line(),private.require_purchase_access(uuid,text,boolean),
  private.calculate_purchase_lines(jsonb),private.check_purchase_header(uuid,uuid,uuid,text,date,date,text,text),
  private.purchase_line_data(uuid),private.save_purchase_draft(uuid,uuid,uuid,uuid,text,date,date,text,text,jsonb),private.purchase_header_data(uuid)
  from public,anon,authenticated;
revoke all on function public.create_purchase_invoice_draft(uuid,uuid,text,date,text,jsonb,uuid,date,text),
  public.update_purchase_invoice_draft(uuid,uuid,uuid,text,date,text,jsonb,uuid,date,text),public.post_purchase_invoice(uuid,uuid),
  public.get_purchase_invoice_overview(uuid,integer),public.get_purchase_invoice_detail(uuid,uuid),public.get_purchase_invoice_context(uuid)
  from public,anon;
grant execute on function public.create_purchase_invoice_draft(uuid,uuid,text,date,text,jsonb,uuid,date,text),
  public.update_purchase_invoice_draft(uuid,uuid,uuid,text,date,text,jsonb,uuid,date,text),public.post_purchase_invoice(uuid,uuid),
  public.get_purchase_invoice_overview(uuid,integer),public.get_purchase_invoice_detail(uuid,uuid),public.get_purchase_invoice_context(uuid)
  to authenticated,service_role;
