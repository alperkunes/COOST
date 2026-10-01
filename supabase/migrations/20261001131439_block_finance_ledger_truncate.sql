-- COOST finance ledger truncate protection
-- Row-level immutability triggers do not fire for TRUNCATE.
-- Ledger history must not be removable through service/backend privileges.

create trigger finance_transactions_no_truncate
before truncate
on public.finance_transactions
for each statement
execute function private.reject_finance_ledger_change();

create trigger finance_entries_no_truncate
before truncate
on public.finance_entries
for each statement
execute function private.reject_finance_ledger_change();
