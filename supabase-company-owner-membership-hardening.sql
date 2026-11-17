-- Harden the company-owner membership trigger.
-- The function is trigger-only (EXECUTE remains postgres-only), and every
-- object/function reference is schema-qualified under an empty search_path.
create or replace function public.create_company_owner_membership()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  insert into public.company_members (
    id, company_id, user_id, member_role, member_status, created_at
  )
  values (
    pg_catalog.gen_random_uuid(),
    new.id,
    new.owner_user_id,
    'owner',
    'active',
    pg_catalog.now()
  )
  on conflict (company_id, user_id) do nothing;

  return new;
end;
$function$;

-- Verification: expected search_path={search_path=""}, one enabled trigger,
-- and EXECUTE granted only to postgres (the trigger owner context).
select
  p.proname,
  p.prosecdef as security_definer,
  p.proconfig as function_settings,
  p.proacl as function_acl,
  t.tgenabled as trigger_enabled
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
join pg_trigger t on t.tgfoid = p.oid and not t.tgisinternal
where n.nspname = 'public'
  and p.proname = 'create_company_owner_membership'
  and t.tgname = 'trg_create_company_owner_membership';
