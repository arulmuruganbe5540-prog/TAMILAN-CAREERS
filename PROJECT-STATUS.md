## 19 November 2026 — Super Admin MFA implementation (initial)

- Added `admin-security.html`, a Super Admin-only account security page that supports Supabase Auth TOTP enrollment using an authenticator app, QR setup, manual secret entry, and six-digit verification.
- Added an Admin Control Center link to the new security page.
- Updated `admin-login.html`: when a verified TOTP factor exists, password login now requires a Supabase MFA challenge and successful verification before redirecting to Admin Control.
- Updated `admin-control.html` to check the Authenticator Assurance Level and prevent direct access with an unverified `aal1` session when MFA is enrolled; it directs the Admin back through the MFA login flow.
- MFA is not globally enforced and no database-wide AAL2 RLS policy was added. Existing Admin access remains unchanged until the Super Admin voluntarily enrolls a factor. This avoids locking out the existing owner account.
- Implementation follows current Supabase Auth MFA TOTP guidance. Browser-based enrollment, challenge, and real-account recovery tests are still pending; do not mark MFA fully verified or mandatory until the owner completes setup and confirms a second-factor recovery path.

## 19 November 2026 — Government exam categories and education pathways

- Expanded `exam-preparation.html` from four broad groups to 16 distinct government exam categories: TNPSC, Police/TNUSRB, TRB/Teacher, TANGEDCO/Power, Forest, Health, UPSC, SSC, Railways/RRB, Banking, Defence, Postal, Insurance, Judiciary, PSU, and Other State PSC.
- Added 16 original locally hosted SVG illustrations under `assets/exam-categories/`; no external Unsplash image dependency for these exam category cards.
- Each category card selects its matching exam group and updates the exam dropdown. Added responsive card layouts, keyboard focus styling, and an active selection state.
- Updated the practice note to show how many question-bank items exist for the selected exam and to clearly indicate when a dedicated question bank is not yet available. This does not imply practice questions exist for all 16 categories; the current question bank remains limited.
- Added eight education-based job discovery pathways to the public homepage: 10th Pass, 12th Pass, ITI, Diploma, Diploma Studying, Degree, Postgraduate, and Studying.
- Added eight original locally hosted SVG illustrations under `assets/education-pathways/`. Each card links to the existing `jobs.html?education=...` filter using the exact education labels supported by the job-search page.
- Verified the updated files and representative SVG assets are present on GitHub. End-to-end browser testing and confirmation against published job records remain pending; the qualification cards may correctly show no results while there are no matching published jobs.

# TAMILAN CAREERS — Project Status & Handover

## 19 November 2026 — Website Design Studio persistence (first implementation)

- Applied live Supabase migration `homepage_design_studio_persistence` to project `qkmljuuusfjowexvybvy`.
- Created `public.site_settings` with public read access and Super Admin-only insert/update policies using the existing `private.is_super_admin()` authorization helper.
- Created public `site-assets` Storage bucket with a 5 MB limit and PNG/JPEG/WebP allowlist. Upload, update and delete object policies require Super Admin authorization.
- Updated `admin-design-studio.html`: loads persisted settings, previews selected banners, saves the homepage design to Supabase, uploads banners to Storage, and removes replaced assets after successful save.
- Updated `index.html`: added a configurable homepage hero and loader for the saved name, headline, description, primary color and public banner.
- Added reproducible SQL setup at `supabase-homepage-design-studio.sql`.
- Verified the live table policies and bucket configuration through SQL inspection, and seeded the initial default homepage settings without overwriting future Admin edits. No banner has been uploaded yet; Admin changes require an authenticated Super Admin browser session. Real browser upload/save and public rendering smoke tests are still pending.

Last live audit: 19 November 2026 (India time)  
Repository: `arulmuruganbe5540-prog/TAMILAN-CAREERS`  
Live Pages: https://tamilancareers.in

This status distinguishes committed website code from verified live Supabase configuration. A deployed page or Edge Function is not proof that a real authenticated workflow has passed end-to-end testing.

## 19 November 2026 — site-wide translation audit and locale-loader repair

