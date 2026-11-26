# Website regression checks

Run from the repository root with Node.js 22 or newer:

```sh
node --test tests/regression/site-regression.test.mjs
```

The test suite uses only Node.js built-ins; it adds no package dependencies and makes no network or database calls.

## Covered checks

- Required public, student, employer, application, company portal and Master Control files exist, declare English UI language and mobile viewport.
- Student and employer login/registration forms remain distinct.
- Private and international listing pages retain separate market modes, database table routing and 10-row page size.
- Private and international applications use their own job and application tables.
- Company verification gates remain independent for Indian private and international posting.
- The Mangaiyarkarasi preview remains read-only, owner-session gated and free of service-role credentials.
- The public homepage does not link to private control internals.
- Static local links in core workflows resolve to files in the repository.

## Important limitation

These are static source regression checks. They do not sign in, submit forms, query Supabase, verify RLS, upload resumes, test email delivery, or run an Android/desktop browser. Those require an isolated test database and browser-level test environment. A passing workflow must not be described as proof that live authentication or posting works.


## Latest workflow result — 2026-11-26
- The static regression suite passed in GitHub Actions: 8 test groups, 0 failures.
- The suite remains source-level only. It does not prove runtime authentication, Supabase RLS, posting, application upload, email delivery, or browser behavior.


## CI coverage status — 2026-11-26
- Website static regression suite: passed (8 test groups).
- Mangaiyarkarasi Deno checks: format, lint and type-check passed.
- Database CI now applies the migration and runs the SQL smoke plus transactional rollback tests against an ephemeral PostgreSQL 16 service. This is not a live Supabase project test.


## Browser smoke coverage — 2026-11-26
- Playwright/Chromium CI opens 10 pages with a mobile-sized viewport.
- Checks Student and Employer sign-in/register tab behavior, password mismatch validation, show/hide password controls, unauthenticated Company Portal and application guards, and market-specific page labels.
- Supabase is mocked and external requests are blocked. This is a front-end smoke test, not a live backend or end-to-end authentication test.
- Result: passed on commit `630ba4f34f7f3e2bb47af64516bb643a903d25fe`.
