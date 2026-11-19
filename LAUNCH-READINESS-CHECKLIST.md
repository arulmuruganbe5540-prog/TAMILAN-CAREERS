# TAMILAN CAREERS — Launch Readiness Checklist

Last reviewed: 17 November 2026

This is an operational checklist based on the project changes and user-confirmed setup steps available at the time of writing. A feature is not considered live merely because its code or SQL file exists.

## Confirmed complete

- [x] Latest confirmed GitHub Pages deployment succeeded for commit `026e7b9b4a564b28d896ea141f7b93d8df371b44` (run `44075721444`; build and deploy jobs succeeded).
- [x] Latest confirmed full website health workflow passed for commit `ac3c98b21263da7e2192151d413af4cc7f8f7a35` (run `44075880374`; audit job succeeded, including SQL lint, Edge Function checks, Resume security guard, and browser smoke tests).
- [x] Read-only schema audit compares `resumes`, `candidate-resumes`, and `job-offers` bucket settings, counts stored objects without exposing paths, and retrieves the live `can_access_job_application` function definition for review.
- [x] Consolidated setup, focused Resume Storage SQL, and employer application-status SQL now fail early when required existing tables/columns are missing or incompatible.
- [x] Candidate Resume deletion now removes the private Storage object before deleting its metadata row; if Storage deletion fails, the metadata remains available for retry. This repository change passed the health workflow and Pages deployment; live Supabase behavior still needs real-account testing.
- [x] Latest GitHub Pages deployment succeeded for main commit `98b47f01b3c6eabf7237ccb410c34aa06c7911bf` on 17 November 2026 (run `44061663205`; deployment completed successfully).
- [x] Latest full website health workflow passed for the same commit `98b47f01b3c6eabf7237ccb410c34aa06c7911bf` (run `44061664222`; Edge Function type checks, SQL lint, privacy guards, website structure checks, Chromium installation, key-page browser smoke tests, and health-report upload all succeeded).
- [x] Interview/notification SQL now performs a schema preflight for the required application, job, company, and company-member tables/columns before making migration changes. This guard is committed, but the SQL still has not been run against the live Supabase project.
- [x] Company workflow SQL was reported successful by the user.
- [x] Candidate application withdrawal SQL was reported successful by the user.
- [x] External job-source registry SQL was reported successful by the user.
- [x] Supabase Edge Function `scan-external-job-sources` was reported deployed successfully by the user.
- [x] External-source discovery remains review-only; scanner code does not publish to the public jobs table.
- [x] A browser smoke test now checks that the external-source review page redirects unauthenticated visitors to login.
- [x] Scanner response parsing is capped at 1.2 MB while streaming, instead of reading an unbounded response before slicing.
- [x] Scanner rejects non-HTML responses, requires an explicit HTML/XHTML content type, validates each HTTPS redirect before fetching it, limits redirects, and records per-source scan failures accurately.
- [x] GitHub Actions now checks dollar-quote pairing across all 18 SQL files to catch malformed PL/pgSQL delimiters; it also checks SECURITY DEFINER functions for a locked-down `search_path`.
- [x] Candidate certification table, owner-only policies, employer applicant-only read policy, and candidate profile add/edit/delete UI are prepared in the repository; Supabase migration and real-account testing are still pending.
- [x] Government source seed migrations now preserve an administrator's enabled/disabled choices when re-run.
- [x] AI resume matcher Bearer header parsing was corrected in the repository source; candidate certifications are now included in the matcher context.
- [x] Candidate profile form supports adding, editing, and deleting certifications in the repository; database setup and real-user test remain pending.
- [x] Government-source fetcher validates HTTPS redirects before following them and caps redirects.
- [x] Public-branch privacy fix: unverified government review/source-candidate JSON files were removed from the current branch, ignored locally, and the monitor workflow now commits only the aggregate scan report. Older Git commits still contain historical copies; removing those requires a separate Git-history rewrite and force-push review.
- [x] CI privacy guard passed: it verifies the two unverified government candidate JSON files are not tracked, remain ignored, and are not staged by the monitor workflow.
- [x] Official-source monitor run completed successfully on main (run `44054710305`): 23 of 60 registered sources were reachable in the latest report; sources blocked by robots policy or returning errors were not bypassed. Source discovery completed. Supabase candidate sync was skipped because the monitor secret remains unconfigured, and only the aggregate report was committed.
- [x] Source-discovery crawler now validates HTTPS redirects, limits redirect count, and accepts only HTML/XHTML content types.
- [x] Candidate profile migration's malformed experience/certification index statements were corrected; SQL lint now also checks CREATE INDEX ... ON clauses.
- [x] Resume application attachment is linked through `job_applications.resume_id`; a database trigger rejects missing, forged, or other-candidate Resume IDs. The SQL files are updated, but Supabase has not yet run this migration.
- [x] Expired private vacancies are hidden from search and AI matches; direct job-detail and application pages block expired deadlines. The consolidated Supabase SQL also adds a database trigger that rejects applications to unpublished or expired jobs, including requests that bypass the browser.
- [x] Candidate employer-profile visibility is revoked after an application is withdrawn; private Resume access remains limited to active application states and a verified company member/owner.
- [x] Employer application status changes create a candidate notification when the notifications table is installed; repeating the same status does not send a duplicate alert.
- [x] Job-posting draft RLS is restricted to active Owner, HR Manager, and Recruiter roles; unrelated active company members cannot read or edit drafts.
- [x] AI resume matching Edge Function now verifies the caller has the `job_seeker` role in addition to requiring explicit AI consent.
- [x] Latest Pages deployment and health workflow were both confirmed successful on 17 November 2026 (commit `be2408bdce0102649f4c0815e7acead4952a085c`).
- [x] State PSC monitor was hardened to use HTTPS-only source URLs, validate redirects, enforce bounded redirects, require HTML/XHTML, and check `robots.txt` before scanning and after redirects.
- [x] Daily State PSC monitor completed successfully on `main` (run `44054341358`): 28 State PSC pages checked; 9 reachable, 19 unreachable/blocked, and 2 pages changed (Nagaland and Tamil Nadu) for manual review. The refreshed report uses HTTPS-only URLs and contains no unverified recruitment snippets; a changed page is not a verified vacancy.
- [x] State PSC public report no longer includes unverified recruitment keyword snippets; CI now rejects such snippets if they reappear.
- [x] Resume application integrity guard added to `supabase-setup-pending.sql`: the database rejects a `resume_id` unless the referenced Resume belongs to the applicant, including null/mismatched candidate IDs.
- [x] Employer applicant-profile access now excludes withdrawn applications in the consolidated Supabase setup SQL.
- [x] Private job-posting draft RLS in the consolidated setup now restricts all draft actions to active Owner, HR Manager, or Recruiter members.
- [x] AI resume-match Edge Function verifies `user_roles.role = job_seeker` on the server before using OpenAI; UI role checks alone are not trusted.
- [x] Interview SQL cancels pending/accepted invitations when an application is withdrawn or rejected, rejects responses for closed applications, suppresses reminders for closed applications, and notifies the company when a candidate withdraws.
- [x] Robots policy matching in both Supabase government/external scanners supports wildcard and end-anchored rules, prefers Allow on equal-length matches, and fails closed when robots policy cannot be checked.
- [x] Read-only Supabase schema audit now includes candidate/resume/notification tables, Storage bucket configuration, and Storage object policies.
- [x] Candidate certification records in the consolidated Supabase setup now have RLS enabled, owner-only write policies, and applicant-only employer read access.
- [x] Candidate withdrawal now cancels pending/accepted interview invitations and notifies the company owner and active HR / Recruiter members; reminder generation skips closed applications.
- [x] Private job search, job details, apply form, and AI matching exclude expired vacancies; the apply page independently blocks late submissions. ISO, DD-MM-YYYY, and DD/MM/YYYY date formats are handled.
- [x] AI matching backend excludes expired jobs and checks `application_deadline`, `deadline`, and `last_date` fields; only Job Seeker accounts with explicit consent can call the AI workflow.
- [x] Public Government Jobs pages now clearly state TAMILAN CAREERS is independent and not government-endorsed; government source links use HTTPS official portals, and the state-job page no longer describes manually curated listings as crawler-verified.
- [x] Latest full health workflow and Pages deployment both passed on commit `f502d7e82b88a4de20b011e2978606ca0cf2d9d1`.
- [x] Latest Pages deployment and full health workflow passed on commit `f18fbe1e3b3e4df7552bda6432167f97f65bba54` (runs `44054190080` and `44054190121`).
- [x] Latest SQL migration lint, Edge Function type checks, privacy guard, browser smoke tests, website health workflow, and Pages deployment all passed on commit `bd78a6f4e69cbe0e440317d30fd9fc58c43e902b`.
- [x] Latest website health run `44052500315` and Pages deployment run `44052501042` both passed on commit `3c58359a079572588724226fd1bfeb6c55a2a930`.


