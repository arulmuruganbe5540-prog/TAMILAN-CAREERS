-- TAMILAN CAREERS: consolidated pending Supabase setup
-- Project: qkmljuuusfjowexvybvy
-- Run as the Supabase project owner in SQL Editor.
-- This script creates private resume storage and candidate resume metadata,
-- private employer job drafts,
-- and restricted employer read access to candidate profiles for actual applicants.
-- It does NOT publish jobs, change application status, expose resumes to employers,
-- or grant access to candidates who have not applied to that employer's company.
--
-- Safe rerun notes:
-- - The resumes bucket is always enforced as private with a 5 MB file limit.
-- - Policies in this script are replaced by name.
-- - The job_posting_drafts table is created only if absent.
--
-- After running, verify that the resumes bucket is PRIVATE in Storage settings.

begin;

-- =========================================================
-- 1. PRIVATE RESUME STORAGE (candidate owns their own folder)
-- =========================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'resumes',
  'resumes',
  false,
  5242880,
  array[
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ]::text[]
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "TC resumes owner can read" on storage.objects;
create policy "TC resumes owner can read"
on storage.objects for select to authenticated
using (
  bucket_id = 'resumes'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

drop policy if exists "TC resumes owner can upload" on storage.objects;
create policy "TC resumes owner can upload"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'resumes'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

drop policy if exists "TC resumes owner can update" on storage.objects;
create policy "TC resumes owner can update"
on storage.objects for update to authenticated
using (
  bucket_id = 'resumes'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
)
with check (
  bucket_id = 'resumes'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

drop policy if exists "TC resumes owner can delete" on storage.objects;
create policy "TC resumes owner can delete"
on storage.objects for delete to authenticated
using (
  bucket_id = 'resumes'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

-- =========================================================
-- 2. PRIVATE COMPANY JOB-POSTING DRAFTS (not published jobs)
-- =========================================================

create table if not exists public.job_posting_drafts (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  draft jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint job_posting_drafts_draft_is_object check (jsonb_typeof(draft) = 'object'),
  constraint job_posting_drafts_company_user_unique unique (company_id, user_id)
);

create index if not exists job_posting_drafts_user_id_idx
  on public.job_posting_drafts(user_id);
create index if not exists job_posting_drafts_company_id_idx
  on public.job_posting_drafts(company_id);

alter table public.job_posting_drafts enable row level security;
grant select, insert, update, delete on public.job_posting_drafts to authenticated;

drop policy if exists "TC job drafts select own active member" on public.job_posting_drafts;
drop policy if exists "TC job drafts select own authorized member" on public.job_posting_drafts;
create policy "TC job drafts select own active member"
on public.job_posting_drafts for select to authenticated
using (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.company_members cm
    where cm.company_id = job_posting_drafts.company_id
      and cm.user_id = (select auth.uid())
      and cm.member_status = 'active'
      and cm.member_role in ('owner', 'hr_manager', 'recruiter')
  )
);

drop policy if exists "TC job drafts insert own active member" on public.job_posting_drafts;
drop policy if exists "TC job drafts insert own authorized member" on public.job_posting_drafts;
create policy "TC job drafts insert own active member"
on public.job_posting_drafts for insert to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.company_members cm
    where cm.company_id = job_posting_drafts.company_id
      and cm.user_id = (select auth.uid())
      and cm.member_status = 'active'
      and cm.member_role in ('owner', 'hr_manager', 'recruiter')
  )
);

drop policy if exists "TC job drafts update own active member" on public.job_posting_drafts;
drop policy if exists "TC job drafts update own authorized member" on public.job_posting_drafts;
create policy "TC job drafts update own active member"
on public.job_posting_drafts for update to authenticated
using (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.company_members cm
    where cm.company_id = job_posting_drafts.company_id
      and cm.user_id = (select auth.uid())
      and cm.member_status = 'active'
      and cm.member_role in ('owner', 'hr_manager', 'recruiter')
  )
)
with check (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.company_members cm
    where cm.company_id = job_posting_drafts.company_id
      and cm.user_id = (select auth.uid())
      and cm.member_status = 'active'
      and cm.member_role in ('owner', 'hr_manager', 'recruiter')
  )
);

