-- Automatically close published jobs after their India-local application deadline.
-- Admin publishing stores date-only deadlines as 23:59:59 Asia/Kolkata in timestamptz.
create or replace function public.tc_expire_published_jobs()
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_closed_count integer := 0;
begin
  update public.jobs as j
  set status = 'closed',
      updated_at = now()
  where j.status = 'published'
    and j.application_deadline is not null
    and j.application_deadline < now();

  get diagnostics v_closed_count = row_count;
  return v_closed_count;
end;
$function$;

revoke all on function public.tc_expire_published_jobs() from public;
revoke all on function public.tc_expire_published_jobs() from anon;
revoke all on function public.tc_expire_published_jobs() from authenticated;

-- Run shortly after midnight India time (18:35 UTC = 00:05 IST).
do $schedule$
declare
  v_job_id bigint;
begin
  select jobid into v_job_id
  from cron.job
  where jobname = 'expire-published-jobs-daily';

  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;

  perform cron.schedule(
    'expire-published-jobs-daily',
    '35 18 * * *',
    'select public.tc_expire_published_jobs();'
  );
end;
$schedule$;