- Added a repeatable translation coverage audit to `scripts/website-health-check.py`. It scans every HTML page, reads the curated dictionaries, separates English-source text from Tamil-English mixed text, reports per-language dictionary matches, and checks whether each page loads the shared locale system.
- The audit scanned 50 HTML pages and found 0 structural errors, 0 warnings, and 0 pages missing the locale loader after the repair below.
- Found that `admin-company-verification.html` was the only HTML page missing `assets/site-protection.js`, which injects the shared locale/country/language experience. Added the shared script. All 50 pages now include the locale loader.
- The actual language selector contains 22 languages (not 23). All 22 have a dictionary, but dictionary coverage is uneven: Tamil/Hindi/Malayalam/English dictionaries matched 189 of 433 unique English-source static strings (43.6%); Sinhala/Chinese/Malay/Spanish/Arabic/French/German/Japanese/Portuguese/Italian matched 22 of 433 (5.1%); Kannada/Telugu/Marathi/Bengali/Gujarati/Punjabi/Odia/Assamese matched 19 of 433 (4.4%).
- The audit also identified 283 unique Tamil-English mixed static strings. These are not fully covered by the current English-source dictionary model. Dynamic JavaScript/API content is not included in these figures, and a dictionary match is not a translation-quality certification.
- Latest full Health Audit run `44422183387` passed for commit `0f3cebc02414a6b8c3cf2023787d18bc14946e35`; GitHub Pages build/deployment run `44422182853` also succeeded for the same commit.
- Translation is therefore not complete. Remaining work is to expand/standardize source phrases and translate the mixed-language public and candidate/employer flows, then re-run the site-wide audit.

## 19 November 2026 — additional locale vocabulary and live security review

- Added 170 additional curated job-search, candidate-profile, and common form translations across the 18 additional locales (Kannada, Telugu, Marathi, Bengali, Gujarati, Punjabi, Odia, Assamese, Sinhala, Chinese, Malay, Spanish, Arabic, French, German, Japanese, Portuguese, and Italian).
- Added automated country-detection and dynamic vocabulary checks for Spain (Spanish) and Malaysia (Malay). The full browser smoke suite passed 34 checks, 0 failures, and 0 uncaught browser errors.
- Final verified full Health Audit run for this change: `44423151262`, commit `b06e46e0ab6658f33e8c8d7f85f209e0b9279afb` (success; 0 structural errors and 0 warnings). Pages deployment run `44423151040` also succeeded for the same commit.
- Translation audit still reports 433 unique English-source static strings and 283 mixed Tamil-English strings. Exact dictionary-key matches: English/Tamil/Hindi/Malayalam 189/433 (43.6%); Sinhala/Chinese/Malay/Spanish/Arabic/French/German/Japanese/Portuguese/Italian 22/433 (5.1%); Kannada/Telugu/Marathi/Bengali/Gujarati/Punjabi/Odia/Assamese 19/433 (4.4%). These are static-source estimates, not a translation-quality score; dynamic/API text is not counted. Full 22-language translation remains unfinished.
- Live Supabase row-count check: 0 jobs, 0 published jobs, 1 company, 0 verified companies, 0 job applications, 0 company verification requests, and 2 profiles. No sample jobs or fake companies were created. The platform still needs genuine employers and real job listings before it can serve job seekers meaningfully. Additional account-readiness counts: 1 job-seeker role/profile, 1 super-admin role, 1 company-member row, 0 candidate resumes, and 0 company invitations. Real candidate/employer end-to-end tests remain blocked until a genuine employer account is verified and test credentials/workflows are available.
- Source-monitor review: 30 external job sources are configured (6 public-page sources have been scanned; 21 are intentionally manual-only; 3 are manual-only because robots.txt blocks safe automated checks); 48 government notice sources are enabled. The latest government monitor report checked 60 official authorities, with 21 successful checks and 39 failures (mostly robots.txt restrictions, plus a stale RRB URL returning 404). The database currently contains 0 government notices. These monitors discover/check sources but do not certify or publish vacancies automatically; Admin review is still required.
- Government review queue: the latest monitor report discovered 1,108 candidate links; the live database contains 150 pending review records (SEBI 120, Manipur PSC 13, TNPSC 8, BPSC 5, IBPS 4). All 150 still have zero verification flags for opening the notice document, verifying dates, and verifying vacancies. None were auto-published. The Admin review page now highlights older years in a title and past application deadlines so reviewers can prioritize manual checks. Health Audit run `44423759558` passed (34 browser checks, 0 failures, 0 browser errors); Pages deployment run `44423758806` succeeded for the same code commit `c15b01a38f6213230fc178afe579efcc6a23ee1a`.
- AI feature status: the deployed `ai-resume-match` and `bilingual-job-search` Edge Functions currently return HTTP 410 (feature disabled). AI resume matching and AI bilingual search are not live. They need real implementation, a server-side `OPENAI_API_KEY` secret, usage limits, and an explicit privacy/consent notice before candidate resume content is sent to an AI provider.
- Security advisor review: 14 SECURITY DEFINER functions are flagged because authenticated users can execute some of them. Manual review confirmed that all authenticated-executable functions check the caller identity and the appropriate candidate/company/Super Admin authorization; none of the reviewed functions is executable by `anon`. `company_invitations` and `job_sources` have RLS enabled, no policies, and no anon/authenticated table privileges, so they remain inaccessible through the public Data API. No blanket privilege changes were made.
- Remaining security items: leaked-password protection is disabled in Supabase Auth; 10 unindexed foreign-key findings and 15 RLS initplan performance findings remain to be reviewed. These settings and schema changes were not altered during this read-only audit.

