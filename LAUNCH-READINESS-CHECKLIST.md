# TAMILAN CAREERS — Launch Readiness Checklist

Last reviewed: 17 November 2026

This is an operational checklist based on the project changes and user-confirmed setup steps available at the time of writing. A feature is not considered live merely because its code or SQL file exists.

## Confirmed complete

- [x] GitHub Pages site exists and the latest confirmed deployment for commit `f7ae09a31e70de51b3779ec22e4bc8e03db448fa` succeeded.
- [x] Website health workflow passed for that same commit, including Deno type checks, structural checks, and browser smoke tests.
- [x] Company workflow SQL was reported successful by the user.
- [x] Candidate application withdrawal SQL was reported successful by the user.
- [x] External job-source registry SQL was reported successful by the user.
- [x] Supabase Edge Function `scan-external-job-sources` was reported deployed successfully by the user.
- [x] External-source discovery remains review-only; scanner code does not publish to the public jobs table.
- [x] A browser smoke test now checks that the external-source review page redirects unauthenticated visitors to login.
- [x] Scanner response parsing is capped at 1.2 MB while streaming, instead of reading an unbounded response before slicing.
- [x] AI resume matcher Bearer header parsing was corrected in the repository source.

## Must finish before enabling external source scanning

- [ ] Create a unique random `GOVERNMENT_MONITOR_SECRET` of at least 32 characters. Do not paste it into chat or commit it.
- [ ] Add the exact same secret in Supabase Edge Function Secrets and GitHub repository Actions Secrets.
- [ ] Check the scanner Edge Function's **Verify JWT with legacy secret** setting. Because the function uses its own `x-monitor-secret` header, the gateway must not block the request by requiring a Supabase JWT; turn legacy JWT verification off if it is on.
- [ ] Run the GitHub workflow manually and inspect the private candidate queue.
- [ ] Verify the Admin review page with a Super Admin account.
- [ ] Confirm that only reviewed, verified notices can enter the public jobs/notice feed.

## Supabase setup and deployment still needing confirmation

- [ ] Run `supabase-setup-pending.sql` for private resume storage, candidate resume metadata, private employer job drafts, and restricted applicant-profile access. Verify the Storage bucket remains private.
- [ ] Deploy `company-resume-access` Edge Function and test a legitimate employer access plus a denied cross-company access. Secure resume viewing is not live until this is tested.
- [ ] Run `supabase-interview-notifications.sql`; test invitation, candidate response, and notifications for both parties. Automated reminders additionally need a secure scheduler/Cron.
- [ ] Run `supabase-candidate-profile-education-experience.sql`; test saving and editing education and experience.
- [ ] Run `supabase-company-application-status.sql`; test permitted and denied employer status updates.
- [ ] For Government Jobs archive, run `supabase-government-archive-install.sql`, deploy `ingest-government-notices`, configure its protected monitor secret, and test the private review queue. Do not auto-publish scraped links.
- [ ] For AI resume matching, deploy `ai-resume-match`, add `OPENAI_API_KEY` as a Supabase Function Secret, and test with explicit candidate consent. Rule-based matching and AI matching must be described separately.
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
