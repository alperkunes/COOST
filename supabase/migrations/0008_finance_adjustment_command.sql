-- COOST Finance Adjustment Command v1
--
-- Purpose:
-- Create controlled manual balance adjustments without
-- allowing browser clients to write finance ledger tables directly.

create or replace function public.create_finance_adjustment(
  p_tenant_id uuid,
  p_account_id uuid,
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
  v_location_id uuid;
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

  if p_amount is null or p_amount = 0 then
    raise exception 'FINANCE_AMOUNT_MUST_BE_NON_ZERO'
      using errcode = '22023';
  end if;

  v_amount := round(p_amount, 2);

  if v_amount = 0 then
    raise exception 'FINANCE_AMOUNT_MUST_BE_NON_ZERO'
      using errcode = '22023';
  end if;

  if abs(v_amount) > 99999999999999.99 then
    raise exception 'FINANCE_AMOUNT_OUT_OF_RANGE'
      using errcode = '22003';
  end if;

  if v_description is null
     or char_length(v_description) < 2
     or char_length(v_description) > 500 then
    raise exception 'FINANCE_DESCRIPTION_INVALID'
      using errcode = '22023';
  end if;

  select fa.location_id
  into v_location_id
  from public.finance_accounts as fa
  where fa.id = p_account_id
    and fa.tenant_id = p_tenant_id
    and fa.status = 'ACTIVE';

  if not found then
    raise exception 'FINANCE_ACCOUNT_NOT_AVAILABLE'
      using errcode = '22023';
  end if;

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
    v_location_id,
    'ADJUSTMENT',
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
  values (
    p_tenant_id,
    v_transaction_id,
    p_account_id,
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
    v_location_id,
    v_user_id,
    'FINANCE_ADJUSTMENT_CREATED',
    'finance_transaction',
    v_transaction_id,
    jsonb_build_object(
      'accountId', p_account_id,
      'amount', v_amount,
      'description', v_description
    )
  );

  return v_transaction_id;
end;
$$;

revoke all
  on function public.create_finance_adjustment(
    uuid,
    uuid,
    numeric,
    text,
    timestamptz
  )
  from public;

revoke all
  on function public.create_finance_adjustment(
    uuid,
    uuid,
    numeric,
    text,
    timestamptz
  )
  from anon;

grant execute
  on function public.create_finance_adjustment(
    uuid,
    uuid,
    numeric,
    text,
    timestamptz
  )
  to authenticated, service_role;

comment on function public.create_finance_adjustment(
  uuid,
  uuid,
  numeric,
  text,
  timestamptz
)
  is 'Creates an audited finance adjustment for an ACTIVE tenant account when the authenticated user has finance.write permission.';