-- COOST supplier / AP integrity hardening.
--
-- Supplier balances and payments are accounting history. This migration closes
-- privileged-write gaps around supplier deactivation, payment source linkage,
-- duplicate source races and TRUNCATE.

create unique index supplier_ledger_purchase_invoice_source_unique
  on public.supplier_ledger_entries(tenant_id, source_id)
  where source_type = 'PURCHASE_INVOICE';

create unique index finance_transactions_supplier_payment_source_unique
  on public.finance_transactions(tenant_id, source_id)
  where source_type = 'SUPPLIER_PAYMENT';


create function private.guard_supplier_update_invariants()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.id is distinct from new.id
     or old.tenant_id is distinct from new.tenant_id then
    raise exception 'SUPPLIER_IDENTITY_IMMUTABLE'
      using errcode = '55000';
  end if;

  if old.status <> new.status
     and new.status = 'PASSIVE'
     and exists (
       select 1
       from public.supplier_ledger_entries sle
       where sle.tenant_id = old.tenant_id
         and sle.supplier_id = old.id
       group by sle.currency_code
       having sum(sle.amount) <> 0
     ) then
    raise exception 'SUPPLIER_NON_ZERO_BALANCE'
      using errcode = '22023';
  end if;

  return new;
end;
$$;

revoke all
  on function private.guard_supplier_update_invariants()
  from public, anon, authenticated;

create trigger supplier_update_invariant_guard
before update on public.suppliers
for each row
execute function private.guard_supplier_update_invariants();


create function private.guard_supplier_payment_dependencies()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_supplier_status text;
  v_account_status text;
  v_account_currency text;
begin
  select s.status
  into v_supplier_status
  from public.suppliers s
  where s.id = new.supplier_id
    and s.tenant_id = new.tenant_id
  for share;

  if not found or v_supplier_status <> 'ACTIVE' then
    raise exception 'SUPPLIER_NOT_AVAILABLE'
      using errcode = '22023';
  end if;

  select fa.status, fa.currency_code
  into v_account_status, v_account_currency
  from public.finance_accounts fa
  where fa.id = new.finance_account_id
    and fa.tenant_id = new.tenant_id
  for share;

  if not found or v_account_status <> 'ACTIVE' then
    raise exception 'FINANCE_ACCOUNT_NOT_AVAILABLE'
      using errcode = '22023';
  end if;

  if new.currency_code <> v_account_currency then
    raise exception 'SUPPLIER_PAYMENT_CURRENCY_MISMATCH'
      using errcode = '22023';
  end if;

  return new;
end;
$$;

revoke all
  on function private.guard_supplier_payment_dependencies()
  from public, anon, authenticated;

create trigger supplier_payment_dependencies_validate
before insert on public.supplier_payments
for each row
execute function private.guard_supplier_payment_dependencies();


