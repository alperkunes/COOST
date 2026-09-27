-- Purchase cost references, not accounting inventory valuation.
insert into public.role_permissions(tenant_id,role_id,permission_key)
select r.tenant_id,r.id,p.key from public.roles r cross join
  (values ('food-service.costing.read'),('food-service.costing.write')) p(key)
where r.key = 'owner' on conflict do nothing;

create table public.recipes (
  id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete restrict,
  name text not null check(name = trim(name) and char_length(name) between 2 and 160),
  code text check(code = trim(code) and char_length(code) between 1 and 100), category text check(char_length(category) <= 120),
  currency_code text not null check(currency_code ~ '^[A-Z]{3}$'),
  portions numeric(12,4) not null check(portions > 0 and portions <> 'NaN'::numeric),
  status text not null default 'ACTIVE' check(status in ('ACTIVE','PASSIVE')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(id,tenant_id), unique(id,tenant_id,currency_code)
);
create unique index recipes_name on public.recipes(tenant_id,lower(regexp_replace(trim(name),'[[:space:]]+',' ','g')));
create unique index recipes_code on public.recipes(tenant_id,lower(code)) where code is not null;
create table public.recipe_lines (
  id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete restrict,
  recipe_id uuid not null, inventory_item_id uuid not null,
  quantity_base numeric(16,4) not null check(quantity_base > 0 and quantity_base <> 'NaN'::numeric),
  line_no integer not null check(line_no > 0), notes text check(char_length(notes) <= 500),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(recipe_id,inventory_item_id), unique(recipe_id,line_no),
  foreign key(recipe_id,tenant_id) references public.recipes(id,tenant_id) on delete restrict,
  foreign key(inventory_item_id,tenant_id) references public.inventory_items(id,tenant_id) on delete restrict
);
create index recipe_lines_item on public.recipe_lines(inventory_item_id,tenant_id);
create index recipe_lines_tenant on public.recipe_lines(tenant_id,recipe_id);
create table public.menu_products (
  id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete restrict,
  name text not null check(name = trim(name) and char_length(name) between 2 and 160),
  code text check(code = trim(code) and char_length(code) between 1 and 100), category text check(char_length(category) <= 120),
  recipe_id uuid not null, currency_code text not null check(currency_code ~ '^[A-Z]{3}$'),
  sale_price_gross numeric(16,2) not null check(sale_price_gross >= 0 and sale_price_gross <> 'NaN'::numeric),
  sales_tax_rate numeric(6,3) not null check(sales_tax_rate between 0 and 100),
  target_food_cost_pct numeric(6,3) check(target_food_cost_pct > 0 and target_food_cost_pct <= 100),
  cost_method text not null default 'WEIGHTED_PURCHASE' check(cost_method in ('LAST_PURCHASE','WEIGHTED_PURCHASE')),
  status text not null default 'ACTIVE' check(status in ('ACTIVE','PASSIVE')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  foreign key(recipe_id,tenant_id,currency_code) references public.recipes(id,tenant_id,currency_code) on delete restrict
);
create unique index menu_products_name on public.menu_products(tenant_id,lower(regexp_replace(trim(name),'[[:space:]]+',' ','g')));
create unique index menu_products_code on public.menu_products(tenant_id,lower(code)) where code is not null;
create index menu_products_recipe on public.menu_products(recipe_id,tenant_id,currency_code);
alter table public.recipes enable row level security;
alter table public.recipe_lines enable row level security;
alter table public.menu_products enable row level security;
revoke all on public.recipes,public.recipe_lines,public.menu_products from public,anon,authenticated;

create function private.require_costing_access(p_tenant_id uuid,p_permission text,p_location_id uuid default null)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501'; end if;
  if not private.is_module_enabled(p_tenant_id,'food-service') then raise exception 'COSTING_MODULE_NOT_AVAILABLE' using errcode = '42501'; end if;
  if not private.has_permission(p_tenant_id,p_permission) then raise exception 'COSTING_PERMISSION_DENIED' using errcode = '42501'; end if;
  if p_location_id is not null and not exists(select 1 from public.locations where id = p_location_id and tenant_id = p_tenant_id) then
    raise exception 'COSTING_LOCATION_NOT_AVAILABLE' using errcode = '22023'; end if;
end; $$;
create function private.guard_costing_record() returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'DELETE' then raise exception 'COSTING_HARD_DELETE_FORBIDDEN' using errcode = '55000'; end if;
  if (new.id,new.tenant_id) is distinct from (old.id,old.tenant_id) then raise exception 'COSTING_IDENTITY_IMMUTABLE' using errcode = '55000'; end if;
  return new;
end; $$;
create trigger recipes_guard before update or delete on public.recipes for each row execute function private.guard_costing_record();
create trigger menu_products_guard before update or delete on public.menu_products for each row execute function private.guard_costing_record();

-- The receipt quantity is immutable; never read the current purchase-unit conversion here.
create function private.purchase_costs(p_tenant_id uuid,p_currency_code text,p_location_id uuid)
returns table(item_id uuid,last_purchase jsonb,previous_purchase jsonb,last_unit_cost numeric,weighted_unit_cost numeric,
  receipt_count bigint,base_quantity numeric,net_total numeric,price_change_pct numeric)
language sql stable set search_path = '' as $$
  with receipts as (
    select m.inventory_item_id,pl.net_amount,m.quantity,pl.net_amount/m.quantity as unit_cost,
      pi.invoice_date,pi.invoice_number,s.name as supplier_name,
      row_number() over(partition by m.inventory_item_id order by pi.invoice_date desc,pi.posted_at desc,pl.line_no desc,pi.id desc,pl.id desc) as rn
    from public.inventory_movements m
    join public.purchase_invoice_lines pl on pl.id = m.source_line_id and pl.tenant_id = m.tenant_id and pl.purchase_invoice_id = m.source_id and pl.inventory_item_id = m.inventory_item_id
    join public.purchase_invoices pi on pi.id = pl.purchase_invoice_id and pi.tenant_id = pl.tenant_id
    join public.suppliers s on s.id = pi.supplier_id and s.tenant_id = pi.tenant_id
    where m.tenant_id = p_tenant_id and m.source_type = 'PURCHASE_INVOICE' and m.movement_type = 'RECEIPT'
      and pi.status = 'POSTED' and pl.inventory_tracking = 'MAPPED' and pi.currency_code = p_currency_code
      and (p_location_id is null or m.location_id = p_location_id)
  )
  select inventory_item_id,
    (jsonb_agg(jsonb_build_object('unitCost',unit_cost,'invoiceDate',invoice_date,'invoiceNumber',invoice_number,'supplierName',supplier_name,'receiptBaseQuantity',quantity)) filter(where rn = 1))->0,
    (jsonb_agg(jsonb_build_object('unitCost',unit_cost,'invoiceDate',invoice_date)) filter(where rn = 2))->0,
    max(unit_cost) filter(where rn = 1),sum(net_amount)/sum(quantity),count(*),sum(quantity),sum(net_amount),
    ((max(unit_cost) filter(where rn = 1))-(max(unit_cost) filter(where rn = 2)))/nullif(max(unit_cost) filter(where rn = 2),0)*100
  from receipts group by inventory_item_id;
$$;
create function public.get_inventory_cost_overview(p_tenant_id uuid,p_currency_code text,p_location_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_costing_access(p_tenant_id,'food-service.costing.read',p_location_id);
  if p_currency_code is null or p_currency_code !~ '^[A-Z]{3}$' then raise exception 'COSTING_CURRENCY_INVALID' using errcode = '22023'; end if;
  return jsonb_build_object('tenantId',p_tenant_id,'currencyCode',p_currency_code,'locationId',p_location_id,
    'locations',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by name,id),'[]') from public.locations where tenant_id = p_tenant_id),
    'items',(select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'name',i.name,'sku',i.sku,'category',i.category,'baseUnit',i.base_unit,
      'lastPurchase',c.last_purchase,'previousPurchase',c.previous_purchase,'weightedPurchaseUnitCost',c.weighted_unit_cost,
      'purchaseReceiptCount',coalesce(c.receipt_count,0),'purchasedBaseQuantity',coalesce(c.base_quantity,0),'purchaseNetTotal',coalesce(c.net_total,0),
      'priceChangePct',c.price_change_pct,'costStatus',case when c.item_id is null then 'NO_PURCHASE_COST' else 'READY' end) order by i.name,i.id),'[]')
      from public.inventory_items i left join private.purchase_costs(p_tenant_id,p_currency_code,p_location_id) c on c.item_id = i.id
      where i.tenant_id = p_tenant_id and i.status = 'ACTIVE'));
