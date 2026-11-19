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
  if exists (
    select 1
    from auth.mfa_factors f
    where f.user_id = v_user
      and f.status::text = 'verified'
  ) and coalesce(auth.jwt()->>'aal', 'aal1') <> 'aal2' then
    raise exception 'MFA verification required for this Super Admin action';
  end if;
end;
$function$;

revoke all on function private.require_super_admin_mfa() from public, anon, authenticated;

do $migration$
declare
  v_oid oid;
  v_name text;
  v_definition text;
  v_old text;
  v_new text;
begin
  for v_oid, v_name in
    select p.oid, p.proname
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'tc_admin_publish_job',
        'tc_review_company_verification',
        'tc_review_job_report',
        'tc_guard_company_verification_status'
      )
  loop
    v_definition := pg_get_functiondef(v_oid);

    if v_name = 'tc_admin_publish_job' then
      v_old := $old$  if not coalesce(private.is_super_admin(), false) then
    raise exception 'Super Admin permission required';
  end if;$old$;
      v_new := v_old || E'\n  perform private.require_super_admin_mfa();';
    elsif v_name = 'tc_review_company_verification' then
      v_old := $old$  if (select auth.uid()) is null
     or not exists (
       select 1 from public.user_roles ur
       where ur.user_id = (select auth.uid()) and ur.role = 'super_admin'
     ) then
    raise exception 'Super Admin permission required';
  end if;$old$;
      v_new := v_old || E'\n  perform private.require_super_admin_mfa();';
    elsif v_name = 'tc_review_job_report' then
      v_old := $old$  if v_user is null or not exists (
    select 1 from public.user_roles ur
    where ur.user_id = v_user and ur.role = 'super_admin'
  ) then raise exception 'Super Admin permission required'; end if;$old$;
      v_new := v_old || E'\n  perform private.require_super_admin_mfa();';
    elsif v_name = 'tc_guard_company_verification_status' then
      v_old := $old$begin
  if tg_op = 'INSERT' then$old$;
      v_new := $old$begin
  if v_is_admin then
    perform private.require_super_admin_mfa();
  end if;
  if tg_op = 'INSERT' then$old$;
    end if;

    if position(v_old in v_definition) = 0 then
      raise exception 'Expected authorization block not found in %', v_name;
    end if;
    v_definition := replace(v_definition, v_old, v_new);
    execute v_definition;
  end loop;

  if (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
      where n.nspname='public' and p.proname in (
        'tc_admin_publish_job','tc_review_company_verification',
        'tc_review_job_report','tc_guard_company_verification_status'
      )) <> 4 then
    raise exception 'One or more expected Super Admin functions were not found';
  end if;
end;
$migration$;
