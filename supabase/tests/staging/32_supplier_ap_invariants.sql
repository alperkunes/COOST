begin;

insert into auth.users(id,aud,role,email,created_at,updated_at)
values(
  '32111111-1111-4111-8111-111111111111',
  'authenticated','authenticated','supplier-ap-invariant@coost.test',now(),now()
);

insert into public.tenants(id,name,status)
values(
  '32222222-2222-4222-8222-222222222222',
  'Supplier AP Invariant Test','ACTIVE'
);

insert into public.memberships(id,tenant_id,user_id,status)
values(
  '32333333-3333-4333-8333-333333333333',
  '32222222-2222-4222-8222-222222222222',
  '32111111-1111-4111-8111-111111111111',
  'ACTIVE'
);

insert into public.roles(id,tenant_id,key,name,is_system)
values(
  '32444444-4444-4444-8444-444444444444',
  '32222222-2222-4222-8222-222222222222',
  'supplier-ap-invariant-writer',
  'Supplier AP Invariant Writer',
  true
);

insert into public.membership_roles(tenant_id,membership_id,role_id)
values(
  '32222222-2222-4222-8222-222222222222',
  '32333333-3333-4333-8333-333333333333',
  '32444444-4444-4444-8444-444444444444'
);

insert into public.role_permissions(tenant_id,role_id,permission_key)
values
('32222222-2222-4222-8222-222222222222','32444444-4444-4444-8444-444444444444','suppliers.read'),
('32222222-2222-4222-8222-222222222222','32444444-4444-4444-8444-444444444444','suppliers.pay'),
('32222222-2222-4222-8222-222222222222','32444444-4444-4444-8444-444444444444','finance.write');

insert into public.tenant_modules(tenant_id,module_key,enabled)
values
('32222222-2222-4222-8222-222222222222','suppliers',true),
('32222222-2222-4222-8222-222222222222','finance',true);

insert into public.finance_accounts(
  id,tenant_id,name,account_type,currency_code,status
)
values(
  '32555555-5555-4555-8555-555555555555',
  '32222222-2222-4222-8222-222222222222',
  'Supplier Test Bank',
  'BANK',
  'TRY',
  'ACTIVE'
);

insert into public.suppliers(id,tenant_id,name,status)
values(
  '32666666-6666-4666-8666-666666666666',
  '32222222-2222-4222-8222-222222222222',
  'Supplier AP Test',
  'ACTIVE'
);

insert into public.supplier_ledger_entries(
  tenant_id,supplier_id,entry_type,currency_code,amount,occurred_at,
  description,source_type,source_id,created_by_user_id
)
values(
  '32222222-2222-4222-8222-222222222222',
  '32666666-6666-4666-8666-666666666666',
  'ADJUSTMENT','TRY',50,now(),
  'Opening adjustment','TEST_ADJUSTMENT',null,
  '32111111-1111-4111-8111-111111111111'
);

do $$
begin
  begin
    update public.suppliers
    set status='PASSIVE'
    where id='32666666-6666-4666-8666-666666666666';
    raise exception 'SUPPLIER_WITH_OPEN_BALANCE_DEACTIVATED';
  exception
    when sqlstate '22023' then
      if sqlerrm <> 'SUPPLIER_NON_ZERO_BALANCE' then raise; end if;
  end;
end
$$;

insert into public.supplier_ledger_entries(
  tenant_id,supplier_id,entry_type,currency_code,amount,occurred_at,
  description,source_type,source_id,created_by_user_id
)
values(
  '32222222-2222-4222-8222-222222222222',
  '32666666-6666-4666-8666-666666666666',
  'ADJUSTMENT','TRY',-50,now(),
  'Closing adjustment','TEST_ADJUSTMENT',null,
  '32111111-1111-4111-8111-111111111111'
);

update public.suppliers
set status='PASSIVE'
where id='32666666-6666-4666-8666-666666666666';

update public.suppliers
set status='ACTIVE'
where id='32666666-6666-4666-8666-666666666666';

do $$
begin
  begin
    update public.suppliers
    set tenant_id='32222222-2222-4222-8222-222222222223'
    where id='32666666-6666-4666-8666-666666666666';
    raise exception 'SUPPLIER_TENANT_ID_CHANGED';
  exception
    when sqlstate '55000' then
      if sqlerrm <> 'SUPPLIER_IDENTITY_IMMUTABLE' then raise; end if;
  end;