drop policy if exists "TC job drafts delete own active member" on public.job_posting_drafts;
drop policy if exists "TC job drafts delete own authorized member" on public.job_posting_drafts;
create policy "TC job drafts delete own active member"
on public.job_posting_drafts for delete to authenticated
using (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.company_members cm
    where cm.company_id = job_posting_drafts.company_id
      and cm.user_id = (select auth.uid())
      and cm.member_status = 'active'
      and cm.member_role in ('owner', 'hr_manager', 'recruiter')
  )
);

create or replace function public.tc_job_posting_drafts_touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists tc_job_posting_drafts_updated_at on public.job_posting_drafts;
create trigger tc_job_posting_drafts_updated_at
before update on public.job_posting_drafts
for each row execute function public.tc_job_posting_drafts_touch_updated_at();

comment on table public.job_posting_drafts is
  'Private company job-posting drafts only. Not public jobs and not application records.';

-- Create candidate education/experience tables before adding employer read policies.
create table if not exists public.candidate_education (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  institution_name text not null check (length(btrim(institution_name)) between 1 and 180),
  qualification text not null check (length(btrim(qualification)) between 1 and 120),
  field_of_study text, grade text, start_date date, end_date date,
  is_current boolean not null default false, description text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  constraint candidate_education_dates_valid check (start_date is null or end_date is null or end_date >= start_date),
  constraint candidate_education_current_has_no_end check (is_current = false or end_date is null)
);
create table if not exists public.candidate_experience (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  company_name text not null check (length(btrim(company_name)) between 1 and 180),
  job_title text not null check (length(btrim(job_title)) between 1 and 140),
  employment_type text, city text, start_date date, end_date date,
  is_current boolean not null default false, description text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  constraint candidate_experience_dates_valid check (start_date is null or end_date is null or end_date >= start_date),
  constraint candidate_experience_current_has_no_end check (is_current = false or end_date is null)
);
create index if not exists candidate_education_user_start_idx on public.candidate_education(user_id, start_date desc);
create index if not exists candidate_experience_user_start_idx on public.candidate_experience(user_id, start_date desc);

create or replace function public.tc_candidate_profile_records_touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
drop trigger if exists tc_candidate_education_updated_at on public.candidate_education;
create trigger tc_candidate_education_updated_at
before update on public.candidate_education
for each row execute function public.tc_candidate_profile_records_touch_updated_at();
drop trigger if exists tc_candidate_experience_updated_at on public.candidate_experience;
create trigger tc_candidate_experience_updated_at
before update on public.candidate_experience
for each row execute function public.tc_candidate_profile_records_touch_updated_at();

create table if not exists public.candidate_certifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  certificate_name text not null check (length(btrim(certificate_name)) between 1 and 180),
  issuing_organization text,
  issue_date date,
  expiry_date date,
  credential_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint candidate_certifications_dates_valid check (issue_date is null or expiry_date is null or expiry_date >= issue_date)
);
create index if not exists candidate_certifications_user_issue_idx on public.candidate_certifications(user_id, issue_date desc);

create or replace function public.tc_candidate_certifications_touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
drop trigger if exists tc_candidate_certifications_updated_at on public.candidate_certifications;
create trigger tc_candidate_certifications_updated_at
before update on public.candidate_certifications
for each row execute function public.tc_candidate_certifications_touch_updated_at();

-- =========================================================
-- 3. EMPLOYER READ ACCESS TO ACTUAL APPLICANT PROFILE DETAILS
-- =========================================================

create or replace function public.can_company_view_candidate(p_candidate_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.job_applications ja
    join public.jobs j on j.id = ja.job_id
    join public.companies c on c.id = j.company_id
    where ja.candidate_id = p_candidate_id
      and ja.status <> 'withdrawn'
      and (
        c.owner_user_id = auth.uid()
        or exists (
          select 1
          from public.company_members cm
          where cm.company_id = c.id
            and cm.user_id = auth.uid()
            and cm.member_status = 'active'
            and cm.member_role in ('owner', 'hr_manager', 'recruiter')
        )
      )
  );
$function$;

revoke all on function public.can_company_view_candidate(uuid) from public;
grant execute on function public.can_company_view_candidate(uuid) to authenticated;

drop policy if exists "Employers read applicant profiles" on public.profiles;
create policy "Employers read applicant profiles"
on public.profiles for select to authenticated
using (public.can_company_view_candidate(id));

