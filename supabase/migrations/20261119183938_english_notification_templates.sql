-- Replace legacy Tamil notification templates with English-only user-facing messages.
-- Function ownership checks, SECURITY DEFINER settings, search_path, triggers and grants are preserved.
begin;

create or replace function public.tc_cancel_interviews_on_application_close()
returns trigger
language plpgsql
security definer
set search_path = ''
as $tc_cancel_interviews$
declare
  v_company_id uuid;
  v_job_title text;
  v_company_name text;
begin
  if new.status in ('withdrawn','rejected') and old.status is distinct from new.status then
    update public.tc_interview_invitations
       set status='cancelled', updated_at=now()
     where application_id=new.id and status in ('pending','accepted');
  end if;

  if new.status='withdrawn' and old.status is distinct from new.status then
    select j.company_id,j.job_title,c.company_name
      into v_company_id,v_job_title,v_company_name
    from public.jobs j
    join public.companies c on c.id=j.company_id
    where j.id=new.job_id;

    if v_company_id is not null then
      insert into public.tc_notifications(user_id,notification_type,title,body,related_application_id)
      select cm.user_id,'application_status','Candidate withdrew an application',
        coalesce(v_company_name,'Company')||' — '||coalesce(v_job_title,'Job')||
        ' — the candidate withdrew this application.',
        new.id
      from public.company_members cm
      where cm.company_id=v_company_id
        and cm.member_status='active'
        and cm.member_role in ('owner','hr_manager','recruiter');

      insert into public.tc_notifications(user_id,notification_type,title,body,related_application_id)
      select c.owner_user_id,'application_status','Candidate withdrew an application',
        coalesce(v_company_name,'Company')||' — '||coalesce(v_job_title,'Job')||
        ' — the candidate withdrew this application.',
        new.id
      from public.companies c
      where c.id=v_company_id and c.owner_user_id is not null
        and not exists (
          select 1 from public.company_members cm
          where cm.company_id=v_company_id and cm.user_id=c.owner_user_id
            and cm.member_status='active'
            and cm.member_role in ('owner','hr_manager','recruiter')
        );
    end if;
  end if;
  return new;
end;
$tc_cancel_interviews$;
revoke all on function public.tc_cancel_interviews_on_application_close() from public, anon, authenticated;

