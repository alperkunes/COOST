-- COOST foundation privilege hardening
-- Browser-facing roles must receive only explicitly required privileges.
-- Critical writes continue through controlled RPC/command boundaries.

-- Remove broad table privileges that are not required by the browser client.
revoke truncate, references, trigger
  on all tables in schema public
  from anon, authenticated;

-- Prevent future postgres-owned public tables from inheriting broad browser privileges.
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated;

-- Browser clients do not need direct sequence privileges.
alter default privileges for role postgres in schema public
  revoke all on sequences from anon, authenticated;

-- New functions must not become executable by browser roles implicitly.
-- RPC functions must be granted explicitly by their own migrations.
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated;