end; $$;

create function private.save_recipe(p_tenant_id uuid,p_id uuid,p_name text,p_code text,p_category text,p_currency_code text,p_portions numeric,p_status text,p_lines jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid := coalesce(p_id,gen_random_uuid()); old public.recipes%rowtype; l jsonb; normalized jsonb := '[]'; previous jsonb; n integer := 0; item uuid; q numeric;
begin
  perform private.require_costing_access(p_tenant_id,'food-service.costing.write');
  p_name := trim(p_name); p_code := nullif(trim(p_code),''); p_category := nullif(trim(p_category),'');
  if p_name is null or char_length(p_name) not between 2 and 160 or char_length(p_code) > 100 or char_length(p_category) > 120
    or p_currency_code is null or p_currency_code !~ '^[A-Z]{3}$' or p_portions is null or p_portions <= 0 or p_portions = 'NaN'::numeric
    or p_portions > 99999999.9999 or p_portions <> round(p_portions,4) or p_status is null or p_status not in ('ACTIVE','PASSIVE') then
    raise exception 'RECIPE_INVALID' using errcode = '22023'; end if;
  if jsonb_typeof(p_lines) is distinct from 'array' then raise exception 'RECIPE_LINES_INVALID' using errcode = '22023'; end if;
  if jsonb_array_length(p_lines) not between 1 and 200 then raise exception 'RECIPE_LINES_INVALID' using errcode = '22023'; end if;
  if p_id is not null then
    select * into old from public.recipes where id = p_id and tenant_id = p_tenant_id for update;
    if not found then raise exception 'RECIPE_NOT_AVAILABLE' using errcode = '22023'; end if;
  end if;
  for l in select value from jsonb_array_elements(p_lines) loop
    if jsonb_typeof(l) is distinct from 'object' or jsonb_typeof(l->'quantityBase') is distinct from 'number' then raise exception 'RECIPE_LINES_INVALID' using errcode = '22023'; end if;
    item := (l->>'inventoryItemId')::uuid; q := (l->>'quantityBase')::numeric;
    if item is null or q <= 0 or q > 999999999999.9999 or q <> round(q,4) or char_length(l->>'notes') > 500 then raise exception 'RECIPE_LINES_INVALID' using errcode = '22023'; end if;
    if exists(select 1 from jsonb_array_elements(normalized) x where x->>'inventoryItemId' = item::text) then raise exception 'RECIPE_DUPLICATE_INGREDIENT' using errcode = '22023'; end if;
    normalized := normalized || jsonb_build_array(jsonb_build_object('inventoryItemId',item,'quantityBase',q,'notes',nullif(trim(l->>'notes'),'')));
  end loop;
  perform 1 from public.inventory_items where tenant_id = p_tenant_id and id in (select (x->>'inventoryItemId')::uuid from jsonb_array_elements(normalized) x) order by id for share;
  if exists(select 1 from jsonb_array_elements(normalized) x where not exists(select 1 from public.inventory_items where id = (x->>'inventoryItemId')::uuid and tenant_id = p_tenant_id and status = 'ACTIVE')) then
    raise exception 'COSTING_ITEM_NOT_AVAILABLE' using errcode = '22023'; end if;
  select jsonb_agg(jsonb_build_object('inventoryItemId',inventory_item_id,'quantityBase',quantity_base,'notes',notes) order by line_no) into previous from public.recipe_lines where recipe_id = v_id and tenant_id = p_tenant_id;
  if p_id is not null and (old.name,old.code,old.category,old.currency_code,old.portions,old.status) is not distinct from (p_name,p_code,p_category,p_currency_code,p_portions,p_status) and previous = normalized then
    raise exception 'COSTING_NO_CHANGES' using errcode = '22023'; end if;
  if p_id is null then
    insert into public.recipes(id,tenant_id,name,code,category,currency_code,portions,status) values(v_id,p_tenant_id,p_name,p_code,p_category,p_currency_code,p_portions,p_status);
  else
    if old.currency_code <> p_currency_code and exists(select 1 from public.menu_products where recipe_id = v_id and tenant_id = p_tenant_id) then raise exception 'RECIPE_CURRENCY_IN_USE' using errcode = '22023'; end if;
    update public.recipes set name = p_name,code = p_code,category = p_category,currency_code = p_currency_code,portions = p_portions,status = p_status,updated_at = now() where id = v_id;
    delete from public.recipe_lines where recipe_id = v_id and tenant_id = p_tenant_id;
  end if;
  for l in select value from jsonb_array_elements(normalized) loop
    n := n + 1;
    insert into public.recipe_lines(tenant_id,recipe_id,inventory_item_id,quantity_base,line_no,notes) values(p_tenant_id,v_id,(l->>'inventoryItemId')::uuid,(l->>'quantityBase')::numeric,n,l->>'notes');
  end loop;
  insert into public.audit_logs(tenant_id,actor_user_id,action,entity_type,entity_id,metadata) values(p_tenant_id,auth.uid(),case when p_id is null then 'RECIPE_CREATED' else 'RECIPE_UPDATED' end,'recipe',v_id,
    jsonb_build_object('recipeId',v_id,'name',p_name,'portions',p_portions,'currencyCode',p_currency_code,'lineCount',n));
  return v_id;
exception when unique_violation then raise exception 'RECIPE_DUPLICATE' using errcode = '23505';
  when invalid_text_representation then raise exception 'RECIPE_LINES_INVALID' using errcode = '22023';
end; $$;
create function public.create_recipe(p_tenant_id uuid,p_name text,p_currency_code text,p_portions numeric,p_lines jsonb,p_code text default null,p_category text default null)
returns uuid language sql security definer set search_path = '' as $$ select private.save_recipe(p_tenant_id,null,p_name,p_code,p_category,p_currency_code,p_portions,'ACTIVE',p_lines); $$;
create function public.update_recipe(p_tenant_id uuid,p_recipe_id uuid,p_name text,p_currency_code text,p_portions numeric,p_status text,p_lines jsonb,p_code text default null,p_category text default null)
returns uuid language sql security definer set search_path = '' as $$ select private.save_recipe(p_tenant_id,p_recipe_id,p_name,p_code,p_category,p_currency_code,p_portions,p_status,p_lines); $$;

create function private.save_menu_product(p_tenant_id uuid,p_id uuid,p_name text,p_code text,p_category text,p_recipe_id uuid,p_currency_code text,p_sale_price_gross numeric,p_sales_tax_rate numeric,p_target_food_cost_pct numeric,p_cost_method text,p_status text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid := coalesce(p_id,gen_random_uuid()); old public.menu_products%rowtype; recipe_currency text;
begin
  perform private.require_costing_access(p_tenant_id,'food-service.costing.write');
  p_name := trim(p_name); p_code := nullif(trim(p_code),''); p_category := nullif(trim(p_category),'');
  if p_name is null or char_length(p_name) not between 2 and 160 or char_length(p_code) > 100 or char_length(p_category) > 120
    or p_currency_code is null or p_currency_code !~ '^[A-Z]{3}$' or p_sale_price_gross is null or p_sale_price_gross < 0 or p_sale_price_gross = 'NaN'::numeric
    or p_sale_price_gross > 99999999999999.99 or p_sale_price_gross <> round(p_sale_price_gross,2)
    or p_sales_tax_rate is null or p_sales_tax_rate not between 0 and 100 or p_sales_tax_rate <> round(p_sales_tax_rate,3)
    or (p_target_food_cost_pct is not null and (p_target_food_cost_pct <= 0 or p_target_food_cost_pct > 100 or p_target_food_cost_pct <> round(p_target_food_cost_pct,3)))
    or p_cost_method is null or p_cost_method not in ('LAST_PURCHASE','WEIGHTED_PURCHASE') or p_status is null or p_status not in ('ACTIVE','PASSIVE') then raise exception 'MENU_PRODUCT_INVALID' using errcode = '22023'; end if;
  select currency_code into recipe_currency from public.recipes where id = p_recipe_id and tenant_id = p_tenant_id for share;
  if not found then raise exception 'RECIPE_NOT_AVAILABLE' using errcode = '22023'; end if;
  if recipe_currency <> p_currency_code then raise exception 'MENU_RECIPE_CURRENCY_MISMATCH' using errcode = '22023'; end if;
  if p_id is not null then
    select * into old from public.menu_products where id = p_id and tenant_id = p_tenant_id for update;
    if not found then raise exception 'MENU_PRODUCT_NOT_AVAILABLE' using errcode = '22023'; end if;
    if (old.name,old.code,old.category,old.recipe_id,old.currency_code,old.sale_price_gross,old.sales_tax_rate,old.target_food_cost_pct,old.cost_method,old.status)
      is not distinct from (p_name,p_code,p_category,p_recipe_id,p_currency_code,p_sale_price_gross,p_sales_tax_rate,p_target_food_cost_pct,p_cost_method,p_status) then raise exception 'COSTING_NO_CHANGES' using errcode = '22023'; end if;
    update public.menu_products set name=p_name,code=p_code,category=p_category,recipe_id=p_recipe_id,currency_code=p_currency_code,sale_price_gross=p_sale_price_gross,
      sales_tax_rate=p_sales_tax_rate,target_food_cost_pct=p_target_food_cost_pct,cost_method=p_cost_method,status=p_status,updated_at=now() where id=v_id;
  else
    insert into public.menu_products(id,tenant_id,name,code,category,recipe_id,currency_code,sale_price_gross,sales_tax_rate,target_food_cost_pct,cost_method,status)
    values(v_id,p_tenant_id,p_name,p_code,p_category,p_recipe_id,p_currency_code,p_sale_price_gross,p_sales_tax_rate,p_target_food_cost_pct,p_cost_method,p_status);
  end if;
  insert into public.audit_logs(tenant_id,actor_user_id,action,entity_type,entity_id,metadata) values(p_tenant_id,auth.uid(),case when p_id is null then 'MENU_PRODUCT_CREATED' else 'MENU_PRODUCT_UPDATED' end,'menu_product',v_id,
    jsonb_build_object('productId',v_id,'recipeId',p_recipe_id,'name',p_name,'currencyCode',p_currency_code,'salePriceGross',p_sale_price_gross,'salesTaxRate',p_sales_tax_rate,'targetFoodCostPct',p_target_food_cost_pct,'costMethod',p_cost_method,'status',p_status));
  return v_id;
exception when unique_violation then raise exception 'MENU_PRODUCT_DUPLICATE' using errcode = '23505';
end; $$;
create function public.create_menu_product(p_tenant_id uuid,p_name text,p_recipe_id uuid,p_currency_code text,p_sale_price_gross numeric,p_sales_tax_rate numeric,p_cost_method text default 'WEIGHTED_PURCHASE',p_target_food_cost_pct numeric default null,p_code text default null,p_category text default null)
returns uuid language sql security definer set search_path = '' as $$ select private.save_menu_product(p_tenant_id,null,p_name,p_code,p_category,p_recipe_id,p_currency_code,p_sale_price_gross,p_sales_tax_rate,p_target_food_cost_pct,p_cost_method,'ACTIVE'); $$;
create function public.update_menu_product(p_tenant_id uuid,p_product_id uuid,p_name text,p_recipe_id uuid,p_currency_code text,p_sale_price_gross numeric,p_sales_tax_rate numeric,p_cost_method text,p_status text,p_target_food_cost_pct numeric default null,p_code text default null,p_category text default null)
returns uuid language sql security definer set search_path = '' as $$ select private.save_menu_product(p_tenant_id,p_product_id,p_name,p_code,p_category,p_recipe_id,p_currency_code,p_sale_price_gross,p_sales_tax_rate,p_target_food_cost_pct,p_cost_method,p_status); $$;

create function private.recipe_costs(p_tenant_id uuid,p_location_id uuid) returns jsonb
language sql stable set search_path = '' as $$
  with currencies as (select distinct currency_code from public.recipes where tenant_id = p_tenant_id),
  costs as materialized (select c.currency_code,p.* from currencies c cross join lateral private.purchase_costs(p_tenant_id,c.currency_code,p_location_id) p),
  calculated as (
    select r.*,coalesce(a.missing,0) as missing,a.lines,
      case when a.missing = 0 then a.last_total end as last_total,case when a.missing = 0 then a.weighted_total end as weighted_total
    from public.recipes r cross join lateral (
      select count(*) filter(where c.item_id is null) as missing,sum(l.quantity_base*c.last_unit_cost) as last_total,sum(l.quantity_base*c.weighted_unit_cost) as weighted_total,
        jsonb_agg(jsonb_build_object('inventoryItemId',i.id,'itemName',i.name,'baseUnit',i.base_unit,'itemStatus',i.status,'quantityBase',l.quantity_base,'notes',l.notes,
          'lastUnitCost',c.last_unit_cost,'weightedUnitCost',c.weighted_unit_cost,'lastLineCost',l.quantity_base*c.last_unit_cost,'weightedLineCost',l.quantity_base*c.weighted_unit_cost,
          'costStatus',case when c.item_id is null then 'NO_PURCHASE_COST' else 'READY' end) order by l.line_no) as lines
      from public.recipe_lines l join public.inventory_items i on i.id=l.inventory_item_id and i.tenant_id=l.tenant_id
      left join costs c on c.item_id=i.id and c.currency_code=r.currency_code where l.recipe_id=r.id and l.tenant_id=r.tenant_id
    ) a where r.tenant_id=p_tenant_id
  )
  select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'code',code,'category',category,'currencyCode',currency_code,'portions',portions,'status',status,
    'lines',coalesce(lines,'[]'),'totalLastCost',last_total,'totalWeightedCost',weighted_total,'costPerPortionLast',last_total/portions,
    'costPerPortionWeighted',weighted_total/portions,'missingCostItemCount',missing,'costingComplete',missing=0 and last_total is not null) order by name,id),'[]') from calculated;
