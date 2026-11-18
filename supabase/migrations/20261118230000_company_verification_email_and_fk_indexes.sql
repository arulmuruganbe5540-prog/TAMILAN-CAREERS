-- Correct the company verification email constraint and index its foreign keys.
alter table public.company_verification_requests
  drop constraint if exists company_verification_requests_official_email_check;

alter table public.company_verification_requests
  add constraint company_verification_requests_official_email_check
  check (
    official_email = lower(btrim(official_email))
    and official_email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+[.][A-Z]{2,}$'
  );

create index if not exists idx_company_verification_documents_company_id
  on public.company_verification_documents(company_id);
create index if not exists idx_company_verification_documents_request_id
  on public.company_verification_documents(request_id);
create index if not exists idx_company_verification_documents_uploaded_by
  on public.company_verification_documents(uploaded_by);
create index if not exists idx_company_verification_requests_submitted_by
  on public.company_verification_requests(submitted_by);
create index if not exists idx_company_verification_requests_reviewed_by
  on public.company_verification_requests(reviewed_by);
