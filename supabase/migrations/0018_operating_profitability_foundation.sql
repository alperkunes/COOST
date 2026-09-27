alter table public.menu_products add column target_operating_margin_pct numeric(6,3)
  check(target_operating_margin_pct > 0 and target_operating_margin_pct < 100),
  add constraint menu_product_currency_identity unique(id,tenant_id,currency_code);
create table public.menu_product_sales_facts (
  id uuid primary key default gen_random_uuid(),tenant_id uuid not null references public.tenants(id) on delete restrict,
  location_id uuid not null,sale_date date not null check(isfinite(sale_date)),menu_product_id uuid not null,
  currency_code text not null check(currency_code ~ '^[A-Z]{3}$'),
  quantity numeric(16,4) not null check(quantity >= 0 and quantity <> 'NaN'::numeric),
  gross_sales numeric(16,2) not null check(gross_sales >= 0 and gross_sales <> 'NaN'::numeric),
  net_sales numeric(16,2) not null check(net_sales >= 0 and net_sales <> 'NaN'::numeric),
  source_type text not null check(source_type in ('MANUAL','NARPOS','IMPORT')),
  created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
  check(quantity > 0 or (gross_sales = 0 and net_sales = 0)),
  unique(tenant_id,location_id,sale_date,menu_product_id,currency_code),
  foreign key(location_id,tenant_id) references public.locations(id,tenant_id) on delete restrict,
  foreign key(menu_product_id,tenant_id,currency_code) references public.menu_products(id,tenant_id,currency_code) on delete restrict
);
create index menu_sales_period on public.menu_product_sales_facts(tenant_id,currency_code,sale_date);
create index menu_sales_product on public.menu_product_sales_facts(menu_product_id,tenant_id,currency_code);
create table public.operating_cost_entries (
  id uuid primary key default gen_random_uuid(),tenant_id uuid not null references public.tenants(id) on delete restrict,
  location_id uuid,occurred_on date not null check(isfinite(occurred_on)),currency_code text not null check(currency_code ~ '^[A-Z]{3}$'),
  category text not null check(category in ('FIXED_OVERHEAD','LABOR','POS_COMMISSION','OTHER_VARIABLE')),
  amount numeric(16,2) not null check(amount > 0 and amount <> 'NaN'::numeric),
  description text not null check(char_length(trim(description)) between 2 and 500),
  source_type text not null check(source_type in ('MANUAL','FINANCE','STAFF','POS')),
  status text not null default 'ACTIVE' check(status in ('ACTIVE','VOID')),
  created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
  foreign key(location_id,tenant_id) references public.locations(id,tenant_id) on delete restrict
);
create index operating_cost_period on public.operating_cost_entries(tenant_id,currency_code,occurred_on);
create index operating_cost_location on public.operating_cost_entries(location_id,tenant_id);
alter table public.menu_product_sales_facts enable row level security;
alter table public.operating_cost_entries enable row level security;
revoke all on public.menu_product_sales_facts,public.operating_cost_entries from public,anon,authenticated;
create trigger sales_fact_guard before update or delete on public.menu_product_sales_facts for each row execute function private.guard_costing_record();
create function private.guard_operating_cost() returns trigger language plpgsql set search_path='' as $$
begin
  if tg_op='DELETE' then raise exception 'COSTING_HARD_DELETE_FORBIDDEN' using errcode='55000'; end if;
  if old.status='VOID' or (new.id,new.tenant_id,new.source_type) is distinct from (old.id,old.tenant_id,old.source_type) then raise exception 'OPERATING_COST_IMMUTABLE' using errcode='55000'; end if;
  return new;
end; $$;
create trigger operating_cost_guard before update or delete on public.operating_cost_entries for each row execute function private.guard_operating_cost();
create function private.check_operating_period(p_start date,p_end date,p_currency text) returns void language plpgsql immutable set search_path='' as $$
begin
  if p_start is null or p_end is null or not isfinite(p_start) or not isfinite(p_end) or p_end<p_start or p_end-p_start>365 then raise exception 'OPERATING_PERIOD_INVALID' using errcode='22023'; end if;
  if p_currency is null or p_currency !~ '^[A-Z]{3}$' then raise exception 'COSTING_CURRENCY_INVALID' using errcode='22023'; end if;
