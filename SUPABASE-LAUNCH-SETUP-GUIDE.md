# TAMILAN CAREERS — Supabase வெளியீட்டு அமைப்பு வழிகாட்டி

இந்த வழிகாட்டி Supabase Dashboard-ல் செய்ய வேண்டிய மீதமுள்ள பணிகளை சரியான வரிசையில் முடிக்க உதவும். SQL கோப்புகளை ஒன்றன்பின் ஒன்றாக மட்டும் இயக்கவும். ஒவ்வொரு கோப்பிற்குப் பிறகும் பிழை இல்லாமல் முடிந்ததா என்று பார்க்கவும்.

## 1. SQL கோப்புகளை இயக்கும் வரிசை

Supabase Dashboard → SQL Editor → New query. GitHub-ல் உள்ள கோப்பைத் திறந்து முழு SQL-ஐ நகலெடுத்து SQL Editor-ல் ஒட்டி Run செய்யவும்.

1. [supabase-setup-pending.sql](https://github.com/arulmuruganbe5540-prog/TAMILAN-CAREERS/blob/main/supabase-setup-pending.sql) — தனிப்பட்ட Resume Storage, Candidate Resume பதிவுகள், Job Drafts, கல்வி, அனுபவம், சான்றிதழ்கள், விண்ணப்பித்த Candidate விவரங்களை Employer பார்க்கும் வரையறுக்கப்பட்ட அனுமதி.
2. [supabase-candidate-profile-education-experience.sql](https://github.com/arulmuruganbe5540-prog/TAMILAN-CAREERS/blob/main/supabase-candidate-profile-education-experience.sql) — கல்வி, அனுபவம், சான்றிதழ் அட்டவணைகள் மற்றும் அவற்றின் பாதுகாப்பு விதிகள். முதல் கோப்பில் இவை ஏற்கெனவே உருவாக்கப்பட்டிருந்தாலும் மீண்டும் இயக்கலாம்.
3. [supabase-company-application-status.sql](https://github.com/arulmuruganbe5540-prog/TAMILAN-CAREERS/blob/main/supabase-company-application-status.sql) — Company விண்ணப்ப நிலை மாற்றும் அனுமதி.
4. [supabase-interview-notifications.sql](https://github.com/arulmuruganbe5540-prog/TAMILAN-CAREERS/blob/main/supabase-interview-notifications.sql) — Candidate / Company அறிவிப்புகள், Interview அழைப்பு, Candidate ஏற்றல் / மறுத்தல், விண்ணப்ப நிலை அறிவிப்பு. இது முந்தைய கோப்பின் application-status RPC-ஐ அறிவிப்புகளுடன் புதுப்பிக்கும்.
5. [supabase-government-archive-install.sql](https://github.com/arulmuruganbe5540-prog/TAMILAN-CAREERS/blob/main/supabase-government-archive-install.sql) — அரசு வேலை அறிவிப்பு ஆதாரங்கள், தனிப்பட்ட Admin Review Queue, சரிபார்த்து வெளியிடும் பாதுகாப்பான RPC.

**முக்கியம்:** SQL Editor-ல் ஒவ்வொரு கோப்பையும் தனித்தனியாக Run செய்யவும். வெற்றி என்ற செய்தி வந்த பிறகே அடுத்த கோப்புக்குச் செல்லவும். எந்த SQL பிழை வந்தாலும் அதைத் தாண்டி அடுத்த கோப்பை இயக்க வேண்டாம்.

## 2. Edge Functions Deploy

Supabase Dashboard → Edge Functions → ஒவ்வொரு Function-ஐத் திறந்து GitHub-ல் உள்ள தற்போதைய `index.ts` code-ஐ Deploy செய்ய வேண்டும்.

- `company-resume-access` — விண்ணப்பித்த Candidate-ன் Resume-ஐ உரிய Company உறுப்பினருக்கு மட்டும் 60 வினாடி பாதுகாப்பான இணைப்பாக வழங்கும்.
- `scan-external-job-sources` — அனுமதிக்கப்பட்ட வெளிப்புற வேலை ஆதாரங்களில் இணைப்புகளைத் தேடும். `robots.txt` அனுமதி உள்ள பக்கங்களை மட்டுமே scan செய்யும்; கண்டுபிடிப்புகள் தனிப்பட்ட Admin Review-ல் மட்டுமே இருக்கும்.
- `ingest-government-notices` — `robots.txt` அனுமதி உள்ள அரசு அறிவிப்பு / முடிவு / Hall Ticket பக்கங்களை மட்டுமே scan செய்து தனிப்பட்ட Admin Review-க்கு அனுப்பும்.
- `ai-resume-match` — Candidate ஒப்புதல் அளித்த பிறகே Resume மற்றும் வேலைக்குத் தொடர்புடைய சுயவிவர விவரங்களை AI சேவைக்கு அனுப்பும்.

Deploy செய்த பிறகு Function-ன் Logs-ல் பிழை இல்லையா எனப் பார்க்கவும். Function Deploy ஆனது மட்டும் live workflow வெற்றியடைந்ததாக அர்த்தமில்லை.

## 3. பாதுகாப்பு Secret-கள்

- `GOVERNMENT_MONITOR_SECRET` — Government மற்றும் external source monitor-க்கு Supabase Function Secrets மற்றும் GitHub Actions Secrets இரண்டிலும் ஒரே பாதுகாப்பான மதிப்பு தேவை. குறைந்தது 32 எழுத்துகள்; சீரற்ற தனித்துவமான மதிப்பை உருவாக்கவும். Chat-ல் பகிர வேண்டாம்.
- `OPENAI_API_KEY` — AI Resume Matching Function-க்கு மட்டும் Supabase Function Secret ஆக சேர்க்க வேண்டும். Frontend அல்லது GitHub source code-ல் வைக்க வேண்டாம்.
- Scanner Function-கள் custom `x-monitor-secret` header பயன்படுத்துகின்றன. Supabase Function Gateway-யின் legacy JWT verification ON ஆக இருந்தால், அந்த Gateway custom header-ஐ அடையும் முன்பே request-ஐ மறுக்கலாம். அமைப்பைச் சரிபார்த்து தேவையான இடத்தில் மட்டுமே OFF செய்யவும்.

## 4. உண்மையான கணக்குகளில் சோதனை

- Candidate: Resume upload / delete, கல்வி / அனுபவம் / சான்றிதழ் சேமிப்பு, வேலைக்கு விண்ணப்பித்தல், விண்ணப்பத்தைத் திரும்பப் பெறுதல்.
- Employer: விண்ணப்பித்த Candidate விவரங்கள், விண்ணப்ப நிலை மாற்றம், Interview அழைப்பு, Resume பார்க்கும் அனுமதி.
- பாதுகாப்பு: வேறு Company-யின் Candidate Resume-ஐப் பார்க்க முயன்றால் மறுக்கப்பட வேண்டும். Login இல்லாதவர் Admin Review பக்கங்களைப் பார்க்கக் கூடாது.
- Government Jobs: கண்டறியப்பட்ட இணைப்புகள் அனைத்தும் தனிப்பட்ட Review Queue-ல் இருக்க வேண்டும். அதிகாரப்பூர்வ அறிவிப்பு, தேதி, காலியிடம், தகுதி, விண்ணப்ப இணைப்பு சரிபார்க்கப்படாமல் வெளியிடக்கூடாது.
- AI: ஒப்புதல் checkbox இல்லாமல் AI Function அழைக்கப்படக் கூடாது; ஒப்புதல் இருந்தால் மட்டும் AI பொருத்தம் சோதிக்க வேண்டும்.

## 5. வெளியீடு முடிந்தது என்று எப்போது சொல்லலாம்?

SQL வெற்றி, Function Deploy, Secret அமைப்பு, RLS அனுமதி, உண்மையான Candidate / Employer கணக்குச் சோதனை, Android மொபைல் சோதனை, GitHub Pages மற்றும் Health Check வெற்றி — இவை அனைத்தும் உறுதிப்படுத்தப்பட்ட பிறகே முழு வெளியீடு முடிந்ததாகக் குறிக்கப்படும்.
