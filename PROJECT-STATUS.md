# TAMILAN CAREERS — Project Status & Handover

Last live audit: 17 November 2026 (India time)  
Repository: `arulmuruganbe5540-prog/TAMILAN-CAREERS`  
Live Pages: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/

This status distinguishes committed website code from verified live Supabase configuration. A deployed page or Edge Function is not proof that a real authenticated workflow has passed end-to-end testing.

## 1. GitHub Pages and CI

- GitHub Pages is enabled and deploying successfully. Latest confirmed Pages deployment: run `44085240569`, commit `ff17f5fbd1f3b39845d2c9bc03f40ba50f359960` (success). A newer build for the latest team-page permission refinement is running.
- Latest confirmed full website Health Audit: run `44085131126`, commit `686da22cc2de92db0e17da16f6454aa4834817f8` (success). Deno Edge Function checks, SQL delimiter lint, privacy guards, website structure, JavaScript checks, and browser smoke tests all passed.
- A newer Health Audit is running for the latest company-team page permission refinement. Do not treat that run as passed until its final conclusion is success.
- CI now checks the tracked `company-members` Edge Function and browser smoke tests for the company team page and safe missing-token handling on the invitation page.

## 2. Recent security and database work verified live

- Candidate salary, preferred-location, and relocation preferences remain private to the candidate; the employer SELECT policy was removed.
- Thirty missing public foreign-key indexes were added. The latest FK audit returned zero unindexed public foreign keys.
- The job-offer Storage SELECT policy had an over-escaped PDF filename expression that rejected valid UUID/UUID.pdf paths. The policy now uses the correct regex; a SQL test with a representative UUID/PDF path returned true.
- The company-invitation acceptance RPC now has an empty search_path and is executable only by `service_role`.
- Authorization-only RLS helpers were moved from exposed `public` into the non-exposed `private` schema: `can_access_company`, `can_access_job_application`, `can_company_view_candidate`, and `is_super_admin`. Public helper EXECUTE permissions were revoked; authenticated users can execute the private helpers for RLS evaluation.
- Simulated authenticated SQL checks verified: the existing company owner can access their company; an unrelated company, nonexistent application, and unrelated candidate are denied; the current non-admin user is not a Super Admin; exposed public helper RPCs are not callable.
- Security advisor warnings for exposed RLS helper functions reduced from 11 to 7. The remaining seven SECURITY DEFINER RPCs are application actions (Admin publish, candidate withdrawal, company application status, notification read, interview response/send) with empty search_path and user/role checks. They remain callable by authenticated users because the website needs those protected actions.
- Security advisor INFO notices remain for `company_invitations` and `job_sources`: RLS is enabled with no client policies. These tables are intentionally service-role / backend-only.
- Leaked-password protection remains disabled in Supabase Auth; this is still a security improvement to configure in project Auth settings.
- Performance advisor currently reports 12 auth-RLS init-plan notices, 15 multiple-permissive-policy notices, and 72 unused-index INFO notices. Health advisor returned no findings.

## 3. Resume and job-offer Storage

- Live Resume bucket: `candidate-resumes`, private, 10 MB bucket limit. `resume-documents.html` and the active `company-resume-access` Edge Function both use this exact bucket.
- `company-resume-access` is ACTIVE version 1 with JWT verification. It verifies application status, company ownership / active company membership, candidate ownership, and the candidate folder path before returning a 60-second signed URL.
- The Resume page stores metadata in `candidate_resumes`, checks for a Job Seeker profile, and enforces file type, 5 MB page limit, and five-document limit.
- Job-offer Storage access now calls the private application-authorization helper and validates the UUID/UUID.pdf object path.
- Live data currently has zero Resume records, zero Resume Storage objects, zero job-offer objects, and zero job applications. Real upload, application attachment, signed URL expiry, and cross-company denial still need end-to-end tests.

## 4. Company Member Management

- Edge Function `company-members` is ACTIVE version 4 with JWT verification. Its tracked source is `supabase/functions/company-members/index.ts`.
- Supported actions: list companies, list members, list pending invitations, invite, accept invitation, cancel invitation, update role, and remove member.
- Owners can invite/manage HR Managers, Recruiters, and Viewers. Active HR Managers can manage Recruiters and Viewers. The function prevents self-removal, self-role changes, and owner changes.
- Invitation tokens are random, stored as SHA-256 hashes, expire after seven days, and are not returned by list actions. Acceptance requires a confirmed signed-in email matching the invited email.
- New website pages: `company-members.html` and `accept-invitation.html`. Dashboard, Company Profile, and Company Applicants pages link to team management.
- Email delivery requires Supabase Function Secrets `RESEND_API_KEY` and `APP_BASE_URL`; optional `RESEND_FROM_EMAIL` should be a verified Resend sender. These values are not confirmed configured. See `COMPANY-MEMBERS-SETUP.md`.
- Live database currently has one company and one active owner member, zero invitations, and no second confirmed account. Real invitation email, acceptance, role change, and removal tests remain outstanding.
- `manage-hiring` remains a legacy login/role-status function; do not mistake it for the active `company-members` implementation.

