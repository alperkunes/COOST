-- COOST foodservice master-data reconcile v3.
--
-- V3 is intentionally idempotent for existing SKU / recipe-code identities.
-- It preserves unresolved direct recipe quantities instead of inventing unit
-- conversions, and makes those gaps visible to costing.

create table public.recipe_unresolved_lines (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  recipe_id uuid not null,
  inventory_item_id uuid not null,
  source_line_key text,
  source_quantity numeric(16,4) not null
    check (
      source_quantity > 0
      and source_quantity <> 'NaN'::numeric
    ),
  source_unit text not null
    check (
      source_unit = upper(trim(source_unit))
      and char_length(source_unit) between 1 and 40
    ),
  reason text not null
    check (reason in ('UNIT_CONVERSION_REQUIRED')),
  line_no integer not null check (line_no > 0),
  notes text check (char_length(notes) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (recipe_id, line_no),
  foreign key (recipe_id, tenant_id)
    references public.recipes(id, tenant_id)
    on delete restrict,
  foreign key (inventory_item_id, tenant_id)
    references public.inventory_items(id, tenant_id)
    on delete restrict
);

create index recipe_unresolved_lines_item
  on public.recipe_unresolved_lines(inventory_item_id, tenant_id);

create index recipe_unresolved_lines_recipe
  on public.recipe_unresolved_lines(tenant_id, recipe_id);

alter table public.recipe_unresolved_lines
  enable row level security;

revoke all
  on public.recipe_unresolved_lines
  from public, anon, authenticated;


create function private.validate_recipe_unresolved_line_dependency()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item_status text;
begin
  select i.status
  into v_item_status
  from public.inventory_items i
  where i.id = new.inventory_item_id
    and i.tenant_id = new.tenant_id
  for share;

  if not found or v_item_status <> 'ACTIVE' then
    raise exception 'COSTING_ITEM_NOT_AVAILABLE'
      using errcode = '22023';
  end if;

  return new;
end;
$$;

revoke all
  on function private.validate_recipe_unresolved_line_dependency()
  from public, anon, authenticated;

create trigger recipe_unresolved_line_dependency_validate
before insert or update on public.recipe_unresolved_lines
for each row
execute function private.validate_recipe_unresolved_line_dependency();


create or replace function private.guard_inventory_item_recipe_dependency()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.status <> new.status
     and new.status = 'PASSIVE'
     and (
       exists (
         select 1
         from public.recipe_lines rl
         join public.recipes r
           on r.id = rl.recipe_id
          and r.tenant_id = rl.tenant_id
         where rl.tenant_id = old.tenant_id
           and rl.inventory_item_id = old.id
           and r.status = 'ACTIVE'
       )
       or exists (
         select 1
         from public.recipe_unresolved_lines ul
         join public.recipes r
           on r.id = ul.recipe_id
          and r.tenant_id = ul.tenant_id
         where ul.tenant_id = old.tenant_id
           and ul.inventory_item_id = old.id
           and r.status = 'ACTIVE'
       )
     ) then
    raise exception 'INVENTORY_ITEM_IN_ACTIVE_RECIPE'
      using errcode = '22023';
  end if;

  return new;
end;
$$;


create or replace function private.guard_recipe_dependency_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.currency_code <> new.currency_code
    and exists(
      select 1
      from public.recipe_subrecipe_lines l
      where l.tenant_id=old.tenant_id
        and (
          l.recipe_id=old.id
          or l.subrecipe_id=old.id
        )
    )
  then
    raise exception 'RECIPE_CURRENCY_IN_USE'
      using errcode='22023';
  end if;

  if old.status <> new.status
    and new.status='PASSIVE'
    and exists(
      select 1
      from public.recipe_subrecipe_lines l
      where l.tenant_id=old.tenant_id
        and l.subrecipe_id=old.id
    )
  then
    raise exception 'RECIPE_SUBRECIPE_IN_USE'
      using errcode='22023';
  end if;

  if old.status <> new.status
    and new.status='PASSIVE'
    and exists(
      select 1
      from public.menu_products mp
      where mp.tenant_id=old.tenant_id
        and mp.recipe_id=old.id
        and mp.status='ACTIVE'
    )
  then
    raise exception 'RECIPE_MENU_PRODUCT_IN_USE'
      using errcode='22023';
  end if;

  if old.status <> new.status
    and new.status='ACTIVE'
  then
    perform 1
    from public.inventory_items i
    join (
      select rl.inventory_item_id
      from public.recipe_lines rl
      where rl.tenant_id=old.tenant_id
        and rl.recipe_id=old.id

      union

      select ul.inventory_item_id
      from public.recipe_unresolved_lines ul
      where ul.tenant_id=old.tenant_id
        and ul.recipe_id=old.id
    ) dependency
      on dependency.inventory_item_id=i.id
    where i.tenant_id=old.tenant_id
    order by i.id
    for share of i;

    if exists(
      select 1
      from public.inventory_items i
      join (
        select rl.inventory_item_id
        from public.recipe_lines rl
        where rl.tenant_id=old.tenant_id
          and rl.recipe_id=old.id

        union

        select ul.inventory_item_id
        from public.recipe_unresolved_lines ul
        where ul.tenant_id=old.tenant_id
          and ul.recipe_id=old.id
      ) dependency
        on dependency.inventory_item_id=i.id
      where i.tenant_id=old.tenant_id
        and i.status <> 'ACTIVE'
    )
    then
      raise exception 'COSTING_ITEM_NOT_AVAILABLE'
        using errcode='22023';
    end if;
  end if;

  if old.yield_unit is distinct from new.yield_unit
    and new.yield_unit is not null
    and exists(
      select 1
      from public.recipe_subrecipe_lines l
      where l.tenant_id=old.tenant_id
        and l.subrecipe_id=old.id
        and l.unit is not null
        and l.unit <> new.yield_unit
    )
  then
    raise exception 'RECIPE_YIELD_UNIT_IN_USE'
      using errcode='22023';
  end if;

  return new;
end;
$$;


create trigger recipe_unresolved_lines_no_truncate
before truncate on public.recipe_unresolved_lines
for each statement
execute function private.reject_costing_master_truncate();


create or replace function private.recipe_cost_node(
  p_tenant_id uuid,
  p_recipe_id uuid,
  p_location_id uuid,
  p_path uuid[] default '{}'::uuid[]
)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  r public.recipes%rowtype;

  l record;
  u record;
  s record;

  v_last_unit numeric;
  v_weighted_unit numeric;

  v_last_line numeric;
  v_weighted_line numeric;

  v_child jsonb;
  v_child_last numeric;
  v_child_weighted numeric;
  v_child_complete boolean;

  v_direct_lines jsonb := '[]'::jsonb;
  v_unresolved_lines jsonb := '[]'::jsonb;
  v_subrecipe_lines jsonb := '[]'::jsonb;

  v_total_last numeric := 0;
  v_total_weighted numeric := 0;

  v_missing_direct integer := 0;
  v_missing_conversion integer := 0;
  v_missing_subrecipe integer := 0;

  v_direct_count integer := 0;
  v_unresolved_count integer := 0;
  v_subrecipe_count integer := 0;

  v_sub_status text;
  v_complete boolean;
begin
  select *
  into r
  from public.recipes
  where id=p_recipe_id
    and tenant_id=p_tenant_id;

  if not found then
    return null;
  end if;

  if p_recipe_id=any(p_path)
    or cardinality(p_path) >= 64
  then
    return jsonb_build_object(
      'id',r.id,
      'name',r.name,
      'code',r.code,
      'category',r.category,
      'currencyCode',r.currency_code,
      'portions',r.portions,
      'status',r.status,
      'yieldQuantity',r.yield_quantity,
      'yieldUnit',r.yield_unit,
      'lines','[]'::jsonb,
      'unresolvedLines','[]'::jsonb,
      'subrecipeLines','[]'::jsonb,
      'totalLastCost',null,
      'totalWeightedCost',null,
      'costPerPortionLast',null,
      'costPerPortionWeighted',null,
      'missingCostItemCount',1,
      'missingDirectCostItemCount',0,
      'missingPurchaseCostItemCount',0,
      'missingConversionItemCount',0,
      'missingSubrecipeCostCount',1,
      'directLineCount',0,
      'unresolvedLineCount',0,
      'subrecipeLineCount',0,
      'costStatus','DEPENDENCY_CYCLE',
      'costingComplete',false
    );
  end if;

  for l in
    select
      rl.inventory_item_id,
      rl.quantity_base,
      rl.line_no,
      rl.notes,
      i.name as item_name,
      i.base_unit,
      i.status as item_status
    from public.recipe_lines rl
    join public.inventory_items i
      on i.id=rl.inventory_item_id
     and i.tenant_id=rl.tenant_id
    where rl.tenant_id=p_tenant_id
      and rl.recipe_id=p_recipe_id
    order by rl.line_no
  loop
    v_direct_count := v_direct_count + 1;

    v_last_unit := null;
    v_weighted_unit := null;

    select
      pc.last_unit_cost,
      pc.weighted_unit_cost
    into
      v_last_unit,
      v_weighted_unit
    from private.purchase_costs(
      p_tenant_id,
      r.currency_code,
      p_location_id
    ) pc
    where pc.item_id=l.inventory_item_id;

    if v_last_unit is null
      or v_weighted_unit is null
    then
      v_missing_direct := v_missing_direct + 1;
      v_last_line := null;
      v_weighted_line := null;
    else
      v_last_line := l.quantity_base * v_last_unit;
      v_weighted_line := l.quantity_base * v_weighted_unit;
      v_total_last := v_total_last + v_last_line;
      v_total_weighted := v_total_weighted + v_weighted_line;
    end if;

    v_direct_lines :=
      v_direct_lines ||
      jsonb_build_array(
        jsonb_build_object(
          'inventoryItemId',l.inventory_item_id,
          'itemName',l.item_name,
          'baseUnit',l.base_unit,
          'itemStatus',l.item_status,
          'quantityBase',l.quantity_base,
          'notes',l.notes,
          'lastUnitCost',v_last_unit,
          'weightedUnitCost',v_weighted_unit,
          'lastLineCost',v_last_line,
          'weightedLineCost',v_weighted_line,
          'costStatus',
            case
              when v_last_unit is null
                or v_weighted_unit is null
                then 'NO_PURCHASE_COST'
              else 'READY'
            end
        )
      );
  end loop;

  for u in
    select
      ul.id,
      ul.inventory_item_id,
      ul.source_line_key,
      ul.source_quantity,
      ul.source_unit,
      ul.reason,
      ul.line_no,
      ul.notes,
      i.name as item_name,
      i.base_unit,
      i.status as item_status
    from public.recipe_unresolved_lines ul
    join public.inventory_items i
      on i.id=ul.inventory_item_id
     and i.tenant_id=ul.tenant_id
    where ul.tenant_id=p_tenant_id
      and ul.recipe_id=p_recipe_id
    order by ul.line_no
  loop
    v_unresolved_count := v_unresolved_count + 1;
    v_missing_conversion := v_missing_conversion + 1;

    v_unresolved_lines :=
      v_unresolved_lines ||
      jsonb_build_array(
        jsonb_build_object(
          'unresolvedLineId',u.id,
          'inventoryItemId',u.inventory_item_id,
          'itemName',u.item_name,
          'baseUnit',u.base_unit,
          'itemStatus',u.item_status,
          'sourceLineKey',u.source_line_key,
          'sourceQuantity',u.source_quantity,
          'sourceUnit',u.source_unit,
          'notes',u.notes,
          'reason',u.reason,
          'costStatus','UNIT_CONVERSION_REQUIRED'
        )
      );
  end loop;

  for s in
    select
      sl.subrecipe_id,
      sl.quantity,
      sl.unit,
      sl.line_no,
      sl.notes,
      cr.name as child_name,
      cr.code as child_code,
      cr.status as child_status,
      cr.yield_quantity as child_yield_quantity,
      cr.yield_unit as child_yield_unit
    from public.recipe_subrecipe_lines sl
    join public.recipes cr
      on cr.id=sl.subrecipe_id
     and cr.tenant_id=sl.tenant_id
    where sl.tenant_id=p_tenant_id
      and sl.recipe_id=p_recipe_id
    order by sl.line_no
  loop
    v_subrecipe_count := v_subrecipe_count + 1;

    v_child :=
      private.recipe_cost_node(
        p_tenant_id,
        s.subrecipe_id,
        p_location_id,
        p_path || array[p_recipe_id]
      );

    v_child_complete :=
      coalesce(
        (v_child->>'costingComplete')::boolean,
        false
      );

    v_child_last :=
      case
        when v_child->>'totalLastCost' is null then null
        else (v_child->>'totalLastCost')::numeric
      end;

    v_child_weighted :=
      case
        when v_child->>'totalWeightedCost' is null then null
        else (v_child->>'totalWeightedCost')::numeric
      end;

    v_last_line := null;
    v_weighted_line := null;

    if s.quantity is null
      or s.unit is null
    then
      v_sub_status := 'MISSING_USAGE_QUANTITY';
    elsif s.child_yield_quantity is null
      or s.child_yield_unit is null
    then
      v_sub_status := 'MISSING_CHILD_YIELD';
    elsif s.unit <> s.child_yield_unit
    then
      v_sub_status := 'UNIT_MISMATCH';
    elsif s.child_status <> 'ACTIVE'
    then
      v_sub_status := 'CHILD_RECIPE_INACTIVE';
    elsif not v_child_complete
    then
      v_sub_status := 'CHILD_COST_INCOMPLETE';
    elsif v_child_last is null
      or v_child_weighted is null
    then
      v_sub_status := 'CHILD_COST_INCOMPLETE';
    else
      v_sub_status := 'READY';
      v_last_line :=
        s.quantity * v_child_last / s.child_yield_quantity;
      v_weighted_line :=
        s.quantity * v_child_weighted / s.child_yield_quantity;
      v_total_last := v_total_last + v_last_line;
      v_total_weighted := v_total_weighted + v_weighted_line;
    end if;

    if v_sub_status <> 'READY' then
      v_missing_subrecipe := v_missing_subrecipe + 1;
    end if;

    v_subrecipe_lines :=
      v_subrecipe_lines ||
      jsonb_build_array(
        jsonb_build_object(
          'subrecipeId',s.subrecipe_id,
          'subrecipeName',s.child_name,
          'subrecipeCode',s.child_code,
          'quantity',s.quantity,
          'unit',s.unit,
          'yieldQuantity',s.child_yield_quantity,
          'yieldUnit',s.child_yield_unit,
          'notes',s.notes,
          'childCostingComplete',v_child_complete,
          'childTotalLastCost',v_child_last,
          'childTotalWeightedCost',v_child_weighted,
          'lastLineCost',v_last_line,
          'weightedLineCost',v_weighted_line,
          'costStatus',v_sub_status
        )
      );
  end loop;

  v_complete :=
    (
      v_missing_direct +
      v_missing_conversion +
      v_missing_subrecipe
    )=0
    and (
      v_direct_count +
      v_unresolved_count +
      v_subrecipe_count
    ) > 0;

  return jsonb_build_object(
    'id',r.id,
    'name',r.name,
    'code',r.code,
    'category',r.category,
    'currencyCode',r.currency_code,
    'portions',r.portions,
    'status',r.status,
    'yieldQuantity',r.yield_quantity,
    'yieldUnit',r.yield_unit,
    'lines',v_direct_lines,
    'unresolvedLines',v_unresolved_lines,
    'subrecipeLines',v_subrecipe_lines,
    'totalLastCost',
      case when v_complete then v_total_last else null end,
    'totalWeightedCost',
      case when v_complete then v_total_weighted else null end,
    'costPerPortionLast',
      case when v_complete then v_total_last / r.portions else null end,
    'costPerPortionWeighted',
      case when v_complete then v_total_weighted / r.portions else null end,
    'missingCostItemCount',
      v_missing_direct +
      v_missing_conversion +
      v_missing_subrecipe,
    'missingDirectCostItemCount',
      v_missing_direct + v_missing_conversion,
    'missingPurchaseCostItemCount',
      v_missing_direct,
    'missingConversionItemCount',
      v_missing_conversion,
    'missingSubrecipeCostCount',
      v_missing_subrecipe,
    'directLineCount',v_direct_count,
    'unresolvedLineCount',v_unresolved_count,
    'subrecipeLineCount',v_subrecipe_count,
    'costStatus',
      case when v_complete then 'READY' else 'INCOMPLETE' end,
    'costingComplete',v_complete
  );
end;
$$;


create function public.import_foodservice_master_data_v3(
  p_tenant_id uuid,
  p_payload jsonb,
  p_mode text default 'DRY_RUN'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_mode text := upper(trim(coalesce(p_mode,'')));

  v_inventory_count integer;
  v_recipe_count integer;
  v_resolved_count integer := 0;
  v_unresolved_count integer := 0;
  v_subrecipe_count integer := 0;

  v_inventory_create_count integer := 0;
  v_inventory_reconcile_count integer := 0;
  v_recipe_create_count integer := 0;
  v_recipe_reconcile_count integer := 0;

  v_inventory_conflicts jsonb := '[]'::jsonb;
  v_recipe_conflicts jsonb := '[]'::jsonb;

  v_item jsonb;
  v_recipe jsonb;
  v_line jsonb;
  v_subline jsonb;

  v_current_item public.inventory_items%rowtype;
  v_current_recipe public.recipes%rowtype;

  v_item_id uuid;
  v_recipe_id uuid;
  v_child_id uuid;

  v_line_no integer;
  v_quantity numeric;
  v_source_quantity numeric;
  v_unit text;
  v_notes text;

  v_can_apply boolean;
begin
  perform private.require_inventory_access(
    p_tenant_id,
    'inventory.write'
  );

  perform private.require_costing_access(
    p_tenant_id,
    'food-service.costing.write'
  );

  if v_mode not in ('DRY_RUN','APPLY') then
    raise exception 'MASTER_DATA_V3_MODE_INVALID'
      using errcode='22023';
  end if;

  if jsonb_typeof(p_payload) is distinct from 'object'
    or jsonb_typeof(p_payload->'schemaVersion') is distinct from 'number'
    or (p_payload->>'schemaVersion')::integer <> 3
    or jsonb_typeof(p_payload->'inventoryItems') is distinct from 'array'
    or jsonb_typeof(p_payload->'recipes') is distinct from 'array'
    or jsonb_typeof(coalesce(p_payload->'menuProducts','[]'::jsonb))
      is distinct from 'array'
    or jsonb_array_length(
      coalesce(p_payload->'menuProducts','[]'::jsonb)
    ) <> 0
  then
    raise exception 'MASTER_DATA_V3_PAYLOAD_INVALID'
      using errcode='22023';
  end if;

  v_inventory_count := jsonb_array_length(p_payload->'inventoryItems');
  v_recipe_count := jsonb_array_length(p_payload->'recipes');

  if v_inventory_count not between 1 and 500
    or v_recipe_count not between 1 and 200
  then
    raise exception 'MASTER_DATA_V3_PAYLOAD_INVALID'
      using errcode='22023';
  end if;

  ------------------------------------------------------------------
  -- INVENTORY PAYLOAD VALIDATION
  ------------------------------------------------------------------

  for v_item in
    select value
    from jsonb_array_elements(p_payload->'inventoryItems')
  loop
    if jsonb_typeof(v_item) is distinct from 'object'
      or jsonb_typeof(v_item->'sku') is distinct from 'string'
      or jsonb_typeof(v_item->'name') is distinct from 'string'
      or jsonb_typeof(v_item->'baseUnit') is distinct from 'string'
      or jsonb_typeof(v_item->'status') is distinct from 'string'
      or (
        v_item ? 'category'
        and jsonb_typeof(v_item->'category') not in ('string','null')
      )
    then
      raise exception 'MASTER_DATA_V3_INVENTORY_INVALID'
        using errcode='22023';
    end if;

    if char_length(trim(v_item->>'sku')) not between 1 and 100
      or char_length(trim(v_item->>'name')) not between 2 and 160
      or char_length(v_item->>'category') > 120
      or upper(trim(v_item->>'baseUnit'))
        not in ('GRAM','MILLILITER','EACH')
      or upper(trim(v_item->>'status')) <> 'ACTIVE'
    then
      raise exception 'MASTER_DATA_V3_INVENTORY_INVALID'
        using errcode='22023';
    end if;
  end loop;

  if exists(
    select 1
    from (
      select lower(trim(value->>'sku')) as key
      from jsonb_array_elements(p_payload->'inventoryItems')
      group by 1
      having count(*) > 1
    ) duplicate
  )
  or exists(
    select 1
    from (
      select lower(
        regexp_replace(
          trim(value->>'name'),
          '[[:space:]]+',
          ' ',
          'g'
        )
      ) as key
      from jsonb_array_elements(p_payload->'inventoryItems')
      group by 1
      having count(*) > 1
    ) duplicate
  )
  then
    raise exception 'MASTER_DATA_V3_INVENTORY_DUPLICATE'
      using errcode='22023';
  end if;

  ------------------------------------------------------------------
  -- RECIPE PAYLOAD VALIDATION
  ------------------------------------------------------------------

  for v_recipe in
    select value
    from jsonb_array_elements(p_payload->'recipes')
  loop
    if jsonb_typeof(v_recipe) is distinct from 'object'
      or jsonb_typeof(v_recipe->'code') is distinct from 'string'
      or jsonb_typeof(v_recipe->'name') is distinct from 'string'
      or jsonb_typeof(v_recipe->'currencyCode') is distinct from 'string'
      or jsonb_typeof(v_recipe->'portions') is distinct from 'number'
      or jsonb_typeof(v_recipe->'status') is distinct from 'string'
      or jsonb_typeof(v_recipe->'lines') is distinct from 'array'
      or jsonb_typeof(
        coalesce(v_recipe->'unresolvedLines','[]'::jsonb)
      ) is distinct from 'array'
      or jsonb_typeof(
        coalesce(v_recipe->'subrecipeLines','[]'::jsonb)
      ) is distinct from 'array'
      or (
        v_recipe ? 'category'
        and jsonb_typeof(v_recipe->'category') not in ('string','null')
      )
    then
      raise exception 'MASTER_DATA_V3_RECIPE_INVALID'
        using errcode='22023';
    end if;

    v_quantity := (v_recipe->>'portions')::numeric;

    if char_length(trim(v_recipe->>'code')) not between 1 and 100
      or char_length(trim(v_recipe->>'name')) not between 2 and 160
      or char_length(v_recipe->>'category') > 120
      or upper(trim(v_recipe->>'currencyCode')) !~ '^[A-Z]{3}$'
      or v_quantity <= 0
      or v_quantity='NaN'::numeric
      or v_quantity > 99999999.9999
      or v_quantity <> round(v_quantity,4)
      or upper(trim(v_recipe->>'status')) <> 'ACTIVE'
      or (
        jsonb_array_length(v_recipe->'lines') +
        jsonb_array_length(
          coalesce(v_recipe->'unresolvedLines','[]'::jsonb)
        ) +
        jsonb_array_length(
          coalesce(v_recipe->'subrecipeLines','[]'::jsonb)
        )
      ) not between 1 and 300
    then
      raise exception 'MASTER_DATA_V3_RECIPE_INVALID'
        using errcode='22023';
    end if;

    for v_line in
      select value
      from jsonb_array_elements(v_recipe->'lines')
    loop
      if jsonb_typeof(v_line) is distinct from 'object'
        or jsonb_typeof(v_line->'lineNo') is distinct from 'number'
        or jsonb_typeof(v_line->'inventorySku') is distinct from 'string'
        or jsonb_typeof(v_line->'quantityBase') is distinct from 'number'
        or (
          v_line ? 'sourceLineKey'
          and jsonb_typeof(v_line->'sourceLineKey') not in ('string','null')
        )
        or (
          v_line ? 'notes'
          and jsonb_typeof(v_line->'notes') not in ('string','null')
        )
      then
        raise exception 'MASTER_DATA_V3_RECIPE_LINE_INVALID'
          using errcode='22023';
      end if;

      v_line_no := (v_line->>'lineNo')::integer;
      v_quantity := (v_line->>'quantityBase')::numeric;

      if v_line_no <= 0
        or (v_line->>'lineNo')::numeric <> v_line_no
        or char_length(trim(v_line->>'inventorySku')) not between 1 and 100
        or v_quantity <= 0
        or v_quantity='NaN'::numeric
        or v_quantity > 999999999999.9999
        or v_quantity <> round(v_quantity,4)
        or char_length(v_line->>'sourceLineKey') > 120
        or char_length(v_line->>'notes') > 500
      then
        raise exception 'MASTER_DATA_V3_RECIPE_LINE_INVALID'
          using errcode='22023';
      end if;

      if not exists(
        select 1
        from jsonb_array_elements(p_payload->'inventoryItems') source_item
        where lower(trim(source_item->>'sku'))
          = lower(trim(v_line->>'inventorySku'))
      )
      then
        raise exception 'MASTER_DATA_V3_RECIPE_ITEM_NOT_IN_PAYLOAD'
          using errcode='22023';
      end if;

      v_resolved_count := v_resolved_count + 1;
    end loop;

    for v_line in
      select value
      from jsonb_array_elements(
        coalesce(v_recipe->'unresolvedLines','[]'::jsonb)
      )
    loop
      if jsonb_typeof(v_line) is distinct from 'object'
        or jsonb_typeof(v_line->'lineNo') is distinct from 'number'
        or jsonb_typeof(v_line->'inventorySku') is distinct from 'string'
        or jsonb_typeof(v_line->'sourceQuantity') is distinct from 'number'
        or jsonb_typeof(v_line->'sourceUnit') is distinct from 'string'
        or jsonb_typeof(v_line->'reason') is distinct from 'string'
        or (
          v_line ? 'sourceLineKey'
          and jsonb_typeof(v_line->'sourceLineKey') not in ('string','null')
        )
        or (
          v_line ? 'notes'
          and jsonb_typeof(v_line->'notes') not in ('string','null')
        )
      then
        raise exception 'MASTER_DATA_V3_UNRESOLVED_LINE_INVALID'
          using errcode='22023';
      end if;

      v_line_no := (v_line->>'lineNo')::integer;
      v_source_quantity := (v_line->>'sourceQuantity')::numeric;
      v_unit := upper(trim(v_line->>'sourceUnit'));

      if v_line_no <= 0
        or (v_line->>'lineNo')::numeric <> v_line_no
        or char_length(trim(v_line->>'inventorySku')) not between 1 and 100
        or v_source_quantity <= 0
        or v_source_quantity='NaN'::numeric
        or v_source_quantity > 999999999999.9999
        or v_source_quantity <> round(v_source_quantity,4)
        or char_length(v_unit) not between 1 and 40
        or upper(trim(v_line->>'reason')) <> 'UNIT_CONVERSION_REQUIRED'
        or char_length(v_line->>'sourceLineKey') > 120
        or char_length(v_line->>'notes') > 500
      then
        raise exception 'MASTER_DATA_V3_UNRESOLVED_LINE_INVALID'
          using errcode='22023';
      end if;

      if not exists(
        select 1
        from jsonb_array_elements(p_payload->'inventoryItems') source_item
        where lower(trim(source_item->>'sku'))
          = lower(trim(v_line->>'inventorySku'))
      )
      then
        raise exception 'MASTER_DATA_V3_RECIPE_ITEM_NOT_IN_PAYLOAD'
          using errcode='22023';
      end if;

      v_unresolved_count := v_unresolved_count + 1;
    end loop;

    for v_subline in
      select value
      from jsonb_array_elements(
        coalesce(v_recipe->'subrecipeLines','[]'::jsonb)
      )
    loop
      if jsonb_typeof(v_subline) is distinct from 'object'
        or jsonb_typeof(v_subline->'lineNo') is distinct from 'number'
        or jsonb_typeof(v_subline->'subrecipeCode') is distinct from 'string'
        or (
          v_subline ? 'sourceLineKey'
          and jsonb_typeof(v_subline->'sourceLineKey') not in ('string','null')
        )
        or (
          v_subline ? 'quantity'
          and jsonb_typeof(v_subline->'quantity') not in ('number','null')
        )
        or (
          v_subline ? 'unit'
          and jsonb_typeof(v_subline->'unit') not in ('string','null')
        )
        or (
          v_subline ? 'notes'
          and jsonb_typeof(v_subline->'notes') not in ('string','null')
        )
      then
        raise exception 'MASTER_DATA_V3_SUBRECIPE_LINE_INVALID'
          using errcode='22023';
      end if;

      v_line_no := (v_subline->>'lineNo')::integer;

      if v_line_no <= 0
        or (v_subline->>'lineNo')::numeric <> v_line_no
        or char_length(trim(v_subline->>'subrecipeCode')) not between 1 and 100
        or char_length(v_subline->>'sourceLineKey') > 120
        or char_length(v_subline->>'notes') > 500
      then
        raise exception 'MASTER_DATA_V3_SUBRECIPE_LINE_INVALID'
          using errcode='22023';
      end if;

      if not (v_subline ? 'quantity')
        or jsonb_typeof(v_subline->'quantity')='null'
      then
        v_quantity := null;
      else
        v_quantity := (v_subline->>'quantity')::numeric;
      end if;

      v_unit := nullif(upper(trim(v_subline->>'unit')),'');

      if (v_quantity is null) <> (v_unit is null)
        or (
          v_quantity is not null
          and (
            v_quantity <= 0
            or v_quantity='NaN'::numeric
            or v_quantity > 999999999999.9999
            or v_quantity <> round(v_quantity,4)
            or v_unit not in ('GRAM','MILLILITER','EACH')
          )
        )
      then
        raise exception 'MASTER_DATA_V3_SUBRECIPE_LINE_INVALID'
          using errcode='22023';
      end if;

      if not exists(
        select 1
        from jsonb_array_elements(p_payload->'recipes') child
        where lower(trim(child->>'code'))
          = lower(trim(v_subline->>'subrecipeCode'))
      )
      then
        raise exception 'MASTER_DATA_V3_SUBRECIPE_NOT_IN_PAYLOAD'
          using errcode='22023';
      end if;

      v_subrecipe_count := v_subrecipe_count + 1;
    end loop;

    if exists(
      select 1
      from (
        select (x->>'lineNo')::integer as line_no
        from jsonb_array_elements(v_recipe->'lines') x

        union all

        select (x->>'lineNo')::integer
        from jsonb_array_elements(
          coalesce(v_recipe->'unresolvedLines','[]'::jsonb)
        ) x

        union all

        select (x->>'lineNo')::integer
        from jsonb_array_elements(
          coalesce(v_recipe->'subrecipeLines','[]'::jsonb)
        ) x
      ) numbered
      group by line_no
      having count(*) > 1
    )
    then
      raise exception 'MASTER_DATA_V3_LINE_NUMBER_DUPLICATE'
        using errcode='22023';
    end if;
  end loop;

  if exists(
    select 1
    from (
      select lower(trim(value->>'code')) as key
      from jsonb_array_elements(p_payload->'recipes')
      group by 1
      having count(*) > 1
    ) duplicate
  )
  or exists(
    select 1
    from (
      select lower(
        regexp_replace(
          trim(value->>'name'),
          '[[:space:]]+',
          ' ',
          'g'
        )
      ) as key
      from jsonb_array_elements(p_payload->'recipes')
      group by 1
      having count(*) > 1
    ) duplicate
  )
  then
    raise exception 'MASTER_DATA_V3_RECIPE_DUPLICATE'
      using errcode='22023';
  end if;

  if exists(
    select 1
    from jsonb_array_elements(p_payload->'recipes') parent
    cross join lateral jsonb_array_elements(
      coalesce(parent->'subrecipeLines','[]'::jsonb)
    ) edge
    join lateral (
      select child.value
      from jsonb_array_elements(p_payload->'recipes') child(value)
      where lower(trim(child.value->>'code'))
        = lower(trim(edge->>'subrecipeCode'))
      limit 1
    ) child on true
    where upper(trim(parent->>'currencyCode'))
      <> upper(trim(child.value->>'currencyCode'))
  )
  then
    raise exception 'MASTER_DATA_V3_SUBRECIPE_CURRENCY_MISMATCH'
      using errcode='22023';
  end if;

  if exists(
    with recursive edges as (
      select
        lower(trim(parent->>'code')) as parent_code,
        lower(trim(edge->>'subrecipeCode')) as child_code
      from jsonb_array_elements(p_payload->'recipes') parent
      cross join lateral jsonb_array_elements(
        coalesce(parent->'subrecipeLines','[]'::jsonb)
      ) edge
    ),
    walk(root_code,node_code,path,cycle_found) as (
      select
        parent_code,
        child_code,
        array[parent_code,child_code]::text[],
        parent_code=child_code
      from edges

      union all

      select
        walk.root_code,
        edges.child_code,
        walk.path || edges.child_code,
        edges.child_code=any(walk.path)
      from walk
      join edges
        on edges.parent_code=walk.node_code
      where not walk.cycle_found
    )
    select 1
    from walk
    where cycle_found
  )
  then
    raise exception 'RECIPE_DEPENDENCY_CYCLE'
      using errcode='22023';
  end if;

  ------------------------------------------------------------------
  -- CURRENT DATA CONFLICT PREVIEW
  ------------------------------------------------------------------

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'sku',source_item->>'sku',
        'name',source_item->>'name',
        'reason',conflict_reason
      )
      order by source_item->>'sku'
    ),
    '[]'::jsonb
  )
  into v_inventory_conflicts
  from jsonb_array_elements(p_payload->'inventoryItems') source_item
  cross join lateral (
    select case
      when exists(
        select 1
        from public.inventory_items current_item
        where current_item.tenant_id=p_tenant_id
          and lower(current_item.sku)=lower(trim(source_item->>'sku'))
          and current_item.base_unit
            <> upper(trim(source_item->>'baseUnit'))
      )
      then 'BASE_UNIT_MISMATCH'
      when exists(
        select 1
        from public.inventory_items current_item
        where current_item.tenant_id=p_tenant_id
          and lower(
            regexp_replace(
              trim(current_item.name),
              '[[:space:]]+',
              ' ',
              'g'
            )
          )=
          lower(
            regexp_replace(
              trim(source_item->>'name'),
              '[[:space:]]+',
              ' ',
              'g'
            )
          )
          and lower(coalesce(current_item.sku,''))
            <> lower(trim(source_item->>'sku'))
      )
      then 'NAME_BELONGS_TO_OTHER_SKU'
      else null
    end as conflict_reason
  ) conflict
  where conflict_reason is not null;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'code',source_recipe->>'code',
        'name',source_recipe->>'name',
        'reason',conflict_reason
      )
      order by source_recipe->>'code'
    ),
    '[]'::jsonb
  )
  into v_recipe_conflicts
  from jsonb_array_elements(p_payload->'recipes') source_recipe
  cross join lateral (
    select case
      when exists(
        select 1
        from public.recipes current_recipe
        where current_recipe.tenant_id=p_tenant_id
          and lower(current_recipe.code)
            = lower(trim(source_recipe->>'code'))
          and current_recipe.currency_code
            <> upper(trim(source_recipe->>'currencyCode'))
      )
      then 'CURRENCY_MISMATCH'
      when exists(
        select 1
        from public.recipes current_recipe
        where current_recipe.tenant_id=p_tenant_id
          and lower(
            regexp_replace(
              trim(current_recipe.name),
              '[[:space:]]+',
              ' ',
              'g'
            )
          )=
          lower(
            regexp_replace(
              trim(source_recipe->>'name'),
              '[[:space:]]+',
              ' ',
              'g'
            )
          )
          and lower(coalesce(current_recipe.code,''))
            <> lower(trim(source_recipe->>'code'))
      )
      then 'NAME_BELONGS_TO_OTHER_CODE'
      else null
    end as conflict_reason
  ) conflict
  where conflict_reason is not null;

  select count(*)
  into v_inventory_reconcile_count
  from jsonb_array_elements(p_payload->'inventoryItems') source_item
  where exists(
    select 1
    from public.inventory_items current_item
    where current_item.tenant_id=p_tenant_id
      and lower(current_item.sku)=lower(trim(source_item->>'sku'))
  );

  v_inventory_create_count :=
    v_inventory_count - v_inventory_reconcile_count;

  select count(*)
  into v_recipe_reconcile_count
  from jsonb_array_elements(p_payload->'recipes') source_recipe
  where exists(
    select 1
    from public.recipes current_recipe
    where current_recipe.tenant_id=p_tenant_id
      and lower(current_recipe.code)=lower(trim(source_recipe->>'code'))
  );

  v_recipe_create_count :=
    v_recipe_count - v_recipe_reconcile_count;

  v_can_apply :=
    jsonb_array_length(v_inventory_conflicts)=0
    and jsonb_array_length(v_recipe_conflicts)=0;

  if v_mode='DRY_RUN' then
    return jsonb_build_object(
      'schemaVersion',3,
      'mode','DRY_RUN',
      'canApply',v_can_apply,
      'inventoryItemCount',v_inventory_count,
      'inventoryCreateCount',v_inventory_create_count,
      'inventoryReconcileCount',v_inventory_reconcile_count,
      'recipeCount',v_recipe_count,
      'recipeCreateCount',v_recipe_create_count,
      'recipeReconcileCount',v_recipe_reconcile_count,
      'resolvedDirectLineCount',v_resolved_count,
      'unresolvedDirectLineCount',v_unresolved_count,
      'subrecipeLineCount',v_subrecipe_count,
      'inventoryConflicts',v_inventory_conflicts,
      'recipeConflicts',v_recipe_conflicts,
      'sourceSummary',coalesce(p_payload->'summary','{}'::jsonb)
    );
  end if;

  if not v_can_apply then
    raise exception 'MASTER_DATA_V3_CONFLICT'
      using errcode='23505';
  end if;

  perform 1
  from public.tenants
  where id=p_tenant_id
  for update;

  if not found then
    raise exception 'MASTER_DATA_V3_TENANT_NOT_AVAILABLE'
      using errcode='22023';
  end if;

  ------------------------------------------------------------------
  -- 1. INVENTORY RECONCILE
  ------------------------------------------------------------------

  for v_item in
    select value
    from jsonb_array_elements(p_payload->'inventoryItems')
  loop
    select *
    into v_current_item
    from public.inventory_items
    where tenant_id=p_tenant_id
      and lower(sku)=lower(trim(v_item->>'sku'))
    for update;

    if not found then
      perform public.create_inventory_item(
        p_tenant_id,
        trim(v_item->>'name'),
        upper(trim(v_item->>'baseUnit')),
        trim(v_item->>'sku'),
        nullif(trim(v_item->>'category'),''),
        null
      );
    else
      if v_current_item.base_unit
        <> upper(trim(v_item->>'baseUnit'))
      then
        raise exception 'MASTER_DATA_V3_CONFLICT'
          using errcode='23505';
      end if;

      if (
        v_current_item.name,
        v_current_item.category,
        v_current_item.status
      ) is distinct from (
        trim(v_item->>'name'),
        nullif(trim(v_item->>'category'),''),
        'ACTIVE'
      )
      then
        update public.inventory_items
        set
          name=trim(v_item->>'name'),
          category=nullif(trim(v_item->>'category'),''),
          status='ACTIVE',
          updated_at=now()
        where id=v_current_item.id;
      end if;
    end if;
  end loop;

  ------------------------------------------------------------------
  -- 2. RECIPE ROWS + DIRECT / UNRESOLVED LINES
  ------------------------------------------------------------------

  for v_recipe in
    select value
    from jsonb_array_elements(p_payload->'recipes')
    order by value->>'code'
  loop
    select *
    into v_current_recipe
    from public.recipes
    where tenant_id=p_tenant_id
      and lower(code)=lower(trim(v_recipe->>'code'))
    for update;

    if found then
      v_recipe_id := v_current_recipe.id;

      delete from public.recipe_subrecipe_lines
      where tenant_id=p_tenant_id
        and recipe_id=v_recipe_id;

      delete from public.recipe_unresolved_lines
      where tenant_id=p_tenant_id
        and recipe_id=v_recipe_id;

      delete from public.recipe_lines
      where tenant_id=p_tenant_id
        and recipe_id=v_recipe_id;

      update public.recipes
      set
        name=trim(v_recipe->>'name'),
        category=nullif(trim(v_recipe->>'category'),''),
        portions=(v_recipe->>'portions')::numeric,
        status='ACTIVE',
        updated_at=now()
      where id=v_recipe_id;
    else
      insert into public.recipes(
        tenant_id,
        name,
        code,
        category,
        currency_code,
        portions,
        status
      )
      values(
        p_tenant_id,
        trim(v_recipe->>'name'),
        trim(v_recipe->>'code'),
        nullif(trim(v_recipe->>'category'),''),
        upper(trim(v_recipe->>'currencyCode')),
        (v_recipe->>'portions')::numeric,
        'ACTIVE'
      )
      returning id into v_recipe_id;
    end if;

    for v_line in
      select value
      from jsonb_array_elements(v_recipe->'lines')
      order by (value->>'lineNo')::integer
    loop
      select id
      into v_item_id
      from public.inventory_items
      where tenant_id=p_tenant_id
        and status='ACTIVE'
        and lower(sku)=lower(trim(v_line->>'inventorySku'));

      if not found then
        raise exception 'MASTER_DATA_V3_ITEM_NOT_AVAILABLE'
          using errcode='22023';
      end if;

      insert into public.recipe_lines(
        tenant_id,
        recipe_id,
        inventory_item_id,
        quantity_base,
        line_no,
        notes
      )
      values(
        p_tenant_id,
        v_recipe_id,
        v_item_id,
        (v_line->>'quantityBase')::numeric,
        (v_line->>'lineNo')::integer,
        nullif(trim(v_line->>'notes'),'')
      );
    end loop;

    for v_line in
      select value
      from jsonb_array_elements(
        coalesce(v_recipe->'unresolvedLines','[]'::jsonb)
      )
      order by (value->>'lineNo')::integer
    loop
      select id
      into v_item_id
      from public.inventory_items
      where tenant_id=p_tenant_id
        and status='ACTIVE'
        and lower(sku)=lower(trim(v_line->>'inventorySku'));

      if not found then
        raise exception 'MASTER_DATA_V3_ITEM_NOT_AVAILABLE'
          using errcode='22023';
      end if;

      insert into public.recipe_unresolved_lines(
        tenant_id,
        recipe_id,
        inventory_item_id,
        source_line_key,
        source_quantity,
        source_unit,
        reason,
        line_no,
        notes
      )
      values(
        p_tenant_id,
        v_recipe_id,
        v_item_id,
        nullif(trim(v_line->>'sourceLineKey'),''),
        (v_line->>'sourceQuantity')::numeric,
        upper(trim(v_line->>'sourceUnit')),
        'UNIT_CONVERSION_REQUIRED',
        (v_line->>'lineNo')::integer,
        nullif(trim(v_line->>'notes'),'')
      );
    end loop;
  end loop;

  ------------------------------------------------------------------
  -- 3. SUBRECIPE EDGES
  ------------------------------------------------------------------

  for v_recipe in
    select value
    from jsonb_array_elements(p_payload->'recipes')
    order by value->>'code'
  loop
    select id
    into v_recipe_id
    from public.recipes
    where tenant_id=p_tenant_id
      and lower(code)=lower(trim(v_recipe->>'code'));

    for v_subline in
      select value
      from jsonb_array_elements(
        coalesce(v_recipe->'subrecipeLines','[]'::jsonb)
      )
      order by (value->>'lineNo')::integer
    loop
      select id
      into v_child_id
      from public.recipes
      where tenant_id=p_tenant_id
        and status='ACTIVE'
        and lower(code)=lower(trim(v_subline->>'subrecipeCode'));

      if not found then
        raise exception 'MASTER_DATA_V3_SUBRECIPE_NOT_AVAILABLE'
          using errcode='22023';
      end if;

      if not (v_subline ? 'quantity')
        or jsonb_typeof(v_subline->'quantity')='null'
      then
        v_quantity := null;
        v_unit := null;
      else
        v_quantity := (v_subline->>'quantity')::numeric;
        v_unit := upper(trim(v_subline->>'unit'));
      end if;

      insert into public.recipe_subrecipe_lines(
        tenant_id,
        recipe_id,
        subrecipe_id,
        quantity,
        unit,
        line_no,
        notes
      )
      values(
        p_tenant_id,
        v_recipe_id,
        v_child_id,
        v_quantity,
        v_unit,
        (v_subline->>'lineNo')::integer,
        nullif(trim(v_subline->>'notes'),'')
      );
    end loop;
  end loop;

  insert into public.audit_logs(
    tenant_id,
    actor_user_id,
    action,
    entity_type,
    metadata
  )
  values(
    p_tenant_id,
    auth.uid(),
    'FOODSERVICE_MASTER_DATA_V3_RECONCILED',
    'master_data_import',
    jsonb_build_object(
      'schemaVersion',3,
      'inventoryItemCount',v_inventory_count,
      'inventoryCreateCount',v_inventory_create_count,
      'inventoryReconcileCount',v_inventory_reconcile_count,
      'recipeCount',v_recipe_count,
      'recipeCreateCount',v_recipe_create_count,
      'recipeReconcileCount',v_recipe_reconcile_count,
      'resolvedDirectLineCount',v_resolved_count,
      'unresolvedDirectLineCount',v_unresolved_count,
      'subrecipeLineCount',v_subrecipe_count,
      'source',coalesce(p_payload->'source','{}'::jsonb)
    )
  );

  return jsonb_build_object(
    'schemaVersion',3,
    'mode','APPLY',
    'applied',true,
    'inventoryItemCount',v_inventory_count,
    'inventoryCreateCount',v_inventory_create_count,
    'inventoryReconcileCount',v_inventory_reconcile_count,
    'recipeCount',v_recipe_count,
    'recipeCreateCount',v_recipe_create_count,
    'recipeReconcileCount',v_recipe_reconcile_count,
    'resolvedDirectLineCount',v_resolved_count,
    'unresolvedDirectLineCount',v_unresolved_count,
    'subrecipeLineCount',v_subrecipe_count
  );
end;
$$;


revoke all
  on function public.import_foodservice_master_data_v3(uuid,jsonb,text)
  from public, anon;

grant execute
  on function public.import_foodservice_master_data_v3(uuid,jsonb,text)
  to authenticated, service_role;

comment on table public.recipe_unresolved_lines
  is 'Direct recipe source lines retained when source units cannot be safely converted to the inventory base unit. These rows intentionally make costing incomplete until conversion data is supplied.';

comment on function public.import_foodservice_master_data_v3(uuid,jsonb,text)
  is 'Idempotent create/reconcile importer for authoritative foodservice master data. Preserves unresolved direct unit conversions instead of inventing quantities.';