end; $$;
create function public.upsert_menu_product_sales_fact(p_tenant_id uuid,p_location_id uuid,p_sale_date date,p_menu_product_id uuid,p_quantity numeric,p_gross_sales numeric,p_net_sales numeric)
returns uuid language plpgsql security definer set search_path='' as $$
declare old public.menu_product_sales_facts%rowtype; v_currency text; v_id uuid;
begin
  perform private.require_costing_access(p_tenant_id,'food-service.costing.write',p_location_id);
  if p_location_id is null or p_sale_date is null or not isfinite(p_sale_date) or p_quantity is null or p_quantity<0 or p_quantity='NaN'::numeric or p_quantity>999999999999.9999 or p_quantity<>round(p_quantity,4)
    or p_gross_sales is null or p_gross_sales<0 or p_gross_sales='NaN'::numeric or p_gross_sales>99999999999999.99 or p_gross_sales<>round(p_gross_sales,2)
    or p_net_sales is null or p_net_sales<0 or p_net_sales='NaN'::numeric or p_net_sales>99999999999999.99 or p_net_sales<>round(p_net_sales,2)
    or (p_quantity=0 and (p_gross_sales<>0 or p_net_sales<>0)) then raise exception 'MENU_SALES_INVALID' using errcode='22023'; end if;
  -- Serialize daily upserts and currency edits through the product row.
  select currency_code into v_currency from public.menu_products where id=p_menu_product_id and tenant_id=p_tenant_id for update;
  if not found then raise exception 'MENU_PRODUCT_NOT_AVAILABLE' using errcode='22023'; end if;
  select * into old from public.menu_product_sales_facts where tenant_id=p_tenant_id and location_id=p_location_id and sale_date=p_sale_date and menu_product_id=p_menu_product_id and currency_code=v_currency for update;
  if found then
    if old.source_type<>'MANUAL' then raise exception 'MENU_SALES_SOURCE_LOCKED' using errcode='55000'; end if;
    if (old.quantity,old.gross_sales,old.net_sales) is not distinct from (p_quantity,p_gross_sales,p_net_sales) then raise exception 'COSTING_NO_CHANGES' using errcode='22023'; end if;
    v_id:=old.id;
    update public.menu_product_sales_facts set quantity=p_quantity,gross_sales=p_gross_sales,net_sales=p_net_sales,updated_at=now() where id=v_id;
  else
    insert into public.menu_product_sales_facts(tenant_id,location_id,sale_date,menu_product_id,currency_code,quantity,gross_sales,net_sales,source_type)
    values(p_tenant_id,p_location_id,p_sale_date,p_menu_product_id,v_currency,p_quantity,p_gross_sales,p_net_sales,'MANUAL') returning id into v_id;
  end if;
  insert into public.audit_logs(tenant_id,location_id,actor_user_id,action,entity_type,entity_id,metadata) values(p_tenant_id,p_location_id,auth.uid(),case when old.id is null then 'MENU_SALES_FACT_CREATED' else 'MENU_SALES_FACT_UPDATED' end,'menu_product_sales_fact',v_id,
    jsonb_build_object('productId',p_menu_product_id,'saleDate',p_sale_date,'currencyCode',v_currency,'sourceType','MANUAL','old',case when old.id is null then null else jsonb_build_object('quantity',old.quantity,'grossSales',old.gross_sales,'netSales',old.net_sales) end,'new',jsonb_build_object('quantity',p_quantity,'grossSales',p_gross_sales,'netSales',p_net_sales)));
  return v_id;
