-- Independent message stores for Government, Private and International jobs.
-- Messages can only be inserted by the signed-in account that owns the session.
-- Sender email is derived from auth.users by a trigger; clients cannot choose it.

CREATE TABLE IF NOT EXISTS public.government_job_post_messages (LIKE public.job_post_messages INCLUDING ALL);
CREATE TABLE IF NOT EXISTS public.private_job_post_messages (LIKE public.job_post_messages INCLUDING ALL);
CREATE TABLE IF NOT EXISTS public.international_job_post_messages (LIKE public.job_post_messages INCLUDING ALL);

DO $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.government_job_post_messages'::regclass AND conname='government_job_post_messages_job_id_fkey') THEN
  ALTER TABLE public.government_job_post_messages ADD CONSTRAINT government_job_post_messages_job_id_fkey FOREIGN KEY(job_id) REFERENCES public.government_jobs(id) ON DELETE CASCADE;
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.private_job_post_messages'::regclass AND conname='private_job_post_messages_job_id_fkey') THEN
  ALTER TABLE public.private_job_post_messages ADD CONSTRAINT private_job_post_messages_job_id_fkey FOREIGN KEY(job_id) REFERENCES public.private_jobs(id) ON DELETE CASCADE;
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.international_job_post_messages'::regclass AND conname='international_job_post_messages_job_id_fkey') THEN
  ALTER TABLE public.international_job_post_messages ADD CONSTRAINT international_job_post_messages_job_id_fkey FOREIGN KEY(job_id) REFERENCES public.international_jobs(id) ON DELETE CASCADE;
 END IF;
END $$;

CREATE OR REPLACE FUNCTION private.set_independent_job_post_message_sender()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE v_email text; v_published boolean := false;
BEGIN
 IF auth.uid() IS NULL OR auth.uid() <> NEW.user_id THEN
  RAISE EXCEPTION 'You must be signed in to send a message.';
 END IF;
 SELECT u.email INTO v_email FROM auth.users u WHERE u.id=NEW.user_id;
 IF v_email IS NULL THEN RAISE EXCEPTION 'Your account email could not be verified.'; END IF;
 IF TG_TABLE_NAME='government_job_post_messages' THEN
  SELECT EXISTS(SELECT 1 FROM public.government_jobs j WHERE j.id=NEW.job_id AND j.status='published') INTO v_published;
 ELSIF TG_TABLE_NAME='private_job_post_messages' THEN
  SELECT EXISTS(SELECT 1 FROM public.private_jobs j WHERE j.id=NEW.job_id AND j.status='published') INTO v_published;
 ELSIF TG_TABLE_NAME='international_job_post_messages' THEN
  SELECT EXISTS(SELECT 1 FROM public.international_jobs j WHERE j.id=NEW.job_id AND j.status='published') INTO v_published;
 END IF;
 IF NOT v_published THEN RAISE EXCEPTION 'Messages can only be sent on published job posts.'; END IF;
 NEW.sender_email:=v_email;
 NEW.status:='visible';
 NEW.updated_at:=now();
 RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.set_independent_job_post_message_sender() FROM PUBLIC,anon,authenticated;

ALTER TABLE public.government_job_post_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.private_job_post_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.international_job_post_messages ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.government_job_post_messages,public.private_job_post_messages,public.international_job_post_messages TO anon,authenticated;
GRANT INSERT,UPDATE,DELETE ON public.government_job_post_messages,public.private_job_post_messages,public.international_job_post_messages TO authenticated;

DROP POLICY IF EXISTS government_job_post_messages_public_read ON public.government_job_post_messages;
CREATE POLICY government_job_post_messages_public_read ON public.government_job_post_messages FOR SELECT TO anon,authenticated USING (status='visible' AND EXISTS (SELECT 1 FROM public.government_jobs j WHERE j.id=government_job_post_messages.job_id AND j.status='published'));
DROP POLICY IF EXISTS government_job_post_messages_authenticated_insert ON public.government_job_post_messages;
CREATE POLICY government_job_post_messages_authenticated_insert ON public.government_job_post_messages FOR INSERT TO authenticated WITH CHECK (user_id=(SELECT auth.uid()));
DROP POLICY IF EXISTS government_job_post_messages_super_admin_all ON public.government_job_post_messages;
CREATE POLICY government_job_post_messages_super_admin_all ON public.government_job_post_messages FOR ALL TO authenticated USING ((SELECT private.is_super_admin())) WITH CHECK ((SELECT private.is_super_admin()));

DROP POLICY IF EXISTS private_job_post_messages_public_read ON public.private_job_post_messages;
CREATE POLICY private_job_post_messages_public_read ON public.private_job_post_messages FOR SELECT TO anon,authenticated USING (status='visible' AND EXISTS (SELECT 1 FROM public.private_jobs j WHERE j.id=private_job_post_messages.job_id AND j.status='published'));
DROP POLICY IF EXISTS private_job_post_messages_authenticated_insert ON public.private_job_post_messages;
CREATE POLICY private_job_post_messages_authenticated_insert ON public.private_job_post_messages FOR INSERT TO authenticated WITH CHECK (user_id=(SELECT auth.uid()));
DROP POLICY IF EXISTS private_job_post_messages_super_admin_all ON public.private_job_post_messages;
CREATE POLICY private_job_post_messages_super_admin_all ON public.private_job_post_messages FOR ALL TO authenticated USING ((SELECT private.is_super_admin())) WITH CHECK ((SELECT private.is_super_admin()));

DROP POLICY IF EXISTS international_job_post_messages_public_read ON public.international_job_post_messages;
CREATE POLICY international_job_post_messages_public_read ON public.international_job_post_messages FOR SELECT TO anon,authenticated USING (status='visible' AND EXISTS (SELECT 1 FROM public.international_jobs j WHERE j.id=international_job_post_messages.job_id AND j.status='published'));
DROP POLICY IF EXISTS international_job_post_messages_authenticated_insert ON public.international_job_post_messages;
CREATE POLICY international_job_post_messages_authenticated_insert ON public.international_job_post_messages FOR INSERT TO authenticated WITH CHECK (user_id=(SELECT auth.uid()));
DROP POLICY IF EXISTS international_job_post_messages_super_admin_all ON public.international_job_post_messages;
CREATE POLICY international_job_post_messages_super_admin_all ON public.international_job_post_messages FOR ALL TO authenticated USING ((SELECT private.is_super_admin())) WITH CHECK ((SELECT private.is_super_admin()));

DROP TRIGGER IF EXISTS trg_independent_message_sender ON public.government_job_post_messages;
CREATE TRIGGER trg_independent_message_sender BEFORE INSERT ON public.government_job_post_messages FOR EACH ROW EXECUTE FUNCTION private.set_independent_job_post_message_sender();
DROP TRIGGER IF EXISTS trg_independent_message_sender ON public.private_job_post_messages;
CREATE TRIGGER trg_independent_message_sender BEFORE INSERT ON public.private_job_post_messages FOR EACH ROW EXECUTE FUNCTION private.set_independent_job_post_message_sender();
DROP TRIGGER IF EXISTS trg_independent_message_sender ON public.international_job_post_messages;
CREATE TRIGGER trg_independent_message_sender BEFORE INSERT ON public.international_job_post_messages FOR EACH ROW EXECUTE FUNCTION private.set_independent_job_post_message_sender();
