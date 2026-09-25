-- Supplier debt: positive = payable, negative = advance/receivable.
create table public.suppliers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  name text not null check (name = trim(name) and char_length(name) between 2 and 160),
  tax_number text check (tax_number ~ '^[0-9]{10,11}$'),
  phone text check (char_length(phone) <= 40),
  email text check (char_length(email) <= 254 and email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'),
  notes text check (char_length(notes) <= 2000),
  status text not null default 'ACTIVE' check (status in ('ACTIVE', 'PASSIVE')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, tenant_id)
);
create unique index suppliers_tenant_normalized_name on public.suppliers
  (tenant_id, lower(regexp_replace(trim(name), '[[:space:]]+', ' ', 'g')));

create table public.supplier_payments (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  supplier_id uuid not null,
  finance_account_id uuid not null,
  finance_transaction_id uuid not null,
  amount numeric(16,2) not null check (amount > 0 and amount <> 'NaN'::numeric),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  occurred_at timestamptz not null,
  description text not null check (char_length(trim(description)) between 2 and 500),
  created_by_user_id uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (id, tenant_id),
  unique (finance_transaction_id, tenant_id),
  foreign key (supplier_id, tenant_id) references public.suppliers(id, tenant_id) on delete restrict,
  foreign key (finance_account_id, tenant_id) references public.finance_accounts(id, tenant_id) on delete restrict,
  -- Preallocate the finance transaction UUID so the business event is inserted first.
  foreign key (finance_transaction_id, tenant_id) references public.finance_transactions(id, tenant_id)
    on delete restrict deferrable initially deferred
);
create index supplier_payments_recent on public.supplier_payments(tenant_id, occurred_at desc, id desc);
create index supplier_payments_supplier on public.supplier_payments(tenant_id, supplier_id);
create index supplier_payments_account on public.supplier_payments(finance_account_id, tenant_id);

create table public.supplier_ledger_entries (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  supplier_id uuid not null,
  entry_type text not null check (entry_type in ('INVOICE', 'PAYMENT', 'ADJUSTMENT', 'CREDIT_NOTE')),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  amount numeric(16,2) not null check (amount <> 0 and amount <> 'NaN'::numeric),
  occurred_at timestamptz not null,
  description text not null check (char_length(trim(description)) between 2 and 500),
  source_type text not null,
  source_id uuid,
  created_by_user_id uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  foreign key (supplier_id, tenant_id) references public.suppliers(id, tenant_id) on delete restrict,
  check (entry_type <> 'PAYMENT' or (amount < 0 and source_type = 'SUPPLIER_PAYMENT' and source_id is not null))
);
create index supplier_ledger_balances on public.supplier_ledger_entries(tenant_id, supplier_id, currency_code);
create unique index supplier_ledger_payment_source on public.supplier_ledger_entries(tenant_id, source_id)
  where entry_type = 'PAYMENT';

alter table public.suppliers enable row level security;
alter table public.supplier_payments enable row level security;
alter table public.supplier_ledger_entries enable row level security;
revoke all on public.suppliers, public.supplier_payments, public.supplier_ledger_entries from public, anon;
revoke all on public.suppliers, public.supplier_payments, public.supplier_ledger_entries from authenticated;
grant select on public.suppliers, public.supplier_payments, public.supplier_ledger_entries to authenticated;
create policy suppliers_read on public.suppliers for select to authenticated
  using (private.is_module_enabled(tenant_id, 'suppliers') and private.has_permission(tenant_id, 'suppliers.read'));
create policy supplier_payments_read on public.supplier_payments for select to authenticated
  using (private.is_module_enabled(tenant_id, 'suppliers') and private.has_permission(tenant_id, 'suppliers.read'));
create policy supplier_ledger_read on public.supplier_ledger_entries for select to authenticated
  using (private.is_module_enabled(tenant_id, 'suppliers') and private.has_permission(tenant_id, 'suppliers.read'));

create function private.reject_supplier_history_change() returns trigger
language plpgsql set search_path = '' as $$
begin
  raise exception 'SUPPLIER_HISTORY_IMMUTABLE' using errcode = '55000';
end;
$$;
revoke all on function private.reject_supplier_history_change() from public, anon, authenticated;
create trigger supplier_payments_immutable before update or delete on public.supplier_payments
  for each row execute function private.reject_supplier_history_change();
create trigger supplier_ledger_immutable before update or delete on public.supplier_ledger_entries
  for each row execute function private.reject_supplier_history_change();
create trigger suppliers_no_delete before delete on public.suppliers
  for each row execute function private.reject_supplier_history_change();

