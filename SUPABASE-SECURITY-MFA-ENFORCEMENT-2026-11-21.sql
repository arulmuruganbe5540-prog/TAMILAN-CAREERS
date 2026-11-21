-- TAMILAN CAREERS: Super Admin MFA enforcement hardening
-- Applied to Supabase project qkmljuuusfjowexvybvy on 2026-11-21.
-- This policy intentionally blocks privileged Super Admin data/actions until
-- the Super Admin has enrolled a verified TOTP factor and the session is AAL2.
-- The Admin Account Security page remains available through the authenticated
-- user's own user_roles row so the Super Admin can enroll without a lockout.

begin;

create or replace function private.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select
    exists (
      select 1
      from public.user_roles ur
      where ur.user_id = (select auth.uid())
        and ur.role = 'super_admin'
    )
    and exists (
      select 1
      from auth.mfa_factors f
      where f.user_id = (select auth.uid())
        and f.status::text = 'verified'
    )
    and coalesce(auth.jwt()->>'aal', 'aal1') = 'aal2';
$function$;

revoke all on function private.is_super_admin() from public, anon;
grant execute on function private.is_super_admin() to authenticated;

create or replace function private.require_super_admin_mfa()
returns void
language plpgsql
set search_path = ''
as $function$
declare
  v_user uuid := (select auth.uid());
begin
  if v_user is null then
    raise exception 'Login required';
  end if;

  if not exists (
    select 1 from public.user_roles ur
    where ur.user_id = v_user and ur.role = 'super_admin'
  ) then
    raise exception 'Super Admin permission required';
  end if;

  if not exists (
    select 1 from auth.mfa_factors f
    where f.user_id = v_user and f.status::text = 'verified'
  ) then
    raise exception 'Register and verify an authenticator device before using Super Admin controls';
  end if;

  if coalesce(auth.jwt()->>'aal', 'aal1') <> 'aal2' then
    raise exception 'MFA verification required for this Super Admin action';
  end if;
end;
$function$;

revoke all on function private.require_super_admin_mfa() from public, anon, authenticated;

alter policy "Super admins review company verification documents"
on public.company_verification_documents
using (private.is_super_admin());

alter policy "Super admins review company verification requests"
on public.company_verification_requests
using (private.is_super_admin());

alter policy "job_reports_admin_update"
on public.job_reports
using (private.is_super_admin())
with check (private.is_super_admin());

alter policy "job_reports_read_own_or_admin"
on public.job_reports
using (
  reporter_user_id = (select auth.uid())
  or private.is_super_admin()
);

alter policy "Super admins read verification files"
on storage.objects
using (
  bucket_id = 'company-verification'
  and private.is_super_admin()
);

commit;
