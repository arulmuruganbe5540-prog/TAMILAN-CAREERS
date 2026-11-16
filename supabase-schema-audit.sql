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
    'user_roles'
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
  and tc.table_name in ('jobs','companies','company_members','job_applications')
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
  and tablename in ('jobs','companies','company_members','job_applications')
order by tablename, policyname;