create function private.guard_supplier_ledger_account() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_status text;
begin
  select status into v_status from public.suppliers
  where id = new.supplier_id and tenant_id = new.tenant_id for share;
  if found and v_status <> 'ACTIVE' then
    raise exception 'SUPPLIER_NOT_AVAILABLE' using errcode = '22023';
  end if;
  return new;
end;
$$;
revoke all on function private.guard_supplier_ledger_account() from public, anon, authenticated;
create trigger supplier_ledger_active_supplier before insert on public.supplier_ledger_entries
  for each row execute function private.guard_supplier_ledger_account();

create function private.require_supplier_access(p_tenant_id uuid, p_permission text, p_payment boolean default false)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501'; end if;
  if not private.is_module_enabled(p_tenant_id, 'suppliers') then
    raise exception 'SUPPLIERS_MODULE_NOT_AVAILABLE' using errcode = '42501';
  end if;
  if not private.has_permission(p_tenant_id, p_permission) then
    raise exception 'SUPPLIER_PERMISSION_DENIED' using errcode = '42501';
  end if;
  if p_payment then
    if not private.is_module_enabled(p_tenant_id, 'finance') then
      raise exception 'FINANCE_MODULE_NOT_AVAILABLE' using errcode = '42501';
    end if;
    if not private.has_permission(p_tenant_id, 'finance.write') then
      raise exception 'FINANCE_WRITE_FORBIDDEN' using errcode = '42501';
    end if;
  end if;
end;
$$;
revoke all on function private.require_supplier_access(uuid, text, boolean) from public, anon, authenticated;

create function private.supplier_fields(p_name text, p_tax_number text, p_phone text, p_email text, p_notes text)
returns jsonb language plpgsql immutable set search_path = '' as $$
declare
  v_name text := trim(regexp_replace(p_name, '[[:space:]]+', ' ', 'g'));
  v_tax text := nullif(trim(p_tax_number), '');
  v_phone text := nullif(trim(p_phone), '');
  v_email text := nullif(lower(trim(p_email)), '');
  v_notes text := nullif(trim(p_notes), '');
