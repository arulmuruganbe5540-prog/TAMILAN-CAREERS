
-- Automatically close pending/accepted interviews when an independent application is rejected or withdrawn.
CREATE OR REPLACE FUNCTION private.tc_cancel_independent_interviews_on_application_close()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE v_row record; v_actor uuid:=(SELECT auth.uid());
BEGIN
 IF NEW.status IS NOT DISTINCT FROM OLD.status OR NEW.status NOT IN ('withdrawn','rejected') THEN RETURN NEW; END IF;
 IF TG_TABLE_NAME='private_job_applications' THEN
  FOR v_row IN SELECT id,candidate_id,application_id,interview_title,status
   FROM public.private_job_interview_invitations WHERE application_id=NEW.id AND status IN ('pending','accepted') FOR UPDATE
  LOOP
   UPDATE public.private_job_interview_invitations SET status='cancelled',updated_at=now() WHERE id=v_row.id;
   INSERT INTO public.private_job_interview_history(interview_id,old_status,new_status,changed_by,change_note)
   VALUES(v_row.id,v_row.status,'cancelled',v_actor,'Application was '||NEW.status);
   INSERT INTO public.tc_notifications(user_id,notification_type,title,body,related_application_id,related_interview_id)
   VALUES(v_row.candidate_id,'interview_invitation','Interview Invitation Closed',
    'The interview "'||v_row.interview_title||'" was cancelled because the application was '||NEW.status||'.',
    v_row.application_id,v_row.id);
  END LOOP;
 ELSIF TG_TABLE_NAME='international_job_applications' THEN
  FOR v_row IN SELECT id,candidate_id,application_id,interview_title,status
   FROM public.international_job_interview_invitations WHERE application_id=NEW.id AND status IN ('pending','accepted') FOR UPDATE
  LOOP
   UPDATE public.international_job_interview_invitations SET status='cancelled',updated_at=now() WHERE id=v_row.id;
   INSERT INTO public.international_job_interview_history(interview_id,old_status,new_status,changed_by,change_note)
   VALUES(v_row.id,v_row.status,'cancelled',v_actor,'Application was '||NEW.status);
   INSERT INTO public.tc_notifications(user_id,notification_type,title,body,related_application_id,related_interview_id)
   VALUES(v_row.candidate_id,'interview_invitation','International Interview Invitation Closed',
    'The interview "'||v_row.interview_title||'" was cancelled because the application was '||NEW.status||'.',
    v_row.application_id,v_row.id);
  END LOOP;
 END IF;
 RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.tc_cancel_independent_interviews_on_application_close() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS tc_cancel_private_interviews_on_application_close ON public.private_job_applications;
CREATE TRIGGER tc_cancel_private_interviews_on_application_close
AFTER UPDATE OF status ON public.private_job_applications
FOR EACH ROW EXECUTE FUNCTION private.tc_cancel_independent_interviews_on_application_close();
DROP TRIGGER IF EXISTS tc_cancel_international_interviews_on_application_close ON public.international_job_applications;
CREATE TRIGGER tc_cancel_international_interviews_on_application_close
AFTER UPDATE OF status ON public.international_job_applications
FOR EACH ROW EXECUTE FUNCTION private.tc_cancel_independent_interviews_on_application_close();

