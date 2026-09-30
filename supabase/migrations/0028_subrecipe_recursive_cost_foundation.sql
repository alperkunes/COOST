alter table public.recipes
  add column yield_quantity numeric(16,4),
  add column yield_unit text;

alter table public.recipes
  add constraint recipes_yield_check
  check (
    (
      yield_quantity is null
      and yield_unit is null
    )
    or
    (
      yield_quantity is not null
      and yield_quantity > 0
      and yield_quantity <> 'NaN'::numeric
      and yield_quantity <= 999999999999.9999
      and yield_unit in ('GRAM','MILLILITER','EACH')
    )
  );

create table public.recipe_subrecipe_lines (
  id uuid primary key default gen_random_uuid(),

  tenant_id uuid not null
    references public.tenants(id)
    on delete restrict,

  recipe_id uuid not null,
  subrecipe_id uuid not null,

  quantity numeric(16,4),
  unit text,

  line_no integer not null
    check (line_no > 0),

  notes text
    check (char_length(notes) <= 500),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint recipe_subrecipe_not_self
    check (recipe_id <> subrecipe_id),

  constraint recipe_subrecipe_quantity_unit_check
    check (
      (
        quantity is null
        and unit is null
      )
      or
      (
        quantity is not null
        and quantity > 0
        and quantity <> 'NaN'::numeric
        and quantity <= 999999999999.9999
        and unit in ('GRAM','MILLILITER','EACH')
      )
    ),

  constraint recipe_subrecipe_parent_fk
    foreign key (recipe_id,tenant_id)
    references public.recipes(id,tenant_id)
    on delete restrict,

  constraint recipe_subrecipe_child_fk
    foreign key (subrecipe_id,tenant_id)
    references public.recipes(id,tenant_id)
    on delete restrict,

  constraint recipe_subrecipe_unique_child
    unique (recipe_id,subrecipe_id),

  constraint recipe_subrecipe_unique_line
    unique (recipe_id,line_no)
);

create index recipe_subrecipe_parent_idx
  on public.recipe_subrecipe_lines(
    tenant_id,
    recipe_id
  );

create index recipe_subrecipe_child_idx
  on public.recipe_subrecipe_lines(
    tenant_id,
    subrecipe_id
  );

alter table public.recipe_subrecipe_lines
  enable row level security;

revoke all
on public.recipe_subrecipe_lines
from public,anon,authenticated;


create function private.recipe_dependency_would_cycle(
  p_tenant_id uuid,
  p_recipe_id uuid,
  p_subrecipe_id uuid
)
returns boolean
language sql
stable
set search_path = ''
as $$
  with recursive walk(
    recipe_id,
    path
  ) as (
    select
      p_subrecipe_id,
      array[p_subrecipe_id]::uuid[]

    union all

    select
      l.subrecipe_id,
      w.path || l.subrecipe_id
    from walk w
    join public.recipe_subrecipe_lines l
      on l.tenant_id=p_tenant_id
     and l.recipe_id=w.recipe_id
    where not l.subrecipe_id=any(w.path)
  )
  select exists(
    select 1
    from walk
    where recipe_id=p_recipe_id
  );
$$;


create function private.validate_recipe_subrecipe_line()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_parent_currency text;
  v_child_currency text;
  v_child_status text;
  v_child_yield_unit text;
begin
  select currency_code
  into v_parent_currency
  from public.recipes
  where id=new.recipe_id
    and tenant_id=new.tenant_id;

  if not found then
    raise exception 'RECIPE_NOT_AVAILABLE'
      using errcode='22023';
  end if;

  select
    currency_code,
    status,
    yield_unit
  into
    v_child_currency,
    v_child_status,
    v_child_yield_unit
  from public.recipes
  where id=new.subrecipe_id
    and tenant_id=new.tenant_id;

  if not found then
    raise exception 'RECIPE_SUBRECIPE_NOT_AVAILABLE'
      using errcode='22023';
  end if;

  if new.recipe_id=new.subrecipe_id then
    raise exception 'RECIPE_DEPENDENCY_CYCLE'
      using errcode='22023';
  end if;

  if v_child_status <> 'ACTIVE' then
    raise exception 'RECIPE_SUBRECIPE_NOT_AVAILABLE'
      using errcode='22023';
  end if;

  if v_parent_currency <> v_child_currency then
    raise exception 'RECIPE_SUBRECIPE_CURRENCY_MISMATCH'
      using errcode='22023';
  end if;

  if new.quantity is not null
    and v_child_yield_unit is not null
    and new.unit <> v_child_yield_unit
  then
    raise exception 'RECIPE_SUBRECIPE_UNIT_MISMATCH'
      using errcode='22023';
  end if;

  if private.recipe_dependency_would_cycle(
    new.tenant_id,
    new.recipe_id,
    new.subrecipe_id
  ) then
    raise exception 'RECIPE_DEPENDENCY_CYCLE'
      using errcode='22023';
  end if;

  return new;
