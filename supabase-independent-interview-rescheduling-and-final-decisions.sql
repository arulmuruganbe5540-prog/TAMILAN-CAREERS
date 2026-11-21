-- TAMILAN CAREERS: independent Private / International interview rescheduling and final decisions.
-- Apply after supabase-independent-interview-management.sql and supabase-independent-applications-and-reports.sql.

CREATE TABLE IF NOT EXISTS public.private_job_interview_reschedule_proposals (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 interview_id uuid NOT NULL REFERENCES public.private_job_interview_invitations(id) ON DELETE RESTRICT,
 application_id uuid NOT NULL REFERENCES public.private_job_applications(id) ON DELETE RESTRICT,
 candidate_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE RESTRICT,
 proposed_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 proposal_type text NOT NULL CHECK (proposal_type IN ('employer_reschedule','candidate_alternative')),
 proposed_at timestamptz NOT NULL, timezone text NOT NULL,
 duration_minutes integer NOT NULL CHECK (duration_minutes BETWEEN 10 AND 480),
 interview_mode text NOT NULL CHECK (interview_mode IN ('online','in_person','phone')),
 meeting_url text, location text, message text NOT NULL DEFAULT '',
 status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','declined','cancelled')),
 response_note text NOT NULL DEFAULT '', responded_at timestamptz, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.international_job_interview_reschedule_proposals (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 interview_id uuid NOT NULL REFERENCES public.international_job_interview_invitations(id) ON DELETE RESTRICT,
 application_id uuid NOT NULL REFERENCES public.international_job_applications(id) ON DELETE RESTRICT,
 candidate_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE RESTRICT,
 proposed_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 proposal_type text NOT NULL CHECK (proposal_type IN ('employer_reschedule','candidate_alternative')),
 proposed_at timestamptz NOT NULL, timezone text NOT NULL,
 duration_minutes integer NOT NULL CHECK (duration_minutes BETWEEN 10 AND 480),
 interview_mode text NOT NULL CHECK (interview_mode IN ('online','in_person','phone')),
 meeting_url text, location text, message text NOT NULL DEFAULT '',
 status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','declined','cancelled')),
 response_note text NOT NULL DEFAULT '', responded_at timestamptz, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS private_one_pending_interview_proposal ON public.private_job_interview_reschedule_proposals(interview_id) WHERE status='pending';
CREATE UNIQUE INDEX IF NOT EXISTS international_one_pending_interview_proposal ON public.international_job_interview_reschedule_proposals(interview_id) WHERE status='pending';
ALTER TABLE public.private_job_interview_reschedule_proposals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.international_job_interview_reschedule_proposals ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS private_interview_proposals_read_authorized ON public.private_job_interview_reschedule_proposals;
CREATE POLICY private_interview_proposals_read_authorized ON public.private_job_interview_reschedule_proposals FOR SELECT TO authenticated USING (
 candidate_id=(SELECT auth.uid())
 OR EXISTS(SELECT 1 FROM public.company_members cm WHERE cm.company_id=public.private_job_interview_reschedule_proposals.company_id AND cm.user_id=(SELECT auth.uid()) AND cm.member_status='active' AND cm.member_role IN ('owner','hr_manager','recruiter'))
 OR EXISTS(SELECT 1 FROM public.companies c WHERE c.id=public.private_job_interview_reschedule_proposals.company_id AND c.owner_user_id=(SELECT auth.uid()))
 OR (SELECT private.is_super_admin())
);
DROP POLICY IF EXISTS international_interview_proposals_read_authorized ON public.international_job_interview_reschedule_proposals;
CREATE POLICY international_interview_proposals_read_authorized ON public.international_job_interview_reschedule_proposals FOR SELECT TO authenticated USING (
 candidate_id=(SELECT auth.uid())
 OR EXISTS(SELECT 1 FROM public.company_members cm WHERE cm.company_id=public.international_job_interview_reschedule_proposals.company_id AND cm.user_id=(SELECT auth.uid()) AND cm.member_status='active' AND cm.member_role IN ('owner','hr_manager','recruiter'))
 OR EXISTS(SELECT 1 FROM public.companies c WHERE c.id=public.international_job_interview_reschedule_proposals.company_id AND c.owner_user_id=(SELECT auth.uid()))
 OR (SELECT private.is_super_admin())
);
REVOKE ALL ON public.private_job_interview_reschedule_proposals,public.international_job_interview_reschedule_proposals FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.private_job_interview_reschedule_proposals,public.international_job_interview_reschedule_proposals TO authenticated;

ALTER TABLE public.private_job_interview_history ADD COLUMN IF NOT EXISTS old_schedule jsonb;
ALTER TABLE public.private_job_interview_history ADD COLUMN IF NOT EXISTS new_schedule jsonb;
ALTER TABLE public.international_job_interview_history ADD COLUMN IF NOT EXISTS old_schedule jsonb;
ALTER TABLE public.international_job_interview_history ADD COLUMN IF NOT EXISTS new_schedule jsonb;

CREATE OR REPLACE FUNCTION private.tc_cancel_independent_interviews_on_application_close()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_row record; v_actor uuid:=(SELECT auth.uid());
BEGIN
 IF NEW.status IS NOT DISTINCT FROM OLD.status OR NEW.status NOT IN ('withdrawn','rejected','selected') THEN RETURN NEW; END IF;
 IF TG_TABLE_NAME='private_job_applications' THEN
  UPDATE public.private_job_interview_reschedule_proposals SET status='cancelled',responded_at=now(),response_note='Application finalised' WHERE application_id=NEW.id AND status='pending';
  FOR v_row IN SELECT id,candidate_id,application_id,interview_title,status FROM public.private_job_interview_invitations WHERE application_id=NEW.id AND status IN ('pending','accepted') FOR UPDATE LOOP
   UPDATE public.private_job_interview_invitations SET status='cancelled',updated_at=now() WHERE id=v_row.id;
   INSERT INTO public.private_job_interview_history(interview_id,old_status,new_status,changed_by,change_note) VALUES(v_row.id,v_row.status,'cancelled',v_actor,'Application was '||NEW.status);
   INSERT INTO public.tc_notifications(user_id,notification_type,title,body,related_application_id,related_interview_id)
   VALUES(v_row.candidate_id,'interview_invitation','Interview Invitation Closed','The interview "'||v_row.interview_title||'" was cancelled because the application was '||NEW.status||'.',v_row.application_id,v_row.id);
  END LOOP;
 ELSIF TG_TABLE_NAME='international_job_applications' THEN
  UPDATE public.international_job_interview_reschedule_proposals SET status='cancelled',responded_at=now(),response_note='Application finalised' WHERE application_id=NEW.id AND status='pending';
  FOR v_row IN SELECT id,candidate_id,application_id,interview_title,status FROM public.international_job_interview_invitations WHERE application_id=NEW.id AND status IN ('pending','accepted') FOR UPDATE LOOP
   UPDATE public.international_job_interview_invitations SET status='cancelled',updated_at=now() WHERE id=v_row.id;
   INSERT INTO public.international_job_interview_history(interview_id,old_status,new_status,changed_by,change_note) VALUES(v_row.id,v_row.status,'cancelled',v_actor,'Application was '||NEW.status);
   INSERT INTO public.tc_notifications(user_id,notification_type,title,body,related_application_id,related_interview_id)
   VALUES(v_row.candidate_id,'interview_invitation','International Interview Invitation Closed','The interview "'||v_row.interview_title||'" was cancelled because the application was '||NEW.status||'.',v_row.application_id,v_row.id);
  END LOOP;
 END IF;
 RETURN NEW;
END;
$function$


CREATE OR REPLACE FUNCTION private.tc_company_finalise_independent_application(p_system text, p_application_id uuid, p_company_id uuid, p_new_status text, p_note text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_user uuid:=(SELECT auth.uid()); v_old text; v_candidate uuid; v_job_company uuid; v_title text;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION 'Login required'; END IF;
 IF p_system NOT IN ('private','international') OR p_new_status NOT IN ('selected','rejected') THEN RAISE EXCEPTION 'Invalid final decision'; END IF;
 IF length(coalesce(p_note,''))>2000 THEN RAISE EXCEPTION 'Decision note is too long'; END IF;
 IF NOT (EXISTS(SELECT 1 FROM public.company_members cm WHERE cm.company_id=p_company_id AND cm.user_id=v_user AND cm.member_status='active' AND cm.member_role IN ('owner','hr_manager','recruiter'))
  OR EXISTS(SELECT 1 FROM public.companies c WHERE c.id=p_company_id AND c.owner_user_id=v_user)) THEN RAISE EXCEPTION 'Company application-management permission required'; END IF;
 IF p_system='private' THEN
  SELECT a.status,a.candidate_id,j.company_id,j.job_title INTO v_old,v_candidate,v_job_company,v_title
  FROM public.private_job_applications a JOIN public.private_jobs j ON j.id=a.job_id
  WHERE a.id=p_application_id AND j.company_id=p_company_id FOR UPDATE OF a;
 ELSE
  SELECT a.status,a.candidate_id,j.company_id,j.job_title INTO v_old,v_candidate,v_job_company,v_title
  FROM public.international_job_applications a JOIN public.international_jobs j ON j.id=a.job_id
  WHERE a.id=p_application_id AND j.company_id=p_company_id AND j.job_sector='private' FOR UPDATE OF a;
 END IF;
 IF NOT FOUND OR v_job_company IS NULL THEN RAISE EXCEPTION 'Application not found for this company'; END IF;
 IF v_old IN ('selected','rejected','withdrawn') THEN RAISE EXCEPTION 'This application already has a final status'; END IF;
 IF v_old NOT IN ('applied','under_review','shortlisted','interview','offer_sent') THEN RAISE EXCEPTION 'Application cannot be finalised from its current status'; END IF;
 IF p_system='private' THEN
  UPDATE public.private_job_applications SET status=p_new_status,updated_at=now() WHERE id=p_application_id;
  UPDATE public.private_job_interview_reschedule_proposals SET status='cancelled',responded_at=now(),response_note='Application finalised' WHERE application_id=p_application_id AND status='pending';
 ELSE
  UPDATE public.international_job_applications SET status=p_new_status,updated_at=now() WHERE id=p_application_id;
  UPDATE public.international_job_interview_reschedule_proposals SET status='cancelled',responded_at=now(),response_note='Application finalised' WHERE application_id=p_application_id AND status='pending';
 END IF;
 INSERT INTO public.tc_notifications(user_id,notification_type,title,body,related_application_id)
 VALUES(v_candidate,'application_status',CASE WHEN p_new_status='selected' THEN 'Congratulations — you have been selected' ELSE 'Application decision updated' END,
  coalesce(v_title,'Job')||' — '||CASE WHEN p_new_status='selected' THEN 'Final selection confirmed' ELSE 'Your application was not selected' END||
  CASE WHEN coalesce(p_note,'')<>'' THEN ' — '||p_note ELSE '' END,p_application_id);
 RETURN p_new_status;
END;
$function$


CREATE OR REPLACE FUNCTION private.tc_create_interview_schedule_proposal(p_system text, p_interview_id uuid, p_proposal_type text, p_scheduled_at timestamp with time zone, p_timezone text, p_duration_minutes integer, p_interview_mode text, p_meeting_url text, p_location text, p_message text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
 v_user uuid:=(SELECT auth.uid()); v_candidate uuid; v_company uuid; v_application uuid;
 v_status text; v_title text; v_id uuid; v_proposal_type text:=p_proposal_type;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION 'Login required'; END IF;
 IF p_system NOT IN ('private','international') THEN RAISE EXCEPTION 'Invalid job system'; END IF;
 IF p_proposal_type NOT IN ('employer_reschedule','candidate_alternative') THEN RAISE EXCEPTION 'Invalid proposal type'; END IF;
 IF p_scheduled_at IS NULL OR p_scheduled_at<=now() THEN RAISE EXCEPTION 'Proposed interview time must be in the future'; END IF;
 IF p_timezone IS NULL OR NOT EXISTS(SELECT 1 FROM pg_catalog.pg_timezone_names WHERE name=p_timezone) THEN RAISE EXCEPTION 'Select a valid IANA time zone'; END IF;
 IF p_duration_minutes IS NULL OR p_duration_minutes NOT BETWEEN 10 AND 480 THEN RAISE EXCEPTION 'Duration must be between 10 and 480 minutes'; END IF;
 IF p_interview_mode NOT IN ('online','in_person','phone') THEN RAISE EXCEPTION 'Invalid interview mode'; END IF;
 IF length(coalesce(p_message,''))>2000 OR length(coalesce(p_location,''))>1000 OR length(coalesce(p_meeting_url,''))>1000 THEN RAISE EXCEPTION 'Proposal details are too long'; END IF;
 IF p_interview_mode='online' AND coalesce(p_meeting_url,'') !~* '^https://[^[:space:]]+$' THEN RAISE EXCEPTION 'Online interviews require an HTTPS meeting link'; END IF;
 IF p_interview_mode='in_person' AND length(btrim(coalesce(p_location,'')))=0 THEN RAISE EXCEPTION 'Enter the interview venue'; END IF;
 IF p_system='private' THEN
  SELECT i.candidate_id,i.company_id,i.application_id,i.status,i.interview_title
   INTO v_candidate,v_company,v_application,v_status,v_title
   FROM public.private_job_interview_invitations i
   JOIN public.private_job_applications a ON a.id=i.application_id
   WHERE i.id=p_interview_id AND a.status IN ('applied','under_review','shortlisted','interview') FOR UPDATE OF i,a;
 ELSE
  SELECT i.candidate_id,i.company_id,i.application_id,i.status,i.interview_title
   INTO v_candidate,v_company,v_application,v_status,v_title
   FROM public.international_job_interview_invitations i
   JOIN public.international_job_applications a ON a.id=i.application_id
   WHERE i.id=p_interview_id AND a.status IN ('applied','under_review','shortlisted','interview') FOR UPDATE OF i,a;
 END IF;
 IF NOT FOUND OR v_status NOT IN ('pending','accepted') THEN RAISE EXCEPTION 'An active interview invitation is required'; END IF;
 IF v_proposal_type='employer_reschedule' THEN
  IF NOT (EXISTS(SELECT 1 FROM public.company_members cm WHERE cm.company_id=v_company AND cm.user_id=v_user AND cm.member_status='active' AND cm.member_role IN ('owner','hr_manager','recruiter'))
    OR EXISTS(SELECT 1 FROM public.companies c WHERE c.id=v_company AND c.owner_user_id=v_user)) THEN RAISE EXCEPTION 'Company interview-management permission required'; END IF;
 ELSE
  IF v_candidate<>v_user THEN RAISE EXCEPTION 'Only the candidate can propose an alternative date'; END IF;
  IF v_status<>'accepted' THEN RAISE EXCEPTION 'Accept the interview invitation before proposing another date'; END IF;
 END IF;
 IF p_system='private' THEN
  IF EXISTS(SELECT 1 FROM public.private_job_interview_reschedule_proposals WHERE interview_id=p_interview_id AND status='pending') THEN RAISE EXCEPTION 'A schedule proposal is already awaiting a response'; END IF;
  INSERT INTO public.private_job_interview_reschedule_proposals(interview_id,application_id,candidate_id,company_id,proposed_by,proposal_type,proposed_at,timezone,duration_minutes,interview_mode,meeting_url,location,message)
  VALUES(p_interview_id,v_application,v_candidate,v_company,v_user,v_proposal_type,p_scheduled_at,p_timezone,p_duration_minutes,p_interview_mode,nullif(btrim(p_meeting_url),''),nullif(btrim(p_location),''),coalesce(p_message,'')) RETURNING id INTO v_id;
  INSERT INTO public.private_job_interview_history(interview_id,old_status,new_status,changed_by,change_note)
  VALUES(p_interview_id,v_status,v_status,v_user,CASE WHEN v_proposal_type='employer_reschedule' THEN 'Employer proposed a new schedule' ELSE 'Candidate proposed an alternative schedule' END);
 ELSE
  IF EXISTS(SELECT 1 FROM public.international_job_interview_reschedule_proposals WHERE interview_id=p_interview_id AND status='pending') THEN RAISE EXCEPTION 'A schedule proposal is already awaiting a response'; END IF;
  INSERT INTO public.international_job_interview_reschedule_proposals(interview_id,application_id,candidate_id,company_id,proposed_by,proposal_type,proposed_at,timezone,duration_minutes,interview_mode,meeting_url,location,message)
  VALUES(p_interview_id,v_application,v_candidate,v_company,v_user,v_proposal_type,p_scheduled_at,p_timezone,p_duration_minutes,p_interview_mode,nullif(btrim(p_meeting_url),''),nullif(btrim(p_location),''),coalesce(p_message,'')) RETURNING id INTO v_id;
  INSERT INTO public.international_job_interview_history(interview_id,old_status,new_status,changed_by,change_note)
  VALUES(p_interview_id,v_status,v_status,v_user,CASE WHEN v_proposal_type='employer_reschedule' THEN 'Employer proposed a new schedule' ELSE 'Candidate proposed an alternative schedule' END);
 END IF;
 IF v_proposal_type='employer_reschedule' THEN
  INSERT INTO public.tc_notifications(user_id,notification_type,title,body,related_application_id,related_interview_id)
  VALUES(v_candidate,'interview_reschedule','Employer proposed a new interview time','A new interview time has been proposed for '||coalesce(v_title,'your interview')||'. Review it in Notifications.',v_application,p_interview_id);
 ELSE
  INSERT INTO public.tc_notifications(user_id,notification_type,title,body,related_application_id,related_interview_id)
  SELECT cm.user_id,'interview_reschedule','Candidate proposed another interview time','The candidate proposed a new time for '||coalesce(v_title,'the interview')||'. Review it in Job Applicants.',v_application,p_interview_id
  FROM public.company_members cm WHERE cm.company_id=v_company AND cm.member_status='active' AND cm.member_role IN ('owner','hr_manager','recruiter');
  INSERT INTO public.tc_notifications(user_id,notification_type,title,body,related_application_id,related_interview_id)
  SELECT c.owner_user_id,'interview_reschedule','Candidate proposed another interview time','The candidate proposed a new time for '||coalesce(v_title,'the interview')||'. Review it in Job Applicants.',v_application,p_interview_id
  FROM public.companies c WHERE c.id=v_company AND c.owner_user_id IS NOT NULL
  AND NOT EXISTS(SELECT 1 FROM public.company_members cm WHERE cm.company_id=v_company AND cm.user_id=c.owner_user_id AND cm.member_status='active' AND cm.member_role IN ('owner','hr_manager','recruiter'));
 END IF;
 RETURN v_id;
END;
$function$


CREATE OR REPLACE FUNCTION private.tc_log_independent_interview_schedule_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_actor uuid:=(SELECT auth.uid());
 v_old jsonb; v_new jsonb;
BEGIN
 IF OLD.scheduled_at IS NOT DISTINCT FROM NEW.scheduled_at
  AND OLD.timezone IS NOT DISTINCT FROM NEW.timezone
  AND OLD.duration_minutes IS NOT DISTINCT FROM NEW.duration_minutes
  AND OLD.interview_mode IS NOT DISTINCT FROM NEW.interview_mode
  AND OLD.meeting_url IS NOT DISTINCT FROM NEW.meeting_url
  AND OLD.location IS NOT DISTINCT FROM NEW.location THEN RETURN NEW; END IF;
 v_old:=jsonb_build_object('scheduled_at',OLD.scheduled_at,'timezone',OLD.timezone,'duration_minutes',OLD.duration_minutes,'interview_mode',OLD.interview_mode,'meeting_url',OLD.meeting_url,'location',OLD.location);
 v_new:=jsonb_build_object('scheduled_at',NEW.scheduled_at,'timezone',NEW.timezone,'duration_minutes',NEW.duration_minutes,'interview_mode',NEW.interview_mode,'meeting_url',NEW.meeting_url,'location',NEW.location);
 IF TG_TABLE_NAME='private_job_interview_invitations' THEN
  INSERT INTO public.private_job_interview_history(interview_id,old_status,new_status,changed_by,change_note,old_schedule,new_schedule)
  VALUES(NEW.id,NEW.status,NEW.status,v_actor,'Interview schedule changed after proposal acceptance',v_old,v_new);
 ELSE
  INSERT INTO public.international_job_interview_history(interview_id,old_status,new_status,changed_by,change_note,old_schedule,new_schedule)
  VALUES(NEW.id,NEW.status,NEW.status,v_actor,'Interview schedule changed after proposal acceptance',v_old,v_new);
 END IF;
 RETURN NEW;
END;
$function$


CREATE OR REPLACE FUNCTION private.tc_respond_interview_schedule_proposal(p_system text, p_proposal_id uuid, p_response text, p_response_note text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_user uuid:=(SELECT auth.uid()); v_candidate uuid; v_company uuid; v_interview uuid; v_application uuid;
 v_type text; v_status text; v_scheduled timestamptz; v_zone text; v_duration integer; v_mode text; v_url text; v_location text; v_message text; v_title text;
 v_current_status text;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION 'Login required'; END IF;
 IF p_system NOT IN ('private','international') OR p_response NOT IN ('accepted','declined') THEN RAISE EXCEPTION 'Invalid response'; END IF;
 IF length(coalesce(p_response_note,''))>2000 THEN RAISE EXCEPTION 'Response note is too long'; END IF;
 IF p_system='private' THEN
  SELECT p.candidate_id,p.company_id,p.interview_id,p.application_id,p.proposal_type,p.status,p.proposed_at,p.timezone,p.duration_minutes,p.interview_mode,p.meeting_url,p.location,p.message,i.interview_title,i.status
   INTO v_candidate,v_company,v_interview,v_application,v_type,v_status,v_scheduled,v_zone,v_duration,v_mode,v_url,v_location,v_message,v_title,v_current_status
   FROM public.private_job_interview_reschedule_proposals p JOIN public.private_job_interview_invitations i ON i.id=p.interview_id
   WHERE p.id=p_proposal_id FOR UPDATE OF p,i;
 ELSE
  SELECT p.candidate_id,p.company_id,p.interview_id,p.application_id,p.proposal_type,p.status,p.proposed_at,p.timezone,p.duration_minutes,p.interview_mode,p.meeting_url,p.location,p.message,i.interview_title,i.status
   INTO v_candidate,v_company,v_interview,v_application,v_type,v_status,v_scheduled,v_zone,v_duration,v_mode,v_url,v_location,v_message,v_title,v_current_status
   FROM public.international_job_interview_reschedule_proposals p JOIN public.international_job_interview_invitations i ON i.id=p.interview_id
   WHERE p.id=p_proposal_id FOR UPDATE OF p,i;
 END IF;
 IF NOT FOUND OR v_status<>'pending' OR v_current_status NOT IN ('pending','accepted') THEN RAISE EXCEPTION 'Pending schedule proposal not found'; END IF;
 IF (v_type='employer_reschedule' AND v_candidate<>v_user)
 OR (v_type='candidate_alternative' AND NOT (
   EXISTS(SELECT 1 FROM public.company_members cm WHERE cm.company_id=v_company AND cm.user_id=v_user AND cm.member_status='active' AND cm.member_role IN ('owner','hr_manager','recruiter'))
   OR EXISTS(SELECT 1 FROM public.companies c WHERE c.id=v_company AND c.owner_user_id=v_user)
 )) THEN RAISE EXCEPTION 'You are not authorized to respond to this proposal'; END IF;
 IF v_scheduled<=now() THEN RAISE EXCEPTION 'This proposed time has passed'; END IF;
 IF p_system='private' THEN
  UPDATE public.private_job_interview_reschedule_proposals SET status=p_response,response_note=coalesce(p_response_note,''),responded_at=now() WHERE id=p_proposal_id;
  IF p_response='accepted' THEN
   UPDATE public.private_job_interview_invitations SET scheduled_at=v_scheduled,timezone=v_zone,duration_minutes=v_duration,interview_mode=v_mode,meeting_url=v_url,location=v_location,invitation_message=CASE WHEN v_message<>'' THEN v_message ELSE invitation_message END,updated_at=now() WHERE id=v_interview;
   INSERT INTO public.private_job_interview_history(interview_id,old_status,new_status,changed_by,change_note) VALUES(v_interview,v_current_status,v_current_status,v_user,'Schedule proposal accepted; new time: '||to_char(v_scheduled AT TIME ZONE v_zone,'DD Mon YYYY HH12:MI AM')||' ('||v_zone||')');
  END IF;
 ELSE
  UPDATE public.international_job_interview_reschedule_proposals SET status=p_response,response_note=coalesce(p_response_note,''),responded_at=now() WHERE id=p_proposal_id;
  IF p_response='accepted' THEN
   UPDATE public.international_job_interview_invitations SET scheduled_at=v_scheduled,timezone=v_zone,duration_minutes=v_duration,interview_mode=v_mode,meeting_url=v_url,location=v_location,invitation_message=CASE WHEN v_message<>'' THEN v_message ELSE invitation_message END,updated_at=now() WHERE id=v_interview;
   INSERT INTO public.international_job_interview_history(interview_id,old_status,new_status,changed_by,change_note) VALUES(v_interview,v_current_status,v_current_status,v_user,'Schedule proposal accepted; new time: '||to_char(v_scheduled AT TIME ZONE v_zone,'DD Mon YYYY HH12:MI AM')||' ('||v_zone||')');
  END IF;
 END IF;
 IF v_type='employer_reschedule' THEN
  INSERT INTO public.tc_notifications(user_id,notification_type,title,body,related_application_id,related_interview_id)
  SELECT cm.user_id,'interview_reschedule',CASE WHEN p_response='accepted' THEN 'Candidate accepted the new interview time' ELSE 'Candidate declined the new interview time' END,
   coalesce(v_title,'Interview')||' — candidate '||p_response||CASE WHEN coalesce(p_response_note,'')<>'' THEN ': '||p_response_note ELSE '' END,v_application,v_interview
  FROM public.company_members cm WHERE cm.company_id=v_company AND cm.member_status='active' AND cm.member_role IN ('owner','hr_manager','recruiter');
  INSERT INTO public.tc_notifications(user_id,notification_type,title,body,related_application_id,related_interview_id)
  SELECT c.owner_user_id,'interview_reschedule',CASE WHEN p_response='accepted' THEN 'Candidate accepted the new interview time' ELSE 'Candidate declined the new interview time' END,
   coalesce(v_title,'Interview')||' — candidate '||p_response,v_application,v_interview
  FROM public.companies c WHERE c.id=v_company AND c.owner_user_id IS NOT NULL
  AND NOT EXISTS(SELECT 1 FROM public.company_members cm WHERE cm.company_id=v_company AND cm.user_id=c.owner_user_id AND cm.member_status='active' AND cm.member_role IN ('owner','hr_manager','recruiter'));
 ELSE
  INSERT INTO public.tc_notifications(user_id,notification_type,title,body,related_application_id,related_interview_id)
  VALUES(v_candidate,'interview_reschedule',CASE WHEN p_response='accepted' THEN 'Employer accepted your proposed interview time' ELSE 'Employer declined your proposed interview time' END,
   coalesce(v_title,'Interview')||' — employer '||p_response,v_application,v_interview);
 END IF;
 RETURN p_response;
END;
$function$


CREATE OR REPLACE FUNCTION public.tc_candidate_propose_international_interview_date(p_interview_id uuid, p_scheduled_at timestamp with time zone, p_timezone text, p_duration_minutes integer, p_interview_mode text, p_meeting_url text, p_location text, p_message text DEFAULT ''::text)
 RETURNS uuid
 LANGUAGE sql
 SET search_path TO ''
AS $function$ SELECT private.tc_create_interview_schedule_proposal('international',p_interview_id,'candidate_alternative',p_scheduled_at,p_timezone,p_duration_minutes,p_interview_mode,p_meeting_url,p_location,p_message) $function$


CREATE OR REPLACE FUNCTION public.tc_candidate_propose_private_interview_date(p_interview_id uuid, p_scheduled_at timestamp with time zone, p_timezone text, p_duration_minutes integer, p_interview_mode text, p_meeting_url text, p_location text, p_message text DEFAULT ''::text)
 RETURNS uuid
 LANGUAGE sql
 SET search_path TO ''
AS $function$ SELECT private.tc_create_interview_schedule_proposal('private',p_interview_id,'candidate_alternative',p_scheduled_at,p_timezone,p_duration_minutes,p_interview_mode,p_meeting_url,p_location,p_message) $function$


CREATE OR REPLACE FUNCTION public.tc_candidate_respond_international_interview_reschedule(p_proposal_id uuid, p_response text, p_response_note text DEFAULT ''::text)
 RETURNS text
 LANGUAGE sql
 SET search_path TO ''
AS $function$ SELECT private.tc_respond_interview_schedule_proposal('international',p_proposal_id,p_response,p_response_note) $function$


CREATE OR REPLACE FUNCTION public.tc_candidate_respond_private_interview_reschedule(p_proposal_id uuid, p_response text, p_response_note text DEFAULT ''::text)
 RETURNS text
 LANGUAGE sql
 SET search_path TO ''
AS $function$ SELECT private.tc_respond_interview_schedule_proposal('private',p_proposal_id,p_response,p_response_note) $function$


CREATE OR REPLACE FUNCTION public.tc_company_finalise_international_application(p_application_id uuid, p_company_id uuid, p_new_status text, p_note text DEFAULT ''::text)
 RETURNS text
 LANGUAGE sql
 SET search_path TO ''
AS $function$ SELECT private.tc_company_finalise_independent_application('international',p_application_id,p_company_id,p_new_status,p_note) $function$


CREATE OR REPLACE FUNCTION public.tc_company_finalise_private_application(p_application_id uuid, p_company_id uuid, p_new_status text, p_note text DEFAULT ''::text)
 RETURNS text
 LANGUAGE sql
 SET search_path TO ''
AS $function$ SELECT private.tc_company_finalise_independent_application('private',p_application_id,p_company_id,p_new_status,p_note) $function$


CREATE OR REPLACE FUNCTION public.tc_company_propose_international_interview_reschedule(p_interview_id uuid, p_scheduled_at timestamp with time zone, p_timezone text, p_duration_minutes integer, p_interview_mode text, p_meeting_url text, p_location text, p_message text DEFAULT ''::text)
 RETURNS uuid
 LANGUAGE sql
 SET search_path TO ''
AS $function$ SELECT private.tc_create_interview_schedule_proposal('international',p_interview_id,'employer_reschedule',p_scheduled_at,p_timezone,p_duration_minutes,p_interview_mode,p_meeting_url,p_location,p_message) $function$


CREATE OR REPLACE FUNCTION public.tc_company_propose_private_interview_reschedule(p_interview_id uuid, p_scheduled_at timestamp with time zone, p_timezone text, p_duration_minutes integer, p_interview_mode text, p_meeting_url text, p_location text, p_message text DEFAULT ''::text)
 RETURNS uuid
 LANGUAGE sql
 SET search_path TO ''
AS $function$ SELECT private.tc_create_interview_schedule_proposal('private',p_interview_id,'employer_reschedule',p_scheduled_at,p_timezone,p_duration_minutes,p_interview_mode,p_meeting_url,p_location,p_message) $function$


CREATE OR REPLACE FUNCTION public.tc_company_respond_international_interview_date_proposal(p_proposal_id uuid, p_response text, p_response_note text DEFAULT ''::text)
 RETURNS text
 LANGUAGE sql
 SET search_path TO ''
AS $function$ SELECT private.tc_respond_interview_schedule_proposal('international',p_proposal_id,p_response,p_response_note) $function$


CREATE OR REPLACE FUNCTION public.tc_company_respond_private_interview_date_proposal(p_proposal_id uuid, p_response text, p_response_note text DEFAULT ''::text)
 RETURNS text
 LANGUAGE sql
 SET search_path TO ''
AS $function$ SELECT private.tc_respond_interview_schedule_proposal('private',p_proposal_id,p_response,p_response_note) $function$


DROP TRIGGER IF EXISTS trg_private_interview_schedule_history ON public.private_job_interview_invitations;
CREATE TRIGGER trg_private_interview_schedule_history BEFORE UPDATE OF scheduled_at,timezone,duration_minutes,interview_mode,meeting_url,location ON public.private_job_interview_invitations FOR EACH ROW EXECUTE FUNCTION private.tc_log_independent_interview_schedule_change();
DROP TRIGGER IF EXISTS trg_international_interview_schedule_history ON public.international_job_interview_invitations;
CREATE TRIGGER trg_international_interview_schedule_history BEFORE UPDATE OF scheduled_at,timezone,duration_minutes,interview_mode,meeting_url,location ON public.international_job_interview_invitations FOR EACH ROW EXECUTE FUNCTION private.tc_log_independent_interview_schedule_change();

GRANT USAGE ON SCHEMA private TO authenticated;
REVOKE ALL ON FUNCTION private.tc_cancel_independent_interviews_on_application_close() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION private.tc_company_finalise_independent_application(p_system text, p_application_id uuid, p_company_id uuid, p_new_status text, p_note text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION private.tc_create_interview_schedule_proposal(p_system text, p_interview_id uuid, p_proposal_type text, p_scheduled_at timestamp with time zone, p_timezone text, p_duration_minutes integer, p_interview_mode text, p_meeting_url text, p_location text, p_message text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION private.tc_log_independent_interview_schedule_change() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION private.tc_respond_interview_schedule_proposal(p_system text, p_proposal_id uuid, p_response text, p_response_note text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION private.tc_cancel_independent_interviews_on_application_close(),
 private.tc_company_finalise_independent_application(p_system text, p_application_id uuid, p_company_id uuid, p_new_status text, p_note text),
 private.tc_create_interview_schedule_proposal(p_system text, p_interview_id uuid, p_proposal_type text, p_scheduled_at timestamp with time zone, p_timezone text, p_duration_minutes integer, p_interview_mode text, p_meeting_url text, p_location text, p_message text),
 private.tc_log_independent_interview_schedule_change(),
 private.tc_respond_interview_schedule_proposal(p_system text, p_proposal_id uuid, p_response text, p_response_note text) TO authenticated;
REVOKE ALL ON FUNCTION public.tc_candidate_propose_international_interview_date(p_interview_id uuid, p_scheduled_at timestamp with time zone, p_timezone text, p_duration_minutes integer, p_interview_mode text, p_meeting_url text, p_location text, p_message text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.tc_candidate_propose_private_interview_date(p_interview_id uuid, p_scheduled_at timestamp with time zone, p_timezone text, p_duration_minutes integer, p_interview_mode text, p_meeting_url text, p_location text, p_message text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.tc_candidate_respond_international_interview_reschedule(p_proposal_id uuid, p_response text, p_response_note text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.tc_candidate_respond_private_interview_reschedule(p_proposal_id uuid, p_response text, p_response_note text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.tc_company_finalise_international_application(p_application_id uuid, p_company_id uuid, p_new_status text, p_note text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.tc_company_finalise_private_application(p_application_id uuid, p_company_id uuid, p_new_status text, p_note text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.tc_company_propose_international_interview_reschedule(p_interview_id uuid, p_scheduled_at timestamp with time zone, p_timezone text, p_duration_minutes integer, p_interview_mode text, p_meeting_url text, p_location text, p_message text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.tc_company_propose_private_interview_reschedule(p_interview_id uuid, p_scheduled_at timestamp with time zone, p_timezone text, p_duration_minutes integer, p_interview_mode text, p_meeting_url text, p_location text, p_message text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.tc_company_respond_international_interview_date_proposal(p_proposal_id uuid, p_response text, p_response_note text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.tc_company_respond_private_interview_date_proposal(p_proposal_id uuid, p_response text, p_response_note text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.tc_candidate_propose_international_interview_date(p_interview_id uuid, p_scheduled_at timestamp with time zone, p_timezone text, p_duration_minutes integer, p_interview_mode text, p_meeting_url text, p_location text, p_message text),
 public.tc_candidate_propose_private_interview_date(p_interview_id uuid, p_scheduled_at timestamp with time zone, p_timezone text, p_duration_minutes integer, p_interview_mode text, p_meeting_url text, p_location text, p_message text),
 public.tc_candidate_respond_international_interview_reschedule(p_proposal_id uuid, p_response text, p_response_note text),
 public.tc_candidate_respond_private_interview_reschedule(p_proposal_id uuid, p_response text, p_response_note text),
 public.tc_company_finalise_international_application(p_application_id uuid, p_company_id uuid, p_new_status text, p_note text),
 public.tc_company_finalise_private_application(p_application_id uuid, p_company_id uuid, p_new_status text, p_note text),
 public.tc_company_propose_international_interview_reschedule(p_interview_id uuid, p_scheduled_at timestamp with time zone, p_timezone text, p_duration_minutes integer, p_interview_mode text, p_meeting_url text, p_location text, p_message text),
 public.tc_company_propose_private_interview_reschedule(p_interview_id uuid, p_scheduled_at timestamp with time zone, p_timezone text, p_duration_minutes integer, p_interview_mode text, p_meeting_url text, p_location text, p_message text),
 public.tc_company_respond_international_interview_date_proposal(p_proposal_id uuid, p_response text, p_response_note text),
 public.tc_company_respond_private_interview_date_proposal(p_proposal_id uuid, p_response text, p_response_note text) TO authenticated;

-- Trigger-only functions are not callable by application roles.
REVOKE ALL ON FUNCTION private.tc_cancel_independent_interviews_on_application_close() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION private.tc_log_independent_interview_schedule_change() FROM PUBLIC,anon,authenticated;