begin
  if v_name is null or char_length(v_name) not between 2 and 160 then
    raise exception 'SUPPLIER_NAME_INVALID' using errcode = '22023';
  end if;
  if v_tax is not null and v_tax !~ '^[0-9]{10,11}$' then
    raise exception 'SUPPLIER_TAX_NUMBER_INVALID' using errcode = '22023';
  end if;
  if char_length(v_phone) > 40 or char_length(v_notes) > 2000 or char_length(v_email) > 254
    or (v_email is not null and v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$') then
    raise exception 'SUPPLIER_CONTACT_INVALID' using errcode = '22023';
  end if;
  return jsonb_build_object('name',v_name,'taxNumber',v_tax,'phone',v_phone,'email',v_email,'notes',v_notes);
end;
$$;
revoke all on function private.supplier_fields(text,text,text,text,text) from public, anon, authenticated;

create function public.create_supplier(p_tenant_id uuid, p_name text, p_tax_number text default null,
  p_phone text default null, p_email text default null, p_notes text default null)
returns uuid language plpgsql volatile security definer set search_path = '' as $$
declare v_fields jsonb; v_id uuid;
begin
  perform private.require_supplier_access(p_tenant_id, 'suppliers.write');
  v_fields := private.supplier_fields(p_name, p_tax_number, p_phone, p_email, p_notes);
  begin
    insert into public.suppliers(tenant_id,name,tax_number,phone,email,notes)
    values(p_tenant_id,v_fields->>'name',v_fields->>'taxNumber',v_fields->>'phone',v_fields->>'email',v_fields->>'notes')
    returning id into v_id;
  exception when unique_violation then raise exception 'SUPPLIER_NAME_EXISTS' using errcode = '23505'; end;
  insert into public.audit_logs(tenant_id,actor_user_id,action,entity_type,entity_id,metadata)
  values(p_tenant_id,auth.uid(),'SUPPLIER_CREATED','supplier',v_id,
    v_fields || jsonb_build_object('supplierId',v_id,'status','ACTIVE'));
  return v_id;
end;
$$;

create function public.update_supplier(p_tenant_id uuid, p_supplier_id uuid, p_name text,
  p_tax_number text, p_phone text, p_email text, p_notes text, p_status text)
returns uuid language plpgsql volatile security definer set search_path = '' as $$
declare v_fields jsonb; v_old public.suppliers%rowtype; v_old_fields jsonb;
begin
  perform private.require_supplier_access(p_tenant_id, 'suppliers.write');
  v_fields := private.supplier_fields(p_name,p_tax_number,p_phone,p_email,p_notes);
  if p_status is null or p_status not in ('ACTIVE','PASSIVE') then
    raise exception 'SUPPLIER_STATUS_INVALID' using errcode = '22023';
  end if;
  select * into v_old from public.suppliers where id = p_supplier_id and tenant_id = p_tenant_id for update;
  if not found then raise exception 'SUPPLIER_NOT_AVAILABLE' using errcode = '22023'; end if;
  v_old_fields := jsonb_build_object('name',v_old.name,'taxNumber',v_old.tax_number,'phone',v_old.phone,
    'email',v_old.email,'notes',v_old.notes,'status',v_old.status);
  v_fields := v_fields || jsonb_build_object('status',p_status);
  if v_fields = v_old_fields then raise exception 'SUPPLIER_NO_CHANGES' using errcode = '22023'; end if;
  if v_old.status = 'ACTIVE' and p_status = 'PASSIVE' and exists (
    select 1 from public.supplier_ledger_entries where tenant_id = p_tenant_id and supplier_id = p_supplier_id
    group by currency_code having sum(amount) <> 0
  ) then raise exception 'SUPPLIER_NON_ZERO_BALANCE' using errcode = '22023'; end if;
  begin
    update public.suppliers set name = v_fields->>'name', tax_number = v_fields->>'taxNumber',
      phone = v_fields->>'phone', email = v_fields->>'email', notes = v_fields->>'notes', status = p_status, updated_at = now()
    where id = p_supplier_id and tenant_id = p_tenant_id;
  exception when unique_violation then raise exception 'SUPPLIER_NAME_EXISTS' using errcode = '23505'; end;
  insert into public.audit_logs(tenant_id,actor_user_id,action,entity_type,entity_id,metadata)
  values(p_tenant_id,auth.uid(),'SUPPLIER_UPDATED','supplier',p_supplier_id,
    jsonb_build_object('supplierId',p_supplier_id,'old',v_old_fields,'new',v_fields));
  return p_supplier_id;
end;
$$;

create function public.get_supplier_overview(p_tenant_id uuid, p_recent_limit integer default 20)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_suppliers jsonb; v_payments jsonb;
begin
  perform private.require_supplier_access(p_tenant_id, 'suppliers.read');
  select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'name',s.name,'taxNumber',s.tax_number,
    'phone',s.phone,'email',s.email,'notes',s.notes,'status',s.status,'balances',coalesce(b.balances,'[]'::jsonb))
    order by s.name,s.id),'[]'::jsonb) into v_suppliers
  from public.suppliers s left join (
    select supplier_id,jsonb_agg(jsonb_build_object('currencyCode',currency_code,'amount',balance) order by currency_code) balances
    from (select supplier_id,currency_code,sum(amount) balance from public.supplier_ledger_entries
      where tenant_id = p_tenant_id group by supplier_id,currency_code) totals group by supplier_id
  ) b on b.supplier_id = s.id where s.tenant_id = p_tenant_id;
  select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'supplierId',p.supplier_id,'supplierName',s.name,
    'financeAccountId',p.finance_account_id,'financeAccountName',a.name,'amount',p.amount,
    'currencyCode',p.currency_code,'occurredAt',p.occurred_at,'description',p.description)
    order by p.occurred_at desc,p.id desc),'[]'::jsonb) into v_payments
  from (select * from public.supplier_payments where tenant_id = p_tenant_id
    order by occurred_at desc,id desc limit least(greatest(coalesce(p_recent_limit,20),1),100)) p
  join public.suppliers s on s.id = p.supplier_id and s.tenant_id = p.tenant_id
  join public.finance_accounts a on a.id = p.finance_account_id and a.tenant_id = p.tenant_id;
  return jsonb_build_object('tenantId',p_tenant_id,'suppliers',v_suppliers,'recentPayments',v_payments);
end;
$$;

create function public.get_supplier_payment_context(p_tenant_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_accounts jsonb;
begin
  perform private.require_supplier_access(p_tenant_id, 'suppliers.pay', true);
  select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'name',a.name,'accountType',a.account_type,
    'currencyCode',a.currency_code,'derivedBalance',a.balance) order by a.name,a.id),'[]'::jsonb) into v_accounts
  from (select fa.id,fa.name,fa.account_type,fa.currency_code,coalesce(sum(fe.amount),0) balance
    from public.finance_accounts fa left join public.finance_entries fe on fe.account_id = fa.id and fe.tenant_id = fa.tenant_id
    where fa.tenant_id = p_tenant_id and fa.status = 'ACTIVE' group by fa.id) a;
  return jsonb_build_object('tenantId',p_tenant_id,'accounts',v_accounts);
end;
$$;

create function public.create_supplier_payment(p_tenant_id uuid, p_supplier_id uuid, p_finance_account_id uuid,
  p_amount numeric, p_description text, p_occurred_at timestamptz default now())
