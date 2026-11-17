# International and company job monitor setup

This module extends TAMILAN CAREERS with an official-source directory for Indian government, foreign government, Indian company, and foreign company careers pages.

## Safety model
- Discovery is not verification. Every discovered link remains private in `external_job_candidates`.
- The monitor does not create or publish rows in the public `jobs` table.
- Admin must open the official source, inspect the original notice, confirm dates, eligibility, vacancy and apply URL, and only then use the existing controlled publishing workflow.
- Company logos are not copied. A company listing must link to its official careers page and must not imply partnership.
- Some portals require JavaScript, login, API access, or block automated access. Those are marked manual; do not bypass access controls or robots restrictions.

## One-time setup
1. Run `supabase-external-job-sources.sql` in Supabase SQL Editor.
2. Deploy Edge Function `scan-external-job-sources`.
3. Set `GOVERNMENT_MONITOR_SECRET` as an Edge Function secret (use a long random value).
4. Add the exact same secret as a GitHub Actions repository secret named `GOVERNMENT_MONITOR_SECRET`. Never paste it into chat or commit it.
5. Run the workflow manually once and inspect the Admin candidate queue.

## Initial official-source directory
The SQL seeds India government portals, selected foreign government job portals, and official career pages of selected Indian and multinational companies. This is a starter registry, not a claim that every listed site has live vacancies or allows automated crawling.

## Publishing rule
No candidate is auto-published. This is deliberate: automated page scraping can mistake general news, expired advertisements, or unrelated links for active vacancies. Public job posts must carry the source URL and a last-verified date. Check each source's terms, robots policy, and available official API/feed before enabling automated page scanning.
