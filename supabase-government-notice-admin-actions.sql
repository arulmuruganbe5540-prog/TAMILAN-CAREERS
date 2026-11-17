-- TAMILAN CAREERS: secure Admin publish/reject actions for government notices
-- Run after supabase-government-notices-setup.sql.
-- Publication is explicit and requires category-appropriate verification.

begin;

create or replace function public.tc_admin_publish_government_notice(
  p_review_id uuid,
  p_title text,
  p_official_url text,
  p_notice_reference text,
  p_notice_date date,
  p_application_start date,
  p_application_end date,
  p_vacancies integer,
  p_eligibility_summary text,
  p_details jsonb,
  p_verification jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_review public.government_notice_reviews%rowtype;
  v_source public.government_notice_sources%rowtype;
  v_host text;
  v_source_host text;
  v_required text[];
  v_key text;
begin
  if auth.uid() is null or not private.is_super_admin() then
    raise exception 'Super admin access required';
  end if;

  if p_review_id is null or nullif(btrim(p_title),'') is null or
     nullif(btrim(p_official_url),'') is null or p_notice_date is null then
    raise exception 'Title, official URL and original notice date are required';
  end if;
  if p_application_start is not null and p_application_end is not null
     and p_application_end < p_application_start then
    raise exception 'Application end date cannot be earlier than start date';
  end if;
  if p_vacancies is not null and p_vacancies < 0 then
    raise exception 'Vacancy count cannot be negative';
  end if;
  if jsonb_typeof(coalesce(p_details,'{}'::jsonb)) <> 'object' or
     jsonb_typeof(coalesce(p_verification,'{}'::jsonb)) <> 'object' then
    raise exception 'Details and verification must be JSON objects';
  end if;

  select * into v_review
  from public.government_notice_reviews
  where id = p_review_id
  for update;
  if not found then raise exception 'Review record not found'; end if;
  if v_review.status not in ('pending','verified') then
    raise exception 'Only pending or verified records can be published';
  end if;

  select * into v_source
  from public.government_notice_sources
  where id = v_review.source_id and enabled = true;
  if not found then raise exception 'Registered official source is not enabled'; end if;

  if p_official_url !~* '^https://' then
    raise exception 'Official URL must use HTTPS';
  end if;
  v_host := lower(substring(p_official_url from '^https://([^/:?#]+)'));
  v_source_host := lower(substring(v_source.base_url from '^https://([^/:?#]+)'));
  if v_host is null or v_source_host is null or
     (v_host <> v_source_host and right(v_host, length(v_source_host) + 1) <> ('.' || v_source_host)) then
    raise exception 'Official URL host does not match the registered source';
  end if;

  if v_review.category = 'recruitment' then
    v_required := array['notice_document_opened','dates_verified','vacancies_verified',
                        'eligibility_verified','application_link_verified','duplicate_checked'];
  else
    v_required := array['notice_document_opened','duplicate_checked'];
  end if;
  foreach v_key in array v_required loop
    if coalesce((p_verification ->> v_key)::boolean,false) is not true then
      raise exception 'Required verification is incomplete: %', v_key;
    end if;
  end loop;

  update public.government_notice_reviews
  set title = btrim(p_title),
      official_url = p_official_url,
      notice_reference = nullif(btrim(p_notice_reference),''),
      notice_date = p_notice_date,
      application_start = p_application_start,
      application_end = p_application_end,
      vacancies = p_vacancies,
      eligibility_summary = nullif(btrim(p_eligibility_summary),''),
      details = coalesce(p_details,'{}'::jsonb) || jsonb_build_object(
        'authority', v_source.authority,
        'scope', v_source.scope,
        'state', v_source.state
      ),
      verification = coalesce(p_verification,'{}'::jsonb),
      status = 'published',
      verification_method = 'admin_official_document_review',
      verified_at = now(),
      verified_by = auth.uid(),
      updated_at = now()
  where id = p_review_id;

  insert into public.government_notices (
    review_id,title,category,official_url,notice_reference,notice_date,
    application_start,application_end,vacancies,eligibility_summary,details,is_active,published_at,updated_at
  ) values (
    p_review_id,btrim(p_title),v_review.category,p_official_url,
    nullif(btrim(p_notice_reference),''),p_notice_date,
    p_application_start,p_application_end,p_vacancies,
    nullif(btrim(p_eligibility_summary),''),
    coalesce(p_details,'{}'::jsonb) || jsonb_build_object(
      'authority',v_source.authority,'scope',v_source.scope,'state',v_source.state
    ),
    true,now(),now()
  )
  on conflict (review_id) do update set
    title=excluded.title, category=excluded.category, official_url=excluded.official_url,
    notice_reference=excluded.notice_reference, notice_date=excluded.notice_date,
    application_start=excluded.application_start, application_end=excluded.application_end,
    vacancies=excluded.vacancies, eligibility_summary=excluded.eligibility_summary,
    details=excluded.details, is_active=true, updated_at=now();

  return jsonb_build_object('ok',true,'review_id',p_review_id,'status','published');
end;
$$;

create or replace function public.tc_admin_reject_government_notice(
  p_review_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not private.is_super_admin() then
    raise exception 'Super admin access required';
  end if;
  if nullif(btrim(p_reason),'') is null then
    raise exception 'Rejection reason is required';
  end if;
  update public.government_notice_reviews
  set status='rejected', rejection_reason=btrim(p_reason),
      verified_by=auth.uid(), verified_at=now(), updated_at=now()
  where id=p_review_id and status in ('pending','verified');
  if not found then raise exception 'Review record not found or no longer pending'; end if;
  return jsonb_build_object('ok',true,'review_id',p_review_id,'status','rejected');
end;
$$;

revoke all on function public.tc_admin_publish_government_notice(uuid,text,text,text,date,date,date,integer,text,jsonb,jsonb) from public, anon;
revoke all on function public.tc_admin_reject_government_notice(uuid,text) from public, anon;
grant execute on function public.tc_admin_publish_government_notice(uuid,text,text,text,date,date,date,integer,text,jsonb,jsonb) to authenticated;
grant execute on function public.tc_admin_reject_government_notice(uuid,text) to authenticated;

commit;
