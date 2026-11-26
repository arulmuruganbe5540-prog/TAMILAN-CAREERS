# Mangaiyarkarasi implementation log

## 2026-11-26 — Phase 1A (repository-only, no production changes)
- Inspected the existing GitHub repository and Supabase project.
- Confirmed the current project already has independent government_jobs, private_jobs and international_jobs tables.
- Confirmed existing SEO foundation tables: seo_job_profiles, seo_keyword_metrics and seo_engine_runs.
- Confirmed existing Edge Functions include government/external job scanners, external candidate analysis and google-indexing-notify.
- Confirmed one current user_roles row has role=super_admin; the control migration will bind the Owner to the existing single Super Admin at migration time and fail closed if the count is not exactly one.
- Added the initial isolated control-registry migration file and read-only smoke-check SQL.
- Added the Owner-gated control API source, JWT verification configuration and allow-listed actions; production deployment action is deliberately disabled.
- Added a GitHub Actions Deno type-check workflow. The first check exposed a strict TypeScript closure-narrowing issue; it was fixed and the latest Deno check completed successfully.
- Added PR #7 as a draft for review; no merge or production release has occurred.
- No Supabase migration has been applied. No Supabase development database branch has been created. No production database, live page, secret, schedule or auth policy has been changed.

## 2026-11-26 — Phase 1B (repository-only hardening)
- Strengthened the read-only SQL smoke script with fail-fast assertions for single-owner binding, RLS coverage, denied public access and append-only audit permissions.
- Clarified in the Edge Function deployment notes that MFA assurance is not yet enforced; the function must not be deployed or exposed with mutation controls until server-side MFA enforcement is implemented and tested.
- Added a staged verification plan covering database, API authorization, audit atomicity, MFA, mobile regression, monitoring, backup and release gates.
- No Supabase development branch was created and no recurring compute charge was incurred. No production system was changed.

## 2026-11-26 — Phase 1C (transaction safety)
- Added a server-side PostgreSQL transaction function for proposal decisions. Proposal status, Owner approval history and immutable audit event are now committed together or rolled back together.
- The transaction function independently verifies the single Owner binding and existing Super Admin role, and its execute permission is restricted to service_role.
- Updated the Edge Function to call the transactional RPC rather than performing separate proposal, approval and audit writes.
- Extended the SQL smoke assertions and CI guards for the restricted RPC.
- GitHub Actions run details were not returned for the latest commits, so CI is not marked as passed. The migration and RPC have not been executed against a database.

## 2026-11-26 — Phase 1D (MFA write gate)
- Added a server-side Supabase Authenticator Assurance Level check to the Edge Function. Every POST/write action now requires the current session to be AAL2; read-only GET operations remain Owner-authenticated.
- Updated deployment notes and CI static guards to require the AAL2 check.
- This is source-level implementation only. It still needs runtime verification with an enrolled MFA factor in an isolated Supabase environment; the function remains undeployed.
- GitHub Actions run details were not returned for the latest commit, so CI is not marked as passed.

## Next phases (without a paid Supabase branch)
1. Continue repository-only development: API validation, safer transactional decisions, automated static/security checks and admin UI integration source.
2. Add isolated test fixtures and documented manual test commands that do not require production credentials.
3. When a real database-backed test is required, ask before creating any paid Supabase development environment; alternatively use a separately approved local/test Postgres environment.
4. Do not deploy or expose mutation controls until the MFA, audit atomicity and database permission gates in docs/MANGAIYARKARASI-VERIFICATION-PLAN.md pass.
5. Add Search Console ingestion, scheduled monitoring, alert delivery and the 20-day review runner only after credentials, schedules and cost limits are approved.
6. Complete full website regression, permission, restore and Android mobile checks before proposing any production release.


## 2026-11-26 — Phase 1E (atomic mutation paths)
- Repaired the PostgreSQL function dollar-quoting delimiter in the proposal-decision RPC source.
- Added transaction-backed RPCs for module pause/resume and proposal creation. Each RPC independently checks the single Master Owner binding and Super Admin role, rejects security-governance changes, and writes its immutable audit event in the same database transaction as the state change.
- Routed the Edge Function mutation handlers through those RPCs; an audit insert failure now rolls back the associated mutation rather than leaving an unaudited partial change.
- Expanded SQL smoke assertions for the new RPC execute grants and expanded CI static guards.
- These changes are committed to the review branch only. The SQL has not been executed against PostgreSQL, the Edge Function has not been deployed, and runtime behavior is not yet verified.


## 2026-11-26 — Phase 1F (read-only Owner UI integration)
- Added `mangai-control-center.html`, an English-only, responsive, Owner-session-gated Control Center page.
- The page uses the existing public Supabase key plus the signed-in user's access token; it never embeds or requests the service-role key.
- It checks the signed-in user and existing `super_admin` role, then reads overview, module registry, change proposals and alerts through the `mangai-control-api` Edge Function.
- The page uses DOM `textContent` for returned database values and provides an explicit unavailable state when the Edge Function or migration is not installed.
- No write controls are exposed. Production deployment remains disabled.
- Added a link to the new page in the existing Super Admin control section.
- UI source was statically inspected for English document language, auth checks, API path, absence of service-role credentials and absence of mutation actions. No browser/mobile runtime test has been run.
- This is still a review-branch preview: no live site, database, auth configuration or Edge Function was changed.