## 5. Active Supabase Edge Functions

| Function | Live state | Notes |
|---|---|---|
| `company-members` | ACTIVE v4, JWT on | Team membership and invitations |
| `company-resume-access` | ACTIVE v1, JWT on | 60-second authorized Resume links |
| `scan-external-job-sources` | ACTIVE v2, JWT off | Uses its own `x-monitor-secret` authentication |
| `ingest-government-notices` | ACTIVE v1, JWT off | Uses its own `x-monitor-secret` authentication |
| `bilingual-job-search` | ACTIVE v1, JWT on | Requires `OPENAI_API_KEY` |
| `ai-resume-match` | ACTIVE v1, JWT on | Requires `OPENAI_API_KEY` |
| `manage-hiring` | ACTIVE v3, JWT off | Legacy basic login/role-status handler |

- External scanner v2 now uses bounded streaming reads, HTTPS-domain and redirect checks, robots.txt checks, HTML content-type checks, manual-source skipping, and per-source success/failure status.
- The external scanner and Government ingestion functions require `GOVERNMENT_MONITOR_SECRET`. The user explicitly asked to defer this secret setup; do not prompt for it during routine work. Deployment is complete, but scheduled ingestion cannot authenticate until the secret is configured.
- AI Resume Match and bilingual search are deployed, but their OpenAI-backed actions will return a configuration error until `OPENAI_API_KEY` is added to Supabase Function Secrets. Never put that key in website code or GitHub.

## 6. Other installed workflows

- Candidate education, experience, skills, languages, and certification tables are present with RLS; candidate profile save/read testing still needs real accounts.
- Company job draft → Admin review → verified-company publish workflow is installed in SQL/source. Real Super Admin and employer workflow tests remain outstanding.
- Interview invitations, candidate accept/decline, notifications, application status updates, and the 15-minute reminder cron job are installed. A transactional smoke test passed and rolled back all test data; separate real Candidate and Employer account testing remains outstanding.
- Government notice sources, private review queue, and publication archive remain separate from Private Jobs. Discovered external links are not automatically published.

## 7. Current live data and launch blockers

Live database snapshot:
- 1 company; 1 active owner membership; 0 invitations.
- 0 jobs; 0 applications; 0 Resume metadata records; 0 Resume Storage objects; 0 job-offer objects.
- Only one auth user is present, so cross-account workflows cannot yet be tested.

Still required before launch:
1. Confirm the latest Pages build and latest Health Audit both finish successfully after the most recent company-team page change.
2. Configure Resend secrets before testing real company invitations.
3. Configure `OPENAI_API_KEY` before testing AI Resume Match and bilingual AI search.
4. Keep `GOVERNMENT_MONITOR_SECRET` deferred until the user chooses to configure it.
5. Run real Candidate, Employer/HR, Super Admin, invitation, Resume upload/view/expiry, interview response, and cross-company denial tests using separate accounts.
6. Enable Supabase Auth leaked-password protection.
7. Review remaining performance advisor notices and intended authenticated SECURITY DEFINER RPCs.

## 17 November 2026 follow-up audit

