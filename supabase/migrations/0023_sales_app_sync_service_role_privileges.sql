-- Restrict Supabase service_role privileges for Sales App sync tables.
-- Supabase default privileges grant service_role broad table access on
-- newly created public tables. The sync boundary intentionally narrows it.

revoke all
  on table public.sales_app_connections,
           public.sales_app_sync_runs
  from service_role;

grant select
  on table public.sales_app_connections
  to service_role;

grant select,insert,update
  on table public.sales_app_sync_runs
  to service_role;