# TAMILAN AI — பாதுகாப்பான Website Integration திட்டம்

**ஆய்வு தேதி:** 19-11-2026  
**நிலை:** வடிவமைப்பு / முன்-செயலாக்கம். இந்த ஆவணம் AI-ஐ இயக்காது; எந்த production endpoint-யும் மாற்றாது.

## 1. தற்போதைய repository ஆய்வு

GitHub main branch-இல் ஆய்வு செய்தபோது:

- `index.html`-இல் தற்போது TAMILAN AI chat widget அல்லது AI assistant UI இல்லை.
- Homepage-இல் Supabase browser client பயன்படுத்தப்படுகிறது. எனவே model credentials அல்லது service-role key-ஐ frontend-ல் சேர்ப்பது முற்றிலும் தவிர்க்கப்பட வேண்டும்.
- `supabase/functions/ai-resume-match/index.ts` தற்போது POST-க்கு HTTP 410 (disabled) அளிக்கிறது.
- `supabase/functions/bilingual-job-search/index.ts` தற்போது POST-க்கு HTTP 410 (disabled) அளிக்கிறது.
- இந்த இரண்டு பழைய endpoints-ஐ புதிய AI திட்டத்தின் பெயரில் அமைதியாக மாற்றக்கூடாது. அவை disabled-ஆகவே இருக்கும்; தனி புதிய endpoint-ஐ தனியாக review செய்ய வேண்டும்.
- தற்போதைய homepage-இல் AI செயல்பாடு இருப்பதாகக் காட்டும் UI இல்லை. எனவே இயங்காத “AI is ready” பொத்தான் அல்லது demo பதிலைச் சேர்க்கக்கூடாது.

## 2. பரிந்துரைக்கப்படும் கட்டமைப்பு

```
Browser (TAMILAN CAREERS)
        |
        | HTTPS + Supabase user session (where required)
        v
New Supabase Edge Function: tamilan-ai-assistant
        |
        +-- Feature flag check (default OFF)
        +-- Request validation / size limit
        +-- Rate limit / abuse controls
        +-- Safe system instructions
        +-- Read-only retrieval from approved public data
        |
        v
Private model inference endpoint (owner-controlled)
        |
        v
Validated answer + source references
        |
        v
Browser
```

- Browser-இல் model provider key, inference token, Supabase service-role key எதுவும் இருக்கக்கூடாது.
- Model endpoint URL மற்றும் token Supabase Edge Function secrets-இல் மட்டும் இருக்க வேண்டும்.
- புதிய Edge Function feature flag இல்லையெனில் பாதுகாப்பாக unavailable பதில் தர வேண்டும்.
- Model endpoint அமைக்கப்படாத நிலையில் mock/fake AI பதில் தரக்கூடாது.
- Browser நேரடியாக model host-ஐ அழைக்கக்கூடாது.

## 3. Feature flag மற்றும் rollout

பரிந்துரைக்கப்படும் server-side secrets:

| Secret | நோக்கம் | ஆரம்ப நிலை |
|---|---|---|
| `TAMILAN_AI_ENABLED` | முழு AI வசதியை இயக்க/நிறுத்த | `false` |
| `TAMILAN_AI_MODEL_URL` | தனிப்பட்ட inference endpoint | அமைக்கப்படாது |
| `TAMILAN_AI_MODEL_TOKEN` | inference endpoint அங்கீகாரம் | அமைக்கப்படாது |
| `TAMILAN_AI_MODEL_ID` | அனுமதிக்கப்பட்ட model identifier | தேர்வு முடியும் வரை அமைக்கப்படாது |

Secrets பெயர்கள் வடிவமைப்பு முன்மொழிவு மட்டுமே; இப்போது Supabase-இல் உருவாக்கப்படவில்லை. எந்த paid provider-யும் தானாகத் தேர்வு செய்யப்படாது.

Rollout படிகள்:
1. Offline prompt/data validation.
2. Free notebook-இல் model-ஐ owner இயக்கும் prototype; அதன் முடிவுகளைச் சேகரித்தல்.
3. Model quality, license, memory, latency மற்றும் safety review.
4. Private inference host தேர்வு. இலவச நிரந்தர GPU hosting கிடைக்கும் எனக் கருதக்கூடாது.
5. புதிய Edge Function-ஐ feature flag OFF நிலையில் deploy செய்து disabled response சோதனை.
6. Test users / limited pilot. Owner ஒப்புதல் மற்றும் செலவு/uptime முடிவு கிடைக்கும் வரை public enable செய்யக்கூடாது.

