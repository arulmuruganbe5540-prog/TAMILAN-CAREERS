-- Harden company verification document paths and prevent reviewing closed requests.
create or replace function public.tc_guard_company_verification_document()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  v_folders text[];
  v_filename text;
  v_expected_extension text;
begin
  v_folders := storage.foldername(new.storage_path);
  v_filename := storage.filename(new.storage_path);

  if v_folders is null
     or array_length(v_folders, 1) <> 3
     or v_folders[1] <> new.company_id::text
     or v_folders[2] <> new.uploaded_by::text
     or v_folders[3] <> new.request_id::text then
    raise exception 'Verification document path must match its company, uploader, and request';
  end if;

  if new.document_type not in (
    'business_registration', 'tax_registration', 'registered_address_proof',
    'recruitment_license', 'work_authorization', 'authorized_signatory_id', 'other'
  ) then
    raise exception 'Unsupported verification document type';
  end if;

  if v_filename !~* '^(business_registration|tax_registration|registered_address_proof|authorized_signatory_id|recruitment_license|work_authorization)-[0-9]{10,16}-[a-z0-9]{4,12}[.](pdf|jpg|png|webp)$'
     and v_filename !~* '^additional-[0-9]{10,16}[.](pdf|jpg|png|webp)$' then
    raise exception 'Invalid verification document filename';
  end if;

  if v_filename !~* '^additional-' and split_part(v_filename, '-', 1) <> new.document_type then
    raise exception 'Document type does not match its storage path';
  end if;

  v_expected_extension := case new.mime_type
    when 'application/pdf' then 'pdf'
    when 'image/jpeg' then 'jpg'
    when 'image/png' then 'png'
    when 'image/webp' then 'webp'
    else null
  end;
  if v_expected_extension is null
     or lower(v_filename) not like '%.' || v_expected_extension then
    raise exception 'Document MIME type does not match its file extension';
  end if;

  if new.file_size_bytes < 1 or new.file_size_bytes > 10485760 then
    raise exception 'Verification documents must be between 1 byte and 10 MB';
  end if;

  return new;
end;
$function$;

drop trigger if exists tc_guard_company_verification_document on public.company_verification_documents;
create trigger tc_guard_company_verification_document
before insert or update on public.company_verification_documents
for each row execute function public.tc_guard_company_verification_document();

drop policy if exists "Company owners upload verification files" on storage.objects;
create policy "Company owners upload verification files"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'company-verification'
  and (storage.foldername(name))[2] = (select auth.uid())::text
  and name ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/(business_registration|tax_registration|registered_address_proof|authorized_signatory_id|recruitment_license|work_authorization)-[0-9]{10,16}-[a-z0-9]{4,12}[.](pdf|jpg|png|webp)$'
      or name ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/additional-[0-9]{10,16}[.](pdf|jpg|png|webp)$')
  and exists (
    select 1
    from public.companies c
    join public.company_verification_requests r on r.company_id = c.id
    where c.id::text = (storage.foldername(name))[1]
      and c.owner_user_id = (select auth.uid())
      and r.id::text = (storage.foldername(name))[3]
      and r.submitted_by = (select auth.uid())
      and r.status in ('pending', 'more_information')
  )
);

create or replace function public.tc_review_company_verification(
  p_request_id uuid,
  p_decision text,
  p_admin_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_company_id uuid;
  v_owner uuid;
  v_legal_name text;
  v_request_status text;
  v_title text;
  v_body text;
begin
  if (select auth.uid()) is null
     or not exists (
       select 1 from public.user_roles ur
       where ur.user_id = (select auth.uid()) and ur.role = 'super_admin'
     ) then
    raise exception 'Super Admin permission required';
  end if;

  if p_decision is null or p_decision not in ('under_review', 'verified', 'rejected', 'more_information') then
    raise exception 'Invalid review decision';
  end if;

  if length(coalesce(p_admin_notes, '')) > 4000 then
    raise exception 'Admin notes cannot exceed 4000 characters';
  end if;

  select r.company_id, c.owner_user_id, r.legal_name, r.status
    into v_company_id, v_owner, v_legal_name, v_request_status
  from public.company_verification_requests r
  join public.companies c on c.id = r.company_id
  where r.id = p_request_id
  for update of r;

  if v_company_id is null then
    raise exception 'Verification request not found';
  end if;

  if v_request_status not in ('pending', 'under_review', 'more_information') then
    raise exception 'This verification request is already closed and cannot be reviewed again';
  end if;

  update public.company_verification_requests
  set status = p_decision,
      admin_notes = left(coalesce(p_admin_notes, ''), 4000),
      reviewed_by = (select auth.uid()),
      reviewed_at = now(),
      updated_at = now()
  where id = p_request_id;

  if p_decision in ('verified', 'rejected') then
    update public.companies
    set verification_status = p_decision, updated_at = now()
    where id = v_company_id;
  elsif p_decision in ('under_review', 'more_information') then
    update public.companies
    set verification_status = 'pending', updated_at = now()
    where id = v_company_id and verification_status <> 'pending';
  end if;

  v_title := case p_decision
    when 'under_review' then 'Company verification is under review'
    when 'verified' then 'Company verification approved'
    when 'rejected' then 'Company verification decision'
    else 'Additional company information required'
  end;
  v_body := case p_decision
    when 'under_review' then 'Your company verification request is now under review.'
    when 'verified' then 'Your company ' || v_legal_name || ' has been verified. You may now use the company features allowed by your account.'
    when 'rejected' then 'Your company verification request was rejected. Please read the Admin note and contact support if you need clarification.'
    else 'The verification team needs more information or documents. Please open Company Verification Status in your dashboard and respond.'
  end;

  if length(btrim(coalesce(p_admin_notes, ''))) > 0 then
    v_body := v_body || E'\n\nAdmin note: ' || left(p_admin_notes, 2500);
  end if;

  insert into public.tc_notifications(user_id, notification_type, title, body)
  values (v_owner, 'system', left(v_title, 180), left(v_body, 4000));

  return jsonb_build_object('success', true, 'status', p_decision, 'company_id', v_company_id);
end;
$function$;
