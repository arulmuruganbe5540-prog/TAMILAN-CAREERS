# TAMILAN CAREERS — கடைசி அமைப்பு வேலைகள் (தமிழ்)

இந்தக் கோப்பில் உள்ளவை, குறியீடு/Database மாற்றங்களால் மட்டும் முடிக்க முடியாத வெளிப்புற கணக்கு அமைப்புகள். எந்த ரகசியத்தையும் ChatGPT-யில் பகிர வேண்டாம்.

## 1. Email அனுப்புதல் — சொந்த Domain இல்லாமலும் செய்யலாம்

Gmail SMTP பயன்படுத்தலாம். இது சிறிய அளவிலான சோதனை/தொடக்கப் பயன்பாட்டுக்கு ஏற்றது; அதிக அளவு production email-க்கு தனி email provider சிறந்தது.

1. Gmail கணக்கில் Google Account → Security → 2-Step Verification இயக்கவும்.
2. Google App Password பக்கத்தில் புதிய App Password உருவாக்கவும்: https://myaccount.google.com/apppasswords
3. Supabase Dashboard → Authentication → SMTP Settings பகுதியில் Custom SMTP இயக்கவும்: https://supabase.com/dashboard/project/qkmljuuusfjowexvybvy/auth/smtp
4. கீழே உள்ள அமைப்புகளை நிரப்பவும்:
   - Host: `smtp.gmail.com`
   - Port: `465` (SSL) அல்லது `587` (STARTTLS)
   - Username: உங்கள் Gmail முகவரி
   - Password: Google உருவாக்கிய App Password
   - Sender email: அதே Gmail முகவரி
   - Sender name: `TAMILAN CAREERS`
5. Save செய்து புதிய test account மூலம் signup email-ஐச் சோதிக்கவும். Email வரவில்லை என்றால் Spam/Promotions பார்க்கவும். Gmail SMTP-க்கு SSL 465 அல்லது STARTTLS 587 பயன்படுத்தலாம்.

Supabase இயல்பான SMTP சேவை பொதுப் பயனர்களுக்கு ஏற்றதல்ல: அது Project Team-இல் உள்ள Email முகவரிகளுக்கு மட்டுமே அனுப்பும்; தற்போது மணிக்கு 2 Email வரம்பும் உள்ளது. Custom SMTP அமைத்த பிறகே எல்லா பயனர்களுக்கும் அனுப்ப முடியும்.

**கவனம்:** Gmail சாதாரண Login Password-ஐ SMTP password ஆகப் பயன்படுத்த வேண்டாம். App Password-ஐ யாரிடமும் பகிர வேண்டாம்.

## 2. OpenAI API Credits

Government notice AI extraction-ஐச் சோதித்தபோது OpenAI API பதில்: `429 — You have no credits remaining`.

1. OpenAI Platform Billing பக்கத்தில் API credits / payment method சேர்க்கவும்.
2. ஏற்கெனவே Supabase Function Secret-ஆக அமைக்கப்பட்டுள்ள `OPENAI_API_KEY`-ஐ இங்கே பகிர வேண்டாம்.
3. Credits சேர்த்த பிறகு TAMILAN CAREERS → Admin Login → அரசு அறிவிப்பு ஆய்வு பக்கத்தில் ஒவ்வொரு நிலுவை அறிவிப்புக்கும் **AI விவரங்களை மீண்டும் முயற்சி** பொத்தானைப் பயன்படுத்தலாம்.

Billing: https://platform.openai.com/settings/organization/billing/overview

## 3. Leaked Password Protection

Supabase Dashboard → Authentication → Security and Protection பகுதியில் Leaked Password Protection-ஐ இயக்கி Save செய்யவும். இந்த அமைப்பு Dashboard-இல் செய்ய வேண்டியது; அதை இங்கிருந்து மாற்ற முடியாது.

## 4. இறுதி நேரடி சோதனை

1. Admin Login: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/admin-login.html
2. Admin Control: https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/admin-control.html
3. ஒரு சோதனை Company கணக்கு உருவாக்கவும்.
4. ஒரு Draft Job உருவாக்கி, அனுமதி/வெளியீட்டு செயல்முறையைச் சோதிக்கவும்.
5. தனி Job Seeker கணக்கில் Login செய்து அந்த Job-க்கு விண்ணப்பிக்கவும்.
6. Admin/Company பகுதியில் விண்ணப்பம் சரியாகத் தெரிகிறதா எனச் சரிபார்க்கவும்.

## 5. தற்போதைய தானியங்கி கண்காணிப்பு

- Government official sources: 48 enabled.
- External job sources: 30 enabled; 6 public-page sources scan செய்யப்படுகின்றன; 24 manual-only sources தானாக crawl செய்யப்படுவதில்லை.
- External candidate links: Admin Review-க்கு மட்டும்; தானாக public ஆகாது.
- Government notice queue: Admin Review-க்கு மட்டும்; தானாக public ஆகாது.
