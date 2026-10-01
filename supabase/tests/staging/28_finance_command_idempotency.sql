begin;

insert into auth.users(id,aud,role,email,created_at,updated_at)
values(
  '28111111-1111-4111-8111-111111111111',
  'authenticated','authenticated','finance-idempotency@coost.test',now(),now()
);

insert into public.tenants(id,name,status)
values(
  '28222222-2222-4222-8222-222222222222',
  'Finance Idempotency Test','ACTIVE'
);

insert into public.memberships(id,tenant_id,user_id,status)
values(
  '28333333-3333-4333-8333-333333333333',
  '28222222-2222-4222-8222-222222222222',
  '28111111-1111-4111-8111-111111111111',
  'ACTIVE'
);

insert into public.roles(id,tenant_id,key,name,is_system)
values(
  '28444444-4444-4444-8444-444444444444',
  '28222222-2222-4222-8222-222222222222',
  'finance-idempotency-writer','Finance Idempotency Writer',true
);

insert into public.membership_roles(tenant_id,membership_id,role_id)
values(
  '28222222-2222-4222-8222-222222222222',
  '28333333-3333-4333-8333-333333333333',
  '28444444-4444-4444-8444-444444444444'
);

insert into public.role_permissions(tenant_id,role_id,permission_key)
values
('28222222-2222-4222-8222-222222222222','28444444-4444-4444-8444-444444444444','finance.read'),
('28222222-2222-4222-8222-222222222222','28444444-4444-4444-8444-444444444444','finance.write'),
('28222222-2222-4222-8222-222222222222','28444444-4444-4444-8444-444444444444','suppliers.read'),
('28222222-2222-4222-8222-222222222222','28444444-4444-4444-8444-444444444444','suppliers.pay');

insert into public.tenant_modules(tenant_id,module_key,enabled)
values
('28222222-2222-4222-8222-222222222222','finance',true),
('28222222-2222-4222-8222-222222222222','suppliers',true);

insert into public.finance_accounts(id,tenant_id,name,account_type,currency_code)
values
('28555555-5555-4555-8555-555555555551','28222222-2222-4222-8222-222222222222','Test Bank','BANK','TRY'),
('28555555-5555-4555-8555-555555555552','28222222-2222-4222-8222-222222222222','Test Cash','CASH','TRY');

insert into public.suppliers(id,tenant_id,name,status)
values(
  '28666666-6666-4666-8666-666666666666',
  '28222222-2222-4222-8222-222222222222',
  'Idempotency Supplier','ACTIVE'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '28111111-1111-4111-8111-111111111111',
  true
);

do $$
declare
  t uuid := '28222222-2222-4222-8222-222222222222';
  bank uuid := '28555555-5555-4555-8555-555555555551';
  cash uuid := '28555555-5555-4555-8555-555555555552';
  supplier uuid := '28666666-6666-4666-8666-666666666666';
  r_adjust uuid := '28aa0000-0000-4000-8000-000000000001';
  r_transfer uuid := '28aa0000-0000-4000-8000-000000000002';
  r_cashflow uuid := '28aa0000-0000-4000-8000-000000000003';
  r_payment uuid := '28aa0000-0000-4000-8000-000000000004';
  first_id uuid;
  second_id uuid;
