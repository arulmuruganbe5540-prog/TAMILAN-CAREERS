-- TAMILAN CAREERS: consolidated pending Supabase setup
-- Project: qkmljuuusfjowexvybvy
-- Run as the Supabase project owner in SQL Editor.
-- This script creates private resume storage, private employer job drafts,
-- and restricted employer read access to candidate profiles for actual applicants.
-- It does NOT publish jobs, change application status, expose resumes to employers,
-- or grant access to candidates who have not applied to that employer's company.
--
-- Safe rerun notes:
-- - The resumes bucket is created only if absent; existing bucket settings are not changed.
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
on conflict (id) do nothing;

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
create policy "TC job drafts select own active member"
on public.job_posting_drafts for select to authenticated
using (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.company_members cm
    where cm.company_id = job_posting_drafts.company_id
      and cm.user_id = (select auth.uid())
      and cm.member_status = 'active'
  )
);

drop policy if exists "TC job drafts insert own active member" on public.job_posting_drafts;
create policy "TC job drafts insert own active member"
on public.job_posting_drafts for insert to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.company_members cm
    where cm.company_id = job_posting_drafts.company_id
      and cm.user_id = (select auth.uid())
      and cm.member_status = 'active'
  )
);

drop policy if exists "TC job drafts update own active member" on public.job_posting_drafts;
create policy "TC job drafts update own active member"
on public.job_posting_drafts for update to authenticated
using (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.company_members cm
    where cm.company_id = job_posting_drafts.company_id
      and cm.user_id = (select auth.uid())
      and cm.member_status = 'active'
  )
)
with check (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.company_members cm
    where cm.company_id = job_posting_drafts.company_id
      and cm.user_id = (select auth.uid())
      and cm.member_status = 'active'
  )
);

drop policy if exists "TC job drafts delete own active member" on public.job_posting_drafts;
create policy "TC job drafts delete own active member"
on public.job_posting_drafts for delete to authenticated
using (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.company_members cm
    where cm.company_id = job_posting_drafts.company_id
      and cm.user_id = (select auth.uid())
      and cm.member_status = 'active'
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

-- =========================================================
-- 3. EMPLOYER READ ACCESS TO ACTUAL APPLICANT PROFILE DETAILS
-- =========================================================

create or replace function public.can_company_view_candidate(p_candidate_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $function$
  select exists (
    select 1
    from public.job_applications ja
    join public.jobs j on j.id = ja.job_id
    join public.companies c on c.id = j.company_id
    where ja.candidate_id = p_candidate_id
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
alter table public.candidate_resumes enable row level security;
grant select, insert, update, delete on public.candidate_resumes to authenticated;
drop policy if exists "TC candidates manage own resume metadata" on public.candidate_resumes;
create policy "TC candidates manage own resume metadata"
on public.candidate_resumes for all to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));
-- Employers intentionally receive no SELECT policy on candidate_resumes.


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

commit;
