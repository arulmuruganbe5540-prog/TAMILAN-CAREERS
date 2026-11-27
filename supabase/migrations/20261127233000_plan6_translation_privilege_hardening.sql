-- Plan 6: remove unnecessary table-level privileges from translation tables.
-- RLS remains the row-level authorization layer.
revoke all privileges on table public.government_job_translations from public, anon, authenticated, service_role;
revoke all privileges on table public.private_job_translations from public, anon, authenticated, service_role;
grant select on table public.government_job_translations to anon, authenticated;
grant select, insert, update, delete on table public.government_job_translations to authenticated;
grant select on table public.private_job_translations to anon, authenticated;
grant select, insert, update, delete on table public.private_job_translations to authenticated;
