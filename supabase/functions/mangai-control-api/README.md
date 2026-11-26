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
- Proposal decisions use a database transaction that writes proposal status, Owner approval and immutable audit event together; a failed transaction rolls all three back.
- Module pause/resume and proposal creation also use transaction-backed RPCs that append their audit event in the same transaction.
- All three RPCs are executable only by the server-side service role and independently re-check the single Owner binding and Super Admin role.
- The Edge Function requires AAL2 MFA for every POST/write action; read-only GET actions remain authenticated Owner-only.
- Does not offer a production deploy action.
- Does not let automation edit owner identity, role assignments, RLS, MFA, secrets or security policy.
- MFA assurance is implemented as a server-side AAL2 check for write actions. It has not yet been runtime-tested with enrolled MFA; do not deploy or expose mutation controls until isolated runtime tests pass.
- Security governance module cannot be paused from this API.

## Important
Deploy only after the migration is installed and smoke checks pass on an isolated Supabase development branch. Test invalid JWT, non-owner, missing owner binding, CORS, AAL1/AAL2 sessions, each allowed action, concurrent proposal decisions and injected audit failures before UI integration.


## Read-only UI preview
- `mangai-control-center.html` is an English-only Owner workspace that reads overview, modules, proposals and alerts from this function.
- It contains no mutation controls and uses only the signed-in user's access token plus the public anon/publishable key.
- Until this Edge Function is deployed and the migration is installed in an isolated test project, the page must show its API-unavailable state; it is not a live dashboard yet.
