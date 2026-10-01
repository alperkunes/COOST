-- COOST finance transaction shape invariants
--
-- Finance ledgers are append-only. This migration adds commit-time structural
-- validation so every committed finance transaction has the expected entry
-- shape even when a privileged backend writes the ledger directly.

alter table public.finance_entries
  add constraint finance_entries_finite_amount_check
  check (
    amount <> 'NaN'::numeric
    and amount <> 'Infinity'::numeric
    and amount <> '-Infinity'::numeric
  );

create function private.validate_finance_transaction_shape(
  p_transaction_id uuid,
  p_tenant_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_transaction_type text;
  v_entry_count integer;
  v_account_count integer;
  v_positive_count integer;
  v_negative_count integer;
  v_amount_sum numeric;
  v_currency_count integer;
begin
  select ft.transaction_type
  into v_transaction_type
  from public.finance_transactions ft
  where ft.id = p_transaction_id
    and ft.tenant_id = p_tenant_id;

  if not found then
    raise exception 'FINANCE_TRANSACTION_NOT_FOUND'
      using errcode = '23514';
  end if;

  select
    count(fe.id)::integer,
    count(distinct fe.account_id)::integer,
    count(fe.id) filter (where fe.amount > 0)::integer,
    count(fe.id) filter (where fe.amount < 0)::integer,
    coalesce(sum(fe.amount), 0),
    count(distinct fa.currency_code)::integer
  into
    v_entry_count,
    v_account_count,
    v_positive_count,
    v_negative_count,
    v_amount_sum,
    v_currency_count
  from public.finance_entries fe
  join public.finance_accounts fa
    on fa.id = fe.account_id
   and fa.tenant_id = fe.tenant_id
  where fe.transaction_id = p_transaction_id
    and fe.tenant_id = p_tenant_id;

  if v_transaction_type = 'TRANSFER' then
    if not (
      v_entry_count = 2
      and v_account_count = 2
      and v_positive_count = 1
      and v_negative_count = 1
      and v_amount_sum = 0
      and v_currency_count = 1
    ) then
      raise exception 'FINANCE_TRANSFER_SHAPE_INVALID'
        using errcode = '23514';
    end if;

    return;
  end if;

  if v_transaction_type = 'INCOME' then
    if not (
      v_entry_count = 1
      and v_positive_count = 1
      and v_negative_count = 0
    ) then
      raise exception 'FINANCE_INCOME_SHAPE_INVALID'
        using errcode = '23514';
    end if;

    return;
  end if;

  if v_transaction_type = 'EXPENSE' then
    if not (
      v_entry_count = 1
      and v_positive_count = 0
      and v_negative_count = 1
    ) then
      raise exception 'FINANCE_EXPENSE_SHAPE_INVALID'
        using errcode = '23514';
    end if;

    return;
  end if;

  if v_transaction_type = 'ADJUSTMENT' then
    if v_entry_count <> 1 then
      raise exception 'FINANCE_ADJUSTMENT_SHAPE_INVALID'
        using errcode = '23514';
    end if;

    return;
  end if;

  raise exception 'FINANCE_TRANSACTION_TYPE_INVALID'
    using errcode = '23514';
end;
$$;

revoke all
  on function private.validate_finance_transaction_shape(uuid,uuid)
  from public, anon, authenticated;


create function private.enforce_finance_transaction_shape_from_header()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.validate_finance_transaction_shape(
    new.id,
    new.tenant_id
  );

  return null;
end;
$$;

revoke all
  on function private.enforce_finance_transaction_shape_from_header()
  from public, anon, authenticated;


create function private.enforce_finance_transaction_shape_from_entry()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.validate_finance_transaction_shape(
    new.transaction_id,
    new.tenant_id
  );

  return null;
end;
$$;

revoke all
  on function private.enforce_finance_transaction_shape_from_entry()
  from public, anon, authenticated;


create constraint trigger finance_transaction_shape_on_header
after insert on public.finance_transactions
deferrable initially deferred
for each row
execute function private.enforce_finance_transaction_shape_from_header();


create constraint trigger finance_transaction_shape_on_entry
after insert on public.finance_entries
deferrable initially deferred
for each row
execute function private.enforce_finance_transaction_shape_from_entry();


comment on function private.validate_finance_transaction_shape(uuid,uuid)
  is 'Commit-time invariant validator for immutable finance transaction entry shapes.';

comment on constraint finance_entries_finite_amount_check
  on public.finance_entries
  is 'Rejects NaN and infinite finance entry amounts.';
