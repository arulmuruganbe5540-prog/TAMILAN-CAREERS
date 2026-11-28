-- Plan 6: enforce translation review gates in the database, not only in the admin UI.
-- Original English job records remain untouched. The source snapshot's original fields
-- are immutable; only the official-source audit metadata may be updated.

create or replace function private.enforce_tamil_translation_review()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_check jsonb;
begin
  if tg_op = 'UPDATE' then
    if (old.source_snapshot - '_official_source_check')
       is distinct from
       (new.source_snapshot - '_official_source_check') then
      raise exception 'The original English source snapshot is immutable.';
    end if;

    if old.translation_status = 'approved'
       and new.translation_status = 'approved'
       and old.translated_content is distinct from new.translated_content then
      raise exception 'An approved Tamil translation must be returned to review before its content can be edited.';
    end if;
  end if;

  if new.translation_status in ('pending_review', 'approved')
     and (
       pg_catalog.btrim(coalesce(new.translated_content ->> 'job_title', '')) = ''
       or pg_catalog.btrim(coalesce(new.translated_content ->> 'description', '')) = ''
     ) then
    raise exception 'Tamil job title and description are required before review submission.';
  end if;

  if new.translation_status = 'approved' then
    if tg_op <> 'UPDATE' then
      raise exception 'A translation must be submitted for review before approval.';
    end if;

    if old.translation_status <> 'pending_review' then
      raise exception 'Only a pending-review translation can be approved.';
    end if;

    v_check := new.source_snapshot -> '_official_source_check';

    if coalesce(v_check ->> 'status', '') <> 'verified'
       or pg_catalog.btrim(coalesce(v_check ->> 'verified_url', '')) = ''
       or pg_catalog.btrim(coalesce(v_check ->> 'notes', '')) = ''
       or coalesce(v_check ->> 'admin_confirmed_original_source_opened', 'false') <> 'true'
       or coalesce(v_check ->> 'verified_at', '') = '' then
      raise exception 'Official source verification and explicit confirmation are required before approval.';
    end if;

    if new.reviewed_by is distinct from auth.uid() or new.reviewed_at is null then
      raise exception 'The approving Super Admin and review timestamp must be recorded.';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_tamil_translation_review() from public, anon, authenticated;

drop trigger if exists government_translation_review_guard on public.government_job_translations;
create trigger government_translation_review_guard
before insert or update on public.government_job_translations
for each row execute function private.enforce_tamil_translation_review();

drop trigger if exists private_translation_review_guard on public.private_job_translations;
create trigger private_translation_review_guard
before insert or update on public.private_job_translations
for each row execute function private.enforce_tamil_translation_review();