drop policy if exists "Employers read applicant job seeker profiles" on public.job_seeker_profiles;
create policy "Employers read applicant job seeker profiles"
on public.job_seeker_profiles for select to authenticated
using (public.can_company_view_candidate(user_id));

drop policy if exists "Employers read applicant education" on public.candidate_education;
create policy "Employers read applicant education"
on public.candidate_education for select to authenticated
using (public.can_company_view_candidate(user_id));

drop policy if exists "Employers read applicant experience" on public.candidate_experience;
create policy "Employers read applicant experience"
on public.candidate_experience for select to authenticated
using (public.can_company_view_candidate(user_id));

drop policy if exists "Employers read applicant skills" on public.candidate_skills;
create policy "Employers read applicant skills"
on public.candidate_skills for select to authenticated
using (public.can_company_view_candidate(user_id));

-- Candidate certifications are not granted here because the table schema is not part of this migration.

drop policy if exists "Employers read applicant certifications" on public.candidate_certifications;
create policy "Employers read applicant certifications"
on public.candidate_certifications for select to authenticated
using (public.can_company_view_candidate(user_id));

drop policy if exists "Employers read applicant languages" on public.candidate_languages;
create policy "Employers read applicant languages"
on public.candidate_languages for select to authenticated
using (public.can_company_view_candidate(user_id));

drop policy if exists "Employers read applicant preferences" on public.candidate_preferences;
create policy "Employers read applicant preferences"
on public.candidate_preferences for select to authenticated
using (public.can_company_view_candidate(user_id));

-- Deliberately no employer access to candidate_resumes or resume_extracted_data.
-- Resume access needs a separate server-verified, short-lived signed URL workflow.


-- =========================================================
-- 4. CANDIDATE RESUME METADATA (owner-only; no employer access)
-- =========================================================
create table if not exists public.candidate_resumes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  resume_title text not null default 'Resume'
    check (length(btrim(resume_title)) between 1 and 160),
  file_path text not null unique,
  original_file_name text not null
    check (length(btrim(original_file_name)) between 1 and 255),
  file_type text not null check (file_type in (
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  )),
  file_size_bytes bigint not null
    check (file_size_bytes between 1 and 5242880),
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint candidate_resumes_owner_path check (
    left(file_path, length(user_id::text) + 1) = user_id::text || '/'
  )
);
create index if not exists candidate_resumes_user_created_idx
  on public.candidate_resumes(user_id, created_at desc);

-- Optional resume selected during job application; secure employer access is
-- provided only by the server-verified company-resume-access function.
alter table public.job_applications
  add column if not exists resume_id uuid
  references public.candidate_resumes(id) on delete set null;
create index if not exists job_applications_resume_id_idx
  on public.job_applications(resume_id) where resume_id is not null;

-- Reject forged Resume IDs that do not belong to the applicant.
create or replace function public.tc_validate_application_resume_owner()
returns trigger
language plpgsql
set search_path = ''
as $tc_validate_resume$
declare
  v_resume_owner uuid;
begin
  if new.resume_id is null then return new; end if;
  select cr.user_id into v_resume_owner
  from public.candidate_resumes cr
  where cr.id = new.resume_id;
  if not found or v_resume_owner is distinct from new.candidate_id then
    raise exception 'The selected Resume does not belong to this candidate';
  end if;
  return new;
end;
$tc_validate_resume$;
revoke all on function public.tc_validate_application_resume_owner() from public;
drop trigger if exists tc_validate_application_resume_owner on public.job_applications;
create trigger tc_validate_application_resume_owner
before insert or update of resume_id, candidate_id on public.job_applications
for each row execute function public.tc_validate_application_resume_owner();
alter table public.candidate_resumes enable row level security;
grant select, insert, update, delete on public.candidate_resumes to authenticated;
drop policy if exists "TC candidates manage own resume metadata" on public.candidate_resumes;
create policy "TC candidates manage own resume metadata"
on public.candidate_resumes for all to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));
-- Employers intentionally receive no SELECT policy on candidate_resumes.