## 19 November 2026 — live Supabase performance fixes

- Applied and recorded migration `20261118234952_add_remaining_foreign_key_indexes_20261119`: added the 10 missing foreign-key indexes identified by the live advisor. The matching GitHub migration file and `supabase-foreign-key-indexes.sql` setup script are committed.
- Applied and recorded migration `20261118235023_optimize_rls_auth_uid_policy_initplans`: wrapped direct `auth.uid()` policy calls in scalar SELECTs on the 15 affected policies. This preserves the existing ownership and authorization predicates while allowing PostgreSQL to evaluate the auth value once per statement.
- Re-ran Supabase performance advisors: `unindexed_foreign_keys = 0` (down from 10) and `auth_rls_initplan = 0` (down from 15). Remaining advisor findings: 22 multiple-permissive-policy notices and many unused-index notices; unused-index notices are expected while the project has very little real traffic/data, so indexes were not dropped.
- Security advisor was rechecked after the RLS optimization. No changes were made to policy roles, ownership checks, or public grants. The previously documented Auth leaked-password-protection setting remains disabled and needs a dashboard-side security setting change. The full Health Audit run `44424175818` passed for the migration-code commit `65832544accb974cdb111b79f16af893f17524d0`; Pages deployment run `44424200948` succeeded for the latest status/documentation commit `52e0e942bb4c1c24bf219522aae18c3f4168b126`. Storage review: all five Supabase Storage buckets are private. Candidate resumes and company verification documents have 10 MB limits and restricted MIME types; resume object policies are owner-scoped, while verification files are limited to the submitting company owner and Super Admin review.

## 19 November 2026 — company invitation custom-domain correction

- The deployed `company-members` Edge Function used the old GitHub Pages URL as its fallback invitation base URL. Updated the GitHub source and deployed version 8 with the fallback set to `https://tamilancareers.in`.
- Verified the live Edge Function reports version 8, keeps `verify_jwt=true`, contains the custom-domain fallback, and no longer contains the old GitHub Pages fallback.
- Updated `CONNECTIONS-AND-LAUNCH-SETUP.md` to specify `APP_BASE_URL=https://tamilancareers.in`. If the Supabase secret `APP_BASE_URL` is already configured to the old URL, the project owner must update that secret in Supabase Dashboard; the function cannot read or change secret values through this workflow.
- Real invitation email delivery remains unverified until the Resend secret and sender are confirmed and an authenticated end-to-end invite is sent.

## 19 November 2026 — Tamil-source translation support and company workflow vocabulary

- Updated `assets/auto-translate.js` so the curated dictionaries can translate exact Tamil source text nodes into English, Hindi, Malayalam, and the 18 additional locales. Ambiguous Tamil phrases that map to conflicting translations are deliberately excluded.
- Added 40 Tamil-source labels for job search, job applications, candidate profiles, government/employer filters, company verification, and team/applicant workflows. The 18 additional locale dictionaries received 720 corresponding entries across these batches.
- Added browser smoke assertions proving Tamil source labels such as `வேலை தேடுபவர்`, `உங்கள் பெயர்`, `அனைத்து வகைகளும்`, and `குழு உறுப்பினர்கள்` translate correctly in Spanish and Malay.
- Latest translation audit scans 50 HTML pages and finds 796 unique pure-Tamil source strings plus 433 English source strings and 283 mixed Tamil-English strings. Tamil-source exact matches: English 73/796 (9.2%), Tamil 75/796 (9.4%), Hindi/Malayalam 71/796 (8.9%), Kannada/Telugu/Marathi/Bengali/Gujarati/Punjabi/Odia/Assamese 54/796 (6.8%), and Sinhala/Chinese/Malay/Spanish/Arabic/French/German/Japanese/Portuguese/Italian 56/796 (7.0%). These are dictionary-key coverage estimates, not translation-quality scores; most long Tamil paragraphs and mixed-language strings remain untranslated.
- Health Audit run `44426060611` passed with 0 errors and 0 warnings; Pages deployment run `44426060923` succeeded for commit `5c2f49cb5af9629410b22ac16531010cc4ce96f7`.
- Full translation remains incomplete. A real translation provider/API with owner-approved privacy, cost limits, and caching—or continued manual curated translation—is needed to translate the remaining hundreds of Tamil strings and dynamic content reliably.

