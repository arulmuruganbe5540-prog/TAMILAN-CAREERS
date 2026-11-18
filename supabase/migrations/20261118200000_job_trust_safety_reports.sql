-- Trust and safety: verified-company public visibility + authenticated job reporting.
drop policy if exists jobs_read_published on public.jobs;
create policy jobs_read_published
on public.jobs
for select
to anon, authenticated
using (
  status = 'published'
  and (
    (company_id is null and is_admin_managed = true)
    or
    (company_id is not null and exists (
      select 1 from public.companies c
      where c.id = jobs.company_id
        and c.verification_status = 'verified'
    ))
  )
);

create table if not exists public.job_reports (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  reporter_user_id uuid not null references auth.users(id) on delete cascade,
  reason text not null check (reason in (
    'upfront_payment','fake_or_misleading','identity_impersonation',
    'personal_data_request','expired_or_filled','other'
  )),
  details text not null default '' check (char_length(details) <= 2000),
  status text not null default 'pending'
    check (status in ('pending','reviewing','actioned','dismissed')),
  admin_note text,
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (job_id, reporter_user_id)
);

create index if not exists job_reports_status_created_idx
  on public.job_reports(status, created_at desc);
create index if not exists job_reports_job_id_idx
  on public.job_reports(job_id);

alter table public.job_reports enable row level security;

drop policy if exists job_reports_read_own_or_admin on public.job_reports;
create policy job_reports_read_own_or_admin
on public.job_reports for select to authenticated
using (
  reporter_user_id = (select auth.uid())
  or exists (
    select 1 from public.user_roles ur
    where ur.user_id = (select auth.uid()) and ur.role = 'super_admin'
  )
);

drop policy if exists job_reports_admin_update on public.job_reports;
create policy job_reports_admin_update
on public.job_reports for update to authenticated
using (
  exists (
    select 1 from public.user_roles ur
    where ur.user_id = (select auth.uid()) and ur.role = 'super_admin'
  )
)
with check (
  exists (
    select 1 from public.user_roles ur
    where ur.user_id = (select auth.uid()) and ur.role = 'super_admin'
  )
);

revoke all on public.job_reports from anon, authenticated;
grant select on public.job_reports to authenticated;
grant update (status, admin_note, reviewed_by, reviewed_at, updated_at)
  on public.job_reports to authenticated;

create or replace function public.tc_submit_job_report(
  p_job_id uuid,
  p_reason text,
  p_details text default ''
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user uuid := (select auth.uid());
  v_report_id uuid;
begin
  if v_user is null then raise exception 'Login required'; end if;
  if p_reason not in (
    'upfront_payment','fake_or_misleading','identity_impersonation',
    'personal_data_request','expired_or_filled','other'
  ) then raise exception 'Choose a valid report reason'; end if;
  if char_length(coalesce(p_details,'')) > 2000 then
    raise exception 'Report details must be 2000 characters or fewer';
  end if;
  if not exists (
    select 1 from public.jobs j
    where j.id = p_job_id and j.status = 'published'
  ) then raise exception 'Published job not found'; end if;

  insert into public.job_reports(job_id, reporter_user_id, reason, details)
  values (p_job_id, v_user, p_reason, btrim(coalesce(p_details,'')))
  on conflict (job_id, reporter_user_id) do nothing
  returning id into v_report_id;

  if v_report_id is null then
    return jsonb_build_object('success', true, 'already_reported', true);
  end if;
  return jsonb_build_object('success', true, 'report_id', v_report_id);
end;
$function$;

create or replace function public.tc_review_job_report(
  p_report_id uuid,
  p_status text,
  p_admin_note text default ''
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare v_user uuid := (select auth.uid());
begin
  if v_user is null or not exists (
    select 1 from public.user_roles ur
    where ur.user_id = v_user and ur.role = 'super_admin'
  ) then raise exception 'Super Admin permission required'; end if;
  if p_status not in ('reviewing','actioned','dismissed') then
    raise exception 'Invalid report decision'; end if;
  update public.job_reports
  set status=p_status, admin_note=left(coalesce(p_admin_note,''),2000),
      reviewed_by=v_user, reviewed_at=now(), updated_at=now()
  where id=p_report_id;
  if not found then raise exception 'Job report not found'; end if;
  return jsonb_build_object('success',true,'report_id',p_report_id,'status',p_status);
end;
$function$;

revoke all on function public.tc_submit_job_report(uuid,text,text) from public, anon;
grant execute on function public.tc_submit_job_report(uuid,text,text) to authenticated;
revoke all on function public.tc_review_job_report(uuid,text,text) from public, anon;
grant execute on function public.tc_review_job_report(uuid,text,text) to authenticated;
