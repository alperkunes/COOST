begin;

insert into auth.users(
  id,
  aud,
  role,
  email,
  created_at,
  updated_at
)
values(
  '29111111-1111-4111-8111-111111111111',
  'authenticated',
  'authenticated',
  'finance-shape@coost.test',
  now(),
  now()
);

insert into public.tenants(
  id,
  name,
  status
)
values(
  '29222222-2222-4222-8222-222222222222',
  'Finance Shape Test',
  'ACTIVE'
);

insert into public.finance_accounts(
  id,
  tenant_id,
  name,
  account_type,
  currency_code
)
values
(
  '29333333-3333-4333-8333-333333333331',
  '29222222-2222-4222-8222-222222222222',
  'TRY Bank',
  'BANK',
  'TRY'
),
(
  '29333333-3333-4333-8333-333333333332',
  '29222222-2222-4222-8222-222222222222',
  'TRY Cash',
  'CASH',
  'TRY'
),
(
  '29333333-3333-4333-8333-333333333333',
  '29222222-2222-4222-8222-222222222222',
  'USD Bank',
  'BANK',
  'USD'
);

do $$
declare
  t uuid := '29222222-2222-4222-8222-222222222222';
  u uuid := '29111111-1111-4111-8111-111111111111';
  try_bank uuid := '29333333-3333-4333-8333-333333333331';
  try_cash uuid := '29333333-3333-4333-8333-333333333332';
  usd_bank uuid := '29333333-3333-4333-8333-333333333333';
  tx uuid;
