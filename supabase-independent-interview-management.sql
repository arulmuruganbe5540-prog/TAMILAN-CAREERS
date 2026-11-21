-- Independent interview invitations for the Private Jobs and International Jobs systems.
-- Government Jobs and the legacy interview workflow are intentionally untouched.

CREATE TABLE IF NOT EXISTS public.private_job_interview_invitations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 application_id uuid NOT NULL REFERENCES public.private_job_applications(id) ON DELETE CASCADE,
 job_id uuid NOT NULL REFERENCES public.private_jobs(id) ON DELETE RESTRICT,
 company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
 candidate_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 invited_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 interview_title text NOT NULL CHECK(length(btrim(interview_title)) BETWEEN 2 AND 180),
 scheduled_at timestamptz NOT NULL,
 timezone text NOT NULL DEFAULT 'Asia/Kolkata',
 duration_minutes integer NOT NULL DEFAULT 30 CHECK(duration_minutes BETWEEN 10 AND 480),
 interview_mode text NOT NULL CHECK(interview_mode IN ('online','in_person','phone')),
 meeting_url text,
 location text,
 invitation_message text NOT NULL DEFAULT '' CHECK(length(invitation_message)<=8000),
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','accepted','declined','cancelled','completed')),
 candidate_response_note text CHECK(length(coalesce(candidate_response_note,''))<=2000),
 candidate_response_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT private_interview_location_length CHECK(length(coalesce(location,''))<=1000),
 CONSTRAINT private_interview_url_length CHECK(length(coalesce(meeting_url,''))<=1000)
);
CREATE TABLE IF NOT EXISTS public.international_job_interview_invitations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 application_id uuid NOT NULL REFERENCES public.international_job_applications(id) ON DELETE CASCADE,
 job_id uuid NOT NULL REFERENCES public.international_jobs(id) ON DELETE RESTRICT,
 company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
 candidate_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 invited_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 interview_title text NOT NULL CHECK(length(btrim(interview_title)) BETWEEN 2 AND 180),
 scheduled_at timestamptz NOT NULL,
 timezone text NOT NULL,
 duration_minutes integer NOT NULL DEFAULT 30 CHECK(duration_minutes BETWEEN 10 AND 480),
 interview_mode text NOT NULL CHECK(interview_mode IN ('online','in_person','phone')),
 meeting_url text,
 location text,
 invitation_message text NOT NULL DEFAULT '' CHECK(length(invitation_message)<=8000),
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','accepted','declined','cancelled','completed')),
 candidate_response_note text CHECK(length(coalesce(candidate_response_note,''))<=2000),
 candidate_response_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT international_interview_location_length CHECK(length(coalesce(location,''))<=1000),
 CONSTRAINT international_interview_url_length CHECK(length(coalesce(meeting_url,''))<=1000)
);
CREATE TABLE IF NOT EXISTS public.private_job_interview_history (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 interview_id uuid NOT NULL REFERENCES public.private_job_interview_invitations(id) ON DELETE CASCADE,
 old_status text,new_status text NOT NULL,changed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 change_note text NOT NULL DEFAULT '',changed_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.international_job_interview_history (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 interview_id uuid NOT NULL REFERENCES public.international_job_interview_invitations(id) ON DELETE CASCADE,
 old_status text,new_status text NOT NULL,changed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 change_note text NOT NULL DEFAULT '',changed_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS private_interview_candidate_schedule_idx ON public.private_job_interview_invitations(candidate_id,scheduled_at DESC);
CREATE INDEX IF NOT EXISTS private_interview_company_schedule_idx ON public.private_job_interview_invitations(company_id,scheduled_at DESC);
CREATE INDEX IF NOT EXISTS private_interview_application_idx ON public.private_job_interview_invitations(application_id,created_at DESC);
CREATE INDEX IF NOT EXISTS international_interview_candidate_schedule_idx ON public.international_job_interview_invitations(candidate_id,scheduled_at DESC);
CREATE INDEX IF NOT EXISTS international_interview_company_schedule_idx ON public.international_job_interview_invitations(company_id,scheduled_at DESC);
CREATE INDEX IF NOT EXISTS international_interview_application_idx ON public.international_job_interview_invitations(application_id,created_at DESC);

ALTER TABLE public.private_job_interview_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.international_job_interview_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.private_job_interview_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.international_job_interview_history ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.private_job_interview_invitations,public.international_job_interview_invitations,
 public.private_job_interview_history,public.international_job_interview_history FROM anon,authenticated;
GRANT SELECT ON public.private_job_interview_invitations,public.international_job_interview_invitations,
 public.private_job_interview_history,public.international_job_interview_history TO authenticated;

DROP POLICY IF EXISTS private_interview_read_authorized ON public.private_job_interview_invitations;
CREATE POLICY private_interview_read_authorized ON public.private_job_interview_invitations FOR SELECT TO authenticated USING (
 candidate_id=(SELECT auth.uid())
 OR EXISTS(SELECT 1 FROM public.company_members cm WHERE cm.company_id=private_job_interview_invitations.company_id AND cm.user_id=(SELECT auth.uid()) AND cm.member_status='active' AND cm.member_role IN ('owner','hr_manager','recruiter'))
 OR EXISTS(SELECT 1 FROM public.companies c WHERE c.id=private_job_interview_invitations.company_id AND c.owner_user_id=(SELECT auth.uid()))
 OR (SELECT private.is_super_admin())
);
DROP POLICY IF EXISTS international_interview_read_authorized ON public.international_job_interview_invitations;
CREATE POLICY international_interview_read_authorized ON public.international_job_interview_invitations FOR SELECT TO authenticated USING (
 candidate_id=(SELECT auth.uid())
 OR EXISTS(SELECT 1 FROM public.company_members cm WHERE cm.company_id=international_job_interview_invitations.company_id AND cm.user_id=(SELECT auth.uid()) AND cm.member_status='active' AND cm.member_role IN ('owner','hr_manager','recruiter'))
 OR EXISTS(SELECT 1 FROM public.companies c WHERE c.id=international_job_interview_invitations.company_id AND c.owner_user_id=(SELECT auth.uid()))
 OR (SELECT private.is_super_admin())
);
DROP POLICY IF EXISTS private_interview_history_read_authorized ON public.private_job_interview_history;
CREATE POLICY private_interview_history_read_authorized ON public.private_job_interview_history FOR SELECT TO authenticated USING (EXISTS(
 SELECT 1 FROM public.private_job_interview_invitations i WHERE i.id=private_job_interview_history.interview_id AND (
  i.candidate_id=(SELECT auth.uid())
  OR EXISTS(SELECT 1 FROM public.company_members cm WHERE cm.company_id=i.company_id AND cm.user_id=(SELECT auth.uid()) AND cm.member_status='active' AND cm.member_role IN ('owner','hr_manager','recruiter'))
  OR EXISTS(SELECT 1 FROM public.companies c WHERE c.id=i.company_id AND c.owner_user_id=(SELECT auth.uid()))
  OR (SELECT private.is_super_admin()))
));
DROP POLICY IF EXISTS international_interview_history_read_authorized ON public.international_job_interview_history;
CREATE POLICY international_interview_history_read_authorized ON public.international_job_interview_history FOR SELECT TO authenticated USING (EXISTS(
 SELECT 1 FROM public.international_job_interview_invitations i WHERE i.id=international_job_interview_history.interview_id AND (
  i.candidate_id=(SELECT auth.uid())
  OR EXISTS(SELECT 1 FROM public.company_members cm WHERE cm.company_id=i.company_id AND cm.user_id=(SELECT auth.uid()) AND cm.member_status='active' AND cm.member_role IN ('owner','hr_manager','recruiter'))
  OR EXISTS(SELECT 1 FROM public.companies c WHERE c.id=i.company_id AND c.owner_user_id=(SELECT auth.uid()))
  OR (SELECT private.is_super_admin()))
));

CREATE OR REPLACE FUNCTION private.tc_create_independent_interview(
 p_system text,p_application_id uuid,p_interview_title text,p_scheduled_at timestamptz,p_timezone text,
 p_duration_minutes integer,p_interview_mode text,p_meeting_url text,p_location text,p_invitation_message text
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE v_user uuid:=(SELECT auth.uid()); v_job_id uuid; v_company_id uuid; v_candidate_id uuid;
 v_job_title text; v_company_name text; v_interview_id uuid; v_old_status text;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION 'Login required'; END IF;
 IF p_system NOT IN ('private','international') THEN RAISE EXCEPTION 'Invalid job system'; END IF;
 IF p_scheduled_at IS NULL OR p_scheduled_at<=now() THEN RAISE EXCEPTION 'Interview date and time must be in the future'; END IF;
 IF p_timezone IS NULL OR NOT EXISTS(SELECT 1 FROM pg_catalog.pg_timezone_names WHERE name=p_timezone) THEN RAISE EXCEPTION 'Select a valid IANA time zone'; END IF;
 IF p_duration_minutes IS NULL OR p_duration_minutes NOT BETWEEN 10 AND 480 THEN RAISE EXCEPTION 'Interview duration must be between 10 and 480 minutes'; END IF;
 IF p_interview_mode NOT IN ('online','in_person','phone') THEN RAISE EXCEPTION 'Invalid interview mode'; END IF;
 IF length(btrim(coalesce(p_interview_title,''))) NOT BETWEEN 2 AND 180 THEN RAISE EXCEPTION 'Enter a valid interview title'; END IF;
 IF length(coalesce(p_meeting_url,''))>1000 OR length(coalesce(p_location,''))>1000 OR length(coalesce(p_invitation_message,''))>8000 THEN RAISE EXCEPTION 'Interview details exceed the allowed length'; END IF;
 IF p_interview_mode='online' AND coalesce(p_meeting_url,'') !~* '^https://[^[:space:]]+$' THEN RAISE EXCEPTION 'Online interviews require a valid HTTPS meeting link'; END IF;
 IF p_interview_mode='in_person' AND length(btrim(coalesce(p_location,'')))=0 THEN RAISE EXCEPTION 'Enter the interview venue address'; END IF;
 IF p_system='private' THEN
  SELECT a.job_id,a.candidate_id,j.company_id,j.job_title,c.company_name,a.status INTO v_job_id,v_candidate_id,v_company_id,v_job_title,v_company_name,v_old_status
  FROM public.private_job_applications a JOIN public.private_jobs j ON j.id=a.job_id JOIN public.companies c ON c.id=j.company_id
  WHERE a.id=p_application_id AND c.verification_status='verified' FOR UPDATE OF a;
 ELSE
  SELECT a.job_id,a.candidate_id,j.company_id,j.job_title,c.company_name,a.status INTO v_job_id,v_candidate_id,v_company_id,v_job_title,v_company_name,v_old_status
  FROM public.international_job_applications a JOIN public.international_jobs j ON j.id=a.job_id JOIN public.companies c ON c.id=j.company_id
  WHERE a.id=p_application_id AND j.job_sector='private' AND c.verification_status='verified' FOR UPDATE OF a;
 END IF;
 IF NOT FOUND OR v_company_id IS NULL THEN RAISE EXCEPTION 'Company-managed application not found'; END IF;
 IF v_old_status NOT IN ('applied','under_review','shortlisted','interview') THEN RAISE EXCEPTION 'This application is not active for interview scheduling'; END IF;
 IF NOT (EXISTS(SELECT 1 FROM public.company_members cm WHERE cm.company_id=v_company_id AND cm.user_id=v_user AND cm.member_status='active' AND cm.member_role IN ('owner','hr_manager','recruiter'))
  OR EXISTS(SELECT 1 FROM public.companies c WHERE c.id=v_company_id AND c.owner_user_id=v_user)) THEN
  RAISE EXCEPTION 'You are not authorized to schedule interviews for this company';
 END IF;
 IF p_system='private' THEN
  INSERT INTO public.private_job_interview_invitations(application_id,job_id,company_id,candidate_id,invited_by,interview_title,scheduled_at,timezone,duration_minutes,interview_mode,meeting_url,location,invitation_message)
  VALUES(p_application_id,v_job_id,v_company_id,v_candidate_id,v_user,btrim(p_interview_title),p_scheduled_at,p_timezone,p_duration_minutes,p_interview_mode,nullif(btrim(p_meeting_url),''),nullif(btrim(p_location),''),coalesce(p_invitation_message,'')) RETURNING id INTO v_interview_id;
  INSERT INTO public.private_job_interview_history(interview_id,new_status,changed_by,change_note) VALUES(v_interview_id,'pending',v_user,'Interview invitation sent');
 ELSE
  INSERT INTO public.international_job_interview_invitations(application_id,job_id,company_id,candidate_id,invited_by,interview_title,scheduled_at,timezone,duration_minutes,interview_mode,meeting_url,location,invitation_message)
  VALUES(p_application_id,v_job_id,v_company_id,v_candidate_id,v_user,btrim(p_interview_title),p_scheduled_at,p_timezone,p_duration_minutes,p_interview_mode,nullif(btrim(p_meeting_url),''),nullif(btrim(p_location),''),coalesce(p_invitation_message,'')) RETURNING id INTO v_interview_id;
  INSERT INTO public.international_job_interview_history(interview_id,new_status,changed_by,change_note) VALUES(v_interview_id,'pending',v_user,'Interview invitation sent');
 END IF;
 INSERT INTO public.tc_notifications(user_id,notification_type,title,body,related_application_id,related_interview_id)
 VALUES(v_candidate,'interview_invitation',CASE WHEN p_system='private' THEN 'Private Job Interview Invitation' ELSE 'International Job Interview Invitation' END,
  coalesce(v_company_name,'Company')||' — '||coalesce(v_job_title,'Job')||' — '||btrim(p_interview_title)||' scheduled for '||
  to_char(p_scheduled_at AT TIME ZONE p_timezone,'DD Mon YYYY, HH12:MI AM')||' ('||p_timezone||').',p_application_id,v_interview_id);
 RETURN v_interview_id;
END;
$$;
REVOKE ALL ON FUNCTION private.tc_create_independent_interview(text,uuid,text,timestamptz,text,integer,text,text,text,text) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.tc_respond_independent_interview(p_system text,p_interview_id uuid,p_response text,p_response_note text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE v_user uuid:=(SELECT auth.uid()); v_candidate uuid; v_company uuid; v_application uuid; v_job_title text; v_company_name text; v_status text; v_scheduled timestamptz;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION 'Login required'; END IF;
 IF p_response NOT IN ('accepted','declined') THEN RAISE EXCEPTION 'Invalid interview response'; END IF;
 IF length(coalesce(p_response_note,''))>2000 THEN RAISE EXCEPTION 'Response note is too long'; END IF;
 IF p_system='private' THEN
  SELECT i.candidate_id,i.company_id,i.application_id,j.job_title,c.company_name,i.status,i.scheduled_at INTO v_candidate,v_company,v_application,v_job_title,v_company_name,v_status,v_scheduled
  FROM public.private_job_interview_invitations i JOIN public.private_jobs j ON j.id=i.job_id JOIN public.companies c ON c.id=i.company_id WHERE i.id=p_interview_id FOR UPDATE OF i;
 ELSIF p_system='international' THEN
  SELECT i.candidate_id,i.company_id,i.application_id,j.job_title,c.company_name,i.status,i.scheduled_at INTO v_candidate,v_company,v_application,v_job_title,v_company_name,v_status,v_scheduled
  FROM public.international_job_interview_invitations i JOIN public.international_jobs j ON j.id=i.job_id JOIN public.companies c ON c.id=i.company_id WHERE i.id=p_interview_id FOR UPDATE OF i;
 ELSE RAISE EXCEPTION 'Invalid job system'; END IF;
 IF NOT FOUND OR v_candidate<>v_user THEN RAISE EXCEPTION 'Interview invitation not found'; END IF;
 IF v_status<>'pending' THEN RAISE EXCEPTION 'This invitation has already been answered or closed'; END IF;
 IF v_scheduled<=now() THEN RAISE EXCEPTION 'This interview time has passed'; END IF;
 IF p_system='private' THEN
  UPDATE public.private_job_interview_invitations SET status=p_response,candidate_response_note=coalesce(p_response_note,''),candidate_response_at=now(),updated_at=now() WHERE id=p_interview_id;
  INSERT INTO public.private_job_interview_history(interview_id,old_status,new_status,changed_by,change_note) VALUES(p_interview_id,'pending',p_response,v_user,coalesce(nullif(p_response_note,''),'Candidate response'));
 ELSE
  UPDATE public.international_job_interview_invitations SET status=p_response,candidate_response_note=coalesce(p_response_note,''),candidate_response_at=now(),updated_at=now() WHERE id=p_interview_id;
  INSERT INTO public.international_job_interview_history(interview_id,old_status,new_status,changed_by,change_note) VALUES(p_interview_id,'pending',p_response,v_user,coalesce(nullif(p_response_note,''),'Candidate response'));
 END IF;
 INSERT INTO public.tc_notifications(user_id,notification_type,title,body,related_application_id,related_interview_id)
 SELECT cm.user_id,'interview_response',CASE WHEN p_response='accepted' THEN 'Candidate accepted an interview invitation' ELSE 'Candidate declined an interview invitation' END,
  coalesce(v_job_title,'Job')||' — Candidate response: '||upper(p_response)||CASE WHEN coalesce(p_response_note,'')<>'' THEN ' — '||p_response_note ELSE '' END,v_application,p_interview_id
 FROM public.company_members cm WHERE cm.company_id=v_company AND cm.member_status='active' AND cm.member_role IN ('owner','hr_manager','recruiter');
 INSERT INTO public.tc_notifications(user_id,notification_type,title,body,related_application_id,related_interview_id)
 SELECT c.owner_user_id,'interview_response',CASE WHEN p_response='accepted' THEN 'Candidate accepted an interview invitation' ELSE 'Candidate declined an interview invitation' END,
  coalesce(v_job_title,'Job')||' — Candidate response: '||upper(p_response),v_application,p_interview_id
 FROM public.companies c WHERE c.id=v_company AND c.owner_user_id IS NOT NULL
 AND NOT EXISTS(SELECT 1 FROM public.company_members cm WHERE cm.company_id=v_company AND cm.user_id=c.owner_user_id AND cm.member_status='active' AND cm.member_role IN ('owner','hr_manager','recruiter'));
 RETURN p_response;
END;
$$;
REVOKE ALL ON FUNCTION private.tc_respond_independent_interview(text,uuid,text,text) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.tc_cancel_independent_interview(p_system text,p_interview_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE v_user uuid:=(SELECT auth.uid()); v_company uuid; v_candidate uuid; v_application uuid; v_title text; v_status text;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION 'Login required'; END IF;
 IF p_system='private' THEN
  SELECT company_id,candidate_id,application_id,interview_title,status INTO v_company,v_candidate,v_application,v_title,v_status FROM public.private_job_interview_invitations WHERE id=p_interview_id FOR UPDATE;
 ELSIF p_system='international' THEN
  SELECT company_id,candidate_id,application_id,interview_title,status INTO v_company,v_candidate,v_application,v_title,v_status FROM public.international_job_interview_invitations WHERE id=p_interview_id FOR UPDATE;
 ELSE RAISE EXCEPTION 'Invalid job system'; END IF;
 IF NOT FOUND THEN RAISE EXCEPTION 'Interview invitation not found'; END IF;
 IF NOT (EXISTS(SELECT 1 FROM public.company_members cm WHERE cm.company_id=v_company AND cm.user_id=v_user AND cm.member_status='active' AND cm.member_role IN ('owner','hr_manager','recruiter'))
  OR EXISTS(SELECT 1 FROM public.companies c WHERE c.id=v_company AND c.owner_user_id=v_user)) THEN RAISE EXCEPTION 'You are not authorized to cancel this interview'; END IF;
 IF v_status NOT IN ('pending','accepted') THEN RAISE EXCEPTION 'This interview cannot be cancelled'; END IF;
 IF p_system='private' THEN
  UPDATE public.private_job_interview_invitations SET status='cancelled',updated_at=now() WHERE id=p_interview_id;
  INSERT INTO public.private_job_interview_history(interview_id,old_status,new_status,changed_by,change_note) VALUES(p_interview_id,v_status,'cancelled',v_user,'Cancelled by employer');
 ELSE
  UPDATE public.international_job_interview_invitations SET status='cancelled',updated_at=now() WHERE id=p_interview_id;
  INSERT INTO public.international_job_interview_history(interview_id,old_status,new_status,changed_by,change_note) VALUES(p_interview_id,v_status,'cancelled',v_user,'Cancelled by employer');
 END IF;
 INSERT INTO public.tc_notifications(user_id,notification_type,title,body,related_application_id,related_interview_id)
 VALUES(v_candidate,'interview_invitation','Interview Invitation Cancelled','The employer cancelled: '||coalesce(v_title,'Interview'),v_application,p_interview_id);
 RETURN true;
END;
$$;
REVOKE ALL ON FUNCTION private.tc_cancel_independent_interview(text,uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.tc_company_send_private_interview_invitation(p_application_id uuid,p_interview_title text,p_scheduled_at timestamptz,p_timezone text,p_duration_minutes integer,p_interview_mode text,p_meeting_url text,p_location text,p_invitation_message text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$ BEGIN RETURN private.tc_create_independent_interview('private',p_application_id,p_interview_title,p_scheduled_at,p_timezone,p_duration_minutes,p_interview_mode,p_meeting_url,p_location,p_invitation_message); END $$;
CREATE OR REPLACE FUNCTION public.tc_company_send_international_interview_invitation(p_application_id uuid,p_interview_title text,p_scheduled_at timestamptz,p_timezone text,p_duration_minutes integer,p_interview_mode text,p_meeting_url text,p_location text,p_invitation_message text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$ BEGIN RETURN private.tc_create_independent_interview('international',p_application_id,p_interview_title,p_scheduled_at,p_timezone,p_duration_minutes,p_interview_mode,p_meeting_url,p_location,p_invitation_message); END $$;
CREATE OR REPLACE FUNCTION public.tc_candidate_respond_private_interview(p_interview_id uuid,p_response text,p_response_note text DEFAULT '')
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$ BEGIN RETURN private.tc_respond_independent_interview('private',p_interview_id,p_response,p_response_note); END $$;
CREATE OR REPLACE FUNCTION public.tc_candidate_respond_international_interview(p_interview_id uuid,p_response text,p_response_note text DEFAULT '')
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$ BEGIN RETURN private.tc_respond_independent_interview('international',p_interview_id,p_response,p_response_note); END $$;
CREATE OR REPLACE FUNCTION public.tc_company_cancel_private_interview(p_interview_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$ BEGIN RETURN private.tc_cancel_independent_interview('private',p_interview_id); END $$;
CREATE OR REPLACE FUNCTION public.tc_company_cancel_international_interview(p_interview_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$ BEGIN RETURN private.tc_cancel_independent_interview('international',p_interview_id); END $$;

REVOKE ALL ON FUNCTION public.tc_company_send_private_interview_invitation(uuid,text,timestamptz,text,integer,text,text,text,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.tc_company_send_international_interview_invitation(uuid,text,timestamptz,text,integer,text,text,text,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.tc_candidate_respond_private_interview(uuid,text,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.tc_candidate_respond_international_interview(uuid,text,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.tc_company_cancel_private_interview(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.tc_company_cancel_international_interview(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.tc_company_send_private_interview_invitation(uuid,text,timestamptz,text,integer,text,text,text,text),
 public.tc_company_send_international_interview_invitation(uuid,text,timestamptz,text,integer,text,text,text,text),
 public.tc_candidate_respond_private_interview(uuid,text,text),
 public.tc_candidate_respond_international_interview(uuid,text,text),
 public.tc_company_cancel_private_interview(uuid),public.tc_company_cancel_international_interview(uuid) TO authenticated;


-- Keep exposed wrappers SECURITY INVOKER; privileged checks stay in the non-exposed private schema.
GRANT USAGE ON SCHEMA private TO authenticated;
GRANT EXECUTE ON FUNCTION private.tc_create_independent_interview(text,uuid,text,timestamptz,text,integer,text,text,text,text),
 private.tc_respond_independent_interview(text,uuid,text,text),
 private.tc_cancel_independent_interview(text,uuid) TO authenticated;
ALTER FUNCTION public.tc_company_send_private_interview_invitation(uuid,text,timestamptz,text,integer,text,text,text,text) SECURITY INVOKER;
ALTER FUNCTION public.tc_company_send_international_interview_invitation(uuid,text,timestamptz,text,integer,text,text,text,text) SECURITY INVOKER;
ALTER FUNCTION public.tc_candidate_respond_private_interview(uuid,text,text) SECURITY INVOKER;
ALTER FUNCTION public.tc_candidate_respond_international_interview(uuid,text,text) SECURITY INVOKER;
ALTER FUNCTION public.tc_company_cancel_private_interview(uuid) SECURITY INVOKER;
ALTER FUNCTION public.tc_company_cancel_international_interview(uuid) SECURITY INVOKER;
