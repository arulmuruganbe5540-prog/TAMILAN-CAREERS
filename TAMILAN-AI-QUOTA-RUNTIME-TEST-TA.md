# TAMILAN AI — Quota RPC runtime test runbook (தமிழ்)

**தயாரிப்பு தேதி:** 19-11-2026  
**நிலை:** Live quota migration apply செய்யப்பட்டது; ஆரம்ப database-level சோதனைகள் முடிந்தன. மீதமுள்ள real-session / cross-account / concurrency சோதனைகள் இன்னும் தேவை. இந்த ஆவணம் Edge Function-ஐ deploy/enable செய்யாது.

## HTTP contract / request-size regression tests — 19-11-2026

GitHub Health Audit run `44477126602` PASS; commit `69dced1091ab147e5f3834c0ced1c9e362cd1411`.

- `handler_test.ts` contains 10 Deno HTTP contract tests, including default-OFF behavior, Bearer token checks, JSON content type, CORS, malformed/oversized input, quota failure/429, published-only result bounds, citations, and query failures.
- Request bodies are read as a stream with a hard 2,048-byte limit; an oversized stream is cancelled before the Supabase client is created.
- The static guard checks that the stream limit, cancellation, non-empty Bearer token, and JSON content type remain enforced.
- The workflow passed all tracked Edge Function type checks, retrieval and rollout guards, logic + HTTP contract tests, website structure validation, and Playwright browser smoke tests.
- GitHub Pages deployment for the subsequent status documentation commit `127eb6649893de64cd2d19472deb6cf8293db927` also passed (run `44477582709`).
- These tests use a fake Supabase client and do not establish real JWT validity, live RLS behavior, cross-account isolation, Anonymous Auth rejection, or production concurrency behavior. The AI Edge Function remains undeployed and OFF.

## 1. சோதனைக்கு முன் கட்டாய நிபந்தனைகள்

இந்த சோதனைகளைத் தொடங்குவதற்கு முன்:

1. Project owner தனியாக அனுமதி அளித்திருக்க வேண்டும்.
2. `20261119065045_tamilan_ai_job_context_rate_limit.sql` migration-ஐ owner அங்கீகரித்த முறையில் apply செய்திருக்க வேண்டும்.
3. குறைந்தது இரண்டு உண்மையான, கட்டுப்பாட்டில் உள்ள registered test accounts (A, B) இருக்க வேண்டும். அவற்றின் Auth UUID-களை Supabase Dashboard-இல் இருந்து owner பாதுகாப்பாகப் பெற வேண்டும். UUID/JWT/password-ஐ GitHub issue, source code அல்லது ChatGPT உரையாடலில் இட வேண்டாம்.
4. Anonymous Auth account சோதனை தேவையானால் தனி disposable anonymous account உருவாக்கி அதன் UUID-ஐ owner வைத்திருக்க வேண்டும்.
5. முதலில் staging/test project-இல் சோதிப்பது சிறந்தது. Production-இல் quota counters-ஐ மாற்றும் சோதனைகள் செய்ய வேண்டாம்; production-இல் சோதிக்க owner தனியாக ஒப்புதல் அளிக்க வேண்டும்.
6. Migration இல்லாமல் RPC test செய்ய வேண்டாம். Edge Function deploy/feature flag enable செய்வதற்கு இந்த runbook வெற்றியடைந்தது மட்டும் போதாது.

## 2. எதிர்பார்க்கப்படும் பாதுகாப்பு எல்லைகள்

- `public.tamilan_ai_consume_job_context_quota()` authenticated role-க்கு மட்டும் EXECUTE.
- `private.tamilan_ai_consume_job_context_quota()` authenticated role-க்கு மட்டும் EXECUTE; anon/PUBLIC மறுக்கப்பட வேண்டும்.
- `private.tamilan_ai_job_context_rate_limits` அட்டவணையை API roles நேரடியாகப் படிக்க/எழுத முடியக்கூடாது.
- ஒவ்வொரு registered user-க்கும் தனி quota row; caller-ன் `auth.uid()` மட்டுமே பயன்படுத்தப்பட வேண்டும்.
- Anonymous Auth user நிராகரிக்கப்பட வேண்டும்.
- UTC minute-க்கு 10; UTC day-க்கு 100 அனுமதிக்கப்பட்ட calls. எல்லையை மீறும் call மறுக்கப்படும்.
- Concurrent calls atomic-ஆக எண்ணப்பட வேண்டும்; quota limit தாண்டி கூடுதல் calls அனுமதிக்கப்படக்கூடாது.
- quota response-ல் மீதமுள்ள எண்ணிக்கை மற்றும் `retry_after_seconds` சரியாக இருக்க வேண்டும்.