## 19 November 2026 — privacy notice alignment

- Updated `privacy.html` to state accurately that AI Resume Matching is not currently enabled and the existing resume-to-job matcher is rule-based, not AI-powered. The notice also commits to a clear disclosure and explicit candidate consent before any future AI provider receives resume/profile content.
- Updated the privacy policy revision date to 19 November 2026.
- Health Audit run `44426297043` passed with 0 errors and 0 warnings; Pages deployment run `44426296399` succeeded for commit `cf1622fdc0af6fd6a7458379957acbd1aa2c4bab`.

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


## 18 November 2026 — current continuation audit

- Current repository code HEAD: `b93a358f532dffd0df7f14733fae85d567006537`. The documentation commits after the main Admin/currency changes updated `README.md` and this handover.
- Current live Supabase inventory: 2 Auth users; 1 `super_admin` role and 1 `job_seeker` role; 1 company; 0 published jobs; 0 active public government notices. No real or sample vacancy is currently published.
- Current Edge Functions: `company-members` v7, `company-resume-access` v3, `scan-external-job-sources` v4, `ingest-government-notices` v6, `bilingual-job-search` v4 (disabled response), `ai-resume-match` v4 (disabled response), `extract-government-notice-details` v10 (disabled response), `generate-job-mock-exam` v2 (disabled), and legacy `manage-hiring` v5. The four AI-related function handlers were inspected and contain disabled responses; Supabase displays them as ACTIVE because the disabled handlers themselves are deployed.
- No-AI policy is reflected in the website source and README. Resume search is deterministic and local; exam practice uses curated local question banks. The stale AI-generated mock-exam wording and old AI job-detail label were corrected. The README no longer links the deleted `ai-job-matches.html` or documents OpenAI API setup.
- Government portal navigation includes Central Government and Tamil Nadu Government pages, department/category tiles, education-wise filters, dynamic department listing pages, government notice details, and the Supabase public feed. Internal HTML destinations referenced by the Central and Tamil Nadu pages were checked against repository files; all seven unique linked page targets resolved. Current feed is empty because the live jobs and government notices tables have no published rows.
- Admin job posting is now gated by the signed-in `super_admin` role and MFA AAL2 at the page level. A read-only simulated JWT-claims check against `private.is_super_admin()` returned AAL1=false and AAL2=true. The Super Admin account currently has 0 verified TOTP factors, so the real Authenticator enrollment/login must still be completed in a browser.
- The live `tc_admin_publish_job(uuid)` definition and `supabase-admin-job-publish-setup.sql` are synchronized. Foreign-job salary currency can be selected in the Admin form and is validated against supported ISO currency codes in the publish function; it is no longer forced to USD. The Admin form JavaScript passed syntax parsing.
- Static JavaScript syntax parsing passed for 16 key pages/scripts, including Admin, job search/details, Central/TN government portals, notice feed, department/category pages, exam centre, Resume search, Dashboard and homepage.
- Current Supabase security advisor: 2 INFO notices for backend-only tables `company_invitations` and `job_sources`; 7 authenticated-callable SECURITY DEFINER application RPC warnings (including the Super Admin-checked publish RPC); and leaked-password protection disabled. Do not remove intended RPC permissions or weaken RLS just to silence the advisor.
- Latest GitHub combined commit status lookup returned no status contexts, and the available repository connection did not expose push-triggered Pages/Health Audit run listings. Therefore deployment of the latest code HEAD is **not verified**. Do not claim the new code is live until the matching Pages build/deploy and Health Audit runs are confirmed successful.
- Remaining items that cannot be truthfully marked complete yet: real browser Admin MFA login; draft → review → approve → publish test with a temporary test job followed by cleanup; checking the test listing in public job/Central/TN/detail pages; real private and foreign job form tests; actual Android/mobile browser checks; and enabling leaked-password protection. No test job was inserted and no real job data was fabricated.
- Release status remains **not fully complete / not launch-ready** until the latest deployment and the owner-session end-to-end checks above pass.


