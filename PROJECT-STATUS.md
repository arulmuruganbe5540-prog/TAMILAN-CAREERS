# TAMILAN CAREERS — Project Status & Handover

Last audited: 17 November 2026 (India time)  
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
- The audit was expanded to compare `resumes`, `candidate-resumes`, and `job-offers` bucket settings; count stored objects without exposing paths; and retrieve the live `can_access_job_application` function definition.
- A private Resume security regression guard was added to CI. It checks that the website, server Function, SQL migrations, and security guide agree on the bucket name and that employer access remains server-verified. The guard passed in run `44075666298`.
- Schema preflight checks were added to the consolidated setup, focused Resume Storage migration, and employer application-status migration so they stop before changes when required existing columns or types do not match.

## 2. Supabase work confirmed by the user

- `supabase-company-workflow.sql` — user reported successful execution. Company profile drafts and private company job drafts are set up.
- `supabase-candidate-withdraw-application.sql` — user reported successful execution. Candidate-owned application withdrawal is set up.
- `supabase-external-job-sources.sql` — user reported successful execution. External job source registry and private candidate-review tables are set up.
- Edge Function `scan-external-job-sources` — user reported an earlier successful deployment. The newest repository safeguards have **not** yet been redeployed.
- Edge Function `manage-hiring` — deployed, but the currently deployed version is only the login/token and role-status handler; the newer company-member actions are not confirmed deployed.
- The user has shared Storage policy rows for `candidate-resumes` and `job-offers`. These rows prove that policies exist, but do not by themselves prove which buckets currently exist or whether either bucket contains files. The `job-offers` policy calls `public.can_access_job_application(uuid)`; that function is not defined in the repository SQL, so its live definition and security settings must be reviewed from Supabase before relying on the policy.

## 3. Implemented in GitHub, not yet confirmed live in Supabase

- Private Resume upload/list/download/delete UI, owner-only metadata SQL, five-document limit, candidate-owned application Resume link, and 60-second employer signed-URL Function.
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
6. Deploy/redeploy `company-resume-access`, `ai-resume-match`, `ingest-government-notices`, `bilingual-job-search`, and the latest `scan-external-job-sources` source as applicable.
7. The currently deployed `manage-hiring` Function still needs a schema-reviewed member-management implementation.
8. Real Candidate, Employer, Super Admin, and cross-company denial tests remain outstanding.

## 5. Resume Storage mismatch — current blocker

- Website page `resume-documents.html` currently uses bucket `resumes`.
- Function `company-resume-access` currently signs files from bucket `resumes`.
- Both Resume SQL migrations currently create/configure private bucket `resumes`.
- The Storage policy rows supplied by the user reference bucket ID `candidate-resumes`.
- Do not run the Resume migration, rename/delete a bucket, or move files until the actual bucket inventory is checked. The updated read-only schema audit now reports both bucket IDs.

## 6. Secrets and scheduled monitors

- `OPENAI_API_KEY` is required only for the optional AI Functions; its live Supabase Secret configuration is not confirmed. It must be stored in Supabase Function Secrets, never in frontend code or GitHub source.
- `GOVERNMENT_MONITOR_SECRET` is still unconfigured. The user has asked to defer this setup; do not prompt them to configure it during routine project work.
- The external-source monitor has previously found 23 of 60 registered sources reachable. Robots-blocked/error sources were not bypassed. The monitor's Supabase candidate sync was skipped because the secret was missing.
- Government and external discoveries remain private until an administrator verifies the original official notice and explicitly publishes it.

## 7. User actions required

### Immediate
- Run the updated read-only `supabase-schema-audit.sql` in the Supabase SQL Editor and provide the result sets, especially the bucket inventory for `resumes` / `candidate-resumes`, the full column/constraint/policy results, and the `can_access_job_application` function definition. This is needed to reconcile Storage and safely verify schema-dependent migrations.

### After the schema is reconciled
- Run only the reviewed Supabase SQL migrations in the documented order, one at a time, and share success/error results.
- Deploy the required Edge Functions from the reviewed source. Never share service-role keys, OpenAI keys, monitor secrets, passwords, or OTPs in chat.
- Perform the Android Candidate/Employer/Admin end-to-end tests using separate test accounts and confirm the outcomes.

## Release rule

The website is **not launch-ready yet**. The target launch date is 19 November 2026, but that date is conditional, not guaranteed. GitHub Pages deployment is working, but the remaining Supabase migrations, Function deployments, secrets (where needed), RLS verification, and real-account tests are launch blockers. Do not mark the project complete until those checks pass.
