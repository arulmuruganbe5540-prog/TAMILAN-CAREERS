
-- Independent application, status-history and report stores for the three job systems.
-- Existing legacy job_applications/job_reports remain untouched.

CREATE TABLE IF NOT EXISTS public.government_job_applications
 (LIKE public.job_applications INCLUDING ALL);
CREATE TABLE IF NOT EXISTS public.private_job_applications
 (LIKE public.job_applications INCLUDING ALL);
CREATE TABLE IF NOT EXISTS public.international_job_applications
 (LIKE public.job_applications INCLUDING ALL);

CREATE TABLE IF NOT EXISTS public.government_job_application_status_history
 (LIKE public.job_application_status_history INCLUDING ALL);
CREATE TABLE IF NOT EXISTS public.private_job_application_status_history
 (LIKE public.job_application_status_history INCLUDING ALL);
CREATE TABLE IF NOT EXISTS public.international_job_application_status_history
 (LIKE public.job_application_status_history INCLUDING ALL);

CREATE TABLE IF NOT EXISTS public.government_job_reports
 (LIKE public.job_reports INCLUDING ALL);
CREATE TABLE IF NOT EXISTS public.private_job_reports
 (LIKE public.job_reports INCLUDING ALL);
CREATE TABLE IF NOT EXISTS public.international_job_reports
 (LIKE public.job_reports INCLUDING ALL);

DO $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.government_job_applications'::regclass AND conname='government_job_applications_job_id_fkey') THEN
  ALTER TABLE public.government_job_applications ADD CONSTRAINT government_job_applications_job_id_fkey FOREIGN KEY(job_id) REFERENCES public.government_jobs(id) ON DELETE RESTRICT;
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.private_job_applications'::regclass AND conname='private_job_applications_job_id_fkey') THEN
  ALTER TABLE public.private_job_applications ADD CONSTRAINT private_job_applications_job_id_fkey FOREIGN KEY(job_id) REFERENCES public.private_jobs(id) ON DELETE RESTRICT;
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.international_job_applications'::regclass AND conname='international_job_applications_job_id_fkey') THEN
  ALTER TABLE public.international_job_applications ADD CONSTRAINT international_job_applications_job_id_fkey FOREIGN KEY(job_id) REFERENCES public.international_jobs(id) ON DELETE RESTRICT;
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.government_job_application_status_history'::regclass AND conname='government_job_application_status_history_application_id_fkey') THEN
  ALTER TABLE public.government_job_application_status_history ADD CONSTRAINT government_job_application_status_history_application_id_fkey FOREIGN KEY(application_id) REFERENCES public.government_job_applications(id) ON DELETE RESTRICT;
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.private_job_application_status_history'::regclass AND conname='private_job_application_status_history_application_id_fkey') THEN
  ALTER TABLE public.private_job_application_status_history ADD CONSTRAINT private_job_application_status_history_application_id_fkey FOREIGN KEY(application_id) REFERENCES public.private_job_applications(id) ON DELETE RESTRICT;
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.international_job_application_status_history'::regclass AND conname='international_job_application_status_history_application_id_fkey') THEN
  ALTER TABLE public.international_job_application_status_history ADD CONSTRAINT international_job_application_status_history_application_id_fkey FOREIGN KEY(application_id) REFERENCES public.international_job_applications(id) ON DELETE RESTRICT;
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.government_job_reports'::regclass AND conname='government_job_reports_job_id_fkey') THEN
  ALTER TABLE public.government_job_reports ADD CONSTRAINT government_job_reports_job_id_fkey FOREIGN KEY(job_id) REFERENCES public.government_jobs(id) ON DELETE CASCADE;
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.private_job_reports'::regclass AND conname='private_job_reports_job_id_fkey') THEN
  ALTER TABLE public.private_job_reports ADD CONSTRAINT private_job_reports_job_id_fkey FOREIGN KEY(job_id) REFERENCES public.private_jobs(id) ON DELETE CASCADE;
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.international_job_reports'::regclass AND conname='international_job_reports_job_id_fkey') THEN
  ALTER TABLE public.international_job_reports ADD CONSTRAINT international_job_reports_job_id_fkey FOREIGN KEY(job_id) REFERENCES public.international_jobs(id) ON DELETE CASCADE;
 END IF;
END $$;

