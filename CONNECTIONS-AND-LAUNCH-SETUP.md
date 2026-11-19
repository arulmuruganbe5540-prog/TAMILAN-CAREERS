# TAMILAN CAREERS — Required Connections & Launch Setup

Last checked: 17 November 2026 (India time)

Live website: https://tamilancareers.in/
GitHub repository: https://github.com/arulmuruganbe5540-prog/TAMILAN-CAREERS
Supabase project: https://supabase.com/dashboard/project/qkmljuuusfjowexvybvy

## Already connected and verified
- GitHub repository and GitHub Pages deployment are connected.
- Supabase project is connected to the website using its project URL and browser-safe public/anon key. Never place a Supabase service-role/secret key in website HTML or JavaScript.
- The operational Supabase Edge Functions include company-members, company-resume-access, scan-external-job-sources, and ingest-government-notices. Legacy AI-related functions are disabled and must remain unused.
- Latest GitHub Pages deployment run `44095184723` succeeded for commit `cd607324586ab899ecf154442dc123ed3fd44831`.
- Latest full Health Audit run `44094931772` succeeded for commit `a7c1fa6ce16b6686a2d490923ad37498a8aa7388`. Deno type-check, SQL delimiter lint, privacy guards, website structure, JavaScript checks, and browser smoke tests all passed.

## External provider connections still needed

Add secrets only in the provider dashboards listed below. Do not send secret values in ChatGPT, email, screenshots, GitHub source files, or public issues.

### 1. AI features — intentionally excluded
AI Job Matching, AI Resume Matching, AI-powered bilingual search, and AI notice extraction are outside the approved product scope. Do not add an OpenAI API key or enable the legacy AI Edge Functions. Resume search remains local and rule-based; Government and job notices require human Admin review.

### 2. Resend — company invitation emails
Create a Resend account, verify a sender/domain if possible, and add these Supabase Edge Function secrets:
- `RESEND_API_KEY` — required
- `APP_BASE_URL` — set exactly to `https://tamilancareers.in`
- `RESEND_FROM_EMAIL` — optional; use an email sender verified in Resend

Used by `company-members`. Without these, invitation records and team management code exist, but real email delivery cannot be verified.

### 3. Government/external-source monitor — scheduled sync
This connection is intentionally deferred until the owner is ready to enable scheduled ingestion.

Create one long random secret and set the exact same value in both places:
- Supabase Edge Function secret: `GOVERNMENT_MONITOR_SECRET`
- GitHub repository Actions secret: `GOVERNMENT_MONITOR_SECRET`

GitHub path: repository → Settings → Secrets and variables → Actions → New repository secret.

Used by:
- Supabase `scan-external-job-sources`
- Supabase `ingest-government-notices`
- GitHub scheduled workflows for external and government source scans

Do not enable automated publishing. Discovered notices stay in the private Admin Review queue until a Super Admin verifies the official source and publishes them.

## First Super Admin account (required for Admin Control Center)

The current database has zero `super_admin` assignments. The Admin pages now check the signed-in account's own `user_roles` row through RLS and will deny access until the project owner grants the first Admin role.

- Open `supabase-first-super-admin-bootstrap.sql` in the repository.
- Replace only the email placeholder with the exact email of the owner's existing, confirmed Supabase Auth account.
- Run the SQL once in the Supabase SQL Editor as the project owner.
- Verify the result reports one Super Admin assignment. Do not grant this role to an unknown or third-party account.

This is deliberately a final owner-controlled privilege step; it is not automatically applied by deployment.

## Supabase Auth security setting
In Supabase Dashboard → Authentication → Settings / Security (wording may vary), enable leaked-password protection. The current Supabase security advisor reports this as disabled. This is a dashboard setting, not a GitHub code change.

## Real-account testing required
Current live database snapshot: 1 Auth user, 1 company, 1 company membership, 0 jobs. Before public launch, create/use separate confirmed accounts for:
1. Candidate / Job Seeker
2. Employer / HR
3. Super Admin (only grant this role through the secured Admin process)

Then test registration/login, company verification and job approval, application, Resume upload and employer-authorized view, invitation email and acceptance, interview accept/decline, notifications, and cross-company access denial. Do not use fake records in production just to make the site look populated.

## What must never be exposed
- Supabase service-role key / secret API key
- OpenAI API key
- Resend API key
- Government monitor secret
- User passwords, OTPs, recovery codes, or private candidate documents

## Current release status
The website is deployed and the latest CI/Health Audit are green. It is not yet launch-ready because provider secrets, Auth hardening, separate real-user accounts, and end-to-end tests are still outstanding. The 19 November 2026 target is conditional, not a guarantee.


## 17 November 2026 — latest verification

- Latest GitHub Pages deployment succeeded for commit `cd607324586ab899ecf154442dc123ed3fd44831` (run `44095184723`).
- Latest full Health Audit succeeded for commit `a7c1fa6ce16b6686a2d490923ad37498a8aa7388` (run `44094931772`), including browser smoke tests for post-login return paths.
- Live Supabase check confirms all 45 public tables have RLS enabled and all four Storage buckets are private. The seven listed Edge Functions are ACTIVE.
- Current live database still has one Auth user, one company, one company membership, zero jobs, and zero applications. It has no Super Admin assignment. Real multi-account workflows cannot yet be verified.
- The external provider secrets and first Super Admin bootstrap below remain owner-controlled final setup steps. The website must not be described as launch-ready until they are completed and real-account end-to-end tests pass.
