-- TAMILAN CAREERS: consolidated Government Jobs archive + Admin workflow installation
-- Run this single script in Supabase SQL Editor.
-- Creates the official-source registry, private review queue, published feed,
-- Admin publish/reject RPCs, and the additional archive/result source URLs.
-- Safe to re-run. It does not insert any guessed historical notices or auto-publish data.
-- Requires private.is_super_admin() to exist.

begin;

-- ===== supabase-government-notices-setup.sql =====
-- TAMILAN CAREERS: Government notice database foundation
-- Creates isolated government-notice tables. Does not alter jobs, users, applications, or existing roles.
-- Requires the existing private.is_super_admin() function.
-- Public visitors can read active published notices and enabled source names only.
-- Review records and source administration are restricted to super admins.

begin;

do $$
begin
  if to_regprocedure('private.is_super_admin()') is null then
    raise exception 'Required function private.is_super_admin() is missing; no setup was applied.';
  end if;
end $$;

create table if not exists public.government_notice_sources (
  id text primary key,
  authority text not null,
  scope text not null check (scope in ('central','state')),
  state text,
  base_url text not null,
  enabled boolean not null default true,
  last_checked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.government_notice_reviews (
  id uuid primary key default gen_random_uuid(),
  source_id text not null references public.government_notice_sources(id),
  title text not null,
  official_url text not null unique,
  category text not null check (category in ('recruitment','result','admit_card','answer_key','exam_update','other')),
  notice_reference text,
  notice_date date,
  application_start date,
  application_end date,
  vacancies integer check (vacancies is null or vacancies >= 0),
  eligibility_summary text,
  details jsonb not null default '{}'::jsonb,
  verification jsonb not null default '{}'::jsonb,
  status text not null default 'pending' check (status in ('pending','verified','rejected','published')),
  verification_method text,
  verified_at timestamptz,
  verified_by uuid references auth.users(id),
  rejection_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.government_notices (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null unique references public.government_notice_reviews(id),
  title text not null,
  category text not null check (category in ('recruitment','result','admit_card','answer_key','exam_update','other')),
  official_url text not null unique,
  notice_reference text,
  notice_date date,
  application_start date,
  application_end date,
  vacancies integer check (vacancies is null or vacancies >= 0),
  eligibility_summary text,
  details jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  published_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists government_notice_reviews_status_created_idx
  on public.government_notice_reviews(status, created_at desc);
create index if not exists government_notice_reviews_source_idx
  on public.government_notice_reviews(source_id, created_at desc);
create index if not exists government_notices_category_published_idx
  on public.government_notices(category, published_at desc);
create index if not exists government_notices_application_end_idx
  on public.government_notices(application_end);

alter table public.government_notice_sources enable row level security;
alter table public.government_notice_reviews enable row level security;
alter table public.government_notices enable row level security;

drop policy if exists government_sources_public_read_enabled on public.government_notice_sources;
create policy government_sources_public_read_enabled
  on public.government_notice_sources for select to anon, authenticated
  using (enabled = true);

drop policy if exists government_sources_super_admin_all on public.government_notice_sources;
create policy government_sources_super_admin_all
  on public.government_notice_sources for all to authenticated
  using (private.is_super_admin())
  with check (private.is_super_admin());

drop policy if exists government_reviews_super_admin_all on public.government_notice_reviews;
create policy government_reviews_super_admin_all
  on public.government_notice_reviews for all to authenticated
  using (private.is_super_admin())
  with check (private.is_super_admin());

drop policy if exists government_notices_public_read_active on public.government_notices;
create policy government_notices_public_read_active
  on public.government_notices for select to anon, authenticated
  using (is_active = true);

drop policy if exists government_notices_super_admin_all on public.government_notices;
create policy government_notices_super_admin_all
  on public.government_notices for all to authenticated
  using (private.is_super_admin())
  with check (private.is_super_admin());

grant select on public.government_notice_sources to anon, authenticated;
grant insert, update, delete on public.government_notice_sources to authenticated;
grant select, insert, update, delete on public.government_notice_reviews to authenticated;
grant select on public.government_notices to anon, authenticated;
grant insert, update, delete on public.government_notices to authenticated;

insert into public.government_notice_sources (id, authority, scope, state, base_url, enabled)
values
('upsc','Union Public Service Commission','central',NULL,'https://upsc.gov.in/',true),
('upsc-ora','UPSC Online Recruitment Applications','central',NULL,'https://upsconline.nic.in/',true),
('ssc','Staff Selection Commission','central',NULL,'https://ssc.gov.in/',true),
('rrb','Railway Recruitment Boards','central',NULL,'https://www.rrbapply.gov.in/',true),
('indian-railways','Indian Railways','central',NULL,'https://indianrailways.gov.in/',true),
('nta','National Testing Agency','central',NULL,'https://nta.ac.in/',true),
('ibps','Institute of Banking Personnel Selection','central',NULL,'https://www.ibps.in/',true),
('sbi-careers','State Bank of India Careers','central',NULL,'https://sbi.co.in/web/careers',true),
('rbi','Reserve Bank of India Opportunities','central',NULL,'https://opportunities.rbi.org.in/',true),
('nabard','NABARD Careers','central',NULL,'https://www.nabard.org/careers-notices1.aspx',true),
('sebi','SEBI Careers','central',NULL,'https://www.sebi.gov.in/sebiweb/about/AboutAction.do?doVacancies=yes',true),
('join-indian-army','Join Indian Army','central',NULL,'https://joinindianarmy.nic.in/',true),
('join-indian-navy','Join Indian Navy','central',NULL,'https://www.joinindiannavy.gov.in/',true),
('agniveervayu','Indian Air Force Agniveervayu','central',NULL,'https://agnipathvayu.cdac.in/',true),
('ncs','National Career Service','central',NULL,'https://www.ncs.gov.in/',true),
('apprenticeship','Apprenticeship India','central',NULL,'https://www.apprenticeshipindia.gov.in/',true),
('employment-news','Employment News','central',NULL,'https://employmentnews.gov.in/',true),
('tnpsc','Tamil Nadu Public Service Commission','state','Tamil Nadu','https://www.tnpsc.gov.in/',true),
('tnusrb','Tamil Nadu Uniformed Services Recruitment Board','state','Tamil Nadu','https://www.tnusrb.tn.gov.in/',true),
('trb-tamilnadu','Teachers Recruitment Board Tamil Nadu','state','Tamil Nadu','https://www.trb.tn.gov.in/',true),
('mrb-tamilnadu','Medical Services Recruitment Board Tamil Nadu','state','Tamil Nadu','https://www.mrb.tn.gov.in/',true),
('appsc','Andhra Pradesh Public Service Commission','state','Andhra Pradesh','https://psc.ap.gov.in/',true),
('appsc-arunachal','Arunachal Pradesh Public Service Commission','state','Arunachal Pradesh','https://appsc.gov.in/',true),
('apsc-assam','Assam Public Service Commission','state','Assam','https://apsc.nic.in/',true),
('bpsc','Bihar Public Service Commission','state','Bihar','https://bpsc.bihar.gov.in/',true),
('psc-cg','Chhattisgarh Public Service Commission','state','Chhattisgarh','https://psc.cg.gov.in/',true),
('gpsc-goa','Goa Public Service Commission','state','Goa','https://gpsc.goa.gov.in/',true),
('gpsc-gujarat','Gujarat Public Service Commission','state','Gujarat','https://gpsc.gujarat.gov.in/',true),
('hpsc','Haryana Public Service Commission','state','Haryana','https://hpsc.gov.in/',true),
('hppsc','Himachal Pradesh Public Service Commission','state','Himachal Pradesh','https://hppsc.hp.gov.in/',true),
('jpsc','Jharkhand Public Service Commission','state','Jharkhand','https://www.jpsc.gov.in/',true),
('kpsc','Karnataka Public Service Commission','state','Karnataka','https://kpsc.kar.nic.in/',true),
('kerala-psc','Kerala Public Service Commission','state','Kerala','https://www.keralapsc.gov.in/',true),
('mppsc','Madhya Pradesh Public Service Commission','state','Madhya Pradesh','https://mppsc.mp.gov.in/',true),
('mpsc-maharashtra','Maharashtra Public Service Commission','state','Maharashtra','https://mpsc.gov.in/',true),
('mpsc-manipur','Manipur Public Service Commission','state','Manipur','https://mpscmanipur.gov.in/',true),
('mpsc-meghalaya','Meghalaya Public Service Commission','state','Meghalaya','https://mpsc.meghalaya.gov.in/',true),
('mpsc-mizoram','Mizoram Public Service Commission','state','Mizoram','https://mpsc.mizoram.gov.in/',true),
('npsc','Nagaland Public Service Commission','state','Nagaland','https://npsc.nagaland.gov.in/',true),
('opsc','Odisha Public Service Commission','state','Odisha','https://www.opsc.gov.in/',true),
('ppsc','Punjab Public Service Commission','state','Punjab','https://www.ppsc.gov.in/',true),
('rpsc','Rajasthan Public Service Commission','state','Rajasthan','https://rpsc.rajasthan.gov.in/',true),
('spsc','Sikkim Public Service Commission','state','Sikkim','https://spsc.sikkim.gov.in/',true),
('tgpsc','Telangana Public Service Commission','state','Telangana','https://www.tgpsc.gov.in/',true),
('tpsc','Tripura Public Service Commission','state','Tripura','https://tpsc.tripura.gov.in/',true),
('uppsc','Uttar Pradesh Public Service Commission','state','Uttar Pradesh','https://uppsc.up.nic.in/',true),
('psc-uk','Uttarakhand Public Service Commission','state','Uttarakhand','https://psc.uk.gov.in/',true),
('psc-wb','West Bengal Public Service Commission','state','West Bengal','https://psc.wb.gov.in/',true),
('upsc-exam-notification-archive','UPSC Examination Notification Archives','central',NULL,'https://www.upsc.gov.in/exams-related-info/exam-notification/archives',true),
('upsc-recruitment-advertisements','UPSC Recruitment Advertisements Archive','central',NULL,'https://www.upsc.gov.in/recruitment/recruitment-advertisement',true),
('upsc-recruitment-results','UPSC Recruitment Test Results','central',NULL,'https://cms.upsc.gov.in/recruitment-tests/results/',true),
('ssc-notice-archives','Staff Selection Commission Notice Archives','central',NULL,'https://ssc.gov.in/home/archives',true),
('tnpsc-exam-dashboard','TNPSC Exam Dashboard and Results','state','Tamil Nadu','https://tnpsc.gov.in/English/Examdashboard.aspx/English/DResultView.aspx',true),
('mrb-results','Tamil Nadu Medical Services Recruitment Board Results','state','Tamil Nadu','https://www.mrb.tn.gov.in/content.php?dept_id=ODAw&lang=MQ%3D%3D&menu_id=MjI0',true)
on conflict (id) do update set
  authority = excluded.authority,
  scope = excluded.scope,
  state = excluded.state,
  base_url = excluded.base_url,
  updated_at = now();

-- IMPORTANT:
-- This migration creates secure storage and visibility boundaries only.
-- It deliberately does NOT auto-publish discovered links.
-- Auto-publication must be implemented in a trusted server-side verifier after
-- fetching the actual official notice/PDF and validating facts, dates, duplicates,
-- source identity and application links. Uncertain items must remain unpublished.


-- ===== supabase-government-official-source-expansion.sql =====
-- TAMILAN CAREERS: add direct recruitment pages for better official-source coverage.
-- Safe to run more than once. This only adds source URLs; it does not publish jobs.
insert into public.government_notice_sources
  (id, authority, scope, state, base_url, enabled)
values
  ('ibps-other-recruitment','IBPS Other Ongoing Recruitments','central',null,'https://www.ibps.in/index.php/recruitment/',true),
  ('upsc-recruitment-advertisements','UPSC Recruitment Advertisements','central',null,'https://www.upsc.gov.in/recruitment/recruitment-advertisement',true),
  ('upsc-recruitment-tests','UPSC Recruitment Tests Notices','central',null,'https://cms.upsc.gov.in/recruitment-tests/notice/',true),
  ('tnpsc-press-releases','TNPSC Official Press Releases','state','Tamil Nadu','https://www.tnpsc.gov.in/English/Press_releases.aspx',true),
  ('tnpsc-groupiv-2026','TNPSC Group IV Notification 11/2026','state','Tamil Nadu','https://www.tnpsc.gov.in/web/examdashboard/index.aspx?notid=7a880763-80dc-4c3a-bbbe-81b6a3a75a87',true),
  ('tnpsc-groupii-2026','TNPSC Group II and IIA Notification 07/2026','state','Tamil Nadu','https://www.tnpsc.gov.in/web/examdashboard/index.aspx?notid=89113de0-6a0e-4d47-a409-c84fb04ef33e',true),
  ('tnpsc-groupi-2026','TNPSC Group I Notification 05/2026','state','Tamil Nadu','https://www.tnpsc.gov.in/web/examdashboard/index.aspx?notid=33aa5415-6205-4ae9-842e-212d62d088f1',true)
on conflict (id) do update set
  authority=excluded.authority,
  scope=excluded.scope,
  state=excluded.state,
  base_url=excluded.base_url,
  updated_at=now();


-- Historical archive and result pages for one-year backfill and ongoing monitoring.
insert into public.government_notice_sources (id, authority, scope, state, base_url, enabled)
values
('upsc-exam-notification-archive','UPSC Examination Notification Archives','central',NULL,'https://www.upsc.gov.in/exams-related-info/exam-notification/archives',true),
('upsc-recruitment-advertisements','UPSC Recruitment Advertisements Archive','central',NULL,'https://www.upsc.gov.in/recruitment/recruitment-advertisement',true),
('upsc-recruitment-results','UPSC Recruitment Test Results','central',NULL,'https://cms.upsc.gov.in/recruitment-tests/results/',true),
('ssc-notice-archives','Staff Selection Commission Notice Archives','central',NULL,'https://ssc.gov.in/home/archives',true),
('tnpsc-exam-dashboard','TNPSC Exam Dashboard and Results','state','Tamil Nadu','https://tnpsc.gov.in/English/Examdashboard.aspx/English/DResultView.aspx',true),
('mrb-results','Tamil Nadu Medical Services Recruitment Board Results','state','Tamil Nadu','https://www.mrb.tn.gov.in/content.php?dept_id=ODAw&lang=MQ%3D%3D&menu_id=MjI0',true)
on conflict (id) do update set authority=excluded.authority, scope=excluded.scope, state=excluded.state, base_url=excluded.base_url, updated_at=now();


-- ===== supabase-government-notice-admin-actions.sql =====
-- TAMILAN CAREERS: secure Admin publish/reject actions for government notices
-- Run after supabase-government-notices-setup.sql.
-- Publication is explicit and requires category-appropriate verification.

begin;

create or replace function public.tc_admin_publish_government_notice(
  p_review_id uuid,
  p_title text,
  p_official_url text,
  p_notice_reference text,
  p_notice_date date,
  p_application_start date,
  p_application_end date,
  p_vacancies integer,
  p_eligibility_summary text,
  p_details jsonb,
  p_verification jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_review public.government_notice_reviews%rowtype;
  v_source public.government_notice_sources%rowtype;
  v_host text;
  v_source_host text;
  v_required text[];
  v_key text;
begin
  if auth.uid() is null or not private.is_super_admin() then
    raise exception 'Super admin access required';
  end if;

  if p_review_id is null or nullif(btrim(p_title),'') is null or
     nullif(btrim(p_official_url),'') is null or p_notice_date is null then
    raise exception 'Title, official URL and original notice date are required';
  end if;
  if p_application_start is not null and p_application_end is not null
     and p_application_end < p_application_start then
    raise exception 'Application end date cannot be earlier than start date';
  end if;
  if p_vacancies is not null and p_vacancies < 0 then
    raise exception 'Vacancy count cannot be negative';
  end if;
  if jsonb_typeof(coalesce(p_details,'{}'::jsonb)) <> 'object' or
     jsonb_typeof(coalesce(p_verification,'{}'::jsonb)) <> 'object' then
    raise exception 'Details and verification must be JSON objects';
  end if;

  select * into v_review
  from public.government_notice_reviews
  where id = p_review_id
  for update;
  if not found then raise exception 'Review record not found'; end if;
  if v_review.status not in ('pending','verified') then
    raise exception 'Only pending or verified records can be published';
  end if;

  select * into v_source
  from public.government_notice_sources
  where id = v_review.source_id and enabled = true;
  if not found then raise exception 'Registered official source is not enabled'; end if;

  if p_official_url !~* '^https://' then
    raise exception 'Official URL must use HTTPS';
  end if;
  v_host := lower(substring(p_official_url from '^https://([^/:?#]+)'));
  v_source_host := lower(substring(v_source.base_url from '^https://([^/:?#]+)'));
  if v_host is null or v_source_host is null or
     (v_host <> v_source_host and right(v_host, length(v_source_host) + 1) <> ('.' || v_source_host)) then
    raise exception 'Official URL host does not match the registered source';
  end if;

  if v_review.category = 'recruitment' then
    v_required := array['notice_document_opened','dates_verified','vacancies_verified',
                        'eligibility_verified','application_link_verified','duplicate_checked'];
  else
    v_required := array['notice_document_opened','duplicate_checked'];
  end if;
  foreach v_key in array v_required loop
    if coalesce((p_verification ->> v_key)::boolean,false) is not true then
      raise exception 'Required verification is incomplete: %', v_key;
    end if;
  end loop;

  update public.government_notice_reviews
  set title = btrim(p_title),
      official_url = p_official_url,
      notice_reference = nullif(btrim(p_notice_reference),''),
      notice_date = p_notice_date,
      application_start = p_application_start,
      application_end = p_application_end,
      vacancies = p_vacancies,
      eligibility_summary = nullif(btrim(p_eligibility_summary),''),
      details = coalesce(p_details,'{}'::jsonb) || jsonb_build_object(
        'authority', v_source.authority,
        'scope', v_source.scope,
        'state', v_source.state
      ),
      verification = coalesce(p_verification,'{}'::jsonb),
      status = 'published',
      verification_method = 'admin_official_document_review',
      verified_at = now(),
      verified_by = auth.uid(),
      updated_at = now()
  where id = p_review_id;

  insert into public.government_notices (
    review_id,title,category,official_url,notice_reference,notice_date,
    application_start,application_end,vacancies,eligibility_summary,details,is_active,published_at,updated_at
  ) values (
    p_review_id,btrim(p_title),v_review.category,p_official_url,
    nullif(btrim(p_notice_reference),''),p_notice_date,
    p_application_start,p_application_end,p_vacancies,
    nullif(btrim(p_eligibility_summary),''),
    coalesce(p_details,'{}'::jsonb) || jsonb_build_object(
      'authority',v_source.authority,'scope',v_source.scope,'state',v_source.state
    ),
    true,now(),now()
  )
  on conflict (review_id) do update set
    title=excluded.title, category=excluded.category, official_url=excluded.official_url,
    notice_reference=excluded.notice_reference, notice_date=excluded.notice_date,
    application_start=excluded.application_start, application_end=excluded.application_end,
    vacancies=excluded.vacancies, eligibility_summary=excluded.eligibility_summary,
    details=excluded.details, is_active=true, updated_at=now();

  return jsonb_build_object('ok',true,'review_id',p_review_id,'status','published');
end;
$$;

create or replace function public.tc_admin_reject_government_notice(
  p_review_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not private.is_super_admin() then
    raise exception 'Super admin access required';
  end if;
  if nullif(btrim(p_reason),'') is null then
    raise exception 'Rejection reason is required';
  end if;
  update public.government_notice_reviews
  set status='rejected', rejection_reason=btrim(p_reason),
      verified_by=auth.uid(), verified_at=now(), updated_at=now()
  where id=p_review_id and status in ('pending','verified');
  if not found then raise exception 'Review record not found or no longer pending'; end if;
  return jsonb_build_object('ok',true,'review_id',p_review_id,'status','rejected');
end;
$$;

revoke all on function public.tc_admin_publish_government_notice(uuid,text,text,text,date,date,date,integer,text,jsonb,jsonb) from public, anon;
revoke all on function public.tc_admin_reject_government_notice(uuid,text) from public, anon;
grant execute on function public.tc_admin_publish_government_notice(uuid,text,text,text,date,date,date,integer,text,jsonb,jsonb) to authenticated;
grant execute on function public.tc_admin_reject_government_notice(uuid,text) to authenticated;
commit;
