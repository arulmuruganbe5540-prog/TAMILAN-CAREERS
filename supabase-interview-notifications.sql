-- TAMILAN CAREERS: secure notifications and interview invitations
-- Run in Supabase SQL Editor. Safe to rerun.
begin;

-- Stop before creating anything if the existing core schema differs from the
-- columns used by invitation, response, and notification workflows.
do $tc_interview_schema_guard$
declare
  v_missing text[] := array[]::text[];
  v_item text;
begin
  if to_regclass('public.job_applications') is null
     or to_regclass('public.jobs') is null
     or to_regclass('public.companies') is null
     or to_regclass('public.company_members') is null then
    raise exception 'Required job_applications, jobs, companies, or company_members table is missing; run supabase-schema-audit.sql first.';
  end if;

  foreach v_item in array array[
    'job_applications.id','job_applications.job_id','job_applications.candidate_id','job_applications.status','job_applications.updated_at',
    'jobs.id','jobs.company_id','jobs.job_title',
    'companies.id','companies.company_name','companies.owner_user_id',
    'company_members.company_id','company_members.user_id','company_members.member_status','company_members.member_role'
  ] loop
    if not exists (
      select 1
      from information_schema.columns c
      where c.table_schema='public'
        and c.table_name=split_part(v_item,'.',1)
        and c.column_name=split_part(v_item,'.',2)
    ) then
      v_missing := array_append(v_missing,v_item);
    end if;
  end loop;

  if cardinality(v_missing) > 0 then
    raise exception 'Interview/notification migration stopped: required columns are missing: %', array_to_string(v_missing, ', ');
  end if;
end;
$tc_interview_schema_guard$;

create table if not exists public.tc_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  notification_type text not null check (notification_type in (
    'application_status','interview_invitation','interview_response','interview_reminder','system'
  )),
  title text not null check (length(btrim(title)) between 1 and 180),
  body text not null default '' check (length(body) <= 4000),
  related_application_id uuid references public.job_applications(id) on delete cascade,
  related_interview_id uuid,
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index if not exists tc_notifications_user_created_idx
  on public.tc_notifications(user_id, created_at desc);
create index if not exists tc_notifications_user_unread_idx
  on public.tc_notifications(user_id, created_at desc) where is_read = false;
alter table public.tc_notifications enable row level security;
revoke all on public.tc_notifications from anon, authenticated;
grant select on public.tc_notifications to authenticated;
drop policy if exists "TC users read own notifications" on public.tc_notifications;
create policy "TC users read own notifications"
on public.tc_notifications for select to authenticated
using (user_id = (select auth.uid()));

