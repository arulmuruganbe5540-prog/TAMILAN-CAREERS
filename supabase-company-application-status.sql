-- TAMILAN CAREERS: secure employer application status updates
-- Safe to rerun. Employers can only update applications for their own company.
begin;

create or replace function public.tc_company_update_application_status(
  p_application_id uuid,
  p_company_id uuid,
  p_new_status text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_current_status text;
begin
  if auth.uid() is null then
    raise exception 'Login required';
  end if;

  if p_new_status not in ('under_review', 'shortlisted', 'rejected') then
    raise exception 'Invalid application status';
  end if;

  if not exists (
    select 1
    from public.company_members cm
    where cm.company_id = p_company_id
      and cm.user_id = auth.uid()
      and cm.member_status = 'active'
      and cm.member_role in ('owner', 'hr_manager', 'recruiter')
  ) then
    raise exception 'You do not have permission to manage this company applications';
  end if;

  select ja.status
    into v_current_status
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

  update public.job_applications
  set status = p_new_status,
      updated_at = now()
  where id = p_application_id;

  return p_new_status;
end;
$$;

revoke all on function public.tc_company_update_application_status(uuid, uuid, text) from public, anon;
grant execute on function public.tc_company_update_application_status(uuid, uuid, text) to authenticated;

comment on function public.tc_company_update_application_status(uuid, uuid, text) is
  'Allows an active company owner, HR manager or recruiter to move their own applicants to under_review, shortlisted or rejected.';

commit;
