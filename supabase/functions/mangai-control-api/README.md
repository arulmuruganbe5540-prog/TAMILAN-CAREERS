# Mangaiyarkarasi Control API — deployment notes

This Edge Function is source code only in the development branch. It has NOT been deployed.

## Required server-side secrets
- SUPABASE_URL
- SUPABASE_ANON_KEY
- SUPABASE_SERVICE_ROLE_KEY

Use Supabase Function Secrets; never put the service-role key in a browser, static HTML, GitHub Pages, or chat.

## Security behavior
- Requires a valid Supabase user JWT.
- Checks the caller has the existing super_admin role.
- Checks the caller matches the single Owner ID captured in mangai_owner_config by the migration.
- Uses the service-role client only inside the Edge Function.
- CORS allow-list is restricted to the production domain and GitHub Pages origin.
- Does not expose any service key or Google credential.
- Provides allow-listed read operations and limited module/proposal decisions.
- Does not offer a production deploy action.
- Does not let automation edit owner identity, role assignments, RLS, MFA, secrets or security policy.
- MFA assurance is not yet enforced by this first API version. Do not expose mutation actions in the admin UI or deploy this function until the chosen MFA policy is implemented and tested.
- Security governance module cannot be paused from this API.

## Important
Deploy only after the migration is installed and smoke checks pass on an isolated Supabase development branch. Test invalid JWT, non-owner, missing owner binding, CORS, each allowed action, duplicate requests and audit failures before UI integration.
