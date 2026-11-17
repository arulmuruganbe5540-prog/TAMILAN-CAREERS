-- TAMILAN CAREERS: secure Admin job-posting review queue
-- Run once in Supabase SQL Editor as project owner.
-- This queue stores drafts and review decisions only. It DOES NOT publish to public.jobs.
begin;

do $$
begin
  if to_regprocedure('public.is_super_admin()') is null then
    raise exception 'Required function public.is_super_admin() is missing; no changes applied.';
  end if;
end $$;

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

comment on table public.admin_job_post_reviews is
  'Admin-only job post draft/review queue. Approved rows are not public jobs until a separately verified publishing workflow inserts into public.jobs.';

commit;
