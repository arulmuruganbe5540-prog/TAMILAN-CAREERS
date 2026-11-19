# TAMILAN CAREERS — Supabase AI Data Access & Security Audit (Tamil)

**ஆய்வு தேதி:** 19-11-2026  
**Project:** `qkmljuuusfjowexvybvy` (TamilanCareers)  
**நிலை:** Read-only ஆய்வு முடிந்தது. எந்த database schema, RLS policy, function அல்லது live AI endpoint-யும் மாற்றப்படவில்லை.

## 1. AI-க்கு தேவையான வேலைவாய்ப்பு தரவு

`public.jobs` அட்டவணை ஆய்வு:
- RLS இயக்கப்பட்டுள்ளது.
- `jobs_read_published` SELECT policy `anon` மற்றும் `authenticated` இரண்டிற்கும் உள்ளது.
- Policy `status = 'published'` என்பதை கட்டாயப்படுத்துகிறது.
- Admin-managed jobs-க்கு `company_id IS NULL AND is_admin_managed = true` தேவை.
- Company jobs-க்கு தொடர்புடைய `companies.verification_status = 'verified'` ஆக இருக்க வேண்டும்.
- Company members / owner-க்கான கூடுதல் SELECT policies உள்ளன; அவை private company workflow-க்கானவை.
- AI retrieval-க்கு public published policy மட்டுமே பயன்படுத்த வேண்டும். Private company policies-ஐ AI bypass செய்யக்கூடாது.
- தற்போதைய jobs அட்டவணையில் பதிவுகள் 0; published jobs-மும் 0. ஆகவே இப்போது AI vacancy recommendations வழங்க முடியாது.

பாதுகாப்பாக AI retrieval-க்கு அனுமதிக்கக்கூடிய fields (பின்னர் செயலாக்கும்போது):
`id, job_title, description, employment_type, workplace_type, experience_min, experience_max, salary_min, salary_max, salary_currency, salary_period, application_deadline, status, published_at, location, education_level, required_skills, job_kind, employer_name, official_website_url, official_notification_url, recruitment_authority, notification_number, country_name, government_scope`.

**AI-க்கு எடுக்கக்கூடாத fields:** `created_by`, `contact_email`, company-private data, application/resume/candidate records. Public job card-க்கு contact_email தேவையில்லை.

ஒவ்வொரு AI job result-லும் database `id` மற்றும் பொருத்தமான official/application URL citation ஆக இணைக்கப்பட வேண்டும். URL இல்லாத job-ஐ official-source verified என்று கூறக்கூடாது.

## 2. `job_sources` அட்டவணை

- RLS இயக்கப்பட்டுள்ளது.
- தற்போது எந்த RLS policy-யும் இல்லை.
- இது default-deny பாதுகாப்பு நிலை; இதை பொதுமக்களுக்கு திறக்க வேண்டாம்.
- AI-க்கு source registry தேவைப்பட்டால், service-role வழியாக table-ஐ திறப்பதற்குப் பதிலாக reviewed server-side mapping அல்லது தனி public-safe source metadata வடிவமைக்க வேண்டும்.
- இப்போது policy அல்லது grant மாற்றம் செய்யப்படவில்லை.

## 3. Supabase Security Advisor கண்டறிதல்கள்

ஆய்வு நேரத்தில்:
- RLS enabled but no policy: 2 tables — `company_invitations`, `job_sources`. இது default-deny ஆக இருக்கலாம்; அவற்றைத் திறக்காமல் ஒவ்வொரு table-ன் intended access model-ஐ தனியாக ஆய்வு செய்ய வேண்டும்.
- Security Advisor, authenticated users execute செய்யக்கூடிய SECURITY DEFINER functions குறித்து 15 warnings காட்டியது.
- Catalog read-only ஆய்வில் public schema-வில் 25 SECURITY DEFINER functions காணப்பட்டன; அவற்றில் 15-ஐ authenticated role execute செய்ய முடிகிறது; anon role execute செய்ய முடியவில்லை.
- SECURITY DEFINER function தானாகவே vulnerability என்று அர்த்தமில்லை. ஒவ்வொரு function body-யிலும் caller identity, role, ownership, row scope, argument validation ஆகியவை சரியாகச் சரிபார்க்கப்படுகிறதா என audit செய்ய வேண்டும்.
- எந்த function-க்கும் EXECUTE revoke செய்யப்படவில்லை; application workflows பாதிக்கப்படாமல் இருக்க blind blanket changes தவிர்க்கப்பட்டன.

## 4. Supabase platform மாற்றம் கவனிக்க வேண்டியது

2026-10-30 முதல் public schema-வில் புதிதாக உருவாக்கப்படும் tables Data API-க்கு தானாக expose ஆகாது என்று Supabase அறிவித்துள்ளது. எனவே எதிர்கால AI usage/rate-limit tables உருவாக்கும்போது RLS மட்டும் போதாது; தேவையான API exposure/grants-ஐத் தெளிவாகத் தேர்வு செய்ய வேண்டும். AI-க்காக புதிய table இப்போது உருவாக்கப்படவில்லை.

## 5. அடுத்த பாதுகாப்பான செயலாக்க வரிசை

1. Published job rows மற்றும் official source data முதலில் சேர்க்கப்பட்டு Admin review முடிவது.
2. Public RLS policy-ஐ anon/authenticated test identities மூலம் நேரடியாகச் சோதித்தல்.
3. AI endpoint-க்கு read-only `anon/publishable` client மட்டும்; service-role key பயன்படுத்த வேண்டாம்.
4. Server-side authenticated endpoint, per-user rate limits, request size/token limits, timeout, no-resume-logging.
5. Model endpoint / token அமைக்கப்படாதபோது fail-closed response.
6. Job data மட்டும் model context-க்கு; job text untrusted input.
7. Model output-ல் source job IDs verify செய்து, database-ல் இல்லாத job facts-ஐ நீக்குதல்.
8. Owner reviewக்கு பிறகே pilot enable.

## 6. உறுதிப்படுத்தப்பட்டவை மற்றும் செய்யப்படாதவை

**உறுதி செய்யப்பட்டவை:** jobs RLS policy விவரங்கள், job count zero, job_sources RLS/no-policy நிலை, Security Advisor warnings, SECURITY DEFINER execute grants ஆகியவை live database read-only queries மூலம் ஆய்வு செய்யப்பட்டன.

**செய்யப்படாதவை:** schema changes, grants, RLS changes, Edge Function deployment, AI model calls, production enablement.

**முடிவு:** தற்போதைய public job table policy ஒரு safe retrieval foundation ஆக இருக்கலாம்; ஆனால் published job data இல்லை. முதலில் verified jobs தரவு உருவாக வேண்டும். AI-க்கு private candidate/company data அணுகல் தேவையில்லை.
