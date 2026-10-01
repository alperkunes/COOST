begin;

insert into auth.users(
  id, aud, role, email, created_at, updated_at
)
values(
  '30111111-1111-4111-8111-111111111111',
  'authenticated',
  'authenticated',
  'purchase-inventory-invariants@coost.test',
  now(),
  now()
);

insert into public.tenants(id,name,status)
values(
  '30222222-2222-4222-8222-222222222222',
  'Purchase Inventory Invariant Test',
  'ACTIVE'
);

insert into public.locations(id,tenant_id,name,status)
values(
  '30444444-4444-4444-8444-444444444444',
  '30222222-2222-4222-8222-222222222222',
  'Main',
  'ACTIVE'
);

insert into public.suppliers(id,tenant_id,name)
values(
  '30333333-3333-4333-8333-333333333333',
  '30222222-2222-4222-8222-222222222222',
  'Invariant Supplier'
);

insert into public.inventory_items(id,tenant_id,name,base_unit)
values(
  '30555555-5555-4555-8555-555555555555',
  '30222222-2222-4222-8222-222222222222',
  'Invariant Ingredient',
  'GRAM'
);

insert into public.inventory_purchase_units(
  id, tenant_id, inventory_item_id, name, conversion_to_base
)
values(
  '30666666-6666-4666-8666-666666666666',
  '30222222-2222-4222-8222-222222222222',
  '30555555-5555-4555-8555-555555555555',
  'KG',
  1000
);


create function pg_temp.seed_invoice(
  p_invoice_id uuid,
  p_line_id uuid,
  p_number text
)
returns void
language plpgsql
as $$
begin
  insert into public.purchase_invoices(
    id, tenant_id, supplier_id, location_id, invoice_number, invoice_date,
    currency_code, subtotal, tax_total, grand_total, created_by_user_id
  )
  values(
    p_invoice_id,
    '30222222-2222-4222-8222-222222222222',
    '30333333-3333-4333-8333-333333333333',
    '30444444-4444-4444-8444-444444444444',
    p_number,
    '2026-10-01',
    'TRY',
    20,
    4,
    24,
    '30111111-1111-4111-8111-111111111111'
  );

  insert into public.purchase_invoice_lines(
    id, tenant_id, purchase_invoice_id, line_no, description, unit,
    quantity, unit_price, price_includes_tax, tax_rate, net_amount,
    tax_amount, gross_amount, inventory_item_id, inventory_tracking,
    inventory_purchase_unit_id
  )
  values(
    p_line_id,
    '30222222-2222-4222-8222-222222222222',
    p_invoice_id,
    1,
    'Invariant ingredient',
    'KG',
    2,
    10,
    false,
    20,
    20,
    4,
    24,
    '30555555-5555-4555-8555-555555555555',
    'MAPPED',
    '30666666-6666-4666-8666-666666666666'
  );
end;
$$;


-- DRAFT -> POSTED cannot become durable without both supplier debt and receipt.
do $$
begin
  begin
    perform pg_temp.seed_invoice(
      '30777777-7777-4777-8777-777777777771',
      '30888888-8888-4888-8888-888888888881',
      'INV-MISSING'
    );

    update public.purchase_invoices
    set status = 'POSTED',
        posted_at = now(),
        posted_by_user_id = '30111111-1111-4111-8111-111111111111'
    where id = '30777777-7777-4777-8777-777777777771';

    set constraints purchase_invoice_shape_on_header immediate;
    raise exception 'PURCHASE_POST_WITHOUT_EFFECTS_ALLOWED';
  exception
    when check_violation then
      if sqlerrm <> 'PURCHASE_INVOICE_LEDGER_INVALID' then
        raise;
      end if;
  end;

  set constraints all deferred;
end
$$;


-- Keep a legitimate draft to prove orphan purchase effects cannot be attached
-- to an unposted invoice.
select pg_temp.seed_invoice(
  '30777777-7777-4777-8777-777777777772',
  '30888888-8888-4888-8888-888888888882',
  'INV-DRAFT-SOURCE'
);

