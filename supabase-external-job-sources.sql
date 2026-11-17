-- TAMILAN CAREERS: international government + official company career source registry
-- Run once in Supabase SQL Editor. Discovery records are private and NEVER auto-published.
begin;
do $$ begin
 if to_regprocedure('public.is_super_admin()') is null then
  raise exception 'Required public.is_super_admin() function is missing.';
 end if;
end $$;
create table if not exists public.external_job_sources (
 id text primary key,
 source_name text not null,
 source_type text not null check (source_type in ('india_government','foreign_government','india_company','foreign_company')),
 country text not null,
 region text,
 base_url text not null,
 monitor_mode text not null default 'public_page' check (monitor_mode in ('public_page','rss','api','manual')),
 enabled boolean not null default true,
 last_checked_at timestamptz,
 last_status text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table if not exists public.external_job_candidates (
 id uuid primary key default gen_random_uuid(),
 source_id text not null references public.external_job_sources(id),
 title text not null,
 official_url text not null unique,
 country text not null,
 region text,
 source_type text not null,
 discovery_context text,
 verification jsonb not null default '{}'::jsonb,
 status text not null default 'pending' check(status in ('pending','verified','rejected','published','expired')),
 rejection_reason text,
 discovered_at timestamptz not null default now(),
 reviewed_at timestamptz,
 reviewed_by uuid references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists external_job_candidates_status_idx on public.external_job_candidates(status,discovered_at desc);
create index if not exists external_job_candidates_country_idx on public.external_job_candidates(country,source_type);
alter table public.external_job_sources enable row level security;
alter table public.external_job_candidates enable row level security;
drop policy if exists external_sources_admin_all on public.external_job_sources;
create policy external_sources_admin_all on public.external_job_sources for all to authenticated using(public.is_super_admin()) with check(public.is_super_admin());
drop policy if exists external_candidates_admin_all on public.external_job_candidates;
create policy external_candidates_admin_all on public.external_job_candidates for all to authenticated using(public.is_super_admin()) with check(public.is_super_admin());
grant select,insert,update,delete on public.external_job_sources,public.external_job_candidates to authenticated;
insert into public.external_job_sources(id,source_name,source_type,country,region,base_url,monitor_mode) values
('india-ncs','National Career Service','india_government','India',null,'https://www.ncs.gov.in/','manual'),
('india-upsc','Union Public Service Commission','india_government','India',null,'https://upsc.gov.in/','public_page'),
('india-ssc','Staff Selection Commission','india_government','India',null,'https://ssc.gov.in/','public_page'),
('india-rrb','Railway Recruitment Boards','india_government','India',null,'https://indianrailways.gov.in/','public_page'),
('india-employment-news','Employment News','india_government','India',null,'https://employmentnews.gov.in/','public_page'),
('india-tnpsc','Tamil Nadu Public Service Commission','india_government','India','Tamil Nadu','https://www.tnpsc.gov.in/','public_page'),
('india-kerala-psc','Kerala Public Service Commission','india_government','India','Kerala','https://www.keralapsc.gov.in/','public_page'),
('india-kpsc','Karnataka Public Service Commission','india_government','India','Karnataka','https://kpsc.kar.nic.in/','public_page'),
('india-mpsc','Maharashtra Public Service Commission','india_government','India','Maharashtra','https://mpsc.gov.in/','public_page'),
('india-upsc-ora','UPSC Online Recruitment Applications','india_government','India',null,'https://upsconline.nic.in/','public_page'),
('usajobs','USAJOBS - US Federal Government','foreign_government','United States',null,'https://www.usajobs.gov/','manual'),
('uk-civil-service','UK Civil Service Jobs','foreign_government','United Kingdom',null,'https://www.civilservicejobs.service.gov.uk/','manual'),
('canada-jobs','Government of Canada Jobs','foreign_government','Canada',null,'https://www.canada.ca/en/services/jobs/opportunities/government.html','manual'),
('australia-aps','Australian Public Service Jobs','foreign_government','Australia',null,'https://www.apsjobs.gov.au/','manual'),
('singapore-careers','Careers@Gov Singapore','foreign_government','Singapore',null,'https://www.careers.gov.sg/','manual'),
('tcs-careers','Tata Consultancy Services Careers','india_company','India',null,'https://www.tcs.com/careers','manual'),
('infosys-careers','Infosys Careers','india_company','India',null,'https://www.infosys.com/careers/','manual'),
('wipro-careers','Wipro Careers','india_company','India',null,'https://careers.wipro.com/','manual'),
('hcl-careers','HCLTech Careers','india_company','India',null,'https://www.hcltech.com/careers','manual'),
('reliance-careers','Reliance Industries Careers','india_company','India',null,'https://careers.ril.com/','manual'),
('tata-motors-careers','Tata Motors Careers','india_company','India',null,'https://www.tatamotors.com/careers/','manual'),
('hdfc-careers','HDFC Bank Careers','india_company','India',null,'https://www.hdfcbank.com/personal/about-us/careers','manual'),
('icici-careers','ICICI Bank Careers','india_company','India',null,'https://www.icicicareers.com/','manual'),
('amazon-jobs','Amazon Jobs','foreign_company','United States',null,'https://www.amazon.jobs/','manual'),
('google-careers','Google Careers','foreign_company','United States',null,'https://www.google.com/about/careers/applications/','manual'),
('microsoft-careers','Microsoft Careers','foreign_company','United States',null,'https://careers.microsoft.com/','manual'),
('apple-jobs','Apple Jobs','foreign_company','United States',null,'https://jobs.apple.com/','manual'),
('unilever-careers','Unilever Careers','foreign_company','United Kingdom',null,'https://careers.unilever.com/','manual'),
('siemens-careers','Siemens Careers','foreign_company','Germany',null,'https://jobs.siemens.com/','manual'),
('samsung-careers','Samsung Careers','foreign_company','South Korea',null,'https://www.samsungcareers.com/','manual')
on conflict(id) do update set source_name=excluded.source_name,source_type=excluded.source_type,country=excluded.country,region=excluded.region,base_url=excluded.base_url,updated_at=now();
commit;
