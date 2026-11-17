-- Job-specific exam preparation resources, AI mock papers, and candidate attempts.
create table if not exists public.job_exam_resources (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  resource_type text not null check (resource_type in ('syllabus','previous_paper','official_notice','exam_schedule','hall_ticket','answer_key','result','cutoff','admit_card','mock_test','other')),
  title text not null, description text, resource_url text, resource_year integer, exam_stage text, source_name text,
  is_official boolean not null default false,
  status text not null default 'draft' check (status in ('draft','published','archived')),
  created_by uuid references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index if not exists job_exam_resources_job_status_idx on public.job_exam_resources(job_id,status,resource_type,resource_year desc);
alter table public.job_exam_resources enable row level security;
drop policy if exists job_exam_resources_public_read on public.job_exam_resources;
create policy job_exam_resources_public_read on public.job_exam_resources for select to anon, authenticated using (status='published');
drop policy if exists job_exam_resources_admin_manage on public.job_exam_resources;
create policy job_exam_resources_admin_manage on public.job_exam_resources for all to authenticated using (private.is_super_admin()) with check (private.is_super_admin());

create table if not exists public.job_exam_question_sets (
  id uuid primary key default gen_random_uuid(), job_id uuid not null references public.jobs(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade, title text not null,
  language text not null default 'ta', difficulty text not null default 'mixed' check (difficulty in ('easy','medium','hard','mixed')),
  question_count integer not null default 15 check (question_count between 5 and 50),
  questions jsonb not null default '[]'::jsonb, generation_model text,
  disclaimer text not null default 'AI உருவாக்கிய பயிற்சி வினாத்தாள் மட்டுமே. அதிகாரப்பூர்வ வினாத்தாள் அல்ல.',
  created_at timestamptz not null default now()
);
create index if not exists job_exam_question_sets_user_job_idx on public.job_exam_question_sets(created_by,job_id,created_at desc);
alter table public.job_exam_question_sets enable row level security;
drop policy if exists job_exam_question_sets_owner_read on public.job_exam_question_sets;
create policy job_exam_question_sets_owner_read on public.job_exam_question_sets for select to authenticated using (created_by=auth.uid() or private.is_super_admin());

create table if not exists public.job_exam_attempts (
  id uuid primary key default gen_random_uuid(), question_set_id uuid not null references public.job_exam_question_sets(id) on delete cascade,
  job_id uuid not null references public.jobs(id) on delete cascade, user_id uuid not null references auth.users(id) on delete cascade,
  answers jsonb not null default '{}'::jsonb, score integer not null default 0, total_questions integer not null default 0,
  completed_at timestamptz not null default now()
);
create index if not exists job_exam_attempts_user_job_idx on public.job_exam_attempts(user_id,job_id,completed_at desc);
alter table public.job_exam_attempts enable row level security;
drop policy if exists job_exam_attempts_owner_read on public.job_exam_attempts;
create policy job_exam_attempts_owner_read on public.job_exam_attempts for select to authenticated using (user_id=auth.uid() or private.is_super_admin());
drop policy if exists job_exam_attempts_owner_insert on public.job_exam_attempts;
create policy job_exam_attempts_owner_insert on public.job_exam_attempts for insert to authenticated with check (user_id=auth.uid());