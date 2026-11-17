# TAMILAN CAREERS — Project Status & Handover

Last audited: 17 November 2026 (India time) — live Supabase Storage and API access rechecked  
Repository: `arulmuruganbe5540-prog/TAMILAN-CAREERS`  
Live Pages: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/

This file separates repository work from live Supabase setup. A committed HTML, SQL, or Edge Function file is **not** proof that the corresponding Supabase feature is live.

## 1. Confirmed GitHub / website work

- Public GitHub repository and `main` branch are present.
- Latest confirmed GitHub Pages deployment succeeded for commit `026e7b9b4a564b28d896ea141f7b93d8df371b44` (run `44075721444`). Latest confirmed full website health workflow passed for commit `ac3c98b21263da7e2192151d413af4cc7f8f7a35` (run `44075880374`), including SQL lint, Edge Function type checks, private Resume security regression checks, and browser smoke tests.
- The health workflow checks Edge Function types, SQL migration delimiters and SECURITY DEFINER search paths, privacy guards, company publication flow, website structure, and browser smoke tests. The expanded workflow including the new Resume security regression guard passed on commit `5755707f840b6c0db2cb4296f1fd27133f7c36da` (run `44074830855`); the Resume guard, Deno checks, SQL lint, and browser smoke tests all passed.
- The current repository contains Tamil/English public pages for job search, job details, applications, candidate profile, saved jobs, company pages, notifications, Resume documents, Government Jobs, State PSC directory, and exam practice.
- The current repository includes separate Private Jobs and Government Jobs areas; scraped/discovered links are not auto-published.
- A read-only Supabase schema audit is available in `supabase-schema-audit.sql`. It reads schema metadata, RLS policies, grants, function signatures, Storage bucket settings, and Storage policies; it does not modify data or schema.
- The live audit confirmed `candidate-resumes` is the actual private Resume bucket (10 MB bucket limit; 0 stored objects), while no `resumes` bucket exists. Storage owner-folder policies were verified and duplicate SELECT rules were removed.
- Resume upload UI and the employer signed-URL Function now use `candidate-resumes`; `company-resume-access` is deployed ACTIVE (version 1) with JWT verification enabled.
- `supabase-core-api-access.sql` was applied. It grants only the operations already covered by RLS, adds employer read access to candidate profile data for applicants of that company, and lets active HR / Recruiter members load their company's jobs. Employers still have no direct Resume metadata or Storage access.
- Trigger-only SECURITY DEFINER functions (`handle_new_user`, `log_job_application_status`, `rls_auto_enable`) no longer have client EXECUTE permission; their database triggers remain attached.
- A private Resume security regression guard was added to CI. It checks that the website, server Function, SQL migrations, and security guide agree on the bucket name and that employer access remains server-verified. The guard passed in run `44075666298`.
- Schema preflight checks were added to the consolidated setup, focused Resume Storage migration, and employer application-status migration so they stop before changes when required existing columns or types do not match.

## 2. Supabase work confirmed by the user

- `supabase-company-workflow.sql` — user reported successful execution. Company profile drafts and private company job drafts are set up.
- `supabase-candidate-withdraw-application.sql` — user reported successful execution. Candidate-owned application withdrawal is set up.
- `supabase-external-job-sources.sql` — user reported successful execution. External job source registry and private candidate-review tables are set up.
- Live Supabase API grants and employer applicant-profile policies — applied through `supabase-core-api-access.sql`; verification confirms the expected table privileges are now present while RLS remains enabled.
- Edge Function `scan-external-job-sources` — user reported an earlier successful deployment. The newest repository safeguards have **not** yet been redeployed.
- Edge Function `manage-hiring` — deployed, but the currently deployed version is only the login/token and role-status handler; the newer company-member actions are not confirmed deployed.
- The user has shared Storage policy rows for `candidate-resumes` and `job-offers`. These rows prove that policies exist, but do not by themselves prove which buckets currently exist or whether either bucket contains files. The `job-offers` policy calls `public.can_access_job_application(uuid)`; that function is not defined in the repository SQL, so its live definition and security settings must be reviewed from Supabase before relying on the policy.

## 3. Implemented in GitHub, not yet confirmed live in Supabase