end; $$;
create function private.save_operating_cost(p_tenant_id uuid,p_id uuid,p_location_id uuid,p_occurred_on date,p_currency_code text,p_category text,p_amount numeric,p_description text)
returns uuid language plpgsql security definer set search_path='' as $$
declare old public.operating_cost_entries%rowtype; v_id uuid;
begin
  perform private.require_costing_access(p_tenant_id,'food-service.costing.write',p_location_id);
  p_description:=trim(p_description);
  if p_occurred_on is null or not isfinite(p_occurred_on) or p_currency_code is null or p_currency_code !~ '^[A-Z]{3}$'
    or p_category is null or p_category not in ('FIXED_OVERHEAD','LABOR','POS_COMMISSION','OTHER_VARIABLE') or p_amount is null or p_amount<=0 or p_amount='NaN'::numeric or p_amount>99999999999999.99 or p_amount<>round(p_amount,2)
    or p_description is null or char_length(p_description) not between 2 and 500 then raise exception 'OPERATING_COST_INVALID' using errcode='22023'; end if;
  if p_id is not null then
    select * into old from public.operating_cost_entries where id=p_id and tenant_id=p_tenant_id for update;
    if not found then raise exception 'OPERATING_COST_NOT_AVAILABLE' using errcode='22023'; end if;
    if old.status<>'ACTIVE' or old.source_type<>'MANUAL' then raise exception 'OPERATING_COST_IMMUTABLE' using errcode='55000'; end if;
    if (old.location_id,old.occurred_on,old.currency_code,old.category,old.amount,old.description) is not distinct from (p_location_id,p_occurred_on,p_currency_code,p_category,p_amount,p_description) then raise exception 'COSTING_NO_CHANGES' using errcode='22023'; end if;
    v_id:=old.id;
    update public.operating_cost_entries set location_id=p_location_id,occurred_on=p_occurred_on,currency_code=p_currency_code,category=p_category,amount=p_amount,description=p_description,updated_at=now() where id=v_id;
  else
    insert into public.operating_cost_entries(tenant_id,location_id,occurred_on,currency_code,category,amount,description,source_type) values(p_tenant_id,p_location_id,p_occurred_on,p_currency_code,p_category,p_amount,p_description,'MANUAL') returning id into v_id;
  end if;
  insert into public.audit_logs(tenant_id,location_id,actor_user_id,action,entity_type,entity_id,metadata) values(p_tenant_id,p_location_id,auth.uid(),case when p_id is null then 'OPERATING_COST_CREATED' else 'OPERATING_COST_UPDATED' end,'operating_cost_entry',v_id,
    jsonb_build_object('old',case when p_id is null then null else to_jsonb(old) end,'new',(select to_jsonb(e) from public.operating_cost_entries e where id=v_id)));
  return v_id;
end; $$;
create function public.create_operating_cost_entry(p_tenant_id uuid,p_occurred_on date,p_currency_code text,p_category text,p_amount numeric,p_description text,p_location_id uuid default null) returns uuid
language sql security definer set search_path='' as $$ select private.save_operating_cost(p_tenant_id,null,p_location_id,p_occurred_on,p_currency_code,p_category,p_amount,p_description); $$;
create function public.update_operating_cost_entry(p_tenant_id uuid,p_entry_id uuid,p_occurred_on date,p_currency_code text,p_category text,p_amount numeric,p_description text,p_location_id uuid default null) returns uuid
language plpgsql security definer set search_path='' as $$ begin
  if p_entry_id is null then raise exception 'OPERATING_COST_NOT_AVAILABLE' using errcode='22023'; end if;
  return private.save_operating_cost(p_tenant_id,p_entry_id,p_location_id,p_occurred_on,p_currency_code,p_category,p_amount,p_description);
