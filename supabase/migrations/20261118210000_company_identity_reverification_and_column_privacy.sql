-- Harden company verification identity and protect private company identifiers.
create or replace function public.tc_guard_company_verification_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_is_admin boolean := exists (
    select 1 from public.user_roles ur
    where ur.user_id = (select auth.uid())
      and ur.role = 'super_admin'
  );
begin
  if tg_op = 'INSERT' then
    if coalesce(new.verification_status,'pending') <> 'pending' and not v_is_admin then
      raise exception 'Only Super Admin can create a verified company';
    end if;
    return new;
  end if;

  if not v_is_admin then
    if new.owner_user_id is distinct from old.owner_user_id then
      raise exception 'Company ownership cannot be changed by the company owner';
    end if;

    if new.verification_status is distinct from old.verification_status
       and new.verification_status <> 'pending' then
      raise exception 'Only Super Admin can verify or reject a company';
    end if;

    if old.verification_status = 'verified' and (
      new.company_name is distinct from old.company_name
      or new.company_slug is distinct from old.company_slug
      or new.description is distinct from old.description
      or new.website_url is distinct from old.website_url
      or new.logo_path is distinct from old.logo_path
      or new.industry is distinct from old.industry
      or new.company_size is distinct from old.company_size
      or new.registration_number is distinct from old.registration_number
    ) then
      new.verification_status := 'pending';
      new.updated_at := now();
    end if;
  end if;
  return new;
end;
$function$;

drop trigger if exists tc_guard_company_verification_status on public.companies;
create trigger tc_guard_company_verification_status
before insert or update on public.companies
for each row execute function public.tc_guard_company_verification_status();

revoke select on public.companies from anon, authenticated;
grant select (
  id, company_name, company_slug, description, website_url, logo_path,
  industry, company_size, verification_status, created_at, updated_at
) on public.companies to anon, authenticated;