## 4. தரவு அணுகல் விதிகள்

### பொதுவான career assistant
- பொதுவான career guidance-க்கு login இல்லாத பயனருக்கும் வரையறுக்கப்பட்ட அணுகலை வழங்கலாம்.
- Vacancy, employer, salary, deadline, job count போன்ற உண்மைத் தகவல்கள் database-இல் இருந்து retrieval செய்யப்பட்டால் மட்டுமே பதிலில் சொல்லலாம்.
- `published` மற்றும் உரிய Admin review முடிந்த job records மட்டுமே பயன்படுத்தப்பட வேண்டும்.
- Job record-இன் source URL / job ID-ஐ பதிலுடன் வழங்க வேண்டும்.
- ஆதாரம் இல்லையெனில் “இந்தத் தகவலை உறுதிப்படுத்த முடியவில்லை” என்று கூற வேண்டும்; எண்ணிக்கையையோ vacancy-யையோ கற்பனை செய்யக்கூடாது.

### Resume மற்றும் தனிப்பட்ட தகவல்
- Resume analysis தனி authenticated flow ஆக இருக்க வேண்டும்; வெளிப்படையான user consent தேவை.
- Resume text-ஐ பொதுவான AI logs-ல் சேமிக்கக்கூடாது.
- வேறு பயனரின் resume, contact details, application status, employer-private data ஆகியவற்றை retrieval செய்யக்கூடாது.
- Resume content model training-க்கு பயன்படுத்தப்படக்கூடாது; தனி தெளிவான opt-in இல்லாமல் எந்த training-க்கும் சேர்க்கக்கூடாது.
- தற்போதைய disabled `ai-resume-match` endpoint-ஐ இந்த கட்டத்தில் மாற்றக்கூடாது.

## 5. AI-க்கு வழங்கக்கூடாத அதிகாரங்கள்

AI advisory assistant மட்டுமே. அது:
- job publish / unpublish செய்யக்கூடாது;
- company-ஐ verify / reject செய்யக்கூடாது;
- candidate-ஐ shortlist / reject செய்யக்கூடாது;
- fraud report-ஐ தானாகத் தீர்மானிக்கக்கூடாது;
- application அல்லது account data-ஐ மாற்றக்கூடாது;
- Admin / Super Admin privileges பெறக்கூடாது.

இத்தகைய செயல்கள் தற்போதைய அங்கீகரிக்கப்பட்ட மனித workflow மற்றும் பாதுகாப்பான RPC வழியாக மட்டுமே நடக்க வேண்டும்.

## 6. Prompt injection மற்றும் untrusted content

- Job description, company text, uploaded resume, user message அனைத்தும் untrusted input.
- அவற்றில் உள்ள “முந்தைய விதிகளை புறக்கணி”, “secret-ஐ வெளியிடு”, “இந்த job-ஐ publish செய்” போன்ற கட்டளைகளை system instruction ஆக ஏற்கக்கூடாது.
- Retrieved text-ஐ data ஆக மட்டுமே பயன்படுத்த வேண்டும்; tool/action instructions ஆக அல்ல.
- Model output-ஐ JSON schema / allowed fields மூலம் validate செய்ய வேண்டும்.
- URL-களை அனுமதிக்கப்பட்ட source host-களுக்கு மட்டும் கட்டுப்படுத்த வேண்டும்; arbitrary server-side URL fetch செய்யக்கூடாது (SSRF தடுப்பு).

## 7. API பாதுகாப்பு மற்றும் செலவு கட்டுப்பாடு

- CORS-ஐ production domain-க்கு மட்டும் கட்டுப்படுத்துதல்; தேவையற்ற wildcard தவிர்த்தல்.
- Request body அளவு, message length, conversation history, output tokens ஆகியவற்றுக்கு hard limits.
- IP/session/user அடிப்படையில் rate limit; anonymous abuse protection.
- Model timeout மற்றும் concurrency cap.
- Usage log-ல் user message / resume text இல்லாமல் request ID, status, token estimate, latency போன்ற குறைந்தபட்ச metadata மட்டும்.
- Model endpoint down அல்லது limit அடைந்தால் தெளிவான retry-later பதில்; fallback-ஆக கற்பனை பதில் இல்லை.
- எந்த paid service-யும் owner-ன் வெளிப்படையான ஒப்புதல் இன்றி இயக்கப்படக்கூடாது.

