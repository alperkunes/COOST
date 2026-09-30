create function public.import_foodservice_master_data_v2(
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
  v_mode text :=
    upper(trim(coalesce(p_mode,'')));

  v_inventory_count integer := 0;
  v_recipe_count integer := 0;
  v_recipe_line_count integer := 0;
  v_subrecipe_line_count integer := 0;
  v_unresolved_subrecipe_count integer := 0;
  v_yield_recipe_count integer := 0;
  v_missing_yield_recipe_count integer := 0;
  v_menu_product_count integer := 0;

  v_item jsonb;
  v_recipe jsonb;
  v_line jsonb;
  v_subline jsonb;

  v_lines jsonb;
  v_sub_lines jsonb;
  v_normalized_sub_lines jsonb;

  v_item_id uuid;
  v_recipe_id uuid;
  v_child_id uuid;

  v_quantity numeric;
  v_portions numeric;
  v_yield_quantity numeric;

  v_unit text;
  v_yield_unit text;
  v_notes text;

  v_inventory_conflicts jsonb := '[]'::jsonb;
  v_recipe_conflicts jsonb := '[]'::jsonb;

  v_can_apply boolean := false;
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
    raise exception 'MASTER_DATA_V2_MODE_INVALID'
      using errcode='22023';
  end if;

  if jsonb_typeof(p_payload)
      is distinct from 'object'
    or jsonb_typeof(
      p_payload->'schemaVersion'
    ) is distinct from 'number'
    or (
      p_payload->>'schemaVersion'
    )::integer <> 2
    or jsonb_typeof(
      p_payload->'inventoryItems'
    ) is distinct from 'array'
    or jsonb_typeof(
      p_payload->'recipes'
    ) is distinct from 'array'
    or jsonb_typeof(
      coalesce(
        p_payload->'menuProducts',
        '[]'::jsonb
      )
    ) is distinct from 'array'
  then
    raise exception 'MASTER_DATA_V2_PAYLOAD_INVALID'
      using errcode='22023';
  end if;

  v_inventory_count :=
    jsonb_array_length(
      p_payload->'inventoryItems'
    );

  v_recipe_count :=
    jsonb_array_length(
      p_payload->'recipes'
    );

  v_menu_product_count :=
    jsonb_array_length(
      coalesce(
        p_payload->'menuProducts',
        '[]'::jsonb
      )
    );

  if v_inventory_count not between 1 and 500
    or v_recipe_count not between 1 and 200
    or v_menu_product_count <> 0
  then
    raise exception 'MASTER_DATA_V2_PAYLOAD_INVALID'
      using errcode='22023';
  end if;

  ------------------------------------------------------------------
  -- INVENTORY VALIDATION
  ------------------------------------------------------------------

  for v_item in
    select value
    from jsonb_array_elements(
      p_payload->'inventoryItems'
    )
  loop
    if jsonb_typeof(v_item)
        is distinct from 'object'
      or jsonb_typeof(
        v_item->'sku'
      ) is distinct from 'string'
      or jsonb_typeof(
        v_item->'name'
      ) is distinct from 'string'
      or jsonb_typeof(
        v_item->'baseUnit'
      ) is distinct from 'string'
      or jsonb_typeof(
        v_item->'status'
      ) is distinct from 'string'
      or (
        v_item ? 'category'
        and jsonb_typeof(
          v_item->'category'
        ) not in ('string','null')
      )
    then
      raise exception 'MASTER_DATA_V2_INVENTORY_INVALID'
        using errcode='22023';
    end if;

    if char_length(
         trim(v_item->>'sku')
       ) not between 1 and 100
      or char_length(
           trim(v_item->>'name')
         ) not between 2 and 160
      or char_length(
           v_item->>'category'
         ) > 120
      or upper(
           trim(v_item->>'baseUnit')
         ) not in (
           'GRAM',
           'MILLILITER',
           'EACH'
         )
      or upper(
           trim(v_item->>'status')
         ) <> 'ACTIVE'
    then
      raise exception 'MASTER_DATA_V2_INVENTORY_INVALID'
        using errcode='22023';
    end if;
  end loop;

  if exists(
    select 1
    from (
      select
        lower(
          trim(value->>'sku')
        ) as key,
        count(*) as row_count
      from jsonb_array_elements(
        p_payload->'inventoryItems'
      )
      group by 1
      having count(*) > 1
    ) d
  )
  or exists(
    select 1
    from (
      select
        lower(
          regexp_replace(
            trim(value->>'name'),
            '[[:space:]]+',
            ' ',
            'g'
          )
        ) as key,
        count(*) as row_count
      from jsonb_array_elements(
        p_payload->'inventoryItems'
      )
      group by 1
      having count(*) > 1
    ) d
  )
  then
    raise exception 'MASTER_DATA_V2_INVENTORY_DUPLICATE'
      using errcode='22023';
  end if;

  ------------------------------------------------------------------
  -- RECIPE + DIRECT LINE + SUBRECIPE LINE VALIDATION
  ------------------------------------------------------------------

  for v_recipe in
    select value
    from jsonb_array_elements(
      p_payload->'recipes'
    )
  loop
    if jsonb_typeof(v_recipe)
        is distinct from 'object'
      or jsonb_typeof(
        v_recipe->'code'
      ) is distinct from 'string'
      or jsonb_typeof(
        v_recipe->'name'
      ) is distinct from 'string'
      or jsonb_typeof(
        v_recipe->'currencyCode'
      ) is distinct from 'string'
      or jsonb_typeof(
        v_recipe->'portions'
      ) is distinct from 'number'
      or jsonb_typeof(
        v_recipe->'status'
      ) is distinct from 'string'
      or jsonb_typeof(
        v_recipe->'lines'
      ) is distinct from 'array'
      or jsonb_typeof(
        coalesce(
          v_recipe->'subrecipeLines',
          '[]'::jsonb
        )
      ) is distinct from 'array'
      or (
        v_recipe ? 'category'
        and jsonb_typeof(
          v_recipe->'category'
        ) not in ('string','null')
      )
      or (
        v_recipe ? 'yieldQuantity'
        and jsonb_typeof(
          v_recipe->'yieldQuantity'
        ) not in ('number','null')
      )
      or (
        v_recipe ? 'yieldUnit'
        and jsonb_typeof(
          v_recipe->'yieldUnit'
        ) not in ('string','null')
      )
    then
      raise exception 'MASTER_DATA_V2_RECIPE_INVALID'
        using errcode='22023';
    end if;

    v_portions :=
      (v_recipe->>'portions')::numeric;

    if not (v_recipe ? 'yieldQuantity')
      or jsonb_typeof(
        v_recipe->'yieldQuantity'
      )='null'
    then
      v_yield_quantity := null;
    else
      v_yield_quantity :=
        (v_recipe->>'yieldQuantity')::numeric;
    end if;

    v_yield_unit :=
      nullif(
        upper(
          trim(
            v_recipe->>'yieldUnit'
          )
        ),
        ''
      );

    if char_length(
         trim(v_recipe->>'code')
       ) not between 1 and 100
      or char_length(
           trim(v_recipe->>'name')
         ) not between 2 and 160
      or char_length(
           v_recipe->>'category'
         ) > 120
      or upper(
           trim(
             v_recipe->>'currencyCode'
           )
         ) !~ '^[A-Z]{3}$'
      or v_portions <= 0
      or v_portions='NaN'::numeric
      or v_portions >
        99999999.9999
      or v_portions <>
        round(v_portions,4)
      or upper(
           trim(
             v_recipe->>'status'
           )
         ) <> 'ACTIVE'
      or jsonb_array_length(
           v_recipe->'lines'
         ) not between 1 and 200
      or jsonb_array_length(
           coalesce(
             v_recipe->'subrecipeLines',
             '[]'::jsonb
           )
         ) > 100
      or (
        (v_yield_quantity is null)
        <> (v_yield_unit is null)
      )
      or (
        v_yield_quantity is not null
        and (
          v_yield_quantity <= 0
          or v_yield_quantity='NaN'::numeric
          or v_yield_quantity >
            999999999999.9999
          or v_yield_quantity <>
            round(
              v_yield_quantity,
              4
            )
          or v_yield_unit not in (
            'GRAM',
            'MILLILITER',
            'EACH'
          )
        )
      )
    then
      raise exception 'MASTER_DATA_V2_RECIPE_INVALID'
        using errcode='22023';
    end if;

    if v_yield_quantity is not null then
      v_yield_recipe_count :=
        v_yield_recipe_count + 1;
    end if;

    --------------------------------------------------------------
    -- Direct ingredient duplicate validation
    --------------------------------------------------------------

    if exists(
      select 1
      from (
        select
          lower(
            trim(
              value->>'inventorySku'
            )
          ) as key,
          count(*) as row_count
        from jsonb_array_elements(
          v_recipe->'lines'
        )
        group by 1
        having count(*) > 1
      ) d
    )
    then
      raise exception
        'MASTER_DATA_V2_RECIPE_DUPLICATE_INGREDIENT'
        using errcode='22023';
    end if;

    --------------------------------------------------------------
    -- Direct ingredient validation
    --------------------------------------------------------------

    for v_line in
      select value
      from jsonb_array_elements(
        v_recipe->'lines'
      )
    loop
      if jsonb_typeof(v_line)
          is distinct from 'object'
        or jsonb_typeof(
          v_line->'inventorySku'
        ) is distinct from 'string'
        or jsonb_typeof(
          v_line->'quantityBase'
        ) is distinct from 'number'
        or (
          v_line ? 'notes'
          and jsonb_typeof(
            v_line->'notes'
          ) not in ('string','null')
        )
      then
        raise exception
          'MASTER_DATA_V2_RECIPE_LINE_INVALID'
          using errcode='22023';
      end if;

      v_quantity :=
        (v_line->>'quantityBase')::numeric;

      if char_length(
           trim(
             v_line->>'inventorySku'
           )
         ) not between 1 and 100
        or v_quantity <= 0
        or v_quantity='NaN'::numeric
        or v_quantity >
          999999999999.9999
        or v_quantity <>
          round(v_quantity,4)
        or char_length(
             v_line->>'notes'
           ) > 500
      then
        raise exception
          'MASTER_DATA_V2_RECIPE_LINE_INVALID'
          using errcode='22023';
      end if;

      if not exists(
        select 1
        from jsonb_array_elements(
          p_payload->'inventoryItems'
        ) source_item
        where lower(
          trim(
            source_item->>'sku'
          )
        ) =
        lower(
          trim(
            v_line->>'inventorySku'
          )
        )
      )
      then
        raise exception
          'MASTER_DATA_V2_RECIPE_ITEM_NOT_IN_PAYLOAD'
          using errcode='22023';
      end if;

      v_recipe_line_count :=
        v_recipe_line_count + 1;
    end loop;

    --------------------------------------------------------------
    -- Subrecipe duplicate validation
    --------------------------------------------------------------

    v_sub_lines :=
      coalesce(
        v_recipe->'subrecipeLines',
        '[]'::jsonb
      );

    if exists(
      select 1
      from (
        select
          lower(
            trim(
              value->>'subrecipeCode'
            )
          ) as key,
          count(*) as row_count
        from jsonb_array_elements(
          v_sub_lines
        )
        group by 1
        having count(*) > 1
      ) d
    )
    then
      raise exception
        'MASTER_DATA_V2_SUBRECIPE_DUPLICATE'
        using errcode='22023';
    end if;

    --------------------------------------------------------------
    -- Subrecipe structural validation
    --------------------------------------------------------------

    for v_subline in
      select value
      from jsonb_array_elements(
        v_sub_lines
      )
    loop
      if jsonb_typeof(v_subline)
          is distinct from 'object'
        or jsonb_typeof(
          v_subline->'subrecipeCode'
        ) is distinct from 'string'
        or (
          v_subline ? 'quantity'
          and jsonb_typeof(
            v_subline->'quantity'
          ) not in ('number','null')
        )
        or (
          v_subline ? 'unit'
          and jsonb_typeof(
            v_subline->'unit'
          ) not in ('string','null')
        )
        or (
          v_subline ? 'notes'
          and jsonb_typeof(
            v_subline->'notes'
          ) not in ('string','null')
        )
      then
        raise exception
          'MASTER_DATA_V2_SUBRECIPE_LINE_INVALID'
          using errcode='22023';
      end if;

      if not (v_subline ? 'quantity')
        or jsonb_typeof(
          v_subline->'quantity'
        )='null'
      then
        v_quantity := null;
      else
        v_quantity :=
          (v_subline->>'quantity')::numeric;
      end if;

      v_unit :=
        nullif(
          upper(
            trim(
              v_subline->>'unit'
            )
          ),
          ''
        );

      v_notes :=
        nullif(
          trim(
            v_subline->>'notes'
          ),
          ''
        );

      if char_length(
           trim(
             v_subline->>'subrecipeCode'
           )
         ) not between 1 and 100
        or (
          (v_quantity is null)
          <> (v_unit is null)
        )
        or (
          v_quantity is not null
          and (
            v_quantity <= 0
            or v_quantity='NaN'::numeric
            or v_quantity >
              999999999999.9999
            or v_quantity <>
              round(
                v_quantity,
                4
              )
            or v_unit not in (
              'GRAM',
              'MILLILITER',
              'EACH'
            )
          )
        )
        or char_length(
             v_notes
           ) > 500
      then
        raise exception
          'MASTER_DATA_V2_SUBRECIPE_LINE_INVALID'
          using errcode='22023';
      end if;

      if not exists(
        select 1
        from jsonb_array_elements(
          p_payload->'recipes'
        ) child_recipe
        where lower(
          trim(
            child_recipe->>'code'
          )
        ) =
        lower(
          trim(
            v_subline->>'subrecipeCode'
          )
        )
      )
      then
        raise exception
          'MASTER_DATA_V2_SUBRECIPE_NOT_IN_PAYLOAD'
          using errcode='22023';
      end if;

      v_subrecipe_line_count :=
        v_subrecipe_line_count + 1;

      if v_quantity is null then
        v_unresolved_subrecipe_count :=
          v_unresolved_subrecipe_count + 1;
      end if;
    end loop;
  end loop;

  ------------------------------------------------------------------
  -- RECIPE CODE / NAME DUPLICATES
  ------------------------------------------------------------------

  if exists(
    select 1
    from (
      select
        lower(
          trim(value->>'code')
        ) as key,
        count(*) as row_count
      from jsonb_array_elements(
        p_payload->'recipes'
      )
      group by 1
      having count(*) > 1
    ) d
  )
  or exists(
    select 1
    from (
      select
        lower(
          regexp_replace(
            trim(value->>'name'),
            '[[:space:]]+',
            ' ',
            'g'
          )
        ) as key,
        count(*) as row_count
      from jsonb_array_elements(
        p_payload->'recipes'
      )
      group by 1
      having count(*) > 1
    ) d
  )
  then
    raise exception 'MASTER_DATA_V2_RECIPE_DUPLICATE'
      using errcode='22023';
  end if;

  ------------------------------------------------------------------
  -- SUBRECIPE CURRENCY COMPATIBILITY
  ------------------------------------------------------------------

  if exists(
    select 1
    from jsonb_array_elements(
      p_payload->'recipes'
    ) parent_recipe
    cross join lateral
      jsonb_array_elements(
        coalesce(
          parent_recipe->'subrecipeLines',
          '[]'::jsonb
        )
      ) sub_line
    join lateral (
      select child_recipe.value
      from jsonb_array_elements(
        p_payload->'recipes'
      ) child_recipe(value)
      where lower(
        trim(
          child_recipe.value->>'code'
        )
      ) =
      lower(
        trim(
          sub_line->>'subrecipeCode'
        )
      )
      limit 1
    ) child
      on true
    where upper(
      trim(
        parent_recipe->>'currencyCode'
      )
    ) <>
    upper(
      trim(
        child.value->>'currencyCode'
      )
    )
  )
  then
    raise exception
      'MASTER_DATA_V2_SUBRECIPE_CURRENCY_MISMATCH'
      using errcode='22023';
  end if;

  ------------------------------------------------------------------
  -- SUBRECIPE UNIT / CHILD YIELD UNIT COMPATIBILITY
  --
  -- A known usage quantity may reference a child with unknown yield.
  -- That is representable but costing remains incomplete.
  --
  -- If both units are known, however, they must match.
  ------------------------------------------------------------------

  if exists(
    select 1
    from jsonb_array_elements(
      p_payload->'recipes'
    ) parent_recipe
    cross join lateral
      jsonb_array_elements(
        coalesce(
          parent_recipe->'subrecipeLines',
          '[]'::jsonb
        )
      ) sub_line
    join lateral (
      select child_recipe.value
      from jsonb_array_elements(
        p_payload->'recipes'
      ) child_recipe(value)
      where lower(
        trim(
          child_recipe.value->>'code'
        )
      ) =
      lower(
        trim(
          sub_line->>'subrecipeCode'
        )
      )
      limit 1
    ) child
      on true
    where sub_line ? 'quantity'
      and jsonb_typeof(
        sub_line->'quantity'
      )='number'
      and child.value ? 'yieldUnit'
      and jsonb_typeof(
        child.value->'yieldUnit'
      )='string'
      and nullif(
        trim(
          child.value->>'yieldUnit'
        ),
        ''
      ) is not null
      and upper(
        trim(
          sub_line->>'unit'
        )
      ) <>
      upper(
        trim(
          child.value->>'yieldUnit'
        )
      )
  )
  then
    raise exception
      'MASTER_DATA_V2_SUBRECIPE_UNIT_MISMATCH'
      using errcode='22023';
  end if;

  ------------------------------------------------------------------
  -- DEPENDENCY CYCLE VALIDATION
  --
  -- This runs entirely on payload recipe codes before APPLY.
  ------------------------------------------------------------------

  if exists(
    with recursive edges as (
      select
        lower(
          trim(
            parent_recipe->>'code'
          )
        ) as parent_code,

        lower(
          trim(
            sub_line->>'subrecipeCode'
          )
        ) as child_code

      from jsonb_array_elements(
        p_payload->'recipes'
      ) parent_recipe

      cross join lateral
        jsonb_array_elements(
          coalesce(
            parent_recipe->'subrecipeLines',
            '[]'::jsonb
          )
        ) sub_line
    ),

    walk(
      root_code,
      node_code,
      path,
      cycle_found
    ) as (
      select
        e.parent_code,
        e.child_code,
        array[
          e.parent_code,
          e.child_code
        ]::text[],
        e.parent_code=e.child_code

      from edges e

      union all

      select
        w.root_code,
        e.child_code,
        w.path || e.child_code,
        e.child_code=any(w.path)

      from walk w

      join edges e
        on e.parent_code=
          w.node_code

      where not w.cycle_found
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
  -- COUNT REFERENCED CHILD RECIPES WITH UNKNOWN YIELD
  ------------------------------------------------------------------

  select count(
    distinct lower(
      trim(
        sub_line->>'subrecipeCode'
      )
    )
  )
  into v_missing_yield_recipe_count

  from jsonb_array_elements(
    p_payload->'recipes'
  ) parent_recipe

  cross join lateral
    jsonb_array_elements(
      coalesce(
        parent_recipe->'subrecipeLines',
        '[]'::jsonb
      )
    ) sub_line

  join lateral (
    select child_recipe.value
    from jsonb_array_elements(
      p_payload->'recipes'
    ) child_recipe(value)
    where lower(
      trim(
        child_recipe.value->>'code'
      )
    ) =
    lower(
      trim(
        sub_line->>'subrecipeCode'
      )
    )
    limit 1
  ) child
    on true

  where not (
    child.value ? 'yieldQuantity'
  )
  or jsonb_typeof(
    child.value->'yieldQuantity'
  )='null';

  ------------------------------------------------------------------
  -- EXISTING INVENTORY CONFLICT PREVIEW
  ------------------------------------------------------------------

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'sku',
          source_item->>'sku',
        'name',
          source_item->>'name',
        'skuExists',
          exists(
            select 1
            from public.inventory_items current_item
            where current_item.tenant_id=
                p_tenant_id
              and lower(
                current_item.sku
              )=
              lower(
                trim(
                  source_item->>'sku'
                )
              )
          ),
        'nameExists',
          exists(
            select 1
            from public.inventory_items current_item
            where current_item.tenant_id=
                p_tenant_id
              and lower(
                regexp_replace(
                  trim(
                    current_item.name
                  ),
                  '[[:space:]]+',
                  ' ',
                  'g'
                )
              )=
              lower(
                regexp_replace(
                  trim(
                    source_item->>'name'
                  ),
                  '[[:space:]]+',
                  ' ',
                  'g'
                )
              )
          )
      )
      order by
        source_item->>'sku'
    ),
    '[]'::jsonb
  )
  into v_inventory_conflicts

  from jsonb_array_elements(
    p_payload->'inventoryItems'
  ) source_item

  where exists(
    select 1
    from public.inventory_items current_item
    where current_item.tenant_id=
        p_tenant_id
      and (
        lower(
          current_item.sku
        )=
        lower(
          trim(
            source_item->>'sku'
          )
        )
        or
        lower(
          regexp_replace(
            trim(
              current_item.name
            ),
            '[[:space:]]+',
            ' ',
            'g'
          )
        )=
        lower(
          regexp_replace(
            trim(
              source_item->>'name'
            ),
            '[[:space:]]+',
            ' ',
            'g'
          )
        )
      )
  );

  ------------------------------------------------------------------
  -- EXISTING RECIPE CONFLICT PREVIEW
  ------------------------------------------------------------------

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'code',
          source_recipe->>'code',
        'name',
          source_recipe->>'name',
        'codeExists',
          exists(
            select 1
            from public.recipes current_recipe
            where current_recipe.tenant_id=
                p_tenant_id
              and lower(
                current_recipe.code
              )=
              lower(
                trim(
                  source_recipe->>'code'
                )
              )
          ),
        'nameExists',
          exists(
            select 1
            from public.recipes current_recipe
            where current_recipe.tenant_id=
                p_tenant_id
              and lower(
                regexp_replace(
                  trim(
                    current_recipe.name
                  ),
                  '[[:space:]]+',
                  ' ',
                  'g'
                )
              )=
              lower(
                regexp_replace(
                  trim(
                    source_recipe->>'name'
                  ),
                  '[[:space:]]+',
                  ' ',
                  'g'
                )
              )
          )
      )
      order by
        source_recipe->>'code'
    ),
    '[]'::jsonb
  )
  into v_recipe_conflicts

  from jsonb_array_elements(
    p_payload->'recipes'
  ) source_recipe

  where exists(
    select 1
    from public.recipes current_recipe
    where current_recipe.tenant_id=
        p_tenant_id
      and (
        lower(
          current_recipe.code
        )=
        lower(
          trim(
            source_recipe->>'code'
          )
        )
        or
        lower(
          regexp_replace(
            trim(
              current_recipe.name
            ),
            '[[:space:]]+',
            ' ',
            'g'
          )
        )=
        lower(
          regexp_replace(
            trim(
              source_recipe->>'name'
            ),
            '[[:space:]]+',
            ' ',
            'g'
          )
        )
      )
  );

  v_can_apply :=
    jsonb_array_length(
      v_inventory_conflicts
    )=0
    and
    jsonb_array_length(
      v_recipe_conflicts
    )=0;

  ------------------------------------------------------------------
  -- DRY RUN RESULT
  ------------------------------------------------------------------

  if v_mode='DRY_RUN' then
    return jsonb_build_object(
      'schemaVersion',2,
      'mode','DRY_RUN',
      'canApply',v_can_apply,

      'inventoryItemCount',
        v_inventory_count,

      'recipeCount',
        v_recipe_count,

      'recipeLineCount',
        v_recipe_line_count,

      'subrecipeLineCount',
        v_subrecipe_line_count,

      'unresolvedSubrecipeLineCount',
        v_unresolved_subrecipe_count,

      'yieldRecipeCount',
        v_yield_recipe_count,

      'referencedRecipeMissingYieldCount',
        v_missing_yield_recipe_count,

      'menuProductCount',
        v_menu_product_count,

      'inventoryConflicts',
        v_inventory_conflicts,

      'recipeConflicts',
        v_recipe_conflicts,

      'sourceSummary',
        coalesce(
          p_payload->'summary',
          '{}'::jsonb
        )
    );
  end if;

  if not v_can_apply then
    raise exception 'MASTER_DATA_V2_CONFLICT'
      using errcode='23505';
  end if;

  ------------------------------------------------------------------
  -- APPLY
  --
  -- The RPC is one database statement. Any failure rolls back:
  -- inventory, recipes, yields, subrecipe relationships and audits.
  ------------------------------------------------------------------

  perform 1
  from public.tenants
  where id=p_tenant_id
  for update;

  if not found then
    raise exception
      'MASTER_DATA_V2_TENANT_NOT_AVAILABLE'
      using errcode='22023';
  end if;

  ------------------------------------------------------------------
  -- 1. INVENTORY
  ------------------------------------------------------------------

  for v_item in
    select value
    from jsonb_array_elements(
      p_payload->'inventoryItems'
    )
  loop
    perform public.create_inventory_item(
      p_tenant_id,
      trim(
        v_item->>'name'
      ),
      upper(
        trim(
          v_item->>'baseUnit'
        )
      ),
      trim(
        v_item->>'sku'
      ),
      nullif(
        trim(
          v_item->>'category'
        ),
        ''
      ),
      null
    );
  end loop;

  ------------------------------------------------------------------
  -- 2. RECIPES + DIRECT INGREDIENTS
  --
  -- All recipe rows are created before dependency edges.
  ------------------------------------------------------------------

  for v_recipe in
    select value
    from jsonb_array_elements(
      p_payload->'recipes'
    )
  loop
    v_lines := '[]'::jsonb;

    for v_line in
      select value
      from jsonb_array_elements(
        v_recipe->'lines'
      )
    loop
      select id
      into v_item_id
      from public.inventory_items
      where tenant_id=p_tenant_id
        and status='ACTIVE'
        and lower(sku)=
          lower(
            trim(
              v_line->>'inventorySku'
            )
          );

      if not found then
        raise exception
          'MASTER_DATA_V2_CREATED_ITEM_NOT_AVAILABLE'
          using errcode='22023';
      end if;

      v_lines :=
        v_lines ||
        jsonb_build_array(
          jsonb_build_object(
            'inventoryItemId',
              v_item_id,

            'quantityBase',
              (
                v_line->>'quantityBase'
              )::numeric,

            'notes',
              nullif(
                trim(
                  v_line->>'notes'
                ),
                ''
              )
          )
        );
    end loop;

    select public.create_recipe(
      p_tenant_id,
      trim(
        v_recipe->>'name'
      ),
      upper(
        trim(
          v_recipe->>'currencyCode'
        )
      ),
      (
        v_recipe->>'portions'
      )::numeric,
      v_lines,
      trim(
        v_recipe->>'code'
      ),
      nullif(
        trim(
          v_recipe->>'category'
        ),
        ''
      )
    )
    into v_recipe_id;
  end loop;

  ------------------------------------------------------------------
  -- 3. RECIPE YIELDS
  ------------------------------------------------------------------

  for v_recipe in
    select value
    from jsonb_array_elements(
      p_payload->'recipes'
    )
  loop
    if v_recipe ? 'yieldQuantity'
      and jsonb_typeof(
        v_recipe->'yieldQuantity'
      )='number'
    then
      select id
      into v_recipe_id
      from public.recipes
      where tenant_id=p_tenant_id
        and lower(code)=
          lower(
            trim(
              v_recipe->>'code'
            )
          );

      if not found then
        raise exception
          'MASTER_DATA_V2_CREATED_RECIPE_NOT_AVAILABLE'
          using errcode='22023';
      end if;

      perform public.update_recipe_yield(
        p_tenant_id,
        v_recipe_id,
        (
          v_recipe->>'yieldQuantity'
        )::numeric,
        upper(
          trim(
            v_recipe->>'yieldUnit'
          )
        )
      );
    end if;
  end loop;

  ------------------------------------------------------------------
  -- 4. SUBRECIPE DEPENDENCIES
  ------------------------------------------------------------------

  for v_recipe in
    select value
    from jsonb_array_elements(
      p_payload->'recipes'
    )
  loop
    v_sub_lines :=
      coalesce(
        v_recipe->'subrecipeLines',
        '[]'::jsonb
      );

    if jsonb_array_length(
         v_sub_lines
       ) > 0
    then
      select id
      into v_recipe_id
      from public.recipes
      where tenant_id=p_tenant_id
        and lower(code)=
          lower(
            trim(
              v_recipe->>'code'
            )
          );

      if not found then
        raise exception
          'MASTER_DATA_V2_CREATED_RECIPE_NOT_AVAILABLE'
          using errcode='22023';
      end if;

      v_normalized_sub_lines :=
        '[]'::jsonb;

      for v_subline in
        select value
        from jsonb_array_elements(
          v_sub_lines
        )
      loop
        select id
        into v_child_id
        from public.recipes
        where tenant_id=p_tenant_id
          and status='ACTIVE'
          and lower(code)=
            lower(
              trim(
                v_subline->>'subrecipeCode'
              )
            );

        if not found then
          raise exception
            'MASTER_DATA_V2_CREATED_RECIPE_NOT_AVAILABLE'
            using errcode='22023';
        end if;

        if not (v_subline ? 'quantity')
          or jsonb_typeof(
            v_subline->'quantity'
          )='null'
        then
          v_quantity := null;
          v_unit := null;
        else
          v_quantity :=
            (
              v_subline->>'quantity'
            )::numeric;

          v_unit :=
            upper(
              trim(
                v_subline->>'unit'
              )
            );
        end if;

        v_normalized_sub_lines :=
          v_normalized_sub_lines ||
          jsonb_build_array(
            jsonb_build_object(
              'subrecipeId',
                v_child_id,

              'quantity',
                v_quantity,

              'unit',
                v_unit,

              'notes',
                nullif(
                  trim(
                    v_subline->>'notes'
                  ),
                  ''
                )
            )
          );
      end loop;

      perform
        public.replace_recipe_subrecipe_lines(
          p_tenant_id,
          v_recipe_id,
          v_normalized_sub_lines
        );
    end if;
  end loop;

  ------------------------------------------------------------------
  -- IMPORT SUMMARY AUDIT
  ------------------------------------------------------------------

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
    'FOODSERVICE_MASTER_DATA_V2_IMPORTED',
    'master_data_import',
    jsonb_build_object(
      'schemaVersion',2,

      'inventoryItemCount',
        v_inventory_count,

      'recipeCount',
        v_recipe_count,

      'recipeLineCount',
        v_recipe_line_count,

      'subrecipeLineCount',
        v_subrecipe_line_count,

      'unresolvedSubrecipeLineCount',
        v_unresolved_subrecipe_count,

      'yieldRecipeCount',
        v_yield_recipe_count,

      'referencedRecipeMissingYieldCount',
        v_missing_yield_recipe_count,

      'menuProductCount',
        v_menu_product_count,

      'source',
        coalesce(
          p_payload->'source',
          '{}'::jsonb
        )
    )
  );

  return jsonb_build_object(
    'schemaVersion',2,
    'mode','APPLY',
    'applied',true,

    'inventoryItemCount',
      v_inventory_count,

    'recipeCount',
      v_recipe_count,

    'recipeLineCount',
      v_recipe_line_count,

    'subrecipeLineCount',
      v_subrecipe_line_count,

    'unresolvedSubrecipeLineCount',
      v_unresolved_subrecipe_count,

    'yieldRecipeCount',
      v_yield_recipe_count,

    'referencedRecipeMissingYieldCount',
      v_missing_yield_recipe_count,

    'menuProductCount',
      v_menu_product_count
  );
end;
$$;


revoke all
on function public.import_foodservice_master_data_v2(
  uuid,
  jsonb,
  text
)
from public,anon;


grant execute
on function public.import_foodservice_master_data_v2(
  uuid,
  jsonb,
  text
)
to authenticated,service_role;