- [ ] Company job draft submission and Admin publication workflow has been strengthened in repository SQL/UI: India-timezone deadline validation, exact company ID preservation, verified-company-only publication, duplicate submission protection, Admin status sync, and monthly/daily salary period. This remains **not live** until schema audit is checked, SQL is run, and real Company → Admin → public-job flow is tested.

## Current live setup and remaining launch work — checked 19 November 2026

### Verified in the live Supabase project
- [x] Supabase project is ACTIVE_HEALTHY.
- [x] All 55 public tables have Row Level Security enabled.
- [x] Live roles: 1 Super Admin and 1 Job Seeker; the first Super Admin bootstrap has already been completed. Do not run it again or grant another privileged role.
- [x] Company profile, company membership, job draft, Admin review, government review, and external candidate tables exist.
- [x] The government notice review queue contains 165 pending records; the external job candidate queue contains 6 pending records. These remain private until manually checked and approved.
- [x] AI-related Edge Functions (ai-resume-match, bilingual-job-search, extract-government-notice-details, generate-job-mock-exam) were inspected in the live project and return HTTP 410 disabled responses. TAMILAN CAREERS must remain a no-AI platform. Do not configure OpenAI keys or enable these functions.
- [x] Health Advisor returned no findings. Security Advisor warnings are documented in PROJECT-STATUS.md; do not remove required authenticated RPC grants without reviewing their caller/ownership checks.
- [x] GitHub Pages deployment and full Health Audit passed for homepage repair commit 9a4d2949476efab54c241c9ec9fd5892b3d68ef6. The subsequent exam-bank expansion also passed the full Health Audit on f81cc6c7e81783e9dfbea18286a1ff4a7a5fb808; the latest Pages deployment after documentation updates must be checked in Actions.