end
$$;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '32111111-1111-4111-8111-111111111111',
  true
);

select public.create_supplier_payment(
  '32222222-2222-4222-8222-222222222222',
  '32666666-6666-4666-8666-666666666666',
  '32555555-5555-4555-8555-555555555555',
  25,
  'Invariant supplier payment',
  '2026-10-01T12:00:00Z',
  '32777777-7777-4777-8777-777777777777'
);

reset role;

set constraints all immediate;
set constraints all deferred;

do $$
declare
  p public.supplier_payments%rowtype;
begin
  select *
  into strict p
  from public.supplier_payments
  where id='32777777-7777-4777-8777-777777777777';

  if p.amount <> 25
     or p.currency_code <> 'TRY'
     or (
       select count(*)
       from public.finance_transactions ft
       where ft.tenant_id=p.tenant_id
         and ft.source_type='SUPPLIER_PAYMENT'
         and ft.source_id=p.id
     ) <> 1
     or (
       select count(*)
       from public.finance_entries fe
       where fe.tenant_id=p.tenant_id
         and fe.transaction_id=p.finance_transaction_id
         and fe.account_id=p.finance_account_id
         and fe.amount=-p.amount
     ) <> 1
     or (
       select count(*)
       from public.supplier_ledger_entries sle
       where sle.tenant_id=p.tenant_id
         and sle.source_type='SUPPLIER_PAYMENT'
         and sle.source_id=p.id
         and sle.entry_type='PAYMENT'
         and sle.amount=-p.amount
     ) <> 1 then
    raise exception 'VALID_SUPPLIER_PAYMENT_SHAPE_WRONG';
  end if;
end
$$;

do $$
begin
  begin
    insert into public.finance_transactions(
      id,tenant_id,transaction_type,occurred_at,description,
      source_type,source_id,created_by_user_id
    )
    values(
      '32888888-8888-4888-8888-888888888881',
      '32222222-2222-4222-8222-222222222222',
      'EXPENSE',now(),'Unrelated expense',
      'MANUAL',null,
      '32111111-1111-4111-8111-111111111111'
    );

    insert into public.finance_entries(
      tenant_id,transaction_id,account_id,amount
    )
    values(
      '32222222-2222-4222-8222-222222222222',
      '32888888-8888-4888-8888-888888888881',
      '32555555-5555-4555-8555-555555555555',
      -5
    );

    insert into public.supplier_payments(
      id,tenant_id,supplier_id,finance_account_id,finance_transaction_id,
      amount,currency_code,occurred_at,description,created_by_user_id
    )
    values(
      '32888888-8888-4888-8888-888888888882',
      '32222222-2222-4222-8222-222222222222',
      '32666666-6666-4666-8666-666666666666',
      '32555555-5555-4555-8555-555555555555',
      '32888888-8888-4888-8888-888888888881',
      5,'TRY',now(),'Invalid direct payment',
      '32111111-1111-4111-8111-111111111111'
    );

    set constraints supplier_payment_shape_on_payment immediate;
    raise exception 'UNBOUND_SUPPLIER_PAYMENT_ALLOWED';
  exception
    when check_violation then
      if sqlerrm <> 'SUPPLIER_PAYMENT_FINANCE_INVALID' then raise; end if;
  end;

  set constraints all deferred;
end
$$;

do $$
begin
  begin
    insert into public.finance_transactions(
      id,tenant_id,transaction_type,occurred_at,description,
      source_type,source_id,created_by_user_id
    )
    values(
      '32888888-8888-4888-8888-888888888883',
      '32222222-2222-4222-8222-222222222222',
      'EXPENSE',now(),'Orphan supplier payment finance',
      'SUPPLIER_PAYMENT',
      '32888888-8888-4888-8888-888888888884',
      '32111111-1111-4111-8111-111111111111'
    );

    insert into public.finance_entries(
      tenant_id,transaction_id,account_id,amount
    )
    values(
      '32222222-2222-4222-8222-222222222222',
      '32888888-8888-4888-8888-888888888883',
      '32555555-5555-4555-8555-555555555555',
      -5
    );

    set constraints supplier_payment_shape_on_finance_transaction immediate;
    raise exception 'ORPHAN_SUPPLIER_PAYMENT_FINANCE_ALLOWED';
  exception
    when check_violation then
      if sqlerrm <> 'SUPPLIER_PAYMENT_NOT_FOUND' then raise; end if;
  end;

  set constraints all deferred;
