-- TAMILAN CAREERS: country-aware job publishing and homepage ordering
-- Applied directly to Supabase and verified. Safe additive change: existing jobs are not rewritten.
alter table public.jobs add column if not exists government_scope text;

insert into public.countries(country_code,country_name,is_active,default_language_code,currency_code,homepage_sections)
values('SG','Singapore',true,'en','SGD','["smart_search","job_categories","country_government_jobs","country_private_jobs","overseas_jobs","local_latest_jobs","employer_cta"]'::jsonb)
on conflict(country_code) do update set country_name=excluded.country_name,is_active=true,default_language_code=excluded.default_language_code,currency_code=excluded.currency_code,homepage_sections=excluded.homepage_sections,updated_at=now();

update public.countries set homepage_sections='["smart_search","job_categories","country_government_jobs","country_private_jobs","overseas_jobs","local_latest_jobs","employer_cta"]'::jsonb,updated_at=now()
where country_code in ('IN','LK','AE','US','SG');

-- Government-scope support and active-country validation are enforced by tc_admin_publish_job.
-- Company private-job submission now requires an active country and copies country_name
-- into the Admin Review payload before the Super Admin publishes the job.
-- See the live function definitions in Supabase:
-- public.tc_admin_publish_job(uuid)
-- public.tc_submit_company_job_draft_for_review(uuid)
