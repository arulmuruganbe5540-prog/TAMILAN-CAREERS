# TAMILAN CAREERS — Government jobs feed and safe automation

## Public listing behaviour

- Existing Indian, Tamil Nadu and other-state government job pages now read published recruitment notices from `public.government_notices`.
- The feed defaults to the last 12 months and lets visitors switch to the last 6 months.
- The public feed loads up to 500 records from Supabase and displays every matching record within the selected 6- or 12-month window (subject to the database query cap).
- Application status is calculated from the official application end date. Expired notices remain clearly marked as expired; they are not presented as open applications.
- Each card links to the original official notice. An application link is shown only when it is explicitly stored in the record's `details.application_url` or `details.apply_url`.
- The public browser does not create, approve, or publish records. It can only read rows allowed by Supabase RLS.

## Scheduled discovery and review intake

The GitHub Actions monitor runs every six hours. It scans registered official sources, then calls the Supabase Edge Function `ingest-government-notices` when the monitor secret is configured. The Edge Function only queues recruitment candidates, with a hard limit of 15 new review candidates per run. It does not publish unverified data.

## Historical archive sources

The registered official-source list includes direct archive/result pages for UPSC examination notifications, UPSC recruitment advertisements and recruitment-test results, SSC archives, TNPSC exam dashboard, and Tamil Nadu MRB results. The discovery function captures the surrounding official table/list context and a possible date hint where available. The date is not treated as verified: Admin must confirm it against the original official page/PDF before publishing.

## Admin review and publishing

- Open `government-notice-review.html` to review discovered candidates.
- Use the per-record review link to open `government-notice-publish.html`.
- Enter the original notice date and verified facts, then complete the category-specific checklist.
- The secure RPC checks super-admin status, registered-source host, required verification flags, and duplicate/pending state before publishing.
- Unverified items remain private in the review queue; rejected items are not public.

Run the single consolidated migration `supabase-government-archive-install.sql` in Supabase SQL Editor. It installs the government source registry, review/published tables, expanded archive sources, and secure Admin publish/reject RPCs. It is safe to re-run and does not auto-publish discovered notices.

## One-time secret configuration

The same long random value must be saved in two places. Never paste it into chat, source files, or a public issue.

1. In Supabase Dashboard, open Project Settings → Edge Functions → Secrets and add `GOVERNMENT_MONITOR_SECRET`.
2. In GitHub, open this repository → Settings → Secrets and variables → Actions → New repository secret. Name it `GOVERNMENT_MONITOR_SECRET` and enter the same value.
3. Confirm that the `ingest-government-notices` Edge Function is deployed. Its server environment must include `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`.
4. Run the GitHub workflow **Frequent official government recruitment monitor** once using Actions → Run workflow.
5. Deploy the updated `supabase/functions/ingest-government-notices/index.ts` Edge Function after applying the government-notice SQL migrations.

If the GitHub secret is absent, the Supabase sync step is intentionally skipped. If the Edge Function is not deployed or the secret does not match, the sync will fail visibly in the Actions log.

## Publication safety rule

A discovered link is not a complete job post. Before a notice can appear publicly, its original official document must be opened and checked for the post title, vacancy count, education/experience, age limit, pay, application dates, fee/selection details, and the official application URL. Duplicates and amendments must be reconciled. If any important field cannot be verified, keep the notice in Admin Review.

**Current limitation:** the discovery Edge Function is not yet an automatic fact verifier or public publisher. The public feed will show only records that have already been published into `government_notices`. Do not bulk-publish link-only candidates to fill the 15 slots. The next implementation stage is official PDF extraction, amendment/duplicate handling, expiry/archive handling, and a trusted server-side publisher for fully verified records.


## AI-assisted full-detail extraction (implemented)

The government monitor now has a second server-side stage: `extract-government-notice-details`.

- After the discovery sync, GitHub Actions calls the extraction Edge Function.
- It reads a direct official PDF using the OpenAI Responses API PDF file input, or extracts readable text from the registered official HTML page and linked same-domain PDFs.
- It prepares structured fields for post-wise vacancy counts, qualifications, age limits, experience, salary, selection process, application fee, dates, documents, official website and application URL.
- Extracted fields are saved to the private Admin Review record and shown with AI status, summary and confidence.
- The public job-detail page renders the structured post-wise fields after an Admin explicitly verifies and publishes the notice.
- AI output is only a draft. It is never treated as verified, never auto-published, and missing or ambiguous facts remain blank.

### Additional one-time secret

Add `OPENAI_API_KEY` in Supabase Dashboard → Project Settings → Edge Functions → Secrets. Do not put this key in GitHub source code or the browser. The extractor uses `gpt-4o-mini` through the Responses API.

The existing `GOVERNMENT_MONITOR_SECRET` must also be configured with the same value in Supabase Edge Function Secrets and GitHub Actions Secrets. Without it, scheduled scanning and the extraction call will be skipped or rejected. If the OpenAI key is missing, the extraction step reports an error and the review candidates remain safely pending.

### Current operating boundary

AI can extract from readable official PDFs/pages, but it cannot guarantee every portal exposes a downloadable PDF or allows automated access. Admin must compare the extracted draft against the original official notice, especially post-wise vacancies, eligibility, age cut-off, pay, fee, dates and application links. Only the existing Super Admin publish action makes a record public.
