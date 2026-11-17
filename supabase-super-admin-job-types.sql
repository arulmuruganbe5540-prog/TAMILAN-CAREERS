-- TAMILAN CAREERS: unified Super Admin managed jobs
-- Applied to production via Supabase migration.
begin;
alter table public.jobs
  add column if not exists job_kind text not null default 'private',
  add column if not exists employer_name text,
  add column if not exists official_website_url text,
  add column if not exists official_notification_url text,
  add column if not exists application_url text,
  add column if not exists recruitment_authority text,
  add column if not exists notification_number text,
  add column if not exists age_limit text,
  add column if not exists application_fee text,
  add column if not exists selection_process text,
  add column if not exists exam_year integer,
  add column if not exists notification_date date,
  add column if not exists country_name text,
  add column if not exists is_admin_managed boolean not null default false;
do $guard$ begin
 if not exists(select 1 from pg_constraint where conrelid='public.jobs'::regclass and conname='jobs_job_kind_check') then
  alter table public.jobs add constraint jobs_job_kind_check check(job_kind in ('government','private','foreign'));
 end if;
end; $guard$;
create index if not exists jobs_job_kind_status_idx on public.jobs(job_kind,status,published_at desc);
CREATE OR REPLACE FUNCTION public.tc_admin_publish_job(p_review_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_review public.admin_job_post_reviews%rowtype;
  v_payload jsonb;
  v_company_id uuid;
  v_category_id uuid;
  v_job_id uuid;
  v_title text;
  v_slug text;
  v_type text;
  v_workplace text;
  v_experience text;
  v_experience_min numeric;
  v_salary_min numeric;
  v_salary_max numeric;
  v_salary_period text;
  v_vacancies integer;
  v_deadline timestamptz;
  v_job_kind text;
  v_employer text;
  v_company_required boolean;
  v_exam_year integer;
  v_notification_date date;
begin
  if not coalesce(private.is_super_admin(), false) then
    raise exception 'Super Admin permission required';
  end if;

  select * into v_review from public.admin_job_post_reviews
  where id = p_review_id for update;
  if not found then raise exception 'Review item not found'; end if;
  if v_review.status <> 'approved' then raise exception 'Only approved job posts can be published'; end if;
  if v_review.published_job_id is not null then return v_review.published_job_id; end if;

  v_payload := v_review.payload;
  v_title := nullif(btrim(v_payload->>'title'), '');
  if v_title is null or length(v_title)>180 then raise exception 'Valid job title is required (max 180 characters)'; end if;
  if nullif(btrim(v_payload->>'description'), '') is null or length(v_payload->>'description')>8000 then
    raise exception 'Job description is required (max 8000 characters)';
  end if;

  v_job_kind := coalesce(nullif(v_payload->>'job_kind',''),'private');
  if v_job_kind not in ('government','private','foreign') then raise exception 'Invalid job category'; end if;
  v_employer := nullif(btrim(coalesce(v_payload->>'company','')), '');
  v_company_required := nullif(v_payload->>'source_draft_id','') is not null;

  if nullif(v_payload->>'company_id','') is not null then
    select c.id into v_company_id from public.companies c
    where c.id=(v_payload->>'company_id')::uuid
      and lower(btrim(c.company_name))=lower(btrim(coalesce(v_payload->>'company',v_review.company_name,'')))
      and c.verification_status='verified';
    if v_company_id is null then raise exception 'Company must be verified before publishing'; end if;
  elsif v_company_required then
    select c.id into v_company_id from public.companies c
    where lower(btrim(c.company_name))=lower(btrim(coalesce(v_payload->>'company',v_review.company_name,'')))
      and c.verification_status='verified'
    order by c.created_at asc limit 1;
    if v_company_id is null then raise exception 'Company-submitted jobs require a verified company'; end if;
  end if;

  if v_company_id is null and v_company_required then
    raise exception 'Company-submitted jobs require a verified company';
  end if;

  select jc.id into v_category_id from public.job_categories jc
  where jc.is_active=true and lower(btrim(jc.category_name))=lower(btrim(coalesce(v_payload->>'category','')))
  order by jc.created_at asc limit 1;
  if v_category_id is null then raise exception 'Select an active job category in the Admin form'; end if;

  v_type := lower(replace(btrim(coalesce(v_payload->>'type','')), ' ', '_'));
  if v_type not in ('full_time','part_time','contract','temporary','internship','freelance','daily_wage') then
    raise exception 'Unsupported employment type';
  end if;
  v_workplace := case lower(btrim(coalesce(v_payload->>'workplace','')))
    when 'remote' then 'remote' when 'hybrid' then 'hybrid' else 'onsite' end;
  v_experience := coalesce(v_payload->>'experience','');
  if v_experience ~ '[0-9]+[.]?[0-9]*' then v_experience_min := substring(v_experience from '[0-9]+[.]?[0-9]*')::numeric; end if;
  v_salary_min := nullif(v_payload->>'salaryMin','')::numeric;
  v_salary_max := nullif(v_payload->>'salaryMax','')::numeric;
  v_salary_period := lower(coalesce(nullif(v_payload->>'salaryPeriod',''),case when v_type='daily_wage' then 'daily' else 'monthly' end));
  if v_salary_period not in ('monthly','daily') then raise exception 'Salary period must be Monthly or Daily'; end if;
  if v_salary_min<0 or v_salary_max<0 or (v_salary_min is not null and v_salary_max is not null and v_salary_min>v_salary_max) then
    raise exception 'Invalid salary range';
  end if;
  v_vacancies := coalesce(nullif(v_payload->>'openings','')::integer,1);
  if v_vacancies<1 then raise exception 'At least one opening is required'; end if;
  if nullif(v_payload->>'deadline','') is not null then
    if (v_payload->>'deadline')::date < (now() at time zone 'Asia/Kolkata')::date then raise exception 'Application deadline cannot be in the past'; end if;
    v_deadline := ((v_payload->>'deadline')::date + time '23:59:59') at time zone 'Asia/Kolkata';
  end if;
  if nullif(v_payload->>'exam_year','') is not null then
    v_exam_year := (v_payload->>'exam_year')::integer;
    if v_exam_year<1950 or v_exam_year>2100 then raise exception 'Invalid exam year'; end if;
  end if;
  if nullif(v_payload->>'notification_date','') is not null then v_notification_date := (v_payload->>'notification_date')::date; end if;

  if v_job_kind='government' and nullif(v_payload->>'official_url','') is null then
    raise exception 'Government job requires an official source website URL';
  end if;
  if v_job_kind='foreign' and nullif(v_payload->>'country_name','') is null then
    raise exception 'Foreign job requires a country';
  end if;

  v_slug := trim(both '-' from regexp_replace(lower(v_title),'[^a-z0-9]+','-','g'));
  if v_slug='' then v_slug:='job'; end if;
  v_slug := left(v_slug,90)||'-'||lower(substr(replace(gen_random_uuid()::text,'-',''),1,8));

  insert into public.jobs (
    company_id,category_id,created_by,job_title,job_slug,job_code,description,
    employment_type,workplace_type,experience_min,salary_min,salary_max,salary_currency,
    salary_period,vacancies,application_deadline,status,published_at,location,
    education_level,required_skills,contact_email,job_kind,employer_name,
    official_website_url,official_notification_url,application_url,recruitment_authority,
    notification_number,age_limit,application_fee,selection_process,exam_year,
    notification_date,country_name,is_admin_managed
  ) values (
    v_company_id,v_category_id,v_review.created_by,v_title,v_slug,
    'TC-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)),
    v_payload->>'description',v_type,v_workplace,v_experience_min,v_salary_min,v_salary_max,
    case when v_job_kind='foreign' then 'USD' else 'INR' end,v_salary_period,v_vacancies,
    v_deadline,'published',now(),nullif(btrim(v_payload->>'location'),''),
    nullif(btrim(v_payload->>'education'),''),nullif(btrim(v_payload->>'skills'),''),
    nullif(btrim(v_payload->>'email'),''),v_job_kind,v_employer,
    nullif(btrim(v_payload->>'official_url'),''),nullif(btrim(v_payload->>'notification_pdf_url'),''),
    nullif(btrim(v_payload->>'application_url'),''),nullif(btrim(v_payload->>'authority'),''),
    nullif(btrim(v_payload->>'notification_number'),''),nullif(btrim(v_payload->>'age_limit'),''),
    nullif(btrim(v_payload->>'application_fee'),''),nullif(btrim(v_payload->>'selection_process'),''),
    v_exam_year,v_notification_date,nullif(btrim(v_payload->>'country_name'),''),true
  ) returning id into v_job_id;

  update public.admin_job_post_reviews set published_job_id=v_job_id where id=p_review_id;
  return v_job_id;
end;
$function$

revoke all on function public.tc_admin_publish_job(uuid) from public,anon;
grant execute on function public.tc_admin_publish_job(uuid) to authenticated;
drop policy if exists jobs_read_published on public.jobs;
create policy jobs_read_published on public.jobs for select to anon,authenticated
using(status='published' and (is_admin_managed=true or (company_id is not null and exists(select 1 from public.companies c where c.id=jobs.company_id and c.verification_status='verified'))));
commit;