-- Extend the existing 15-minute reminder job to independent Private and International interviews.
CREATE OR REPLACE FUNCTION public.tc_generate_interview_reminders()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE v_count integer:=0; v_rows integer:=0;
BEGIN
 INSERT INTO public.tc_notifications(user_id,notification_type,title,body,related_application_id,related_interview_id)
 SELECT i.candidate_id,'interview_reminder','Your interview is tomorrow',
  'Your interview is in 24 hours. Date: '||to_char(i.scheduled_at AT TIME ZONE 'Asia/Kolkata','DD-MM-YYYY HH12:MI AM'),
  i.application_id,i.id
 FROM public.tc_interview_invitations i JOIN public.job_applications ja ON ja.id=i.application_id
 WHERE i.status='accepted' AND ja.status IN ('applied','under_review','shortlisted')
  AND i.scheduled_at BETWEEN now()+interval '23 hours' AND now()+interval '25 hours'
  AND NOT EXISTS(SELECT 1 FROM public.tc_notifications n WHERE n.user_id=i.candidate_id AND n.related_interview_id=i.id AND n.notification_type='interview_reminder' AND n.body LIKE 'Your interview is in 24 hours.%');
 GET DIAGNOSTICS v_rows=ROW_COUNT; v_count:=v_count+v_rows;

 INSERT INTO public.tc_notifications(user_id,notification_type,title,body,related_application_id,related_interview_id)
 SELECT i.candidate_id,'interview_reminder','Your interview starts in one hour',
  'Your interview starts in one hour. Date: '||to_char(i.scheduled_at AT TIME ZONE 'Asia/Kolkata','DD-MM-YYYY HH12:MI AM'),
  i.application_id,i.id
 FROM public.tc_interview_invitations i JOIN public.job_applications ja ON ja.id=i.application_id
 WHERE i.status='accepted' AND ja.status IN ('applied','under_review','shortlisted')
  AND i.scheduled_at BETWEEN now()+interval '50 minutes' AND now()+interval '70 minutes'
  AND NOT EXISTS(SELECT 1 FROM public.tc_notifications n WHERE n.user_id=i.candidate_id AND n.related_interview_id=i.id AND n.notification_type='interview_reminder' AND n.body LIKE 'Your interview starts in one hour.%');
 GET DIAGNOSTICS v_rows=ROW_COUNT; v_count:=v_count+v_rows;

 INSERT INTO public.tc_notifications(user_id,notification_type,title,body,related_application_id,related_interview_id)
 SELECT i.candidate_id,'interview_reminder','Your Private Job interview is tomorrow',
  'Your interview is in 24 hours. Date: '||to_char(i.scheduled_at AT TIME ZONE i.timezone,'DD-MM-YYYY HH12:MI AM')||' ('||i.timezone||').',
  i.application_id,i.id
 FROM public.private_job_interview_invitations i JOIN public.private_job_applications a ON a.id=i.application_id
 WHERE i.status='accepted' AND a.status IN ('applied','under_review','shortlisted','interview')
  AND i.scheduled_at BETWEEN now()+interval '23 hours' AND now()+interval '25 hours'
  AND NOT EXISTS(SELECT 1 FROM public.tc_notifications n WHERE n.user_id=i.candidate_id AND n.related_interview_id=i.id AND n.notification_type='interview_reminder' AND n.body LIKE 'Your interview is in 24 hours.%');
 GET DIAGNOSTICS v_rows=ROW_COUNT; v_count:=v_count+v_rows;

 INSERT INTO public.tc_notifications(user_id,notification_type,title,body,related_application_id,related_interview_id)
 SELECT i.candidate_id,'interview_reminder','Your Private Job interview starts in one hour',
  'Your interview starts in one hour. Date: '||to_char(i.scheduled_at AT TIME ZONE i.timezone,'DD-MM-YYYY HH12:MI AM')||' ('||i.timezone||').',
  i.application_id,i.id
 FROM public.private_job_interview_invitations i JOIN public.private_job_applications a ON a.id=i.application_id
 WHERE i.status='accepted' AND a.status IN ('applied','under_review','shortlisted','interview')
  AND i.scheduled_at BETWEEN now()+interval '50 minutes' AND now()+interval '70 minutes'
  AND NOT EXISTS(SELECT 1 FROM public.tc_notifications n WHERE n.user_id=i.candidate_id AND n.related_interview_id=i.id AND n.notification_type='interview_reminder' AND n.body LIKE 'Your interview starts in one hour.%');
 GET DIAGNOSTICS v_rows=ROW_COUNT; v_count:=v_count+v_rows;

 INSERT INTO public.tc_notifications(user_id,notification_type,title,body,related_application_id,related_interview_id)
 SELECT i.candidate_id,'interview_reminder','Your International Job interview is tomorrow',
  'Your interview is in 24 hours. Date: '||to_char(i.scheduled_at AT TIME ZONE i.timezone,'DD-MM-YYYY HH12:MI AM')||' ('||i.timezone||').',
  i.application_id,i.id
 FROM public.international_job_interview_invitations i JOIN public.international_job_applications a ON a.id=i.application_id
 WHERE i.status='accepted' AND a.status IN ('applied','under_review','shortlisted','interview')
  AND i.scheduled_at BETWEEN now()+interval '23 hours' AND now()+interval '25 hours'
  AND NOT EXISTS(SELECT 1 FROM public.tc_notifications n WHERE n.user_id=i.candidate_id AND n.related_interview_id=i.id AND n.notification_type='interview_reminder' AND n.body LIKE 'Your interview is in 24 hours.%');
 GET DIAGNOSTICS v_rows=ROW_COUNT; v_count:=v_count+v_rows;

 INSERT INTO public.tc_notifications(user_id,notification_type,title,body,related_application_id,related_interview_id)
 SELECT i.candidate_id,'interview_reminder','Your International Job interview starts in one hour',
  'Your interview starts in one hour. Date: '||to_char(i.scheduled_at AT TIME ZONE i.timezone,'DD-MM-YYYY HH12:MI AM')||' ('||i.timezone||').',
  i.application_id,i.id
 FROM public.international_job_interview_invitations i JOIN public.international_job_applications a ON a.id=i.application_id
 WHERE i.status='accepted' AND a.status IN ('applied','under_review','shortlisted','interview')
  AND i.scheduled_at BETWEEN now()+interval '50 minutes' AND now()+interval '70 minutes'
  AND NOT EXISTS(SELECT 1 FROM public.tc_notifications n WHERE n.user_id=i.candidate_id AND n.related_interview_id=i.id AND n.notification_type='interview_reminder' AND n.body LIKE 'Your interview starts in one hour.%');
 GET DIAGNOSTICS v_rows=ROW_COUNT; v_count:=v_count+v_rows;
 RETURN v_count;
END;
$$;
