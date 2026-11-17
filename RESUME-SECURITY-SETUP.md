# TAMILAN CAREERS — Resume security and application attachment

## What the workflow does

- Job Seekers upload PDF, DOC, or DOCX files to the private Supabase Storage bucket `candidate-resumes`.
- The bucket is private. Each candidate can access only the folder named with their own Supabase Auth user ID.
- The metadata table `public.candidate_resumes` is protected by owner-only RLS. A database trigger enforces a maximum of five metadata records per candidate, including concurrent submissions.
- `job_applications.resume_id` links the optional selected Resume. A database trigger rejects forged IDs unless the Resume belongs to the applicant.
- A candidate may optionally attach one of their own uploaded Resume records when applying for a published job.
- Employers do not receive direct table or Storage access to candidate resumes.
- An authorized company owner, or active `owner`, `hr_manager`, or `recruiter` member, can request a 60-second signed URL only for the Resume attached to an application for a job belonging to that company.
- Withdrawn or otherwise inactive applications do not provide Resume access.

## Supabase setup

Run `supabase-setup-pending.sql` in the Supabase SQL Editor for project `qkmljuuusfjowexvybvy`. It includes the private bucket, Storage policies, candidate resume metadata table, RLS, and the five-document database limit. It also includes other pending profile and employer setup items, so review the full SQL file before running it.

The focused, rerunnable Resume-only SQL is `supabase-resume-storage.sql`.

## Edge Function deployment

Deploy the function directory:

```bash
supabase functions deploy company-resume-access
```

The function expects the standard Supabase Edge Function environment values `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY`. Never put the service-role key in website JavaScript or GitHub Pages.

## End-to-end test

1. Sign in as a Job Seeker and upload a PDF or DOCX on `resume-documents.html`.
2. Open a published job and apply, selecting the uploaded Resume.
3. Sign in as that job's company owner or an active HR Manager / Recruiter.
4. Open `company-applicants.html` and choose **பாதுகாப்பாக Resume பார்க்கவும்**.
5. Confirm that the document opens and that the signed URL expires after about 60 seconds.
6. Confirm that a different company account, an inactive member, and a non-applicant cannot obtain a link.

## Important limitation

A successful GitHub Pages deployment does not run the SQL in Supabase or deploy the Edge Function. The live upload and employer-view workflow remains inactive until those Supabase steps are completed and an authenticated end-to-end test passes.
