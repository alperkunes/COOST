begin;

insert into public.tenants(id,name,status)
values('31111111-1111-4111-8111-111111111111','Costing Invariant Test','ACTIVE');

insert into public.inventory_items(id,tenant_id,name,base_unit,status)
values
('31222222-2222-4222-8222-222222222221','31111111-1111-4111-8111-111111111111','Active Ingredient','GRAM','ACTIVE'),
('31222222-2222-4222-8222-222222222222','31111111-1111-4111-8111-111111111111','Passive Ingredient','GRAM','PASSIVE');

insert into public.recipes(id,tenant_id,name,code,currency_code,portions,status)
values
('31333333-3333-4333-8333-333333333331','31111111-1111-4111-8111-111111111111','Active Recipe','ACTIVE-RECIPE','TRY',1,'ACTIVE'),
('31333333-3333-4333-8333-333333333332','31111111-1111-4111-8111-111111111111','Passive Recipe','PASSIVE-RECIPE','TRY',1,'PASSIVE'),
('31333333-3333-4333-8333-333333333333','31111111-1111-4111-8111-111111111111','Menu Recipe','MENU-RECIPE','TRY',1,'ACTIVE'),
('31333333-3333-4333-8333-333333333334','31111111-1111-4111-8111-111111111111','Cycle A','CYCLE-A','TRY',1,'ACTIVE'),
('31333333-3333-4333-8333-333333333335','31111111-1111-4111-8111-111111111111','Cycle B','CYCLE-B','TRY',1,'ACTIVE');

insert into public.recipe_lines(tenant_id,recipe_id,inventory_item_id,quantity_base,line_no)
values(
  '31111111-1111-4111-8111-111111111111',
  '31333333-3333-4333-8333-333333333331',
  '31222222-2222-4222-8222-222222222221',
  100,
  1
);

do $$
begin
  begin
    insert into public.recipe_lines(tenant_id,recipe_id,inventory_item_id,quantity_base,line_no)
    values('31111111-1111-4111-8111-111111111111','31333333-3333-4333-8333-333333333331','31222222-2222-4222-8222-222222222222',1,2);
    raise exception 'PASSIVE_RECIPE_INGREDIENT_ALLOWED';
  exception when sqlstate '22023' then
    if sqlerrm <> 'COSTING_ITEM_NOT_AVAILABLE' then raise; end if;
  end;
end $$;

do $$
begin
  begin
    update public.inventory_items set status='PASSIVE'
    where id='31222222-2222-4222-8222-222222222221';
    raise exception 'ACTIVE_RECIPE_ITEM_DEACTIVATED';
  exception when sqlstate '22023' then
    if sqlerrm <> 'INVENTORY_ITEM_IN_ACTIVE_RECIPE' then raise; end if;
  end;
end $$;

update public.recipes set status='PASSIVE'
where id='31333333-3333-4333-8333-333333333331';

update public.inventory_items set status='PASSIVE'
where id='31222222-2222-4222-8222-222222222221';

do $$
begin
  begin
    update public.recipes set status='ACTIVE'
    where id='31333333-3333-4333-8333-333333333331';
    raise exception 'RECIPE_REACTIVATED_WITH_PASSIVE_ITEM';
  exception when sqlstate '22023' then
    if sqlerrm <> 'COSTING_ITEM_NOT_AVAILABLE' then raise; end if;
  end;
end $$;

update public.inventory_items set status='ACTIVE'
where id='31222222-2222-4222-8222-222222222221';

update public.recipes set status='ACTIVE'
where id='31333333-3333-4333-8333-333333333331';

insert into public.menu_products(
  id,tenant_id,name,recipe_id,currency_code,sale_price_gross,sales_tax_rate,cost_method,status
)
values(
  '31444444-4444-4444-8444-444444444441',
  '31111111-1111-4111-8111-111111111111',
  'Active Menu Product',
  '31333333-3333-4333-8333-333333333333',
  'TRY',100,20,'WEIGHTED_PURCHASE','ACTIVE'
);

do $$
begin
  begin
    update public.recipes set status='PASSIVE'
    where id='31333333-3333-4333-8333-333333333333';
    raise exception 'ACTIVE_MENU_RECIPE_DEACTIVATED';
  exception when sqlstate '22023' then
    if sqlerrm <> 'RECIPE_MENU_PRODUCT_IN_USE' then raise; end if;
  end;
end $$;

insert into public.menu_products(
  id,tenant_id,name,recipe_id,currency_code,sale_price_gross,sales_tax_rate,cost_method,status
)
values(
  '31444444-4444-4444-8444-444444444442',
  '31111111-1111-4111-8111-111111111111',
  'Passive Menu Product',
  '31333333-3333-4333-8333-333333333332',
  'TRY',100,20,'WEIGHTED_PURCHASE','PASSIVE'
);

do $$
begin
  begin
    update public.menu_products set status='ACTIVE'
    where id='31444444-4444-4444-8444-444444444442';
    raise exception 'ACTIVE_MENU_WITH_PASSIVE_RECIPE_ALLOWED';
  exception when sqlstate '22023' then
    if sqlerrm <> 'MENU_RECIPE_NOT_ACTIVE' then raise; end if;
  end;
end $$;

insert into public.recipe_subrecipe_lines(
  tenant_id,recipe_id,subrecipe_id,quantity,unit,line_no
)
values(
  '31111111-1111-4111-8111-111111111111',
  '31333333-3333-4333-8333-333333333334',
  '31333333-3333-4333-8333-333333333335',
  null,null,1
);

do $$
begin
  begin
    insert into public.recipe_subrecipe_lines(
      tenant_id,recipe_id,subrecipe_id,quantity,unit,line_no
    )
    values(
      '31111111-1111-4111-8111-111111111111',
      '31333333-3333-4333-8333-333333333335',
      '31333333-3333-4333-8333-333333333334',
      null,null,1
    );
    raise exception 'RECIPE_DEPENDENCY_CYCLE_ALLOWED';
  exception when sqlstate '22023' then
    if sqlerrm <> 'RECIPE_DEPENDENCY_CYCLE' then raise; end if;
  end;
end $$;

create function pg_temp.expect_costing_truncate_guard(p_command text)
returns void
language plpgsql
as $$
begin
  execute p_command;
  raise exception 'COSTING_TRUNCATE_ALLOWED: %', p_command;
exception
  when sqlstate '55000' then
    if sqlerrm <> 'COSTING_MASTER_DATA_TRUNCATE_FORBIDDEN' then raise; end if;
end;
$$;

select pg_temp.expect_costing_truncate_guard('truncate table public.recipe_lines');
select pg_temp.expect_costing_truncate_guard('truncate table public.recipe_subrecipe_lines');
select pg_temp.expect_costing_truncate_guard('truncate table public.menu_products cascade');
select pg_temp.expect_costing_truncate_guard('truncate table public.recipes cascade');

rollback;

do $$
begin
  if exists(select 1 from public.tenants where id='31111111-1111-4111-8111-111111111111') then
    raise exception 'COSTING_RECIPE_INVARIANT_TEST_RESIDUALS';
  end if;
end $$;

select 'PASS - COSTING RECIPE INVARIANTS' as result;