$$;
create function public.get_recipe_costing_overview(p_tenant_id uuid,p_location_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_costing_access(p_tenant_id,'food-service.costing.read',p_location_id);
  return jsonb_build_object('tenantId',p_tenant_id,'locationId',p_location_id,'recipes',private.recipe_costs(p_tenant_id,p_location_id));
end; $$;
create function public.get_menu_costing_overview(p_tenant_id uuid,p_location_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare products jsonb;
begin
  perform private.require_costing_access(p_tenant_id,'food-service.costing.read',p_location_id);
  with recipes as (select value r from jsonb_array_elements(private.recipe_costs(p_tenant_id,p_location_id))),
  costs as (select p.*,r->>'name' as recipe_name,(r->>'costingComplete')::boolean as complete,(r->>'missingCostItemCount')::int as missing,
    (r->>case when p.cost_method='LAST_PURCHASE' then 'costPerPortionLast' else 'costPerPortionWeighted' end)::numeric as cost,
    p.sale_price_gross/(1+p.sales_tax_rate/100) as net from public.menu_products p join recipes on (r->>'id')::uuid=p.recipe_id where p.tenant_id=p_tenant_id)
  select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'code',code,'category',category,'recipeId',recipe_id,'recipeName',recipe_name,
    'currencyCode',currency_code,'salePriceGross',sale_price_gross,'salesTaxRate',sales_tax_rate,'targetFoodCostPct',target_food_cost_pct,'costMethod',cost_method,'status',status,
    'costingComplete',complete,'missingCostItemCount',missing,'salePriceNet',net,'recipeCostPerPortion',cost,'foodCostPct',cost/nullif(net,0)*100,
    'contributionMargin',net-cost,'suggestedNetPrice',cost/(target_food_cost_pct/100),'suggestedGrossPrice',cost/(target_food_cost_pct/100)*(1+sales_tax_rate/100),
    'targetDifferencePp',cost/nullif(net,0)*100-target_food_cost_pct) order by name,id),'[]') into products from costs;
  return jsonb_build_object('tenantId',p_tenant_id,'locationId',p_location_id,'products',products);
