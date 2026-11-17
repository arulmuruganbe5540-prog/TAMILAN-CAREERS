-- TAMILAN CAREERS: private Resume & Document Storage
-- Run in Supabase SQL Editor for project qkmljuuusfjowexvybvy.
-- Idempotent: enforces a private 5 MB bucket, owner-only file access,
-- owner-only metadata, and a maximum of five documents per candidate.

begin;

-- Stop before migration work if the Storage or application schema is incomplete.
do $tc_resume_storage_guard$
declare
  v_missing text[] := array[]::text[];
  v_item text;
begin
  if to_regclass('storage.buckets') is null
     or to_regclass('storage.objects') is null
     or to_regclass('public.job_applications') is null then
    raise exception 'Resume Storage setup stopped: Storage relations or job_applications are missing; run supabase-schema-audit.sql first.';
  end if;
  foreach v_item in array array[
    'job_applications.id','job_applications.candidate_id'
  ] loop
    if not exists (
      select 1 from information_schema.columns c
      where c.table_schema='public'
        and c.table_name=split_part(v_item,'.',1)
        and c.column_name=split_part(v_item,'.',2)
    ) then
      v_missing := array_append(v_missing,v_item);
    end if;
  end loop;
  if to_regclass('public.candidate_resumes') is not null then
    foreach v_item in array array[
      'candidate_resumes.id','candidate_resumes.user_id','candidate_resumes.file_path',
      'candidate_resumes.original_file_name','candidate_resumes.file_type','candidate_resumes.file_size_bytes'
    ] loop
      if not exists (
        select 1 from information_schema.columns c
        where c.table_schema='public'
          and c.table_name=split_part(v_item,'.',1)
          and c.column_name=split_part(v_item,'.',2)
      ) then
        v_missing := array_append(v_missing,v_item);
      end if;
    end loop;
  end if;
  if cardinality(v_missing) > 0 then
    raise exception 'Resume Storage setup stopped: required columns are missing: %', array_to_string(v_missing, ', ');
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='job_applications'
      and column_name='resume_id' and data_type <> 'uuid'
  ) then
    raise exception 'Resume Storage setup stopped: job_applications.resume_id exists but is not UUID.';
  end if;
end;
$tc_resume_storage_guard$;

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
using (bucket_id = 'resumes' and (storage.foldername(name))[1] = (select auth.uid()::text));

drop policy if exists "TC resumes owner can upload" on storage.objects;
create policy "TC resumes owner can upload"
on storage.objects for insert to authenticated
with check (bucket_id = 'resumes' and (storage.foldername(name))[1] = (select auth.uid()::text));

drop policy if exists "TC resumes owner can update" on storage.objects;
create policy "TC resumes owner can update"
on storage.objects for update to authenticated
using (bucket_id = 'resumes' and (storage.foldername(name))[1] = (select auth.uid()::text))
with check (bucket_id = 'resumes' and (storage.foldername(name))[1] = (select auth.uid()::text));

drop policy if exists "TC resumes owner can delete" on storage.objects;
create policy "TC resumes owner can delete"
on storage.objects for delete to authenticated
using (bucket_id = 'resumes' and (storage.foldername(name))[1] = (select auth.uid()::text));

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
  file_size_bytes bigint not null check (file_size_bytes between 1 and 5242880),
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint candidate_resumes_owner_path check (
    left(file_path, length(user_id::text) + 1) = user_id::text || '/'
  )
);

create index if not exists candidate_resumes_user_created_idx
  on public.candidate_resumes(user_id, created_at desc);

-- Link an optional candidate-owned resume to an application. The employer still
-- cannot read the metadata directly; company-resume-access verifies membership.
alter table public.job_applications
  add column if not exists resume_id uuid
  references public.candidate_resumes(id) on delete set null;
create index if not exists job_applications_resume_id_idx
  on public.job_applications(resume_id) where resume_id is not null;

-- Prevent a candidate from attaching another user's Resume by forging an ID.
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

create or replace function public.tc_limit_candidate_resume_count()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare existing_count integer;
begin
  perform pg_advisory_xact_lock(hashtextextended(new.user_id::text, 0));
  select count(*) into existing_count from public.candidate_resumes where user_id = new.user_id;
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

commit;
