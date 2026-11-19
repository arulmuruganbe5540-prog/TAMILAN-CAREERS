# TAMILAN CAREERS — 19 நவம்பர் 2026 தொடர்ச்சி ஆய்வு

## சரிபார்த்த முடிவுகள்

### GitHub Actions / Website
- Health Audit run: https://github.com/arulmuruganbe5540-prog/TAMILAN-CAREERS/actions/runs/44460389393 — வெற்றி.
- இந்த run-இல் Deno Edge Function type checks, SQL migration lint, Admin MFA guard, external candidate review guard, TAMILAN AI safety guard, website structure check, browser smoke tests ஆகியவை வெற்றிகரமாக முடிந்தன.
- GitHub Pages deployment run: https://github.com/arulmuruganbe5540-prog/TAMILAN-CAREERS/actions/runs/44460786210 — commit 3d95e7df5916954f51674700acaa16e7a8c3678d-க்கு வெற்றி.
- Health Audit run 78b9865aca2eaf28ef45a9daa7c1ed298f8ea72c commit-இல் நடந்தது. அதற்குப் பிறகு வந்த 3d95... commit ஆவண/நிலைப் புதுப்பிப்பு; அதற்கான Pages deployment வெற்றியடைந்தது. இதை புதிய Health Audit run எனக் கூறவில்லை.

### Supabase live read-only checks
Project: qkmljuuusfjowexvybvy
- public.jobs: மொத்தம் 0 rows.
- Published jobs: 0.
- AI-க்கு public-ஆக வழங்கத் தகுதியான published jobs: 0.
- ஆகவே இப்போது AI வேலை பரிந்துரை/வேலை எண்ணிக்கை காட்டக்கூடாது. உண்மையான published data வரும்வரை தரவு இல்லை என்று தெளிவாகச் சொல்ல வேண்டும்.
- job_sources மற்றும் company_invitations அட்டவணைகளில் RLS உள்ளது; policies இல்லை. இவை default-deny ஆகவே உள்ளன. இதை மாற்றவில்லை.

### SECURITY DEFINER RPC — முதற்கட்ட முழுப் பட்டியல் சரிபார்ப்பு
Supabase Security Advisor காட்டிய 15 authenticated-callable SECURITY DEFINER functions-ஐ live catalog-ல் மீண்டும் கணக்கிட்டோம்.
- 15/15 functions-க்கும் empty search_path அமைப்பு உள்ளது.
- 15/15 function bodies-ல் auth.uid() அல்லது Super Admin authorization check உள்ளது.
- 4 Admin-sensitive functions-ல் MFA enforcement உள்ளது (helper அல்லது conditional AAL2 logic).
- இவை application workflow RPCs என்பதால் grants-ஐ blanket revoke செய்யவில்லை; அது உண்மையான வேலைப்பாடுகளை உடைக்கக்கூடும்.
- இது source/catalog-level first-pass review மட்டுமே; ஒவ்வொரு RPC-க்கும் தனித்தனியான authenticated browser integration test இன்னும் தேவை.

### இன்னும் சரிசெய்ய வேண்டிய Security Advisor குறிப்புகள்
1. 15 authenticated-callable SECURITY DEFINER RPC warnings — authorization checks இருப்பினும், function-by-function browser tests மற்றும் future hardening தேவை. https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable
2. company_invitations, job_sources RLS enabled but no policy — தற்போது Data API grants/policies default-deny என உறுதி செய்துள்ளோம்; broad policy சேர்க்க வேண்டாம். https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy
3. Supabase Auth Leaked Password Protection இன்னும் disabled — Dashboard-இல் owner செய்ய வேண்டிய அமைப்பு. https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

## மாற்றங்கள் / பாதுகாப்பு வரம்பு
- இந்த ஆய்வில் database schema, data, policies, grants, functions, secrets அல்லது Edge Function deployment எதையும் மாற்றவில்லை.
- TAMILAN AI feature இன்னும் OFF; model endpoint/token அமைக்கப்படவில்லை.
- பழைய AI Edge Functions HTTP 410 disabled நிலையில் தொடர்கின்றன.
- AI integration-க்கு model token அல்லது service-role key browser-ல் சேர்க்கப்படாது.
- Model benchmark notebook இன்னும் run செய்யப்படவில்லை; free Colab GPU கிடைப்பது உறுதி இல்லை.

## அடுத்த கட்டப் பணிகள்
1. 15 RPC-களுக்கான individual browser-level test matrix உருவாக்கி, user/owner/admin role boundary-களை சோதிக்க வேண்டும்.
2. Existing published job schema-வுடன் பொருந்தும் read-only AI retrieval contract + tests எழுத வேண்டும்; jobs அட்டவணையில் data 0 என்பதால் இப்போது live recommendation வழங்கக் கூடாது.
3. Retrieval-இல் public RLS-ஐ மீறாத anon/publishable access மட்டும் பயன்படுத்த வேண்டும்; private candidate/company records மற்றும் job_sources சேர்க்கக்கூடாது.
4. Model benchmark-ஐ free GPU கிடைக்கும் போது மட்டுமே நடத்த வேண்டும்; எந்த paid inference-மும் owner அனுமதி இல்லாமல் இல்லை.
5. Owner Supabase Auth settings-இல் Leaked Password Protection-ஐ enable செய்ய வேண்டும்; Admin MFA-வின் உண்மையான browser test-ஐயும் owner account மூலம் முடிக்க வேண்டும்.

நிலை: Website build/deployment verified. Health Audit verified on the stated code commit. Live jobs = 0. AI is not deployed or enabled. Owner-dependent security settings and real-account tests remain pending.
## 19-11-2026 — Read-only job context implementation and CI verification

- Added `supabase/functions/tamilan-ai-job-context/index.ts` to GitHub. It is a source-only, JWT-protected, feature-flagged OFF endpoint; it has not been deployed to Supabase.
- Added `verify_jwt = true` for this function in `supabase/config.toml`.
- Uses only `SUPABASE_ANON_KEY` plus the caller's Bearer JWT so existing `public.jobs` RLS applies. No service-role key, model key, candidate/application data or `job_sources` access.
- Only `status='published'` rows, max 5, public job fields, max 2 KB request body, bounded query fields. Citation uses the official notification URL, official website URL, or the internal job details URL; employer application URLs are not treated as evidence citations.
- Job descriptions are marked untrusted; response carries actual job source IDs and citation URLs. No model inference or generated job facts are performed by this function.
- Added `scripts/tamilan-ai-retrieval-guard.py`, Deno type-check, and a dedicated GitHub Actions guard step.
- Final Health Audit run for commit `8c85b75fa13a6293e4352b3d4dd00961d840eee8` passed: https://github.com/arulmuruganbe5540-prog/TAMILAN-CAREERS/actions/runs/44469643202. Deno type-check, retrieval safety guard, all existing guards, website structure and browser smoke tests passed.
- GitHub Pages deployment for the same commit passed: https://github.com/arulmuruganbe5540-prog/TAMILAN-CAREERS/actions/runs/44469644291.
- Live Supabase function inventory confirms `tamilan-ai-job-context` is NOT deployed. No Supabase function deployment, secrets, database schema/data/policy changes were made.
- Remaining before any enablement: implement rate limiting and usage controls, runtime authenticated integration tests, validate deployed JWT/RLS behavior, add model adapter and human-reviewed pilot. Feature must remain OFF. Live job table still has 0 records.