- Private Resume upload/list/download/delete UI, owner-only metadata SQL, five-document limit, candidate-owned application Resume link, and 60-second employer signed-URL Function. The live bucket and Function are aligned; authenticated end-to-end upload and employer-view tests remain outstanding.
- Candidate education, work experience, and certification UI and SQL.
- Employer applicant profile read policies and application status update RPC.
- Company job draft → Super Admin review → verified-company publish workflow.
- Interview invitations, candidate accept/decline, notification centre, and reminder generator.
- AI Resume-to-job matching. The local rule-based matcher is separate from the optional AI Function.
- Government notice private review/publish archive and ingestion Function.
- External source scanner latest safeguards and source monitor workflow.

## 4. Live setup still needing confirmation

The following must not be described as live until SQL/function deployment and real-account tests are completed:

1. `supabase-setup-pending.sql` — private Resume Storage, candidate Resume metadata, education/experience/certifications, job drafts hardening, applicant-only employer profile visibility, and application integrity/deadline triggers.
2. `supabase-company-application-status.sql` — secure employer application status changes.
3. `supabase-admin-job-publish-setup.sql` — protected Company Draft → Admin Review → verified-company publish flow.
4. `supabase-interview-notifications.sql` — notification and interview workflow.
5. `supabase-government-archive-install.sql` — separate Government notice source registry, private review queue, and reviewed publication.
6. Deploy/redeploy `ai-resume-match`, `ingest-government-notices`, `bilingual-job-search`, and the latest `scan-external-job-sources` source as applicable. `company-resume-access` is already deployed.
7. The currently deployed `manage-hiring` Function still needs a schema-reviewed member-management implementation.
8. Real Candidate, Employer, Super Admin, and cross-company denial tests remain outstanding.

## 5. Resume Storage — reconciled, end-to-end test pending

- Live bucket: `candidate-resumes`, Private, 10 MB bucket limit; object count currently 0.
- The actual Storage policies restrict SELECT / INSERT / UPDATE / DELETE to the authenticated user's own first-level folder.
- The two redundant legacy SELECT policies were removed. One owner-only rule remains for each Storage operation.
- `resume-documents.html` and `company-resume-access` now both use `candidate-resumes`.
- Edge Function `company-resume-access` is ACTIVE (version 1), with `verify_jwt=true`, and creates a 60-second signed URL only after checking the application, company owner / active HR role, candidate ownership, and folder path.
- The live `candidate_resumes` table references `job_seeker_profiles(user_id)`; the Resume page now checks that a Job Seeker profile exists before allowing upload.
- `supabase-resume-storage.sql`, `supabase-setup-pending.sql`, and `RESUME-SECURITY-SETUP.md` were reconciled to the live bucket and metadata columns.
- No actual Resume objects or attached applications exist yet, so upload, application attachment, signed URL delivery, expiry, and cross-company denial still require authenticated end-to-end testing. Do not describe the full Resume workflow as live until those tests pass.

## 6. Secrets and scheduled monitors

- `OPENAI_API_KEY` is required only for the optional AI Functions; its live Supabase Secret configuration is not confirmed. It must be stored in Supabase Function Secrets, never in frontend code or GitHub source.
- `GOVERNMENT_MONITOR_SECRET` is still unconfigured. The user has asked to defer this setup; do not prompt them to configure it during routine project work.
- The external-source monitor has previously found 23 of 60 registered sources reachable. Robots-blocked/error sources were not bypassed. The monitor's Supabase candidate sync was skipped because the secret was missing.
- Government and external discoveries remain private until an administrator verifies the original official notice and explicitly publishes it.

## 7. User actions required

### End-to-end verification
- No SQL copy/paste is required for the completed bucket reconciliation or core API grants.
- The remaining Resume test needs a signed-in Job Seeker with a saved profile, one real uploaded document, a published job, an attached application, and a separate company owner / active HR account.
- Real Candidate, Employer, Super Admin, and cross-company denial tests remain outstanding. Do not share passwords, OTPs, service-role keys, or other secrets in chat.

## Release rule

The website is **not launch-ready yet**. The target launch date is 19 November 2026, but that date is conditional, not guaranteed. GitHub Pages deployment is working, but the remaining Supabase migrations, Function deployments, secrets (where needed), RLS verification, and real-account tests are launch blockers. Do not mark the project complete until those checks pass.
