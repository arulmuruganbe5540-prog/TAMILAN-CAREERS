
ALTER TABLE public.admin_job_post_reviews
 ADD COLUMN IF NOT EXISTS published_private_job_id uuid REFERENCES public.private_jobs(id) ON DELETE SET NULL;

CREATE OR REPLACE FUNCTION public.tc_admin_publish_private_job(p_review_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE
 v_user uuid:=(SELECT auth.uid());
 v_review public.admin_job_post_reviews%rowtype;
 v_payload jsonb;
 v_company uuid;
 v_company_name text;
 v_category uuid;
 v_title text;
 v_slug text;
 v_type text;
 v_workplace text;
 v_salary_min numeric;
 v_salary_max numeric;
 v_salary_currency text;
 v_salary_period text;
 v_vacancies integer;
 v_deadline timestamptz;
 v_job_id uuid;
 v_employer text;
 v_education text;
 v_skills text;
 v_email text;
 v_application_url text;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION 'Login required'; END IF;
 PERFORM private.require_super_admin_mfa();
 SELECT * INTO v_review FROM public.admin_job_post_reviews WHERE id=p_review_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Private job review item not found'; END IF;
 IF v_review.status<>'approved' THEN RAISE EXCEPTION 'Only approved private job submissions can be published'; END IF;
 IF v_review.published_private_job_id IS NOT NULL THEN RETURN v_review.published_private_job_id; END IF;
 v_payload:=v_review.payload;
 IF coalesce(v_payload->>'job_kind','private')<>'private' THEN RAISE EXCEPTION 'This review item is not part of the Private Jobs system'; END IF;
 v_title:=nullif(btrim(v_payload->>'title'),'');
 IF v_title IS NULL OR length(v_title)>180 THEN RAISE EXCEPTION 'Valid private job title is required'; END IF;
 IF nullif(btrim(v_payload->>'description'),'') IS NULL OR length(v_payload->>'description')>8000 THEN RAISE EXCEPTION 'Job description is required'; END IF;
 IF nullif(btrim(v_payload->>'location'),'') IS NULL OR nullif(btrim(v_payload->>'category'),'') IS NULL OR nullif(btrim(v_payload->>'type'),'') IS NULL THEN RAISE EXCEPTION 'Category, employment type and location are required'; END IF;
 IF nullif(v_payload->>'company_id','') IS NOT NULL THEN
  SELECT c.id,c.company_name INTO v_company,v_company_name FROM public.companies c
  WHERE c.id=(v_payload->>'company_id')::uuid
   AND c.verification_status='verified'
   AND lower(btrim(c.company_name))=lower(btrim(coalesce(v_payload->>'company',v_review.company_name,'')));
  IF v_company IS NULL THEN RAISE EXCEPTION 'Company must be verified before publishing'; END IF;
 ELSIF nullif(v_payload->>'source_draft_id','') IS NOT NULL THEN
  RAISE EXCEPTION 'Company-submitted private jobs must retain their verified company ID';
 END IF;
 SELECT jc.id INTO v_category FROM public.job_categories jc
 WHERE jc.is_active=true AND lower(btrim(jc.category_name))=lower(btrim(v_payload->>'category'))
 ORDER BY jc.created_at ASC LIMIT 1;
 IF v_category IS NULL THEN RAISE EXCEPTION 'Select a valid active job category'; END IF;
 v_type:=CASE lower(btrim(v_payload->>'type'))
  WHEN 'full time' THEN 'full_time' WHEN 'part time' THEN 'part_time'
  WHEN 'daily wage' THEN 'daily_wage' WHEN 'temporary' THEN 'temporary'
  WHEN 'contract' THEN 'contract' WHEN 'internship' THEN 'internship'
  WHEN 'freelance' THEN 'freelance' ELSE lower(regexp_replace(btrim(v_payload->>'type'),'[^a-zA-Z0-9]+','_','g')) END;
 v_workplace:=CASE lower(btrim(coalesce(v_payload->>'workplace','onsite')))
  WHEN 'on-site' THEN 'onsite' WHEN 'on site' THEN 'onsite'
  WHEN 'hybrid' THEN 'hybrid' WHEN 'remote' THEN 'remote' ELSE 'onsite' END;
 v_salary_min:=nullif(v_payload->>'salaryMin','')::numeric;
 v_salary_max:=nullif(v_payload->>'salaryMax','')::numeric;
 IF v_salary_min IS NOT NULL AND v_salary_max IS NOT NULL AND v_salary_min>v_salary_max THEN RAISE EXCEPTION 'Minimum salary cannot exceed maximum salary'; END IF;
 v_salary_currency:=left(upper(coalesce(nullif(v_payload->>'salaryCurrency',''),'INR')),3);
 v_salary_period:=coalesce(nullif(v_payload->>'salaryPeriod',''),CASE WHEN v_type='daily_wage' THEN 'daily' ELSE 'monthly' END);
 IF v_salary_period NOT IN ('monthly','daily') THEN RAISE EXCEPTION 'Invalid salary period'; END IF;
 v_vacancies:=greatest(1,coalesce(nullif(v_payload->>'openings','')::integer,1));
 IF nullif(v_payload->>'deadline','') IS NOT NULL THEN
  IF (v_payload->>'deadline') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN RAISE EXCEPTION 'Application deadline must be a valid date'; END IF;
  IF (v_payload->>'deadline')::date < (now() at time zone 'Asia/Kolkata')::date THEN RAISE EXCEPTION 'Application deadline cannot be in the past'; END IF;
  v_deadline:=((v_payload->>'deadline')::date + interval '1 day' - interval '1 second') at time zone 'Asia/Kolkata';
 END IF;
 v_employer:=coalesce(v_company_name,nullif(btrim(coalesce(v_payload->>'company',v_review.company_name,'')),''));
 v_education:=nullif(btrim(coalesce(v_payload->>'education','')),'');
 v_skills:=nullif(btrim(coalesce(v_payload->>'skills','')),'');
 v_email:=nullif(btrim(coalesce(v_payload->>'email','')),'');
 v_application_url:=nullif(btrim(coalesce(v_payload->>'applicationUrl','')),'');
 v_slug:=lower(regexp_replace(v_title,'[^a-zA-Z0-9]+','-','g'))||'-'||substr(replace(gen_random_uuid()::text,'-',''),1,8);
 INSERT INTO public.private_jobs(
  company_id,category_id,created_by,job_title,job_slug,job_code,description,
  employment_type,workplace_type,salary_min,salary_max,salary_currency,salary_period,
  vacancies,application_url,application_deadline,status,published_at,location,
  education_level,required_skills,contact_email,employer_name,country_name,is_admin_managed
 ) VALUES (
  v_company,v_category,v_user,v_title,v_slug,'TC-PRI-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)),btrim(v_payload->>'description'),
  v_type,v_workplace,v_salary_min,v_salary_max,v_salary_currency,v_salary_period,
  v_vacancies,v_application_url,v_deadline,'published',now(),btrim(v_payload->>'location'),
  v_education,v_skills,v_email,v_employer,coalesce(nullif(btrim(v_payload->>'country_name'),''),'India'),v_company IS NULL
 ) RETURNING id INTO v_job_id;
 UPDATE public.admin_job_post_reviews
 SET published_private_job_id=v_job_id,reviewed_by=v_user,reviewed_at=coalesce(reviewed_at,now()),updated_at=now()
 WHERE id=p_review_id;
 RETURN v_job_id;
END;
$$;

REVOKE ALL ON FUNCTION public.tc_admin_publish_private_job(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.tc_admin_publish_private_job(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.tc_sync_company_job_draft_review_status()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE v_source_draft_id uuid; v_status text; v_published_id uuid;
BEGIN
 v_source_draft_id:=nullif(NEW.payload->>'source_draft_id','')::uuid;
 IF v_source_draft_id IS NULL THEN RETURN NEW; END IF;
 v_published_id:=coalesce(NEW.published_private_job_id,NEW.published_job_id);
 v_status:=CASE WHEN v_published_id IS NOT NULL THEN 'published' ELSE NEW.status END;
 UPDATE public.job_posting_drafts
 SET draft=draft||jsonb_build_object('draft_status',v_status,'review_note',coalesce(NEW.review_note,''),'published_job_id',v_published_id,'reviewed_at',NEW.reviewed_at),
 updated_at=now()
 WHERE id=v_source_draft_id;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.tc_sync_company_job_draft_review_status() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS tc_sync_company_job_draft_review_status ON public.admin_job_post_reviews;
CREATE TRIGGER tc_sync_company_job_draft_review_status
AFTER UPDATE OF status,published_job_id,published_private_job_id,review_note ON public.admin_job_post_reviews
FOR EACH ROW EXECUTE FUNCTION public.tc_sync_company_job_draft_review_status();

REVOKE ALL ON FUNCTION public.tc_admin_publish_job(uuid) FROM PUBLIC,anon,authenticated;