end; $$;

revoke all on function private.require_costing_access(uuid,text,uuid),private.guard_costing_record(),private.purchase_costs(uuid,text,uuid),private.recipe_costs(uuid,uuid),
  private.save_recipe(uuid,uuid,text,text,text,text,numeric,text,jsonb),private.save_menu_product(uuid,uuid,text,text,text,uuid,text,numeric,numeric,numeric,text,text) from public,anon,authenticated;
revoke all on function public.get_inventory_cost_overview(uuid,text,uuid),public.get_recipe_costing_overview(uuid,uuid),public.get_menu_costing_overview(uuid,uuid),
  public.create_recipe(uuid,text,text,numeric,jsonb,text,text),public.update_recipe(uuid,uuid,text,text,numeric,text,jsonb,text,text),
  public.create_menu_product(uuid,text,uuid,text,numeric,numeric,text,numeric,text,text),public.update_menu_product(uuid,uuid,text,uuid,text,numeric,numeric,text,text,numeric,text,text) from public,anon;
grant execute on function public.get_inventory_cost_overview(uuid,text,uuid),public.get_recipe_costing_overview(uuid,uuid),public.get_menu_costing_overview(uuid,uuid),
  public.create_recipe(uuid,text,text,numeric,jsonb,text,text),public.update_recipe(uuid,uuid,text,text,numeric,text,jsonb,text,text),
  public.create_menu_product(uuid,text,uuid,text,numeric,numeric,text,numeric,text,text),public.update_menu_product(uuid,uuid,text,uuid,text,numeric,numeric,text,text,numeric,text,text) to authenticated,service_role;
