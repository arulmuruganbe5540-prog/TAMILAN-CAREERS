# TAMILAN CAREERS

தமிழ்நாடு மற்றும் இந்தியா முழுவதும் வேலை தேடுவோரையும் வேலைவாய்ப்பு வழங்கும் நிறுவனங்களையும் இணைக்கும் தமிழ்-முன்னுரிமை வேலைவாய்ப்பு தளம்.

## Live website
- Homepage: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/
- Job search: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/jobs.html
- Saved jobs: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/saved-jobs.html
- Job seeker profile: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/job-seeker-profile.html
- Resume & documents: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/resume-documents.html
- Indian Government Jobs: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/indian-government-jobs.html
- Tamil Nadu Government Jobs: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/tamil-nadu-government-jobs.html

## Main features currently in the repository
- Tamil / English responsive public homepage and job search.
- Supabase email registration, login, password reset flow and account dashboard.
- Job seeker profile editor.
- Saved jobs page with browser-local save/remove controls (not account-synced).
- Government job information portals for India and Tamil Nadu.
- Terms, privacy, about and Tamil help pages.
- Resume and document management frontend (private Storage setup required).

## Supabase setup required for private resume storage
1. Open the Supabase project SQL Editor.
2. Open `supabase-resume-storage.sql` in this repository.
3. Review the SQL and run it in the SQL Editor while signed in as the project owner.
4. Confirm that a private Storage bucket named `resumes` exists and that the four `TC resumes owner ...` policies are present.
5. Test upload, list, signed download and delete using a Job Seeker test account.

The SQL creates a non-public bucket with a 5 MB file limit and PDF/DOC/DOCX MIME restrictions. Storage object policies restrict access to the authenticated user's own first-level folder. Do not make this bucket public and do not expose service-role keys in browser code.

## Important implementation status
- Job search reads the Supabase `jobs` table; real listing visibility depends on the table schema, RLS and published job records.
- Job application submission and employer job posting must not be considered live until their database schema, RLS policies and end-to-end flows are implemented and tested.
- Government job pages provide information and official links; verify every vacancy and deadline at the relevant official source.
- Never pay an individual or share OTPs, passwords, bank PINs or account credentials to obtain a job.

## Technology
- Static responsive HTML/CSS/JavaScript frontend
- Supabase Auth, Database and Storage
- GitHub Pages hosting
