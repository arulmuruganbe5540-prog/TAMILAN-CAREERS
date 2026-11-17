-- TAMILAN CAREERS: core Data API grants and employer applicant visibility
-- Safe to rerun. RLS remains enabled; grants only make policy-governed operations reachable.
-- Candidate resumes remain owner-only. Employers receive no Storage or resume-metadata access.

begin;

-- =========================================================
-- 1. Profile ownership and application-based employer access
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

revoke all on function public.can_company_view_candidate(uuid) from public, anon;
grant execute on function public.can_company_view_candidate(uuid) to authenticated;

alter table public.profiles enable row level security;
drop policy if exists "TC users manage own profile row" on public.profiles;
create policy "TC users manage own profile row"
on public.profiles for all to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

drop policy if exists "Employers read applicant profiles" on public.profiles;
create policy "Employers read applicant profiles"
on public.profiles for select to authenticated
using (public.can_company_view_candidate(id));

alter table public.job_seeker_profiles enable row level security;
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

-- Active company HR / Recruiter members can load their own company's jobs.
-- Company owners already have the separate jobs_read_own_company policy.
drop policy if exists "jobs_read_active_company_members" on public.jobs;
create policy "jobs_read_active_company_members"
on public.jobs for select to authenticated
using (
  exists (
    select 1
    from public.company_members cm
    where cm.company_id = jobs.company_id
      and cm.user_id = (select auth.uid())
      and cm.member_status = 'active'
      and cm.member_role in ('owner', 'hr_manager', 'recruiter')
  )
);

-- =========================================================
-- 2. Grants matching existing RLS policies
-- =========================================================

-- Candidate account, profile, and private records.
grant select, insert, update on table public.profiles to authenticated;
grant select, insert, update on table public.job_seeker_profiles to authenticated;
grant select, insert, update, delete on table public.candidate_education to authenticated;
grant select, insert, update, delete on table public.candidate_experience to authenticated;
grant select, insert, update, delete on table public.candidate_skills to authenticated;
grant select, insert, update, delete on table public.candidate_languages to authenticated;
grant select, insert, update, delete on table public.candidate_preferences to authenticated;
grant select, insert, update, delete on table public.candidate_certifications to authenticated;
grant select, insert, update, delete on table public.candidate_saved_jobs to authenticated;
grant select, insert, update, delete on table public.candidate_resumes to authenticated;
grant select, insert, update, delete on table public.job_alerts to authenticated;
grant select, insert, update, delete on table public.job_match_preferences to authenticated;
grant select on table public.job_match_results to authenticated;
grant select on table public.job_match_notification_logs to authenticated;
grant select on table public.resume_extracted_data to authenticated;
grant select, insert, update on table public.resume_extraction_reviews to authenticated;

-- Applications: candidates may submit; applicants and authorized company members may read.
grant select, insert on table public.job_applications to authenticated;
grant select on table public.job_application_status_history to authenticated;
grant select on table public.job_interviews to authenticated;
grant select on table public.job_offers to authenticated;

-- Company and job workflows; RLS still controls owner / member / publication scope.
grant select on table public.company_members to authenticated;
grant select, insert, update on table public.companies to authenticated;
grant select on table public.companies to anon;
grant select, insert, update, delete on table public.company_profile_drafts to authenticated;
grant select, insert, update, delete on table public.job_posting_drafts to authenticated;
grant select, insert, update, delete on table public.jobs to authenticated;
grant select on table public.jobs to anon;
grant select, insert, update, delete on table public.job_locations to authenticated;
grant select on table public.job_locations to anon;
grant select, insert, update, delete on table public.job_requirements to authenticated;
grant select on table public.job_requirements to anon;
grant select, insert, update, delete on table public.job_skills to authenticated;
grant select on table public.job_skills to anon;

-- Public lookup data and active job categories.
grant select on table public.countries, public.currencies, public.languages to anon, authenticated;
grant select on table public.job_categories to anon, authenticated;

-- Candidate settings and consent.
grant select on table public.user_roles to authenticated;
grant select, insert on table public.user_consents to authenticated;
grant select, insert, update on table public.user_settings to authenticated;

-- Restricted Admin / Government / external-source queues; RLS checks Super Admin.
grant select, insert, update, delete on table public.admin_job_post_reviews to authenticated;
grant select, insert, update, delete on table public.government_notice_reviews to authenticated;
grant select, insert, update, delete on table public.government_notice_sources to authenticated;
grant select on table public.government_notice_sources to anon;
grant select, insert, update, delete on table public.government_notices to authenticated;
grant select on table public.government_notices to anon;
grant select, insert, update, delete on table public.external_job_sources to authenticated;
grant select, insert, update, delete on table public.external_job_candidates to authenticated;

-- Trigger / event-trigger functions are not public RPC endpoints.
-- Their owning triggers continue to invoke them; clients do not need EXECUTE.
revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.log_job_application_status() from public, anon, authenticated;
revoke all on function public.rls_auto_enable() from public, anon, authenticated;

commit;