end; $$;
create function public.void_operating_cost_entry(p_tenant_id uuid,p_entry_id uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare old public.operating_cost_entries%rowtype;
begin
  perform private.require_costing_access(p_tenant_id,'food-service.costing.write');
  select * into old from public.operating_cost_entries where id=p_entry_id and tenant_id=p_tenant_id for update;
  if not found then raise exception 'OPERATING_COST_NOT_AVAILABLE' using errcode='22023'; end if;
  if old.status<>'ACTIVE' or old.source_type<>'MANUAL' then raise exception 'OPERATING_COST_IMMUTABLE' using errcode='55000'; end if;
  update public.operating_cost_entries set status='VOID',updated_at=now() where id=p_entry_id;
  insert into public.audit_logs(tenant_id,location_id,actor_user_id,action,entity_type,entity_id,metadata) values(p_tenant_id,old.location_id,auth.uid(),'OPERATING_COST_VOIDED','operating_cost_entry',p_entry_id,jsonb_build_object('old',to_jsonb(old),'newStatus','VOID'));
  return p_entry_id;
end; $$;

create function public.get_operating_profitability(p_tenant_id uuid,p_start_date date,p_end_date date,p_currency_code text,p_location_id uuid default null,p_allocation_method text default 'NET_SALES')
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
  perform private.require_costing_access(p_tenant_id,'food-service.costing.read',p_location_id);
  perform private.check_operating_period(p_start_date,p_end_date,p_currency_code);
  if p_allocation_method is null or p_allocation_method not in ('NET_SALES','QUANTITY','EQUAL') then raise exception 'OPERATING_ALLOCATION_INVALID' using errcode='22023'; end if;
  with sales as (
    select menu_product_id,sum(quantity) q,sum(gross_sales) gross,sum(net_sales) net from public.menu_product_sales_facts
    where tenant_id=p_tenant_id and currency_code=p_currency_code and sale_date between p_start_date and p_end_date and (p_location_id is null or location_id=p_location_id) group by menu_product_id
  ), expenses as (
    select coalesce(sum(amount) filter(where category='FIXED_OVERHEAD'),0) fixed,coalesce(sum(amount) filter(where category='LABOR'),0) labor,
      coalesce(sum(amount) filter(where category='POS_COMMISSION'),0) pos,coalesce(sum(amount) filter(where category='OTHER_VARIABLE'),0) other
    from public.operating_cost_entries where tenant_id=p_tenant_id and currency_code=p_currency_code and occurred_on between p_start_date and p_end_date and status='ACTIVE' and (p_location_id is null or location_id=p_location_id or location_id is null)
  ), recipe as (select value r from jsonb_array_elements(private.recipe_costs(p_tenant_id,p_location_id))),
  base as (
    select s.*,p.name,p.category,p.cost_method,p.sales_tax_rate,p.target_operating_margin_pct,(r->>'costingComplete')::boolean complete,
      (r->>case when p.cost_method='LAST_PURCHASE' then 'costPerPortionLast' else 'costPerPortionWeighted' end)::numeric cost,
      case p_allocation_method when 'NET_SALES' then s.net when 'QUANTITY' then s.q else 1 end basis
    from sales s join public.menu_products p on p.id=s.menu_product_id and p.tenant_id=p_tenant_id join recipe on (r->>'id')::uuid=p.recipe_id
  ), ranked as (
    select *,sum(basis) over() denominator,row_number() over(order by basis,menu_product_id) rn,count(*) over() n,
      sum(basis) over(order by basis,menu_product_id rows unbounded preceding) running from base
  ), cumulative as (
    select *,case when denominator=0 then null when rn=n then 1::numeric else running/denominator end cumulative_weight from ranked
  ), allocated as (
    -- Differences of cumulative amounts telescope exactly to each category total, including repeating fractions.
    select c.*,cumulative_weight-coalesce(lag(cumulative_weight) over w,0) weight,
      fixed*cumulative_weight-coalesce(lag(fixed*cumulative_weight) over w,0) af,
      labor*cumulative_weight-coalesce(lag(labor*cumulative_weight) over w,0) al,
      pos*cumulative_weight-coalesce(lag(pos*cumulative_weight) over w,0) ap,
      other*cumulative_weight-coalesce(lag(other*cumulative_weight) over w,0) ao
    from cumulative c cross join expenses window w as(order by basis,menu_product_id)
  ), metrics as (
    select *,q*cost estimated,net-q*cost direct,af+al+ap+ao allocated_cost,net-q*cost-af-al-ap-ao contribution from allocated
  ), totals as (
    select count(*) n,coalesce(sum(q),0) q,coalesce(sum(gross),0) gross,coalesce(sum(net),0) net,
      case when count(*)=0 then 0 when bool_and(complete) then sum(estimated) end estimated,
      case when count(*)=0 then 0 when bool_and(complete) then sum(direct) end direct,
      case when bool_and(complete) then sum(contribution) end contribution,
      case when count(*)=0 then 'NO_SALES' when max(denominator)=0 then 'ZERO_ALLOCATION_BASE' else 'READY' end allocation_status
    from metrics
  )
  select jsonb_build_object('tenantId',p_tenant_id,'startDate',p_start_date,'endDate',p_end_date,'currencyCode',p_currency_code,'locationId',p_location_id,'allocationMethod',p_allocation_method,'allocationStatus',t.allocation_status,
    'summary',jsonb_build_object('totalQuantity',t.q,'grossSales',t.gross,'netSales',t.net,'estimatedRecipeCost',t.estimated,'directContribution',t.direct,
      'operatingCosts',jsonb_build_object('fixedOverhead',e.fixed,'labor',e.labor,'posCommission',e.pos,'otherVariable',e.other,'total',e.fixed+e.labor+e.pos+e.other),
      'allocatedOperatingContribution',t.contribution,'allocatedOperatingMarginPct',t.contribution/nullif(t.net,0)*100),
    'products',(select coalesce(jsonb_agg(jsonb_build_object('productId',menu_product_id,'productName',name,'category',category,'quantitySold',q,'grossSales',gross,'netSales',net,
      'recipeCostMethod',cost_method,'recipeCostPerPortion',cost,'costingComplete',complete,'estimatedRecipeCost',estimated,'directContribution',direct,'directContributionPct',direct/nullif(net,0)*100,
      'allocationWeight',weight,'allocatedFixedOverhead',af,'allocatedLabor',al,'allocatedPosCommission',ap,'allocatedOtherVariable',ao,'allocatedOperatingCost',allocated_cost,
      'allocatedOperatingContribution',contribution,'allocatedOperatingMarginPct',contribution/nullif(net,0)*100,'allocatedOperatingCostPerUnit',allocated_cost/nullif(q,0),
      'targetOperatingMarginPct',target_operating_margin_pct,'targetDifferencePp',contribution/nullif(net,0)*100-target_operating_margin_pct,
      'suggestedNetPriceAtTarget',(cost+allocated_cost/nullif(q,0))/(1-target_operating_margin_pct/100),
      'suggestedGrossPriceAtTarget',(cost+allocated_cost/nullif(q,0))/(1-target_operating_margin_pct/100)*(1+sales_tax_rate/100)) order by name,menu_product_id),'[]') from metrics)) into result from totals t cross join expenses e;
  return result;
end; $$;

create function public.get_operating_data(p_tenant_id uuid,p_start_date date,p_end_date date,p_currency_code text,p_location_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  perform private.require_costing_access(p_tenant_id,'food-service.costing.read',p_location_id);
  perform private.check_operating_period(p_start_date,p_end_date,p_currency_code);
  return jsonb_build_object('tenantId',p_tenant_id,'startDate',p_start_date,'endDate',p_end_date,'currencyCode',p_currency_code,'locationId',p_location_id,
    'locations',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by name,id),'[]') from public.locations where tenant_id=p_tenant_id),
    'products',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'currencyCode',currency_code) order by name,id),'[]') from public.menu_products where tenant_id=p_tenant_id and currency_code=p_currency_code),
    'sales',(select coalesce(jsonb_agg(jsonb_build_object('id',f.id,'locationId',f.location_id,'saleDate',f.sale_date,'productId',f.menu_product_id,'productName',p.name,'currencyCode',f.currency_code,'quantity',f.quantity,'grossSales',f.gross_sales,'netSales',f.net_sales,'sourceType',f.source_type) order by f.sale_date desc,f.id),'[]') from public.menu_product_sales_facts f join public.menu_products p on p.id=f.menu_product_id and p.tenant_id=f.tenant_id where f.tenant_id=p_tenant_id and f.currency_code=p_currency_code and f.sale_date between p_start_date and p_end_date and (p_location_id is null or f.location_id=p_location_id)),
    'expenses',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'locationId',location_id,'occurredOn',occurred_on,'currencyCode',currency_code,'category',category,'amount',amount,'description',description,'sourceType',source_type,'status',status) order by occurred_on desc,id),'[]') from public.operating_cost_entries where tenant_id=p_tenant_id and currency_code=p_currency_code and occurred_on between p_start_date and p_end_date and (p_location_id is null or location_id=p_location_id or location_id is null)));