returns uuid language plpgsql volatile security definer set search_path = '' as $$
declare
  v_payment_id uuid := gen_random_uuid();
  v_transaction_id uuid := gen_random_uuid();
  v_amount numeric;
  v_description text := trim(p_description);
  v_occurred_at timestamptz := coalesce(p_occurred_at,now());
  v_account public.finance_accounts%rowtype;
begin
  perform private.require_supplier_access(p_tenant_id, 'suppliers.pay', true);
  if p_amount is null or p_amount <= 0 or p_amount::text in ('NaN','Infinity','-Infinity') then
    raise exception 'SUPPLIER_PAYMENT_AMOUNT_INVALID' using errcode = '22023';
  end if;
  v_amount := round(p_amount,2);
  if v_amount = 0 then raise exception 'SUPPLIER_PAYMENT_AMOUNT_INVALID' using errcode = '22023'; end if;
  if v_amount > 99999999999999.99 then raise exception 'SUPPLIER_PAYMENT_AMOUNT_OVERFLOW' using errcode = '22003'; end if;
  if v_description is null or char_length(v_description) not between 2 and 500 then
    raise exception 'SUPPLIER_PAYMENT_DESCRIPTION_INVALID' using errcode = '22023';
  end if;
  -- Shared locks serialize payment with supplier/account deactivation.
  perform 1 from public.suppliers where id = p_supplier_id and tenant_id = p_tenant_id and status = 'ACTIVE' for share;
  if not found then raise exception 'SUPPLIER_NOT_AVAILABLE' using errcode = '22023'; end if;
  select * into v_account from public.finance_accounts
    where id = p_finance_account_id and tenant_id = p_tenant_id and status = 'ACTIVE' for share;
  if not found then raise exception 'FINANCE_ACCOUNT_NOT_AVAILABLE' using errcode = '22023'; end if;
  insert into public.supplier_payments(id,tenant_id,supplier_id,finance_account_id,finance_transaction_id,
    amount,currency_code,occurred_at,description,created_by_user_id)
  values(v_payment_id,p_tenant_id,p_supplier_id,p_finance_account_id,v_transaction_id,v_amount,
    v_account.currency_code,v_occurred_at,v_description,auth.uid());
  insert into public.finance_transactions(id,tenant_id,location_id,transaction_type,occurred_at,description,source_type,source_id,created_by_user_id)
  values(v_transaction_id,p_tenant_id,v_account.location_id,'EXPENSE',v_occurred_at,v_description,'SUPPLIER_PAYMENT',v_payment_id,auth.uid());
  insert into public.finance_entries(tenant_id,transaction_id,account_id,amount)
  values(p_tenant_id,v_transaction_id,p_finance_account_id,-v_amount);
  insert into public.supplier_ledger_entries(tenant_id,supplier_id,entry_type,currency_code,amount,occurred_at,description,source_type,source_id,created_by_user_id)
  values(p_tenant_id,p_supplier_id,'PAYMENT',v_account.currency_code,-v_amount,v_occurred_at,v_description,'SUPPLIER_PAYMENT',v_payment_id,auth.uid());
  insert into public.audit_logs(tenant_id,location_id,actor_user_id,action,entity_type,entity_id,metadata)
  values(p_tenant_id,v_account.location_id,auth.uid(),'SUPPLIER_PAYMENT_CREATED','supplier_payment',v_payment_id,
    jsonb_build_object('paymentId',v_payment_id,'supplierId',p_supplier_id,'financeAccountId',p_finance_account_id,
      'financeTransactionId',v_transaction_id,'amount',v_amount,'currencyCode',v_account.currency_code,'description',v_description));
  return v_payment_id;
end;
$$;

revoke all on function public.create_supplier(uuid,text,text,text,text,text) from public, anon;
revoke all on function public.update_supplier(uuid,uuid,text,text,text,text,text,text) from public, anon;
revoke all on function public.get_supplier_overview(uuid,integer) from public, anon;
revoke all on function public.get_supplier_payment_context(uuid) from public, anon;
revoke all on function public.create_supplier_payment(uuid,uuid,uuid,numeric,text,timestamptz) from public, anon;
grant execute on function public.create_supplier(uuid,text,text,text,text,text) to authenticated, service_role;
grant execute on function public.update_supplier(uuid,uuid,text,text,text,text,text,text) to authenticated, service_role;
grant execute on function public.get_supplier_overview(uuid,integer) to authenticated, service_role;
grant execute on function public.get_supplier_payment_context(uuid) to authenticated, service_role;
grant execute on function public.create_supplier_payment(uuid,uuid,uuid,numeric,text,timestamptz) to authenticated, service_role;
