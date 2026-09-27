-- Fix PL/pgSQL variable / SQL alias ambiguity in Sales App daily import.
create or replace function public.import_sales_app_daily_sales(
  p_tenant_id uuid,
  p_location_id uuid,
  p_business_date date,
  p_external_batch_key text,
  p_currency_code text,
  p_rows jsonb
)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare
  b public.sales_app_import_batches%rowtype;
  m public.sales_app_product_mappings%rowtype;
  v_row jsonb;
  normalized jsonb := '[]';
  ext text;
  nm text;
  code text;
  q numeric;
  g numeric;
  n numeric;
  v_id uuid;
  fingerprint text;
  result jsonb;
begin
  perform private.require_costing_access(
    p_tenant_id,
    'food-service.costing.write',
    p_location_id
  );

  if p_location_id is null
    or not exists(
      select 1
      from public.locations
      where id=p_location_id
        and tenant_id=p_tenant_id
        and status='ACTIVE'
    )
  then
    raise exception 'COSTING_LOCATION_NOT_AVAILABLE'
      using errcode='22023';
  end if;

  perform private.check_operating_period(
    p_business_date,
    p_business_date,
    p_currency_code
  );

  p_external_batch_key := trim(p_external_batch_key);

  if p_external_batch_key is null
    or char_length(p_external_batch_key) not between 1 and 200
    or jsonb_typeof(p_rows) is distinct from 'array'
  then
    raise exception 'SALES_APP_IMPORT_INVALID'
      using errcode='22023';
  end if;

  if jsonb_array_length(p_rows) not between 1 and 5000 then
    raise exception 'SALES_APP_IMPORT_INVALID'
      using errcode='22023';
  end if;

  for v_row in
    select x.value
    from jsonb_array_elements(p_rows) as x(value)
  loop
    if jsonb_typeof(v_row) is distinct from 'object'
      or jsonb_typeof(v_row->'externalProductId') is distinct from 'string'
      or jsonb_typeof(v_row->'externalProductName') is distinct from 'string'
      or jsonb_typeof(v_row->'quantity') is distinct from 'number'
      or jsonb_typeof(v_row->'grossSales') is distinct from 'number'
      or jsonb_typeof(v_row->'netSales') is distinct from 'number'
      or (
        v_row ? 'externalProductCode'
        and jsonb_typeof(v_row->'externalProductCode')
          not in ('string','null')
      )
    then
      raise exception 'SALES_APP_ROW_INVALID'
        using errcode='22023';
    end if;

    ext := trim(v_row->>'externalProductId');
    nm := trim(v_row->>'externalProductName');
    code := nullif(trim(v_row->>'externalProductCode'),'');

    q := (v_row->>'quantity')::numeric;
    g := (v_row->>'grossSales')::numeric;
    n := (v_row->>'netSales')::numeric;

    if char_length(ext) not between 1 and 200
      or char_length(nm) not between 1 and 200
      or char_length(code) > 200
      or q < 0
      or q > 999999999999.9999
      or q <> round(q,4)
      or g < 0
      or g > 99999999999999.99
      or g <> round(g,2)
      or n < 0
      or n > 99999999999999.99
      or n <> round(n,2)
      or (q=0 and (g<>0 or n<>0))
    then
      raise exception 'SALES_APP_ROW_INVALID'
        using errcode='22023';
    end if;

    normalized := normalized || jsonb_build_array(
      jsonb_build_object(
        'externalProductId',ext,
        'externalProductCode',code,
        'externalProductName',nm,
        'quantity',q,
        'grossSales',g,
        'netSales',n
      )
    );
  end loop;

  if exists(
    select 1
    from jsonb_array_elements(normalized) as x(value)
    group by x.value->>'externalProductId'
    having count(*) > 1
  )
  then
    raise exception 'SALES_APP_DUPLICATE_PRODUCT'
      using errcode='22023';
  end if;

  select jsonb_agg(
    x.value
    order by x.value->>'externalProductId'
  )
  into normalized
  from jsonb_array_elements(normalized) as x(value);

  fingerprint := md5(
    jsonb_build_object(
      'date',p_business_date,
      'currency',p_currency_code,
      'rows',normalized
    )::text
  );

  perform 1
  from public.tenants
  where id=p_tenant_id
  for update;

  select *
  into b
  from public.sales_app_import_batches
  where tenant_id=p_tenant_id
    and provider_key='SALES_APP'
    and location_id=p_location_id
    and external_batch_key=p_external_batch_key;

  if found then
    if b.metadata->>'payloadFingerprint'
      is distinct from fingerprint
    then
      raise exception 'SALES_APP_BATCH_KEY_CONFLICT'
        using errcode='22023';
    end if;

    return b.id;
  end if;

  insert into public.sales_app_import_batches(
    tenant_id,
    location_id,
    business_date,
    currency_code,
    external_batch_key,
    status,
    row_count,
    created_by_user_id,
    metadata
  )
  values(
    p_tenant_id,
    p_location_id,
    p_business_date,
    p_currency_code,
    p_external_batch_key,
    'PROCESSING',
    jsonb_array_length(normalized),
    auth.uid(),
    jsonb_build_object(
      'payloadFingerprint',
      fingerprint
    )
  )
  returning id into v_id;

  for v_row in
    select x.value
    from jsonb_array_elements(normalized) as x(value)
  loop
    select *
    into m
    from public.sales_app_product_mappings
    where tenant_id=p_tenant_id
      and provider_key='SALES_APP'
      and external_product_id=v_row->>'externalProductId'
      and (
        location_id=p_location_id
        or location_id is null
      )
    order by location_id nulls last
    limit 1;

    if not found then
      insert into public.sales_app_product_mappings(
        tenant_id,
        location_id,
        external_product_id,
        external_product_code,
        external_product_name
      )
      values(
        p_tenant_id,
        p_location_id,
        v_row->>'externalProductId',
        v_row->>'externalProductCode',
        v_row->>'externalProductName'
      )
      returning * into m;
    end if;

    if m.status='MAPPED'
      and exists(
        select 1
        from public.menu_products
        where id=m.menu_product_id
          and tenant_id=p_tenant_id
          and currency_code<>p_currency_code
      )
    then
      raise exception 'SALES_APP_CURRENCY_MISMATCH'
        using errcode='22023';
    end if;

    insert into public.sales_app_import_rows(
      tenant_id,
      batch_id,
      external_product_id,
      external_product_code,
      external_product_name,
      quantity,
      gross_sales,
      net_sales,
      currency_code,
      mapping_status,
      menu_product_id
    )
    values(
      p_tenant_id,
      v_id,
      v_row->>'externalProductId',
      v_row->>'externalProductCode',
      v_row->>'externalProductName',
      (v_row->>'quantity')::numeric,
      (v_row->>'grossSales')::numeric,
      (v_row->>'netSales')::numeric,
      p_currency_code,
      m.status,
      m.menu_product_id
    );
  end loop;

  result := private.apply_sales_app_batch(v_id);

  update public.sales_app_import_batches
  set
    status='COMPLETED',
    mapped_row_count=(result->>'mappedRowCount')::int,
    unmapped_row_count=(result->>'unmappedRowCount')::int,
    metadata=metadata||result
  where id=v_id;

  insert into public.audit_logs(
    tenant_id,
    location_id,
    actor_user_id,
    action,
    entity_type,
    entity_id,
    metadata
  )
  values(
    p_tenant_id,
    p_location_id,
    auth.uid(),
    'SALES_APP_IMPORT_COMPLETED',
    'sales_app_import_batch',
    v_id,
    result
  );

  return v_id;
end;
$$;