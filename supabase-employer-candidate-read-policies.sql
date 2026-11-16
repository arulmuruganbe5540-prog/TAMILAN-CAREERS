-- TAMILAN CAREERS: secure employer read access to candidate profile details
-- Run this in Supabase SQL Editor only after reviewing the policy scope.
-- It grants SELECT only to the company owner / active HR manager / recruiter
-- for candidates who have actually applied to a job belonging to that company.
-- It does not grant access to resumes or allow INSERT / UPDATE / DELETE.

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
on public.profiles
for select
to authenticated
using (public.can_company_view_candidate(id));

drop policy if exists "Employers read applicant job seeker profiles" on public.job_seeker_profiles;
create policy "Employers read applicant job seeker profiles"
on public.job_seeker_profiles
for select
to authenticated
using (public.can_company_view_candidate(user_id));

drop policy if exists "Employers read applicant education" on public.candidate_education;
create policy "Employers read applicant education"
on public.candidate_education
for select
to authenticated
using (public.can_company_view_candidate(user_id));

drop policy if exists "Employers read applicant experience" on public.candidate_experience;
create policy "Employers read applicant experience"
on public.candidate_experience
for select
to authenticated
using (public.can_company_view_candidate(user_id));

drop policy if exists "Employers read applicant skills" on public.candidate_skills;
create policy "Employers read applicant skills"
on public.candidate_skills
for select
to authenticated
using (public.can_company_view_candidate(user_id));

drop policy if exists "Employers read applicant certifications" on public.candidate_certifications;
create policy "Employers read applicant certifications"
on public.candidate_certifications
for select
to authenticated
using (public.can_company_view_candidate(user_id));

drop policy if exists "Employers read applicant languages" on public.candidate_languages;
create policy "Employers read applicant languages"
on public.candidate_languages
for select
to authenticated
using (public.can_company_view_candidate(user_id));

drop policy if exists "Employers read applicant preferences" on public.candidate_preferences;
create policy "Employers read applicant preferences"
on public.candidate_preferences
for select
to authenticated
using (public.can_company_view_candidate(user_id));

-- Intentionally no employer policy on candidate_resumes or resume_extracted_data.
-- Resume downloads must use a server-verified, short-lived signed URL.
