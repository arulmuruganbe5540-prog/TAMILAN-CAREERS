-- TAMILAN CAREERS: Secure role visibility for Admin Login
-- Users may read only their own assigned roles.
-- Super Admins may read role assignments for admin operations.
-- No client-side INSERT/UPDATE/DELETE privileges are added.

begin;

alter table public.user_roles enable row level security;

drop policy if exists user_roles_read_own_or_super_admin on public.user_roles;
create policy user_roles_read_own_or_super_admin
  on public.user_roles
  for select
  to authenticated
  using (
    user_id = (select auth.uid())
    or (select private.is_super_admin())
  );

grant select on public.user_roles to authenticated;

commit;