create or replace function public.tc_send_interview_invitation(
  p_application_id uuid,
  p_scheduled_at timestamptz,
  p_interview_mode text default 'in_person',
  p_location_or_link text default '',
  p_letter_text text default ''
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_company_id uuid;
  v_candidate_id uuid;
  v_job_title text;
  v_interview_id uuid;
  v_company_name text;
begin
  if auth.uid() is null then raise exception 'Login required'; end if;
  if p_scheduled_at is null or p_scheduled_at <= now() then
    raise exception 'Interview date and time must be in the future';
  end if;
  if p_interview_mode not in ('in_person','online','phone') then
    raise exception 'Invalid interview mode';
  end if;
  if length(coalesce(p_location_or_link,'')) > 1000 or length(coalesce(p_letter_text,'')) > 8000 then
    raise exception 'Interview details are too long';
  end if;

  select j.company_id, ja.candidate_id, j.job_title, c.company_name
    into v_company_id, v_candidate_id, v_job_title, v_company_name
  from public.job_applications ja
  join public.jobs j on j.id = ja.job_id
  join public.companies c on c.id = j.company_id
  where ja.id = p_application_id
    and ja.status in ('applied','under_review','shortlisted')
  for update of ja;

  if not found then raise exception 'Active application not found'; end if;

  if not (
    exists (
      select 1 from public.company_members cm
      where cm.company_id = v_company_id
        and cm.user_id = auth.uid()
        and cm.member_status = 'active'
        and cm.member_role in ('owner','hr_manager','recruiter')
    )
    or exists (
      select 1 from public.companies c
      where c.id = v_company_id and c.owner_user_id = auth.uid()
    )
  ) then
    raise exception 'You are not allowed to invite this candidate';
  end if;

  insert into public.tc_interview_invitations(
    application_id,company_id,candidate_id,invited_by,scheduled_at,
    interview_mode,location_or_link,letter_text
  ) values (
    p_application_id,v_company_id,v_candidate_id,auth.uid(),p_scheduled_at,
    p_interview_mode,coalesce(p_location_or_link,''),coalesce(p_letter_text,'')
  ) returning id into v_interview_id;

  insert into public.tc_notifications(
    user_id,notification_type,title,body,related_application_id,related_interview_id
  ) values (
    v_candidate_id,'interview_invitation','New interview invitation',
    coalesce(v_company_name,'Company') || ' Company ' ||
    coalesce(v_job_title,'Job') || ' has invited you to interview. Date: ' ||
    to_char(p_scheduled_at at time zone 'Asia/Kolkata','DD-MM-YYYY HH12:MI AM'),
    p_application_id,v_interview_id
  );
  return v_interview_id;
end;
$$;
revoke all on function public.tc_send_interview_invitation(uuid,timestamptz,text,text,text) from public, anon;
grant execute on function public.tc_send_interview_invitation(uuid,timestamptz,text,text,text) to authenticated;

create or replace function public.tc_respond_interview_invitation(
  p_interview_id uuid,
  p_response text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_candidate_id uuid;
  v_company_id uuid;
  v_application_id uuid;
  v_job_title text;
  v_company_name text;
  v_status text;
begin
  if auth.uid() is null then raise exception 'Login required'; end if;
  if p_response not in ('accepted','declined') then raise exception 'Invalid response'; end if;

  select i.candidate_id,i.company_id,i.application_id,j.job_title,c.company_name,i.status
    into v_candidate_id,v_company_id,v_application_id,v_job_title,v_company_name,v_status
  from public.tc_interview_invitations i
  join public.job_applications ja on ja.id=i.application_id
  join public.jobs j on j.id=ja.job_id
  join public.companies c on c.id=i.company_id
  where i.id=p_interview_id
    and ja.status in ('applied','under_review','shortlisted')
  for update of i;

  if not found or v_candidate_id <> auth.uid() then
    raise exception 'Interview invitation not found';
  end if;
  if v_status <> 'pending' then raise exception 'This invitation has already been answered or closed'; end if;

  update public.tc_interview_invitations
  set status=p_response,candidate_response_at=now(),updated_at=now()
  where id=p_interview_id;

  insert into public.tc_notifications(
    user_id,notification_type,title,body,related_application_id,related_interview_id
  )
  select cm.user_id,'interview_response',
    case when p_response='accepted' then 'Candidate accepted the interview invitation' else 'Candidate declined the interview invitation' end,
    'Job: '||coalesce(v_job_title,'')||' — Candidate response: '||
      case when p_response='accepted' then 'Accepted' else 'Declined' end,
    v_application_id,p_interview_id
  from public.company_members cm
  where cm.company_id=v_company_id and cm.member_status='active'
    and cm.member_role in ('owner','hr_manager','recruiter');

  insert into public.tc_notifications(user_id,notification_type,title,body,related_application_id,related_interview_id)
  select c.owner_user_id,'interview_response',
    case when p_response='accepted' then 'Candidate accepted the interview invitation' else 'Candidate declined the interview invitation' end,
    'Job: '||coalesce(v_job_title,'')||' — Candidate response: '||
      case when p_response='accepted' then 'Accepted' else 'Declined' end,
    v_application_id,p_interview_id
  from public.companies c where c.id=v_company_id
    and c.owner_user_id is not null
    and not exists (select 1 from public.company_members cm where cm.company_id=v_company_id and cm.user_id=c.owner_user_id and cm.member_status='active' and cm.member_role in ('owner','hr_manager','recruiter'));

  return p_response;
end;
$$;
revoke all on function public.tc_respond_interview_invitation(uuid,text) from public, anon;
grant execute on function public.tc_respond_interview_invitation(uuid,text) to authenticated;

create or replace function public.tc_notify_company_on_new_application()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_company_id uuid;
  v_job_title text;
  v_company_name text;
begin
  select j.company_id,j.job_title,c.company_name
    into v_company_id,v_job_title,v_company_name
  from public.jobs j
  join public.companies c on c.id=j.company_id
  where j.id=new.job_id;

  if v_company_id is null then return new; end if;

  insert into public.tc_notifications(user_id,notification_type,title,body,related_application_id)
  select cm.user_id,'application_status','New job application received',
    coalesce(v_company_name,'Company')||' — '||coalesce(v_job_title,'Job')||
    ' has received a new application.',
    new.id
  from public.company_members cm
  where cm.company_id=v_company_id
    and cm.member_status='active'
    and cm.member_role in ('owner','hr_manager','recruiter');

  insert into public.tc_notifications(user_id,notification_type,title,body,related_application_id)
  select c.owner_user_id,'application_status','New job application received',
    coalesce(v_company_name,'Company')||' — '||coalesce(v_job_title,'Job')||
    ' has received a new application.',
    new.id
  from public.companies c
  where c.id=v_company_id and c.owner_user_id is not null
    and not exists (
      select 1 from public.company_members cm
      where cm.company_id=v_company_id and cm.user_id=c.owner_user_id
        and cm.member_status='active'
        and cm.member_role in ('owner','hr_manager','recruiter')
    );
  return new;
end;
$$;
revoke all on function public.tc_notify_company_on_new_application() from public, anon, authenticated;

create or replace function public.tc_generate_interview_reminders()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare v_count integer := 0; v_rows integer := 0;
begin
  -- Candidate reminder approximately 24 hours before the interview.
  insert into public.tc_notifications(user_id,notification_type,title,body,related_application_id,related_interview_id)
  select i.candidate_id,'interview_reminder','Your interview is tomorrow',
    'Your interview is in 24 hours. Date: '||
    to_char(i.scheduled_at at time zone 'Asia/Kolkata','DD-MM-YYYY HH12:MI AM'),
    i.application_id,i.id
  from public.tc_interview_invitations i
  join public.job_applications ja on ja.id=i.application_id
  where i.status='accepted'
    and ja.status in ('applied','under_review','shortlisted')
    and i.scheduled_at between now()+interval '23 hours' and now()+interval '25 hours'
    and not exists (
      select 1 from public.tc_notifications n
      where n.user_id=i.candidate_id and n.related_interview_id=i.id
        and n.notification_type='interview_reminder'
        and n.body like 'Your interview is in 24 hours.%'
    );
  get diagnostics v_rows = row_count; v_count := v_count + v_rows;

  -- Candidate reminder approximately 1 hour before the interview.
  insert into public.tc_notifications(user_id,notification_type,title,body,related_application_id,related_interview_id)
  select i.candidate_id,'interview_reminder','Your interview starts in one hour',
    'Your interview starts in one hour. Date: '||
    to_char(i.scheduled_at at time zone 'Asia/Kolkata','DD-MM-YYYY HH12:MI AM'),
    i.application_id,i.id
  from public.tc_interview_invitations i
  join public.job_applications ja on ja.id=i.application_id
  where i.status='accepted'
    and ja.status in ('applied','under_review','shortlisted')
    and i.scheduled_at between now()+interval '50 minutes' and now()+interval '70 minutes'
    and not exists (
      select 1 from public.tc_notifications n
      where n.user_id=i.candidate_id and n.related_interview_id=i.id
        and n.notification_type='interview_reminder'
        and n.body like 'Your interview starts in one hour.%'
    );
  get diagnostics v_rows = row_count; v_count := v_count + v_rows;
  return v_count;
end;
$$;
revoke all on function public.tc_generate_interview_reminders() from public, anon, authenticated;
grant execute on function public.tc_generate_interview_reminders() to service_role;

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
revoke all on function public.tc_company_update_application_status(uuid,uuid,text) from public, anon;
grant execute on function public.tc_company_update_application_status(uuid,uuid,text) to authenticated;

commit;
