# TAMILAN CAREERS

> **Current project status:** [PROJECT-STATUS.md](PROJECT-STATUS.md) is the authoritative handover for what is confirmed in GitHub, what is confirmed in Supabase, and what still requires setup/testing. Do not treat committed code as a live Supabase feature.

தமிழ்நாடு மற்றும் இந்தியா முழுவதும் வேலை தேடுவோரையும் வேலைவாய்ப்பு வழங்கும் நிறுவனங்களையும் இணைக்கும் தமிழ்-முன்னுரிமை வேலைவாய்ப்பு தளம்.

## Live website
- Homepage: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/
- Job search: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/jobs.html
- Job details: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/job-details.html
- Apply for a job: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/apply.html
- My applications: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/my-applications.html
- Company applicant dashboard: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/company-applicants.html
- Job applications database SQL: `supabase-job-applications.sql`
- Read-only schema and RLS audit SQL: `supabase-schema-audit.sql`
- Government notices database setup SQL: `supabase-government-notices-setup.sql` (creates isolated source, private review and public published-notice tables; does not auto-publish or alter existing job/application tables).
- Government notice discovery Edge Function: `supabase/functions/ingest-government-notices/index.ts` (server-side scan of enabled registered sources; writes candidates only to the private review table; never publishes).
- Admin Job Post & Review Queue: `admin-job-post.html` (Super Admin + MFA AAL2 only; use `supabase-admin-job-publish-setup.sql` for the protected review queue and secure publish function. Company-submitted jobs require a verified company; manual Super Admin posts can be entered directly).
- Admin Control Center: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/admin-control.html (responsive Admin dashboard; requires the signed-in user's `super_admin` role and MFA AAL2; links to admin/workflow pages).
- Initial Super Admin bootstrap: `supabase-first-super-admin-bootstrap.sql` (one-time, guarded SQL for the project owner to grant the first `super_admin` role to an explicitly selected existing Auth account; requires replacing the email placeholder and running it manually in Supabase SQL Editor). Admin browser pages now read only the signed-in user's own `user_roles` row under RLS rather than calling the revoked public SECURITY DEFINER RPC.
- Admin government notice review page: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/government-notice-review.html (review queue with category/status filters and verification checklist; access is enforced by Supabase RLS and Super Admin authorization).
- New government portal discovery: `scripts/government-source-discovery.py` scans links from already trusted government sources and creates `government-source-discovery-candidates.json`. Newly found domains are suggestions only and require verification before joining the trusted list; this runs every six hours with the official-source monitor.
- Saved jobs: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/saved-jobs.html
- Job seeker profile: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/job-seeker-profile.html
- Resume job matching: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/ai-job-matches.html
- Resume & documents: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/resume-documents.html
- Company job posting draft: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/job-posting.html
- Private job-draft database SQL: `supabase-job-posting-drafts.sql`
- Consolidated pending Supabase setup: `supabase-setup-pending.sql` (private resume storage + job drafts + restricted employer applicant-profile access + owner-only candidate resume, education, experience and certification records).
- Candidate education / experience / certification migration: `supabase-candidate-profile-education-experience.sql`.
- Supabase launch setup guide (Tamil, ordered SQL / Edge Function / Secret / testing steps): `SUPABASE-LAUNCH-SETUP-GUIDE.md`.
- Launch readiness checklist: `LAUNCH-READINESS-CHECKLIST.md`.
- Indian Government Jobs: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/indian-government-jobs.html
- All 28 State Government Jobs (official State PSC directory + verified notification tracker): https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/state-government-jobs.html
- Daily 28-state PSC source-monitor report: `state-job-monitor-report.json` (first scheduled run pending; source changes require manual vacancy verification).
- Tamil Nadu Government Jobs: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/tamil-nadu-government-jobs.html
- Government Exam Preparation: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/exam-preparation.html

## Main features currently in the repository
- Resume-to-job matching page: reads PDF/DOCX text locally in the browser and ranks currently published internal jobs against profile/resume keywords, skills and preferred location (transparent rule-based first version; not generative AI).
- Tamil / English responsive public homepage, job search and individual job details pages.
- Supabase email registration, login, password reset flow and account dashboard.
- Job seeker profile editor connected to `profiles`, `job_seeker_profiles`, `candidate_skills`, `candidate_languages`, `candidate_preferences`, `candidate_education` and `candidate_experience`; supports multiple education, work-history and certification records with add/edit/delete controls (requires matching RLS policies).
- Saved jobs page with browser-local save/remove controls (not account-synced).
- Job application form frontend with Job Seeker role check and private application submission.
- Applicant application-tracking page linked from the Job Seeker dashboard; candidates can request withdrawal of their own active applications through a server-side permission-checked RPC.
- Government job information portals for India and Tamil Nadu.
- All-India State Government Jobs directory: searchable directory for all 28 states with official State Public Service Commission links, department-wise recruitment categories, application guidance and warnings about domicile / language eligibility. A GitHub Actions workflow (`.github/workflows/state-psc-monitor.yml`) is scheduled daily at 08:00 IST to check all 28 official PSC pages for source-page changes; its Python monitor writes `state-job-monitor-report.json` when the snapshot changes. This is a change detector only, not an automatic vacancy verifier or application feed; detected changes still require manual review of the official notice. The manually curated, source-linked notification tracker was checked on 16 Nov 2026 and includes: APPSC Group-II Notification 37/2026 (720 posts; 10 Nov–11 Dec 2026; 13 Nov corrigendum); TGPSC MPSO/ASO Notification 07/G/ES/2026 (30 Oct–27 Nov 2026); Meghalaya MPSC Advt 01/2026-2027 (five post categories, 12 Nov–12 Dec 2026); Goa Assistant Public Prosecutor (20 posts, deadline 27 Nov 2026) and Goa State Pollution Control Board posts (deadline 30 Nov 2026); Odisha OPSC Scientific Officer Group-B (89 posts, 6–26 Nov 2026); Kerala PSC Gazette Categories 162–173/2026 (last date 2 Dec 2026) and latest Gazette Categories 175–192/2026 dated 16 Nov 2026 (last date 16 Dec 2026); UPPSC Samiksha Adhikari / Sahayak Samiksha Adhikari Advt A-4/E-1/2026 (last date 26 Nov 2026) and Miscellaneous Examination Advt A-5/E-1/2026 (last date 4 Dec 2026); Himachal Pradesh HPPSC Agriculture Development Officer (23 posts, Advt 63/9-2026; extended last date 30 Nov 2026).; Gujarat GPSC Sports Authority engineering posts — Deputy Executive Engineer (Civil) and Assistant Engineer (Civil), 8 total posts, Advt 62/2026-27 & 63/2026-27 (last date 20 Nov 2026). The tracker is not an automatically refreshed feed; these entries are manually checked and must be rechecked on the official site before applying. Non-PSC department recruitments must also be checked at official department / recruitment-board sites.
- Government Exam Preparation starter: exam categories for TNPSC/TNUSRB/TRB, UPSC/SSC, Railway and Banking; 45 original TNPSC practice questions: 15 each for Group IV, Group II/IIA and Group I. Each exam has a separate question pool and relevant topic filters; timed 5/10/15-question practice, answer explanations, result review and browser-local progress are included. Group II/IIA prelim questions cover Tamil, General Studies and Aptitude; Group I prelim questions cover General Studies and Aptitude. These are original sample questions, not official or previous-year papers; full syllabus coverage, mains practice and account-synced progress remain future phases.
- Terms, privacy, about and Tamil help pages.
- Resume and document management frontend with private Storage upload/download/delete and `candidate_resumes` metadata synchronization (consolidated Supabase SQL required).

## Supabase setup required
- The consolidated SQL also adds owner-only self-management RLS for `candidate_education` and `candidate_experience`.
- `supabase-setup-pending.sql` is the consolidated setup script for private resume storage, private company job-posting drafts, and employer read access to profiles of candidates who actually applied to that employer's company.
- It replaces the three separate setup steps for those features. Run only after reviewing the SQL and confirming the project schema matches the documented tables/columns.
- Candidate resume metadata (`candidate_resumes`) is owner-only under the consolidated SQL; employers are not granted direct resume metadata or file access.
- The resumes bucket must remain PRIVATE. The script does not make resumes available to employers; employer resume access requires a separate server-verified, short-lived signed URL workflow.
- After running, verify the `resumes` bucket is private, the `job_posting_drafts` table exists, and the employer read policies are present. Then test with separate Job Seeker and Company test accounts.
- Never expose service-role keys in browser code.

## Important implementation status
- Job search reads the Supabase `jobs` table; real listing visibility depends on the table schema, RLS and published job records.
- Job application frontend is committed. Run `supabase-job-applications.sql` only after confirming `public.jobs.id` is UUID; then test with a Job Seeker account.
- Candidate application withdrawal: `my-applications.html` provides a withdrawal control for the signed-in candidate's own `applied`, `under_review` or `shortlisted` application through `tc_candidate_withdraw_application`; run `supabase-candidate-withdraw-application.sql` once in Supabase SQL Editor. The function never permits withdrawing another candidate's application or changing already rejected/withdrawn applications.
- Employer application status workflow: `company-applicants.html` now provides secure status changes (under review, shortlisted, rejected) through `tc_company_update_application_status`; run `supabase-company-application-status.sql` once in Supabase SQL Editor. The function checks the signed-in user's active company membership and only permits updates for that company's applications.
- Employer applicant-profile read policies have been prepared in `supabase-setup-pending.sql`, but they are not live until that script is run and verified in Supabase. Application status changes and employer resume downloads are not implemented.
- Government job pages provide information and official links; verify every vacancy and deadline at the relevant official source.
- Never pay an individual or share OTPs, passwords, bank PINs or account credentials to obtain a job.


### Bilingual AI job search (deployment required)
- `jobs.html` includes a separate AI search action that can understand a query written in any language and returns job titles, descriptions, locations, skills and match reasons in Tamil and English only. The existing whole-site language selector is unchanged.
- Backend source: `supabase/functions/bilingual-job-search/index.ts`. It requires a signed-in user, reads only published jobs under that user's Supabase RLS permissions, ranks relevant jobs, and translates only supplied job facts. It does not use the service-role key.
- Deployment: `supabase functions deploy bilingual-job-search`. Configure `OPENAI_API_KEY` in Supabase Edge Function Secrets. Supabase must provide `SUPABASE_URL` and `SUPABASE_ANON_KEY` to the function. Keep the OpenAI key out of browser code and GitHub.
- AI search may incur API charges and currently evaluates at most 100 published job rows per request. Ordinary database search remains available without signing in; the any-language AI search requires login and a deployed function.
- Source code is committed but the Edge Function has not yet been deployed or live-tested. Do not advertise the AI search as live until deployment, secret setup and an authenticated test succeed.

### Automatic job-data and technology maintenance
- Government source discovery and state PSC page-change monitoring run on schedules and report candidates/changes; source monitoring does not prove that a vacancy is open. New sources and vacancies require verification before publication.
- Job listing freshness must be handled by scheduled trusted-source sync, expiry checks and duplicate detection. Do not invent vacancy counts or publish unverified scraped jobs.
- `.github/dependabot.yml` asks GitHub to check GitHub Actions updates weekly and open update pull requests. These PRs are tested before merging; unreviewed dependency or application-code updates are not pushed straight to the live website.
- New job-search and AI tools should be added through tested releases, not by allowing an automated agent to rewrite production code automatically. Security fixes, API/model changes and database migrations require validation and a rollback path.

## Technology
- Static responsive HTML/CSS/JavaScript frontend
- Supabase Auth, Database and Storage
- GitHub Pages hosting


### Company profile draft
- `company-profile.html` lets an authenticated user save a company profile draft in their own Supabase Auth user metadata.
- The dashboard links to the page for company users.
- This is a draft only: it does not verify a company, create a trusted company record, grant employer permissions, or enable job posting. Those require a reviewed database schema, secure server-side validation, and RLS policies.


### Company job posting draft
- `job-posting.html` provides a structured job-detail form for users with an active `company_members` membership.
- The page checks the signed-in user's active company memberships and saves a private job-posting draft in `job_posting_drafts`.
- This is not a published job: it does not insert into the `jobs` table, accept applications, verify job content, or grant posting permission. A secure server-side workflow, reviewed schema, RLS and moderation process are still required before public posting.

### Private job-posting draft database
- The private `job_posting_drafts` table and its RLS policies are included in `supabase-setup-pending.sql` (or can be run separately using `supabase-job-posting-drafts.sql`).
- After the SQL is applied, `job-posting.html` reads and saves drafts in that table per company and signed-in member.
- This table is for private drafts only. It deliberately does not insert into `jobs`, publish vacancies, accept applications, or grant public posting permissions.
- The SQL has not been executed against the live Supabase project from this repository workflow; verify the table and policies in Supabase before testing the form.


### Job application setup
- `apply.html` loads the selected job, requires a signed-in `job_seeker` role, and submits applicant details to `job_applications`.
- Before enabling submission, inspect `public.jobs.id` and confirm its type is UUID. Then review and run `supabase-job-applications.sql` in the Supabase SQL Editor.
- The SQL lets an applicant submit one application per job and read only their own application records. It does not yet grant employer access to applicant records; that must be implemented after verifying the actual company/job ownership schema.
- Do not announce applications as live until the SQL is applied and a real test application is confirmed.

- `my-applications.html` lists the signed-in Job Seeker's own applications and their status, using the applicant-only SELECT policy.


### Company applicant dashboard
- `company-applicants.html` provides a company-member-gated workspace and lists jobs associated with the selected company when the `jobs.company_id` field and corresponding read policy permit it.
- `supabase-setup-pending.sql` prepares restricted SELECT access to applicant profile details for the employer whose job received the application. This SQL has not yet been run against the live Supabase project. The existing applicant-only application policy is not weakened. Application status changes are not enabled until a secure server-side workflow and authorization checks are implemented.


### Read-only schema and RLS audit
- `supabase-schema-audit.sql` reports relevant public table columns/types, foreign-key/unique/check constraints and RLS policies for jobs, companies, company_members and job_applications. It performs no DDL or data changes.
- Use its results to verify actual `jobs.id` type and company/job ownership relationship before creating employer applicant-read or status-update policies.

### AI resume matching backend (deployment required)
- `ai-job-matches.html` now offers an optional AI matching action in addition to the local rule-based matcher. It requires the user to explicitly tick a consent checkbox before any resume text is sent to the AI service.
- Secure Edge Function source: `supabase/functions/ai-resume-match/index.ts`. It validates the signed-in Supabase user, reads candidate profile data and published jobs under that user's Supabase permissions/RLS, sends only job-related candidate context and resume text to the OpenAI Responses API, and returns structured match explanations. It does not use the service-role key.
- The Edge Function requires the Supabase function secrets `OPENAI_API_KEY` (user-provided OpenAI API key), `SUPABASE_URL`, and `SUPABASE_ANON_KEY`. Supabase normally provides the latter two as Edge Function default environment variables; verify they are available in the deployed function environment.
- Deploy the function from the Supabase project using the Supabase CLI: `supabase functions deploy ai-resume-match`. Then add `OPENAI_API_KEY` under Supabase Project Settings → Edge Functions → Secrets (or the equivalent Secrets page in the current dashboard). Do not put this key in HTML, GitHub, or browser code.
- The AI request is optional and may incur OpenAI API charges on the account that owns the key. Keep the key private and monitor usage. Resume text is sent to OpenAI only after explicit consent; users should remove unnecessary personal identifiers from the resume first.
- The AI backend source and frontend JavaScript have been committed, but the Edge Function has not been deployed or live-tested from this repository workflow. AI matching will show a setup message until deployment and secret configuration are complete. The existing local rule-based matcher remains available.


## Advanced government recruitment discovery (initial implementation)
- Source registry: `data/government-official-sources.json`. It lists central recruiting bodies and State PSC / Tamil Nadu recruitment boards, with an explicit authority name and official entry URL.
- Monitor: `scripts/government-job-monitor.py`. The scheduled workflow checks registered source pages every six hours, follows only links on the same registered official host (HTTPS), detects recruitment / result / answer-key / admit-card / exam-update link candidates, deduplicates them, and writes `government-job-review-queue.json` plus `government-job-monitor-report.json`.
- Workflow: `.github/workflows/government-job-monitor.yml`; scheduled at minute 17 every six hours and can also be manually started from GitHub Actions.
- **Safety boundary:** discovery is not verification. A matching link does not prove that a vacancy is open, dates are current, eligibility is correct, or a PDF is genuine. Every candidate remains `pending_admin_verification`; `publish_allowed` is always false. No government job is automatically published by this first phase.
- The repository is public, so the JSON review queue is also publicly readable. It contains discovered official-site links only, not applicant data or credentials. It is not yet a private Admin Dashboard. A private Supabase review table with strict admin-only RLS, verified notice/PDF checks, audit history and an explicit publish action is the next backend phase.
- The monitor does not scrape CAPTCHA/login-protected portals, bypass access controls, or treat third-party job sites as authoritative. Some sites may block automated requests or change layout; failures are reported, not interpreted as "no jobs".
- No Supabase SQL has been executed and no public vacancy auto-publishing has been enabled by this change.


## Continuous website maintenance (starter)
- Daily read-only structural audit: `scripts/website-health-check.py` checks local HTML pages, internal links/assets, duplicate IDs, image alt text and mobile viewport metadata.
- Workflow: `.github/workflows/website-health-check.yml` runs daily and after relevant website/script changes, then stores `website-health-report.json`.
- The audit reports issues; it does not silently rewrite production code. Authentication, Supabase permissions, resume uploads, email delivery, external job-source correctness, performance under real traffic and complete user journeys require separate integration tests and live monitoring.
- Content freshness and software maintenance are separate systems: job feeds/source monitors update listings; controlled code releases update website features. Security-sensitive changes require review and backup before release.


## Admin job publishing setup
- Run `supabase-admin-job-publish-setup.sql` once in the Supabase SQL Editor. This creates the Admin-only review queue, adds optional display fields to `public.jobs` (`location`, `education_level`, `required_skills`, `contact_email`), and installs `public.tc_admin_publish_job(uuid)`.
- The publish function re-checks Super Admin permission (including the MFA AAL2 helper), requires the review item to be approved, and validates active job category and required fields. Company-submitted jobs require an exact match with `companies.verification_status = 'verified'`; manually entered Super Admin posts may be published without linking a company record. It inserts a `published` row and records its ID on the review item. Repeated publish calls for the same item return the existing job ID.
- The function does not weaken the existing `jobs` RLS policies. The function is SECURITY DEFINER and executable only by authenticated users; it performs its own Super Admin check.
- The category is linked only when an active `job_categories.category_name` exactly matches the selected category; otherwise the publish function rejects the post.
- Existing job rows are not deleted or rewritten. The migration is safe to re-run.


## Official external job-source discovery (admin review only)
- Admin candidate review: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/external-job-review.html
- Setup guide: `EXTERNAL-JOB-SOURCES-SETUP.md`
- Source registry SQL: `supabase-external-job-sources.sql`
- Supabase scanner: `supabase/functions/scan-external-job-sources/index.ts`
- GitHub scheduled workflow: `.github/workflows/external-job-source-monitor.yml`
- Important: discovered links stay private and pending until an administrator verifies the original notice, eligibility, dates and application link. The scanner never publishes jobs automatically. Scheduled scanning remains inactive until `GOVERNMENT_MONITOR_SECRET` is configured in both Supabase Edge Function Secrets and GitHub Actions repository secrets.

- Launch readiness checklist: `LAUNCH-READINESS-CHECKLIST.md` (confirmed completed items, pending Supabase setup, security checks, and final launch tests).
