-- COOST purchase -> supplier ledger -> inventory receipt integrity.
--
-- Posting is atomic at the RPC layer. These deferred constraints also protect
-- the database when a privileged backend writes the underlying tables directly.

alter table public.inventory_movements
  add constraint inventory_source_line_scope_check
  check (
    source_line_id is null
    or source_type = 'PURCHASE_INVOICE'
  ) not valid;

alter table public.inventory_movements
  validate constraint inventory_source_line_scope_check;


create function private.validate_purchase_invoice_posting_shape(
  p_tenant_id uuid,
  p_invoice_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  inv public.purchase_invoices%rowtype;
  calc jsonb;
  line record;
  expected_quantity numeric;
  line_count integer;
  ledger_count integer;
  ledger_match_count integer;
  receipt_count integer;
  receipt_match_count integer;
begin
  select *
  into inv
  from public.purchase_invoices
  where id = p_invoice_id
    and tenant_id = p_tenant_id;

  if not found then
    raise exception 'PURCHASE_INVOICE_NOT_FOUND'
      using errcode = '23514';
  end if;

  -- Drafts deliberately have no supplier-ledger or inventory effect.
  if inv.status = 'DRAFT' then
    return;
  end if;

  if inv.status <> 'POSTED' then
    raise exception 'PURCHASE_INVOICE_SHAPE_INVALID'
      using errcode = '23514';
  end if;

  select count(*)::integer
  into line_count
  from public.purchase_invoice_lines
  where tenant_id = p_tenant_id
    and purchase_invoice_id = p_invoice_id;

  if line_count < 1 then
    raise exception 'PURCHASE_INVOICE_LINES_INVALID'
      using errcode = '23514';
  end if;

  if exists (
    select 1
    from public.purchase_invoice_lines
    where tenant_id = p_tenant_id
      and purchase_invoice_id = p_invoice_id
      and inventory_tracking = 'UNMAPPED'
  ) then
    raise exception 'PURCHASE_INVOICE_UNMAPPED_LINES'
      using errcode = '23514';
  end if;

  if inv.location_id is null
     and exists (
       select 1
       from public.purchase_invoice_lines
       where tenant_id = p_tenant_id
         and purchase_invoice_id = p_invoice_id
         and inventory_tracking = 'MAPPED'
     ) then
    raise exception 'PURCHASE_INVOICE_LOCATION_INVALID'
      using errcode = '23514';
  end if;

  calc := private.calculate_purchase_lines(
    private.purchase_line_data(p_invoice_id)
  );

  if (inv.subtotal, inv.tax_total, inv.grand_total)
     is distinct from (
       (calc->>'subtotal')::numeric,
       (calc->>'taxTotal')::numeric,
       (calc->>'grandTotal')::numeric
     ) then
    raise exception 'PURCHASE_INVOICE_TOTALS_INVALID'
      using errcode = '23514';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(calc->'lines') j
    join public.purchase_invoice_lines pl
      on pl.tenant_id = p_tenant_id
     and pl.purchase_invoice_id = p_invoice_id
     and pl.line_no = (j->>'lineNo')::integer
    where (pl.net_amount, pl.tax_amount, pl.gross_amount)
      is distinct from (
        (j->>'netAmount')::numeric,
        (j->>'taxAmount')::numeric,
        (j->>'grossAmount')::numeric
      )
  ) then
    raise exception 'PURCHASE_INVOICE_LINE_TOTALS_INVALID'
      using errcode = '23514';
  end if;

  select
    count(*)::integer,
    count(*) filter (
      where sle.entry_type = 'INVOICE'
        and sle.supplier_id = inv.supplier_id
        and sle.currency_code = inv.currency_code
        and sle.amount = inv.grand_total
    )::integer
  into ledger_count, ledger_match_count
  from public.supplier_ledger_entries sle
  where sle.tenant_id = p_tenant_id
    and sle.source_type = 'PURCHASE_INVOICE'
    and sle.source_id = p_invoice_id;

  if ledger_count <> 1 or ledger_match_count <> 1 then
    raise exception 'PURCHASE_INVOICE_LEDGER_INVALID'
      using errcode = '23514';
  end if;

  for line in
    select
      pl.id,
      pl.inventory_tracking,
      pl.inventory_item_id,
      pl.inventory_purchase_unit_id,
      pl.quantity,
      u.conversion_to_base,
      u.status as purchase_unit_status,
      i.status as inventory_item_status
    from public.purchase_invoice_lines pl
    left join public.inventory_purchase_units u
      on u.id = pl.inventory_purchase_unit_id
     and u.inventory_item_id = pl.inventory_item_id
     and u.tenant_id = pl.tenant_id
    left join public.inventory_items i
      on i.id = pl.inventory_item_id
     and i.tenant_id = pl.tenant_id
    where pl.tenant_id = p_tenant_id
      and pl.purchase_invoice_id = p_invoice_id
    order by pl.line_no
  loop
    select count(*)::integer
    into receipt_count
    from public.inventory_movements m
    where m.tenant_id = p_tenant_id
      and m.source_type = 'PURCHASE_INVOICE'
      and m.source_id = p_invoice_id
      and m.source_line_id = line.id;

    if line.inventory_tracking = 'NON_STOCK' then
      if receipt_count <> 0 then
        raise exception 'PURCHASE_INVOICE_RECEIPT_INVALID'
          using errcode = '23514';
      end if;

      continue;
    end if;

    if line.inventory_tracking <> 'MAPPED'
       or line.inventory_item_id is null
       or line.inventory_purchase_unit_id is null
       or line.conversion_to_base is null
       or line.purchase_unit_status <> 'ACTIVE'
       or line.inventory_item_status <> 'ACTIVE' then
      raise exception 'PURCHASE_INVOICE_MAPPING_INVALID'
        using errcode = '23514';
    end if;

    expected_quantity := private.purchase_inventory_quantity(
      line.quantity,
      line.conversion_to_base
    );

    select
      count(*)::integer,
      count(*) filter (
        where m.inventory_item_id = line.inventory_item_id
          and m.location_id = inv.location_id
          and m.movement_type = 'RECEIPT'
          and m.quantity = expected_quantity
      )::integer
    into receipt_count, receipt_match_count
    from public.inventory_movements m
    where m.tenant_id = p_tenant_id
      and m.source_type = 'PURCHASE_INVOICE'
      and m.source_id = p_invoice_id
      and m.source_line_id = line.id;

    if receipt_count <> 1 or receipt_match_count <> 1 then
      raise exception 'PURCHASE_INVOICE_RECEIPT_INVALID'
        using errcode = '23514';
    end if;
  end loop;
