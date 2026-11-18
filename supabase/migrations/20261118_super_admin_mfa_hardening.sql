-- Super Admin access uses Email + Password authentication and the
-- server-side super_admin role. Authenticator MFA is intentionally not required.
create or replace function private.is_super_admin()
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.user_roles where user_id = auth.uid() and role = 'super_admin');
$$;
revoke all on function private.is_super_admin() from public, anon;
grant execute on function private.is_super_admin() to authenticated;
