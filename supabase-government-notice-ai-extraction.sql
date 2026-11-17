-- TAMILAN CAREERS: AI-assisted extraction status for official government notices
-- Safe to re-run. This does not publish notices or change public visibility.

alter table public.government_notice_reviews
  add column if not exists ai_extraction_status text not null default 'pending',
  add column if not exists ai_extraction_error text,
  add column if not exists ai_extracted_at timestamptz,
  add column if not exists ai_extraction_model text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.government_notice_reviews'::regclass
      and conname='government_notice_reviews_ai_extraction_status_check'
  ) then
    alter table public.government_notice_reviews
      add constraint government_notice_reviews_ai_extraction_status_check
      check (ai_extraction_status in ('pending','processing','completed','failed','skipped'));
  end if;
end $$;

create index if not exists government_notice_reviews_ai_extraction_idx
  on public.government_notice_reviews(ai_extraction_status, created_at)
  where status='pending';
