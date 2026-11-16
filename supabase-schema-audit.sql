-- TAMILAN CAREERS: Read-only Supabase schema and RLS audit
-- SAFE: This script only reads PostgreSQL metadata. It creates, changes or deletes nothing.
-- Run in Supabase SQL Editor and inspect the Results for the actual column types and policies.

select
  table_name,
  column_name,
  data_type,
  udt_name,
  is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name in (
    'jobs',
    'companies',
    'company_members',
    'job_applications',
    'user_roles',
    'government_notice_sources',
    'government_notice_reviews',
    'government_notices'
  )
order by table_name, ordinal_position;

select
  tc.table_name,
  tc.constraint_name,
  tc.constraint_type,
  kcu.column_name,
  ccu.table_name as foreign_table_name,
  ccu.column_name as foreign_column_name
from information_schema.table_constraints tc
left join information_schema.key_column_usage kcu
  on tc.constraint_schema = kcu.constraint_schema
 and tc.constraint_name = kcu.constraint_name
 and tc.table_name = kcu.table_name
left join information_schema.constraint_column_usage ccu
  on ccu.constraint_schema = tc.constraint_schema
 and ccu.constraint_name = tc.constraint_name
where tc.constraint_schema = 'public'
  and tc.table_name in ('jobs','companies','company_members','job_applications','government_notice_sources','government_notice_reviews','government_notices')
order by tc.table_name, tc.constraint_type, tc.constraint_name;

select
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
from pg_policies
where schemaname = 'public'
  and tablename in ('jobs','companies','company_members','job_applications','user_roles','government_notice_sources','government_notice_reviews','government_notices')
order by tablename, policyname;


-- 4. Existing admin-related role values (metadata only; no user records exposed).
select
  column_name,
  data_type,
  udt_name
from information_schema.columns
where table_schema = 'public'
  and table_name = 'user_roles'
order by ordinal_position;

-- 5. Existing table grants for the job and government-notice tables.
select
  table_name,
  grantee,
  privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name in (
    'jobs','companies','company_members','job_applications','user_roles',
    'government_notice_sources','government_notice_reviews','government_notices'
  )
order by table_name, grantee, privilege_type;

-- 6. Existing security-definer functions that might be relevant to role/admin checks.
select
  n.nspname as schema_name,
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as arguments,
  p.prosecdef as security_definer,
  p.proconfig as function_settings
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and (
    p.proname ilike '%admin%'
    or p.proname ilike '%role%'
    or p.proname ilike '%publish%'
    or p.proname ilike '%government%'
  )
order by p.proname;
