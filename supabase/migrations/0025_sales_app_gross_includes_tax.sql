-- Support sales sources that provide only a realized, tax-inclusive sales amount.
-- Existing integrations keep their current PROVIDED_NET behavior.
-- GROSS_INCLUDES_TAX derives accounting net sales from the mapped COOST menu
-- product's sales_tax_rate when the batch is applied/reprocessed.

alter table public.sales_app_import_batches
  add column sales_amount_mode text not null default 'PROVIDED_NET'
  check (
    sales_amount_mode in (
      'PROVIDED_NET',
      'GROSS_INCLUDES_TAX'
    )
  );

comment on column public.sales_app_import_batches.sales_amount_mode is
  'PROVIDED_NET uses provider net_sales as supplied. GROSS_INCLUDES_TAX treats gross_sales as realized tax-inclusive sales and derives net_sales from the mapped menu product sales_tax_rate.';

create or replace function private.apply_sales_app_batch(
  p_batch_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  b public.sales_app_import_batches%rowtype;
  v_row record;
  old public.menu_product_sales_facts%rowtype;
  v_id uuid;
  n int := 0;
begin
  select *
  into strict b
  from public.sales_app_import_batches
  where id=p_batch_id;

  -- Serialize import/reprocess with menu product edits.
  perform 1
  from public.menu_products
  where tenant_id=b.tenant_id
  order by id
  for update;

  if exists(
    select 1
    from private.sales_app_resolved_rows(b.id) as resolved
    join public.menu_products p
      on p.id=resolved.product_id
     and p.tenant_id=b.tenant_id
    where resolved.mapping_status='MAPPED'
      and p.currency_code<>b.currency_code
  )
  then
    raise exception 'SALES_APP_CURRENCY_MISMATCH'
      using errcode='22023';
  end if;

  for v_row in
    with grouped_raw as (
      select
        resolved.product_id,
        sum(resolved.quantity) as quantity,
        sum(resolved.gross) as gross,
        sum(resolved.net) as provided_net,
        p.sales_tax_rate
      from private.sales_app_resolved_rows(b.id) as resolved
      join public.menu_products p
        on p.id=resolved.product_id
       and p.tenant_id=b.tenant_id
      where resolved.mapping_status='MAPPED'
      group by
        resolved.product_id,
        p.sales_tax_rate
    ),
    grouped as (
      select
        g.product_id,
        g.quantity,
        g.gross,
        case
          when b.sales_amount_mode='GROSS_INCLUDES_TAX'
          then round(
            g.gross /
            (1 + g.sales_tax_rate / 100),
            2
          )
          else g.provided_net
        end as net
      from grouped_raw g
    ),
    desired as (
      select
        g.product_id,
        g.quantity,
        g.gross,
        g.net
      from grouped g

      union all

      select
        f.menu_product_id,
        0::numeric as quantity,
        0::numeric as gross,
        0::numeric as net
      from public.menu_product_sales_facts f
      where f.tenant_id=b.tenant_id
        and f.location_id=b.location_id
        and f.sale_date=b.business_date
        and f.currency_code=b.currency_code
        and f.source_type='SALES_APP'
        and not exists(
          select 1
          from grouped g
          where g.product_id=f.menu_product_id
        )
    )
    select *
    from desired
    order by product_id
  loop
    if v_row.quantity > 999999999999.9999
      or v_row.gross > 99999999999999.99
      or v_row.net > 99999999999999.99
    then
      raise exception 'SALES_APP_TOTAL_OVERFLOW'
        using errcode='22023';
    end if;

    old := null;

    select *
    into old
    from public.menu_product_sales_facts
    where tenant_id=b.tenant_id
      and location_id=b.location_id
      and sale_date=b.business_date
      and menu_product_id=v_row.product_id
      and currency_code=b.currency_code
    for update;

    if old.id is not null
      and (
        old.quantity,
        old.gross_sales,
        old.net_sales,
        old.source_type
      )
      is not distinct from (
        v_row.quantity,
        v_row.gross,
        v_row.net,
        'SALES_APP'::text
      )
    then
      continue;
    end if;

    insert into public.menu_product_sales_facts(
      tenant_id,
      location_id,
      sale_date,
      menu_product_id,
      currency_code,
      quantity,
      gross_sales,
      net_sales,
      source_type
    )
    values(
      b.tenant_id,
      b.location_id,
      b.business_date,
      v_row.product_id,
      b.currency_code,
      v_row.quantity,
      v_row.gross,
      v_row.net,
      'SALES_APP'
    )
    on conflict(
      tenant_id,
      location_id,
      sale_date,
      menu_product_id,
      currency_code
    )
    do update
    set
      quantity=excluded.quantity,
      gross_sales=excluded.gross_sales,
      net_sales=excluded.net_sales,
      source_type='SALES_APP',
      updated_at=now()
    returning id into v_id;

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
      b.tenant_id,
      b.location_id,
      auth.uid(),
      'SALES_APP_FACT_REPLACED',
      'menu_product_sales_fact',
      v_id,
      jsonb_build_object(
        'batchId',b.id,
        'salesAmountMode',b.sales_amount_mode,
        'previousSourceType',old.source_type,
        'newSourceType','SALES_APP',
        'old',
          case
            when old.id is null then null
            else to_jsonb(old)
          end,
        'new',
          jsonb_build_object(
            'quantity',v_row.quantity,
            'grossSales',v_row.gross,
            'netSales',v_row.net
          )
      )
    );

    n := n + 1;
  end loop;

  return jsonb_build_object(
    'businessDate',b.business_date,
    'externalBatchKey',b.external_batch_key,
    'salesAmountMode',b.sales_amount_mode,
    'rowCount',b.row_count,
    'mappedRowCount',
      (
        select count(*)
        from private.sales_app_resolved_rows(b.id) as resolved
        where resolved.mapping_status='MAPPED'
      ),
    'unmappedRowCount',
      (
        select count(*)
        from private.sales_app_resolved_rows(b.id) as resolved
        where resolved.mapping_status='UNMAPPED'
      ),
    'salesFactCount',
      (
        select count(distinct resolved.product_id)
        from private.sales_app_resolved_rows(b.id) as resolved
        where resolved.mapping_status='MAPPED'
      ),
    'changedFactCount',n
  );
