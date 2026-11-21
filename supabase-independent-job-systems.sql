-- TAMILAN CAREERS: independent Government, Private and International job systems.
-- Additive setup. The legacy public.jobs table is intentionally preserved untouched.
-- This script is safe to re-run.

CREATE TABLE IF NOT EXISTS public.government_jobs (LIKE public.jobs INCLUDING ALL);
CREATE TABLE IF NOT EXISTS public.private_jobs (LIKE public.jobs INCLUDING ALL);
CREATE TABLE IF NOT EXISTS public.international_jobs (LIKE public.jobs INCLUDING ALL);

ALTER TABLE public.government_jobs DROP COLUMN IF EXISTS job_kind CASCADE;
ALTER TABLE public.private_jobs DROP COLUMN IF EXISTS job_kind CASCADE;
ALTER TABLE public.international_jobs DROP COLUMN IF EXISTS job_kind CASCADE;

ALTER TABLE public.international_jobs
  ADD COLUMN IF NOT EXISTS job_sector text,
  ADD COLUMN IF NOT EXISTS country_code text,
  ADD COLUMN IF NOT EXISTS visa_type text,
  ADD COLUMN IF NOT EXISTS work_permit text,
  ADD COLUMN IF NOT EXISTS visa_sponsorship_available boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS relocation_support boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS language_requirements text,
  ADD COLUMN IF NOT EXISTS visa_notes text;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['government_jobs','private_jobs','international_jobs'] LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = format('public.%I',t)::regclass AND conname = t||'_company_id_fkey') THEN
      EXECUTE format('ALTER TABLE public.%I ADD CONSTRAINT %I FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE SET NULL',t,t||'_company_id_fkey');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = format('public.%I',t)::regclass AND conname = t||'_category_id_fkey') THEN
      EXECUTE format('ALTER TABLE public.%I ADD CONSTRAINT %I FOREIGN KEY (category_id) REFERENCES public.job_categories(id) ON DELETE SET NULL',t,t||'_category_id_fkey');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = format('public.%I',t)::regclass AND conname = t||'_source_id_fkey') THEN
      EXECUTE format('ALTER TABLE public.%I ADD CONSTRAINT %I FOREIGN KEY (source_id) REFERENCES public.job_sources(id) ON DELETE SET NULL',t,t||'_source_id_fkey');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = format('public.%I',t)::regclass AND conname = t||'_created_by_fkey') THEN
      EXECUTE format('ALTER TABLE public.%I ADD CONSTRAINT %I FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL',t,t||'_created_by_fkey');
    END IF;
  END LOOP;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.international_jobs'::regclass AND conname='international_jobs_sector_check') THEN
    ALTER TABLE public.international_jobs ADD CONSTRAINT international_jobs_sector_check CHECK (job_sector IS NULL OR job_sector IN ('government','private'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS government_jobs_status_published_idx ON public.government_jobs(status,published_at DESC);
CREATE INDEX IF NOT EXISTS government_jobs_scope_idx ON public.government_jobs(government_scope,status);
CREATE INDEX IF NOT EXISTS private_jobs_status_published_idx ON public.private_jobs(status,published_at DESC);
CREATE INDEX IF NOT EXISTS private_jobs_company_status_idx ON public.private_jobs(company_id,status,created_at DESC);
CREATE INDEX IF NOT EXISTS international_jobs_status_published_idx ON public.international_jobs(status,published_at DESC);
CREATE INDEX IF NOT EXISTS international_jobs_country_sector_idx ON public.international_jobs(country_name,job_sector,status);

ALTER TABLE public.government_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.private_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.international_jobs ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.government_jobs,public.private_jobs,public.international_jobs TO anon,authenticated;
GRANT INSERT,UPDATE,DELETE ON public.government_jobs,public.private_jobs,public.international_jobs TO authenticated;

DROP POLICY IF EXISTS government_jobs_public_read ON public.government_jobs;
CREATE POLICY government_jobs_public_read ON public.government_jobs FOR SELECT TO anon,authenticated USING (status='published');
DROP POLICY IF EXISTS government_jobs_super_admin_all ON public.government_jobs;
CREATE POLICY government_jobs_super_admin_all ON public.government_jobs FOR ALL TO authenticated USING ((SELECT private.is_super_admin())) WITH CHECK ((SELECT private.is_super_admin()));

DROP POLICY IF EXISTS private_jobs_public_read ON public.private_jobs;
CREATE POLICY private_jobs_public_read ON public.private_jobs FOR SELECT TO anon,authenticated USING (
  status='published' AND (
    (company_id IS NULL AND is_admin_managed=true)
    OR EXISTS (SELECT 1 FROM public.companies c WHERE c.id=private_jobs.company_id AND c.verification_status='verified')
  )
);
DROP POLICY IF EXISTS private_jobs_company_read ON public.private_jobs;
CREATE POLICY private_jobs_company_read ON public.private_jobs FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.companies c WHERE c.id=private_jobs.company_id AND c.owner_user_id=(SELECT auth.uid()))
);
DROP POLICY IF EXISTS private_jobs_company_insert ON public.private_jobs;
CREATE POLICY private_jobs_company_insert ON public.private_jobs FOR INSERT TO authenticated WITH CHECK (
  created_by=(SELECT auth.uid()) AND status='pending_review'
  AND EXISTS (SELECT 1 FROM public.companies c WHERE c.id=private_jobs.company_id AND c.owner_user_id=(SELECT auth.uid()) AND c.verification_status='verified')
);
DROP POLICY IF EXISTS private_jobs_company_update ON public.private_jobs;
CREATE POLICY private_jobs_company_update ON public.private_jobs FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM public.companies c WHERE c.id=private_jobs.company_id AND c.owner_user_id=(SELECT auth.uid()) AND c.verification_status='verified'))
WITH CHECK (created_by=(SELECT auth.uid()) AND status IN ('draft','pending_review','paused','closed')
  AND EXISTS (SELECT 1 FROM public.companies c WHERE c.id=private_jobs.company_id AND c.owner_user_id=(SELECT auth.uid()) AND c.verification_status='verified'));
DROP POLICY IF EXISTS private_jobs_company_delete ON public.private_jobs;
CREATE POLICY private_jobs_company_delete ON public.private_jobs FOR DELETE TO authenticated USING (
  EXISTS (SELECT 1 FROM public.companies c WHERE c.id=private_jobs.company_id AND c.owner_user_id=(SELECT auth.uid()))
);
DROP POLICY IF EXISTS private_jobs_super_admin_all ON public.private_jobs;
CREATE POLICY private_jobs_super_admin_all ON public.private_jobs FOR ALL TO authenticated USING ((SELECT private.is_super_admin())) WITH CHECK ((SELECT private.is_super_admin()));

DROP POLICY IF EXISTS international_jobs_public_read ON public.international_jobs;
CREATE POLICY international_jobs_public_read ON public.international_jobs FOR SELECT TO anon,authenticated USING (status='published');
DROP POLICY IF EXISTS international_jobs_super_admin_all ON public.international_jobs;
CREATE POLICY international_jobs_super_admin_all ON public.international_jobs FOR ALL TO authenticated USING ((SELECT private.is_super_admin())) WITH CHECK ((SELECT private.is_super_admin()));