## 3. SQL catalog / privilege preflight

Migration apply ஆன பிறகே SQL Editor-இல் இதை இயக்கவும்:

```sql
select
  to_regclass('private.tamilan_ai_job_context_rate_limits') as quota_table,
  to_regprocedure('private.tamilan_ai_consume_job_context_quota()') as private_rpc,
  to_regprocedure('public.tamilan_ai_consume_job_context_quota()') as public_rpc;

```

```sql
select
  n.nspname,
  p.proname,
  p.prosecdef,
  p.proconfig
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where p.oid in (
  'private.tamilan_ai_consume_job_context_quota()'::regprocedure,
  'public.tamilan_ai_consume_job_context_quota()'::regprocedure
);
```

எதிர்பார்ப்பு: private helper மட்டும் `SECURITY DEFINER`; public wrapper `SECURITY INVOKER`; private helper-ன் `search_path` காலியாக இருக்க வேண்டும்.

## 4. Authenticated account A — அடிப்படை call

Owner-ன் பாதுகாப்பான test session/JWT மூலம் authenticated RPC call செய்யவும். SQL Editor-இல் போலியான UUID அல்லது வெறும் `SET ROLE` மட்டும் உண்மையான JWT-க்கு மாற்றாகாது. உண்மையான user session-இல் இருந்து Supabase client மூலம்:

```js
const { data, error } = await supabase.rpc(
  "tamilan_ai_consume_job_context_quota"
);
```

முதல் 10 calls-க்கு `allowed: true` வர வேண்டும். முதல் call-க்கு பொதுவாக minute_remaining 9, day_remaining 99; அதே bucket-இல் அடுத்த calls-ல் குறைய வேண்டும். Minute/day boundary கடந்தால் counter புதிய bucket-ஆக reset ஆகும்.

## 5. Limit சோதனை

**Staging/test project மட்டும்.** Account A-இல் ஒரே UTC minute-க்குள் 11 sequential calls செய்யவும்:

- Calls 1–10: `allowed: true`.
- Call 11: `allowed: false`, `minute_remaining: 0`, `retry_after_seconds >= 1`.
- அடுத்த minute bucket-இல் மீண்டும் அனுமதி கிடைக்க வேண்டும்; daily quota முடிவடையாதிருக்க வேண்டும்.

Daily limit சோதனைக்காக staging/test project-இல் மட்டும் ஒரே UTC day-க்குள் 101 calls செய்யவும்:

- Calls 1–100: daily quota அடிப்படையில் அனுமதி.
- Call 101: `allowed: false`, `day_remaining: 0`, `retry_after_seconds >= 1`.

ஒரே minute limit 10 என்பதால் daily test-ஐ நேரடியாக 101 calls செய்து முடிக்க முடியாது; பல minute buckets-ஆக சோதிக்க வேண்டும். UTC day boundary-ஐத் தாண்டாமல் திட்டமிடவும். Production quota-வை இவ்வாறு drain செய்ய வேண்டாம்.

## 6. Cross-account isolation

- Account A-இன் quota-வை 2–3 calls மூலம் பயன்படுத்தவும்.
- Account B-இல் login செய்து அதே RPC-ஐ அழைக்கவும்.
- B-க்கு தனித்த counter (அதன் முதல் call-க்கு minute_remaining 9, day_remaining 99) கிடைக்க வேண்டும்.
- A-வின் quota B-க்கு மாற்றப்படக்கூடாது; A-வின் UUID-ஐ request body அல்லது RPC argument மூலம் வழங்கும் வழி இல்லை.

## 7. Anonymous / unauthenticated denial

- JWT இல்லாத call: public RPC execute அனுமதி கிடைக்கக்கூடாது அல்லது authentication error வர வேண்டும்.
- Supabase Anonymous Auth user session மூலம் public RPC call: registered account required என மறுக்கப்பட வேண்டும்.
- anon role-க்கு private helper execute privilege இருக்கக்கூடாது.

இவை உண்மையான anonymous session மற்றும் anon key மூலம் சோதிக்கப்பட வேண்டும்; வெறும் SQL role simulation முழுமையான Auth சோதனை அல்ல.

## 8. Direct table access denial