end; $$;
revoke all on function private.guard_operating_cost(),private.check_operating_period(date,date,text),private.save_operating_cost(uuid,uuid,uuid,date,text,text,numeric,text) from public,anon,authenticated;
revoke all on function public.upsert_menu_product_sales_fact(uuid,uuid,date,uuid,numeric,numeric,numeric),public.create_operating_cost_entry(uuid,date,text,text,numeric,text,uuid),public.update_operating_cost_entry(uuid,uuid,date,text,text,numeric,text,uuid),public.void_operating_cost_entry(uuid,uuid),public.get_operating_profitability(uuid,date,date,text,uuid,text),public.get_operating_data(uuid,date,date,text,uuid) from public,anon;
grant execute on function public.upsert_menu_product_sales_fact(uuid,uuid,date,uuid,numeric,numeric,numeric),public.create_operating_cost_entry(uuid,date,text,text,numeric,text,uuid),public.update_operating_cost_entry(uuid,uuid,date,text,text,numeric,text,uuid),public.void_operating_cost_entry(uuid,uuid),public.get_operating_profitability(uuid,date,date,text,uuid,text),public.get_operating_data(uuid,date,date,text,uuid) to authenticated,service_role;

-- Replace public signatures with optional trailing arguments; old callers remain valid.
drop function public.create_menu_product(uuid,text,uuid,text,numeric,numeric,text,numeric,text,text);
drop function public.update_menu_product(uuid,uuid,text,uuid,text,numeric,numeric,text,text,numeric,text,text);
drop function private.save_menu_product(uuid,uuid,text,text,text,uuid,text,numeric,numeric,numeric,text,text);
create function private.save_menu_product(p_tenant_id uuid,p_id uuid,p_name text,p_code text,p_category text,p_recipe_id uuid,p_currency_code text,p_sale_price_gross numeric,p_sales_tax_rate numeric,p_target_food_cost_pct numeric,p_cost_method text,p_status text,p_target_operating_margin_pct numeric)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid := coalesce(p_id,gen_random_uuid()); old public.menu_products%rowtype; recipe_currency text;
begin
  perform private.require_costing_access(p_tenant_id,'food-service.costing.write');
  if p_target_operating_margin_pct is not null and (p_target_operating_margin_pct <= 0 or p_target_operating_margin_pct >= 100 or p_target_operating_margin_pct <> round(p_target_operating_margin_pct,3)) then raise exception 'MENU_OPERATING_TARGET_INVALID' using errcode = '22023'; end if;
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
    if (old.name,old.code,old.category,old.recipe_id,old.currency_code,old.sale_price_gross,old.sales_tax_rate,old.target_food_cost_pct,old.cost_method,old.status,old.target_operating_margin_pct)
      is not distinct from (p_name,p_code,p_category,p_recipe_id,p_currency_code,p_sale_price_gross,p_sales_tax_rate,p_target_food_cost_pct,p_cost_method,p_status,p_target_operating_margin_pct) then raise exception 'COSTING_NO_CHANGES' using errcode = '22023'; end if;
    update public.menu_products set name=p_name,code=p_code,category=p_category,recipe_id=p_recipe_id,currency_code=p_currency_code,sale_price_gross=p_sale_price_gross,
      sales_tax_rate=p_sales_tax_rate,target_food_cost_pct=p_target_food_cost_pct,cost_method=p_cost_method,status=p_status,target_operating_margin_pct=p_target_operating_margin_pct,updated_at=now() where id=v_id;
  else
    insert into public.menu_products(id,tenant_id,name,code,category,recipe_id,currency_code,sale_price_gross,sales_tax_rate,target_food_cost_pct,cost_method,status,target_operating_margin_pct)
    values(v_id,p_tenant_id,p_name,p_code,p_category,p_recipe_id,p_currency_code,p_sale_price_gross,p_sales_tax_rate,p_target_food_cost_pct,p_cost_method,p_status,p_target_operating_margin_pct);
  end if;
  insert into public.audit_logs(tenant_id,actor_user_id,action,entity_type,entity_id,metadata) values(p_tenant_id,auth.uid(),case when p_id is null then 'MENU_PRODUCT_CREATED' else 'MENU_PRODUCT_UPDATED' end,'menu_product',v_id,
    jsonb_build_object('productId',v_id,'recipeId',p_recipe_id,'name',p_name,'currencyCode',p_currency_code,'salePriceGross',p_sale_price_gross,'salesTaxRate',p_sales_tax_rate,'targetFoodCostPct',p_target_food_cost_pct,'costMethod',p_cost_method,'status',p_status,'targetOperatingMarginPct',p_target_operating_margin_pct));
  return v_id;
