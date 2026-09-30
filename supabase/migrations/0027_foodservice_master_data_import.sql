create function public.import_foodservice_master_data(
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

  v_inventory_count integer := 0;
  v_recipe_count integer := 0;
  v_recipe_line_count integer := 0;
  v_menu_product_count integer := 0;

  v_item jsonb;
  v_recipe jsonb;
  v_line jsonb;

  v_lines jsonb;
  v_item_id uuid;

  v_inventory_conflicts jsonb := '[]'::jsonb;
  v_recipe_conflicts jsonb := '[]'::jsonb;

  v_can_apply boolean := false;

  v_quantity numeric;
  v_portions numeric;
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
    raise exception 'MASTER_DATA_MODE_INVALID'
      using errcode='22023';
  end if;

  if jsonb_typeof(p_payload) is distinct from 'object'
    or jsonb_typeof(p_payload->'schemaVersion') is distinct from 'number'
    or (p_payload->>'schemaVersion')::integer <> 1
    or jsonb_typeof(p_payload->'inventoryItems') is distinct from 'array'
    or jsonb_typeof(p_payload->'recipes') is distinct from 'array'
    or jsonb_typeof(
      coalesce(
        p_payload->'menuProducts',
        '[]'::jsonb
      )
    ) is distinct from 'array'
  then
    raise exception 'MASTER_DATA_PAYLOAD_INVALID'
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
    raise exception 'MASTER_DATA_PAYLOAD_INVALID'
      using errcode='22023';
  end if;

  ------------------------------------------------------------------
  -- Inventory payload validation
  ------------------------------------------------------------------

  for v_item in
    select value
    from jsonb_array_elements(
      p_payload->'inventoryItems'
    )
  loop
    if jsonb_typeof(v_item)
        is distinct from 'object'
      or jsonb_typeof(v_item->'sku')
        is distinct from 'string'
      or jsonb_typeof(v_item->'name')
        is distinct from 'string'
      or jsonb_typeof(v_item->'baseUnit')
        is distinct from 'string'
      or jsonb_typeof(v_item->'status')
        is distinct from 'string'
      or (
        v_item ? 'category'
        and jsonb_typeof(
          v_item->'category'
        ) not in ('string','null')
      )
    then
      raise exception 'MASTER_DATA_INVENTORY_INVALID'
        using errcode='22023';
    end if;

    if char_length(
         trim(v_item->>'sku')
       ) not between 1 and 100
      or char_length(
           trim(v_item->>'name')
         ) not between 2 and 160
      or char_length(
           trim(v_item->>'category')
         ) > 120
      or v_item->>'baseUnit'
        not in (
          'GRAM',
          'MILLILITER',
          'EACH'
        )
      or v_item->>'status' <> 'ACTIVE'
    then
      raise exception 'MASTER_DATA_INVENTORY_INVALID'
        using errcode='22023';
    end if;
  end loop;

  if exists(
    select 1
    from (
      select
        lower(trim(value->>'sku')) key,
        count(*) row_count
      from jsonb_array_elements(
        p_payload->'inventoryItems'
      )
      group by 1
      having count(*) > 1
    ) duplicate_skus
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
        ) key,
        count(*) row_count
      from jsonb_array_elements(
        p_payload->'inventoryItems'
      )
      group by 1
      having count(*) > 1
    ) duplicate_names
  )
  then
    raise exception 'MASTER_DATA_INVENTORY_DUPLICATE'
      using errcode='22023';
  end if;

  ------------------------------------------------------------------
  -- Recipe payload validation
  ------------------------------------------------------------------

  for v_recipe in
    select value
    from jsonb_array_elements(
      p_payload->'recipes'
    )
  loop
    if jsonb_typeof(v_recipe)
        is distinct from 'object'
      or jsonb_typeof(v_recipe->'code')
        is distinct from 'string'
      or jsonb_typeof(v_recipe->'name')
        is distinct from 'string'
      or jsonb_typeof(v_recipe->'currencyCode')
        is distinct from 'string'
      or jsonb_typeof(v_recipe->'portions')
        is distinct from 'number'
      or jsonb_typeof(v_recipe->'status')
        is distinct from 'string'
      or jsonb_typeof(v_recipe->'lines')
        is distinct from 'array'
      or (
        v_recipe ? 'category'
        and jsonb_typeof(
          v_recipe->'category'
        ) not in ('string','null')
      )
    then
      raise exception 'MASTER_DATA_RECIPE_INVALID'
        using errcode='22023';
    end if;

    v_portions :=
      (v_recipe->>'portions')::numeric;

    if char_length(
         trim(v_recipe->>'code')
       ) not between 1 and 100
      or char_length(
           trim(v_recipe->>'name')
         ) not between 2 and 160
      or char_length(
           trim(v_recipe->>'category')
         ) > 120
      or v_recipe->>'currencyCode'
        !~ '^[A-Z]{3}$'
      or v_portions <= 0
      or v_portions >
        99999999.9999
      or v_portions <>
        round(v_portions,4)
      or v_recipe->>'status'
        <> 'ACTIVE'
      or jsonb_array_length(
           v_recipe->'lines'
         ) not between 1 and 200
    then
      raise exception 'MASTER_DATA_RECIPE_INVALID'
        using errcode='22023';
    end if;

    if exists(
      select 1
      from (
        select
          lower(
            trim(
              value->>'inventorySku'
            )
          ) key,
          count(*) row_count
        from jsonb_array_elements(
          v_recipe->'lines'
        )
        group by 1
        having count(*) > 1
      ) duplicate_lines
    )
    then
      raise exception 'MASTER_DATA_RECIPE_DUPLICATE_INGREDIENT'
        using errcode='22023';
    end if;

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
        raise exception 'MASTER_DATA_RECIPE_LINE_INVALID'
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
        or v_quantity >
          999999999999.9999
        or v_quantity <>
          round(v_quantity,4)
        or char_length(
             v_line->>'notes'
           ) > 500
      then
        raise exception 'MASTER_DATA_RECIPE_LINE_INVALID'
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
        raise exception 'MASTER_DATA_RECIPE_ITEM_NOT_IN_PAYLOAD'
          using errcode='22023';
      end if;

      v_recipe_line_count :=
        v_recipe_line_count + 1;
    end loop;
  end loop;

  if exists(
    select 1
    from (
      select
        lower(trim(value->>'code')) key,
        count(*) row_count
      from jsonb_array_elements(
        p_payload->'recipes'
      )
      group by 1
      having count(*) > 1
    ) duplicate_codes
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
        ) key,
        count(*) row_count
      from jsonb_array_elements(
        p_payload->'recipes'
      )
      group by 1
      having count(*) > 1
    ) duplicate_names
  )
  then
    raise exception 'MASTER_DATA_RECIPE_DUPLICATE'
      using errcode='22023';
  end if;

  ------------------------------------------------------------------
  -- Existing data conflict preview
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
          where current_item.tenant_id =
              p_tenant_id
            and lower(
              current_item.sku
            ) =
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
          where current_item.tenant_id =
              p_tenant_id
            and lower(
              regexp_replace(
                trim(current_item.name),
                '[[:space:]]+',
                ' ',
                'g'
              )
            ) =
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
      order by source_item->>'sku'
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
    where current_item.tenant_id =
        p_tenant_id
      and (
        lower(current_item.sku) =
          lower(
            trim(
              source_item->>'sku'
            )
          )
        or
        lower(
          regexp_replace(
            trim(current_item.name),
            '[[:space:]]+',
            ' ',
            'g'
          )
        ) =
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
          where current_recipe.tenant_id =
              p_tenant_id
            and lower(
              current_recipe.code
            ) =
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
          where current_recipe.tenant_id =
              p_tenant_id
            and lower(
              regexp_replace(
                trim(current_recipe.name),
                '[[:space:]]+',
                ' ',
                'g'
              )
            ) =
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
      order by source_recipe->>'code'
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
    where current_recipe.tenant_id =
        p_tenant_id
      and (
        lower(current_recipe.code) =
          lower(
            trim(
              source_recipe->>'code'
            )
          )
        or
        lower(
          regexp_replace(
            trim(current_recipe.name),
            '[[:space:]]+',
            ' ',
            'g'
          )
        ) =
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
    ) = 0
    and
    jsonb_array_length(
      v_recipe_conflicts
    ) = 0;

  if v_mode = 'DRY_RUN' then
    return jsonb_build_object(
      'schemaVersion',1,
      'mode','DRY_RUN',
      'canApply',v_can_apply,
      'inventoryItemCount',
        v_inventory_count,
      'recipeCount',
        v_recipe_count,
      'recipeLineCount',
        v_recipe_line_count,
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
    raise exception 'MASTER_DATA_CONFLICT'
      using errcode='23505';
  end if;

  ------------------------------------------------------------------
  -- APPLY
  -- One function statement = one database transaction.
  ------------------------------------------------------------------

  perform 1
  from public.tenants
  where id=p_tenant_id
  for update;

  if not found then
    raise exception 'MASTER_DATA_TENANT_NOT_AVAILABLE'
      using errcode='22023';
  end if;

  for v_item in
    select value
    from jsonb_array_elements(
      p_payload->'inventoryItems'
    )
  loop
    perform public.create_inventory_item(
      p_tenant_id,
      trim(v_item->>'name'),
      v_item->>'baseUnit',
      trim(v_item->>'sku'),
      nullif(
        trim(v_item->>'category'),
        ''
      ),
      null
    );
  end loop;

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
        raise exception 'MASTER_DATA_CREATED_ITEM_NOT_AVAILABLE'
          using errcode='22023';
      end if;

      v_lines :=
        v_lines ||
        jsonb_build_array(
          jsonb_build_object(
            'inventoryItemId',
              v_item_id,
            'quantityBase',
              (v_line->>'quantityBase')::numeric,
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

    perform public.create_recipe(
      p_tenant_id,
      trim(v_recipe->>'name'),
      v_recipe->>'currencyCode',
      (v_recipe->>'portions')::numeric,
      v_lines,
      trim(v_recipe->>'code'),
      nullif(
        trim(
          v_recipe->>'category'
        ),
        ''
      )
    );
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
    'FOODSERVICE_MASTER_DATA_IMPORTED',
    'master_data_import',
    jsonb_build_object(
      'schemaVersion',1,
      'inventoryItemCount',
        v_inventory_count,
      'recipeCount',
        v_recipe_count,
      'recipeLineCount',
        v_recipe_line_count,
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
    'schemaVersion',1,
    'mode','APPLY',
    'applied',true,
    'inventoryItemCount',
      v_inventory_count,
    'recipeCount',
      v_recipe_count,
    'recipeLineCount',
      v_recipe_line_count,
    'menuProductCount',
      v_menu_product_count
  );
end;
$$;

revoke all
on function public.import_foodservice_master_data(
  uuid,
  jsonb,
  text
)
from public,anon;

grant execute
on function public.import_foodservice_master_data(
  uuid,
  jsonb,
  text
)
to authenticated,service_role;
