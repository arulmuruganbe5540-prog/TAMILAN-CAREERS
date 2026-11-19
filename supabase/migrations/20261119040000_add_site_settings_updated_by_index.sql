-- Cover the site_settings.updated_by foreign key for efficient user deletion/update checks.
create index if not exists idx_site_settings_updated_by
  on public.site_settings (updated_by);
