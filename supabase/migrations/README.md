# Mangaiyarkarasi database migration

This folder contains an additive, isolated-development migration for the control registry.

## Apply policy
- Do not run against production directly.
- First create an isolated Supabase development branch after the Owner accepts its hourly compute cost.
- Confirm exactly one current `super_admin` exists. The migration intentionally stops if it finds zero or more than one.
- Apply the migration to the development branch only.
- Run `supabase/tests/mangaiyarkarasi_control_foundation_smoke.sql`.
- Verify that anon/authenticated cannot read control tables and service_role can.
- Verify audit rows cannot be updated/deleted.
- Verify the Owner binding matches the intended Master Owner.

The tables are RLS-enabled with no client policies and explicit grants only to `service_role`. Never expose the service-role key in static website files.
