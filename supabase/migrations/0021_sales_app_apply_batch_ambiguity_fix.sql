-- Fix PL/pgSQL record / SQL alias ambiguity in Sales App batch application.
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
    with grouped as (
      select
        resolved.product_id,
        sum(resolved.quantity) as quantity,
        sum(resolved.gross) as gross,
        sum(resolved.net) as net
      from private.sales_app_resolved_rows(b.id) as resolved
      where resolved.mapping_status='MAPPED'
      group by resolved.product_id
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