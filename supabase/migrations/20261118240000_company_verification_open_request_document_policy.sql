-- Restrict verification-document metadata inserts to requests that are still open.
drop policy if exists "Company owners add own verification documents" on public.company_verification_documents;
create policy "Company owners add own verification documents"
on public.company_verification_documents
for insert
to authenticated
with check (
  uploaded_by = (select auth.uid())
  and exists (
    select 1
    from public.companies c
    where c.id = company_verification_documents.company_id
      and c.owner_user_id = (select auth.uid())
  )
  and exists (
    select 1
    from public.company_verification_requests r
    where r.id = company_verification_documents.request_id
      and r.company_id = company_verification_documents.company_id
      and r.submitted_by = (select auth.uid())
      and r.status in ('pending', 'more_information')
  )
);