## 2026-11-18 — Automatic published-job expiry

- Added Supabase migration `auto_expire_published_jobs` and repository SQL file `supabase/migrations/20261118190000_auto_expire_published_jobs.sql`.
- Deployed database function `public.tc_expire_published_jobs()`: closes jobs only when `status='published'`, `application_deadline` is present, and its stored India-local end-of-day timestamp is earlier than the current time.
- Scheduled Supabase pg_cron job `expire-published-jobs-daily` at `35 18 * * *` UTC (00:05 Asia/Kolkata). Verified the database timezone is UTC and the cron job is active.
- Manually invoked the function safely; it returned 0 because there are currently no published jobs. This confirms execution, not the future scheduled run.
- The hourly GitHub Actions sitemap workflow completed successfully. Its logs confirmed 14 static URLs and 0 active published job URLs.
- Google Indexing API deletion notices are still pending Search Console ownership verification and the Google service-account secret. Closed jobs will no longer be included by the dynamic sitemap generator.

## 18 November 2026 — Job trust and safety reporting

- Hardened the public jobs_read_published policy: Admin-managed jobs without a company may be public; any job linked to a company is public only while that company has verification_status='verified'. The previous policy allowed any is_admin_managed=true row to bypass the company-verification predicate.
- Added public.job_reports with RLS, one report per signed-in user per job, constrained report reasons/statuses, and bounded report details. Reports can be submitted only for currently published jobs.
- Added authenticated tc_submit_job_report RPC and Super Admin-only tc_review_job_report RPC. Both use an empty search path and explicit authorization; no public/anonymous execution.
- Added a Tamil report form to job-details.html for upfront-payment demands, fake/misleading listings, impersonation, misuse of personal data, expired/filled jobs, and other issues. Login is required before submission.
- Added a verified-employer badge to job detail pages only when the linked company record currently says verified.
- Added admin-job-reports.html and linked it from Admin Control Center. Super Admin can review the report, set status to reviewing/actioned/dismissed, and add an admin note. A report does not automatically remove a job.
- Live schema migration applied successfully. Current published job count is 0, so no real job report or verified-company public listing flow can be end-to-end tested yet. No test job or report was inserted.
- Supabase security advisor now lists the two new authenticated SECURITY DEFINER RPCs among the project's authenticated-callable functions; these are intentionally callable and perform their own auth.uid() / Super Admin checks. Existing unrelated advisor notices remain: backend-only RLS tables and leaked-password protection disabled.
- GitHub Pages deployment and browser end-to-end tests for this change are not yet confirmed. Do not claim the new pages are live until the matching CI/Pages runs succeed.

## 18 November 2026 — Company identity re-verification and data privacy

- Audited company verification tables, RLS, trigger behavior, storage policies, and company-facing page queries.
- Found that a company owner could change company identity fields while retaining the existing verified status. Reworked `tc_guard_company_verification_status` and its trigger to cover every company update: owners cannot transfer ownership or self-assign verified/rejected status; changes to company name, slug, description, website, logo, industry, size, or registration number automatically move a verified company back to pending. Only Super Admin can verify/reject.
- Restricted `companies` Data API SELECT privileges for both anon and authenticated users to display-safe columns only. `registration_number` and `owner_user_id` are no longer selectable from the companies table. Company verification requests continue to hold legal details behind their own owner/admin RLS policies.
- Updated `company-profile.html` duplicate-request recovery to look up the user's own open verification request rather than querying private registration and owner columns from `companies`.
- Added Tamil UI guidance explaining that changes to verified company identity details trigger re-verification.
- Applied migration successfully. SQL checks confirmed anon/authenticated cannot select the full companies table; both can read public display fields; neither can read registration_number or owner_user_id. Trigger now fires before every INSERT/UPDATE on companies and uses SECURITY DEFINER with an empty search_path.
- Audited company-facing pages: company applicant/member/job pages use only company display name and verification status; public jobs page uses company id/name; admin verification uses display name/status/website while legal details come from protected verification request rows.
- A rollback-only SQL transaction test confirmed: a verified company identity edit automatically resets status to pending; an owner cannot transfer company ownership; an owner cannot self-verify. The transaction was rolled back and a follow-up count confirmed zero test rows remain.
- GitHub Health Audit run `44353248832` passed for code commit `d68cb5388a0b556e39e8570972b9e8fb78e01226`, including Deno checks, SQL migration lint, internal structure checks, and Chromium browser smoke tests.
- GitHub Pages build and deployment run `44353289218` succeeded for commit `7685509f9d4546b91cb286c7f19e60f25c00d6d4`, which includes all company verification and privacy changes. Live authenticated company-owner/Admin end-to-end UI testing remains pending; no real verification records or test identities were created.


