-- Read-only smoke checks for Mangaiyarkarasi control foundation.
-- Run only after applying the migration to an isolated development database.
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
