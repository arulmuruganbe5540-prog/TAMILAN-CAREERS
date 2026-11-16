-- TAMILAN CAREERS: private company job-posting drafts
-- Run this script in the Supabase SQL Editor as the project owner.
-- This creates DRAFT storage only. It does not publish jobs or grant publishing rights.

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
