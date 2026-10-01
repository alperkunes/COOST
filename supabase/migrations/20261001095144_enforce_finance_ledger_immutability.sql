-- COOST finance ledger immutability
-- Finance transaction headers and entries are append-only history.
-- Corrections must be represented by compensating transactions, never mutation.

create function private.reject_finance_ledger_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'FINANCE_LEDGER_IMMUTABLE'
    using errcode = '55000';
end;
$$;

revoke all
  on function private.reject_finance_ledger_change()
  from public, anon, authenticated;

create trigger finance_transactions_immutable
before update or delete
on public.finance_transactions
for each row
execute function private.reject_finance_ledger_change();

create trigger finance_entries_immutable
before update or delete
on public.finance_entries
for each row
execute function private.reject_finance_ledger_change();
