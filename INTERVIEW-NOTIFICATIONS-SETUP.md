# TAMILAN CAREERS — Interview & Notification Setup

## Included in this change

- Private per-user notification inbox with read/unread state.
- Candidate notification when an employer changes application status using the secure status RPC.
- Employer can send an interview invitation from each eligible applicant card.
- Invitation includes date/time, mode, venue or meeting link, and letter text.
- Candidate can accept or decline; authorized company members receive a response notification.
- Candidate and company notification center at `notifications.html`.
- Dashboard links for candidates and companies.
- Database function to generate 24-hour and 1-hour reminders for accepted interviews.

## Required Supabase setup

1. Open the Supabase SQL Editor for the TAMILAN CAREERS project.
2. Open `supabase-interview-notifications.sql` from this repository.
3. Copy the complete SQL into the SQL Editor and run it once.
4. Confirm that `tc_notifications` and `tc_interview_invitations` exist under Table Editor.
5. Sign in with a company Owner / active HR Manager / Recruiter account, open Company Applicants, and send a test invitation to a test candidate application.
6. Sign in as that candidate, open Dashboard → Notifications, and accept or decline the invitation.

The SQL is safe to rerun. The browser cannot directly insert notifications or modify interview records; those actions go through security-definer RPCs that validate the signed-in user and application/company relationship.

## Reminder scheduling

The SQL creates `public.tc_generate_interview_reminders()`. It generates candidate notifications for accepted interviews about 24 hours and 1 hour before the scheduled time, and avoids creating the same reminder twice.

**Reminders are not automatic until a scheduler is configured.** If Supabase Cron (pg_cron) is enabled in this project, an administrator can schedule the function every 15 minutes, for example:

```sql
select cron.schedule(
  'tc-interview-reminders-every-15-minutes',
  '*/15 * * * *',
  $$select public.tc_generate_interview_reminders();$$
);
```

Check whether the job already exists before scheduling it again. If pg_cron is unavailable, use a trusted external scheduler to invoke the function with an appropriately secured database connection; never expose a service-role key in browser code.

## Important deployment boundary

GitHub Pages publishes the HTML/JavaScript. Supabase SQL must be run separately. Until the SQL is run, notification and interview actions will report that the database function/table is unavailable. No live interview invitations or reminders are claimed before the SQL and authenticated tests succeed.