end;
$$;


create function public.import_sales_app_daily_gross_sales(
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
    code := nullif(
      trim(v_row->>'externalProductCode'),
      ''
    );

    q := (v_row->>'quantity')::numeric;
    g := (v_row->>'grossSales')::numeric;

    if char_length(ext) not between 1 and 200
      or char_length(nm) not between 1 and 200
      or char_length(code) > 200
      or q < 0
      or q > 999999999999.9999
      or q <> round(q,4)
      or g < 0
      or g > 99999999999999.99
      or g <> round(g,2)
      or (q=0 and g<>0)
    then
      raise exception 'SALES_APP_ROW_INVALID'
        using errcode='22023';
    end if;

    -- netSales is intentionally carried as the gross amount in the immutable
    -- import row. For GROSS_INCLUDES_TAX batches it is NOT used when sales
    -- facts are applied. The mapped menu product tax rate derives net sales.
    normalized := normalized || jsonb_build_array(
      jsonb_build_object(
        'externalProductId',ext,
        'externalProductCode',code,
        'externalProductName',nm,
        'quantity',q,
        'grossSales',g,
        'netSales',g
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
      'salesAmountMode','GROSS_INCLUDES_TAX',
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
    if b.sales_amount_mode <> 'GROSS_INCLUDES_TAX'
      or b.metadata->>'payloadFingerprint'
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
    sales_amount_mode,
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
    'GROSS_INCLUDES_TAX',
    'PROCESSING',
    jsonb_array_length(normalized),
    auth.uid(),
    jsonb_build_object(
      'payloadFingerprint',fingerprint,
      'salesAmountMode','GROSS_INCLUDES_TAX'
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
      (v_row->>'grossSales')::numeric,
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

revoke all
on function public.import_sales_app_daily_gross_sales(
  uuid,
  uuid,
  date,
  text,
  text,
  jsonb
)
from public,anon;

grant execute
on function public.import_sales_app_daily_gross_sales(
  uuid,
  uuid,
  date,
  text,
  text,
  jsonb
)
to authenticated,service_role;