end;
$$;


create trigger recipe_subrecipe_validate
before insert or update
on public.recipe_subrecipe_lines
for each row
execute function private.validate_recipe_subrecipe_line();


create function private.guard_recipe_dependency_update()
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


create trigger recipes_dependency_guard
before update
on public.recipes
for each row
execute function private.guard_recipe_dependency_update();


create function public.update_recipe_yield(
  p_tenant_id uuid,
  p_recipe_id uuid,
  p_yield_quantity numeric,
  p_yield_unit text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  old public.recipes%rowtype;
  v_unit text :=
    nullif(
      upper(trim(p_yield_unit)),
      ''
    );
begin
  perform private.require_costing_access(
    p_tenant_id,
    'food-service.costing.write'
  );

  select *
  into old
  from public.recipes
  where id=p_recipe_id
    and tenant_id=p_tenant_id
  for update;

  if not found then
    raise exception 'RECIPE_NOT_AVAILABLE'
      using errcode='22023';
  end if;

  if (
      p_yield_quantity is null
      and v_unit is not null
    )
    or (
      p_yield_quantity is not null
      and v_unit is null
    )
    or (
      p_yield_quantity is not null
      and (
        p_yield_quantity <= 0
        or p_yield_quantity='NaN'::numeric
        or p_yield_quantity > 999999999999.9999
        or p_yield_quantity <>
          round(p_yield_quantity,4)
        or v_unit not in (
          'GRAM',
          'MILLILITER',
          'EACH'
        )
      )
    )
  then
    raise exception 'RECIPE_YIELD_INVALID'
      using errcode='22023';
  end if;

  if (
    old.yield_quantity,
    old.yield_unit
  ) is not distinct from (
    p_yield_quantity,
    v_unit
  ) then
    raise exception 'COSTING_NO_CHANGES'
      using errcode='22023';
  end if;

  if v_unit is not null
    and exists(
      select 1
      from public.recipe_subrecipe_lines l
      where l.tenant_id=p_tenant_id
        and l.subrecipe_id=p_recipe_id
        and l.unit is not null
        and l.unit <> v_unit
    )
  then
    raise exception 'RECIPE_YIELD_UNIT_IN_USE'
      using errcode='22023';
  end if;

  update public.recipes
  set
    yield_quantity=p_yield_quantity,
    yield_unit=v_unit,
    updated_at=now()
  where id=p_recipe_id;

  insert into public.audit_logs(
    tenant_id,
    actor_user_id,
    action,
    entity_type,
    entity_id,
    metadata
  )
  values(
    p_tenant_id,
    auth.uid(),
    'RECIPE_YIELD_UPDATED',
    'recipe',
    p_recipe_id,
    jsonb_build_object(
      'recipeId',
        p_recipe_id,
      'yieldQuantity',
        p_yield_quantity,
      'yieldUnit',
        v_unit
    )
  );

  return p_recipe_id;
end;
$$;


create function public.replace_recipe_subrecipe_lines(
  p_tenant_id uuid,
  p_recipe_id uuid,
  p_lines jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  l jsonb;
  normalized jsonb := '[]'::jsonb;
  previous jsonb := '[]'::jsonb;

  v_child uuid;
  v_quantity numeric;
  v_unit text;
  v_notes text;

  n integer := 0;
begin
  perform private.require_costing_access(
    p_tenant_id,
    'food-service.costing.write'
  );

  perform 1
  from public.recipes
  where id=p_recipe_id
    and tenant_id=p_tenant_id
  for update;

  if not found then
    raise exception 'RECIPE_NOT_AVAILABLE'
      using errcode='22023';
  end if;

  if jsonb_typeof(p_lines)
      is distinct from 'array'
    or jsonb_array_length(p_lines) > 100
  then
    raise exception 'RECIPE_SUBRECIPE_LINES_INVALID'
      using errcode='22023';
  end if;

  for l in
    select value
    from jsonb_array_elements(p_lines)
  loop
    if jsonb_typeof(l)
        is distinct from 'object'
      or jsonb_typeof(
        l->'subrecipeId'
      ) is distinct from 'string'
      or (
        l ? 'quantity'
        and jsonb_typeof(
          l->'quantity'
        ) not in ('number','null')
      )
      or (
        l ? 'unit'
        and jsonb_typeof(
          l->'unit'
        ) not in ('string','null')
      )
      or (
        l ? 'notes'
        and jsonb_typeof(
          l->'notes'
        ) not in ('string','null')
      )
    then
      raise exception 'RECIPE_SUBRECIPE_LINES_INVALID'
        using errcode='22023';
    end if;

    begin
      v_child :=
        (l->>'subrecipeId')::uuid;
    exception
      when invalid_text_representation then
        raise exception 'RECIPE_SUBRECIPE_LINES_INVALID'
          using errcode='22023';
    end;

    if l->'quantity' is null
      or jsonb_typeof(
        l->'quantity'
      )='null'
    then
      v_quantity := null;
    else
      v_quantity :=
        (l->>'quantity')::numeric;
    end if;

    v_unit :=
      nullif(
        upper(trim(l->>'unit')),
        ''
      );

    v_notes :=
      nullif(
        trim(l->>'notes'),
        ''
      );

    if v_child is null
      or (
        (v_quantity is null)
        <> (v_unit is null)
      )
      or (
        v_quantity is not null
        and (
          v_quantity <= 0
          or v_quantity='NaN'::numeric
          or v_quantity > 999999999999.9999
          or v_quantity <>
            round(v_quantity,4)
          or v_unit not in (
            'GRAM',
            'MILLILITER',
            'EACH'
          )
        )
      )
      or char_length(v_notes) > 500
    then
      raise exception 'RECIPE_SUBRECIPE_LINES_INVALID'
        using errcode='22023';
    end if;

    if exists(
      select 1
      from jsonb_array_elements(
        normalized
      ) x
      where x->>'subrecipeId'=
        v_child::text
    ) then
      raise exception 'RECIPE_SUBRECIPE_DUPLICATE'
        using errcode='22023';
    end if;

    normalized :=
      normalized ||
      jsonb_build_array(
        jsonb_build_object(
          'subrecipeId',
            v_child,
          'quantity',
            v_quantity,
          'unit',
            v_unit,
          'notes',
            v_notes
        )
      );
  end loop;

  perform 1
  from public.recipes r
  where r.tenant_id=p_tenant_id
    and r.id in (
      select
        (x->>'subrecipeId')::uuid
      from jsonb_array_elements(
        normalized
      ) x
    )
  order by r.id
  for share;

  if exists(
    select 1
    from jsonb_array_elements(
      normalized
    ) x
    where not exists(
      select 1
      from public.recipes r
      where r.tenant_id=p_tenant_id
        and r.id=
          (x->>'subrecipeId')::uuid
        and r.status='ACTIVE'
    )
  ) then
    raise exception 'RECIPE_SUBRECIPE_NOT_AVAILABLE'
      using errcode='22023';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'subrecipeId',
          subrecipe_id,
        'quantity',
          quantity,
        'unit',
          unit,
        'notes',
          notes
      )
      order by line_no
    ),
    '[]'::jsonb
  )
  into previous
  from public.recipe_subrecipe_lines
  where tenant_id=p_tenant_id
    and recipe_id=p_recipe_id;

  if previous=normalized then
    raise exception 'COSTING_NO_CHANGES'
      using errcode='22023';
  end if;

  delete
  from public.recipe_subrecipe_lines
  where tenant_id=p_tenant_id
    and recipe_id=p_recipe_id;

  for l in
    select value
    from jsonb_array_elements(
      normalized
    )
  loop
    n := n + 1;

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
      p_recipe_id,
      (l->>'subrecipeId')::uuid,
      case
        when l->'quantity'='null'::jsonb
          then null
        else
          (l->>'quantity')::numeric
      end,
      l->>'unit',
      n,
      l->>'notes'
    );
  end loop;

  insert into public.audit_logs(
    tenant_id,
    actor_user_id,
    action,
    entity_type,
    entity_id,
    metadata
  )
  values(
    p_tenant_id,
    auth.uid(),
    'RECIPE_SUBRECIPES_REPLACED',
    'recipe',
    p_recipe_id,
    jsonb_build_object(
      'recipeId',
        p_recipe_id,
      'lineCount',
        n,
      'resolvedLineCount',
        (
          select count(*)
          from jsonb_array_elements(
            normalized
          ) x
          where x->'quantity'
            <> 'null'::jsonb
        ),
      'unresolvedLineCount',
        (
          select count(*)
          from jsonb_array_elements(
            normalized
          ) x
          where x->'quantity'
            = 'null'::jsonb
        )
    )
  );

  return p_recipe_id;