do $$
begin
  begin
    insert into public.supplier_ledger_entries(
      tenant_id, supplier_id, entry_type, currency_code, amount, occurred_at,
      description, source_type, source_id, created_by_user_id
    )
    values(
      '30222222-2222-4222-8222-222222222222',
      '30333333-3333-4333-8333-333333333333',
      'INVOICE',
      'TRY',
      24,
      now(),
      'Invalid draft invoice debt',
      'PURCHASE_INVOICE',
      '30777777-7777-4777-8777-777777777772',
      '30111111-1111-4111-8111-111111111111'
    );

    set constraints purchase_invoice_shape_on_supplier_ledger immediate;
    raise exception 'DRAFT_PURCHASE_LEDGER_ALLOWED';
  exception
    when check_violation then
      if sqlerrm <> 'PURCHASE_LEDGER_SOURCE_INVALID' then
        raise;
      end if;
  end;

  set constraints all deferred;
end
$$;


do $$
begin
  begin
    insert into public.inventory_movements(
      tenant_id, location_id, inventory_item_id, movement_type, quantity,
      occurred_at, description, source_type, source_id, source_line_id,
      created_by_user_id
    )
    values(
      '30222222-2222-4222-8222-222222222222',
      '30444444-4444-4444-8444-444444444444',
      '30555555-5555-4555-8555-555555555555',
      'RECEIPT',
      2000,
      now(),
      'Invalid draft invoice receipt',
      'PURCHASE_INVOICE',
      '30777777-7777-4777-8777-777777777772',
      '30888888-8888-4888-8888-888888888882',
      '30111111-1111-4111-8111-111111111111'
    );

    set constraints purchase_invoice_shape_on_receipt immediate;
    raise exception 'DRAFT_PURCHASE_RECEIPT_ALLOWED';
  exception
    when check_violation then
      if sqlerrm <> 'PURCHASE_RECEIPT_SOURCE_INVALID' then
        raise;
      end if;
  end;

  set constraints all deferred;
end
$$;


-- A complete-looking direct post with the wrong base-unit quantity is rejected.
do $$
begin
  begin
    perform pg_temp.seed_invoice(
      '30777777-7777-4777-8777-777777777773',
      '30888888-8888-4888-8888-888888888883',
      'INV-WRONG-QTY'
    );

    insert into public.supplier_ledger_entries(
      tenant_id, supplier_id, entry_type, currency_code, amount, occurred_at,
      description, source_type, source_id, created_by_user_id
    )
    values(
      '30222222-2222-4222-8222-222222222222',
      '30333333-3333-4333-8333-333333333333',
      'INVOICE',
      'TRY',
      24,
      now(),
      'Wrong quantity invoice debt',
      'PURCHASE_INVOICE',
      '30777777-7777-4777-8777-777777777773',
      '30111111-1111-4111-8111-111111111111'
    );

    insert into public.inventory_movements(
      tenant_id, location_id, inventory_item_id, movement_type, quantity,
      occurred_at, description, source_type, source_id, source_line_id,
      created_by_user_id
    )
    values(
      '30222222-2222-4222-8222-222222222222',
      '30444444-4444-4444-8444-444444444444',
      '30555555-5555-4555-8555-555555555555',
      'RECEIPT',
      1999,
      now(),
      'Wrong quantity invoice receipt',
      'PURCHASE_INVOICE',
      '30777777-7777-4777-8777-777777777773',
      '30888888-8888-4888-8888-888888888883',
      '30111111-1111-4111-8111-111111111111'
    );

    update public.purchase_invoices
    set status = 'POSTED',
        posted_at = now(),
        posted_by_user_id = '30111111-1111-4111-8111-111111111111'
    where id = '30777777-7777-4777-8777-777777777773';

    set constraints all immediate;
    raise exception 'WRONG_PURCHASE_RECEIPT_QUANTITY_ALLOWED';
  exception
    when check_violation then
      if sqlerrm not in (
        'PURCHASE_INVOICE_RECEIPT_INVALID',
        'PURCHASE_RECEIPT_QUANTITY_INVALID'
      ) then
        raise;
      end if;
  end;

  set constraints all deferred;
end
$$;


-- A complete atomic shape is accepted.
select pg_temp.seed_invoice(
  '30777777-7777-4777-8777-777777777774',
  '30888888-8888-4888-8888-888888888884',
  'INV-VALID'
);

