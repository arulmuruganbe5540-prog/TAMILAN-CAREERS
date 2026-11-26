# Autonomous Operations — Monitoring Stage

## What this stage does
- Runs public endpoint checks every 30 minutes using GitHub Actions.
- Checks the homepage, Government Jobs, Private Jobs, International Jobs, sitemap and robots.txt over HTTPS.
- Stores a Markdown/JSON report in each workflow run.
- Opens or updates one GitHub issue when a check fails and closes it after a later healthy run.
- Checks daily whether 20 days have elapsed since the previous audit task; if due, it creates a review issue with an evidence-based checklist.

## What this stage does not prove or automate
- It is not a second-by-second monitoring service. GitHub scheduled workflows can be delayed.
- It does not test login, registration, form submission, database writes, RLS, external links, Google Search Console, Google rankings or backup restoration.
- The 20-day workflow schedules a human/Owner review task; it does not independently inspect all platform data or deploy improvements.
- It does not write to Supabase or change the live website.

## Verification
Run:
`node --test tests/monitor/site-health-check.test.mjs`

A green test confirms only the monitor's local logic. The first scheduled/manual GitHub Actions run is needed to verify the real website from the runner.

## Next safe integration stages
1. Connect monitoring results to the existing Mangaiyarkarasi control API only after its schema and Edge Function are installed and runtime-tested.
2. Add authenticated Supabase health/run history and alert delivery without exposing service credentials.
3. Generate evidence-backed change proposals in the control centre; keep all production deployment actions behind explicit Owner approval.
4. Add isolated browser/form/database tests and restore drills before considering production rollout.
