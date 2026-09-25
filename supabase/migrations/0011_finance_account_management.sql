-- Account lifecycle commands. Balances remain derived from immutable entries.
-- Serialize ALL ledger writers with account deactivation, including older RPCs.
create or replace function private.guard_finance_entry_account()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_status text;
begin
  select status into v_status from public.finance_accounts
  where id = new.account_id and tenant_id = new.tenant_id
  for share;
  -- Missing / cross-tenant accounts are still rejected by the existing FK.
  if found and v_status <> 'ACTIVE' then
    raise exception 'FINANCE_ACCOUNT_NOT_AVAILABLE' using errcode = '22023';
  end if;
  return new;
end;
$$;
revoke all on function private.guard_finance_entry_account() from public, anon, authenticated;
create trigger finance_entry_active_account
  before insert on public.finance_entries
  for each row execute function private.guard_finance_entry_account();

create or replace function public.create_finance_account(
  p_tenant_id uuid, p_name text, p_account_type text, p_currency_code text,
  p_location_id uuid default null
)
returns uuid language plpgsql volatile security definer set search_path = '' as $$
declare
  v_user_id uuid := auth.uid();
  v_name text := trim(p_name);
  v_currency text := upper(trim(p_currency_code));
  v_id uuid;
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
  if v_name is null or char_length(v_name) not between 2 and 120 then
    raise exception 'FINANCE_ACCOUNT_NAME_INVALID' using errcode = '22023';
  end if;
  if p_account_type is null or p_account_type not in ('CASH', 'BANK') then
    raise exception 'FINANCE_ACCOUNT_TYPE_INVALID' using errcode = '22023';
  end if;
  if v_currency is null or v_currency !~ '^[A-Z]{3}$' then
    raise exception 'FINANCE_ACCOUNT_CURRENCY_INVALID' using errcode = '22023';
  end if;
  if p_location_id is not null then
    perform 1 from public.locations
    where id = p_location_id and tenant_id = p_tenant_id and status = 'ACTIVE'
    for share;
    if not found then
      raise exception 'FINANCE_LOCATION_NOT_AVAILABLE' using errcode = '22023';
    end if;
  end if;
  begin
    insert into public.finance_accounts (tenant_id, name, account_type, currency_code, location_id, status)
    values (p_tenant_id, v_name, p_account_type, v_currency, p_location_id, 'ACTIVE')
    returning id into v_id;
  exception when unique_violation then
    raise exception 'FINANCE_ACCOUNT_NAME_EXISTS' using errcode = '23505';
  end;
  insert into public.audit_logs (tenant_id, location_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (p_tenant_id, p_location_id, v_user_id, 'FINANCE_ACCOUNT_CREATED', 'finance_account', v_id,
    jsonb_build_object('accountId', v_id, 'name', v_name, 'accountType', p_account_type,
      'currencyCode', v_currency, 'locationId', p_location_id));
  return v_id;
end;
$$;

create or replace function public.update_finance_account(
  p_tenant_id uuid, p_account_id uuid, p_name text, p_status text
)
returns uuid language plpgsql volatile security definer set search_path = '' as $$
declare
  v_user_id uuid := auth.uid();
  v_name text := trim(p_name);
  v_account public.finance_accounts%rowtype;
  v_balance numeric;
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
  if v_name is null or char_length(v_name) not between 2 and 120 then
    raise exception 'FINANCE_ACCOUNT_NAME_INVALID' using errcode = '22023';
  end if;
  if p_status is null or p_status not in ('ACTIVE', 'PASSIVE') then
    raise exception 'FINANCE_ACCOUNT_STATUS_INVALID' using errcode = '22023';
  end if;
  select * into v_account from public.finance_accounts
  where id = p_account_id and tenant_id = p_tenant_id for update;
  if not found then
    raise exception 'FINANCE_ACCOUNT_NOT_AVAILABLE' using errcode = '22023';
  end if;
  if v_account.name = v_name and v_account.status = p_status then
    raise exception 'FINANCE_ACCOUNT_NO_CHANGES' using errcode = '22023';
  end if;
  if v_account.status = 'ACTIVE' and p_status = 'PASSIVE' then
    select coalesce(sum(amount), 0) into v_balance from public.finance_entries
    where tenant_id = p_tenant_id and account_id = p_account_id;
    if v_balance <> 0 then
      raise exception 'FINANCE_ACCOUNT_NON_ZERO_BALANCE' using errcode = '22023';
    end if;
  end if;
  begin
    update public.finance_accounts set name = v_name, status = p_status, updated_at = now()
    where id = p_account_id and tenant_id = p_tenant_id;
  exception when unique_violation then
    raise exception 'FINANCE_ACCOUNT_NAME_EXISTS' using errcode = '23505';
  end;
  insert into public.audit_logs (tenant_id, location_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (p_tenant_id, v_account.location_id, v_user_id, 'FINANCE_ACCOUNT_UPDATED', 'finance_account', p_account_id,
    jsonb_build_object('accountId', p_account_id, 'oldName', v_account.name, 'newName', v_name,
      'oldStatus', v_account.status, 'newStatus', p_status));
  return p_account_id;
end;
$$;

create or replace function public.get_finance_account_management(p_tenant_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_accounts jsonb;
begin
  if auth.uid() is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;
  if not private.is_module_enabled(p_tenant_id, 'finance') then
    raise exception 'FINANCE_MODULE_NOT_AVAILABLE' using errcode = '42501';
  end if;
  if not private.has_permission(p_tenant_id, 'finance.read') then
    raise exception 'FINANCE_READ_FORBIDDEN' using errcode = '42501';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', a.id, 'name', a.name, 'accountType', a.account_type, 'currencyCode', a.currency_code,
    'status', a.status, 'locationId', a.location_id, 'locationName', a.location_name, 'balance', a.balance
  ) order by a.status, a.name, a.id), '[]'::jsonb) into v_accounts
  from (
    select fa.id, fa.name, fa.account_type, fa.currency_code, fa.status, fa.location_id,
      l.name as location_name, coalesce(sum(fe.amount), 0) as balance
    from public.finance_accounts fa
    left join public.locations l on l.id = fa.location_id and l.tenant_id = fa.tenant_id
    left join public.finance_entries fe on fe.account_id = fa.id and fe.tenant_id = fa.tenant_id
    where fa.tenant_id = p_tenant_id
    group by fa.id, l.name
  ) a;
  return jsonb_build_object('tenantId', p_tenant_id, 'accounts', v_accounts);
end;
$$;

revoke all on function public.create_finance_account(uuid, text, text, text, uuid) from public, anon;
revoke all on function public.update_finance_account(uuid, uuid, text, text) from public, anon;
revoke all on function public.get_finance_account_management(uuid) from public, anon;
grant execute on function public.create_finance_account(uuid, text, text, text, uuid) to authenticated, service_role;
grant execute on function public.update_finance_account(uuid, uuid, text, text) to authenticated, service_role;
grant execute on function public.get_finance_account_management(uuid) to authenticated, service_role;