CREATE OR REPLACE FUNCTION private.can_access_government_job_application(p_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $$
 SELECT EXISTS (
  SELECT 1 FROM public.government_job_applications a
  WHERE a.id=p_id AND (
   a.candidate_id=(SELECT auth.uid()) OR (SELECT private.is_super_admin())
  )
 );
$$;
CREATE OR REPLACE FUNCTION private.can_access_private_job_application(p_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $$
 SELECT EXISTS (
  SELECT 1 FROM public.private_job_applications a
  JOIN public.private_jobs j ON j.id=a.job_id
  LEFT JOIN public.companies c ON c.id=j.company_id
  WHERE a.id=p_id AND (
   a.candidate_id=(SELECT auth.uid()) OR (SELECT private.is_super_admin())
   OR c.owner_user_id=(SELECT auth.uid())
   OR EXISTS (SELECT 1 FROM public.company_members cm WHERE cm.company_id=j.company_id AND cm.user_id=(SELECT auth.uid()) AND cm.member_status='active' AND cm.member_role IN ('owner','hr_manager','recruiter'))
  )
 );
$$;
CREATE OR REPLACE FUNCTION private.can_access_international_job_application(p_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $$
 SELECT EXISTS (
  SELECT 1 FROM public.international_job_applications a
  JOIN public.international_jobs j ON j.id=a.job_id
  LEFT JOIN public.companies c ON c.id=j.company_id
  WHERE a.id=p_id AND (
   a.candidate_id=(SELECT auth.uid()) OR (SELECT private.is_super_admin())
   OR c.owner_user_id=(SELECT auth.uid())
   OR EXISTS (SELECT 1 FROM public.company_members cm WHERE cm.company_id=j.company_id AND cm.user_id=(SELECT auth.uid()) AND cm.member_status='active' AND cm.member_role IN ('owner','hr_manager','recruiter'))
  )
 );
$$;
REVOKE ALL ON FUNCTION private.can_access_government_job_application(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION private.can_access_private_job_application(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION private.can_access_international_job_application(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.can_access_government_job_application(uuid),private.can_access_private_job_application(uuid),private.can_access_international_job_application(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION private.log_independent_job_application_status()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE target_table text;
BEGIN
 target_table := CASE TG_TABLE_NAME
  WHEN 'government_job_applications' THEN 'government_job_application_status_history'
  WHEN 'private_job_applications' THEN 'private_job_application_status_history'
  WHEN 'international_job_applications' THEN 'international_job_application_status_history'
  ELSE NULL END;
 IF target_table IS NULL THEN RAISE EXCEPTION 'Unsupported application table'; END IF;
 IF TG_OP='INSERT' OR NEW.status IS DISTINCT FROM OLD.status THEN
  IF target_table='government_job_application_status_history' THEN
   INSERT INTO public.government_job_application_status_history(application_id,old_status,new_status,changed_by,change_note)
   VALUES(NEW.id,CASE WHEN TG_OP='INSERT' THEN NULL ELSE OLD.status END,NEW.status,(SELECT auth.uid()),CASE WHEN TG_OP='INSERT' THEN 'Application submitted' ELSE 'Application status changed' END);
  ELSIF target_table='private_job_application_status_history' THEN
   INSERT INTO public.private_job_application_status_history(application_id,old_status,new_status,changed_by,change_note)
   VALUES(NEW.id,CASE WHEN TG_OP='INSERT' THEN NULL ELSE OLD.status END,NEW.status,(SELECT auth.uid()),CASE WHEN TG_OP='INSERT' THEN 'Application submitted' ELSE 'Application status changed' END);
  ELSE
   INSERT INTO public.international_job_application_status_history(application_id,old_status,new_status,changed_by,change_note)
   VALUES(NEW.id,CASE WHEN TG_OP='INSERT' THEN NULL ELSE OLD.status END,NEW.status,(SELECT auth.uid()),CASE WHEN TG_OP='INSERT' THEN 'Application submitted' ELSE 'Application status changed' END);
  END IF;
 END IF;
 RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.log_independent_job_application_status() FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.validate_independent_job_application()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE v_ok boolean:=false;
BEGIN
 IF (SELECT auth.uid()) IS NULL OR NEW.candidate_id IS DISTINCT FROM (SELECT auth.uid()) THEN
  RAISE EXCEPTION 'You can only submit an application for your own signed-in account.';
 END IF;
 IF NEW.status<>'applied' THEN RAISE EXCEPTION 'New applications must start in applied status.'; END IF;
 IF NEW.resume_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.candidate_resumes r WHERE r.id=NEW.resume_id AND r.user_id=(SELECT auth.uid())) THEN
  RAISE EXCEPTION 'The selected resume does not belong to your account.';
 END IF;
 IF TG_TABLE_NAME='government_job_applications' THEN
  SELECT EXISTS(SELECT 1 FROM public.government_jobs j WHERE j.id=NEW.job_id AND j.status='published' AND (j.application_deadline IS NULL OR j.application_deadline>now())) INTO v_ok;
 ELSIF TG_TABLE_NAME='private_job_applications' THEN
  SELECT EXISTS(SELECT 1 FROM public.private_jobs j JOIN public.companies c ON c.id=j.company_id WHERE j.id=NEW.job_id AND j.status='published' AND c.verification_status='verified' AND (j.application_deadline IS NULL OR j.application_deadline>now())) INTO v_ok;
 ELSIF TG_TABLE_NAME='international_job_applications' THEN
  SELECT EXISTS(
   SELECT 1 FROM public.international_jobs j
   LEFT JOIN public.companies c ON c.id=j.company_id
   WHERE j.id=NEW.job_id AND j.status='published'
    AND (j.application_deadline IS NULL OR j.application_deadline>now())
    AND ((j.job_sector='government') OR (j.job_sector='private' AND c.verification_status='verified'))
  ) INTO v_ok;
 END IF;
 IF NOT v_ok THEN RAISE EXCEPTION 'This job is unavailable, not published, expired, or not verified for applications.'; END IF;
 RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.validate_independent_job_application() FROM PUBLIC,anon,authenticated;

DO $$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY['government_job_applications','private_job_applications','international_job_applications'] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('GRANT SELECT,INSERT ON public.%I TO authenticated',t);
 END LOOP;
 FOREACH t IN ARRAY ARRAY['government_job_application_status_history','private_job_application_status_history','international_job_application_status_history'] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('GRANT SELECT ON public.%I TO authenticated',t);
 END LOOP;
 FOREACH t IN ARRAY ARRAY['government_job_reports','private_job_reports','international_job_reports'] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('GRANT SELECT ON public.%I TO authenticated',t);
 END LOOP;
END $$;

DROP POLICY IF EXISTS government_job_applications_insert_candidate ON public.government_job_applications;
CREATE POLICY government_job_applications_insert_candidate ON public.government_job_applications FOR INSERT TO authenticated WITH CHECK(candidate_id=(SELECT auth.uid()) AND status='applied' AND (resume_id IS NULL OR EXISTS(SELECT 1 FROM public.candidate_resumes r WHERE r.id=resume_id AND r.user_id=(SELECT auth.uid()))));
DROP POLICY IF EXISTS government_job_applications_read_authorized ON public.government_job_applications;
CREATE POLICY government_job_applications_read_authorized ON public.government_job_applications FOR SELECT TO authenticated USING(candidate_id=(SELECT auth.uid()) OR (SELECT private.is_super_admin()));
DROP POLICY IF EXISTS private_job_applications_insert_candidate ON public.private_job_applications;
CREATE POLICY private_job_applications_insert_candidate ON public.private_job_applications FOR INSERT TO authenticated WITH CHECK(candidate_id=(SELECT auth.uid()) AND status='applied' AND (resume_id IS NULL OR EXISTS(SELECT 1 FROM public.candidate_resumes r WHERE r.id=resume_id AND r.user_id=(SELECT auth.uid()))));
DROP POLICY IF EXISTS private_job_applications_read_authorized ON public.private_job_applications;
CREATE POLICY private_job_applications_read_authorized ON public.private_job_applications FOR SELECT TO authenticated USING(private.can_access_private_job_application(id));
DROP POLICY IF EXISTS international_job_applications_insert_candidate ON public.international_job_applications;
CREATE POLICY international_job_applications_insert_candidate ON public.international_job_applications FOR INSERT TO authenticated WITH CHECK(candidate_id=(SELECT auth.uid()) AND status='applied' AND (resume_id IS NULL OR EXISTS(SELECT 1 FROM public.candidate_resumes r WHERE r.id=resume_id AND r.user_id=(SELECT auth.uid()))));
DROP POLICY IF EXISTS international_job_applications_read_authorized ON public.international_job_applications;
CREATE POLICY international_job_applications_read_authorized ON public.international_job_applications FOR SELECT TO authenticated USING(private.can_access_international_job_application(id));

DROP POLICY IF EXISTS government_job_application_history_read ON public.government_job_application_status_history;
CREATE POLICY government_job_application_history_read ON public.government_job_application_status_history FOR SELECT TO authenticated USING(private.can_access_government_job_application(application_id));
DROP POLICY IF EXISTS private_job_application_history_read ON public.private_job_application_status_history;
CREATE POLICY private_job_application_history_read ON public.private_job_application_status_history FOR SELECT TO authenticated USING(private.can_access_private_job_application(application_id));
DROP POLICY IF EXISTS international_job_application_history_read ON public.international_job_application_status_history;
CREATE POLICY international_job_application_history_read ON public.international_job_application_status_history FOR SELECT TO authenticated USING(private.can_access_international_job_application(application_id));

DROP POLICY IF EXISTS government_job_reports_read_own_or_admin ON public.government_job_reports;
CREATE POLICY government_job_reports_read_own_or_admin ON public.government_job_reports FOR SELECT TO authenticated USING(reporter_user_id=(SELECT auth.uid()) OR (SELECT private.is_super_admin()));
DROP POLICY IF EXISTS government_job_reports_admin_update ON public.government_job_reports;
CREATE POLICY government_job_reports_admin_update ON public.government_job_reports FOR UPDATE TO authenticated USING((SELECT private.is_super_admin())) WITH CHECK((SELECT private.is_super_admin()));
DROP POLICY IF EXISTS private_job_reports_read_own_or_admin ON public.private_job_reports;
CREATE POLICY private_job_reports_read_own_or_admin ON public.private_job_reports FOR SELECT TO authenticated USING(reporter_user_id=(SELECT auth.uid()) OR (SELECT private.is_super_admin()));
DROP POLICY IF EXISTS private_job_reports_admin_update ON public.private_job_reports;
CREATE POLICY private_job_reports_admin_update ON public.private_job_reports FOR UPDATE TO authenticated USING((SELECT private.is_super_admin())) WITH CHECK((SELECT private.is_super_admin()));
DROP POLICY IF EXISTS international_job_reports_read_own_or_admin ON public.international_job_reports;
CREATE POLICY international_job_reports_read_own_or_admin ON public.international_job_reports FOR SELECT TO authenticated USING(reporter_user_id=(SELECT auth.uid()) OR (SELECT private.is_super_admin()));
DROP POLICY IF EXISTS international_job_reports_admin_update ON public.international_job_reports;
CREATE POLICY international_job_reports_admin_update ON public.international_job_reports FOR UPDATE TO authenticated USING((SELECT private.is_super_admin())) WITH CHECK((SELECT private.is_super_admin()));

CREATE OR REPLACE FUNCTION public.tc_candidate_withdraw_government_application(p_application_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE v_user uuid:=(SELECT auth.uid()); v_id uuid;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION 'Login required'; END IF;
 UPDATE public.government_job_applications SET status='withdrawn',updated_at=now()
 WHERE id=p_application_id AND candidate_id=v_user AND status IN ('applied','under_review','shortlisted') RETURNING id INTO v_id;
 IF v_id IS NULL THEN RAISE EXCEPTION 'Application not found or cannot be withdrawn'; END IF;
 RETURN jsonb_build_object('success',true,'application_id',v_id);
END $$;
CREATE OR REPLACE FUNCTION public.tc_candidate_withdraw_private_application(p_application_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE v_user uuid:=(SELECT auth.uid()); v_id uuid;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION 'Login required'; END IF;
 UPDATE public.private_job_applications SET status='withdrawn',updated_at=now()
 WHERE id=p_application_id AND candidate_id=v_user AND status IN ('applied','under_review','shortlisted') RETURNING id INTO v_id;
 IF v_id IS NULL THEN RAISE EXCEPTION 'Application not found or cannot be withdrawn'; END IF;
 RETURN jsonb_build_object('success',true,'application_id',v_id);
END $$;
CREATE OR REPLACE FUNCTION public.tc_candidate_withdraw_international_application(p_application_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE v_user uuid:=(SELECT auth.uid()); v_id uuid;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION 'Login required'; END IF;
 UPDATE public.international_job_applications SET status='withdrawn',updated_at=now()
 WHERE id=p_application_id AND candidate_id=v_user AND status IN ('applied','under_review','shortlisted') RETURNING id INTO v_id;
 IF v_id IS NULL THEN RAISE EXCEPTION 'Application not found or cannot be withdrawn'; END IF;
 RETURN jsonb_build_object('success',true,'application_id',v_id);
END $$;

REVOKE ALL ON FUNCTION public.tc_candidate_withdraw_government_application(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.tc_candidate_withdraw_private_application(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.tc_candidate_withdraw_international_application(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.tc_candidate_withdraw_government_application(uuid),public.tc_candidate_withdraw_private_application(uuid),public.tc_candidate_withdraw_international_application(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.tc_submit_government_job_report(p_job_id uuid,p_reason text,p_details text DEFAULT '')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE v_user uuid:=(SELECT auth.uid()); v_id uuid;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION 'Login required'; END IF;
 IF p_reason NOT IN ('upfront_payment','fake_or_misleading','identity_impersonation','personal_data_request','expired_or_filled','other') OR char_length(coalesce(p_details,''))>2000 THEN RAISE EXCEPTION 'Invalid report reason or details'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.government_jobs WHERE id=p_job_id AND status='published') THEN RAISE EXCEPTION 'Published Government job not found'; END IF;
 INSERT INTO public.government_job_reports(job_id,reporter_user_id,reason,details) VALUES(p_job_id,v_user,p_reason,btrim(coalesce(p_details,''))) ON CONFLICT(job_id,reporter_user_id) DO NOTHING RETURNING id INTO v_id;
 RETURN jsonb_build_object('success',true,'already_reported',v_id IS NULL,'report_id',v_id);
END $$;
CREATE OR REPLACE FUNCTION public.tc_submit_private_job_report(p_job_id uuid,p_reason text,p_details text DEFAULT '')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE v_user uuid:=(SELECT auth.uid()); v_id uuid;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION 'Login required'; END IF;
 IF p_reason NOT IN ('upfront_payment','fake_or_misleading','identity_impersonation','personal_data_request','expired_or_filled','other') OR char_length(coalesce(p_details,''))>2000 THEN RAISE EXCEPTION 'Invalid report reason or details'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.private_jobs WHERE id=p_job_id AND status='published') THEN RAISE EXCEPTION 'Published Private job not found'; END IF;
 INSERT INTO public.private_job_reports(job_id,reporter_user_id,reason,details) VALUES(p_job_id,v_user,p_reason,btrim(coalesce(p_details,''))) ON CONFLICT(job_id,reporter_user_id) DO NOTHING RETURNING id INTO v_id;
 RETURN jsonb_build_object('success',true,'already_reported',v_id IS NULL,'report_id',v_id);
END $$;
CREATE OR REPLACE FUNCTION public.tc_submit_international_job_report(p_job_id uuid,p_reason text,p_details text DEFAULT '')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE v_user uuid:=(SELECT auth.uid()); v_id uuid;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION 'Login required'; END IF;
 IF p_reason NOT IN ('upfront_payment','fake_or_misleading','identity_impersonation','personal_data_request','expired_or_filled','other') OR char_length(coalesce(p_details,''))>2000 THEN RAISE EXCEPTION 'Invalid report reason or details'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.international_jobs WHERE id=p_job_id AND status='published') THEN RAISE EXCEPTION 'Published International job not found'; END IF;
 INSERT INTO public.international_job_reports(job_id,reporter_user_id,reason,details) VALUES(p_job_id,v_user,p_reason,btrim(coalesce(p_details,''))) ON CONFLICT(job_id,reporter_user_id) DO NOTHING RETURNING id INTO v_id;
 RETURN jsonb_build_object('success',true,'already_reported',v_id IS NULL,'report_id',v_id);
END $$;
REVOKE ALL ON FUNCTION public.tc_submit_government_job_report(uuid,text,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.tc_submit_private_job_report(uuid,text,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.tc_submit_international_job_report(uuid,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.tc_submit_government_job_report(uuid,text,text),public.tc_submit_private_job_report(uuid,text,text),public.tc_submit_international_job_report(uuid,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.tc_review_government_job_report(p_report_id uuid,p_status text,p_admin_note text DEFAULT '')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE v_user uuid:=(SELECT auth.uid());
BEGIN
 IF v_user IS NULL OR NOT EXISTS(SELECT 1 FROM public.user_roles WHERE user_id=v_user AND role='super_admin') THEN RAISE EXCEPTION 'Super Admin permission required'; END IF;
 PERFORM private.require_super_admin_mfa();
 IF p_status NOT IN ('reviewing','actioned','dismissed') THEN RAISE EXCEPTION 'Invalid report decision'; END IF;
 UPDATE public.government_job_reports SET status=p_status,admin_note=left(coalesce(p_admin_note,''),2000),reviewed_by=v_user,reviewed_at=now(),updated_at=now() WHERE id=p_report_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Government job report not found'; END IF;
 RETURN jsonb_build_object('success',true,'report_id',p_report_id,'status',p_status);
END $$;
CREATE OR REPLACE FUNCTION public.tc_review_private_job_report(p_report_id uuid,p_status text,p_admin_note text DEFAULT '')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE v_user uuid:=(SELECT auth.uid());
BEGIN
 IF v_user IS NULL OR NOT EXISTS(SELECT 1 FROM public.user_roles WHERE user_id=v_user AND role='super_admin') THEN RAISE EXCEPTION 'Super Admin permission required'; END IF;
 PERFORM private.require_super_admin_mfa();
 IF p_status NOT IN ('reviewing','actioned','dismissed') THEN RAISE EXCEPTION 'Invalid report decision'; END IF;
 UPDATE public.private_job_reports SET status=p_status,admin_note=left(coalesce(p_admin_note,''),2000),reviewed_by=v_user,reviewed_at=now(),updated_at=now() WHERE id=p_report_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Private job report not found'; END IF;
 RETURN jsonb_build_object('success',true,'report_id',p_report_id,'status',p_status);
END $$;
CREATE OR REPLACE FUNCTION public.tc_review_international_job_report(p_report_id uuid,p_status text,p_admin_note text DEFAULT '')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE v_user uuid:=(SELECT auth.uid());
BEGIN
 IF v_user IS NULL OR NOT EXISTS(SELECT 1 FROM public.user_roles WHERE user_id=v_user AND role='super_admin') THEN RAISE EXCEPTION 'Super Admin permission required'; END IF;
 PERFORM private.require_super_admin_mfa();
 IF p_status NOT IN ('reviewing','actioned','dismissed') THEN RAISE EXCEPTION 'Invalid report decision'; END IF;
 UPDATE public.international_job_reports SET status=p_status,admin_note=left(coalesce(p_admin_note,''),2000),reviewed_by=v_user,reviewed_at=now(),updated_at=now() WHERE id=p_report_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'International job report not found'; END IF;
 RETURN jsonb_build_object('success',true,'report_id',p_report_id,'status',p_status);
END $$;
REVOKE ALL ON FUNCTION public.tc_review_government_job_report(uuid,text,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.tc_review_private_job_report(uuid,text,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.tc_review_international_job_report(uuid,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.tc_review_government_job_report(uuid,text,text),public.tc_review_private_job_report(uuid,text,text),public.tc_review_international_job_report(uuid,text,text) TO authenticated;

DROP TRIGGER IF EXISTS trg_independent_job_application_validation ON public.government_job_applications;
DROP TRIGGER IF EXISTS trg_independent_job_application_validation ON public.private_job_applications;
DROP TRIGGER IF EXISTS trg_independent_job_application_validation ON public.international_job_applications;
DROP TRIGGER IF EXISTS trg_independent_job_application_history ON public.government_job_applications;
DROP TRIGGER IF EXISTS trg_independent_job_application_history ON public.private_job_applications;
DROP TRIGGER IF EXISTS trg_independent_job_application_history ON public.international_job_applications;
CREATE TRIGGER trg_independent_job_application_validation BEFORE INSERT ON public.government_job_applications FOR EACH ROW EXECUTE FUNCTION private.validate_independent_job_application();
CREATE TRIGGER trg_independent_job_application_validation BEFORE INSERT ON public.private_job_applications FOR EACH ROW EXECUTE FUNCTION private.validate_independent_job_application();
CREATE TRIGGER trg_independent_job_application_validation BEFORE INSERT ON public.international_job_applications FOR EACH ROW EXECUTE FUNCTION private.validate_independent_job_application();
CREATE TRIGGER trg_independent_job_application_history AFTER INSERT OR UPDATE ON public.government_job_applications FOR EACH ROW EXECUTE FUNCTION private.log_independent_job_application_status();
CREATE TRIGGER trg_independent_job_application_history AFTER INSERT OR UPDATE ON public.private_job_applications FOR EACH ROW EXECUTE FUNCTION private.log_independent_job_application_status();
CREATE TRIGGER trg_independent_job_application_history AFTER INSERT OR UPDATE ON public.international_job_applications FOR EACH ROW EXECUTE FUNCTION private.log_independent_job_application_status();

-- Foreign keys are deliberately added explicitly because CREATE TABLE LIKE does not copy FK constraints.
DO $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.government_job_applications'::regclass AND conname='government_job_applications_candidate_id_fkey') THEN ALTER TABLE public.government_job_applications ADD CONSTRAINT government_job_applications_candidate_id_fkey FOREIGN KEY(candidate_id) REFERENCES auth.users(id) ON DELETE RESTRICT; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.government_job_applications'::regclass AND conname='government_job_applications_resume_id_fkey') THEN ALTER TABLE public.government_job_applications ADD CONSTRAINT government_job_applications_resume_id_fkey FOREIGN KEY(resume_id) REFERENCES public.candidate_resumes(id) ON DELETE SET NULL; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.government_job_application_status_history'::regclass AND conname='government_job_application_history_changed_by_fkey') THEN ALTER TABLE public.government_job_application_status_history ADD CONSTRAINT government_job_application_history_changed_by_fkey FOREIGN KEY(changed_by) REFERENCES auth.users(id) ON DELETE SET NULL; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.government_job_reports'::regclass AND conname='government_job_reports_reporter_user_id_fkey') THEN ALTER TABLE public.government_job_reports ADD CONSTRAINT government_job_reports_reporter_user_id_fkey FOREIGN KEY(reporter_user_id) REFERENCES auth.users(id) ON DELETE CASCADE; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.government_job_reports'::regclass AND conname='government_job_reports_reviewed_by_fkey') THEN ALTER TABLE public.government_job_reports ADD CONSTRAINT government_job_reports_reviewed_by_fkey FOREIGN KEY(reviewed_by) REFERENCES auth.users(id); END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.private_job_applications'::regclass AND conname='private_job_applications_candidate_id_fkey') THEN ALTER TABLE public.private_job_applications ADD CONSTRAINT private_job_applications_candidate_id_fkey FOREIGN KEY(candidate_id) REFERENCES auth.users(id) ON DELETE RESTRICT; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.private_job_applications'::regclass AND conname='private_job_applications_resume_id_fkey') THEN ALTER TABLE public.private_job_applications ADD CONSTRAINT private_job_applications_resume_id_fkey FOREIGN KEY(resume_id) REFERENCES public.candidate_resumes(id) ON DELETE SET NULL; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.private_job_application_status_history'::regclass AND conname='private_job_application_history_changed_by_fkey') THEN ALTER TABLE public.private_job_application_status_history ADD CONSTRAINT private_job_application_history_changed_by_fkey FOREIGN KEY(changed_by) REFERENCES auth.users(id) ON DELETE SET NULL; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.private_job_reports'::regclass AND conname='private_job_reports_reporter_user_id_fkey') THEN ALTER TABLE public.private_job_reports ADD CONSTRAINT private_job_reports_reporter_user_id_fkey FOREIGN KEY(reporter_user_id) REFERENCES auth.users(id) ON DELETE CASCADE; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.private_job_reports'::regclass AND conname='private_job_reports_reviewed_by_fkey') THEN ALTER TABLE public.private_job_reports ADD CONSTRAINT private_job_reports_reviewed_by_fkey FOREIGN KEY(reviewed_by) REFERENCES auth.users(id); END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.international_job_applications'::regclass AND conname='international_job_applications_candidate_id_fkey') THEN ALTER TABLE public.international_job_applications ADD CONSTRAINT international_job_applications_candidate_id_fkey FOREIGN KEY(candidate_id) REFERENCES auth.users(id) ON DELETE RESTRICT; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.international_job_applications'::regclass AND conname='international_job_applications_resume_id_fkey') THEN ALTER TABLE public.international_job_applications ADD CONSTRAINT international_job_applications_resume_id_fkey FOREIGN KEY(resume_id) REFERENCES public.candidate_resumes(id) ON DELETE SET NULL; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.international_job_application_status_history'::regclass AND conname='international_job_application_history_changed_by_fkey') THEN ALTER TABLE public.international_job_application_status_history ADD CONSTRAINT international_job_application_history_changed_by_fkey FOREIGN KEY(changed_by) REFERENCES auth.users(id) ON DELETE SET NULL; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.international_job_reports'::regclass AND conname='international_job_reports_reporter_user_id_fkey') THEN ALTER TABLE public.international_job_reports ADD CONSTRAINT international_job_reports_reporter_user_id_fkey FOREIGN KEY(reporter_user_id) REFERENCES auth.users(id) ON DELETE CASCADE; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.international_job_reports'::regclass AND conname='international_job_reports_reviewed_by_fkey') THEN ALTER TABLE public.international_job_reports ADD CONSTRAINT international_job_reports_reviewed_by_fkey FOREIGN KEY(reviewed_by) REFERENCES auth.users(id); END IF;
END $$;

CREATE OR REPLACE FUNCTION private.validate_independent_job_application()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE v_ok boolean:=false;
BEGIN
 IF (SELECT auth.uid()) IS NULL OR NEW.candidate_id IS DISTINCT FROM (SELECT auth.uid()) THEN RAISE EXCEPTION 'You can only submit an application for your own signed-in account.'; END IF;
 IF NEW.status<>'applied' THEN RAISE EXCEPTION 'New applications must start in applied status.'; END IF;
 IF NEW.resume_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.candidate_resumes r WHERE r.id=NEW.resume_id AND r.user_id=(SELECT auth.uid())) THEN RAISE EXCEPTION 'The selected resume does not belong to your account.'; END IF;
 IF TG_TABLE_NAME='government_job_applications' THEN
  SELECT EXISTS(SELECT 1 FROM public.government_jobs j WHERE j.id=NEW.job_id AND j.status='published' AND (j.application_deadline IS NULL OR j.application_deadline>now())) INTO v_ok;
 ELSIF TG_TABLE_NAME='private_job_applications' THEN
  SELECT EXISTS(SELECT 1 FROM public.private_jobs j LEFT JOIN public.companies c ON c.id=j.company_id WHERE j.id=NEW.job_id AND j.status='published' AND (j.is_admin_managed=true OR c.verification_status='verified') AND (j.application_deadline IS NULL OR j.application_deadline>now())) INTO v_ok;
 ELSIF TG_TABLE_NAME='international_job_applications' THEN
  SELECT EXISTS(SELECT 1 FROM public.international_jobs j LEFT JOIN public.companies c ON c.id=j.company_id WHERE j.id=NEW.job_id AND j.status='published' AND (j.application_deadline IS NULL OR j.application_deadline>now()) AND (j.job_sector='government' OR (j.job_sector='private' AND (j.is_admin_managed=true OR c.verification_status='verified')))) INTO v_ok;
 END IF;
 IF NOT v_ok THEN RAISE EXCEPTION 'This job is unavailable, not published, expired, or not verified for applications.'; END IF;
 RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.validate_independent_job_application() FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.tc_company_update_private_application_status(p_application_id uuid,p_company_id uuid,p_new_status text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE v_old text; v_candidate uuid; v_title text;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Login required'; END IF;
 IF p_new_status NOT IN ('under_review','shortlisted','rejected') THEN RAISE EXCEPTION 'Invalid application status'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.companies c WHERE c.id=p_company_id AND c.owner_user_id=auth.uid())
 AND NOT EXISTS(SELECT 1 FROM public.company_members cm WHERE cm.company_id=p_company_id AND cm.user_id=auth.uid() AND cm.member_status='active' AND cm.member_role IN ('owner','hr_manager','recruiter')) THEN RAISE EXCEPTION 'Company application permission required'; END IF;
 SELECT a.status,a.candidate_id,j.job_title INTO v_old,v_candidate,v_title FROM public.private_job_applications a JOIN public.private_jobs j ON j.id=a.job_id WHERE a.id=p_application_id AND j.company_id=p_company_id FOR UPDATE OF a;
 IF NOT FOUND THEN RAISE EXCEPTION 'Private job application not found'; END IF;
 IF v_old IN ('withdrawn','rejected') THEN RAISE EXCEPTION 'This application is closed'; END IF;
 IF v_old NOT IN ('applied','under_review','shortlisted') THEN RAISE EXCEPTION 'Application status cannot be changed'; END IF;
 IF v_old=p_new_status THEN RETURN p_new_status; END IF;
 UPDATE public.private_job_applications SET status=p_new_status,updated_at=now() WHERE id=p_application_id;
 IF to_regclass('public.tc_notifications') IS NOT NULL THEN INSERT INTO public.tc_notifications(user_id,notification_type,title,body,related_application_id) VALUES(v_candidate,'application_status','Your application status was updated',coalesce(v_title,'Private Job')||' — '||replace(p_new_status,'_',' '),p_application_id); END IF;
 RETURN p_new_status;
END $$;

CREATE OR REPLACE FUNCTION public.tc_company_update_international_application_status(p_application_id uuid,p_company_id uuid,p_new_status text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE v_old text; v_candidate uuid; v_title text;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Login required'; END IF;
 IF p_new_status NOT IN ('under_review','shortlisted','rejected') THEN RAISE EXCEPTION 'Invalid application status'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.companies c WHERE c.id=p_company_id AND c.owner_user_id=auth.uid())
 AND NOT EXISTS(SELECT 1 FROM public.company_members cm WHERE cm.company_id=p_company_id AND cm.user_id=auth.uid() AND cm.member_status='active' AND cm.member_role IN ('owner','hr_manager','recruiter')) THEN RAISE EXCEPTION 'Company application permission required'; END IF;
 SELECT a.status,a.candidate_id,j.job_title INTO v_old,v_candidate,v_title FROM public.international_job_applications a JOIN public.international_jobs j ON j.id=a.job_id WHERE a.id=p_application_id AND j.company_id=p_company_id FOR UPDATE OF a;
 IF NOT FOUND THEN RAISE EXCEPTION 'International job application not found'; END IF;
 IF v_old IN ('withdrawn','rejected') THEN RAISE EXCEPTION 'This application is closed'; END IF;
 IF v_old NOT IN ('applied','under_review','shortlisted') THEN RAISE EXCEPTION 'Application status cannot be changed'; END IF;
 IF v_old=p_new_status THEN RETURN p_new_status; END IF;
 UPDATE public.international_job_applications SET status=p_new_status,updated_at=now() WHERE id=p_application_id;
 IF to_regclass('public.tc_notifications') IS NOT NULL THEN INSERT INTO public.tc_notifications(user_id,notification_type,title,body,related_application_id) VALUES(v_candidate,'application_status','Your application status was updated',coalesce(v_title,'International Job')||' — '||replace(p_new_status,'_',' '),p_application_id); END IF;
 RETURN p_new_status;
END $$;

REVOKE ALL ON FUNCTION public.tc_company_update_private_application_status(uuid,uuid,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.tc_company_update_international_application_status(uuid,uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.tc_company_update_private_application_status(uuid,uuid,text),public.tc_company_update_international_application_status(uuid,uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.tc_company_manage_private_job(p_job_id uuid,p_new_status text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE v_company uuid; v_deadline timestamptz;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Login required'; END IF;
 IF p_new_status NOT IN ('closed','published') THEN RAISE EXCEPTION 'Invalid job status'; END IF;
 SELECT company_id,application_deadline INTO v_company,v_deadline FROM public.private_jobs WHERE id=p_job_id FOR UPDATE;
 IF NOT FOUND OR v_company IS NULL THEN RAISE EXCEPTION 'Private job not found or not linked to a company'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.companies c WHERE c.id=v_company AND c.owner_user_id=auth.uid())
 AND NOT EXISTS(SELECT 1 FROM public.company_members cm WHERE cm.company_id=v_company AND cm.user_id=auth.uid() AND cm.member_status='active' AND cm.member_role IN ('owner','hr_manager')) THEN RAISE EXCEPTION 'Company owner or HR Manager permission required'; END IF;
 IF p_new_status='published' AND v_deadline IS NOT NULL AND v_deadline<=now() THEN RAISE EXCEPTION 'Expired job cannot be republished'; END IF;
 UPDATE public.private_jobs SET status=p_new_status,published_at=CASE WHEN p_new_status='published' THEN coalesce(published_at,now()) ELSE published_at END,updated_at=now() WHERE id=p_job_id;
 RETURN jsonb_build_object('success',true,'job_id',p_job_id,'status',p_new_status);
END $$;
CREATE OR REPLACE FUNCTION public.tc_company_manage_international_job(p_job_id uuid,p_new_status text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE v_company uuid; v_deadline timestamptz;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Login required'; END IF;
 IF p_new_status NOT IN ('closed','published') THEN RAISE EXCEPTION 'Invalid job status'; END IF;
 SELECT company_id,application_deadline INTO v_company,v_deadline FROM public.international_jobs WHERE id=p_job_id FOR UPDATE;
 IF NOT FOUND OR v_company IS NULL THEN RAISE EXCEPTION 'International job not found or not linked to a company'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.companies c WHERE c.id=v_company AND c.owner_user_id=auth.uid())
 AND NOT EXISTS(SELECT 1 FROM public.company_members cm WHERE cm.company_id=v_company AND cm.user_id=auth.uid() AND cm.member_status='active' AND cm.member_role IN ('owner','hr_manager')) THEN RAISE EXCEPTION 'Company owner or HR Manager permission required'; END IF;
 IF p_new_status='published' AND v_deadline IS NOT NULL AND v_deadline<=now() THEN RAISE EXCEPTION 'Expired job cannot be republished'; END IF;
 UPDATE public.international_jobs SET status=p_new_status,published_at=CASE WHEN p_new_status='published' THEN coalesce(published_at,now()) ELSE published_at END,updated_at=now() WHERE id=p_job_id;
 RETURN jsonb_build_object('success',true,'job_id',p_job_id,'status',p_new_status);
END $$;
REVOKE ALL ON FUNCTION public.tc_company_manage_private_job(uuid,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.tc_company_manage_international_job(uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.tc_company_manage_private_job(uuid,text),public.tc_company_manage_international_job(uuid,text) TO authenticated;
