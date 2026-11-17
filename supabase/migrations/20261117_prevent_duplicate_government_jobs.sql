-- Prevent duplicate government job publication without AI.
-- Duplicate keys: same recruitment authority + notification number,
-- same official notification URL, or same title + authority + exam year + notice date.
create or replace function public.tc_block_duplicate_government_job()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_key text;
  v_existing_id uuid;
  v_existing_title text;
begin
  if new.job_kind is distinct from 'government' or new.status is distinct from 'published' then return new; end if;
  v_key := case
    when nullif(btrim(new.notification_number), '') is not null then lower(btrim(coalesce(new.recruitment_authority,''))) || '|notice|' || lower(btrim(new.notification_number))
    when nullif(btrim(new.official_notification_url), '') is not null then 'url|' || lower(regexp_replace(btrim(new.official_notification_url), '/+$', ''))
    else lower(btrim(coalesce(new.recruitment_authority,''))) || '|title|' || lower(regexp_replace(btrim(coalesce(new.job_title,'')), '\\s+', ' ', 'g')) || '|' || coalesce(new.exam_year::text,'') || '|' || coalesce(new.notification_date::text,'')
  end;
  perform pg_advisory_xact_lock(hashtextextended(v_key, 0));
  select j.id, j.job_title into v_existing_id, v_existing_title
  from public.jobs j
  where j.id is distinct from new.id and j.job_kind='government' and j.status='published'
    and (
      (nullif(btrim(new.notification_number),'') is not null and nullif(btrim(j.notification_number),'') is not null
       and lower(btrim(coalesce(j.recruitment_authority,'')))=lower(btrim(coalesce(new.recruitment_authority,'')))
       and lower(btrim(j.notification_number))=lower(btrim(new.notification_number)))
      or (nullif(btrim(new.official_notification_url),'') is not null and nullif(btrim(j.official_notification_url),'') is not null
       and lower(regexp_replace(btrim(j.official_notification_url), '/+$', ''))=lower(regexp_replace(btrim(new.official_notification_url), '/+$', '')))
      or (lower(regexp_replace(btrim(coalesce(j.job_title,'')), '\\s+', ' ', 'g'))=lower(regexp_replace(btrim(coalesce(new.job_title,'')), '\\s+', ' ', 'g'))
       and lower(btrim(coalesce(j.recruitment_authority,'')))=lower(btrim(coalesce(new.recruitment_authority,'')))
       and new.exam_year is not null and j.exam_year=new.exam_year
       and j.notification_date is not distinct from new.notification_date)
    ) limit 1;
  if v_existing_id is not null then
    raise exception 'Duplicate government job: "%" already exists (job id %)', v_existing_title, v_existing_id using errcode='23505';
  end if;
  return new;
end;
$$;
drop trigger if exists tc_jobs_prevent_duplicate_government_publish on public.jobs;
create trigger tc_jobs_prevent_duplicate_government_publish
before insert or update of job_kind,status,job_title,recruitment_authority,notification_number,official_notification_url,exam_year,notification_date
on public.jobs for each row execute function public.tc_block_duplicate_government_job();