### Real-account tests still required
- [ ] Test Company Draft → Admin Review → Approve → Publish using the existing verified Super Admin and a real authorized Company account.
- [ ] Test Candidate registration/login, profile, search, job details, application, application history, and withdrawal.
- [ ] Test Employer applicant access, application status updates, interview invitations, candidate responses, notifications, and authorized Resume viewing.
- [ ] Test company verification submission, private document upload/download, Admin decision, and cross-account denial.
- [ ] Test the Government notice review page with a Super Admin account; manually verify official notice, dates, eligibility, vacancies, and source links before publishing.
- [ ] Test Android and desktop layouts using real devices/browsers.

### Owner-controlled service settings
- [ ] Enable Supabase Auth Leaked Password Protection.
- [ ] Configure custom SMTP for signup/password-reset email delivery.
- [ ] Configure Resend secrets if Company invitation email delivery is required; otherwise continue using the supported invitation-link sharing flow.
- [ ] Configure the same protected GOVERNMENT_MONITOR_SECRET in Supabase and GitHub Actions only if scheduled source ingestion is to be enabled. Keep automated publishing disabled.
- [ ] Enroll and verify a Super Admin MFA factor before enforcing MFA on Admin access.

### Current production data boundary
- Live snapshot: 2 Auth users, 1 Job Seeker role, 1 Super Admin role, 1 company, 1 company membership, 0 jobs, and 0 applications.
- Public job lists are expected to remain empty until genuine jobs are submitted and approved. Do not insert fabricated vacancies or test applications into production.
- 48 government sources and 30 external job sources are registered. Pending review candidates are not verified vacancies.

## Safety and release rules

- Discovery is not verification. Candidate links must remain private until the original notice, eligibility, dates, vacancy details, and application link are checked.
- Never expose Supabase service-role keys, monitor secrets, passwords, or OTPs in frontend code, GitHub commits, or chat. No OpenAI API key is part of the approved product.
- Do not claim a feature is live until its database setup, function deployment, permissions, and real-user test have all passed.
- Prioritize launch blockers over optional enhancements.


## 17 November 2026 — historical Admin authorization note (superseded)

- Admin Control Center and Admin Job Post check the signed-in user's own user_roles row under RLS.
- The first Super Admin was subsequently assigned; the live audit on 19 November confirms one Super Admin. Follow the current status section above and do not rerun the bootstrap SQL.

- Final verification after the Admin authorization repair: Pages deployment run `44091403705` succeeded for commit `2ac0f9cf236147c30047118351f14918f49786be`; Health Audit run `44091331004` succeeded for code commit `6a1ac636aa6c4420a128ef3fcc643eb83f338013`. All health workflow steps, including browser smoke tests, passed.


## 17 November 2026 — latest post-login and code-side verification

- [x] Post-login routing now returns to the requested same-site page under the GitHub Pages repository base path, preserves query strings, rejects external redirects, and rejects duplicated repository-base paths.
- [x] Protected Candidate Profile, Government Notice Review/Publish, and Dashboard pages now preserve the requested page through login.
- [x] Browser smoke tests cover the redirect helper and key protected-page return targets.
- [x] Latest Pages deployment succeeded for commit `a7c1fa6ce16b6686a2d490923ad37498a8aa7388` (run `44094932098`).
- [x] Latest full Health Audit succeeded for the same commit (run `44094931772`), including Deno checks, SQL lint, privacy/security guards, structural checks, and Chromium browser smoke tests.
- [ ] Enable Supabase Auth leaked-password protection and configure the required email/monitor providers as described in the current section.
- [ ] Complete real-account Candidate, Employer, and Super Admin end-to-end tests. Current live data has two Auth users, one company, zero jobs, and zero applications; production data must not be fabricated for testing.
- [ ] Final release approval after owner actions and real-account tests. A green code-side CI run alone does not make the platform launch-ready.