## 18 November 2026 — company verification upload and review hardening

- Added and applied `20261118220000_company_verification_storage_and_review_hardening.sql`.
- The company-verification Storage bucket remains private with a 10 MB limit and PDF/JPEG/PNG/WEBP MIME allowlist. The owner upload policy now requires the exact company/user/request folder structure, a valid document filename, an owned company, and an open verification request. Uploads are accepted only while the request is pending or awaiting additional information.
- Added a database trigger for `company_verification_documents` that checks the stored path matches the row's company, uploader, and request IDs; validates the document type, allowed filename pattern, MIME/extension pairing, and 1-byte-to-10-MB size limit. Existing owner/Admin read policies remain unchanged.
- Hardened `tc_review_company_verification`: only Super Admin may review; invalid decisions and oversized notes are rejected; a request must still be open before it can be reviewed. Verified/rejected requests are terminal and cannot be overwritten by a later review call. Company verification status remains pending during review or when more information is requested.
- During a rollback-only submission test, discovered the existing official-email CHECK constraint had an over-escaped dot expression that rejected valid email addresses, including the account's own valid email. Fixed the constraint to require a normalized lowercase address with a valid domain suffix. The real submission RPC then passed a rollback-only test using the existing company-owner identity; no company/request data was retained.
- Added five indexes for the verification tables' foreign keys: document company, request and uploader; request submitter and reviewer.
- Rollback-only database tests passed: valid document metadata path accepted; invalid filename/path rejected; MIME/extension mismatch rejected; pending request advanced to under_review and verified; a second decision against the closed request was rejected. All test changes were rolled back; zero test requests remain.
- The separate rollback-only company verification submission RPC test passed after the email constraint correction; zero test requests remain.
- Applied follow-up migration `20261118230000_company_verification_email_and_fk_indexes.sql`.
- Security advisor still reports intentional authenticated-callable SECURITY DEFINER application RPCs, including the Super Admin-checked review RPC, plus the existing backend-only RLS INFO notices and disabled leaked-password protection. Health advisor returned no findings. Performance advisor still has unrelated low-traffic/multiple-policy and unused-index notices; the new verification foreign-key indexes address the five verification-table FK warnings.
- No real verification requests or documents currently exist. Actual browser file upload, signed-download, and cross-account denial tests remain pending. Do not claim those end-to-end flows are tested.
- GitHub Health Audit and Pages deployment for these migrations must be confirmed against their matching workflow runs before marking deployment complete.

- Updated `.github/workflows/website-health-check.yml` so future changes under `supabase/migrations/**` automatically trigger the SQL migration lint and full website Health Audit. Previously the path filter did not include the migrations directory, so database-only migrations could bypass the push-triggered audit.


## 18 November 2026 — verification document RLS and review UI follow-up

- Added and applied `20261118240000_company_verification_open_request_document_policy.sql`: document metadata inserts are now limited to the request owner's company and requests that remain `pending` or `more_information`.
- Added and applied `20261118250000_company_verification_private_identity_rls_helper.sql`, then moved the helper into the non-exposed `private` schema in `20261118260000_company_verification_private_rls_helper_schema.sql`. This was necessary because the earlier company identity privacy migration deliberately revoked direct reads of `companies.owner_user_id`; the old verification RLS expressions still queried that protected column directly and could fail with permission errors.
- The private SECURITY DEFINER helper checks the signed-in user against the company owner and request submitter, and optionally requires an open request. Verification request/document owner SELECT policies and Storage owner read/upload policies now use this helper. Direct INSERT policy for verification requests was removed: new requests must go through the validated submission RPC. Super Admin read policies remain separate.
- Confirmed `authenticated` cannot SELECT the whole `companies` table, can SELECT safe display fields, and cannot SELECT `owner_user_id` or `registration_number`. The helper now lives in `private`, not the exposed `public` API schema.
- Rollback-only authenticated-role tests passed: owner can read their own verification request, add metadata for an open request, and cannot add document metadata for a closed request. The helper denies closed requests for upload. All test data rolled back; zero test rows remain.
- Updated `company-verification-status.html` to show a clear unavailable message if a signed document URL cannot be created, and to label successful links as short-lived (5 minutes).
- Updated `admin-company-verification.html` to report document query/link failures and hide review actions for terminal/closed requests. The database still independently rejects review attempts on closed requests.
- Supabase Health Advisor: no findings. Security Advisor no longer reports the new verification helper as a public API SECURITY DEFINER RPC; remaining warnings are pre-existing application RPCs and the Auth leaked-password protection setting. Performance notices remain elsewhere in the project.
- One Health Audit initially failed because its simple migration-lint rule interpreted the phrase "SECURITY DEFINER" in a SQL comment as an unconfigured function. The comment was corrected; Health Audit run `44355469251` passed, including SQL migration lint and Chromium key-page browser smoke tests. Pages deployment run `44355578212` also completed successfully for the documented repository state.
- Actual browser upload, signed-download, and cross-account denial tests remain pending because there are currently no real company verification requests/documents. No real verification records were created.