Authenticated client மூலம் `private.tamilan_ai_job_context_rate_limits`-ஐ SELECT/INSERT/UPDATE செய்ய முயற்சிக்கவும். எல்லா direct access-களும் permission/schema exposure காரணமாக மறுக்கப்பட வேண்டும். அட்டவணை API roles-க்கு நேரடியாகத் திறக்கப்படக்கூடாது.

## 9. Atomic concurrency

Staging/test project-இல் account A-க்கு ஒரே UTC minute-இல் 15 அல்லது அதற்கு மேற்பட்ட இணைநேர RPC requests அனுப்பவும். எதிர்பார்ப்பு: அந்த minute-இல் அதிகபட்சம் 10 calls மட்டுமே `allowed: true`; மீதமுள்ளவை deny. ஒரே நேரத்தில் வந்த calls அனைத்தும் வெற்றி பெறுவது அல்லது count 10-ஐத் தாண்டுவது failure. சோதனையை மீண்டும் புதிய minute bucket-இல் இயக்கி உறுதிப்படுத்தவும்.

## 10. Live Supabase-இல் செய்யப்பட்ட ஆரம்ப சோதனைகள் — 19-11-2026

Project owner அனுமதிக்குப் பிறகு migration live project-இல் apply செய்யப்பட்டது. Migration history version: `20261119065045`.

**PASS — Catalog / privilege boundary**
- Quota table உள்ளது; RLS ON.
- `anon` மற்றும் `authenticated` இரண்டிற்கும் quota table direct SELECT privilege இல்லை.
- anon-க்கு private helper மற்றும் public RPC EXECUTE இல்லை.
- authenticated-க்கு இரு functions EXECUTE உள்ளது.
- private helper மட்டும் SECURITY DEFINER; public wrapper SECURITY INVOKER; இரண்டிற்கும் empty search_path.

**PASS — Database-role simulation (உண்மையான browser JWT அல்ல)**
- Registered account claim உடன் authenticated role-ல் அடிப்படை RPC: `allowed=true`, initial `minute_remaining=9`, `day_remaining=99`.
- 11 calls ஒரே transaction-ல்: 10 allowed, 1 denied; denied call-க்கு positive Retry-After.
- Daily counter 100 என transaction-க்குள் அமைத்து சோதித்தபோது: `allowed=false`, `day_remaining=0`, positive Retry-After.
- எல்லா test writes-உம் ROLLBACK செய்யப்பட்டன; பின்னர் persistent quota row count = 0.

**இன்னும் செய்ய வேண்டியவை**
- இரண்டு உண்மையான owner-controlled accounts மூலம் cross-account isolation.
- உண்மையான Anonymous Auth session மற்றும் no-JWT HTTP denial.
- இணைநேர request stress test (குறைந்தது 15 requests).
- உண்மையான browser/client JWT மூலம் Edge Function authenticated integration test.

இந்த SQL role/claim simulation உண்மையான client JWT சோதனைக்கு மாற்றாகாது. Production quota rows-ஐ உருவாக்காமல், transaction rollback மூலம் boundary checks செய்யப்பட்டன.

## 11. முடிவு பதிவு

ஒவ்வொரு சோதனைக்கும் PASS / FAIL, தேதி (UTC), project (staging/production), test account label (A/B; UUID அல்ல), response fields மற்றும் பிழைச் சுருக்கம் மட்டும் பதிவு செய்யவும். JWT, password, resume, prompt, job description அல்லது தனிப்பட்ட தகவலை log செய்ய வேண்டாம்.

## 12. Enable செய்யும் முன் இறுதி gate

இந்த quota tests வெற்றி பெற்றாலும் கீழ்கண்டவை தனித்தனியாக முடியும் வரை AI retrieval OFF-ஆகவே இருக்க வேண்டும்:

- Edge Function authenticated runtime test மற்றும் RLS verification.
- quota boundary / concurrency / cross-account / anonymous denial சோதனைகள்.
- privacy, CORS, rate-limit response மற்றும் failure-mode review.
- உண்மையான published jobs இல்லையெனில் vacancy assistant-ஐ “இயங்குகிறது” என்று காட்டக்கூடாது.
- owner-ன் வெளிப்படையான rollout ஒப்புதல்.

**தற்போதைய நிலை:** migration live Supabase-இல் apply செய்யப்பட்டுள்ளது. ஆரம்ப SQL catalog/privilege, minute limit மற்றும் daily limit சோதனைகள் PASS. உண்மையான JWT, cross-account, anonymous session, concurrency சோதனைகள் மீதமுள்ளன. Edge Function deploy செய்யப்படவில்லை; feature flag OFF.