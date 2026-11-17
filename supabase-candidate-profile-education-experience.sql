-- TAMILAN CAREERS: candidate education and work-experience records
-- Safe to run more than once. Candidate-owned rows only.
-- This migration does not change existing profile, job, or application data.

begin;

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
  constraint candidate_education_dates_valid check (
    start_date is null or end_date is null or end_date >= start_date
  ),
  constraint candidate_education_current_has_no_end check (
    is_current = false or end_date is null
  )
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
  constraint candidate_experience_dates_valid check (
    start_date is null or end_date is null or end_date >= start_date
  ),
  constraint candidate_experience_current_has_no_end check (
    is_current = false or end_date is null
  )
);

create index if not exists candidate_education_user_start_idx
  on public.candidate_education(user_id, start_date desc);
create index if not exists candidate_experience_user_start_idx
  on public.candidate_experience(user_id, start_date desc);

alter table public.candidate_education enable row level security;
alter table public.candidate_experience enable row level security;

grant select, insert, update, delete on public.candidate_education to authenticated;
grant select, insert, update, delete on public.candidate_experience to authenticated;

drop policy if exists "TC seekers manage own education" on public.candidate_education;
create policy "TC seekers manage own education"
  on public.candidate_education for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "TC seekers manage own experience" on public.candidate_experience;
create policy "TC seekers manage own experience"
  on public.candidate_experience for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

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

commit;