insert into public.supplier_ledger_entries(
  tenant_id, supplier_id, entry_type, currency_code, amount, occurred_at,
  description, source_type, source_id, created_by_user_id
)
values(
  '30222222-2222-4222-8222-222222222222',
  '30333333-3333-4333-8333-333333333333',
  'INVOICE',
  'TRY',
  24,
  now(),
  'Valid invoice debt',
  'PURCHASE_INVOICE',
  '30777777-7777-4777-8777-777777777774',
  '30111111-1111-4111-8111-111111111111'
);

insert into public.inventory_movements(
  tenant_id, location_id, inventory_item_id, movement_type, quantity,
  occurred_at, description, source_type, source_id, source_line_id,
  created_by_user_id
)
values(
  '30222222-2222-4222-8222-222222222222',
  '30444444-4444-4444-8444-444444444444',
  '30555555-5555-4555-8555-555555555555',
  'RECEIPT',
  2000,
  now(),
  'Valid invoice receipt',
  'PURCHASE_INVOICE',
  '30777777-7777-4777-8777-777777777774',
  '30888888-8888-4888-8888-888888888884',
  '30111111-1111-4111-8111-111111111111'
);

update public.purchase_invoices
set status = 'POSTED',
    posted_at = now(),
    posted_by_user_id = '30111111-1111-4111-8111-111111111111'
where id = '30777777-7777-4777-8777-777777777774';

set constraints all immediate;


do $$
begin
  if (
    select count(*)
    from public.inventory_movements
    where tenant_id = '30222222-2222-4222-8222-222222222222'
      and source_type = 'PURCHASE_INVOICE'
      and source_id = '30777777-7777-4777-8777-777777777774'
  ) <> 1 then
    raise exception 'VALID_PURCHASE_RECEIPT_COUNT_WRONG';
  end if;

  if (
    select count(*)
    from public.supplier_ledger_entries
    where tenant_id = '30222222-2222-4222-8222-222222222222'
      and source_type = 'PURCHASE_INVOICE'
      and source_id = '30777777-7777-4777-8777-777777777774'
  ) <> 1 then
    raise exception 'VALID_PURCHASE_LEDGER_COUNT_WRONG';
  end if;
end
$$;


-- source_line_id belongs only to purchase-invoice receipt provenance.
do $$
begin
  begin
    insert into public.inventory_movements(
      tenant_id, location_id, inventory_item_id, movement_type, quantity,
      occurred_at, description, source_type, source_line_id, created_by_user_id
    )
    values(
      '30222222-2222-4222-8222-222222222222',
      '30444444-4444-4444-8444-444444444444',
      '30555555-5555-4555-8555-555555555555',
      'RECEIPT',
      1,
      now(),
      'Invalid source-line scope',
      'MANUAL',
      '30888888-8888-4888-8888-888888888884',
      '30111111-1111-4111-8111-111111111111'
    );

    raise exception 'NON_PURCHASE_SOURCE_LINE_ALLOWED';
  exception
    when check_violation then
      null;
  end;
end
$$;


create function pg_temp.expect_history_guard(p_command text)
returns void
language plpgsql
as $$
begin
  execute p_command;
  raise exception 'HISTORY_TRUNCATE_ALLOWED: %', p_command;
exception
  when sqlstate '55000' then
    if sqlerrm <> 'PURCHASE_INVENTORY_HISTORY_IMMUTABLE' then
      raise;
    end if;
end;
$$;

select pg_temp.expect_history_guard(
  'truncate table public.purchase_invoices cascade'
);
select pg_temp.expect_history_guard(
  'truncate table public.inventory_movements'
);
select pg_temp.expect_history_guard(
  'truncate table public.inventory_purchase_units cascade'
);
select pg_temp.expect_history_guard(
  'truncate table public.supplier_ledger_entries'
);


rollback;


do $$
begin
  if exists(
    select 1
    from auth.users
    where id = '30111111-1111-4111-8111-111111111111'
  )
  or exists(
    select 1
    from public.tenants
    where id = '30222222-2222-4222-8222-222222222222'
  ) then
    raise exception 'PURCHASE_INVENTORY_INVARIANT_TEST_RESIDUALS';
  end if;
end
$$;


select 'PASS - PURCHASE INVENTORY INVARIANTS' as result;
