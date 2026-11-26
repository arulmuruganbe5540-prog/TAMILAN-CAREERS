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