create table if not exists public.tc_interview_invitations (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.job_applications(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  candidate_id uuid not null references auth.users(id) on delete cascade,
  invited_by uuid not null references auth.users(id),
  scheduled_at timestamptz not null,
  interview_mode text not null default 'in_person'
    check (interview_mode in ('in_person','online','phone')),
  location_or_link text not null default '' check (length(location_or_link) <= 1000),
  letter_text text not null default '' check (length(letter_text) <= 8000),
  status text not null default 'pending'
    check (status in ('pending','accepted','declined','cancelled','completed')),
  candidate_response_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists tc_interviews_candidate_date_idx
  on public.tc_interview_invitations(candidate_id, scheduled_at);
create index if not exists tc_interviews_company_date_idx
  on public.tc_interview_invitations(company_id, scheduled_at);
alter table public.tc_interview_invitations enable row level security;
revoke all on public.tc_interview_invitations from anon, authenticated;
grant select on public.tc_interview_invitations to authenticated;

drop policy if exists "TC candidate reads own interview invitations" on public.tc_interview_invitations;
create policy "TC candidate reads own interview invitations"
on public.tc_interview_invitations for select to authenticated
using (candidate_id = (select auth.uid()));

drop policy if exists "TC authorized company reads interview invitations" on public.tc_interview_invitations;
create policy "TC authorized company reads interview invitations"
on public.tc_interview_invitations for select to authenticated
using (
  exists (
    select 1 from public.company_members cm
    where cm.company_id = tc_interview_invitations.company_id
      and cm.user_id = (select auth.uid())
      and cm.member_status = 'active'
      and cm.member_role in ('owner','hr_manager','recruiter')
  )
  or exists (
    select 1 from public.companies c
    where c.id = tc_interview_invitations.company_id
      and c.owner_user_id = (select auth.uid())
  )
);

-- Close pending/accepted interviews when the underlying application is withdrawn or rejected.
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
      select cm.user_id,'application_status','Candidate விண்ணப்பத்தைத் திரும்பப் பெற்றுள்ளார்',
        coalesce(v_company_name,'நிறுவனம்')||' — '||coalesce(v_job_title,'வேலை')||
        ' பணிக்கான விண்ணப்பத்தை Candidate திரும்பப் பெற்றுள்ளார்.',
        new.id
      from public.company_members cm
      where cm.company_id=v_company_id
        and cm.member_status='active'
        and cm.member_role in ('owner','hr_manager','recruiter');

      insert into public.tc_notifications(user_id,notification_type,title,body,related_application_id)
      select c.owner_user_id,'application_status','Candidate விண்ணப்பத்தைத் திரும்பப் பெற்றுள்ளார்',
        coalesce(v_company_name,'நிறுவனம்')||' — '||coalesce(v_job_title,'வேலை')||
        ' பணிக்கான விண்ணப்பத்தை Candidate திரும்பப் பெற்றுள்ளார்.',
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
drop trigger if exists tc_cancel_interviews_on_application_close on public.job_applications;
create trigger tc_cancel_interviews_on_application_close
after update of status on public.job_applications
for each row execute function public.tc_cancel_interviews_on_application_close();

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
    v_candidate_id,'interview_invitation','புதிய Interview அழைப்பு',
    coalesce(v_company_name,'நிறுவனம்') || ' நிறுவனம் ' ||
    coalesce(v_job_title,'வேலை') || ' பணிக்கான நேர்காணலுக்கு அழைத்துள்ளது. தேதி: ' ||
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
    case when p_response='accepted' then 'Candidate Interview-ஐ ஏற்றுக்கொண்டார்' else 'Candidate Interview-ஐ மறுத்துள்ளார்' end,
    'வேலை: '||coalesce(v_job_title,'')||' — Candidate பதில்: '||
      case when p_response='accepted' then 'ஏற்றுக்கொண்டார்' else 'மறுத்துள்ளார்' end,
    v_application_id,p_interview_id
  from public.company_members cm
  where cm.company_id=v_company_id and cm.member_status='active'
    and cm.member_role in ('owner','hr_manager','recruiter');

  insert into public.tc_notifications(user_id,notification_type,title,body,related_application_id,related_interview_id)
  select c.owner_user_id,'interview_response',
    case when p_response='accepted' then 'Candidate Interview-ஐ ஏற்றுக்கொண்டார்' else 'Candidate Interview-ஐ மறுத்துள்ளார்' end,
    'வேலை: '||coalesce(v_job_title,'')||' — Candidate பதில்: '||
      case when p_response='accepted' then 'ஏற்றுக்கொண்டார்' else 'மறுத்துள்ளார்' end,
    v_application_id,p_interview_id
  from public.companies c where c.id=v_company_id
    and c.owner_user_id is not null
    and not exists (select 1 from public.company_members cm where cm.company_id=v_company_id and cm.user_id=c.owner_user_id and cm.member_status='active' and cm.member_role in ('owner','hr_manager','recruiter'));

  return p_response;
end;
$$;
revoke all on function public.tc_respond_interview_invitation(uuid,text) from public, anon;
grant execute on function public.tc_respond_interview_invitation(uuid,text) to authenticated;

create or replace function public.tc_mark_notification_read(p_notification_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'Login required'; end if;
  update public.tc_notifications
     set is_read=true,read_at=coalesce(read_at,now())
   where id=p_notification_id and user_id=auth.uid();
  return found;
end;
$$;
revoke all on function public.tc_mark_notification_read(uuid) from public, anon;
grant execute on function public.tc_mark_notification_read(uuid) to authenticated;

create or replace function public.tc_mark_all_notifications_read()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare v_count integer;
begin
  if auth.uid() is null then raise exception 'Login required'; end if;
  update public.tc_notifications set is_read=true,read_at=coalesce(read_at,now())
  where user_id=auth.uid() and is_read=false;
  get diagnostics v_count=row_count;
  return v_count;
end;
$$;
revoke all on function public.tc_mark_all_notifications_read() from public, anon;
grant execute on function public.tc_mark_all_notifications_read() to authenticated;

-- Notify authorized company users immediately when a candidate submits an application.
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
  select cm.user_id,'application_status','புதிய வேலை விண்ணப்பம் வந்துள்ளது',
    coalesce(v_company_name,'நிறுவனம்')||' — '||coalesce(v_job_title,'வேலை')||
    ' பணிக்கு புதிய விண்ணப்பம் வந்துள்ளது.',
    new.id
  from public.company_members cm
  where cm.company_id=v_company_id
    and cm.member_status='active'
    and cm.member_role in ('owner','hr_manager','recruiter');

  insert into public.tc_notifications(user_id,notification_type,title,body,related_application_id)
  select c.owner_user_id,'application_status','புதிய வேலை விண்ணப்பம் வந்துள்ளது',
    coalesce(v_company_name,'நிறுவனம்')||' — '||coalesce(v_job_title,'வேலை')||
    ' பணிக்கு புதிய விண்ணப்பம் வந்துள்ளது.',
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
drop trigger if exists tc_notify_company_on_new_application on public.job_applications;
create trigger tc_notify_company_on_new_application
after insert on public.job_applications
for each row execute function public.tc_notify_company_on_new_application();

-- Scheduled reminder generator. Call from Supabase Cron / trusted server every 15 minutes.
-- It is intentionally not executable by browser users; configure a scheduled call separately.
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
  select i.candidate_id,'interview_reminder','நாளை உங்கள் Interview',
    'உங்கள் Interview 24 மணி நேரத்தில் உள்ளது. தேதி: '||
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
        and n.body like 'உங்கள் Interview 24 மணி நேரத்தில் உள்ளது.%'
    );
  get diagnostics v_rows = row_count; v_count := v_count + v_rows;

  -- Candidate reminder approximately 1 hour before the interview.
  insert into public.tc_notifications(user_id,notification_type,title,body,related_application_id,related_interview_id)
  select i.candidate_id,'interview_reminder','ஒரு மணி நேரத்தில் Interview',
    'உங்கள் Interview ஒரு மணி நேரத்தில் தொடங்கும். தேதி: '||
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
        and n.body like 'உங்கள் Interview ஒரு மணி நேரத்தில் தொடங்கும்.%'
    );
  get diagnostics v_rows = row_count; v_count := v_count + v_rows;
  return v_count;
end;
$$;
revoke all on function public.tc_generate_interview_reminders() from public, anon, authenticated;
grant execute on function public.tc_generate_interview_reminders() to service_role;

-- Extend the existing employer status RPC to notify the candidate on every actual status change.
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
  v_candidate_id uuid;
  v_job_title text;
begin
  if auth.uid() is null then raise exception 'Login required'; end if;
  if p_new_status is null or p_new_status not in ('under_review','shortlisted','rejected') then
    raise exception 'Invalid application status';
  end if;
  if not exists (
    select 1 from public.company_members cm
    where cm.company_id=p_company_id and cm.user_id=auth.uid()
      and cm.member_status='active'
      and cm.member_role in ('owner','hr_manager','recruiter')
  ) and not exists (
    select 1 from public.companies c where c.id=p_company_id and c.owner_user_id=auth.uid()
  ) then
    raise exception 'You do not have permission to manage this company applications';
  end if;

  select ja.status,ja.candidate_id,j.job_title
    into v_current_status,v_candidate_id,v_job_title
  from public.job_applications ja
  join public.jobs j on j.id=ja.job_id
  where ja.id=p_application_id and j.company_id=p_company_id
  for update of ja;

  if not found then raise exception 'Application not found for this company'; end if;
  if v_current_status in ('withdrawn','rejected') then raise exception 'This application is closed and cannot be changed'; end if;
  if v_current_status not in ('applied','under_review','shortlisted') then raise exception 'Current application status cannot be changed'; end if;

  update public.job_applications set status=p_new_status,updated_at=now()
  where id=p_application_id;

  if v_current_status is distinct from p_new_status then
    insert into public.tc_notifications(user_id,notification_type,title,body,related_application_id)
    values (
      v_candidate_id,'application_status','உங்கள் விண்ணப்ப நிலை புதுப்பிக்கப்பட்டது',
      'வேலை: '||coalesce(v_job_title,'')||' — புதிய நிலை: '||
      case p_new_status when 'under_review' then 'பரிசீலனையில்' when 'shortlisted' then 'Shortlist' else 'நிராகரிக்கப்பட்டது' end,
      p_application_id
    );
  end if;
  return p_new_status;
end;
$$;
revoke all on function public.tc_company_update_application_status(uuid,uuid,text) from public, anon;
grant execute on function public.tc_company_update_application_status(uuid,uuid,text) to authenticated;

commit;
