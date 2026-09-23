-- COOST Finance Foundation v1
--
-- Operational treasury ledger.
-- Balances are derived from immutable account entries.

create table public.finance_accounts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null
    references public.tenants(id)
    on delete cascade,
  location_id uuid,
  name text not null,
  account_type text not null,
  currency_code text not null default 'TRY',
  status text not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint finance_accounts_location_fk
    foreign key (location_id, tenant_id)
    references public.locations(id, tenant_id)
    on delete restrict,

  constraint finance_accounts_name_check
    check (char_length(trim(name)) between 2 and 120),

  constraint finance_accounts_type_check
    check (account_type in ('CASH', 'BANK')),

  constraint finance_accounts_currency_check
    check (currency_code ~ '^[A-Z]{3}$'),

  constraint finance_accounts_status_check
    check (status in ('ACTIVE', 'PASSIVE')),

  constraint finance_accounts_tenant_name_unique
    unique (tenant_id, name),

  constraint finance_accounts_id_tenant_unique
    unique (id, tenant_id)
);


create table public.finance_transactions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null
    references public.tenants(id)
    on delete restrict,
  location_id uuid,
  transaction_type text not null,
  occurred_at timestamptz not null,
  description text,
  source_type text,
  source_id uuid,
  created_by_user_id uuid not null
    references auth.users(id)
    on delete restrict,
  created_at timestamptz not null default now(),

  constraint finance_transactions_location_fk
    foreign key (location_id, tenant_id)
    references public.locations(id, tenant_id)
    on delete restrict,

  constraint finance_transactions_type_check
    check (
      transaction_type in (
        'INCOME',
        'EXPENSE',
        'TRANSFER',
        'ADJUSTMENT'
      )
    ),

  constraint finance_transactions_description_check
    check (
      description is null
      or char_length(trim(description)) between 1 and 500
    ),

  constraint finance_transactions_id_tenant_unique
    unique (id, tenant_id)
);


create table public.finance_entries (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null
    references public.tenants(id)
    on delete restrict,
  transaction_id uuid not null,
  account_id uuid not null,
  amount numeric(16,2) not null,
  created_at timestamptz not null default now(),

  constraint finance_entries_transaction_fk
    foreign key (transaction_id, tenant_id)
    references public.finance_transactions(id, tenant_id)
    on delete restrict,

  constraint finance_entries_account_fk
    foreign key (account_id, tenant_id)
    references public.finance_accounts(id, tenant_id)
    on delete restrict,

  constraint finance_entries_amount_check
    check (amount <> 0)
);


create index idx_finance_accounts_tenant
  on public.finance_accounts(
    tenant_id,
    status
  );

create index idx_finance_transactions_tenant_occurred
  on public.finance_transactions(
    tenant_id,
    occurred_at desc
  );

create index idx_finance_entries_transaction
  on public.finance_entries(
    tenant_id,
    transaction_id
  );

create index idx_finance_entries_account
  on public.finance_entries(
    tenant_id,
    account_id
  );


alter table public.finance_accounts
  enable row level security;

alter table public.finance_transactions
  enable row level security;

alter table public.finance_entries
  enable row level security;


revoke all
  on table public.finance_accounts,
           public.finance_transactions,
           public.finance_entries
  from anon;

revoke insert, update, delete
  on table public.finance_accounts,
           public.finance_transactions,
           public.finance_entries
  from authenticated;

grant select
  on table public.finance_accounts,
           public.finance_transactions,
           public.finance_entries
  to authenticated;


create policy finance_accounts_select_authorized
  on public.finance_accounts
  for select
  to authenticated
  using (
    private.is_module_enabled(
      tenant_id,
      'finance'
    )
    and private.has_permission(
      tenant_id,
      'finance.read'
    )
  );


create policy finance_transactions_select_authorized
  on public.finance_transactions
  for select
  to authenticated
  using (
    private.is_module_enabled(
      tenant_id,
      'finance'
    )
    and private.has_permission(
      tenant_id,
      'finance.read'
    )
  );


create policy finance_entries_select_authorized
  on public.finance_entries
  for select
  to authenticated
  using (
    private.is_module_enabled(
      tenant_id,
      'finance'
    )
    and private.has_permission(
      tenant_id,
      'finance.read'
    )
  );


comment on table public.finance_accounts
  is 'Tenant cash and bank accounts used by the COOST operational treasury ledger.';

comment on table public.finance_transactions
  is 'Immutable finance transaction headers. Browser clients cannot mutate these tables directly.';

comment on table public.finance_entries
  is 'Signed account movements. Positive values increase an account balance; negative values decrease it.';