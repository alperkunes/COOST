-- COOST Finance Transfer Command v1
--
-- Purpose:
-- Create an immutable zero-sum transfer between two ACTIVE
-- finance accounts without allowing direct browser writes.

create or replace function public.create_finance_transfer(
  p_tenant_id uuid,
  p_from_account_id uuid,
  p_to_account_id uuid,
  p_amount numeric,
  p_description text,
  p_occurred_at timestamptz default now()
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_transaction_id uuid;

  v_from_location_id uuid;
  v_to_location_id uuid;

  v_from_currency text;
  v_to_currency text;

  v_transaction_location_id uuid;
  v_description text := trim(p_description);
  v_amount numeric(16,2);
begin
  if v_user_id is null then
    raise exception 'AUTHENTICATION_REQUIRED'
      using errcode = '42501';
  end if;

  if not private.is_module_enabled(
    p_tenant_id,
    'finance'
  ) then
    raise exception 'FINANCE_MODULE_NOT_AVAILABLE'
      using errcode = '42501';
  end if;

  if not private.has_permission(
    p_tenant_id,
    'finance.write'
  ) then
    raise exception 'FINANCE_WRITE_FORBIDDEN'
      using errcode = '42501';
  end if;

  if p_from_account_id = p_to_account_id then
    raise exception 'FINANCE_TRANSFER_ACCOUNTS_MUST_DIFFER'
      using errcode = '22023';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'FINANCE_TRANSFER_AMOUNT_MUST_BE_POSITIVE'
      using errcode = '22023';
  end if;

  v_amount := round(p_amount, 2);

  if v_amount <= 0 then
    raise exception 'FINANCE_TRANSFER_AMOUNT_MUST_BE_POSITIVE'
      using errcode = '22023';
  end if;

  if v_amount > 99999999999999.99 then
    raise exception 'FINANCE_AMOUNT_OUT_OF_RANGE'
      using errcode = '22003';
  end if;

  if v_description is null
     or char_length(v_description) < 2
     or char_length(v_description) > 500 then
    raise exception 'FINANCE_DESCRIPTION_INVALID'
      using errcode = '22023';
  end if;

  select
    fa.location_id,
    fa.currency_code
  into
    v_from_location_id,
    v_from_currency
  from public.finance_accounts as fa
  where fa.id = p_from_account_id
    and fa.tenant_id = p_tenant_id
    and fa.status = 'ACTIVE';

  if not found then
    raise exception 'FINANCE_FROM_ACCOUNT_NOT_AVAILABLE'
      using errcode = '22023';
  end if;

  select
    fa.location_id,
    fa.currency_code
  into
    v_to_location_id,
    v_to_currency
  from public.finance_accounts as fa
  where fa.id = p_to_account_id
    and fa.tenant_id = p_tenant_id
    and fa.status = 'ACTIVE';

  if not found then
    raise exception 'FINANCE_TO_ACCOUNT_NOT_AVAILABLE'
      using errcode = '22023';
  end if;

  if v_from_currency <> v_to_currency then
    raise exception 'FINANCE_TRANSFER_CURRENCY_MISMATCH'
      using errcode = '22023';
  end if;

  v_transaction_location_id :=
    case
      when v_from_location_id is not distinct from v_to_location_id
        then v_from_location_id
      else null
    end;

  insert into public.finance_transactions (
    tenant_id,
    location_id,
    transaction_type,
    occurred_at,
    description,
    source_type,
    created_by_user_id
  )
  values (
    p_tenant_id,
    v_transaction_location_id,
    'TRANSFER',
    coalesce(p_occurred_at, now()),
    v_description,
    'MANUAL',
    v_user_id
  )
  returning id
  into v_transaction_id;

  insert into public.finance_entries (
    tenant_id,
    transaction_id,
    account_id,
    amount
  )
  values
  (
    p_tenant_id,
    v_transaction_id,
    p_from_account_id,
    -v_amount
  ),
  (
    p_tenant_id,
    v_transaction_id,
    p_to_account_id,
    v_amount
  );

  insert into public.audit_logs (
    tenant_id,
    location_id,
    actor_user_id,
    action,
    entity_type,
    entity_id,
    metadata
  )
  values (
    p_tenant_id,
    v_transaction_location_id,
    v_user_id,
    'FINANCE_TRANSFER_CREATED',
    'finance_transaction',
    v_transaction_id,
    jsonb_build_object(
      'fromAccountId', p_from_account_id,
      'toAccountId', p_to_account_id,
      'amount', v_amount,
      'currencyCode', v_from_currency,
      'description', v_description
    )
  );

  return v_transaction_id;
end;
$$;

revoke all
  on function public.create_finance_transfer(
    uuid,
    uuid,
    uuid,
    numeric,
    text,
    timestamptz
  )
  from public;

revoke all
  on function public.create_finance_transfer(
    uuid,
    uuid,
    uuid,
    numeric,
    text,
    timestamptz
  )
  from anon;

grant execute
  on function public.create_finance_transfer(
    uuid,
    uuid,
    uuid,
    numeric,
    text,
    timestamptz
  )
  to authenticated, service_role;

comment on function public.create_finance_transfer(
  uuid,
  uuid,
  uuid,
  numeric,
  text,
  timestamptz
)
  is 'Creates an audited zero-sum transfer between two ACTIVE same-currency finance accounts when the authenticated user has finance.write permission.';