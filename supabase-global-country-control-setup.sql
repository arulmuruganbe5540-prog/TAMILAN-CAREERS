-- TAMILAN CAREERS: country-aware platform settings
-- Adds configuration to the existing public.countries table; no existing job records are rewritten.
alter table public.countries
  add column if not exists default_language_code text not null default 'en',
  add column if not exists currency_code text not null default 'USD',
  add column if not exists homepage_sections jsonb not null default '["smart_search","job_categories","local_latest_jobs","employer_cta"]'::jsonb,
  add column if not exists updated_at timestamptz not null default now();

insert into public.countries (country_code,country_name,is_active,default_language_code,currency_code)
values ('IN','India',true,'ta','INR'),('LK','Sri Lanka',true,'ta','LKR'),('AE','United Arab Emirates',true,'en','AED'),('US','United States',true,'en','USD')
on conflict (country_code) do update set country_name=excluded.country_name,is_active=true,
 default_language_code=coalesce(nullif(public.countries.default_language_code,''),excluded.default_language_code),
 currency_code=coalesce(nullif(public.countries.currency_code,''),excluded.currency_code),updated_at=now();

alter table public.countries alter column homepage_sections set default '["smart_search","job_categories","local_latest_jobs","employer_cta"]'::jsonb;
update public.countries set homepage_sections='["smart_search","job_categories","local_latest_jobs","employer_cta"]'::jsonb where homepage_sections is null;

do $$ begin
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='countries' and policyname='Super admins manage countries') then
  create policy "Super admins manage countries" on public.countries for all to authenticated
   using ((select private.is_super_admin())) with check ((select private.is_super_admin()));
 end if;
end $$;
grant select on public.countries to anon,authenticated;
grant insert,update,delete on public.countries to authenticated;