create function private.validate_supplier_payment_shape(
  p_payment_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  sp public.supplier_payments%rowtype;
  fa public.finance_accounts%rowtype;
  v_tx_count integer;
  v_tx_match_count integer;
  v_entry_count integer;
  v_entry_match_count integer;
  v_ledger_count integer;
  v_ledger_match_count integer;
begin
  select *
  into sp
  from public.supplier_payments
  where id = p_payment_id;

  if not found then
    raise exception 'SUPPLIER_PAYMENT_NOT_FOUND'
      using errcode = '23514';
  end if;

  select *
  into fa
  from public.finance_accounts
  where id = sp.finance_account_id
    and tenant_id = sp.tenant_id;

  if not found
     or fa.status <> 'ACTIVE'
     or fa.currency_code <> sp.currency_code then
    raise exception 'SUPPLIER_PAYMENT_ACCOUNT_INVALID'
      using errcode = '23514';
  end if;

  select
    count(*)::integer,
    count(*) filter (
      where ft.id = sp.finance_transaction_id
        and ft.transaction_type = 'EXPENSE'
        and ft.location_id is not distinct from fa.location_id
        and ft.occurred_at = sp.occurred_at
        and ft.description is not distinct from sp.description
        and ft.created_by_user_id = sp.created_by_user_id
    )::integer
  into v_tx_count, v_tx_match_count
  from public.finance_transactions ft
  where ft.tenant_id = sp.tenant_id
    and ft.source_type = 'SUPPLIER_PAYMENT'
    and ft.source_id = sp.id;

  if v_tx_count <> 1 or v_tx_match_count <> 1 then
    raise exception 'SUPPLIER_PAYMENT_FINANCE_INVALID'
      using errcode = '23514';
  end if;

  select
    count(*)::integer,
    count(*) filter (
      where fe.account_id = sp.finance_account_id
        and fe.amount = -sp.amount
    )::integer
  into v_entry_count, v_entry_match_count
  from public.finance_entries fe
  where fe.tenant_id = sp.tenant_id
    and fe.transaction_id = sp.finance_transaction_id;

  if v_entry_count <> 1 or v_entry_match_count <> 1 then
    raise exception 'SUPPLIER_PAYMENT_FINANCE_ENTRY_INVALID'
      using errcode = '23514';
  end if;

  select
    count(*)::integer,
    count(*) filter (
      where sle.entry_type = 'PAYMENT'
        and sle.supplier_id = sp.supplier_id
        and sle.currency_code = sp.currency_code
        and sle.amount = -sp.amount
        and sle.occurred_at = sp.occurred_at
        and sle.description = sp.description
        and sle.created_by_user_id = sp.created_by_user_id
    )::integer
  into v_ledger_count, v_ledger_match_count
  from public.supplier_ledger_entries sle
  where sle.tenant_id = sp.tenant_id
    and sle.source_type = 'SUPPLIER_PAYMENT'
    and sle.source_id = sp.id;

  if v_ledger_count <> 1 or v_ledger_match_count <> 1 then
    raise exception 'SUPPLIER_PAYMENT_LEDGER_INVALID'
      using errcode = '23514';
  end if;
end;
$$;

revoke all
  on function private.validate_supplier_payment_shape(uuid)
  from public, anon, authenticated;


create function private.enforce_supplier_payment_shape_from_payment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.validate_supplier_payment_shape(new.id);
  return null;
end;
$$;

revoke all
  on function private.enforce_supplier_payment_shape_from_payment()
  from public, anon, authenticated;


create function private.enforce_supplier_payment_shape_from_finance_transaction()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.source_type is distinct from 'SUPPLIER_PAYMENT' then
    return null;
  end if;

  if new.source_id is null then
    raise exception 'SUPPLIER_PAYMENT_SOURCE_INVALID'
      using errcode = '23514';
  end if;

  perform private.validate_supplier_payment_shape(new.source_id);
  return null;
end;
$$;

revoke all
  on function private.enforce_supplier_payment_shape_from_finance_transaction()
  from public, anon, authenticated;


create function private.enforce_supplier_payment_shape_from_ledger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.source_type is distinct from 'SUPPLIER_PAYMENT'
     and new.entry_type is distinct from 'PAYMENT' then
    return null;
  end if;

  if new.source_id is null then
    raise exception 'SUPPLIER_PAYMENT_SOURCE_INVALID'
      using errcode = '23514';
  end if;

  perform private.validate_supplier_payment_shape(new.source_id);
  return null;
end;
$$;

revoke all
  on function private.enforce_supplier_payment_shape_from_ledger()
  from public, anon, authenticated;


create constraint trigger supplier_payment_shape_on_payment
after insert on public.supplier_payments
deferrable initially deferred
for each row
execute function private.enforce_supplier_payment_shape_from_payment();

create constraint trigger supplier_payment_shape_on_finance_transaction
after insert on public.finance_transactions
deferrable initially deferred
for each row
execute function private.enforce_supplier_payment_shape_from_finance_transaction();

create constraint trigger supplier_payment_shape_on_supplier_ledger
after insert on public.supplier_ledger_entries
deferrable initially deferred
for each row
execute function private.enforce_supplier_payment_shape_from_ledger();


create trigger suppliers_no_truncate
before truncate on public.suppliers
for each statement
execute function private.reject_supplier_history_change();

create trigger supplier_payments_no_truncate
before truncate on public.supplier_payments
for each statement
execute function private.reject_supplier_history_change();


comment on function private.validate_supplier_payment_shape(uuid)
  is 'Deferred invariant validator binding supplier payment, finance transaction/entry and supplier ledger into one accounting event.';

comment on index supplier_ledger_purchase_invoice_source_unique
  is 'Prevents concurrent duplicate supplier debt rows for one purchase invoice.';

comment on index finance_transactions_supplier_payment_source_unique
  is 'Prevents concurrent duplicate finance transactions for one supplier payment.';
