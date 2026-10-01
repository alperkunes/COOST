begin;

do $$
declare
  v_table record;
begin
  -- Browser roles must never receive schema-level destructive privileges
  -- on public application tables.
  for v_table in
    select schemaname, tablename
    from pg_tables
    where schemaname = 'public'
  loop
    if has_table_privilege(
      'authenticated',
      format('%I.%I', v_table.schemaname, v_table.tablename),
      'TRUNCATE'
    ) then
      raise exception
        'AUTHENTICATED_TRUNCATE_PRIVILEGE_PRESENT:%',
        v_table.tablename;
    end if;

    if has_table_privilege(
      'authenticated',
      format('%I.%I', v_table.schemaname, v_table.tablename),
      'REFERENCES'
    ) then
      raise exception
        'AUTHENTICATED_REFERENCES_PRIVILEGE_PRESENT:%',
        v_table.tablename;
    end if;

    if has_table_privilege(
      'authenticated',
      format('%I.%I', v_table.schemaname, v_table.tablename),
      'TRIGGER'
    ) then
      raise exception
        'AUTHENTICATED_TRIGGER_PRIVILEGE_PRESENT:%',
        v_table.tablename;
    end if;

    if has_table_privilege(
      'anon',
      format('%I.%I', v_table.schemaname, v_table.tablename),
      'TRUNCATE'
    ) then
      raise exception
        'ANON_TRUNCATE_PRIVILEGE_PRESENT:%',
        v_table.tablename;
    end if;

    if has_table_privilege(
      'anon',
      format('%I.%I', v_table.schemaname, v_table.tablename),
      'REFERENCES'
    ) then
      raise exception
        'ANON_REFERENCES_PRIVILEGE_PRESENT:%',
        v_table.tablename;
    end if;

    if has_table_privilege(
      'anon',
      format('%I.%I', v_table.schemaname, v_table.tablename),
      'TRIGGER'
    ) then
      raise exception
        'ANON_TRIGGER_PRIVILEGE_PRESENT:%',
        v_table.tablename;
    end if;
  end loop;

  -- Existing explicitly granted application access must remain intact.
  if not has_table_privilege(
    'authenticated',
    'public.tenants',
    'SELECT'
  ) then
    raise exception 'AUTHENTICATED_TENANT_SELECT_REMOVED';
  end if;

  if not has_column_privilege(
    'authenticated',
    'public.profiles',
    'display_name',
    'UPDATE'
  ) then
    raise exception 'PROFILE_DISPLAY_NAME_UPDATE_REMOVED';
  end if;

  if not has_function_privilege(
    'authenticated',
    'public.get_finance_overview(uuid,integer)',
    'EXECUTE'
  ) then
    raise exception 'FINANCE_OVERVIEW_RPC_EXECUTE_REMOVED';
  end if;
end
$$;

-- Verify postgres default privileges by creating rollback-only probes.
create table public.coost_privilege_probe (
  id bigint primary key
);

create sequence public.coost_privilege_probe_seq;

create function public.coost_privilege_probe_fn()
returns integer
language sql
as $function$
  select 1;
$function$;

do $$
begin
  if has_table_privilege(
    'authenticated',
    'public.coost_privilege_probe',
    'SELECT'
  )
  or has_table_privilege(
    'authenticated',
    'public.coost_privilege_probe',
    'INSERT'
  )
  or has_table_privilege(
    'authenticated',
    'public.coost_privilege_probe',
    'UPDATE'
  )
  or has_table_privilege(
    'authenticated',
    'public.coost_privilege_probe',
    'DELETE'
  )
  or has_table_privilege(
    'authenticated',
    'public.coost_privilege_probe',
    'TRUNCATE'
  )
  or has_table_privilege(
    'authenticated',
    'public.coost_privilege_probe',
    'REFERENCES'
  )
  or has_table_privilege(
    'authenticated',
    'public.coost_privilege_probe',
    'TRIGGER'
  ) then
    raise exception 'FUTURE_TABLE_AUTHENTICATED_PRIVILEGE_LEAK';
  end if;

  if has_table_privilege(
    'anon',
    'public.coost_privilege_probe',
    'SELECT'
  )
  or has_table_privilege(
    'anon',
    'public.coost_privilege_probe',
    'INSERT'
  )
  or has_table_privilege(
    'anon',
    'public.coost_privilege_probe',
    'UPDATE'
  )
  or has_table_privilege(
    'anon',
    'public.coost_privilege_probe',
    'DELETE'
  )
  or has_table_privilege(
    'anon',
    'public.coost_privilege_probe',
    'TRUNCATE'
  )
  or has_table_privilege(
    'anon',
    'public.coost_privilege_probe',
    'REFERENCES'
  )
  or has_table_privilege(
    'anon',
    'public.coost_privilege_probe',
    'TRIGGER'
  ) then
    raise exception 'FUTURE_TABLE_ANON_PRIVILEGE_LEAK';
  end if;

  if has_sequence_privilege(
    'authenticated',
    'public.coost_privilege_probe_seq',
    'USAGE'
  )
  or has_sequence_privilege(
    'authenticated',
    'public.coost_privilege_probe_seq',
    'SELECT'
  )
  or has_sequence_privilege(
    'authenticated',
    'public.coost_privilege_probe_seq',
    'UPDATE'
  )
  or has_sequence_privilege(
    'anon',
    'public.coost_privilege_probe_seq',
    'USAGE'
  )
  or has_sequence_privilege(
    'anon',
    'public.coost_privilege_probe_seq',
    'SELECT'
  )
  or has_sequence_privilege(
    'anon',
    'public.coost_privilege_probe_seq',
    'UPDATE'
  ) then
    raise exception 'FUTURE_SEQUENCE_BROWSER_PRIVILEGE_LEAK';
  end if;

  if has_function_privilege(
    'authenticated',
    'public.coost_privilege_probe_fn()',
    'EXECUTE'
  )
  or has_function_privilege(
    'anon',
    'public.coost_privilege_probe_fn()',
    'EXECUTE'
  )
  or has_function_privilege(
    'public',
    'public.coost_privilege_probe_fn()',
    'EXECUTE'
  ) then
    raise exception 'FUTURE_FUNCTION_BROWSER_EXECUTE_LEAK';
  end if;
end
$$;

rollback;

select
  'PASS - FOUNDATION PRIVILEGE HARDENING' as result;
