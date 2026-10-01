-- COOST costing / recipe structural invariants.

create function private.validate_recipe_line_dependency()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item_status text;
begin
  select i.status
  into v_item_status
  from public.inventory_items i
  where i.id = new.inventory_item_id
    and i.tenant_id = new.tenant_id
  for share;

  if not found or v_item_status <> 'ACTIVE' then
    raise exception 'COSTING_ITEM_NOT_AVAILABLE'
      using errcode = '22023';
  end if;

  return new;
end;
$$;

revoke all
  on function private.validate_recipe_line_dependency()
  from public, anon, authenticated;

create trigger recipe_line_dependency_validate
before insert or update on public.recipe_lines
for each row
execute function private.validate_recipe_line_dependency();


create function private.guard_inventory_item_recipe_dependency()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.status <> new.status
     and new.status = 'PASSIVE'
     and exists (
       select 1
       from public.recipe_lines rl
       join public.recipes r
         on r.id = rl.recipe_id
        and r.tenant_id = rl.tenant_id
       where rl.tenant_id = old.tenant_id
         and rl.inventory_item_id = old.id
         and r.status = 'ACTIVE'
     ) then
    raise exception 'INVENTORY_ITEM_IN_ACTIVE_RECIPE'
      using errcode = '22023';
  end if;

  return new;
end;
$$;

revoke all
  on function private.guard_inventory_item_recipe_dependency()
  from public, anon, authenticated;

create trigger inventory_item_costing_dependency_guard
before update on public.inventory_items
for each row
execute function private.guard_inventory_item_recipe_dependency();


create function private.validate_menu_product_recipe_dependency()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_recipe_status text;
begin
  select r.status
  into v_recipe_status
  from public.recipes r
  where r.id = new.recipe_id
    and r.tenant_id = new.tenant_id
  for share;

  if not found then
    raise exception 'RECIPE_NOT_AVAILABLE'
      using errcode = '22023';
  end if;

  if new.status = 'ACTIVE'
     and v_recipe_status <> 'ACTIVE' then
    raise exception 'MENU_RECIPE_NOT_ACTIVE'
      using errcode = '22023';
  end if;

  return new;
end;
$$;

revoke all
  on function private.validate_menu_product_recipe_dependency()
  from public, anon, authenticated;

create trigger menu_product_recipe_dependency_validate
before insert or update on public.menu_products
for each row
execute function private.validate_menu_product_recipe_dependency();


create or replace function private.guard_recipe_dependency_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.currency_code <> new.currency_code
    and exists(
      select 1
      from public.recipe_subrecipe_lines l
      where l.tenant_id=old.tenant_id
        and (l.recipe_id=old.id or l.subrecipe_id=old.id)
    )
  then
    raise exception 'RECIPE_CURRENCY_IN_USE'
      using errcode='22023';
  end if;

  if old.status <> new.status
    and new.status='PASSIVE'
    and exists(
      select 1
      from public.recipe_subrecipe_lines l
      where l.tenant_id=old.tenant_id
        and l.subrecipe_id=old.id
    )
  then
    raise exception 'RECIPE_SUBRECIPE_IN_USE'
      using errcode='22023';
  end if;

  if old.status <> new.status
    and new.status='PASSIVE'
    and exists(
      select 1
      from public.menu_products mp
      where mp.tenant_id=old.tenant_id
        and mp.recipe_id=old.id
        and mp.status='ACTIVE'
    )
  then
    raise exception 'RECIPE_MENU_PRODUCT_IN_USE'
      using errcode='22023';
  end if;

  if old.status <> new.status
    and new.status='ACTIVE'
    and exists(
      select 1
      from public.recipe_lines rl
      join public.inventory_items i
        on i.id=rl.inventory_item_id
       and i.tenant_id=rl.tenant_id
      where rl.tenant_id=old.tenant_id
        and rl.recipe_id=old.id
        and i.status <> 'ACTIVE'
    )
  then
    raise exception 'COSTING_ITEM_NOT_AVAILABLE'
      using errcode='22023';
  end if;

  if old.yield_unit is distinct from new.yield_unit
    and new.yield_unit is not null
    and exists(
      select 1
      from public.recipe_subrecipe_lines l
      where l.tenant_id=old.tenant_id
        and l.subrecipe_id=old.id
        and l.unit is not null
        and l.unit <> new.yield_unit
    )
  then
    raise exception 'RECIPE_YIELD_UNIT_IN_USE'
      using errcode='22023';
  end if;

  return new;
end;
$$;


create or replace function private.validate_recipe_subrecipe_line()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_parent_currency text;
  v_child_currency text;
  v_child_status text;
  v_child_yield_unit text;
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext('coost_recipe_graph'),
    pg_catalog.hashtext(new.tenant_id::text)
  );

  select r.currency_code
  into v_parent_currency
  from public.recipes r
  where r.id=new.recipe_id
    and r.tenant_id=new.tenant_id
  for share;

  if not found then
    raise exception 'RECIPE_NOT_AVAILABLE'
      using errcode='22023';
  end if;

  select r.currency_code,r.status,r.yield_unit
  into v_child_currency,v_child_status,v_child_yield_unit
  from public.recipes r
  where r.id=new.subrecipe_id
    and r.tenant_id=new.tenant_id
  for share;

  if not found then
    raise exception 'RECIPE_SUBRECIPE_NOT_AVAILABLE'
      using errcode='22023';
  end if;

  if new.recipe_id=new.subrecipe_id then
    raise exception 'RECIPE_DEPENDENCY_CYCLE'
      using errcode='22023';
  end if;

  if v_child_status <> 'ACTIVE' then
    raise exception 'RECIPE_SUBRECIPE_NOT_AVAILABLE'
      using errcode='22023';
  end if;

  if v_parent_currency <> v_child_currency then
    raise exception 'RECIPE_SUBRECIPE_CURRENCY_MISMATCH'
      using errcode='22023';
  end if;

  if new.quantity is not null
    and v_child_yield_unit is not null
    and new.unit <> v_child_yield_unit
  then
    raise exception 'RECIPE_SUBRECIPE_UNIT_MISMATCH'
      using errcode='22023';
  end if;

  if private.recipe_dependency_would_cycle(
    new.tenant_id,
    new.recipe_id,
    new.subrecipe_id
  ) then
    raise exception 'RECIPE_DEPENDENCY_CYCLE'
      using errcode='22023';
  end if;

  return new;
end;
$$;


create function private.reject_costing_master_truncate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception 'COSTING_MASTER_DATA_TRUNCATE_FORBIDDEN'
    using errcode = '55000';
end;
$$;

revoke all
  on function private.reject_costing_master_truncate()
  from public, anon, authenticated;

create trigger recipes_no_truncate
before truncate on public.recipes
for each statement
execute function private.reject_costing_master_truncate();

create trigger recipe_lines_no_truncate
before truncate on public.recipe_lines
for each statement
execute function private.reject_costing_master_truncate();

create trigger recipe_subrecipe_lines_no_truncate
before truncate on public.recipe_subrecipe_lines
for each statement
execute function private.reject_costing_master_truncate();

create trigger menu_products_no_truncate
before truncate on public.menu_products
for each statement
execute function private.reject_costing_master_truncate();