create or replace function public.tc_limit_candidate_resume_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  existing_count integer;
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.user_id::text, 0));
  select count(*) into existing_count
  from public.candidate_resumes
  where user_id = new.user_id;
  if existing_count >= 5 then
    raise exception 'A maximum of 5 documents is allowed per candidate';
  end if;
  return new;
end;
$$;
revoke all on function public.tc_limit_candidate_resume_count() from public;
drop trigger if exists tc_limit_candidate_resume_count on public.candidate_resumes;
create trigger tc_limit_candidate_resume_count
before insert on public.candidate_resumes
for each row execute function public.tc_limit_candidate_resume_count();


-- =========================================================
-- 4A. CANDIDATE EDUCATION AND WORK EXPERIENCE TABLES
-- =========================================================
create table if not exists public.candidate_education (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  institution_name text not null check (length(btrim(institution_name)) between 1 and 180),
  qualification text not null check (length(btrim(qualification)) between 1 and 120),
  field_of_study text,
  grade text,
  start_date date,
  end_date date,
  is_current boolean not null default false,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint candidate_education_dates_valid check (start_date is null or end_date is null or end_date >= start_date),
  constraint candidate_education_current_has_no_end check (is_current = false or end_date is null)
);

create table if not exists public.candidate_experience (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  company_name text not null check (length(btrim(company_name)) between 1 and 180),
  job_title text not null check (length(btrim(job_title)) between 1 and 140),
  employment_type text,
  city text,
  start_date date,
  end_date date,
  is_current boolean not null default false,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint candidate_experience_dates_valid check (start_date is null or end_date is null or end_date >= start_date),
  constraint candidate_experience_current_has_no_end check (is_current = false or end_date is null)
);

create index if not exists candidate_education_user_start_idx on public.candidate_education(user_id, start_date desc);
create index if not exists candidate_experience_user_start_idx on public.candidate_experience(user_id, start_date desc);

-- =========================================================
-- 5. JOB SEEKER SELF-MANAGEMENT POLICIES FOR PROFILE TABLES
-- =========================================================
-- These policies let each authenticated Job Seeker manage only
-- rows carrying their own auth.uid(). They do not grant employer access.
alter table public.profiles enable row level security;
grant select, insert, update on public.profiles to authenticated;
drop policy if exists "TC users manage own profile row" on public.profiles;
create policy "TC users manage own profile row"
on public.profiles for all to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

alter table public.job_seeker_profiles enable row level security;
grant select, insert, update, delete on public.job_seeker_profiles to authenticated;
drop policy if exists "TC seekers manage own seeker profile" on public.job_seeker_profiles;
create policy "TC seekers manage own seeker profile"
on public.job_seeker_profiles for all to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

alter table public.candidate_skills enable row level security;
grant select, insert, update, delete on public.candidate_skills to authenticated;
drop policy if exists "TC seekers manage own skills" on public.candidate_skills;
create policy "TC seekers manage own skills"
on public.candidate_skills for all to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

alter table public.candidate_languages enable row level security;
grant select, insert, update, delete on public.candidate_languages to authenticated;
drop policy if exists "TC seekers manage own languages" on public.candidate_languages;
create policy "TC seekers manage own languages"
on public.candidate_languages for all to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

alter table public.candidate_preferences enable row level security;
grant select, insert, update, delete on public.candidate_preferences to authenticated;
drop policy if exists "TC seekers manage own preferences" on public.candidate_preferences;
create policy "TC seekers manage own preferences"
on public.candidate_preferences for all to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));


-- Candidate-owned certifications
alter table public.candidate_certifications enable row level security;
grant select, insert, update, delete on public.candidate_certifications to authenticated;
drop policy if exists "TC seekers manage own certifications" on public.candidate_certifications;
create policy "TC seekers manage own certifications"
on public.candidate_certifications for all to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

-- Candidate-owned education records
alter table public.candidate_education enable row level security;
grant select, insert, update, delete on public.candidate_education to authenticated;
drop policy if exists "TC seekers manage own education" on public.candidate_education;
create policy "TC seekers manage own education"
on public.candidate_education for all to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

-- Candidate-owned work experience records
alter table public.candidate_experience enable row level security;
grant select, insert, update, delete on public.candidate_experience to authenticated;
drop policy if exists "TC seekers manage own experience" on public.candidate_experience;
create policy "TC seekers manage own experience"
on public.candidate_experience for all to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

commit;
