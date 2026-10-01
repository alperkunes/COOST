-- COOST global function privilege hardening
-- PostgreSQL grants EXECUTE on newly created functions to PUBLIC by default.
-- This global default must be revoked explicitly; schema-scoped revocation alone
-- does not remove the built-in PUBLIC function privilege.

alter default privileges for role postgres
  revoke execute on functions from public;
