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
      when 'under_review' then 'உங்கள் விண்ணப்பம் பரிசீலனையில் உள்ளது'
      when 'shortlisted' then 'நீங்கள் Shortlist செய்யப்பட்டுள்ளீர்கள்'
      when 'rejected' then 'விண்ணப்ப நிலை புதுப்பிக்கப்பட்டது'
      else 'விண்ணப்ப நிலை புதுப்பிக்கப்பட்டது'
    end;
    v_notification_body := coalesce(v_job_title, 'வேலை') || ' பணிக்கான உங்கள் விண்ணப்ப நிலை: ' ||
      case p_new_status
        when 'under_review' then 'பரிசீலனையில்'
        when 'shortlisted' then 'Shortlist'
        when 'rejected' then 'நிராகரிக்கப்பட்டது'
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
