# MANGAIYARKARASI — TAMILAN CAREERS Autonomous Master Control
Version: 1.0 proposal | Date: 2026-11-26
Status: Architecture and isolated preview branch; NOT deployed to production.

## Owner and operating principles
- One human authority: the existing TAMILAN CAREERS Super Admin / Master Owner.
- Mangaiyarkarasi is a controlled automation orchestrator, not a second human owner and never a privileged identity.
- English-only visible website and admin interface.
- Preserve all current public pages, auth flows, job tables, applications, company verification, SEO and admin modules.
- Never claim a connection, scan, backup, test, ranking, or deployment succeeded unless a real run produced verifiable evidence.
- Public job content is separate by domain: Government, Indian Private, International. Never cross-post or mix their records.
- No autonomous privilege escalation, owner change, security-policy rewrite, MFA/RLS disablement, secret disclosure, or arbitrary production code modification.

## Complete capability catalogue

### A. Master command and orchestration
- Central command centre with Tamil voice input, text fallback, command history and clear confirmation prompts.
- Intent router for site questions, job discovery, source review, analytics, SEO, monitoring, reports and safe actions.
- Module registry for every current and future feature: owner, environment, permissions, health check, data classification, dependencies, runbook and approval tier.
- Role separation: Master Owner, bounded automation service, human reviewer, company/employer, candidate and public visitor.
- Automation can recommend and prepare; only the Owner can authorize protected production actions.

### B. Jobs intelligence
- Government source discovery, official-source verification, robots/terms respect, PDF/notice extraction, freshness and closing-date checks.
- Duplicate detection across existing records and candidates before any proposed post.
- Qualification, state/district, vacancy, application link, source, deadline and eligibility validation.
- Private and International candidate discovery kept in separate queues and tables.
- Company verification and active membership required before company job publication.
- Candidate lifecycle: discovered → extracted → verified → duplicate checked → reviewed → Owner approved → published.
- Uncertain, unverifiable, expired or duplicate jobs are held or rejected, never auto-published.
- Existing JUST NOW (first 5 hours) and expiry indicators remain supported.

### C. Google Search Intelligence / automatic SEO
- Connect Search Console API for actual query/page/country/device/date performance: clicks, impressions, CTR and average position.
- Import data on a scheduled basis; retain source, date range and import timestamp.
- Combine Search Console queries with relevant job fields, location, qualification and a properly licensed keyword/trend provider where configured.
- Score keyword relevance, observed demand, current impressions, CTR opportunity, page intent and competition evidence.
- Generate job-specific SEO title, meta description, headings, useful FAQs and internal-link suggestions.
- Never keyword-stuff, invent salary/eligibility/deadlines, alter official job facts, create doorway pages or claim guaranteed rank/first position.
- SEO suggestions are versioned. Auto-apply only low-risk metadata/content improvements within approved templates; material content changes require Owner review.
- Maintain canonical URLs, sitemap generation, valid JobPosting structured data, robots rules and index/noindex policy.
- Use Google Indexing API only for eligible JobPosting URLs and within Google's current policy/quota; use sitemap discovery for ordinary pages. Log every notification and response.
- Monitor indexed status and search performance; ranking changes are reported, not promised.

### D. 24/7 operations and monitoring
- Uptime/HTTPS/DNS/certificate checks; page availability and broken internal/external links.
- Browser smoke tests for navigation, forms, login, registration, job detail, apply flow and mobile layouts.
- Supabase health, database connectivity, RLS/advisor findings, Edge Function health/errors, Cron schedules/runs, storage and usage limits.
- GitHub workflow/deployment status and release health.
- Job source scanner success/failure, candidate backlog, stale sources and approval queue.
- Alert severity: info, warning, critical. Notify Owner through configured channel; never silently suppress critical failures.
- Respect privacy: aggregate analytics only; do not covertly fingerprint or identify visitors.

### E. Visitor and growth intelligence
- GA4 and Search Console integration with 30-day, daily, country, device, landing-page and referrer reports.
- Exclude Owner/internal traffic using a verified internal-traffic rule.
- Popular jobs, qualification interests, search landing pages, engagement and exit trends.
- No collection of unnecessary personal data; consent and retention rules apply.

### F. Safe updates and release management
- Development branch → isolated staging → automated tests → Owner preview → explicit production approval → deployment → post-deploy smoke tests.
- Change states: Proposed → Allowed for development → Testing → Ready for deployment → Owner approved → Deployed; or Rejected / Rolled back.
- "Allowed" means permission to build/test only, not permission to publish live.
- Automated rollback only when a known health gate fails and the rollback target is verified.
- Database migrations must be additive/backward-compatible first; destructive migrations require explicit Owner approval and verified backup/restore plan.
- Feature flags, versioned config, release notes and immutable deployment audit.
- Never deploy a failing or untested change.

