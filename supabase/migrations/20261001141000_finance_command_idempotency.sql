-- COOST finance command idempotency
--
-- A client-generated UUID identifies one logical money-writing request.
-- Retried requests with the same UUID and same normalized payload return
-- the original result instead of creating duplicate ledger history.

drop function public.create_finance_adjustment(uuid,uuid,numeric,text,timestamptz);

create function public.create_finance_adjustment(
  p_tenant_id uuid,
  p_account_id uuid,
  p_amount numeric,
  p_description text,
  p_occurred_at timestamptz default null,
  p_request_id uuid default null
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_request_id uuid := coalesce(p_request_id, gen_random_uuid());
  v_inserted_id uuid;
  v_location_id uuid;
  v_description text := trim(p_description);
  v_amount numeric(16,2);
  v_matches boolean;
begin
  if v_user_id is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;
  if not private.is_module_enabled(p_tenant_id, 'finance') then
    raise exception 'FINANCE_MODULE_NOT_AVAILABLE' using errcode = '42501';
  end if;
  if not private.has_permission(p_tenant_id, 'finance.write') then
    raise exception 'FINANCE_WRITE_FORBIDDEN' using errcode = '42501';
  end if;
  if p_amount is null or p_amount = 0 then
    raise exception 'FINANCE_AMOUNT_MUST_BE_NON_ZERO' using errcode = '22023';
  end if;

  v_amount := round(p_amount, 2);

  if v_amount = 0 then
    raise exception 'FINANCE_AMOUNT_MUST_BE_NON_ZERO' using errcode = '22023';
  end if;
  if abs(v_amount) > 99999999999999.99 then
    raise exception 'FINANCE_AMOUNT_OUT_OF_RANGE' using errcode = '22003';
  end if;
  if v_description is null or char_length(v_description) not between 2 and 500 then
    raise exception 'FINANCE_DESCRIPTION_INVALID' using errcode = '22023';
  end if;

  if exists(select 1 from public.finance_transactions where id = v_request_id) then
    select
      ft.tenant_id = p_tenant_id
      and ft.transaction_type = 'ADJUSTMENT'
      and ft.description = v_description
      and ft.source_type = 'MANUAL'
      and ft.source_id is null
      and ft.created_by_user_id = v_user_id
      and (p_occurred_at is null or ft.occurred_at = p_occurred_at)
      and (
        select count(*) = 1
        from public.finance_entries fe
        where fe.tenant_id = p_tenant_id
          and fe.transaction_id = v_request_id
      )
      and exists (
        select 1
        from public.finance_entries fe
        where fe.tenant_id = p_tenant_id
          and fe.transaction_id = v_request_id
          and fe.account_id = p_account_id
          and fe.amount = v_amount
      )
    into v_matches
    from public.finance_transactions ft
    where ft.id = v_request_id;

    if v_matches then
      return v_request_id;
    end if;

    raise exception 'FINANCE_IDEMPOTENCY_CONFLICT' using errcode = '55000';
  end if;

  select fa.location_id
  into v_location_id
  from public.finance_accounts fa
  where fa.id = p_account_id
    and fa.tenant_id = p_tenant_id
    and fa.status = 'ACTIVE'
  for share;

  if not found then
    raise exception 'FINANCE_ACCOUNT_NOT_AVAILABLE' using errcode = '22023';
  end if;

  insert into public.finance_transactions(
    id, tenant_id, location_id, transaction_type, occurred_at,
    description, source_type, created_by_user_id
  )
  values(
    v_request_id, p_tenant_id, v_location_id, 'ADJUSTMENT',
    coalesce(p_occurred_at, now()), v_description, 'MANUAL', v_user_id
  )
  on conflict (id) do nothing
  returning id into v_inserted_id;

  if v_inserted_id is null then
    select
      ft.tenant_id = p_tenant_id
      and ft.transaction_type = 'ADJUSTMENT'
      and ft.description = v_description
      and ft.source_type = 'MANUAL'
      and ft.source_id is null
      and ft.created_by_user_id = v_user_id
      and (p_occurred_at is null or ft.occurred_at = p_occurred_at)
      and (
        select count(*) = 1
        from public.finance_entries fe
        where fe.tenant_id = p_tenant_id
          and fe.transaction_id = v_request_id
      )
      and exists (
        select 1
        from public.finance_entries fe
        where fe.tenant_id = p_tenant_id
          and fe.transaction_id = v_request_id
          and fe.account_id = p_account_id
          and fe.amount = v_amount
      )
    into v_matches
    from public.finance_transactions ft
    where ft.id = v_request_id;

    if v_matches then
      return v_request_id;
    end if;

    raise exception 'FINANCE_IDEMPOTENCY_CONFLICT' using errcode = '55000';
  end if;

  insert into public.finance_entries(tenant_id,transaction_id,account_id,amount)
  values(p_tenant_id,v_request_id,p_account_id,v_amount);

  insert into public.audit_logs(
    tenant_id,location_id,actor_user_id,action,entity_type,entity_id,metadata
  )
  values(
    p_tenant_id,v_location_id,v_user_id,'FINANCE_ADJUSTMENT_CREATED',
    'finance_transaction',v_request_id,
    jsonb_build_object(
      'accountId',p_account_id,
      'amount',v_amount,
      'description',v_description
    )
  );

  return v_request_id;
end;
$$;

revoke all
  on function public.create_finance_adjustment(uuid,uuid,numeric,text,timestamptz,uuid)
  from public, anon;

grant execute
  on function public.create_finance_adjustment(uuid,uuid,numeric,text,timestamptz,uuid)
  to authenticated, service_role;


drop function public.create_finance_transfer(uuid,uuid,uuid,numeric,text,timestamptz);

create function public.create_finance_transfer(
  p_tenant_id uuid,
  p_from_account_id uuid,
  p_to_account_id uuid,
  p_amount numeric,
  p_description text,
  p_occurred_at timestamptz default null,
  p_request_id uuid default null
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_request_id uuid := coalesce(p_request_id, gen_random_uuid());
  v_inserted_id uuid;
  v_from_location_id uuid;
  v_to_location_id uuid;
  v_from_currency text;
  v_to_currency text;
  v_transaction_location_id uuid;
  v_description text := trim(p_description);
  v_amount numeric(16,2);
  v_matches boolean;
begin
  if v_user_id is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;
  if not private.is_module_enabled(p_tenant_id, 'finance') then
    raise exception 'FINANCE_MODULE_NOT_AVAILABLE' using errcode = '42501';
  end if;
  if not private.has_permission(p_tenant_id, 'finance.write') then
    raise exception 'FINANCE_WRITE_FORBIDDEN' using errcode = '42501';
  end if;
  if p_from_account_id = p_to_account_id then
    raise exception 'FINANCE_TRANSFER_ACCOUNTS_MUST_DIFFER' using errcode = '22023';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'FINANCE_TRANSFER_AMOUNT_MUST_BE_POSITIVE' using errcode = '22023';
  end if;

  v_amount := round(p_amount, 2);

  if v_amount <= 0 then
    raise exception 'FINANCE_TRANSFER_AMOUNT_MUST_BE_POSITIVE' using errcode = '22023';
  end if;
  if v_amount > 99999999999999.99 then
    raise exception 'FINANCE_AMOUNT_OUT_OF_RANGE' using errcode = '22003';
  end if;
  if v_description is null or char_length(v_description) not between 2 and 500 then
    raise exception 'FINANCE_DESCRIPTION_INVALID' using errcode = '22023';
  end if;

  if exists(select 1 from public.finance_transactions where id = v_request_id) then
    select
      ft.tenant_id = p_tenant_id
      and ft.transaction_type = 'TRANSFER'
      and ft.description = v_description
      and ft.source_type = 'MANUAL'
      and ft.source_id is null
      and ft.created_by_user_id = v_user_id
      and (p_occurred_at is null or ft.occurred_at = p_occurred_at)
      and (
        select count(*) = 2
        from public.finance_entries fe
        where fe.tenant_id = p_tenant_id
          and fe.transaction_id = v_request_id
      )
      and exists (
        select 1 from public.finance_entries fe
        where fe.tenant_id = p_tenant_id
          and fe.transaction_id = v_request_id
          and fe.account_id = p_from_account_id
          and fe.amount = -v_amount
      )
      and exists (
        select 1 from public.finance_entries fe
        where fe.tenant_id = p_tenant_id
          and fe.transaction_id = v_request_id
          and fe.account_id = p_to_account_id
          and fe.amount = v_amount
      )
    into v_matches
    from public.finance_transactions ft
    where ft.id = v_request_id;

    if v_matches then
      return v_request_id;
    end if;

    raise exception 'FINANCE_IDEMPOTENCY_CONFLICT' using errcode = '55000';
  end if;

  select fa.location_id,fa.currency_code
  into v_from_location_id,v_from_currency
  from public.finance_accounts fa
  where fa.id = p_from_account_id
    and fa.tenant_id = p_tenant_id
    and fa.status = 'ACTIVE'
  for share;

  if not found then
    raise exception 'FINANCE_FROM_ACCOUNT_NOT_AVAILABLE' using errcode = '22023';
  end if;

  select fa.location_id,fa.currency_code
  into v_to_location_id,v_to_currency
  from public.finance_accounts fa
  where fa.id = p_to_account_id
    and fa.tenant_id = p_tenant_id
    and fa.status = 'ACTIVE'
  for share;

  if not found then
    raise exception 'FINANCE_TO_ACCOUNT_NOT_AVAILABLE' using errcode = '22023';
  end if;

  if v_from_currency <> v_to_currency then
    raise exception 'FINANCE_TRANSFER_CURRENCY_MISMATCH' using errcode = '22023';
  end if;

  v_transaction_location_id :=
    case
      when v_from_location_id is not distinct from v_to_location_id then v_from_location_id
      else null
    end;

  insert into public.finance_transactions(
    id,tenant_id,location_id,transaction_type,occurred_at,
    description,source_type,created_by_user_id
  )
  values(
    v_request_id,p_tenant_id,v_transaction_location_id,'TRANSFER',
    coalesce(p_occurred_at,now()),v_description,'MANUAL',v_user_id
  )
  on conflict (id) do nothing
  returning id into v_inserted_id;

  if v_inserted_id is null then
    select
      ft.tenant_id = p_tenant_id
      and ft.transaction_type = 'TRANSFER'
      and ft.description = v_description
      and ft.source_type = 'MANUAL'
      and ft.source_id is null
      and ft.created_by_user_id = v_user_id
      and (p_occurred_at is null or ft.occurred_at = p_occurred_at)
      and (
        select count(*) = 2
        from public.finance_entries fe
        where fe.tenant_id = p_tenant_id
          and fe.transaction_id = v_request_id
      )
      and exists (
        select 1 from public.finance_entries fe
        where fe.tenant_id = p_tenant_id
          and fe.transaction_id = v_request_id
          and fe.account_id = p_from_account_id
          and fe.amount = -v_amount
      )
      and exists (
        select 1 from public.finance_entries fe
        where fe.tenant_id = p_tenant_id
          and fe.transaction_id = v_request_id
          and fe.account_id = p_to_account_id
          and fe.amount = v_amount
      )
    into v_matches
    from public.finance_transactions ft
    where ft.id = v_request_id;

    if v_matches then
      return v_request_id;
    end if;

    raise exception 'FINANCE_IDEMPOTENCY_CONFLICT' using errcode = '55000';
  end if;

  insert into public.finance_entries(tenant_id,transaction_id,account_id,amount)
  values
    (p_tenant_id,v_request_id,p_from_account_id,-v_amount),
    (p_tenant_id,v_request_id,p_to_account_id,v_amount);

  insert into public.audit_logs(
    tenant_id,location_id,actor_user_id,action,entity_type,entity_id,metadata
  )
  values(
    p_tenant_id,v_transaction_location_id,v_user_id,'FINANCE_TRANSFER_CREATED',
    'finance_transaction',v_request_id,
    jsonb_build_object(
      'fromAccountId',p_from_account_id,
      'toAccountId',p_to_account_id,
      'amount',v_amount,
      'currencyCode',v_from_currency,
      'description',v_description
    )
  );

  return v_request_id;
end;
$$;

revoke all
  on function public.create_finance_transfer(uuid,uuid,uuid,numeric,text,timestamptz,uuid)
  from public, anon;

grant execute
  on function public.create_finance_transfer(uuid,uuid,uuid,numeric,text,timestamptz,uuid)
  to authenticated, service_role;


drop function public.create_finance_cashflow(uuid,uuid,text,numeric,text,timestamptz);

create function public.create_finance_cashflow(
  p_tenant_id uuid,
  p_account_id uuid,
  p_transaction_type text,
  p_amount numeric,
  p_description text,
  p_occurred_at timestamptz default null,
  p_request_id uuid default null
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_request_id uuid := coalesce(p_request_id, gen_random_uuid());
  v_inserted_id uuid;
  v_location_id uuid;
  v_description text := trim(p_description);
  v_amount numeric;
  v_signed_amount numeric;
  v_matches boolean;
begin
  if v_user_id is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;
  if not private.is_module_enabled(p_tenant_id,'finance') then
    raise exception 'FINANCE_MODULE_NOT_AVAILABLE' using errcode = '42501';
  end if;
  if not private.has_permission(p_tenant_id,'finance.write') then
    raise exception 'FINANCE_WRITE_FORBIDDEN' using errcode = '42501';
  end if;
  if p_transaction_type is null or p_transaction_type not in ('INCOME','EXPENSE') then
    raise exception 'FINANCE_CASHFLOW_TYPE_INVALID' using errcode = '22023';
  end if;
  if p_amount is null or p_amount <= 0 or p_amount::text in ('NaN','Infinity','-Infinity') then
    raise exception 'FINANCE_CASHFLOW_AMOUNT_MUST_BE_POSITIVE' using errcode = '22023';
  end if;

  v_amount := round(p_amount,2);

  if v_amount <= 0 then
    raise exception 'FINANCE_CASHFLOW_AMOUNT_MUST_BE_POSITIVE' using errcode = '22023';
  end if;
  if v_amount > 99999999999999.99 then
    raise exception 'FINANCE_AMOUNT_OUT_OF_RANGE' using errcode = '22003';
  end if;
  if v_description is null or char_length(v_description) not between 2 and 500 then
    raise exception 'FINANCE_DESCRIPTION_INVALID' using errcode = '22023';
  end if;

  v_signed_amount :=
    case when p_transaction_type = 'INCOME' then v_amount else -v_amount end;

  if exists(select 1 from public.finance_transactions where id = v_request_id) then
    select
      ft.tenant_id = p_tenant_id
      and ft.transaction_type = p_transaction_type
      and ft.description = v_description
      and ft.source_type = 'MANUAL'
      and ft.source_id is null
      and ft.created_by_user_id = v_user_id
      and (p_occurred_at is null or ft.occurred_at = p_occurred_at)
      and (
        select count(*) = 1
        from public.finance_entries fe
        where fe.tenant_id = p_tenant_id
          and fe.transaction_id = v_request_id
      )
      and exists (
        select 1 from public.finance_entries fe
        where fe.tenant_id = p_tenant_id
          and fe.transaction_id = v_request_id
          and fe.account_id = p_account_id
          and fe.amount = v_signed_amount
      )
    into v_matches
    from public.finance_transactions ft
    where ft.id = v_request_id;

    if v_matches then
      return v_request_id;
    end if;

    raise exception 'FINANCE_IDEMPOTENCY_CONFLICT' using errcode = '55000';
  end if;

  select fa.location_id
  into v_location_id
  from public.finance_accounts fa
  where fa.id = p_account_id
    and fa.tenant_id = p_tenant_id
    and fa.status = 'ACTIVE'
  for share;

  if not found then
    raise exception 'FINANCE_ACCOUNT_NOT_AVAILABLE' using errcode = '22023';
  end if;

  insert into public.finance_transactions(
    id,tenant_id,location_id,transaction_type,occurred_at,
    description,source_type,created_by_user_id
  )
  values(
    v_request_id,p_tenant_id,v_location_id,p_transaction_type,
    coalesce(p_occurred_at,now()),v_description,'MANUAL',v_user_id
  )
  on conflict (id) do nothing
  returning id into v_inserted_id;

  if v_inserted_id is null then
    select
      ft.tenant_id = p_tenant_id
      and ft.transaction_type = p_transaction_type
      and ft.description = v_description
      and ft.source_type = 'MANUAL'
      and ft.source_id is null
      and ft.created_by_user_id = v_user_id
      and (p_occurred_at is null or ft.occurred_at = p_occurred_at)
      and (
        select count(*) = 1
        from public.finance_entries fe
        where fe.tenant_id = p_tenant_id
          and fe.transaction_id = v_request_id
      )
      and exists (
        select 1 from public.finance_entries fe
        where fe.tenant_id = p_tenant_id
          and fe.transaction_id = v_request_id
          and fe.account_id = p_account_id
          and fe.amount = v_signed_amount
      )
    into v_matches
    from public.finance_transactions ft
    where ft.id = v_request_id;

    if v_matches then
      return v_request_id;
    end if;

    raise exception 'FINANCE_IDEMPOTENCY_CONFLICT' using errcode = '55000';
  end if;

  insert into public.finance_entries(tenant_id,transaction_id,account_id,amount)
  values(p_tenant_id,v_request_id,p_account_id,v_signed_amount);

  insert into public.audit_logs(
    tenant_id,location_id,actor_user_id,action,entity_type,entity_id,metadata
  )
  values(
    p_tenant_id,v_location_id,v_user_id,
    case when p_transaction_type = 'INCOME'
      then 'FINANCE_INCOME_CREATED'
      else 'FINANCE_EXPENSE_CREATED'
    end,
    'finance_transaction',v_request_id,
    jsonb_build_object(
      'accountId',p_account_id,
      'transactionType',p_transaction_type,
      'amount',v_amount,
      'signedAmount',v_signed_amount,
      'description',v_description
    )
  );

  return v_request_id;
end;
$$;

revoke all
  on function public.create_finance_cashflow(uuid,uuid,text,numeric,text,timestamptz,uuid)
  from public, anon;

grant execute
  on function public.create_finance_cashflow(uuid,uuid,text,numeric,text,timestamptz,uuid)
  to authenticated, service_role;


drop function public.create_supplier_payment(uuid,uuid,uuid,numeric,text,timestamptz);

create function public.create_supplier_payment(
  p_tenant_id uuid,
  p_supplier_id uuid,
  p_finance_account_id uuid,
  p_amount numeric,
  p_description text,
  p_occurred_at timestamptz default null,
  p_request_id uuid default null
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_payment_id uuid := coalesce(p_request_id,gen_random_uuid());
  v_transaction_id uuid := gen_random_uuid();
  v_inserted_payment_id uuid;
  v_amount numeric;
  v_description text := trim(p_description);
  v_occurred_at timestamptz := coalesce(p_occurred_at,now());
  v_account public.finance_accounts%rowtype;
  v_matches boolean;
begin
  perform private.require_supplier_access(p_tenant_id,'suppliers.pay',true);

  if p_amount is null or p_amount <= 0 or p_amount::text in ('NaN','Infinity','-Infinity') then
    raise exception 'SUPPLIER_PAYMENT_AMOUNT_INVALID' using errcode = '22023';
  end if;

  v_amount := round(p_amount,2);

  if v_amount = 0 then
    raise exception 'SUPPLIER_PAYMENT_AMOUNT_INVALID' using errcode = '22023';
  end if;
  if v_amount > 99999999999999.99 then
    raise exception 'SUPPLIER_PAYMENT_AMOUNT_OVERFLOW' using errcode = '22003';
  end if;
  if v_description is null or char_length(v_description) not between 2 and 500 then
    raise exception 'SUPPLIER_PAYMENT_DESCRIPTION_INVALID' using errcode = '22023';
  end if;

  if exists(select 1 from public.supplier_payments where id = v_payment_id) then
    select
      sp.tenant_id = p_tenant_id
      and sp.supplier_id = p_supplier_id
      and sp.finance_account_id = p_finance_account_id
      and sp.amount = v_amount
      and sp.description = v_description
      and sp.created_by_user_id = v_user_id
      and (p_occurred_at is null or sp.occurred_at = p_occurred_at)
      and ft.transaction_type = 'EXPENSE'
      and ft.source_type = 'SUPPLIER_PAYMENT'
      and ft.source_id = sp.id
      and ft.created_by_user_id = v_user_id
      and (
        select count(*) = 1
        from public.finance_entries fe
        where fe.tenant_id = sp.tenant_id
          and fe.transaction_id = sp.finance_transaction_id
      )
      and exists (
        select 1 from public.finance_entries fe
        where fe.tenant_id = sp.tenant_id
          and fe.transaction_id = sp.finance_transaction_id
          and fe.account_id = sp.finance_account_id
          and fe.amount = -sp.amount
      )
      and exists (
        select 1 from public.supplier_ledger_entries sle
        where sle.tenant_id = sp.tenant_id
          and sle.supplier_id = sp.supplier_id
          and sle.entry_type = 'PAYMENT'
          and sle.currency_code = sp.currency_code
          and sle.amount = -sp.amount
          and sle.source_type = 'SUPPLIER_PAYMENT'
          and sle.source_id = sp.id
      )
    into v_matches
    from public.supplier_payments sp
    join public.finance_transactions ft
      on ft.id = sp.finance_transaction_id
     and ft.tenant_id = sp.tenant_id
    where sp.id = v_payment_id;

    if v_matches then
      return v_payment_id;
    end if;

    raise exception 'SUPPLIER_PAYMENT_IDEMPOTENCY_CONFLICT' using errcode = '55000';
  end if;

  perform 1
  from public.suppliers
  where id = p_supplier_id
    and tenant_id = p_tenant_id
    and status = 'ACTIVE'
  for share;

  if not found then
    raise exception 'SUPPLIER_NOT_AVAILABLE' using errcode = '22023';
  end if;

  select *
  into v_account
  from public.finance_accounts
  where id = p_finance_account_id
    and tenant_id = p_tenant_id
    and status = 'ACTIVE'
  for share;

  if not found then
    raise exception 'FINANCE_ACCOUNT_NOT_AVAILABLE' using errcode = '22023';
  end if;

  insert into public.supplier_payments(
    id,tenant_id,supplier_id,finance_account_id,finance_transaction_id,
    amount,currency_code,occurred_at,description,created_by_user_id
  )
  values(
    v_payment_id,p_tenant_id,p_supplier_id,p_finance_account_id,
    v_transaction_id,v_amount,v_account.currency_code,v_occurred_at,
    v_description,v_user_id
  )
  on conflict (id) do nothing
  returning id into v_inserted_payment_id;

  if v_inserted_payment_id is null then
    select
      sp.tenant_id = p_tenant_id
      and sp.supplier_id = p_supplier_id
      and sp.finance_account_id = p_finance_account_id
      and sp.amount = v_amount
      and sp.description = v_description
      and sp.created_by_user_id = v_user_id
      and (p_occurred_at is null or sp.occurred_at = p_occurred_at)
      and ft.transaction_type = 'EXPENSE'
      and ft.source_type = 'SUPPLIER_PAYMENT'
      and ft.source_id = sp.id
      and ft.created_by_user_id = v_user_id
      and (
        select count(*) = 1
        from public.finance_entries fe
        where fe.tenant_id = sp.tenant_id
          and fe.transaction_id = sp.finance_transaction_id
      )
      and exists (
        select 1 from public.finance_entries fe
        where fe.tenant_id = sp.tenant_id
          and fe.transaction_id = sp.finance_transaction_id
          and fe.account_id = sp.finance_account_id
          and fe.amount = -sp.amount
      )
      and exists (
        select 1 from public.supplier_ledger_entries sle
        where sle.tenant_id = sp.tenant_id
          and sle.supplier_id = sp.supplier_id
          and sle.entry_type = 'PAYMENT'
          and sle.currency_code = sp.currency_code
          and sle.amount = -sp.amount
          and sle.source_type = 'SUPPLIER_PAYMENT'
          and sle.source_id = sp.id
      )
    into v_matches
    from public.supplier_payments sp
    join public.finance_transactions ft
      on ft.id = sp.finance_transaction_id
     and ft.tenant_id = sp.tenant_id
    where sp.id = v_payment_id;

    if v_matches then
      return v_payment_id;
    end if;

    raise exception 'SUPPLIER_PAYMENT_IDEMPOTENCY_CONFLICT' using errcode = '55000';
  end if;

  insert into public.finance_transactions(
    id,tenant_id,location_id,transaction_type,occurred_at,description,
    source_type,source_id,created_by_user_id
  )
  values(
    v_transaction_id,p_tenant_id,v_account.location_id,'EXPENSE',
    v_occurred_at,v_description,'SUPPLIER_PAYMENT',v_payment_id,v_user_id
  );

  insert into public.finance_entries(tenant_id,transaction_id,account_id,amount)
  values(p_tenant_id,v_transaction_id,p_finance_account_id,-v_amount);

  insert into public.supplier_ledger_entries(
    tenant_id,supplier_id,entry_type,currency_code,amount,occurred_at,
    description,source_type,source_id,created_by_user_id
  )
  values(
    p_tenant_id,p_supplier_id,'PAYMENT',v_account.currency_code,-v_amount,
    v_occurred_at,v_description,'SUPPLIER_PAYMENT',v_payment_id,v_user_id
  );

  insert into public.audit_logs(
    tenant_id,location_id,actor_user_id,action,entity_type,entity_id,metadata
  )
  values(
    p_tenant_id,v_account.location_id,v_user_id,'SUPPLIER_PAYMENT_CREATED',
    'supplier_payment',v_payment_id,
    jsonb_build_object(
      'paymentId',v_payment_id,
      'supplierId',p_supplier_id,
      'financeAccountId',p_finance_account_id,
      'financeTransactionId',v_transaction_id,
      'amount',v_amount,
      'currencyCode',v_account.currency_code,
      'description',v_description
    )
  );

  return v_payment_id;
end;
$$;

revoke all
  on function public.create_supplier_payment(uuid,uuid,uuid,numeric,text,timestamptz,uuid)
  from public, anon;

grant execute
  on function public.create_supplier_payment(uuid,uuid,uuid,numeric,text,timestamptz,uuid)
  to authenticated, service_role;
