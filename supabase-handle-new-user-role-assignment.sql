-- TAMILAN CAREERS: Assign only non-privileged roles during signup.
-- User-editable metadata is whitelisted; it can never grant admin/moderator roles.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  requested_type text;
  assigned_role text;
begin
  insert into public.profiles (id, full_name, email, phone)
  values (
    new.id,
    new.raw_user_meta_data ->> 'full_name',
    new.email,
    new.phone
  )
  on conflict (id) do nothing;

  insert into public.user_settings (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  requested_type := coalesce(new.raw_user_meta_data ->> 'requested_account_type', 'job_seeker');
  assigned_role := case
    when requested_type = 'company' then 'company_member'
    else 'job_seeker'
  end;

  insert into public.user_roles (user_id, role)
  values (new.id, assigned_role)
  on conflict (user_id, role) do nothing;

  return new;
end;
$function$;
