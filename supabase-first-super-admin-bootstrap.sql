-- One-time first Super Admin bootstrap for the project owner.
-- Run only in the Supabase SQL Editor as the project owner.
-- Replace the placeholder below with the exact email of the account you control.
-- Never commit a real email address or any password/key into this file.

DO $bootstrap$
DECLARE
  target_email text := lower(trim('REPLACE_WITH_OWNER_LOGIN_EMAIL'));
  target_user_id uuid;
  existing_admins integer;
BEGIN
  IF target_email = '' OR target_email = 'replace_with_owner_login_email' THEN
    RAISE EXCEPTION 'Set target_email to the exact owner login email before running this bootstrap.';
  END IF;

  SELECT id
    INTO target_user_id
    FROM auth.users
   WHERE lower(email) = target_email;

  IF target_user_id IS NULL THEN
    RAISE EXCEPTION 'No Supabase Auth account matches the supplied email. Create and confirm the owner account first.';
  END IF;

  SELECT count(*)
    INTO existing_admins
    FROM public.user_roles
   WHERE role = 'super_admin';

  IF existing_admins > 0
     AND NOT EXISTS (
       SELECT 1 FROM public.user_roles
        WHERE user_id = target_user_id AND role = 'super_admin'
     ) THEN
    RAISE EXCEPTION 'A Super Admin already exists. Use the secured existing admin process instead of first-admin bootstrap.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.user_roles
     WHERE user_id = target_user_id AND role = 'super_admin'
  ) THEN
    INSERT INTO public.user_roles (user_id, role)
    VALUES (target_user_id, 'super_admin');
  END IF;
END
$bootstrap$;

-- Verify without exposing account identifiers:
SELECT count(*) AS super_admin_role_assignments
FROM public.user_roles
WHERE role = 'super_admin';