exception when unique_violation then raise exception 'MENU_PRODUCT_DUPLICATE' using errcode = '23505';
end; $$;
create function public.create_menu_product(p_tenant_id uuid,p_name text,p_recipe_id uuid,p_currency_code text,p_sale_price_gross numeric,p_sales_tax_rate numeric,p_cost_method text default 'WEIGHTED_PURCHASE',p_target_food_cost_pct numeric default null,p_code text default null,p_category text default null,p_target_operating_margin_pct numeric default null)
returns uuid language sql security definer set search_path = '' as $$ select private.save_menu_product(p_tenant_id,null,p_name,p_code,p_category,p_recipe_id,p_currency_code,p_sale_price_gross,p_sales_tax_rate,p_target_food_cost_pct,p_cost_method,'ACTIVE',p_target_operating_margin_pct); $$;
create function public.update_menu_product(p_tenant_id uuid,p_product_id uuid,p_name text,p_recipe_id uuid,p_currency_code text,p_sale_price_gross numeric,p_sales_tax_rate numeric,p_cost_method text,p_status text,p_target_food_cost_pct numeric default null,p_code text default null,p_category text default null,p_target_operating_margin_pct numeric default null)
returns uuid language sql security definer set search_path = '' as $$ select private.save_menu_product(p_tenant_id,p_product_id,p_name,p_code,p_category,p_recipe_id,p_currency_code,p_sale_price_gross,p_sales_tax_rate,p_target_food_cost_pct,p_cost_method,p_status,p_target_operating_margin_pct); $$;