end
$$;

do $$
begin
  begin
    insert into public.supplier_ledger_entries(
      tenant_id,supplier_id,entry_type,currency_code,amount,occurred_at,
      description,source_type,source_id,created_by_user_id
    )
    values(
      '32222222-2222-4222-8222-222222222222',
      '32666666-6666-4666-8666-666666666666',
      'PAYMENT','TRY',-5,now(),
      'Orphan supplier payment ledger',
      'SUPPLIER_PAYMENT',
      '32888888-8888-4888-8888-888888888885',
      '32111111-1111-4111-8111-111111111111'
    );

    set constraints supplier_payment_shape_on_supplier_ledger immediate;
    raise exception 'ORPHAN_SUPPLIER_PAYMENT_LEDGER_ALLOWED';
  exception
    when check_violation then
      if sqlerrm <> 'SUPPLIER_PAYMENT_NOT_FOUND' then raise; end if;
  end;

  set constraints all deferred;
end
$$;

do $$
begin
  begin
    insert into public.finance_transactions(
      id,tenant_id,transaction_type,occurred_at,description,
      source_type,source_id,created_by_user_id
    )
    values
    (
      '32888888-8888-4888-8888-888888888886',
      '32222222-2222-4222-8222-222222222222',
      'EXPENSE',now(),'Duplicate source 1',
      'SUPPLIER_PAYMENT',
      '32888888-8888-4888-8888-888888888888',
      '32111111-1111-4111-8111-111111111111'
    ),
    (
      '32888888-8888-4888-8888-888888888887',
      '32222222-2222-4222-8222-222222222222',
      'EXPENSE',now(),'Duplicate source 2',
      'SUPPLIER_PAYMENT',
      '32888888-8888-4888-8888-888888888888',
      '32111111-1111-4111-8111-111111111111'
    );

    raise exception 'DUPLICATE_SUPPLIER_PAYMENT_FINANCE_SOURCE_ALLOWED';
  exception
    when unique_violation then null;
  end;
end
$$;

do $$
begin
  begin
    insert into public.supplier_ledger_entries(
      tenant_id,supplier_id,entry_type,currency_code,amount,occurred_at,
      description,source_type,source_id,created_by_user_id
    )
    values
    (
      '32222222-2222-4222-8222-222222222222',
      '32666666-6666-4666-8666-666666666666',
      'INVOICE','TRY',10,now(),'Duplicate invoice source 1',
      'PURCHASE_INVOICE',
      '32888888-8888-4888-8888-888888888889',
      '32111111-1111-4111-8111-111111111111'
    ),
    (
      '32222222-2222-4222-8222-222222222222',
      '32666666-6666-4666-8666-666666666666',
      'INVOICE','TRY',10,now(),'Duplicate invoice source 2',
      'PURCHASE_INVOICE',
      '32888888-8888-4888-8888-888888888889',
      '32111111-1111-4111-8111-111111111111'
    );

    raise exception 'DUPLICATE_PURCHASE_LEDGER_SOURCE_ALLOWED';
  exception
    when unique_violation then null;
  end;
end
$$;

create function pg_temp.expect_supplier_truncate_blocked(p_command text)
returns void
language plpgsql
as $$
begin
  execute p_command;
  raise exception 'SUPPLIER_TRUNCATE_ALLOWED: %', p_command;
exception
  when sqlstate '55000' then null;
end;
$$;

select pg_temp.expect_supplier_truncate_blocked(
  'truncate table public.supplier_payments'
);

select pg_temp.expect_supplier_truncate_blocked(
  'truncate table public.suppliers cascade'
);

select pg_temp.expect_supplier_truncate_blocked(
  'truncate table public.supplier_ledger_entries'
);

rollback;

do $$
begin
  if exists(
    select 1
    from auth.users
    where id='32111111-1111-4111-8111-111111111111'
  ) or exists(
    select 1
    from public.tenants
    where id='32222222-2222-4222-8222-222222222222'
  ) then
    raise exception 'SUPPLIER_AP_INVARIANT_TEST_RESIDUALS';
  end if;
end
$$;

select 'PASS - SUPPLIER AP INVARIANTS' as result;
