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
