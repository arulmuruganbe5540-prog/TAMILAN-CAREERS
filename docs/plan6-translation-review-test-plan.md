# Plan 6 — Tamil Translation Review Test Plan

Status: planned; not yet executed.
Target: non-production Supabase staging project only.
Related implementation: `supabase/migrations/20261128120000_plan6_translation_review_guards.sql`.

## Safety and test setup

- Do not run destructive or permission-changing tests against the production project.
- First provision or identify a separate staging Supabase project and confirm its project reference.
- Apply the migration to staging only, after taking a staging backup.
- Use dedicated test identities: anonymous, authenticated non-admin, and Super Admin.
- Create disposable test jobs for (a) Tamil Nadu State Government, (b) another state's Government, (c) Central Government, (d) Tamil Nadu-located Indian Private, and (e) non-Tamil-Nadu Indian Private.
- Keep real user/job data and production credentials out of fixtures.
- Record SQL output, authenticated role/UID, expected result, actual result, and pass/fail for every case.

## A. Read and role access

1. Anonymous client can read only translations whose `translation_status` is `approved`; pending/draft rows are not returned.
2. Anonymous client cannot read the private audit table or invoke the audit-list RPC.
3. Authenticated non-admin can read approved public translations but cannot insert, update, or delete translation rows.
4. Authenticated non-admin cannot retrieve audit history through the RPC.
5. Super Admin can access the admin translation workspace and retrieve audit history for permitted filters.
6. Confirm the audit table itself remains inaccessible to anon/authenticated clients; access is through the guarded RPC only.

## B. Regional eligibility and source preservation

7. Super Admin can create a translation draft for a Tamil Nadu State Government job.
8. Super Admin can create a translation draft for a Tamil Nadu-located Indian Private job.
9. Attempts to create translations for Central Government, another state, or a non-Tamil-Nadu private job are rejected by the database guard.
10. Original English source fields remain unchanged when a translation is saved or reviewed.
11. `job_id` and `language_code` cannot be reassigned after creation.
12. Source snapshot changes are rejected except for the explicitly permitted official-source verification metadata.

## C. Review and approval workflow

13. Direct insertion with `translation_status='approved'` is rejected.
14. A draft missing Tamil title or Tamil description cannot be submitted for review or approved.
15. A draft can be submitted to `pending_review` only when the required Tamil content is present.
16. Approval is rejected unless the row is already `pending_review`.
17. Approval is rejected when the official source URL is missing or is not HTTPS.
18. Approval is rejected when review notes are missing.
19. Approval is rejected unless the reviewer explicitly confirms that the official source was opened.
20. Approval is rejected if review timestamp or reviewer identity is missing or does not match the authenticated Super Admin.
21. Successful approval records the reviewer identity and review timestamp.
22. Editing approved Tamil content while leaving it approved is rejected; the content must return through the permitted draft/review path first.
23. Verify the UI displays the correct validation feedback for each rejected workflow action.

## D. Delete and audit-history integrity

24. DELETE of a government translation row is rejected by the database trigger.
25. DELETE of a private translation row is rejected by the database trigger.
26. After rejected DELETE attempts, the translation row and its earlier audit entries still exist.
27. INSERT and UPDATE operations create corresponding audit records with the correct table name, translation/job identifiers, actor, old/new status, source snapshot, translated content, and timestamp.
28. An audit insert failure rolls back the associated translation write; no translation change may commit without its audit record.
29. Audit history cannot be changed through ordinary anon/authenticated client privileges.
30. Verify privileged database-owner/service-role access is treated as a trusted administrative boundary; append-only client protections do not make the audit table tamper-proof against privileged database operators.

## E. Audit RPC validation

31. RPC rejects unauthenticated callers and authenticated non-admin callers.
32. RPC rejects unsupported table names.
33. RPC respects the requested table/job filter and does not leak unrelated records.
34. RPC applies the documented limit bounds (minimum 1, maximum 500).
35. Returned audit rows are read-only in the admin UI; displayed values are safely escaped and cannot inject HTML/script.

## F. Regression and end-to-end checks

36. Tamil Nadu State Government listing/detail pages show approved Tamil content and Tamil UI labels.
37. Other-state and Central Government pages remain English.
38. Tamil Nadu private listing/detail/application pages show approved Tamil content and Tamil UI labels.
39. Non-Tamil-Nadu Indian Private and International pages remain English.
40. Unapproved Tamil content shows the review-pending fallback and never silently publishes raw/unreviewed translation text.
41. Government official Apply URLs and verified private employer/ATS Apply URLs remain unchanged; discovery URLs are not substituted.
42. Test desktop and Android mobile layouts, pagination, filters, breadcrumbs, date/salary formatting, empty states, and console/network errors.

## Execution record

No tests in this document have been executed yet. Fill in the staging project reference, migration run identifier, test date, tester, evidence links, and pass/fail results only after a separate staging environment is confirmed. Production migration, PR merge, and deployment require separate explicit approval.
