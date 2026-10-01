begin;

insert into auth.users (
  id, aud, role, email, created_at, updated_at
)
values (
  '27111111-1111-4111-8111-111111111111',
  'authenticated',
  'authenticated',
  'finance-ledger-immutability@coost.test',
  now(),
  now()
);

insert into public.tenants (
  id, name, status
)
values (
  '27222222-2222-4222-8222-222222222222',
  'Finance Ledger Immutability Test',
  'ACTIVE'
);

insert into public.finance_accounts (
  id, tenant_id, name, account_type, currency_code
)
values (
  '27333333-3333-4333-8333-333333333333',
  '27222222-2222-4222-8222-222222222222',
  'Test Cash',
  'CASH',
  'TRY'
);

insert into public.finance_transactions (
  id,
  tenant_id,
  transaction_type,
  occurred_at,
  description,
  source_type,
  created_by_user_id
)
values (
  '27444444-4444-4444-8444-444444444444',
  '27222222-2222-4222-8222-222222222222',
  'INCOME',
  now(),
  'Immutable ledger test',
  'MANUAL',
  '27111111-1111-4111-8111-111111111111'
);

insert into public.finance_entries (
  id,
  tenant_id,
  transaction_id,
  account_id,
  amount
)
values (
  '27555555-5555-4555-8555-555555555555',
  '27222222-2222-4222-8222-222222222222',
  '27444444-4444-4444-8444-444444444444',
  '27333333-3333-4333-8333-333333333333',
  100.00
);

-- Flush deferred finance-shape checks before exercising TRUNCATE guards.
set constraints all immediate;

do $$
begin
  begin
    update public.finance_transactions
    set description = 'Mutation must fail'
    where id = '27444444-4444-4444-8444-444444444444';

    raise exception 'FINANCE_TRANSACTION_UPDATE_ALLOWED';
  exception
    when sqlstate '55000' then
      if sqlerrm <> 'FINANCE_LEDGER_IMMUTABLE' then
        raise;
      end if;
  end;

  begin
    delete from public.finance_transactions
    where id = '27444444-4444-4444-8444-444444444444';

    raise exception 'FINANCE_TRANSACTION_DELETE_ALLOWED';
  exception
    when sqlstate '55000' then
      if sqlerrm <> 'FINANCE_LEDGER_IMMUTABLE' then
        raise;
      end if;
  end;

  begin
    update public.finance_entries
    set amount = 101.00
    where id = '27555555-5555-4555-8555-555555555555';

    raise exception 'FINANCE_ENTRY_UPDATE_ALLOWED';
  exception
    when sqlstate '55000' then
      if sqlerrm <> 'FINANCE_LEDGER_IMMUTABLE' then
        raise;
      end if;
  end;

  begin
    delete from public.finance_entries
    where id = '27555555-5555-4555-8555-555555555555';

    raise exception 'FINANCE_ENTRY_DELETE_ALLOWED';
  exception
    when sqlstate '55000' then
      if sqlerrm <> 'FINANCE_LEDGER_IMMUTABLE' then
        raise;
      end if;
  end;

  begin
    truncate table public.finance_entries;

    raise exception 'FINANCE_ENTRIES_TRUNCATE_ALLOWED';
  exception
    when sqlstate '55000' then
      if sqlerrm <> 'FINANCE_LEDGER_IMMUTABLE' then
        raise;
      end if;
  end;

  begin
    truncate table public.finance_transactions cascade;

    raise exception 'FINANCE_TRANSACTIONS_TRUNCATE_ALLOWED';
  exception
    when sqlstate '55000' then
      if sqlerrm <> 'FINANCE_LEDGER_IMMUTABLE' then
        raise;
      end if;
  end;
end
$$;

rollback;

select
  'PASS - FINANCE LEDGER IMMUTABILITY' as result;
