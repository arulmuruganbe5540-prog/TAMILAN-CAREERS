# TAMILAN CAREERS — Company Profile and Job Draft Setup

## What this stage adds

- Company profile information is saved as a private Supabase database draft instead of relying only on browser/account metadata.
- Existing older profile draft metadata is read as a one-time fallback and can be saved into the new table.
- Job-posting drafts are stored separately for each company and authorized user.
- Only active company members with role `owner`, `hr_manager`, or `recruiter` can manage job-posting drafts.
- Job drafts remain private and are not public job listings. No application can be submitted against a draft.

## Supabase setup

1. Open the TAMILAN CAREERS Supabase SQL Editor.
2. Open `supabase-company-workflow.sql` in this repository.
3. Copy the complete SQL and run it.
4. Verify that `company_profile_drafts` and `job_posting_drafts` appear in Table Editor.
5. Test with an authorized company account: save and reload a company profile draft, then save and reload a job-posting draft.
6. Sign in as a non-company or unauthorized member and verify the job-posting page blocks access.

The migration is safe to rerun. Profile drafts are private to the account that created them. Job-posting draft RLS additionally checks the active company membership and allowed role.

## Important boundary

This stage does not verify a company, approve a company, publish a job, or create a public vacancy. Company verification and public job publishing need separate Admin approval and server-side publishing workflows. GitHub Pages deployment alone does not create the Supabase tables; the SQL must be run separately.