## 18 November 2026 — overseas employer verification hardening

- Fixed a backend validation gap: overseas companies could previously choose a domestic entity label and bypass the recruitment/sponsor authorization details requirement. The submission RPC now requires authorization details whenever the registered country is not India, regardless of the selected legal entity type; the existing Foreign Recruitment Company type still requires the details even if the registration country is India.
- Updated the company verification form so the authorization field appears and becomes required based on the registered country or Foreign Recruitment Company entity type. The notice now accurately states that registry checks are manual; no automatic government-registry integration is claimed.
- Added an overseas-specific Admin review checklist: independently verify the legal entity, registration number, registered address, official domain/contact, recruitment-licence applicability, and sponsor/work authorization where applicable. Admin notes must contain at least 40 characters before an overseas request can be marked verified.
- The database schema already supports country code, legal entity type, authorization details, and private document categories for recruitment licences and work authorization. No new user data or sample verification records were created.
- Migration applied to the live Supabase project: `20261118270000_foreign_employer_authorization_requirements.sql`. GitHub source and the matching migration file are committed.
- Automated migration/Health Audit and Pages deployment status must be checked against the latest commit before calling the work deployed. Real foreign employer submission, document upload, official registry lookup, and Admin decision tests remain pending until a real overseas employer application exists. This is a manual review workflow, not a government registry integration.


## 19 November 2026 — dynamic translation reliability

- Improved `assets/auto-translate.js` so translated UI text is applied to dynamic placeholders, accessible labels, image alt text, title attributes, and button/submit values.
- Dynamic attribute translation now observes changes to those attributes, skips values that are already translated, and uses canonical English dictionary keys to avoid translation cycles.
- Fixed a MutationObserver queueing issue: DOM mutation records arriving while a previous animation-frame scan was pending are now queued instead of silently discarded. This prevents newly inserted form fields and accessibility labels from remaining in English.
- Expanded the browser smoke test to create dynamic Malayalam text, an input placeholder, a button title, and an aria-label, then verify their translations.
- Latest full Health Audit run `44385541563` passed for commit `1acbdf1fc969fe9daeb692c2bb7eb7157658b4c5`; browser smoke tests passed (32 passed, 0 failed), with no uncaught browser JavaScript errors.
- GitHub Pages build and deployment run `44385542125` succeeded for the same commit.
- This improves translation coverage for dynamic UI attributes; it does not mean every page or every supported language has been fully translated. Full translation coverage remains a separate task.


## 19 November 2026 — education, industry and employer-form translations

- Expanded the curated Tamil, Hindi and Malayalam dictionary with 36 terms covering education levels (including ITI, Diploma, Degree and PhD/Research), industries, job categories, business entity types, and company verification document labels.
- Added a browser smoke assertion for dynamic Malayalam translation of the education term `Degree`.
- Latest full Health Audit run `44386300040` passed for commit `16a0cdde784c6ff84dd62bcfaa93101f139a1fc1`; the browser smoke suite completed with no failures.
- GitHub Pages deployment run `44386300019` succeeded for the same commit.
- This expands coverage for the listed terms in Tamil, Hindi and Malayalam. Other languages still use their own shorter dictionaries, and a full-site translation audit remains outstanding.


## 19 November 2026 — candidate login and profile translation coverage

- Added 18 Tamil/Hindi/Malayalam translations for mixed-language candidate-facing labels, including login role choices, password confirmation, profile education/credential fields, common example placeholders, and page titles.
- A source-text audit of 12 key pages now finds no untranslated English-only text in `jobs.html` or `job-details.html`; the remaining matches in Candidate Profile, Login, Dashboard, Company Profile, and Job Posting are mostly intentional brand names, examples, or mixed-language phrases that have separate curated entries where appropriate.
- Latest full Health Audit run `44386980640` passed for commit `143108ff706d0b474234dcfcf1fabf52dae701bb`; Pages build and deployment run `44386980875` also succeeded for the same commit.
- This is a targeted dictionary expansion, not a claim that every page and every supported language is fully translated. A complete site-wide translation review remains open.