end;
$$;

revoke all
  on function private.validate_purchase_invoice_posting_shape(uuid,uuid)
  from public, anon, authenticated;


create function private.validate_purchase_receipt_shape(
  p_movement_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  m public.inventory_movements%rowtype;
  inv public.purchase_invoices%rowtype;
  pl public.purchase_invoice_lines%rowtype;
  unit_row public.inventory_purchase_units%rowtype;
  item_row public.inventory_items%rowtype;
  expected_quantity numeric;
begin
  select *
  into m
  from public.inventory_movements
  where id = p_movement_id;

  if not found then
    raise exception 'PURCHASE_RECEIPT_NOT_FOUND'
      using errcode = '23514';
  end if;

  if m.source_type is distinct from 'PURCHASE_INVOICE' then
    return;
  end if;

  select *
  into pl
  from public.purchase_invoice_lines
  where id = m.source_line_id
    and purchase_invoice_id = m.source_id
    and tenant_id = m.tenant_id;

  if not found or pl.inventory_tracking <> 'MAPPED' then
    raise exception 'PURCHASE_RECEIPT_SOURCE_INVALID'
      using errcode = '23514';
  end if;

  select *
  into inv
  from public.purchase_invoices
  where id = pl.purchase_invoice_id
    and tenant_id = pl.tenant_id;

  if not found
     or inv.status <> 'POSTED'
     or inv.location_id is null
     or m.location_id <> inv.location_id
     or m.inventory_item_id <> pl.inventory_item_id
     or m.movement_type <> 'RECEIPT'
     or m.quantity <= 0 then
    raise exception 'PURCHASE_RECEIPT_SOURCE_INVALID'
      using errcode = '23514';
  end if;

  select *
  into unit_row
  from public.inventory_purchase_units
  where id = pl.inventory_purchase_unit_id
    and inventory_item_id = pl.inventory_item_id
    and tenant_id = pl.tenant_id;

  select *
  into item_row
  from public.inventory_items
  where id = pl.inventory_item_id
    and tenant_id = pl.tenant_id;

  if unit_row.id is null
     or item_row.id is null
     or unit_row.status <> 'ACTIVE'
     or item_row.status <> 'ACTIVE' then
    raise exception 'PURCHASE_RECEIPT_SOURCE_INVALID'
      using errcode = '23514';
  end if;

  expected_quantity := private.purchase_inventory_quantity(
    pl.quantity,
    unit_row.conversion_to_base
  );

  if m.quantity <> expected_quantity then
    raise exception 'PURCHASE_RECEIPT_QUANTITY_INVALID'
      using errcode = '23514';
  end if;
end;
$$;

revoke all
  on function private.validate_purchase_receipt_shape(uuid)
  from public, anon, authenticated;


create function private.validate_purchase_supplier_ledger_shape(
  p_ledger_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  sle public.supplier_ledger_entries%rowtype;
  inv public.purchase_invoices%rowtype;
begin
  select *
  into sle
  from public.supplier_ledger_entries
  where id = p_ledger_id;

  if not found then
    raise exception 'PURCHASE_LEDGER_ENTRY_NOT_FOUND'
      using errcode = '23514';
  end if;

  if sle.source_type is distinct from 'PURCHASE_INVOICE' then
    return;
  end if;

  if sle.source_id is null then
    raise exception 'PURCHASE_LEDGER_SOURCE_INVALID'
      using errcode = '23514';
  end if;

  select *
  into inv
  from public.purchase_invoices
  where id = sle.source_id
    and tenant_id = sle.tenant_id;

  if not found
     or inv.status <> 'POSTED'
     or sle.entry_type <> 'INVOICE'
     or sle.supplier_id <> inv.supplier_id
     or sle.currency_code <> inv.currency_code
     or sle.amount <> inv.grand_total then
    raise exception 'PURCHASE_LEDGER_SOURCE_INVALID'
      using errcode = '23514';
  end if;
end;
$$;

revoke all
  on function private.validate_purchase_supplier_ledger_shape(uuid)
  from public, anon, authenticated;


create function private.enforce_purchase_invoice_posting_shape()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.validate_purchase_invoice_posting_shape(
    new.tenant_id,
    new.id
  );
  return null;
end;
$$;

revoke all
  on function private.enforce_purchase_invoice_posting_shape()
  from public, anon, authenticated;


create function private.enforce_purchase_receipt_shape()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.validate_purchase_receipt_shape(new.id);
  return null;
end;
$$;

revoke all
  on function private.enforce_purchase_receipt_shape()
  from public, anon, authenticated;


create function private.enforce_purchase_supplier_ledger_shape()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.validate_purchase_supplier_ledger_shape(new.id);
  return null;
end;
$$;

revoke all
  on function private.enforce_purchase_supplier_ledger_shape()
  from public, anon, authenticated;


create constraint trigger purchase_invoice_shape_on_header
after insert or update on public.purchase_invoices
deferrable initially deferred
for each row
execute function private.enforce_purchase_invoice_posting_shape();

create constraint trigger purchase_invoice_shape_on_receipt
after insert on public.inventory_movements
deferrable initially deferred
for each row
execute function private.enforce_purchase_receipt_shape();

create constraint trigger purchase_invoice_shape_on_supplier_ledger
after insert on public.supplier_ledger_entries
deferrable initially deferred
for each row
execute function private.enforce_purchase_supplier_ledger_shape();


create function private.reject_purchase_inventory_history_truncate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception 'PURCHASE_INVENTORY_HISTORY_IMMUTABLE'
    using errcode = '55000';
end;
$$;

revoke all
  on function private.reject_purchase_inventory_history_truncate()
  from public, anon, authenticated;


create trigger purchase_invoices_no_truncate
before truncate on public.purchase_invoices
for each statement
execute function private.reject_purchase_inventory_history_truncate();

create trigger purchase_invoice_lines_no_truncate
before truncate on public.purchase_invoice_lines
for each statement
execute function private.reject_purchase_inventory_history_truncate();

create trigger inventory_items_no_truncate
before truncate on public.inventory_items
for each statement
execute function private.reject_purchase_inventory_history_truncate();

create trigger inventory_movements_no_truncate
before truncate on public.inventory_movements
for each statement
execute function private.reject_purchase_inventory_history_truncate();

create trigger inventory_counts_no_truncate
before truncate on public.inventory_counts
for each statement
execute function private.reject_purchase_inventory_history_truncate();

create trigger inventory_count_lines_no_truncate
before truncate on public.inventory_count_lines
for each statement
execute function private.reject_purchase_inventory_history_truncate();

create trigger inventory_purchase_units_no_truncate
before truncate on public.inventory_purchase_units
for each statement
execute function private.reject_purchase_inventory_history_truncate();

create trigger supplier_ledger_purchase_no_truncate
before truncate on public.supplier_ledger_entries
for each statement
execute function private.reject_purchase_inventory_history_truncate();


comment on function private.validate_purchase_invoice_posting_shape(uuid,uuid)
  is 'Deferred structural validator for posted purchase invoices, supplier debt and inventory receipts.';

comment on function private.validate_purchase_receipt_shape(uuid)
  is 'Deferred validator for purchase-origin inventory receipts.';

comment on function private.validate_purchase_supplier_ledger_shape(uuid)
  is 'Deferred validator for purchase-origin supplier ledger entries.';