## 2026-11-26 — Phase 1G (website regression guard)
- Mapped the existing student and employer authentication pages, separate private/international job listing and application pages, and company profile/verification/posting portal before adding tests.
- Added dependency-free Node.js regression tests for required English/mobile page shells, separate login/register forms, private/international table routing, isolated application tables, independent company verification gates, read-only Owner Control preview, public-page isolation and local-link resolution.
- Added a GitHub Actions workflow to run the regression suite on relevant pull-request and development-branch changes.
- Added test coverage documentation. These are static source checks only; they do not simulate sign-in, submit forms, query Supabase, validate RLS, or replace Android/browser runtime tests.
- Existing website pages and production systems were not modified. All additions remain in the open draft PR; workflow execution must be checked before marking the suite as passing.


## 2026-11-26 — Phase 1H (CI verification)
- The website static regression workflow passed: 8 test groups passed, 0 failed (Node.js 22). This verifies repository structure and static contracts only, not runtime sign-in or Supabase behavior.
- The Mangaiyarkarasi Control API workflow passed Deno format, lint, type-check and all static SQL/RPC/MFA guard assertions on commit `990a6ec17e4d05369fd3c37731925238178cbd1d`.
- CI fixes: applied Deno formatting, moved the Supabase JS dependency into the function-local Deno import map, removed an unused variable, passed the function-local Deno config explicitly to type-check, and aligned static guards with formatted RPC calls.
- CI success does not execute the SQL migration or run live database/MFA/browser tests. No Supabase migration was applied, no Edge Function deployed, and no production website/auth/secrets/schedules were changed.


## 2026-11-26 — Phase 1I (ephemeral PostgreSQL integration verification)
- Fixed the smoke-test DO block closing delimiter, then added a dependency-free PostgreSQL 16 CI integration job using a disposable GitHub Actions service container. No Supabase project or paid database branch is used.
- The job creates minimal Supabase-compatible roles and one Owner fixture, applies the additive migration, runs RLS/grant/append-only smoke assertions, and tests all three transaction-backed RPCs.
- Injected audit-insert failures and verified module state, proposal creation, proposal decision, approval history and audit rows roll back together. The successful decision path also commits the expected status and approval row.
- Latest CI run for commit 905036fdbc7baaf0aa4b81dee1e6e3b59998dc1e: PostgreSQL integration job PASSED; Deno format/lint/type-check and static security guards PASSED.
- This verifies the migration against vanilla PostgreSQL 16 with a minimal compatibility fixture, not against the hosted Supabase project. Live Auth JWT/AAL2, Supabase RLS/Data API behavior, Edge Function deployment and browser/mobile flows remain untested. No production system was changed.


## 2026-11-26 — Phase 1J (mobile browser smoke coverage)
- Added `tests/browser/site-smoke.mjs` and `.github/workflows/site-browser-check.yml` using Playwright + Chromium in GitHub Actions. The test uses a local static server and a mocked Supabase client; it does not contact or mutate the hosted Supabase project.
- **Passed on commit `630ba4f34f7f3e2bb47af64516bb643a903d25fe`:** 10 page loads; mobile viewport declarations; Student and Employer login/register tab switching; password mismatch validation before submission; password visibility controls; sign-in guards on Company Portal and both application forms; Government/Private/International page identity labels.
- Browser run: https://github.com/arulmuruganbe5540-prog/TAMILAN-CAREERS/actions/runs/45850823649
- Control API Deno checks and ephemeral PostgreSQL migration/RLS/transaction tests also passed on the same commit.
- **Not tested:** real Supabase Auth, email confirmation, actual login/register, MFA/AAL2 session enforcement, live database RLS, real job submission/application, file upload, desktop physical device, or Android phone. Browser test mocks the Supabase client and must not be represented as an end-to-end backend test.
- No production website, Supabase project, secrets, schedules or live database were changed. PR #7 remains open and draft.


## 2026-11-26 — Executable authorization policy coverage
- Added a shared pure-policy module for Master Owner identity/role matching, fail-closed registry errors, AAL2 write assurance, protected security-governance controls, and disabled production release actions.
- Wired the Edge Function to call the same policy helpers covered by unit tests; invalid JWTs still fail fast with HTTP 401 before privileged registry queries.
- Added seven Deno unit-test groups covering the policy decisions and wired format, lint, type-check, and test commands into the Control API workflow.
- The first CI attempt confirmed the ephemeral PostgreSQL integration and browser smoke jobs passed, while Deno format check failed on import/assert formatting. Formatting was corrected and the workflow YAML was split into separate type-check and test steps. A fresh CI result for the corrected commit has not yet been confirmed; do not treat these new unit tests as passed until that run is observed.
- No Supabase migration or Edge Function deployment was performed; all changes remain in the review branch.

- Follow-up CI diagnosis: formatting and lint passed after the import-map adjustment; type-check then exposed a missing `200` member in the Owner-gate result union. Expanded the union to include the successful status. The corrected commit is awaiting a fresh CI result.
