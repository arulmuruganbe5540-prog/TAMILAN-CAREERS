-- TAMILAN CAREERS: secure employer application status updates
-- Safe to rerun. Employers can only update applications for their own company.
begin;

-- Fail before creating the RPC if the live company/application schema differs.
do $tc_company_status_guard$
declare
  v_missing text[] := array[]::text[];
  v_item text;
begin
  if to_regclass('public.company_members') is null
     or to_regclass('public.companies') is null
     or to_regclass('public.jobs') is null
     or to_regclass('public.job_applications') is null then
    raise exception 'Company application status setup stopped: required company/application tables are missing; run supabase-schema-audit.sql first.';
  end if;
  foreach v_item in array array[
    'company_members.company_id','company_members.user_id','company_members.member_status','company_members.member_role',
    'companies.id','companies.owner_user_id',
    'jobs.id','jobs.company_id','jobs.job_title',
    'job_applications.id','job_applications.job_id','job_applications.candidate_id','job_applications.status','job_applications.updated_at'
  ] loop
    if not exists (
      select 1 from information_schema.columns c
      where c.table_schema='public'
        and c.table_name=split_part(v_item,'.',1)
        and c.column_name=split_part(v_item,'.',2)
    ) then
      v_missing := array_append(v_missing,v_item);
    end if;
  end loop;
  if cardinality(v_missing) > 0 then
    raise exception 'Company application status setup stopped: required columns are missing: %', array_to_string(v_missing, ', ');
  end if;
end;
$tc_company_status_guard$;

create or replace function public.tc_company_update_application_status(
  p_application_id uuid,
  p_company_id uuid,
  p_new_status text
)
returns text
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_current_status text;
  v_candidate_id uuid;
  v_job_title text;
  v_notification_title text;
  v_notification_body text;
begin
  if auth.uid() is null then
    raise exception 'Login required';
  end if;

  if p_new_status is null or p_new_status not in ('under_review', 'shortlisted', 'rejected') then
    raise exception 'Invalid application status';
  end if;

  if not exists (
    select 1
    from public.company_members cm
    where cm.company_id = p_company_id
      and cm.user_id = auth.uid()
      and cm.member_status = 'active'
      and cm.member_role in ('owner', 'hr_manager', 'recruiter')
  ) and not exists (
    select 1 from public.companies c
    where c.id = p_company_id and c.owner_user_id = auth.uid()
  ) then
    raise exception 'You do not have permission to manage this company applications';
  end if;

  select ja.status, ja.candidate_id, j.job_title
    into v_current_status, v_candidate_id, v_job_title
  from public.job_applications ja
  join public.jobs j on j.id = ja.job_id
  where ja.id = p_application_id
    and j.company_id = p_company_id
  for update of ja;

  if not found then
    raise exception 'Application not found for this company';
  end if;

  if v_current_status in ('withdrawn', 'rejected') then
    raise exception 'This application is closed and cannot be changed';
  end if;

  if v_current_status not in ('applied', 'under_review', 'shortlisted') then
    raise exception 'Current application status cannot be changed';
  end if;

  if v_current_status = p_new_status then
    return p_new_status;
  end if;

  update public.job_applications
  set status = p_new_status,
      updated_at = now()
  where id = p_application_id;

  -- Keep this status RPC usable even when the optional notification migration
  -- has not been installed yet. When notifications exist, alert the candidate.
  if pg_catalog.to_regclass('public.tc_notifications') is not null then
    v_notification_title := case p_new_status
      when 'under_review' then 'Your application is under review'
      when 'shortlisted' then 'You have been shortlisted'
      when 'rejected' then 'Application status updated'
      else 'Application status updated'
    end;
    v_notification_body := coalesce(v_job_title, 'Job') || ' application status: ' ||
      case p_new_status
        when 'under_review' then 'Under review'
        when 'shortlisted' then 'Shortlist'
        when 'rejected' then 'Rejected'
        else p_new_status
      end;
    insert into public.tc_notifications(
      user_id, notification_type, title, body, related_application_id
    ) values (
      v_candidate_id, 'application_status', v_notification_title,
      v_notification_body, p_application_id
    );
  end if;

  return p_new_status;
end;
$function$;

revoke all on function public.tc_company_update_application_status(uuid, uuid, text) from public, anon;
grant execute on function public.tc_company_update_application_status(uuid, uuid, text) to authenticated;

comment on function public.tc_company_update_application_status(uuid, uuid, text) is
  'Allows an active company owner, HR manager or recruiter to move their own applicants to under_review, shortlisted or rejected.';

commit;
