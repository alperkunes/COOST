-- COOST Finance Overview RPC v1
--
-- Purpose:
-- Return finance account balances and recent transactions
-- without downloading the full ledger to the browser.

create or replace function public.get_finance_overview(
  p_tenant_id uuid,
  p_recent_limit integer default 20
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_recent_limit integer :=
    least(
      greatest(coalesce(p_recent_limit, 20), 1),
      100
    );

  v_accounts jsonb;
  v_recent_transactions jsonb;
begin
  if not private.is_module_enabled(
    p_tenant_id,
    'finance'
  ) then
    raise exception 'FINANCE_MODULE_NOT_AVAILABLE'
      using errcode = '42501';
  end if;

  if not private.has_permission(
    p_tenant_id,
    'finance.read'
  ) then
    raise exception 'FINANCE_READ_FORBIDDEN'
      using errcode = '42501';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', account_data.id,
        'name', account_data.name,
        'accountType', account_data.account_type,
        'currencyCode', account_data.currency_code,
        'status', account_data.status,
        'balance', account_data.balance
      )
      order by
        account_data.account_type,
        account_data.name,
        account_data.id
    ),
    '[]'::jsonb
  )
  into v_accounts
  from (
    select
      fa.id,
      fa.name,
      fa.account_type,
      fa.currency_code,
      fa.status,
      coalesce(
        sum(fe.amount),
        0
      ) as balance
    from public.finance_accounts as fa
    left join public.finance_entries as fe
      on fe.tenant_id = fa.tenant_id
     and fe.account_id = fa.id
    where fa.tenant_id = p_tenant_id
      and fa.status = 'ACTIVE'
    group by
      fa.id,
      fa.name,
      fa.account_type,
      fa.currency_code,
      fa.status
  ) as account_data;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', transaction_data.id,
        'transactionType',
          transaction_data.transaction_type,
        'occurredAt',
          transaction_data.occurred_at,
        'description',
          transaction_data.description,
        'sourceType',
          transaction_data.source_type,
        'sourceId',
          transaction_data.source_id,
        'entries',
          transaction_data.entries
      )
      order by
        transaction_data.occurred_at desc,
        transaction_data.id desc
    ),
    '[]'::jsonb
  )
  into v_recent_transactions
  from (
    select
      ft.id,
      ft.transaction_type,
      ft.occurred_at,
      ft.description,
      ft.source_type,
      ft.source_id,
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'id', fe.id,
              'accountId', fe.account_id,
              'accountName', fa.name,
              'accountType', fa.account_type,
              'currencyCode', fa.currency_code,
              'amount', fe.amount
            )
            order by
              fe.created_at,
              fe.id
          )
          from public.finance_entries as fe
          inner join public.finance_accounts as fa
            on fa.tenant_id = fe.tenant_id
           and fa.id = fe.account_id
          where fe.tenant_id = ft.tenant_id
            and fe.transaction_id = ft.id
        ),
        '[]'::jsonb
      ) as entries
    from public.finance_transactions as ft
    where ft.tenant_id = p_tenant_id
    order by
      ft.occurred_at desc,
      ft.id desc
    limit v_recent_limit
  ) as transaction_data;

  return jsonb_build_object(
    'tenantId', p_tenant_id,
    'accounts', v_accounts,
    'recentTransactions', v_recent_transactions
  );
end;
$$;

revoke all
  on function public.get_finance_overview(uuid, integer)
  from public;

revoke all
  on function public.get_finance_overview(uuid, integer)
  from anon;

grant execute
  on function public.get_finance_overview(uuid, integer)
  to authenticated, service_role;

comment on function public.get_finance_overview(uuid, integer)
  is 'Returns authorized finance account balances and recent ledger transactions for one tenant.';