-- Serialize recipe activation against concurrent inventory-item deactivation.
-- An ACTIVE recipe must never commit while one of its direct ingredients
-- concurrently becomes PASSIVE.

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
        and (
          l.recipe_id=old.id
          or l.subrecipe_id=old.id
        )
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
  then
    -- Lock every referenced inventory item in a deterministic order.
    -- This serializes recipe activation with concurrent item deactivation.
    perform 1
    from public.recipe_lines rl
    join public.inventory_items i
      on i.id=rl.inventory_item_id
     and i.tenant_id=rl.tenant_id
    where rl.tenant_id=old.tenant_id
      and rl.recipe_id=old.id
    order by i.id
    for share of i;

    if exists(
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

comment on function private.guard_recipe_dependency_update()
  is 'Protects recipe dependency invariants and locks direct inventory dependencies during recipe activation.';