## 19 November 2026 — Admin dashboard translation coverage

- Added 38 Tamil/Hindi/Malayalam translations for the Admin Control Center, navigation groups, review sections, jobs/applications/companies, team/users, learning, and website design controls.
- Added a browser smoke assertion that verifies the dynamically inserted `Admin Control Center` label translates into Malayalam.
- Latest full Health Audit run `44387382862` passed for commit `3cfce7f8c7f2f5e5a835a379b7c2ffb1ac360632`; the Pages build and deployment run `44387382517` also succeeded.
- Translation remains dictionary-based. Pages and dynamic strings not yet included in the curated dictionaries may still show English; no machine-translation API is configured.


## 19 November 2026 — government exam practice question-bank expansion

- Added 45 original Tamil practice questions across nine named exam tracks: TNPSC VAO, TNUSRB Police Constable, TNTET Paper I, UPSC Civil Services, SSC CGL, RRB NTPC, IBPS PO, LIC AAO, and Indian Army Agniveer.
- Questions cover Tamil, Indian polity, general knowledge, quantitative aptitude, reasoning, teaching/child development, banking, insurance, science, geography, economy, and environment as appropriate to each track.
- Each question includes four answer options, a keyed answer, and a short explanation. Existing questions and the existing exam-specific filtering flow were preserved.
- These are TAMILAN CAREERS-authored practice questions, not official previous-year questions or a complete syllabus bank. Some listed exam options still have no dedicated question set; the page should continue to show its existing unavailable notice for those options.
- Browser/automated Health Audit and Pages deployment for this commit must be checked before claiming the change is live.


## 19 November 2026 — homepage regression repair, exam-bank coverage and live launch audit

- Restored the owner's homepage preference: removed the hero/banner section again while preserving the Google AdSense script (ca-pub-5514219463771418) and the qualification pathway cards. The homepage design loader now applies brand/accent settings without recreating the removed hero.
- Fixed the 360px mobile horizontal overflow in the homepage section heading. GitHub Pages deployment run 44451494186 succeeded and the full Health Audit run 44451494225 passed for commit 9a4d2949476efab54c241c9ec9fd5892b3d68ef6; the browser suite reported no failures or uncaught browser errors.
- Expanded the exam practice bank by another 35 questions. It now contains 110 exam-specific questions across 18 named tracks, including at least one dedicated track for each of the 16 top-level exam categories. These are original practice questions, not official previous-year papers or a complete syllabus.
- Added an automated browser smoke assertion for all 16 category-to-question-bank mappings and an 80-question minimum. Full Health Audit run 44451700508 passed for commit f81cc6c7e81783e9dfbea18286a1ff4a7a5fb808. Its Pages run was cancelled by the later documentation-only commit; the latest Pages deployment run 44451937018 succeeded for commit 06e8449485bfa4e3e6ada51e4f87b1bf84993488 and includes all current code and documentation.
- Live Supabase read-only audit: project is ACTIVE_HEALTHY; all 55 public tables have RLS enabled; 2 Auth users, 1 Job Seeker role, 1 Super Admin role, 1 company, 1 company membership, 0 jobs, 0 applications, 165 pending government review records, and 6 pending external-job candidates. No production sample jobs or applications were inserted.
- Confirmed live AI-related Edge Functions ai-resume-match, bilingual-job-search, extract-government-notice-details, and generate-job-mock-exam return HTTP 410 disabled responses. The built-in exam question bank and local rule-based Resume search remain non-AI features. Do not configure OpenAI API keys or re-enable these functions.
- Supabase Health Advisor returned no findings. Security Advisor still reports 14 callable SECURITY DEFINER RPC warnings and two RLS-enabled/no-policy informational findings; reviewed public SECURITY DEFINER functions have an empty search_path, and authenticated RPCs contain user/role/ownership checks. Leaked Password Protection remains disabled and requires an owner-side Auth setting change.
- Remaining owner-controlled launch tasks: configure SMTP and Resend secrets if email delivery is required; configure the government monitor secret before enabling scheduled ingestion; enable Leaked Password Protection; perform real Candidate/Employer/Super Admin end-to-end tests; manually review pending government/external records. Zero published jobs means public job lists correctly remain empty until genuine listings are approved.