### G. Security, identity and governance
- Owner-only Super Admin authorization checked server-side; MFA policy respected.
- Least-privilege service credentials, secrets only in server-side secret storage, rotation and access logs.
- RLS on exposed tables, scoped policies, private schemas for internal control data.
- No service-role key, Google private key or provider token in HTML, JavaScript, GitHub Pages or logs.
- Automation cannot modify its own permissions, role map, approval policy, owner identity or secret vault.
- Append-only audit events with actor, action, target, before/after summary, timestamp, request/run ID and result.
- Rate limits, idempotency keys, retry/backoff, dead-letter queue and alerting.

### H. Resilience, backup and recovery
- Scheduled database backups according to available Supabase plan/retention and separate exports for critical configuration.
- Backup inventory, age/size/status and retention visibility.
- Scheduled restore drills into isolated staging; a backup is not considered verified until restore succeeds.
- Documented recovery objectives (RPO/RTO), incident playbooks and owner alerts.
- Storage and external asset backup strategy; restore steps tested.

### I. Performance, accessibility and cost
- Core Web Vitals, page weight, image optimization, cache and database query review.
- Android/iOS/tablet/desktop responsive and accessibility checks.
- Supabase/GitHub/monitoring/provider usage and cost thresholds with alerts.
- No automatic plan upgrades or paid spending without Owner approval.

### J. Future Evolution cycle
- Every 20 days: full technical, security, SEO, accessibility, performance, job pipeline and feature audit.
- Review relevant technology/platform changes and competitor/public search trends.
- Generate proposed changes with reason, expected impact, risk, dependencies, test plan, cost and rollback.
- Show current vs proposed preview; Owner chooses Approve for development, Reject, or Keep existing.
- Never automatically replace the live design.

## Existing infrastructure discovered (read-only inspection, 2026-11-26)
- GitHub repository: arulmuruganbe5540-prog/TAMILAN-CAREERS; default branch main; public repository.
- Supabase project ref: qkmljuuusfjowexvybvy; region ap-south-1; PostgreSQL 17; project status ACTIVE_HEALTHY.
- Existing admin pages include super-admin.html, super-admin-security.html, super-admin-system-health.html, super-admin-seo-intelligence.html, source monitor, review centre, usage insights, reports, activity logs and other module pages.
- Existing database includes separate government_jobs, private_jobs and international_jobs; external_job_sources/candidates; government_notice_sources/reviews; seo_job_profiles, seo_keyword_metrics, seo_engine_runs; page_analytics; super_admin_activity_logs; site_settings.
- Existing Edge Functions include scan-government-notice-sources, scan-external-job-sources, analyze-external-job-candidates, google-indexing-notify and other job/auth workflows.
- Existing Cron jobs observed: interview reminders (15m), expiry processing (daily), government source scanning, company source scanning, external candidate analysis. These are not proof of complete 24/7 website monitoring.
- Existing SEO page reports Search Console, Trends and search-volume provider are not connected. The existing SEO engine currently generates phrases from job fields.
- Existing google-indexing-notify function checks Super Admin authorization/MFA and job eligibility; it requires GOOGLE_INDEXING_SERVICE_ACCOUNT_JSON secret. Its presence does not prove Google notifications are configured or accepted.
- Supabase security advisor currently reports existing findings, including callable SECURITY DEFINER functions and other notices. These require review; do not mass-change policies without understanding each workflow.
- Supabase performance advisor reports multiple permissive RLS policies and unused indexes; review in context before altering.

## Implementation phases
1. Foundation (this branch): architecture, control-centre preview, inventory and explicit production-safety gates.
2. Control registry + approval/audit schema in an isolated Supabase development branch; verify RLS and Owner-only access.
3. Health/monitoring Edge Functions and scheduled jobs with alerting and run history.
4. Search Console API ingestion and SEO scoring; connect credentials only through Supabase secrets; verify real query imports.
5. Job pipeline integration, duplicate checks, candidate review and approved SEO metadata workflow.
6. Staging CI, browser tests, rollback and release gates.
7. 20-day audit/evolution cycle, reporting and command interface (voice + text).
8. Production rollout only after Owner review, backup/restore drill, end-to-end tests and explicit approval.

## Definition of done
- Every module has an owner, health check, permission boundary, audit trail and failure alert.
- Every automatic action is idempotent, logged, rate-limited and recoverable.
- Every production change has a tested artifact, approved release and rollback path.
- Search Console imports show source timestamps and real data; no fabricated search volume or rank.
- Government/private/international job flows remain separate and existing user flows pass regression tests.
- Owner can pause automation globally or per module.
- No secrets or privileged keys are exposed in public code.
- A successful preview, test or branch commit is never described as a live production deployment.
