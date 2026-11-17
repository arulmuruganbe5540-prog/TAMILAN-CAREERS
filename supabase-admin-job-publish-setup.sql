-- TAMILAN CAREERS: Admin job review + safe publishing setup
-- Run this ONE file in Supabase SQL Editor. Safe to re-run; no existing job rows are deleted.
begin;

do $
begin
  if to_regprocedure('public.is_super_admin()') is null then
    raise exception 'Required function public.is_super_admin() is missing; no changes applied.';
  end if;
  if to_regclass('public.job_posting_drafts') is null then
    raise exception 'Run supabase-setup-pending.sql first; company job draft table is missing.';
  end if;
end $;

create table if not exists public.admin_job_post_reviews (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references auth.users(id) on delete restrict,
  title text not null,
  company_name text,
  status text not null default 'draft'
    check (status in ('draft','pending_review','approved','rejected')),
  payload jsonb not null default '{}'::jsonb
    check (jsonb_typeof(payload) = 'object'),
  review_note text,
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists admin_job_post_reviews_status_created_idx
  on public.admin_job_post_reviews(status, created_at desc);
create index if not exists admin_job_post_reviews_created_by_idx
  on public.admin_job_post_reviews(created_by, created_at desc);

alter table public.admin_job_post_reviews
  add column if not exists published_job_id uuid references public.jobs(id) on delete set null;

alter table public.admin_job_post_reviews enable row level security;
revoke all on public.admin_job_post_reviews from anon;
grant select, insert, update, delete on public.admin_job_post_reviews to authenticated;

drop policy if exists "TC admin job reviews super admin select" on public.admin_job_post_reviews;
create policy "TC admin job reviews super admin select"
on public.admin_job_post_reviews for select to authenticated
using ((select public.is_super_admin()));

drop policy if exists "TC admin job reviews super admin insert" on public.admin_job_post_reviews;
create policy "TC admin job reviews super admin insert"
on public.admin_job_post_reviews for insert to authenticated
with check ((select public.is_super_admin()) and created_by = (select auth.uid()));

drop policy if exists "TC admin job reviews super admin update" on public.admin_job_post_reviews;
create policy "TC admin job reviews super admin update"
on public.admin_job_post_reviews for update to authenticated
using ((select public.is_super_admin()))
with check ((select public.is_super_admin()));

drop policy if exists "TC admin job reviews super admin delete" on public.admin_job_post_reviews;
create policy "TC admin job reviews super admin delete"
on public.admin_job_post_reviews for delete to authenticated
using ((select public.is_super_admin()));

create or replace function public.tc_admin_job_reviews_touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists tc_admin_job_reviews_updated_at on public.admin_job_post_reviews;
create trigger tc_admin_job_reviews_updated_at
before update on public.admin_job_post_reviews
for each row execute function public.tc_admin_job_reviews_touch_updated_at();

-- Company Owner / HR Manager / Recruiter submits a private job draft for
-- Super Admin review. The browser cannot insert directly into the admin queue.
create or replace function public.tc_submit_company_job_draft_for_review(p_draft_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $tc_submit_company_draft$
declare
  v_company_id uuid;
  v_user_id uuid;
  v_draft jsonb;
  v_company_name text;
  v_title text;
  v_payload jsonb;
  v_review_id uuid;
begin
  if auth.uid() is null then raise exception 'Login required'; end if;

  select d.company_id, d.user_id, d.draft
    into v_company_id, v_user_id, v_draft
  from public.job_posting_drafts d
  where d.id = p_draft_id
    and d.user_id = auth.uid()
  for update;

  if not found then raise exception 'Company draft not found or not owned by this account'; end if;

  if not exists (
    select 1 from public.company_members cm
    where cm.company_id = v_company_id
      and cm.user_id = auth.uid()
      and cm.member_status = 'active'
      and cm.member_role in ('owner','hr_manager','recruiter')
  ) then
    raise exception 'Active Owner, HR Manager, or Recruiter permission is required';
  end if;

  select c.company_name into v_company_name
  from public.companies c
  where c.id = v_company_id;

  if not found then raise exception 'Company record not found'; end if;
  if v_draft->>'draft_status' = 'published' then
    raise exception 'This job draft has already been published. Edit it to create a new version before submitting again';
  end if;

  v_title := nullif(btrim(v_draft->>'jobTitle'), '');
  if v_title is null then raise exception 'Job title is required'; end if;
  if nullif(btrim(v_draft->>'description'), '') is null then
    raise exception 'Job description is required';
  end if;
  if nullif(btrim(v_draft->>'category'), '') is null
     or nullif(btrim(v_draft->>'employmentType'), '') is null
     or nullif(btrim(v_draft->>'location'), '') is null then
    raise exception 'Category, employment type, and location are required';
  end if;

  if nullif(btrim(v_draft->>'deadline'),'') is not null then
    if (v_draft->>'deadline') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}  select r.id into v_review_id
  from public.admin_job_post_reviews r
  where r.payload->>'source_draft_id' = p_draft_id::text
    and r.status in ('pending_review','approved')
    and r.published_job_id is null
  order by r.created_at desc
  limit 1;

  if v_review_id is not null then
    return v_review_id;
  end if;

  v_payload := jsonb_build_object(
    'title', v_title,
    'company', v_company_name,
    'company_id', v_company_id,
    'source_draft_id', p_draft_id,
    'category', v_draft->>'category',
    'type', v_draft->>'employmentType',
    'workplace', v_draft->>'workplaceType',
    'location', v_draft->>'location',
    'openings', coalesce(nullif(v_draft->>'openings',''), '1'),
    'experience', v_draft->>'experience',
    'education', v_draft->>'education',
    'salaryMin', v_draft->>'salaryMin',
    'salaryMax', v_draft->>'salaryMax',
    'skills', v_draft->>'skills',
    'description', v_draft->>'description',
    'deadline', v_draft->>'deadline',
    'email', v_draft->>'contactEmail'
  );

  insert into public.admin_job_post_reviews(
    created_by, title, company_name, status, payload
  ) values (
    auth.uid(), v_title, v_company_name,
    'pending_review', v_payload
  )
  returning id into v_review_id;

  update public.job_posting_drafts
  set draft = draft || jsonb_build_object(
    'draft_status','pending_review',
    'submitted_review_id',v_review_id,
    'submitted_at',now()
  ),
  updated_at = now()
  where id = p_draft_id;

  return v_review_id;
end;
$tc_submit_company_draft$;

revoke all on function public.tc_submit_company_job_draft_for_review(uuid) from public, anon;
grant execute on function public.tc_submit_company_job_draft_for_review(uuid) to authenticated;

-- Reflect Admin decisions back into the private company draft for status visibility.
create or replace function public.tc_sync_company_job_draft_review_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $tc_sync_company_draft$
declare
  v_source_draft_id uuid;
  v_status text;
begin
  v_source_draft_id := nullif(new.payload->>'source_draft_id','')::uuid;
  if v_source_draft_id is null then return new; end if;

  v_status := case when new.published_job_id is not null then 'published' else new.status end;

  update public.job_posting_drafts
  set draft = draft || jsonb_build_object(
    'draft_status', v_status,
    'review_note', coalesce(new.review_note,''),
    'published_job_id', new.published_job_id,
    'reviewed_at', new.reviewed_at
  ),
  updated_at = now()
  where id = v_source_draft_id;

  return new;
end;
$tc_sync_company_draft$;

revoke all on function public.tc_sync_company_job_draft_review_status() from public, anon, authenticated;
drop trigger if exists tc_sync_company_job_draft_review_status on public.admin_job_post_reviews;
create trigger tc_sync_company_job_draft_review_status
after update of status, published_job_id, review_note on public.admin_job_post_reviews
for each row execute function public.tc_sync_company_job_draft_review_status();

-- Fields needed by the existing public jobs list/detail pages.
alter table public.jobs add column if not exists location text;
alter table public.jobs add column if not exists education_level text;
alter table public.jobs add column if not exists required_skills text;
alter table public.jobs add column if not exists contact_email text;

create or replace function public.tc_admin_publish_job(p_review_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_review public.admin_job_post_reviews%rowtype;
  v_payload jsonb;
  v_company_id uuid;
  v_category_id uuid;
  v_job_id uuid;
  v_title text;
  v_slug text;
  v_type text;
  v_workplace text;
  v_experience text;
  v_experience_min numeric;
  v_salary_min numeric;
  v_salary_max numeric;
  v_vacancies integer;
  v_deadline timestamptz;
begin
  if not coalesce(public.is_super_admin(), false) then
    raise exception 'Super Admin permission required';
  end if;

  select * into v_review
  from public.admin_job_post_reviews
  where id = p_review_id
  for update;

  if not found then raise exception 'Review item not found'; end if;
  if v_review.status <> 'approved' then
    raise exception 'Only approved job posts can be published';
  end if;
  if v_review.published_job_id is not null then
    return v_review.published_job_id;
  end if;

  v_payload := v_review.payload;
  v_title := nullif(btrim(v_payload->>'title'), '');
  if v_title is null then raise exception 'Job title is required'; end if;
  if nullif(btrim(v_payload->>'description'), '') is null then
    raise exception 'Job description is required';
  end if;

  -- Prefer the exact company ID from an authenticated company submission.
  -- Manual Super Admin posts may still use exact company-name matching.
  if nullif(v_payload->>'company_id','') is not null then
    select c.id into v_company_id
    from public.companies c
    where c.id = (v_payload->>'company_id')::uuid
      and lower(btrim(c.company_name)) = lower(btrim(coalesce(v_payload->>'company', v_review.company_name, '')))
      and c.verification_status = 'verified';
  else
    select c.id into v_company_id
    from public.companies c
    where lower(btrim(c.company_name)) = lower(btrim(coalesce(v_payload->>'company', v_review.company_name, '')))
      and c.verification_status = 'verified'
    order by c.created_at asc
    limit 1;
  end if;

  if v_company_id is null then
    raise exception 'Verified company not found. Check exact company name and verification_status=verified before publishing.';
  end if;

  select jc.id into v_category_id
  from public.job_categories jc
  where jc.is_active = true
    and lower(btrim(jc.category_name)) = lower(btrim(coalesce(v_payload->>'category','')))
  order by jc.created_at asc
  limit 1;

  v_type := lower(replace(btrim(coalesce(v_payload->>'type','')), ' ', '_'));
  if v_type not in ('full_time','part_time','contract','temporary','internship','freelance','daily_wage') then
    raise exception 'Unsupported employment type. Select Full Time, Part Time, Contract, Temporary, Internship, or Freelance.';
  end if;

  v_workplace := case lower(btrim(coalesce(v_payload->>'workplace','')))
    when 'remote' then 'remote'
    when 'hybrid' then 'hybrid'
    else 'onsite'
  end;

  v_experience := coalesce(v_payload->>'experience','');
  if v_experience ~ '[0-9]+[.]?[0-9]*' then
    v_experience_min := substring(v_experience from '[0-9]+[.]?[0-9]*')::numeric;
  end if;

  v_salary_min := nullif(v_payload->>'salaryMin','')::numeric;
  v_salary_max := nullif(v_payload->>'salaryMax','')::numeric;
  v_vacancies := greatest(0, coalesce(nullif(v_payload->>'openings','')::integer, 1));
  if nullif(v_payload->>'deadline','') is not null then
    if (v_payload->>'deadline')::date < (now() at time zone 'Asia/Kolkata')::date then
      raise exception 'Application deadline cannot be in the past';
    end if;
    v_deadline := ((v_payload->>'deadline')::date + time '23:59:59') at time zone 'Asia/Kolkata';
  end if;

  v_slug := trim(both '-' from regexp_replace(lower(v_title), '[^a-z0-9]+', '-', 'g'));
  if v_slug = '' then v_slug := 'job'; end if;
  v_slug := left(v_slug, 90) || '-' || lower(substr(replace(gen_random_uuid()::text,'-',''),1,8));

  insert into public.jobs (
    company_id, category_id, created_by, job_title, job_slug, job_code,
    description, employment_type, workplace_type, experience_min,
    salary_min, salary_max, salary_currency, salary_period, vacancies,
    application_deadline, status, published_at,
    location, education_level, required_skills, contact_email
  ) values (
    v_company_id, v_category_id, v_review.created_by, v_title, v_slug,
    'TC-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)),
    v_payload->>'description', v_type, v_workplace, v_experience_min,
    v_salary_min, v_salary_max, '₹', 'monthly', v_vacancies,
    v_deadline, 'published', now(),
    nullif(btrim(v_payload->>'location'), ''),
    nullif(btrim(v_payload->>'education'), ''),
    nullif(btrim(v_payload->>'skills'), ''),
    nullif(btrim(v_payload->>'email'), '')
  )
  returning id into v_job_id;

  update public.admin_job_post_reviews
  set published_job_id = v_job_id
  where id = p_review_id;

  return v_job_id;
end;
$$;

revoke all on function public.tc_admin_publish_job(uuid) from public, anon;
grant execute on function public.tc_admin_publish_job(uuid) to authenticated;

comment on function public.tc_admin_publish_job(uuid) is
  'Publishes an approved admin review item only for an existing verified company. Idempotent per review item.';

commit;
 then
      raise exception 'Application deadline must be a valid date';
    end if;
    if (v_draft->>'deadline')::date < (pg_catalog.now() at time zone 'Asia/Kolkata')::date then
      raise exception 'Application deadline cannot be in the past';
    end if;
  end if;

  select r.id into v_review_id
  from public.admin_job_post_reviews r
  where r.payload->>'source_draft_id' = p_draft_id::text
    and r.status in ('pending_review','approved')
    and r.published_job_id is null
  order by r.created_at desc
  limit 1;

  if v_review_id is not null then
    return v_review_id;
  end if;

  v_payload := jsonb_build_object(
    'title', v_title,
    'company', v_company_name,
    'company_id', v_company_id,
    'source_draft_id', p_draft_id,
    'category', v_draft->>'category',
    'type', v_draft->>'employmentType',
    'workplace', v_draft->>'workplaceType',
    'location', v_draft->>'location',
    'openings', coalesce(nullif(v_draft->>'openings',''), '1'),
    'experience', v_draft->>'experience',
    'education', v_draft->>'education',
    'salaryMin', v_draft->>'salaryMin',
    'salaryMax', v_draft->>'salaryMax',
    'skills', v_draft->>'skills',
    'description', v_draft->>'description',
    'deadline', v_draft->>'deadline',
    'email', v_draft->>'contactEmail'
  );

  insert into public.admin_job_post_reviews(
    created_by, title, company_name, status, payload
  ) values (
    auth.uid(), v_title, v_company_name,
    'pending_review', v_payload
  )
  returning id into v_review_id;

  update public.job_posting_drafts
  set draft = draft || jsonb_build_object(
    'draft_status','pending_review',
    'submitted_review_id',v_review_id,
    'submitted_at',now()
  ),
  updated_at = now()
  where id = p_draft_id;

  return v_review_id;
end;
$tc_submit_company_draft$;

revoke all on function public.tc_submit_company_job_draft_for_review(uuid) from public, anon;
grant execute on function public.tc_submit_company_job_draft_for_review(uuid) to authenticated;

-- Reflect Admin decisions back into the private company draft for status visibility.
create or replace function public.tc_sync_company_job_draft_review_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $tc_sync_company_draft$
declare
  v_source_draft_id uuid;
  v_status text;
begin
  v_source_draft_id := nullif(new.payload->>'source_draft_id','')::uuid;
  if v_source_draft_id is null then return new; end if;

  v_status := case when new.published_job_id is not null then 'published' else new.status end;

  update public.job_posting_drafts
  set draft = draft || jsonb_build_object(
    'draft_status', v_status,
    'review_note', coalesce(new.review_note,''),
    'published_job_id', new.published_job_id,
    'reviewed_at', new.reviewed_at
  ),
  updated_at = now()
  where id = v_source_draft_id;

  return new;
end;
$tc_sync_company_draft$;

revoke all on function public.tc_sync_company_job_draft_review_status() from public, anon, authenticated;
drop trigger if exists tc_sync_company_job_draft_review_status on public.admin_job_post_reviews;
create trigger tc_sync_company_job_draft_review_status
after update of status, published_job_id, review_note on public.admin_job_post_reviews
for each row execute function public.tc_sync_company_job_draft_review_status();

-- Fields needed by the existing public jobs list/detail pages.
alter table public.jobs add column if not exists location text;
alter table public.jobs add column if not exists education_level text;
alter table public.jobs add column if not exists required_skills text;
alter table public.jobs add column if not exists contact_email text;

create or replace function public.tc_admin_publish_job(p_review_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_review public.admin_job_post_reviews%rowtype;
  v_payload jsonb;
  v_company_id uuid;
  v_category_id uuid;
  v_job_id uuid;
  v_title text;
  v_slug text;
  v_type text;
  v_workplace text;
  v_experience text;
  v_experience_min numeric;
  v_salary_min numeric;
  v_salary_max numeric;
  v_vacancies integer;
  v_deadline timestamptz;
begin
  if not coalesce(public.is_super_admin(), false) then
    raise exception 'Super Admin permission required';
  end if;

  select * into v_review
  from public.admin_job_post_reviews
  where id = p_review_id
  for update;

  if not found then raise exception 'Review item not found'; end if;
  if v_review.status <> 'approved' then
    raise exception 'Only approved job posts can be published';
  end if;
  if v_review.published_job_id is not null then
    return v_review.published_job_id;
  end if;

  v_payload := v_review.payload;
  v_title := nullif(btrim(v_payload->>'title'), '');
  if v_title is null then raise exception 'Job title is required'; end if;
  if nullif(btrim(v_payload->>'description'), '') is null then
    raise exception 'Job description is required';
  end if;

  -- Prefer the exact company ID from an authenticated company submission.
  -- Manual Super Admin posts may still use exact company-name matching.
  if nullif(v_payload->>'company_id','') is not null then
    select c.id into v_company_id
    from public.companies c
    where c.id = (v_payload->>'company_id')::uuid
      and lower(btrim(c.company_name)) = lower(btrim(coalesce(v_payload->>'company', v_review.company_name, '')))
      and c.verification_status = 'verified';
  else
    select c.id into v_company_id
    from public.companies c
    where lower(btrim(c.company_name)) = lower(btrim(coalesce(v_payload->>'company', v_review.company_name, '')))
      and c.verification_status = 'verified'
    order by c.created_at asc
    limit 1;
  end if;

  if v_company_id is null then
    raise exception 'Verified company not found. Check exact company name and verification_status=verified before publishing.';
  end if;

  select jc.id into v_category_id
  from public.job_categories jc
  where jc.is_active = true
    and lower(btrim(jc.category_name)) = lower(btrim(coalesce(v_payload->>'category','')))
  order by jc.created_at asc
  limit 1;

  v_type := lower(replace(btrim(coalesce(v_payload->>'type','')), ' ', '_'));
  if v_type not in ('full_time','part_time','contract','temporary','internship','freelance','daily_wage') then
    raise exception 'Unsupported employment type. Select Full Time, Part Time, Contract, Temporary, Internship, or Freelance.';
  end if;

  v_workplace := case lower(btrim(coalesce(v_payload->>'workplace','')))
    when 'remote' then 'remote'
    when 'hybrid' then 'hybrid'
    else 'onsite'
  end;

  v_experience := coalesce(v_payload->>'experience','');
  if v_experience ~ '[0-9]+[.]?[0-9]*' then
    v_experience_min := substring(v_experience from '[0-9]+[.]?[0-9]*')::numeric;
  end if;

  v_salary_min := nullif(v_payload->>'salaryMin','')::numeric;
  v_salary_max := nullif(v_payload->>'salaryMax','')::numeric;
  v_vacancies := greatest(0, coalesce(nullif(v_payload->>'openings','')::integer, 1));
  if nullif(v_payload->>'deadline','') is not null then
    if (v_payload->>'deadline')::date < (now() at time zone 'Asia/Kolkata')::date then
      raise exception 'Application deadline cannot be in the past';
    end if;
    v_deadline := ((v_payload->>'deadline')::date + time '23:59:59') at time zone 'Asia/Kolkata';
  end if;

  v_slug := trim(both '-' from regexp_replace(lower(v_title), '[^a-z0-9]+', '-', 'g'));
  if v_slug = '' then v_slug := 'job'; end if;
  v_slug := left(v_slug, 90) || '-' || lower(substr(replace(gen_random_uuid()::text,'-',''),1,8));

  insert into public.jobs (
    company_id, category_id, created_by, job_title, job_slug, job_code,
    description, employment_type, workplace_type, experience_min,
    salary_min, salary_max, salary_currency, salary_period, vacancies,
    application_deadline, status, published_at,
    location, education_level, required_skills, contact_email
  ) values (
    v_company_id, v_category_id, v_review.created_by, v_title, v_slug,
    'TC-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)),
    v_payload->>'description', v_type, v_workplace, v_experience_min,
    v_salary_min, v_salary_max, '₹', 'monthly', v_vacancies,
    v_deadline, 'published', now(),
    nullif(btrim(v_payload->>'location'), ''),
    nullif(btrim(v_payload->>'education'), ''),
    nullif(btrim(v_payload->>'skills'), ''),
    nullif(btrim(v_payload->>'email'), '')
  )
  returning id into v_job_id;

  update public.admin_job_post_reviews
  set published_job_id = v_job_id
  where id = p_review_id;

  return v_job_id;
end;
$$;

revoke all on function public.tc_admin_publish_job(uuid) from public, anon;
grant execute on function public.tc_admin_publish_job(uuid) to authenticated;

comment on function public.tc_admin_publish_job(uuid) is
  'Publishes an approved admin review item only for an existing verified company. Idempotent per review item.';

commit;