create or replace function public.get_menu_costing_overview(p_tenant_id uuid,p_location_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare products jsonb;
begin
  perform private.require_costing_access(p_tenant_id,'food-service.costing.read',p_location_id);
  with recipes as (select value r from jsonb_array_elements(private.recipe_costs(p_tenant_id,p_location_id))),
  costs as (select p.*,r->>'name' as recipe_name,(r->>'costingComplete')::boolean as complete,(r->>'missingCostItemCount')::int as missing,
    (r->>case when p.cost_method='LAST_PURCHASE' then 'costPerPortionLast' else 'costPerPortionWeighted' end)::numeric as cost,
    p.sale_price_gross/(1+p.sales_tax_rate/100) as net from public.menu_products p join recipes on (r->>'id')::uuid=p.recipe_id where p.tenant_id=p_tenant_id)
  select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'code',code,'category',category,'recipeId',recipe_id,'recipeName',recipe_name,
    'currencyCode',currency_code,'salePriceGross',sale_price_gross,'salesTaxRate',sales_tax_rate,'targetFoodCostPct',target_food_cost_pct,'targetOperatingMarginPct',target_operating_margin_pct,'costMethod',cost_method,'status',status,
    'costingComplete',complete,'missingCostItemCount',missing,'salePriceNet',net,'recipeCostPerPortion',cost,'foodCostPct',cost/nullif(net,0)*100,
    'contributionMargin',net-cost,'suggestedNetPrice',cost/(target_food_cost_pct/100),'suggestedGrossPrice',cost/(target_food_cost_pct/100)*(1+sales_tax_rate/100),
    'targetDifferencePp',cost/nullif(net,0)*100-target_food_cost_pct) order by name,id),'[]') into products from costs;
  return jsonb_build_object('tenantId',p_tenant_id,'locationId',p_location_id,'products',products);
end; $$;

revoke all on function private.save_menu_product(uuid,uuid,text,text,text,uuid,text,numeric,numeric,numeric,text,text,numeric) from public,anon,authenticated;
revoke all on function public.create_menu_product(uuid,text,uuid,text,numeric,numeric,text,numeric,text,text,numeric),public.update_menu_product(uuid,uuid,text,uuid,text,numeric,numeric,text,text,numeric,text,text,numeric) from public,anon;
grant execute on function public.create_menu_product(uuid,text,uuid,text,numeric,numeric,text,numeric,text,text,numeric),public.update_menu_product(uuid,uuid,text,uuid,text,numeric,numeric,text,text,numeric,text,text,numeric) to authenticated,service_role;
