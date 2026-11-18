-- TAMILAN CAREERS: country-aware job publishing and homepage ordering
-- Additive migration. Existing job records are preserved.
alter table public.jobs add column if not exists government_scope text;

insert into public.countries(country_code,country_name,is_active,default_language_code,currency_code,homepage_sections)
values('SG','Singapore',true,'en','SGD','["smart_search","job_categories","country_government_jobs","country_private_jobs","overseas_jobs","local_latest_jobs","employer_cta"]'::jsonb)
on conflict(country_code) do update set country_name=excluded.country_name,is_active=true,default_language_code=excluded.default_language_code,currency_code=excluded.currency_code,homepage_sections=excluded.homepage_sections,updated_at=now();

update public.countries set homepage_sections='["smart_search","job_categories","country_government_jobs","country_private_jobs","overseas_jobs","local_latest_jobs","employer_cta"]'::jsonb,updated_at=now()
where country_code in ('IN','LK','AE','US','SG');

create or replace function public.tc_admin_publish_job(p_review_id uuid)
returns uuid language plpgsql security definer set search_path = ''
as $function$
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
  v_salary_currency text;
  v_vacancies integer;
  v_deadline timestamptz;
  v_job_kind text;
  v_employer text;
  v_company_required boolean;
  v_exam_year integer;
  v_notification_date date;
  v_government_scope text;
  v_country_name text;
