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
  v_is_tamil_nadu boolean := false;
begin
  -- Enforce the Plan 6 regional boundary in the database as well as the admin UI.
  if tg_table_name = 'government_job_translations' then
    select exists (
      select 1
      from public.government_jobs j
      where j.id = new.job_id
        and lower(btrim(coalesce(j.state_name, ''))) in ('tamil nadu', 'tamilnadu', 'tn')
        and lower(btrim(coalesce(j.government_scope, ''))) in ('state', 'state government')
    ) into v_is_tamil_nadu;
  elsif tg_table_name = 'private_job_translations' then
    select exists (
      select 1
      from public.private_jobs j
      where j.id = new.job_id
        and (
          lower(coalesce(j.location, '')) like '%tamil nadu%'
          or lower(coalesce(j.location, '')) like '%tamilnadu%'
          or (
            (lower(btrim(coalesce(j.country_name, ''))) = 'india'
             or lower(btrim(coalesce(j.location, ''))) = 'india'
             or lower(btrim(coalesce(j.location, ''))) like '%, india'
             or lower(btrim(coalesce(j.location, ''))) like '% india')
            and split_part(regexp_replace(lower(btrim(coalesce(j.location, ''))), '[ ,|].*$', ''), ' ', 1) in (
              'chennai','salem','namakkal','coimbatore','madurai','erode','vellore',
              'tiruppur','thanjavur','tirunelveli','kanchipuram','cuddalore','dindigul',
              'karur','krishnagiri','dharmapuri','villupuram','kallakurichi','perambalur',
              'ariyalur','sivaganga','virudhunagar','thoothukudi','tenkasi','nilgiris',
              'ooty','ranipet','chengalpattu','tiruvallur','mayiladuthurai','nagapattinam',
              'pudukkottai','ramanathapuram','tiruchirappalli','trichy'
            )
          )
        )
    ) into v_is_tamil_nadu;
  end if;

  if not v_is_tamil_nadu then
    raise exception 'Tamil translations are restricted to Tamil Nadu State Government and Tamil Nadu-located Indian Private jobs.';
  end if;

  if tg_op = 'UPDATE' then
    if new.job_id is distinct from old.job_id
       or new.language_code is distinct from old.language_code then
      raise exception 'A translation record cannot be reassigned to another job or language.';
    end if;

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

  if new.translation_status <> 'approved'
     and (new.reviewed_by is not null or new.reviewed_at is not null) then
    raise exception 'Review identity and timestamp may only be set on approved translations.';
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
       or pg_catalog.btrim(coalesce(v_check ->> 'verified_url', '')) !~* '^https://[^[:space:]]+'
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


-- Append-only audit history: preserve every translation draft, review, approval,
-- source-verification change and later correction with the authenticated actor.
create table if not exists private.translation_review_audit (
  id bigint generated always as identity primary key,
  translation_table text not null check (translation_table in ('government_job_translations','private_job_translations')),
  translation_id uuid not null,
  job_id uuid not null,
  action text not null check (action in ('INSERT','UPDATE')),
  actor_id uuid,
  old_status text,
  new_status text not null,
  source_snapshot jsonb not null,
  translated_content jsonb not null,
  recorded_at timestamptz not null default pg_catalog.now()
);

revoke all on table private.translation_review_audit from public, anon, authenticated;

create or replace function private.record_tamil_translation_audit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into private.translation_review_audit (
    translation_table, translation_id, job_id, action, actor_id,
    old_status, new_status, source_snapshot, translated_content
  ) values (
    tg_table_name,
    new.id,
    new.job_id,
    tg_op,
    auth.uid(),
    case when tg_op = 'UPDATE' then old.translation_status else null end,
    new.translation_status,
    new.source_snapshot,
    new.translated_content
  );
  return new;
end;
$$;

revoke all on function private.record_tamil_translation_audit() from public, anon, authenticated;

drop trigger if exists government_translation_audit_log on public.government_job_translations;
create trigger government_translation_audit_log
after insert or update on public.government_job_translations
for each row execute function private.record_tamil_translation_audit();

drop trigger if exists private_translation_audit_log on public.private_job_translations;
create trigger private_translation_audit_log
after insert or update on public.private_job_translations
for each row execute function private.record_tamil_translation_audit();
