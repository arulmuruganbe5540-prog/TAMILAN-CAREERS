-- Read-only smoke checks for Mangaiyarkarasi control foundation.
-- Run only after applying the migration to an isolated development database.
-- The assertion block fails the script if a required security invariant is missing.

do $$
declare
  v_owner_count integer;
  v_table_count integer;
  v_rls_count integer;
begin
  select count(*) into v_owner_count from public.mangai_owner_config;
  if v_owner_count <> 1 then
    raise exception 'Expected exactly one Master Owner binding; found %', v_owner_count;
  end if;

  select count(*) into v_table_count
  from information_schema.tables
  where table_schema = 'public' and table_name like 'mangai_%';
  if v_table_count < 9 then
    raise exception 'Expected at least 9 control tables; found %', v_table_count;
  end if;

  select count(*) into v_rls_count
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname like 'mangai_%'
    and c.relrowsecurity;
  if v_rls_count <> v_table_count then
    raise exception 'RLS is not enabled on every Mangai control table (% of %)', v_rls_count, v_table_count;
  end if;

  if has_table_privilege('anon', 'public.mangai_control_modules', 'select')
     or has_table_privilege('authenticated', 'public.mangai_control_modules', 'select') then
    raise exception 'Public or authenticated role can read the private module registry';
  end if;

  if has_table_privilege('anon', 'public.mangai_audit_events', 'insert')
     or has_table_privilege('authenticated', 'public.mangai_audit_events', 'insert') then
    raise exception 'Public or authenticated role can write audit events';
  end if;

  if has_table_privilege('service_role', 'public.mangai_audit_events', 'update')
     or has_table_privilege('service_role', 'public.mangai_audit_events', 'delete') then
    raise exception 'Audit events are not append-only for service_role';
  end if;

  if not has_table_privilege('service_role', 'public.mangai_audit_events', 'insert') then
    raise exception 'service_role cannot append audit events';
  end if;
end $$;

-- Human-readable evidence after the assertions pass.
select table_name
from information_schema.tables
where table_schema='public'
  and table_name like 'mangai_%'
order by table_name;

select
  c.relname as table_name,
  c.relrowsecurity as rls_enabled
from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public'
  and c.relname like 'mangai_%'
order by c.relname;

select
  has_table_privilege('anon', 'public.mangai_control_modules', 'select') as anon_can_read_modules,
  has_table_privilege('authenticated', 'public.mangai_control_modules', 'select') as authenticated_can_read_modules,
  has_table_privilege('service_role', 'public.mangai_control_modules', 'select') as service_role_can_read_modules,
  has_table_privilege('service_role', 'public.mangai_audit_events', 'update') as service_role_can_update_audit,
  has_table_privilege('service_role', 'public.mangai_audit_events', 'insert') as service_role_can_insert_audit;

select module_key, enabled, execution_mode, permission_tier, approval_required
from public.mangai_control_modules
order by category, module_key;

select count(*) as owner_binding_rows from public.mangai_owner_config;