- Latest Pages deployment run `44085660477` completed successfully for commit `e3d9a78013254cb0c78b9bf1cd4dd7f76a9e5b58`; build, deploy, and report steps all passed.
- Latest full Health Audit run `44085660992` completed successfully for the same commit. All 17 audit steps passed, including Deno type-check for all Edge Functions, SQL dollar-quote lint, privacy guards, JavaScript checks, and browser smoke tests.
- The active database function scan found only `tc_admin_publish_job(uuid)` calling `private.is_super_admin()`; no other public application function still calls the revoked public helper. The public `is_super_admin()` function itself remains present but its public execute permissions were revoked.
- Current live count rechecked: 1 Auth user, 1 company, 1 company membership, and 0 jobs. Separate Candidate, Employer/HR, and Super Admin journeys cannot be fully verified until separate real accounts and real test records exist.
- Current security advisor: 7 authenticated SECURITY DEFINER application RPC warnings (intentionally used by signed-in app workflows and guarded in function bodies), 2 backend-only RLS/no-client-policy INFO notices (`company_invitations`, `job_sources`), and leaked-password protection WARN (still disabled).
- Current performance advisor: 12 auth-RLS init-plan notices, 15 multiple-permissive-policy notices, and 72 unused-index INFO notices. Unused-index notices are not proof those indexes should be dropped; retain them until production query patterns justify removal. Health advisor returned no findings.
- Added `CONNECTIONS-AND-LAUNCH-SETUP.md` with the exact external provider connections and dashboard steps: OpenAI `OPENAI_API_KEY`, Resend `RESEND_API_KEY` + `APP_BASE_URL` (+ optional `RESEND_FROM_EMAIL`), and the matching GitHub/Supabase `GOVERNMENT_MONITOR_SECRET`. Government monitoring remains deferred as previously requested.
- No service-role or provider secret was added to public website code or GitHub source.

## 17 November 2026 Admin integration repair

- Found that `admin-control.html` and `admin-job-post.html` still called the old `public.is_super_admin()` RPC after its EXECUTE permission had been revoked. Both pages now check only the signed-in user's own `public.user_roles` row using the existing RLS SELECT policy (`user_id = auth.uid()`). No SECURITY DEFINER RPC needs to be re-exposed.
- Admin Control Center no longer displays a hard-coded personal name. It displays the signed-in account email after authorization succeeds.
- GitHub Pages deployment run `44091403705` completed successfully for commit `2ac0f9cf236147c30047118351f14918f49786be` (includes the Admin UI and documentation changes).
- Full Health Audit run `44091331004` completed successfully for code commit `6a1ac636aa6c4420a128ef3fcc643eb83f338013`. All steps passed, including Deno type-checks, SQL lint, privacy and workflow guards, website structure checks, Chromium installation, and all key-page browser smoke tests.
- Live `user_roles` snapshot: one role assignment exists and it is `job_seeker`; there are currently zero `super_admin` role assignments. Therefore the Admin UI is now checking the right secure source, but it will correctly deny access until the project owner deliberately grants the first Super Admin role.
- Added `supabase-first-super-admin-bootstrap.sql`, a guarded one-time SQL script requiring the project owner to replace an email placeholder and manually run it. It does not assign a role automatically and refuses to create a second initial Admin if one already exists.
- Updated README to explain the new Admin authorization path and the first-admin bootstrap.

## Release rule

The website is **not launch-ready yet**. The target launch date is 19 November 2026, but it is conditional, not guaranteed. GitHub Pages deployment is working and many backend components are installed, but required secrets, real-account end-to-end tests, Auth hardening, and the final CI run still remain. Do not mark the project complete until those checks pass.


## 17 November 2026 — latest continuation check

- The latest full website Health Audit remains run `44091331004`, completed successfully for code commit `6a1ac636aa6c4420a128ef3fcc643eb83f338013`. It ran after the Admin authorization repair and passed all configured checks, including Deno checks, SQL lint, privacy/workflow guards, structural checks, and browser smoke tests.
- Documentation and launch setup commit `ed82f6dc094790a45e17039bac5713a65496b6ed` was deployed successfully by Pages run `44091592918`.
- The latest commit `399901485d6df56716372645dd4e7f7ad58d75a7` refreshes only the official government-source discovery report. Its Pages build job succeeded; the deploy job was still in progress when this status note was written. Do not claim this latest deployment is complete until the run concludes successfully.
- Latest official-source discovery report: 60 registered sources, 22 successful checks, 38 unsuccessful checks, and 1,135 candidate links discovered. This is discovery-only data; it does not verify vacancies, prove a source is safe to publish, or sync/publish jobs. Many sources are intentionally skipped because robots.txt cannot be safely checked; two IBPS endpoints had TLS/protocol errors and the RRB endpoint returned HTTP 404. These limitations must remain visible to Admin reviewers.
- The committed `website-health-report.json` is an older snapshot (03:27 UTC); use the successful Health Audit run and its uploaded artifact as the newer verification evidence, not that stale committed timestamp.
- Repository-wide code-search checks made during this continuation found no indexed matches for the revoked `public.is_super_admin` call, TODO/FIXME markers, or service-role key strings. This is a search result, not a proof that no secret or unfinished work exists anywhere; the Health Audit and source review remain the stronger checks.
- No provider credentials were added, no Super Admin role was silently granted, and no live-user data or permissions were changed during this continuation.


