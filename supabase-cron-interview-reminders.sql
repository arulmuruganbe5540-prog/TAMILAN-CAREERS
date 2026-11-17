-- TAMILAN CAREERS: schedule accepted-interview reminders every 15 minutes.
-- Safe to rerun. The reminder function creates candidate notifications only when
-- an accepted interview is approximately 24 hours or 1 hour away.
-- The function itself is restricted to trusted database execution.

create extension if not exists pg_cron;

do $tc_interview_reminder_cron$
begin
  if not exists (
    select 1 from cron.job where jobname = 'tc-interview-reminders-15m'
  ) then
    perform cron.schedule(
      'tc-interview-reminders-15m',
      '*/15 * * * *',
      'select public.tc_generate_interview_reminders();'
    );
  end if;
end;
$tc_interview_reminder_cron$;

-- Verify with:
-- select jobid, jobname, schedule, command, active, username
-- from cron.job where jobname = 'tc-interview-reminders-15m';
