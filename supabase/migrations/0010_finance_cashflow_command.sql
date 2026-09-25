-- Controlled manual income/expense; browser ledger writes remain revoked.
create or replace function public.create_finance_cashflow(
  p_tenant_id uuid,
  p_account_id uuid,
  p_transaction_type text,
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
  v_amount numeric;
  v_signed_amount numeric;
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
  if p_transaction_type is null or p_transaction_type not in ('INCOME', 'EXPENSE') then
    raise exception 'FINANCE_CASHFLOW_TYPE_INVALID' using errcode = '22023';
  end if;
  if p_amount is null or p_amount <= 0 or p_amount::text in ('NaN', 'Infinity', '-Infinity') then
    raise exception 'FINANCE_CASHFLOW_AMOUNT_MUST_BE_POSITIVE' using errcode = '22023';
  end if;
  v_amount := round(p_amount, 2);
  if v_amount <= 0 then
    raise exception 'FINANCE_CASHFLOW_AMOUNT_MUST_BE_POSITIVE' using errcode = '22023';
  end if;
  if v_amount > 99999999999999.99 then
    raise exception 'FINANCE_AMOUNT_OUT_OF_RANGE' using errcode = '22003';
  end if;
  if v_description is null or char_length(v_description) not between 2 and 500 then
    raise exception 'FINANCE_DESCRIPTION_INVALID' using errcode = '22023';
  end if;

  select fa.location_id into v_location_id
  from public.finance_accounts as fa
  where fa.id = p_account_id and fa.tenant_id = p_tenant_id and fa.status = 'ACTIVE'
  for share;
  if not found then
    raise exception 'FINANCE_ACCOUNT_NOT_AVAILABLE' using errcode = '22023';
  end if;

  v_signed_amount := case when p_transaction_type = 'INCOME' then v_amount else -v_amount end;
  insert into public.finance_transactions (
    tenant_id, location_id, transaction_type, occurred_at, description, source_type, created_by_user_id
  ) values (
    p_tenant_id, v_location_id, p_transaction_type, coalesce(p_occurred_at, now()), v_description, 'MANUAL', v_user_id
  ) returning id into v_transaction_id;

  insert into public.finance_entries (tenant_id, transaction_id, account_id, amount)
  values (p_tenant_id, v_transaction_id, p_account_id, v_signed_amount);

  insert into public.audit_logs (
    tenant_id, location_id, actor_user_id, action, entity_type, entity_id, metadata
  ) values (
    p_tenant_id, v_location_id, v_user_id,
    case when p_transaction_type = 'INCOME' then 'FINANCE_INCOME_CREATED' else 'FINANCE_EXPENSE_CREATED' end,
    'finance_transaction', v_transaction_id,
    jsonb_build_object(
      'accountId', p_account_id, 'transactionType', p_transaction_type,
      'amount', v_amount, 'signedAmount', v_signed_amount, 'description', v_description
    )
  );
  return v_transaction_id;
end;
$$;

revoke all on function public.create_finance_cashflow(uuid, uuid, text, numeric, text, timestamptz) from public, anon;
grant execute on function public.create_finance_cashflow(uuid, uuid, text, numeric, text, timestamptz) to authenticated, service_role;

comment on function public.create_finance_cashflow(uuid, uuid, text, numeric, text, timestamptz)
  is 'Creates audited manual income or expense for an ACTIVE tenant account with finance.write authorization.';