## 17 November 2026 — database trigger hardening

- A further live database review found `public.create_company_owner_membership()` was a trigger-only SECURITY DEFINER function with `search_path=public, pg_temp`. Although EXECUTE was already restricted to `postgres` and it was attached to one enabled company trigger, the path was hardened to the empty search path and its function calls are now schema-qualified.
- Live verification confirmed: SECURITY DEFINER remains enabled for the trigger's intended insert, `search_path=""`, EXECUTE ACL remains `postgres` only, and exactly one enabled trigger remains attached.
- A transaction-only smoke test inserted a temporary company and confirmed the owner membership row was automatically created. The transaction was rolled back; no test company or membership was retained.
- The reproducible SQL source is committed as `supabase-company-owner-membership-hardening.sql`.
- The latest Supabase advisor snapshot at 13:25 UTC still reports: 7 authenticated-callable SECURITY DEFINER application RPCs (each reviewed for user/role checks and empty search_path), 2 intentional backend-only RLS/no-client-policy INFO notices, and leaked-password protection disabled. Performance notices remain 12 RLS init-plan, 15 multiple permissive policies, and 72 unused indexes. No indexes were dropped and no authorization policy was weakened.
- Public schema audit: all 45 ordinary public tables have RLS enabled; no public ordinary table without RLS was found. No public views were returned by the audit query. All four Storage buckets are private; Resume and Job Offer buckets each have a 10 MB bucket limit.


## 17 November 2026 — post-login routing and final code-side audit

- Fixed the post-login return path for GitHub Pages. The login page now resolves destinations relative to the repository base path, preserves safe same-site query strings, rejects external redirect URLs, and rejects duplicated `/TAMILAN-CAREERS/TAMILAN-CAREERS/` paths.
- Updated protected Candidate Profile, Government Notice Review/Publish, and Dashboard routes to preserve the requested destination through login. Other key protected flows already preserved their destination.
- Expanded `scripts/browser-smoke-test.mjs` to verify relative return, nested page/query preservation, rejection of external redirects and duplicated repository paths, and the return targets for key protected pages.
- Latest code commit `a7c1fa6ce16b6686a2d490923ad37498a8aa7388` deployed successfully to GitHub Pages (run `44094932098`; build, deploy, and status-report jobs succeeded).
- Latest full Health Audit passed for the same commit (run `44094931772`). All steps succeeded: six Supabase Edge Function Deno checks, SQL migration lint, privacy guards, company publication and Resume security guards, JavaScript and internal-link checks, Chromium install, and key-page browser smoke tests.
- Live Supabase recheck: 45 public base tables; all 45 have RLS enabled. All four Storage buckets are private. Seven Edge Functions are ACTIVE: `company-members` v4, `company-resume-access` v1, `scan-external-job-sources` v2, `ingest-government-notices` v1, `bilingual-job-search` v1, `ai-resume-match` v1, and legacy `manage-hiring` v3.
- Live data recheck: 1 Auth user, 1 company, 1 active company membership, 0 jobs, 0 applications, and one `job_seeker` role assignment. There is still no `super_admin` assignment. This prevents real multi-party employer/candidate/Admin end-to-end tests and means the Admin Control Center remains correctly gated.
- Current Supabase security advisor: 7 authenticated-callable SECURITY DEFINER application RPCs with their intended authorization checks, 2 backend-only RLS/no-client-policy INFO notices (`company_invitations`, `job_sources`), and leaked-password protection disabled. Performance advisor still reports RLS init-plan and multiple-policy warnings plus unused-index INFO notices; indexes were not dropped based on a zero/low-traffic database snapshot. Health advisor returned no findings.
- Provider secrets remain deliberately unconfigured/deferred: OpenAI `OPENAI_API_KEY`; Resend `RESEND_API_KEY`, `APP_BASE_URL` and optional `RESEND_FROM_EMAIL`; and Government Monitor `GOVERNMENT_MONITOR_SECRET` in Supabase and GitHub Actions. No secrets were added to code or chat.
- Remaining owner-controlled launch actions: bootstrap the first Super Admin using the guarded SQL and the owner's exact confirmed account email; enable leaked-password protection in Supabase Auth; configure the deferred provider secrets; create separate real Candidate and Employer accounts; then run complete real-user tests for job publishing, applications, Resume upload/authorized access, invitations/email, interview responses, notifications, and cross-company denial.
- Release status remains **not launch-ready** until those owner actions and end-to-end tests pass. Do not treat green CI or a successful Pages deployment as proof of live provider-backed features.
