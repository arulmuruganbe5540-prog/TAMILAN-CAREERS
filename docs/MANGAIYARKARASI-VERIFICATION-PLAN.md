# Mangaiyarkarasi — verification plan

Status: repository-level preparation only. No database-backed or live-site test has been run because no paid Supabase development branch was created.

## Gate 1 — Database migration (isolated development project only)
- Confirm there is exactly one existing `user_roles.role = 'super_admin'` row. The migration must fail closed if the count is zero or greater than one.
- Apply the additive migration only to a disposable/isolated development database.
- Run `supabase/tests/mangaiyarkarasi_control_foundation_smoke.sql`; every assertion must pass.
- Confirm RLS is enabled on every `mangai_%` table.
- Confirm anon/authenticated have no access to control tables.
- Confirm service_role can append audit events but cannot update/delete them.
- Confirm the Owner binding contains exactly one user and matches the intended existing Super Admin.

## Gate 2 — Edge Function security tests
- No Authorization header: 401.
- Expired, malformed, or invalid JWT: 401.
- Authenticated non-Super-Admin: 403.
- Super Admin whose user ID differs from the Owner binding: 403.
- Missing/duplicate Owner binding or database permission failure: fail closed.
- Unapproved Origin preflight: 403.
- Unsupported HTTP method and unknown action: rejected.
- Security governance pause attempt: 403.
- Production deploy/approve action: rejected (409).
- Invalid JSON, malformed IDs, oversized text fields and unknown module IDs: rejected safely.
- Each accepted mutation must have a corresponding immutable audit record.
- Inject audit-write failure and verify no partial state change is left behind; if the implementation cannot guarantee this atomically, disable that mutation until it is made transactional.
- Test concurrent decisions on the same proposal; only one decision may succeed.

## Gate 3 — MFA and session policy
- Select and document the required Supabase MFA assurance level.
- Enforce that assurance level server-side for every mutation, not merely by hiding buttons.
- Test session expiry and step-up authentication.
- Until this gate passes, do not deploy the API or expose mutation controls.

## Gate 4 — Admin UI and regression
- Read-only views first; no browser-side service-role credentials.
- Verify all controls are owner-gated by the Edge Function.
- Test mobile layout on Android and desktop layout.
- Regression-test existing login, registration, government/private/international job forms, employer verification, apply links, and public pages.
- Confirm internal scanner/automation details never appear on public pages.

## Gate 5 — Scheduling and operations
- Add real scheduled checks only after provider credentials, budgets, alert destinations and rate limits are configured.
- Test uptime checks, page/form/API checks, source scanning, Search Console ingestion, alert delivery, and the 20-day review runner.
- Verify pause/resume controls do not stop security logging or critical safeguards.
- Add backup inventory, restore rehearsal, release rollback and cost limits.

## Release rule
A proposal may be allowed for isolated testing without authorizing production deployment. Production release requires passing all applicable gates, a verified backup/rollback path, and a separate explicit Owner approval. No live changes are made by this repository-only phase.
