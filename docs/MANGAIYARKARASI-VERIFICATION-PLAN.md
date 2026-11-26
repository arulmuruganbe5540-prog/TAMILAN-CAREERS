# Mangaiyarkarasi — verification plan

Status: repository-level preparation only. No database-backed or live-site test has been run because no paid Supabase development branch was created. Module pause/resume, proposal creation and proposal decisions are implemented through transaction-backed RPC source, but remain unexecuted until an isolated test database is available.

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
- Module pause/resume, proposal creation and proposal decisions now use transaction-backed PostgreSQL RPCs. Each RPC verifies the Owner binding and Super Admin role and writes its audit event in the same transaction.
- Verify the new RPC signatures and grants with the smoke test; inject audit-write failures for all three RPCs and confirm each business mutation rolls back.
- Test concurrent decisions on the same proposal; only one decision may succeed.
- Confirm the Edge Function has no direct write path for these transactional actions.
- Test concurrent decisions on the same proposal; only one decision may succeed.

## Gate 3 — MFA and session policy
- Required level is AAL2. The Edge Function now checks `auth.mfa.getAuthenticatorAssuranceLevel()` server-side for every POST/write action; read-only GET requests do not mutate state.
- Runtime-test the AAL2 check with an enrolled MFA factor, an AAL1 session, a session without MFA, and an expired session. Confirm AAL1 and missing-MFA writes return 403 and do not mutate data.
- Test session expiry and step-up authentication.
- Until this gate passes, do not deploy the API or expose mutation controls.

## Gate 4 — Admin UI and regression
- Added the English-only read-only Owner workspace at `mangai-control-center.html`; it requests overview, modules, proposals and alerts from the Edge Function using the signed-in user's access token.
- The existing Super Admin home links to this page. The new page has no mutation controls and does not contain a service-role credential.
- Verify the new page redirects signed-out users, rejects users without the existing Super Admin role, displays an unavailable state when the Edge Function is absent, and loads the four read-only views when deployed in an isolated test environment.
- Verify returned database text is rendered as text, not interpreted as HTML.
- Read-only views first; no browser-side service-role credentials.
- Verify all controls are owner-gated by the Edge Function.
- Test mobile layout on Android and desktop layout, including refresh and sign-out.
- Regression-test existing login, registration, government/private/international job forms, employer verification, apply links, and public pages. Confirm the new read-only workspace does not change these flows.
- Confirm internal scanner/automation details never appear on public pages.

## Gate 5 — Scheduling and operations
- Add real scheduled checks only after provider credentials, budgets, alert destinations and rate limits are configured.
- Test uptime checks, page/form/API checks, source scanning, Search Console ingestion, alert delivery, and the 20-day review runner.
- Verify pause/resume controls do not stop security logging or critical safeguards.
- Add backup inventory, restore rehearsal, release rollback and cost limits.

## Release rule
A proposal may be allowed for isolated testing without authorizing production deployment. Production release requires passing all applicable gates, a verified backup/rollback path, and a separate explicit Owner approval. No live changes are made by this repository-only phase.


## Gate 4A — Automated static regression suite
- Added `tests/regression/site-regression.test.mjs`, runnable with Node.js 22 using `node --test tests/regression/site-regression.test.mjs`.
- Added `.github/workflows/site-regression-check.yml` to run it for relevant PR/development-branch changes.
- Coverage includes English/mobile page shells, student/employer login and registration forms, private/international listing separation, distinct application tables, company-market verification gates, Owner Control read-only boundary, public-page isolation and local file links.
- A passing static suite is not proof of runtime authentication, database authorization, resume upload, email delivery, or Android browser behavior. Those remain separate release gates.


## Latest repository CI result — 2026-11-26
- **Passed:** Website Regression Checks (Node.js 22, 8 test groups; static-only coverage).
- **Passed:** Mangaiyarkarasi Control API Checks: Deno format, lint, type-check and static SQL/RPC/MFA guard assertions.
- **Not run:** PostgreSQL migration/smoke SQL, Edge Function runtime authorization, real AAL2 MFA session tests, live form submissions, Android/desktop browser checks, backups/restore and scheduled monitoring.
- CI links: [Website Regression Checks](https://github.com/arulmuruganbe5540-prog/TAMILAN-CAREERS/actions) · [Control API Checks](https://github.com/arulmuruganbe5540-prog/TAMILAN-CAREERS/actions).


## Gate 1A — Ephemeral PostgreSQL integration result (2026-11-26)
- **Passed:** Migration applies to a disposable PostgreSQL 16 instance with a minimal public.user_roles fixture and the expected anon, authenticated, and service_role roles.
- **Passed:** SQL smoke assertions for exactly one Owner binding, Mangai table count, RLS coverage, denied anon/authenticated access, append-only audit permissions, and restricted RPC execution.
- **Passed:** Transaction tests for module pause/resume, proposal creation and proposal decisions. An injected audit insert failure rolled back each associated state change; the healthy decision path committed proposal status, approval and audit together.
- **Passed:** Deno format, lint and type-check; website static regression suite also passed in CI.
- **Scope limitation:** The PostgreSQL 16 job is an ephemeral test container, not a hosted Supabase database. It does not prove Supabase Auth JWT/AAL2, hosted Data API exposure, Edge Function runtime, storage, browser forms or Android behavior. Those gates remain open.
