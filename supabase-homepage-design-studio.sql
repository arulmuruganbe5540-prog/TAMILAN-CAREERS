-- TAMILAN CAREERS — Homepage Design Studio persistence
-- Apply via Supabase migration tooling. Safe to re-run.
create table if not exists public.site_settings (
  setting_key text primary key check (setting_key = 'homepage'),
  site_name text not null default 'TAMILAN CAREERS',
  headline text not null default 'உங்கள் திறமைக்கு ஏற்ற வேலை இங்கே!',
  subtitle text not null default 'இந்தியா முழுவதும் அரசு மற்றும் தனியார் வேலைவாய்ப்புகளை ஒரே இடத்தில் தேடுங்கள். தமிழிலும் ஆங்கிலத்திலும் உங்கள் அடுத்த வாய்ப்பைத் தொடங்குங்கள்.',
  primary_color text not null default '#101d3a' check (primary_color ~ '^#[0-9A-Fa-f]{6}$'),
  banner_path text,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);
alter table public.site_settings enable row level security;
drop policy if exists "Public can read homepage site settings" on public.site_settings;
create policy "Public can read homepage site settings" on public.site_settings
  for select to anon, authenticated using (setting_key = 'homepage');
drop policy if exists "Super admins insert homepage site settings" on public.site_settings;
create policy "Super admins insert homepage site settings" on public.site_settings
  for insert to authenticated with check (
    setting_key = 'homepage' and (select private.is_super_admin())
  );
drop policy if exists "Super admins update homepage site settings" on public.site_settings;
create policy "Super admins update homepage site settings" on public.site_settings
  for update to authenticated using ((select private.is_super_admin()))
  with check (setting_key = 'homepage' and (select private.is_super_admin()));
grant select on public.site_settings to anon, authenticated;
grant insert, update on public.site_settings to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('site-assets', 'site-assets', true, 5242880, array['image/png','image/jpeg','image/webp'])
on conflict (id) do update set public = true, file_size_limit = 5242880,
  allowed_mime_types = array['image/png','image/jpeg','image/webp'];
drop policy if exists "Super admins upload site assets" on storage.objects;
create policy "Super admins upload site assets" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'site-assets' and (select private.is_super_admin())
  );
drop policy if exists "Super admins update site assets" on storage.objects;
create policy "Super admins update site assets" on storage.objects
  for update to authenticated using (
    bucket_id = 'site-assets' and (select private.is_super_admin())
  ) with check (
    bucket_id = 'site-assets' and (select private.is_super_admin())
  );
drop policy if exists "Super admins delete site assets" on storage.objects;
create policy "Super admins delete site assets" on storage.objects
  for delete to authenticated using (
    bucket_id = 'site-assets' and (select private.is_super_admin())
  );

-- Seed the first default homepage configuration without overwriting later Admin edits.
insert into public.site_settings (setting_key, site_name, headline, subtitle, primary_color)
values (
  'homepage',
  'TAMILAN CAREERS',
  'உங்கள் திறமைக்கு ஏற்ற வேலை இங்கே!',
  'இந்தியா முழுவதும் அரசு மற்றும் தனியார் வேலைவாய்ப்புகளை ஒரே இடத்தில் தேடுங்கள். தமிழிலும் ஆங்கிலத்திலும் உங்கள் அடுத்த வாய்ப்பைத் தொடங்குங்கள்.',
  '#101d3a'
)
on conflict (setting_key) do nothing;
