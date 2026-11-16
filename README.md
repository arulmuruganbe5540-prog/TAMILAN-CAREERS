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
- Saved jobs: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/saved-jobs.html
- Job seeker profile: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/job-seeker-profile.html
- Resume & documents: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/resume-documents.html
- Company job posting draft: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/job-posting.html
- Private job-draft database SQL: `supabase-job-posting-drafts.sql`
- Indian Government Jobs: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/indian-government-jobs.html
- Tamil Nadu Government Jobs: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/tamil-nadu-government-jobs.html

## Main features currently in the repository
- Tamil / English responsive public homepage, job search and individual job details pages.
- Supabase email registration, login, password reset flow and account dashboard.
- Job seeker profile editor.
- Saved jobs page with browser-local save/remove controls (not account-synced).
- Job application form frontend with Job Seeker role check and private application submission.
- Applicant application-tracking page linked from the Job Seeker dashboard.
- Government job information portals for India and Tamil Nadu.
- Terms, privacy, about and Tamil help pages.
- Resume and document management frontend (private Storage setup required).

## Supabase setup required for private resume storage
1. Open the Supabase project SQL Editor.
2. Open `supabase-resume-storage.sql` in this repository.
3. Review the SQL and run it in the SQL Editor while signed in as the project owner.
4. Confirm that a private Storage bucket named `resumes` exists and that the four `TC resumes owner ...` policies are present.
5. Test upload, list, signed download and delete using a Job Seeker test account.

The SQL creates a non-public bucket with a 5 MB file limit and PDF/DOC/DOCX MIME restrictions. Storage object policies restrict access to the authenticated user's own first-level folder. Do not make this bucket public and do not expose service-role keys in browser code.

## Important implementation status
- Job search reads the Supabase `jobs` table; real listing visibility depends on the table schema, RLS and published job records.
- Job application frontend is committed. Run `supabase-job-applications.sql` only after confirming `public.jobs.id` is UUID; then test with a Job Seeker account. Employer review access and end-to-end application processing are not yet implemented or verified.
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
- Run `supabase-job-posting-drafts.sql` in the Supabase SQL Editor to create the private `job_posting_drafts` table and owner/active-company-member RLS policies.
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
- Applicant records remain hidden until a reviewed employer SELECT RLS policy is added to `job_applications`. The existing applicant-only policy is intentionally not weakened. Application status changes are not enabled until a secure server-side workflow and authorization checks are implemented.
