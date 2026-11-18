-- Keep the RLS helper out of the exposed public API schema.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create or replace function private.tc_can_access_company_verification(
  p_company_id uuid,
  p_user_id uuid,
  p_request_id uuid,
  p_require_open boolean default false
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select
    (select auth.uid()) is not null
    and p_user_id = (select auth.uid())
    and exists (
      select 1
      from public.companies c
      join public.company_verification_requests r on r.company_id = c.id
      where c.id = p_company_id
        and c.owner_user_id = (select auth.uid())
        and r.id = p_request_id
        and r.submitted_by = (select auth.uid())
        and (
          not coalesce(p_require_open, false)
          or r.status in ('pending', 'more_information')
        )
    );
$function$;

revoke all on function private.tc_can_access_company_verification(uuid,uuid,uuid,boolean) from public, anon, authenticated;
grant execute on function private.tc_can_access_company_verification(uuid,uuid,uuid,boolean) to authenticated;

drop policy if exists "Company owners view own verification requests" on public.company_verification_requests;
create policy "Company owners view own verification requests"
on public.company_verification_requests
for select to authenticated
using (private.tc_can_access_company_verification(company_id, submitted_by, id, false));

drop policy if exists "Company owners view own verification documents" on public.company_verification_documents;
create policy "Company owners view own verification documents"
on public.company_verification_documents
for select to authenticated
using (private.tc_can_access_company_verification(company_id, uploaded_by, request_id, false));

drop policy if exists "Company owners add own verification documents" on public.company_verification_documents;
create policy "Company owners add own verification documents"
on public.company_verification_documents
for insert to authenticated
with check (private.tc_can_access_company_verification(company_id, uploaded_by, request_id, true));

drop policy if exists "Company owners read verification files" on storage.objects;
create policy "Company owners read verification files"
on storage.objects
for select to authenticated
using (
  bucket_id = 'company-verification'
  and array_length(storage.foldername(name), 1) = 3
  and private.tc_can_access_company_verification(
    (storage.foldername(name))[1]::uuid,
    (storage.foldername(name))[2]::uuid,
    (storage.foldername(name))[3]::uuid,
    false
  )
);

drop policy if exists "Company owners upload verification files" on storage.objects;
create policy "Company owners upload verification files"
on storage.objects
for insert to authenticated
with check (
  bucket_id = 'company-verification'
  and array_length(storage.foldername(name), 1) = 3
  and private.tc_can_access_company_verification(
    (storage.foldername(name))[1]::uuid,
    (storage.foldername(name))[2]::uuid,
    (storage.foldername(name))[3]::uuid,
    true
  )
  and (
    name ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/(business_registration|tax_registration|registered_address_proof|authorized_signatory_id|recruitment_license|work_authorization)-[0-9]{10,16}-[a-z0-9]{4,12}[.](pdf|jpg|png|webp)$'
    or name ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/additional-[0-9]{10,16}[.](pdf|jpg|png|webp)$'
  )
);

drop function if exists public.tc_can_access_company_verification(uuid,uuid,uuid,boolean);