begin
  if not coalesce(private.is_super_admin(),false) then raise exception 'Super Admin permission required'; end if;
  select * into v_review from public.admin_job_post_reviews where id=p_review_id for update;
  if not found then raise exception 'Review item not found'; end if;
  if v_review.status<>'approved' then raise exception 'Only approved job posts can be published'; end if;
  if v_review.published_job_id is not null then return v_review.published_job_id; end if;
  v_payload:=v_review.payload;
  v_title:=nullif(btrim(v_payload->>'title'),'');
  if v_title is null or length(v_title)>180 then raise exception 'Valid job title is required (max 180 characters)'; end if;
  if nullif(btrim(v_payload->>'description'),'') is null or length(v_payload->>'description')>8000 then raise exception 'Job description is required (max 8000 characters)'; end if;
  v_job_kind:=coalesce(nullif(v_payload->>'job_kind',''),'private');
  if v_job_kind not in ('government','private','foreign') then raise exception 'Invalid job category'; end if;
  v_employer:=nullif(btrim(coalesce(v_payload->>'company','')),'');
  v_company_required:=nullif(v_payload->>'source_draft_id','') is not null;
  v_country_name:=nullif(btrim(v_payload->>'country_name'),'');
  if v_country_name is null then raise exception 'Select the country where this job is located'; end if;
  if not exists(select 1 from public.countries c where lower(btrim(c.country_name))=lower(btrim(v_country_name)) and c.is_active=true) then raise exception 'Select an active country from Country Management'; end if;
  v_government_scope:=nullif(btrim(v_payload->>'governmentScope'),'');
  if v_job_kind='government' then
    if v_government_scope is null then raise exception 'Select the government job scope'; end if;
    if v_government_scope not in ('central','tamil-nadu','national') then raise exception 'Invalid government job scope'; end if;
    if v_country_name<>'India' and v_government_scope<>'national' then raise exception 'For non-India government jobs, select National Government'; end if;
    if v_country_name='India' and v_government_scope='national' then raise exception 'For India, select Central Government or Tamil Nadu Government'; end if;
  else v_government_scope:=null;
  end if;

  if nullif(v_payload->>'company_id','') is not null then
    select c.id into v_company_id from public.companies c where c.id=(v_payload->>'company_id')::uuid
      and lower(btrim(c.company_name))=lower(btrim(coalesce(v_payload->>'company',v_review.company_name,''))) and c.verification_status='verified';
    if v_company_id is null then raise exception 'Company must be verified before publishing'; end if;
  elsif v_company_required then
    select c.id into v_company_id from public.companies c where lower(btrim(c.company_name))=lower(btrim(coalesce(v_payload->>'company',v_review.company_name,'')))
      and c.verification_status='verified' order by c.created_at asc limit 1;
    if v_company_id is null then raise exception 'Company-submitted jobs require a verified company'; end if;
  end if;
  if v_company_id is null and v_company_required then raise exception 'Company-submitted jobs require a verified company'; end if;
  select jc.id into v_category_id from public.job_categories jc where jc.is_active=true
    and lower(btrim(jc.category_name))=lower(btrim(coalesce(v_payload->>'category',''))) order by jc.created_at asc limit 1;
  if v_category_id is null then raise exception 'Select an active job category in the Admin form'; end if;
  v_type:=lower(replace(btrim(coalesce(v_payload->>'type','')),' ','_'));
  if v_type not in ('full_time','part_time','contract','temporary','internship','freelance','daily_wage') then raise exception 'Unsupported employment type'; end if;
  v_workplace:=case lower(btrim(coalesce(v_payload->>'workplace',''))) when 'remote' then 'remote' when 'hybrid' then 'hybrid' else 'onsite' end;
  v_experience:=coalesce(v_payload->>'experience','');
  if v_experience ~ '[0-9]+[.]?[0-9]*' then v_experience_min:=substring(v_experience from '[0-9]+[.]?[0-9]*')::numeric; end if;
  v_salary_min:=nullif(v_payload->>'salaryMin','')::numeric;
  v_salary_max:=nullif(v_payload->>'salaryMax','')::numeric;
  v_salary_period:=lower(coalesce(nullif(v_payload->>'salaryPeriod',''),case when v_type='daily_wage' then 'daily' else 'monthly' end));
  if v_salary_period not in ('monthly','daily') then raise exception 'Salary period must be Monthly or Daily'; end if;
  v_salary_currency:=case when v_job_kind='foreign' or v_country_name<>'India' then upper(coalesce(nullif(v_payload->>'salaryCurrency',''),case when v_country_name='United Arab Emirates' then 'AED' when v_country_name='Singapore' then 'SGD' when v_country_name='Sri Lanka' then 'LKR' when v_country_name='United States' then 'USD' else 'USD' end)) else 'INR' end;
  if v_salary_currency not in ('USD','AED','SAR','QAR','OMR','KWD','BHD','SGD','MYR','EUR','GBP','CAD','AUD','INR','LKR') then raise exception 'Unsupported salary currency'; end if;
  if v_salary_min<0 or v_salary_max<0 or (v_salary_min is not null and v_salary_max is not null and v_salary_min>v_salary_max) then raise exception 'Invalid salary range'; end if;
  v_vacancies:=coalesce(nullif(v_payload->>'openings','')::integer,1);
  if v_vacancies<1 then raise exception 'At least one opening is required'; end if;
  if nullif(v_payload->>'deadline','') is not null then
    if (v_payload->>'deadline')::date<(now() at time zone 'Asia/Kolkata')::date then raise exception 'Application deadline cannot be in the past'; end if;
    v_deadline:=((v_payload->>'deadline')::date+time '23:59:59') at time zone 'Asia/Kolkata';
  end if;
  if nullif(v_payload->>'exam_year','') is not null then v_exam_year:=(v_payload->>'exam_year')::integer; if v_exam_year<1950 or v_exam_year>2100 then raise exception 'Invalid exam year'; end if; end if;
  if nullif(v_payload->>'notification_date','') is not null then v_notification_date:=(v_payload->>'notification_date')::date; end if;
  if v_job_kind='government' and nullif(v_payload->>'official_url','') is null then raise exception 'Government job requires an official source website URL'; end if;
  v_slug:=trim(both '-' from regexp_replace(lower(v_title),'[^a-z0-9]+','-','g'));
  if v_slug='' then v_slug:='job'; end if;
  v_slug:=left(v_slug,90)||'-'||lower(substr(replace(gen_random_uuid()::text,'-',''),1,8));
  insert into public.jobs(company_id,category_id,created_by,job_title,job_slug,job_code,description,employment_type,workplace_type,experience_min,salary_min,salary_max,salary_currency,salary_period,vacancies,application_deadline,status,published_at,location,education_level,required_skills,contact_email,job_kind,employer_name,official_website_url,official_notification_url,application_url,recruitment_authority,notification_number,age_limit,application_fee,selection_process,exam_year,notification_date,country_name,government_scope,is_admin_managed)
  values(v_company_id,v_category_id,v_review.created_by,v_title,v_slug,'TC-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)),v_payload->>'description',v_type,v_workplace,v_experience_min,v_salary_min,v_salary_max,v_salary_currency,v_salary_period,v_vacancies,v_deadline,'published',now(),nullif(btrim(v_payload->>'location'),''),nullif(btrim(v_payload->>'education'),''),nullif(btrim(v_payload->>'skills'),''),nullif(btrim(v_payload->>'email'),''),v_job_kind,v_employer,nullif(btrim(v_payload->>'official_url'),''),nullif(btrim(v_payload->>'notification_pdf_url'),''),nullif(btrim(v_payload->>'application_url'),''),nullif(btrim(v_payload->>'authority'),''),nullif(btrim(v_payload->>'notification_number'),''),nullif(btrim(v_payload->>'age_limit'),''),nullif(btrim(v_payload->>'application_fee'),''),nullif(btrim(v_payload->>'selection_process'),''),v_exam_year,v_notification_date,v_country_name,v_government_scope,true)
  returning id into v_job_id;
  update public.admin_job_post_reviews set published_job_id=v_job_id where id=p_review_id;
  return v_job_id;
end;
$function$;

create or replace function public.tc_submit_company_job_draft_for_review(p_draft_id uuid)
returns uuid language plpgsql security definer set search_path = ''
as $function$
declare
  v_company_id uuid;
  v_draft jsonb;
  v_company_name text;
  v_title text;
  v_payload jsonb;
  v_review_id uuid;
  v_country_name text;
begin
  if auth.uid() is null then raise exception 'Login required'; end if;
  select d.company_id,d.draft into v_company_id,v_draft from public.job_posting_drafts d
  where d.id=p_draft_id and d.user_id=auth.uid() for update;
  if not found then raise exception 'Company draft not found or not owned by this account'; end if;
  if not exists(select 1 from public.company_members cm where cm.company_id=v_company_id and cm.user_id=auth.uid()
    and cm.member_status='active' and cm.member_role in ('owner','hr_manager','recruiter')) then raise exception 'Active Owner, HR Manager, or Recruiter permission is required'; end if;
  select c.company_name into v_company_name from public.companies c where c.id=v_company_id and c.verification_status='verified';
  if not found or nullif(btrim(v_company_name),'') is null then raise exception 'Company record or company name not found'; end if;
  if v_draft->>'draft_status'='published' then raise exception 'This job draft has already been published. Edit it to create a new version before submitting again'; end if;
  v_title:=nullif(btrim(v_draft->>'jobTitle'),'');
  if v_title is null then raise exception 'Job title is required'; end if;
  if length(v_title)>180 then raise exception 'Job title is too long'; end if;
  if nullif(btrim(v_draft->>'description'),'') is null then raise exception 'Job description is required'; end if;
  if length(v_draft->>'description')>8000 then raise exception 'Job description is too long'; end if;
  if nullif(btrim(v_draft->>'category'),'') is null or nullif(btrim(v_draft->>'employmentType'),'') is null or nullif(btrim(v_draft->>'location'),'') is null then raise exception 'Category, employment type, and location are required'; end if;
  v_country_name:=nullif(btrim(v_draft->>'countryName'),'');
  if v_country_name is null then raise exception 'Select the country where this job is located'; end if;
  if not exists(select 1 from public.countries c where lower(btrim(c.country_name))=lower(btrim(v_country_name)) and c.is_active=true) then raise exception 'Select an active country from Country Management'; end if;
  if nullif(btrim(v_draft->>'deadline'),'') is not null then
    if (v_draft->>'deadline') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then raise exception 'Application deadline must be a valid date'; end if;
    if (v_draft->>'deadline')::date<(now() at time zone 'Asia/Kolkata')::date then raise exception 'Application deadline cannot be in the past'; end if;
  end if;
  select r.id into v_review_id from public.admin_job_post_reviews r where r.payload->>'source_draft_id'=p_draft_id::text
    and r.status in ('pending_review','approved') and r.published_job_id is null order by r.created_at desc limit 1;
  if v_review_id is not null then raise exception 'This job draft is already under review or approved; wait for the Admin decision'; end if;
  v_payload:=jsonb_build_object('title',v_title,'company',v_company_name,'company_id',v_company_id,'job_kind','private','source_draft_id',p_draft_id,
    'category',v_draft->>'category','type',v_draft->>'employmentType','workplace',v_draft->>'workplaceType','location',v_draft->>'location',
    'country_name',v_country_name,'openings',coalesce(nullif(v_draft->>'openings',''),'1'),'experience',v_draft->>'experience',
    'education',v_draft->>'education','salaryMin',v_draft->>'salaryMin','salaryMax',v_draft->>'salaryMax',
    'salaryPeriod',coalesce(nullif(v_draft->>'salaryPeriod',''),case when v_draft->>'employmentType'='Daily Wage' then 'daily' else 'monthly' end),
    'skills',v_draft->>'skills','description',v_draft->>'description','deadline',v_draft->>'deadline','email',v_draft->>'contactEmail');
  insert into public.admin_job_post_reviews(created_by,title,company_name,status,payload)
  values(auth.uid(),v_title,v_company_name,'pending_review',v_payload) returning id into v_review_id;
  update public.job_posting_drafts set draft=draft||jsonb_build_object('draft_status','pending_review','submitted_review_id',v_review_id,'submitted_at',now()),updated_at=now()
  where id=p_draft_id;
  return v_review_id;
end;
$function$;
