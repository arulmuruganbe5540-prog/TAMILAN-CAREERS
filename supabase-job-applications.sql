-- TAMILAN CAREERS: Job applications
-- Review the jobs.id type before running. This script expects public.jobs.id to be UUID.

create table if not exists public.job_applications (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  applicant_user_id uuid not null references auth.users(id) on delete cascade,
  applicant_name text not null check (char_length(trim(applicant_name)) between 2 and 120),
  applicant_email text,
  applicant_phone text,
  cover_letter text,
  application_status text not null default 'submitted'
    check (application_status in ('submitted','under_review','shortlisted','rejected','withdrawn')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint job_applications_one_per_user unique (job_id, applicant_user_id)
);

create index if not exists job_applications_applicant_idx
  on public.job_applications(applicant_user_id);
create index if not exists job_applications_job_idx
  on public.job_applications(job_id);

alter table public.job_applications enable row level security;

grant select, insert on public.job_applications to authenticated;

drop policy if exists "TC applicants submit own application" on public.job_applications;
create policy "TC applicants submit own application"
on public.job_applications
for insert to authenticated
with check (
  applicant_user_id = (select auth.uid())
  and exists (
    select 1 from public.jobs j
    where j.id = job_applications.job_id
      and (j.status is null or lower(j.status) in ('active','published','open','approved'))
  )
);

drop policy if exists "TC applicants read own applications" on public.job_applications;
create policy "TC applicants read own applications"
on public.job_applications
for select to authenticated
using (applicant_user_id = (select auth.uid()));

comment on table public.job_applications is
'Job applications submitted by authenticated job seekers. Applicants can insert and read only their own records. Employer review access must be added only after company/job ownership schema is verified.';
