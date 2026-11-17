-- Require verified Supabase Authenticator Assurance Level 2 for all paths
-- protected by private.is_super_admin(). Super Admin TOTP setup is in admin-login.html.
create or replace function private.is_super_admin()
returns boolean language sql stable security definer set search_path = ''
as $$
  select coalesce(auth.jwt() ->> 'aal', 'aal1') = 'aal2'
    and exists (
      select 1 from public.user_roles
      where user_id = auth.uid() and role = 'super_admin'
    );
$$;
revoke all on function private.is_super_admin() from public;
grant execute on function private.is_super_admin() to authenticated;