exception
  when unique_violation then
    raise exception 'RECIPE_SUBRECIPE_DUPLICATE'
      using errcode='23505';
end;
$$;


create function private.recipe_cost_node(
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
  s record;

  v_last_unit numeric;
  v_weighted_unit numeric;

  v_last_line numeric;
  v_weighted_line numeric;

  v_child jsonb;
  v_child_last numeric;
  v_child_weighted numeric;
  v_child_complete boolean;

  v_direct_lines jsonb :=
    '[]'::jsonb;

  v_subrecipe_lines jsonb :=
    '[]'::jsonb;

  v_total_last numeric := 0;
  v_total_weighted numeric := 0;

  v_missing_direct integer := 0;
  v_missing_subrecipe integer := 0;

  v_direct_count integer := 0;
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
      'id',
        r.id,
      'name',
        r.name,
      'code',
        r.code,
      'category',
        r.category,
      'currencyCode',
        r.currency_code,
      'portions',
        r.portions,
      'status',
        r.status,
      'yieldQuantity',
        r.yield_quantity,
      'yieldUnit',
        r.yield_unit,
      'lines',
        '[]'::jsonb,
      'subrecipeLines',
        '[]'::jsonb,
      'totalLastCost',
        null,
      'totalWeightedCost',
        null,
      'costPerPortionLast',
        null,
      'costPerPortionWeighted',
        null,
      'missingCostItemCount',
        1,
      'missingDirectCostItemCount',
        0,
      'missingSubrecipeCostCount',
        1,
      'costStatus',
        'DEPENDENCY_CYCLE',
      'costingComplete',
        false
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
    v_direct_count :=
      v_direct_count + 1;

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
    where pc.item_id=
      l.inventory_item_id;

    if v_last_unit is null
      or v_weighted_unit is null
    then
      v_missing_direct :=
        v_missing_direct + 1;

      v_last_line := null;
      v_weighted_line := null;
    else
      v_last_line :=
        l.quantity_base *
        v_last_unit;

      v_weighted_line :=
        l.quantity_base *
        v_weighted_unit;

      v_total_last :=
        v_total_last +
        v_last_line;

      v_total_weighted :=
        v_total_weighted +
        v_weighted_line;
    end if;

    v_direct_lines :=
      v_direct_lines ||
      jsonb_build_array(
        jsonb_build_object(
          'inventoryItemId',
            l.inventory_item_id,
          'itemName',
            l.item_name,
          'baseUnit',
            l.base_unit,
          'itemStatus',
            l.item_status,
          'quantityBase',
            l.quantity_base,
          'notes',
            l.notes,
          'lastUnitCost',
            v_last_unit,
          'weightedUnitCost',
            v_weighted_unit,
          'lastLineCost',
            v_last_line,
          'weightedLineCost',
            v_weighted_line,
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
      cr.yield_quantity
        as child_yield_quantity,
      cr.yield_unit
        as child_yield_unit

    from public.recipe_subrecipe_lines sl
    join public.recipes cr
      on cr.id=sl.subrecipe_id
     and cr.tenant_id=sl.tenant_id

    where sl.tenant_id=p_tenant_id
      and sl.recipe_id=p_recipe_id

    order by sl.line_no
  loop
    v_subrecipe_count :=
      v_subrecipe_count + 1;

    v_child :=
      private.recipe_cost_node(
        p_tenant_id,
        s.subrecipe_id,
        p_location_id,
        p_path ||
          array[p_recipe_id]
      );

    v_child_complete :=
      coalesce(
        (
          v_child
          ->>'costingComplete'
        )::boolean,
        false
      );

    v_child_last :=
      case
        when v_child->>'totalLastCost'
          is null
          then null
        else
          (
            v_child
            ->>'totalLastCost'
          )::numeric
      end;

    v_child_weighted :=
      case
        when v_child
          ->>'totalWeightedCost'
          is null
          then null
        else
          (
            v_child
            ->>'totalWeightedCost'
          )::numeric
      end;

    v_last_line := null;
    v_weighted_line := null;

    if s.quantity is null
      or s.unit is null
    then
      v_sub_status :=
        'MISSING_USAGE_QUANTITY';

    elsif s.child_yield_quantity
        is null
      or s.child_yield_unit
        is null
    then
      v_sub_status :=
        'MISSING_CHILD_YIELD';

    elsif s.unit <>
      s.child_yield_unit
    then
      v_sub_status :=
        'UNIT_MISMATCH';

    elsif s.child_status <>
      'ACTIVE'
    then
      v_sub_status :=
        'CHILD_RECIPE_INACTIVE';

    elsif not v_child_complete
    then
      v_sub_status :=
        'CHILD_COST_INCOMPLETE';

    elsif v_child_last is null
      or v_child_weighted is null
    then
      v_sub_status :=
        'CHILD_COST_INCOMPLETE';

    else
      v_sub_status := 'READY';

      v_last_line :=
        s.quantity *
        v_child_last /
        s.child_yield_quantity;

      v_weighted_line :=
        s.quantity *
        v_child_weighted /
        s.child_yield_quantity;

      v_total_last :=
        v_total_last +
        v_last_line;

      v_total_weighted :=
        v_total_weighted +
        v_weighted_line;
    end if;

    if v_sub_status <> 'READY' then
      v_missing_subrecipe :=
        v_missing_subrecipe + 1;
    end if;

    v_subrecipe_lines :=
      v_subrecipe_lines ||
      jsonb_build_array(
        jsonb_build_object(
          'subrecipeId',
            s.subrecipe_id,
          'subrecipeName',
            s.child_name,
          'subrecipeCode',
            s.child_code,
          'quantity',
            s.quantity,
          'unit',
            s.unit,
          'yieldQuantity',
            s.child_yield_quantity,
          'yieldUnit',
            s.child_yield_unit,
          'notes',
            s.notes,
          'childCostingComplete',
            v_child_complete,
          'childTotalLastCost',
            v_child_last,
          'childTotalWeightedCost',
            v_child_weighted,
          'lastLineCost',
            v_last_line,
          'weightedLineCost',
            v_weighted_line,
          'costStatus',
            v_sub_status
        )
      );
  end loop;

  v_complete :=
    (
      v_missing_direct +
      v_missing_subrecipe
    )=0
    and (
      v_direct_count +
      v_subrecipe_count
    ) > 0;

  return jsonb_build_object(
    'id',
      r.id,
    'name',
      r.name,
    'code',
      r.code,
    'category',
      r.category,
    'currencyCode',
      r.currency_code,
    'portions',
      r.portions,
    'status',
      r.status,

    'yieldQuantity',
      r.yield_quantity,
    'yieldUnit',
      r.yield_unit,

    'lines',
      v_direct_lines,
    'subrecipeLines',
      v_subrecipe_lines,

    'totalLastCost',
      case
        when v_complete
          then v_total_last
        else null
      end,

    'totalWeightedCost',
      case
        when v_complete
          then v_total_weighted
        else null
      end,

    'costPerPortionLast',
      case
        when v_complete
          then
            v_total_last /
            r.portions
        else null
      end,

    'costPerPortionWeighted',
      case
        when v_complete
          then
            v_total_weighted /
            r.portions
        else null
      end,

    'missingCostItemCount',
      v_missing_direct +
      v_missing_subrecipe,

    'missingDirectCostItemCount',
      v_missing_direct,

    'missingSubrecipeCostCount',
      v_missing_subrecipe,

    'directLineCount',
      v_direct_count,

    'subrecipeLineCount',
      v_subrecipe_count,

    'costStatus',
      case
        when v_complete
          then 'READY'
        else 'INCOMPLETE'
      end,

    'costingComplete',
      v_complete
  );
end;
$$;


create or replace function private.recipe_costs(
  p_tenant_id uuid,
  p_location_id uuid
)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select coalesce(
    jsonb_agg(
      x.node
      order by
        x.recipe_name,
        x.recipe_id
    ),
    '[]'::jsonb
  )
  from (
    select
      r.id as recipe_id,
      r.name as recipe_name,

      private.recipe_cost_node(
        p_tenant_id,
        r.id,
        p_location_id
      ) as node

    from public.recipes r
    where r.tenant_id=p_tenant_id
  ) x;
$$;


revoke all
on function private.recipe_dependency_would_cycle(
  uuid,
  uuid,
  uuid
)
from public,anon,authenticated;

revoke all
on function private.validate_recipe_subrecipe_line()
from public,anon,authenticated;

revoke all
on function private.guard_recipe_dependency_update()
from public,anon,authenticated;

revoke all
on function private.recipe_cost_node(
  uuid,
  uuid,
  uuid,
  uuid[]
)
from public,anon,authenticated;


revoke all
on function public.update_recipe_yield(
  uuid,
  uuid,
  numeric,
  text
)
from public,anon;

grant execute
on function public.update_recipe_yield(
  uuid,
  uuid,
  numeric,
  text
)
to authenticated,service_role;


revoke all
on function public.replace_recipe_subrecipe_lines(
  uuid,
  uuid,
  jsonb
)
from public,anon;

grant execute
on function public.replace_recipe_subrecipe_lines(
  uuid,
  uuid,
  jsonb
)
to authenticated,service_role;
