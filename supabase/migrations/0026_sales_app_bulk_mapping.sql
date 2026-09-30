-- Atomically update multiple Sales App product mappings.
-- Either every requested mapping change succeeds or the whole statement rolls back.

create function public.bulk_update_sales_app_product_mappings(
  p_tenant_id uuid,
  p_updates jsonb
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_item jsonb;
  v_mapping_id uuid;
  v_menu_product_id uuid;
  v_status text;
  v_seen_ids uuid[] := array[]::uuid[];
  v_count integer := 0;
begin
  perform private.require_costing_access(
    p_tenant_id,
    'food-service.costing.write'
  );

  if jsonb_typeof(p_updates) is distinct from 'array'
    or jsonb_array_length(p_updates) not between 1 and 500
  then
    raise exception 'SALES_APP_BULK_MAPPING_INVALID'
      using errcode='22023';
  end if;

  -- Serialize mapping edits for the tenant.
  perform 1
  from public.tenants
  where id=p_tenant_id
  for update;

  for v_item in
    select value
    from jsonb_array_elements(p_updates)
  loop
    if jsonb_typeof(v_item) is distinct from 'object'
      or jsonb_typeof(v_item->'mappingId') is distinct from 'string'
      or jsonb_typeof(v_item->'status') is distinct from 'string'
      or (
        v_item ? 'menuProductId'
        and jsonb_typeof(v_item->'menuProductId')
          not in ('string','null')
      )
    then
      raise exception 'SALES_APP_BULK_MAPPING_INVALID'
        using errcode='22023';
    end if;

    if (v_item->>'mappingId') !~
      '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'
    then
      raise exception 'SALES_APP_BULK_MAPPING_INVALID'
        using errcode='22023';
    end if;

    v_mapping_id :=
      (v_item->>'mappingId')::uuid;

    v_status :=
      v_item->>'status';

    if v_status not in (
      'MAPPED',
      'UNMAPPED',
      'IGNORED'
    )
    then
      raise exception 'SALES_APP_BULK_MAPPING_INVALID'
        using errcode='22023';
    end if;

    if v_mapping_id = any(v_seen_ids) then
      raise exception 'SALES_APP_BULK_MAPPING_DUPLICATE'
        using errcode='22023';
    end if;

    v_seen_ids :=
      array_append(
        v_seen_ids,
        v_mapping_id
      );

    v_menu_product_id := null;

    if v_status='MAPPED' then
      if jsonb_typeof(
        v_item->'menuProductId'
      ) is distinct from 'string'
        or (v_item->>'menuProductId') !~
          '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'
      then
        raise exception 'SALES_APP_BULK_MAPPING_INVALID'
          using errcode='22023';
      end if;

      v_menu_product_id :=
        (v_item->>'menuProductId')::uuid;
    elsif (
      v_item ? 'menuProductId'
      and v_item->'menuProductId' <> 'null'::jsonb
    ) then
      raise exception 'SALES_APP_BULK_MAPPING_INVALID'
        using errcode='22023';
    end if;

    perform public.update_sales_app_product_mapping(
      p_tenant_id,
      v_mapping_id,
      v_status,
      v_menu_product_id
    );

    v_count := v_count + 1;
  end loop;

  return jsonb_build_object(
    'mappingCount',
    v_count
  );
end;
$$;

revoke all
on function public.bulk_update_sales_app_product_mappings(
  uuid,
  jsonb
)
from public,anon;

grant execute
on function public.bulk_update_sales_app_product_mappings(
  uuid,
  jsonb
)
to authenticated,service_role;