## 8. Multilingual நடத்தை

- User தேர்ந்தெடுத்த மொழியே முதன்மை; browser locale ஒரு உதவி signal மட்டுமே.
- முதற்கட்ட நேரடி மதிப்பீடு: தமிழ், ஆங்கிலம், இந்தி, Tanglish, அரபு, ஸ்பானிஷ், பிரெஞ்சு, இந்தோனேஷியன்.
- ஒவ்வொரு மொழிக்கும் தனித்த தர மதிப்பீடு வேண்டும். Model card-ல் “100+ languages” என்று இருப்பது எல்லா மொழிகளிலும் சமமான தரம் எனப் பொருளல்ல.
- மொழிபெயர்க்கப்பட்ட job text-க்கு மூல மொழி மற்றும் அதிகாரப்பூர்வ source link காட்ட வேண்டும்.
- பதில் மொழி தெரியாவிட்டால் பயனரிடம் மொழியைத் தேர்வு செய்யச் சொல்ல வேண்டும்; அமைதியாக தவறான மொழிக்கு மாற்றக்கூடாது.

## 9. செயலாக்கத்திற்கு முன் முடிக்க வேண்டியவை

- [ ] Free model prototype உண்மையில் இயக்கப்பட்டு முடிவுகள் பதிவு செய்யப்படுதல்.
- [ ] தேர்ந்தெடுக்கப்படும் exact model checkpoint-இன் license மற்றும் commercial-use terms மறுபரிசீலனை.
- [ ] தற்போதைய Supabase jobs schema / RLS-ஐ read-only retrieval-க்கு ஆய்வு.
- [ ] புதிய Edge Function-க்கான threat model மற்றும் request/response schema.
- [ ] Feature flag OFF, invalid input, rate limit, model unavailable, prompt injection ஆகியவற்றுக்கான tests.
- [ ] Privacy/logging review.
- [ ] Owner-ன் authenticated browser test.
- [ ] Public pilot enable செய்வதற்கு முன் owner-ன் வெளிப்படையான rollout ஒப்புதல்.


## 11. புதிய read-only job context அடித்தளம் — 19-11-2026

Repository-இல் `supabase/functions/tamilan-ai-job-context/index.ts` என்ற புதிய Edge Function source சேர்க்கப்பட்டுள்ளது. இது model inference செய்யாது; வெளியிடப்பட்ட வேலைவாய்ப்பு பதிவுகளை பாதுகாப்பாக context ஆக வழங்குவதற்கான தனி அடித்தளம் மட்டுமே.

- `supabase/config.toml`-இல் `verify_jwt = true` கட்டாயமாக அமைக்கப்பட்டுள்ளது.
- `TAMILAN_AI_RETRIEVAL_ENABLED` server-side flag `true` இல்லையெனில் HTTP 503 `FEATURE_DISABLED` கிடைக்கும். Secret உருவாக்கப்படவில்லை; function deploy செய்யப்படவில்லை.
- Supabase anon/publishable key + பயனரின் Bearer JWT மட்டுமே பயன்படுத்தப்படுகிறது. Service-role key பயன்படுத்தப்படவில்லை; எனவே jobs RLS policy தொடர்ந்து அமலில் இருக்கும்.
- `jobs.status = 'published'` மட்டும் query செய்யப்படுகிறது; அதிகபட்சம் 5 முடிவுகள்; job title / country search மட்டும். Request body 2 KB-க்கு வரையறுக்கப்பட்டுள்ளது.
- Candidate/application/private company தகவல்கள் select செய்யப்படவில்லை. `job_sources` அட்டவணையும் அணுகப்படவில்லை.
- ஒவ்வொரு context item-க்கும் உண்மையான `source_id`, citation URL, `content_is_untrusted` குறி சேர்க்கப்படுகிறது.
- Query மற்றும் country filter-களில் PostgREST wildcard/filter punctuation நீக்கப்படுகிறது; request-ல் அனுமதிக்கப்பட்ட `query`, `country` keys மட்டுமே.
- CORS production domain-களுக்கு மட்டும். இந்த prototype login தேவைப்படுத்துகிறது; anonymous public use இன்னும் இல்லை.
- புதிய static guard `scripts/tamilan-ai-retrieval-guard.py` மற்றும் GitHub Actions Deno type-check சேர்க்கப்பட்டுள்ளன.

