-- Correct the private job-offer Storage object path matcher.
-- The old expression was over-escaped and rejected valid UUID/UUID.pdf paths.
begin;

drop policy if exists "job_offers_select_authorized" on storage.objects;
create policy "job_offers_select_authorized"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'job-offers'
  and name ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.pdf$'
  and private.can_access_job_application(split_part(name, '/', 1)::uuid)
);

commit;
