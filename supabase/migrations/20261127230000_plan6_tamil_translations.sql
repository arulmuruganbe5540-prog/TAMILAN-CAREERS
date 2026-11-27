-- Plan 6: Tamil Nadu regional-language content storage.
-- Additive only: preserves all original English/source job records.
create table if not exists public.government_job_translations (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.government_jobs(id) on delete cascade,
  language_code text not null default 'ta' check (language_code = 'ta'),
  translated_content jsonb not null default '{}'::jsonb,
  source_snapshot jsonb not null default '{}'::jsonb,
  translation_status text not null default 'draft'
    check (translation_status in ('draft','pending_review','approved','rejected')),
  translation_method text not null default 'admin',
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (job_id, language_code)
);

create table if not exists public.private_job_translations (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.private_jobs(id) on delete cascade,
  language_code text not null default 'ta' check (language_code = 'ta'),
  translated_content jsonb not null default '{}'::jsonb,
  source_snapshot jsonb not null default '{}'::jsonb,
  translation_status text not null default 'draft'
    check (translation_status in ('draft','pending_review','approved','rejected')),
  translation_method text not null default 'admin',
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (job_id, language_code)
);

create index if not exists government_job_translations_status_idx
  on public.government_job_translations (translation_status);
create index if not exists private_job_translations_status_idx
  on public.private_job_translations (translation_status);

alter table public.government_job_translations enable row level security;
alter table public.private_job_translations enable row level security;

revoke all privileges on table public.government_job_translations from public, anon, authenticated, service_role;
revoke all privileges on table public.private_job_translations from public, anon, authenticated, service_role;
grant select on public.government_job_translations to anon, authenticated;
grant select, insert, update, delete on public.government_job_translations to authenticated;
grant select on public.private_job_translations to anon, authenticated;
grant select, insert, update, delete on public.private_job_translations to authenticated;

drop policy if exists government_job_translations_public_approved_read on public.government_job_translations;
create policy government_job_translations_public_approved_read
  on public.government_job_translations for select to anon, authenticated
  using (translation_status = 'approved');

drop policy if exists government_job_translations_super_admin_all on public.government_job_translations;
create policy government_job_translations_super_admin_all
  on public.government_job_translations for all to authenticated
  using ((select private.is_super_admin()))
  with check ((select private.is_super_admin()));

drop policy if exists private_job_translations_public_approved_read on public.private_job_translations;
create policy private_job_translations_public_approved_read
  on public.private_job_translations for select to anon, authenticated
  using (translation_status = 'approved');

drop policy if exists private_job_translations_super_admin_all on public.private_job_translations;
create policy private_job_translations_super_admin_all
  on public.private_job_translations for all to authenticated
  using ((select private.is_super_admin()))
  with check ((select private.is_super_admin()));

comment on table public.government_job_translations is
  'Tamil Nadu government job Tamil translations. Original source content remains in government_jobs.';
comment on table public.private_job_translations is
  'Tamil Nadu private job Tamil translations. Original source content remains in private_jobs.';
