-- TAMILAN CAREERS: company profile drafts and employer draft permissions
-- Safe to rerun. This stores unverified profile details as private drafts only.
begin;

create table if not exists public.company_profile_drafts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  profile jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint company_profile_drafts_profile_object check (jsonb_typeof(profile) = 'object')
);

alter table public.company_profile_drafts enable row level security;
revoke all on public.company_profile_drafts from anon, authenticated;
grant select, insert, update, delete on public.company_profile_drafts to authenticated;

drop policy if exists "TC users manage own company profile draft" on public.company_profile_drafts;
create policy "TC users manage own company profile draft"
on public.company_profile_drafts for all to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create or replace function public.tc_company_profile_drafts_touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists tc_company_profile_drafts_updated_at on public.company_profile_drafts;
create trigger tc_company_profile_drafts_updated_at
before update on public.company_profile_drafts
for each row execute function public.tc_company_profile_drafts_touch_updated_at();

-- Only active Owner / HR Manager / Recruiter members may keep private job drafts.
alter table public.job_posting_drafts enable row level security;
grant select, insert, update, delete on public.job_posting_drafts to authenticated;

drop policy if exists "TC job drafts select own active member" on public.job_posting_drafts;
create policy "TC job drafts select own authorized member"
on public.job_posting_drafts for select to authenticated
using (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.company_members cm
    where cm.company_id = job_posting_drafts.company_id
      and cm.user_id = (select auth.uid())
      and cm.member_status = 'active'
      and cm.member_role in ('owner','hr_manager','recruiter')
  )
);

drop policy if exists "TC job drafts insert own active member" on public.job_posting_drafts;
create policy "TC job drafts insert own authorized member"
on public.job_posting_drafts for insert to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.company_members cm
    where cm.company_id = job_posting_drafts.company_id
      and cm.user_id = (select auth.uid())
      and cm.member_status = 'active'
      and cm.member_role in ('owner','hr_manager','recruiter')
  )
);

drop policy if exists "TC job drafts update own active member" on public.job_posting_drafts;
create policy "TC job drafts update own authorized member"
on public.job_posting_drafts for update to authenticated
using (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.company_members cm
    where cm.company_id = job_posting_drafts.company_id
      and cm.user_id = (select auth.uid())
      and cm.member_status = 'active'
      and cm.member_role in ('owner','hr_manager','recruiter')
  )
)
with check (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.company_members cm
    where cm.company_id = job_posting_drafts.company_id
      and cm.user_id = (select auth.uid())
      and cm.member_status = 'active'
      and cm.member_role in ('owner','hr_manager','recruiter')
  )
);

drop policy if exists "TC job drafts delete own active member" on public.job_posting_drafts;
create policy "TC job drafts delete own authorized member"
on public.job_posting_drafts for delete to authenticated
using (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.company_members cm
    where cm.company_id = job_posting_drafts.company_id
      and cm.user_id = (select auth.uid())
      and cm.member_status = 'active'
      and cm.member_role in ('owner','hr_manager','recruiter')
  )
);

comment on table public.company_profile_drafts is
  'Private unverified company profile drafts owned by the authenticated user; not a verified company record.';
comment on table public.job_posting_drafts is
  'Private job-posting drafts; only active owner, HR manager and recruiter members may manage their own drafts. Not published jobs.';

commit;