**முக்கிய வரம்பு:** இந்த commit-இல் Edge Function source மட்டும் சேர்க்கப்பட்டுள்ளது. Deploy, runtime test, rate limiter, usage monitoring, model adapter, assistant UI எதுவும் இல்லை. Rate limiting மற்றும் authenticated integration tests சேர்க்கப்படும் வரை feature flag OFF-ஆகவே இருக்க வேண்டும். Job table தற்போது காலியாக இருப்பதால் vacancy பதில்கள் உருவாக்கப்படக்கூடாது.

## 12. Durable per-user rate limit — privilege boundary revised, source not applied

- Public Data API wrapper `public.tamilan_ai_consume_job_context_quota()` is `SECURITY INVOKER`, not SECURITY DEFINER.
- Privileged implementation `private.tamilan_ai_consume_job_context_quota()` stays in the non-exposed `private` schema. This private helper is SECURITY DEFINER with empty search_path; it checks `auth.uid()`, rejects anonymous Auth users, and can update only the caller's row.
- Both functions revoke PUBLIC/anon execute and grant execute only to authenticated. The wrapper can call the helper because authenticated already has USAGE on the private schema; the helper's own execute grant is narrow.
- A CI static guard now asserts the public wrapper never becomes SECURITY DEFINER and the private helper retains an empty search_path.

## 12. Durable per-user rate limit — source prepared, not applied

- புதிய migration source: `supabase/migrations/20261119080000_tamilan_ai_job_context_rate_limit.sql`.
- தனிப்பட்ட `private` schema-இல் ஒரு user-க்கு ஒரு counter row மட்டுமே. User prompts, resumes, search text, job descriptions எதுவும் சேமிக்கப்படாது.
- ஆரம்ப quota: ஒரு registered user-க்கு 10 requests / UTC minute, 100 requests / UTC day. Anonymous Auth users நிராகரிக்கப்படுவர்.
- Public RPC `tamilan_ai_consume_job_context_quota()` caller-ன் `auth.uid()` அடிப்படையில் மட்டுமே கணக்கிடும்; caller user ID அல்லது quota key அனுப்ப முடியாது. SECURITY DEFINER, empty search_path; execute `authenticated`-க்கு மட்டும்; `anon` மற்றும் PUBLIC மறுக்கப்பட்டுள்ளன.
- Counter atomic upsert மூலம் concurrent calls-ஐ serialize செய்கிறது. Quota table-க்கு API role direct grant இல்லை; RLS enabled, policy இல்லாமல் default deny.
- Edge Function job query-க்கு முன் RPC-ஐ அழைக்கும். RPC error / malformed output ஏற்பட்டால் 503 fail-closed; limit முடிந்தால் 429 + Retry-After.
- Deno unit tests மற்றும் static guard சேர்க்கப்பட்டுள்ளன.

**நேரடி Supabase-இல் இன்னும் apply செய்யவில்லை.** Source migration மற்றும் function code மட்டும் repository-யில் உள்ளன. Database migration apply, RPC permission live test, authenticated runtime test, function deploy, usage monitoring மற்றும் owner approval முடியும் வரை retrieval feature flag OFF-ஆகவே இருக்க வேண்டும். Migration-ஐ live-இல் இயக்குவதற்கு முன் GitHub Health Audit SQL lint மற்றும் Deno tests வெற்றி பெற வேண்டும்.

## 10. தற்போதைய முடிவு

**இப்போது செய்தவை:** repository-யில் homepage-க்கு AI widget இல்லை என்றும் இரண்டு பழைய AI endpoints disabled என்றும் code-ஐப் பார்த்து உறுதிப்படுத்தப்பட்டது. இந்த ஆவணம் பாதுகாப்பான புதிய integration-க்கான ஒப்பந்தத்தை வரையறுக்கிறது.

**இன்னும் செய்யப்படாதவை:** model inference இயக்கம், Supabase secrets, புதிய Edge Function, database retrieval, UI, live AI test, production deployment. இவற்றில் எதுவும் முடிந்ததாகக் கருதக்கூடாது.