begin
  -- A transaction header may exist temporarily inside a transaction,
  -- but it must not survive the deferred commit-time check without entries.
  begin
    tx := '29444444-4444-4444-8444-444444444441';

    insert into public.finance_transactions(
      id,
      tenant_id,
      transaction_type,
      occurred_at,
      description,
      source_type,
      created_by_user_id
    )
    values(
      tx,
      t,
      'INCOME',
      now(),
      'Orphan header',
      'TEST',
      u
    );

    set constraints finance_transaction_shape_on_header immediate;

    raise exception 'ORPHAN_FINANCE_HEADER_ALLOWED';
  exception
    when check_violation then
      if sqlerrm <> 'FINANCE_INCOME_SHAPE_INVALID' then
        raise;
      end if;
  end;

  -- INCOME must contain exactly one positive entry.
  begin
    tx := '29444444-4444-4444-8444-444444444442';

    insert into public.finance_transactions(
      id, tenant_id, transaction_type, occurred_at,
      description, source_type, created_by_user_id
    )
    values(
      tx, t, 'INCOME', now(),
      'Negative income', 'TEST', u
    );

    insert into public.finance_entries(
      tenant_id,
      transaction_id,
      account_id,
      amount
    )
    values(
      t,
      tx,
      try_cash,
      -10
    );

    set constraints all immediate;

    raise exception 'NEGATIVE_INCOME_ALLOWED';
  exception
    when check_violation then
      if sqlerrm <> 'FINANCE_INCOME_SHAPE_INVALID' then
        raise;
      end if;
  end;

  -- EXPENSE must contain exactly one negative entry.
  begin
    tx := '29444444-4444-4444-8444-444444444443';

    insert into public.finance_transactions(
      id, tenant_id, transaction_type, occurred_at,
      description, source_type, created_by_user_id
    )
    values(
      tx, t, 'EXPENSE', now(),
      'Positive expense', 'TEST', u
    );

    insert into public.finance_entries(
      tenant_id,
      transaction_id,
      account_id,
      amount
    )
    values(
      t,
      tx,
      try_cash,
      10
    );

    set constraints all immediate;

    raise exception 'POSITIVE_EXPENSE_ALLOWED';
  exception
    when check_violation then
      if sqlerrm <> 'FINANCE_EXPENSE_SHAPE_INVALID' then
        raise;
      end if;
  end;

  -- ADJUSTMENT must contain exactly one entry.
  begin
    tx := '29444444-4444-4444-8444-444444444444';

    insert into public.finance_transactions(
      id, tenant_id, transaction_type, occurred_at,
      description, source_type, created_by_user_id
    )
    values(
      tx, t, 'ADJUSTMENT', now(),
      'Two-entry adjustment', 'TEST', u
    );

    insert into public.finance_entries(
      tenant_id,
      transaction_id,
      account_id,
      amount
    )
    values
      (t, tx, try_bank, 10),
      (t, tx, try_cash, -10);

    set constraints all immediate;

    raise exception 'MULTI_ENTRY_ADJUSTMENT_ALLOWED';
  exception
    when check_violation then
      if sqlerrm <> 'FINANCE_ADJUSTMENT_SHAPE_INVALID' then
        raise;
      end if;
  end;

  -- TRANSFER must contain two different accounts, one positive and one
  -- negative, sum to zero, and remain within a single currency.
  begin
    tx := '29444444-4444-4444-8444-444444444445';

    insert into public.finance_transactions(
      id, tenant_id, transaction_type, occurred_at,
      description, source_type, created_by_user_id
    )
    values(
      tx, t, 'TRANSFER', now(),
      'Unbalanced transfer', 'TEST', u
    );

    insert into public.finance_entries(
      tenant_id,
      transaction_id,
      account_id,
      amount
    )
    values
      (t, tx, try_bank, -10),
      (t, tx, try_cash, 9);

    set constraints all immediate;

    raise exception 'UNBALANCED_TRANSFER_ALLOWED';
  exception
    when check_violation then
      if sqlerrm <> 'FINANCE_TRANSFER_SHAPE_INVALID' then
        raise;
      end if;
  end;

  begin
    tx := '29444444-4444-4444-8444-444444444446';

    insert into public.finance_transactions(
      id, tenant_id, transaction_type, occurred_at,
      description, source_type, created_by_user_id
    )
    values(
      tx, t, 'TRANSFER', now(),
      'Cross-currency transfer', 'TEST', u
    );

    insert into public.finance_entries(
      tenant_id,
      transaction_id,
      account_id,
      amount
    )
    values
      (t, tx, try_bank, -10),
      (t, tx, usd_bank, 10);

    set constraints all immediate;

    raise exception 'CROSS_CURRENCY_TRANSFER_ALLOWED';
  exception
    when check_violation then
      if sqlerrm <> 'FINANCE_TRANSFER_SHAPE_INVALID' then
        raise;
      end if;
  end;

  -- Non-finite numeric values must be rejected at the entry constraint.
  begin
    tx := '29444444-4444-4444-8444-444444444447';

    insert into public.finance_transactions(
      id, tenant_id, transaction_type, occurred_at,
      description, source_type, created_by_user_id
    )
    values(
      tx, t, 'ADJUSTMENT', now(),
      'NaN adjustment', 'TEST', u
    );

    insert into public.finance_entries(
      tenant_id,
      transaction_id,
      account_id,
      amount
    )
    values(
      t,
      tx,
      try_cash,
      'NaN'::numeric
    );

    raise exception 'NAN_FINANCE_ENTRY_ALLOWED';
  exception
    when check_violation then
      null;
  end;

  -- A valid balanced transfer remains allowed.
  tx := '29444444-4444-4444-8444-444444444448';

  insert into public.finance_transactions(
    id, tenant_id, transaction_type, occurred_at,
    description, source_type, created_by_user_id
  )
  values(
    tx, t, 'TRANSFER', now(),
    'Valid transfer', 'TEST', u
  );

  insert into public.finance_entries(
    tenant_id,
    transaction_id,
    account_id,
    amount
  )
  values
    (t, tx, try_bank, -25),
    (t, tx, try_cash, 25);

  set constraints all immediate;

  if (
    select count(*)
    from public.finance_entries
    where tenant_id = t
      and transaction_id = tx
  ) <> 2 then
    raise exception 'VALID_TRANSFER_ENTRY_COUNT_WRONG';
  end if;
end
$$;

rollback;

do $$
begin
  if exists(
    select 1
    from auth.users
    where id = '29111111-1111-4111-8111-111111111111'
  )
  or exists(
    select 1
    from public.tenants
    where id = '29222222-2222-4222-8222-222222222222'
  ) then
    raise exception 'FINANCE_SHAPE_TEST_ROLLBACK_RESIDUALS';
  end if;
end
$$;

select 'PASS - FINANCE TRANSACTION SHAPE INVARIANTS' as result;
