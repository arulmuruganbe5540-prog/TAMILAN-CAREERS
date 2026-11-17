# TAMILAN CAREERS — Launch Readiness Checklist

Last reviewed: 17 November 2026

This is an operational checklist based on the project changes and user-confirmed setup steps available at the time of writing. A feature is not considered live merely because its code or SQL file exists.

## Confirmed complete

- [x] Latest GitHub Pages deployment succeeded for commit `7b4ed7b4fa396bb2cb7eeaa0dd586940444db5c8` (run `44065324676`; build, deploy, and status-report jobs all succeeded).
- [x] Latest full website health workflow passed for commit `7b4ed7b4fa396bb2cb7eeaa0dd586940444db5c8` (run `44065323970`; audit job succeeded).
- [x] Read-only schema audit now compares both `resumes` and `candidate-resumes` Storage bucket IDs so the live bucket can be reconciled before Resume setup.
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

## Must finish before enabling external source scanning

- [ ] Create a unique random `GOVERNMENT_MONITOR_SECRET` of at least 32 characters. Do not paste it into chat or commit it.
- [ ] Redeploy the latest scanner source from GitHub after the recent bounded-response, non-HTML response rejection, and per-source status fixes. The user-confirmed deployment was the earlier version; repository changes are not live until redeployed.
- [ ] Add the exact same secret in Supabase Edge Function Secrets and GitHub repository Actions Secrets.
- [ ] Check the scanner Edge Function's **Verify JWT with legacy secret** setting. Because the function uses its own `x-monitor-secret` header, the gateway must not block the request by requiring a Supabase JWT; turn legacy JWT verification off if it is on.
- [ ] Run the GitHub workflow manually and inspect the private candidate queue.
- [ ] Verify the Admin review page with a Super Admin account.
- [ ] Confirm that only reviewed, verified notices can enter the public jobs/notice feed.

## Supabase setup and deployment still needing confirmation

- [ ] Run `supabase-setup-pending.sql` for private resume storage, candidate resume metadata, private employer job drafts, candidate education/experience/certifications, and restricted applicant-profile access. Verify the Storage bucket remains private.
- [ ] Resolve the Resume Storage bucket-name mismatch before running setup: existing Storage policy output references `candidate-resumes`, while the current website, Edge Function, and setup SQL use `resumes`. Run the updated bucket audit and preserve any existing files; do not delete or rename buckets blindly.
- [ ] Deploy `company-resume-access` Edge Function and test a legitimate employer access plus a denied cross-company access. Secure resume viewing is not live until this is tested.
- [ ] Run `supabase-interview-notifications.sql`; test invitation, candidate response, and notifications for both parties. Automated reminders additionally need a secure scheduler/Cron.
- [ ] Run `supabase-candidate-profile-education-experience.sql`; test saving and editing education, experience, and certifications. (The consolidated `supabase-setup-pending.sql` also includes these records.)
- [ ] Run `supabase-company-application-status.sql`; test permitted and denied employer status updates.
- [ ] Run `supabase-admin-job-publish-setup.sql` after `supabase-setup-pending.sql`; test Company Draft → Admin Review → Approve → Publish with a verified company. The submission RPC validates active company role, preserves the exact company ID, syncs Admin decisions back to the private draft, and rejects past deadlines.
- [ ] For Government Jobs archive, run `supabase-government-archive-install.sql`, deploy `ingest-government-notices`, configure its protected monitor secret, and test the private review queue. Do not auto-publish scraped links.
- [ ] For AI resume matching, redeploy the latest `ai-resume-match` source (Bearer token parsing was corrected in GitHub), add `OPENAI_API_KEY` as a Supabase Function Secret, and test with explicit candidate consent. Rule-based matching and AI matching must be described separately.
- [ ] Review the deployed `manage-hiring` function and exact company/member schema before replacing the current minimal login/status handler with member-management actions. Do not deploy schema-dependent changes without the schema audit.

## Final launch checks

- [ ] Test candidate registration, login, profile, job search, job details, application, and application history on Android.
- [ ] Test company registration/login, company profile, job draft, job publishing approval, applicant list, and resume authorization.
- [ ] Test Government Jobs and Private Jobs as separate sections.
- [ ] Confirm that no unverified vacancy, fake company partnership, or unauthorized logo is displayed.
- [ ] Confirm email delivery, password reset, and notification behavior using real test accounts.
- [ ] Check latest GitHub Pages deployment and latest health workflow after the final commit.
- [ ] Perform a final mobile browser review and fix launch-blocking issues.

## Safety and release rules

- Discovery is not verification. Candidate links must remain private until the original notice, eligibility, dates, vacancy details, and application link are checked.
- Never expose Supabase service-role keys, OpenAI keys, monitor secrets, passwords, or OTPs in frontend code, GitHub commits, or chat.
- Do not claim a feature is live until its database setup, function deployment, permissions, and real-user test have all passed.
- Prioritize launch blockers over optional enhancements.
