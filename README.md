# TAMILAN CAREERS

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
- Saved jobs: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/saved-jobs.html
- Job seeker profile: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/job-seeker-profile.html
- Resume & documents: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/resume-documents.html
- Company job posting draft: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/job-posting.html
- Private job-draft database SQL: `supabase-job-posting-drafts.sql`
- Consolidated pending Supabase setup: `supabase-setup-pending.sql` (resume storage + private job drafts + employer applicant-profile read policies + owner-only candidate resume metadata and Job Seeker profile self-management policies + Job Seeker profile self-management RLS)
- Indian Government Jobs: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/indian-government-jobs.html
- Tamil Nadu Government Jobs: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/tamil-nadu-government-jobs.html

## Main features currently in the repository
- Tamil / English responsive public homepage, job search and individual job details pages.
- Supabase email registration, login, password reset flow and account dashboard.
- Job seeker profile editor connected to `profiles`, `job_seeker_profiles`, `candidate_skills`, `candidate_languages` and `candidate_preferences` (requires matching RLS policies).
- Saved jobs page with browser-local save/remove controls (not account-synced).
- Job application form frontend with Job Seeker role check and private application submission.
- Applicant application-tracking page linked from the Job Seeker dashboard.
- Government job information portals for India and Tamil Nadu.
- Terms, privacy, about and Tamil help pages.
- Resume and document management frontend with private Storage upload/download/delete and `candidate_resumes` metadata synchronization (consolidated Supabase SQL required).

## Supabase setup required
- `supabase-setup-pending.sql` is the consolidated setup script for private resume storage, private company job-posting drafts, and employer read access to profiles of candidates who actually applied to that employer's company.
- It replaces the three separate setup steps for those features. Run only after reviewing the SQL and confirming the project schema matches the documented tables/columns.
- Candidate resume metadata (`candidate_resumes`) is owner-only under the consolidated SQL; employers are not granted direct resume metadata or file access.
- The resumes bucket must remain PRIVATE. The script does not make resumes available to employers; employer resume access requires a separate server-verified, short-lived signed URL workflow.
- After running, verify the `resumes` bucket is private, the `job_posting_drafts` table exists, and the employer read policies are present. Then test with separate Job Seeker and Company test accounts.
- Never expose service-role keys in browser code.

## Important implementation status
- Job search reads the Supabase `jobs` table; real listing visibility depends on the table schema, RLS and published job records.
- Job application frontend is committed. Run `supabase-job-applications.sql` only after confirming `public.jobs.id` is UUID; then test with a Job Seeker account.
- Employer applicant-profile read policies have been prepared in `supabase-setup-pending.sql`, but they are not live until that script is run and verified in Supabase. Application status changes and employer resume downloads are not implemented.
- Government job pages provide information and official links; verify every vacancy and deadline at the relevant official source.
- Never pay an individual or share OTPs, passwords, bank PINs or account credentials to obtain a job.

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
