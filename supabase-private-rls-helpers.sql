-- Move authorization-only RLS helpers out of the exposed public schema.
-- RLS policies still call them as authenticated; the private schema is not a Data API schema.
begin;

create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create or replace function private.can_access_company(p_company_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $function$
  select exists (
    select 1 from public.companies c
    where c.id = p_company_id
      and (
        c.owner_user_id = auth.uid()
        or exists (
          select 1 from public.company_members cm
          where cm.company_id = c.id and cm.user_id = auth.uid()
            and cm.member_status = 'active'
            and cm.member_role in ('owner', 'hr_manager', 'recruiter')
        )
      )
  );
$function$;

create or replace function private.can_access_job_application(p_application_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $function$
  select exists (
    select 1
    from public.job_applications ja
    join public.jobs j on j.id = ja.job_id
    join public.companies c on c.id = j.company_id
    where ja.id = p_application_id
      and (
        ja.candidate_id = auth.uid()
        or c.owner_user_id = auth.uid()
        or exists (
          select 1 from public.company_members cm
          where cm.company_id = c.id and cm.user_id = auth.uid()
            and cm.member_status = 'active'
            and cm.member_role in ('owner', 'hr_manager', 'recruiter')
        )
      )
  );
$function$;

create or replace function private.can_company_view_candidate(p_candidate_id uuid)
returns boolean language sql stable security definer set search_path = ''
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
          select 1 from public.company_members cm
          where cm.company_id = c.id and cm.user_id = auth.uid()
            and cm.member_status = 'active'
            and cm.member_role in ('owner', 'hr_manager', 'recruiter')
        )
      )
  );
$function$;

revoke all on function private.can_access_company(uuid) from public, anon;
revoke all on function private.can_access_job_application(uuid) from public, anon;
revoke all on function private.can_company_view_candidate(uuid) from public, anon;
grant execute on function private.can_access_company(uuid) to authenticated;
grant execute on function private.can_access_job_application(uuid) to authenticated;
grant execute on function private.can_company_view_candidate(uuid) to authenticated;

alter policy "companies_read_active_members" on public.companies using (private.can_access_company(id));
alter policy "jobs_read_active_company_members" on public.jobs using (private.can_access_company(company_id));
alter policy "Employers read applicant profiles" on public.profiles using (private.can_company_view_candidate(id));
alter policy "Employers read applicant job seeker profiles" on public.job_seeker_profiles using (private.can_company_view_candidate(user_id));
alter policy "Employers read applicant education" on public.candidate_education using (private.can_company_view_candidate(user_id));
alter policy "Employers read applicant experience" on public.candidate_experience using (private.can_company_view_candidate(user_id));
alter policy "Employers read applicant skills" on public.candidate_skills using (private.can_company_view_candidate(user_id));
alter policy "Employers read applicant certifications" on public.candidate_certifications using (private.can_company_view_candidate(user_id));
alter policy "Employers read applicant languages" on public.candidate_languages using (private.can_company_view_candidate(user_id));
alter policy "job_applications_read_authorized" on public.job_applications using (private.can_access_job_application(id));
alter policy "application_history_read_authorized" on public.job_application_status_history using (private.can_access_job_application(application_id));
alter policy "job_interviews_read_authorized" on public.job_interviews using (private.can_access_job_application(application_id));
alter policy "job_offers_read_authorized" on public.job_offers using (private.can_access_job_application(application_id));

drop policy if exists "job_offers_select_authorized" on storage.objects;
create policy "job_offers_select_authorized" on storage.objects
for select to authenticated
using (
  bucket_id = 'job-offers'
  and name ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.pdf$'
  and private.can_access_job_application(split_part(name, '/', 1)::uuid)
);

revoke all on function public.can_access_company(uuid) from public, anon, authenticated;
revoke all on function public.can_access_job_application(uuid) from public, anon, authenticated;
revoke all on function public.can_company_view_candidate(uuid) from public, anon, authenticated;

commit;