begin
  first_id := public.create_finance_adjustment(
    t,bank,100,'Idempotent adjustment',null,r_adjust
  );
  second_id := public.create_finance_adjustment(
    t,bank,100,'Idempotent adjustment',null,r_adjust
  );

  if first_id <> r_adjust or second_id <> r_adjust then
    raise exception 'ADJUSTMENT_IDEMPOTENCY_RETURN_WRONG';
  end if;

  begin
    perform public.create_finance_adjustment(
      t,bank,101,'Idempotent adjustment',null,r_adjust
    );
    raise exception 'ADJUSTMENT_IDEMPOTENCY_CONFLICT_NOT_RAISED';
  exception
    when sqlstate '55000' then
      if sqlerrm <> 'FINANCE_IDEMPOTENCY_CONFLICT' then raise; end if;
  end;

  first_id := public.create_finance_transfer(
    t,bank,cash,40,'Idempotent transfer',null,r_transfer
  );
  second_id := public.create_finance_transfer(
    t,bank,cash,40,'Idempotent transfer',null,r_transfer
  );

  if first_id <> r_transfer or second_id <> r_transfer then
    raise exception 'TRANSFER_IDEMPOTENCY_RETURN_WRONG';
  end if;

  begin
    perform public.create_finance_transfer(
      t,bank,cash,41,'Idempotent transfer',null,r_transfer
    );
    raise exception 'TRANSFER_IDEMPOTENCY_CONFLICT_NOT_RAISED';
  exception
    when sqlstate '55000' then
      if sqlerrm <> 'FINANCE_IDEMPOTENCY_CONFLICT' then raise; end if;
  end;

  first_id := public.create_finance_cashflow(
    t,cash,'INCOME',75,'Idempotent cashflow',null,r_cashflow
  );
  second_id := public.create_finance_cashflow(
    t,cash,'INCOME',75,'Idempotent cashflow',null,r_cashflow
  );

  if first_id <> r_cashflow or second_id <> r_cashflow then
    raise exception 'CASHFLOW_IDEMPOTENCY_RETURN_WRONG';
  end if;

  begin
    perform public.create_finance_cashflow(
      t,cash,'INCOME',76,'Idempotent cashflow',null,r_cashflow
    );
    raise exception 'CASHFLOW_IDEMPOTENCY_CONFLICT_NOT_RAISED';
  exception
    when sqlstate '55000' then
      if sqlerrm <> 'FINANCE_IDEMPOTENCY_CONFLICT' then raise; end if;
  end;

  first_id := public.create_supplier_payment(
    t,supplier,bank,25,'Idempotent supplier payment',null,r_payment
  );
  second_id := public.create_supplier_payment(
    t,supplier,bank,25,'Idempotent supplier payment',null,r_payment
  );

  if first_id <> r_payment or second_id <> r_payment then
    raise exception 'SUPPLIER_PAYMENT_IDEMPOTENCY_RETURN_WRONG';
  end if;

  begin
    perform public.create_supplier_payment(
      t,supplier,bank,26,'Idempotent supplier payment',null,r_payment
    );
    raise exception 'SUPPLIER_PAYMENT_IDEMPOTENCY_CONFLICT_NOT_RAISED';
  exception
    when sqlstate '55000' then
      if sqlerrm <> 'SUPPLIER_PAYMENT_IDEMPOTENCY_CONFLICT' then raise; end if;
  end;
end
$$;

reset role;

do $$
declare
  t uuid := '28222222-2222-4222-8222-222222222222';
begin
  if (select count(*) from public.finance_transactions where tenant_id = t) <> 4 then
    raise exception 'IDEMPOTENCY_TRANSACTION_COUNT_WRONG';
  end if;

  if (select count(*) from public.finance_entries where tenant_id = t) <> 5 then
    raise exception 'IDEMPOTENCY_ENTRY_COUNT_WRONG';
  end if;

  if (select count(*) from public.supplier_payments where tenant_id = t) <> 1 then
    raise exception 'IDEMPOTENCY_SUPPLIER_PAYMENT_COUNT_WRONG';
  end if;

  if (select count(*) from public.supplier_ledger_entries where tenant_id = t) <> 1 then
    raise exception 'IDEMPOTENCY_SUPPLIER_LEDGER_COUNT_WRONG';
  end if;

  if (select count(*) from public.audit_logs where tenant_id = t
      and action = 'FINANCE_ADJUSTMENT_CREATED') <> 1 then
    raise exception 'IDEMPOTENCY_ADJUSTMENT_AUDIT_COUNT_WRONG';
  end if;

  if (select count(*) from public.audit_logs where tenant_id = t
      and action = 'FINANCE_TRANSFER_CREATED') <> 1 then
    raise exception 'IDEMPOTENCY_TRANSFER_AUDIT_COUNT_WRONG';
  end if;

  if (select count(*) from public.audit_logs where tenant_id = t
      and action = 'FINANCE_INCOME_CREATED') <> 1 then
    raise exception 'IDEMPOTENCY_CASHFLOW_AUDIT_COUNT_WRONG';
  end if;

  if (select count(*) from public.audit_logs where tenant_id = t
      and action = 'SUPPLIER_PAYMENT_CREATED') <> 1 then
    raise exception 'IDEMPOTENCY_PAYMENT_AUDIT_COUNT_WRONG';
  end if;
end
$$;

rollback;

do $$
begin
  if exists(
    select 1 from auth.users
    where id = '28111111-1111-4111-8111-111111111111'
  ) or exists(
    select 1 from public.tenants
    where id = '28222222-2222-4222-8222-222222222222'
  ) then
    raise exception 'FINANCE_IDEMPOTENCY_ROLLBACK_RESIDUALS';
  end if;
end
$$;

select 'PASS - FINANCE COMMAND IDEMPOTENCY' as result;
