-- TAMILAN CAREERS: private Resume & Document Storage
-- Run in Supabase SQL Editor for project qkmljuuusfjowexvybvy.
-- This creates a PRIVATE bucket and owner-folder-only access policies.
-- Existing bucket settings are not overwritten.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'resumes',
  'resumes',
  false,
  5242880,
  array[
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ]::text[]
)
on conflict (id) do nothing;

create policy "TC resumes owner can read"
on storage.objects for select
to authenticated
using (
  bucket_id = 'resumes'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

create policy "TC resumes owner can upload"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'resumes'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

create policy "TC resumes owner can update"
on storage.objects for update
to authenticated
using (
  bucket_id = 'resumes'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
)
with check (
  bucket_id = 'resumes'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

create policy "TC resumes owner can delete"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'resumes'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);
