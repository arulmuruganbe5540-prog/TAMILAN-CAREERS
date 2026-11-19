# TAMILAN CAREERS — SECURITY DEFINER விரிவான மறுஆய்வு

**ஆய்வு தேதி:** 19-11-2026  
**முறை:** Supabase catalog, function-definition மற்றும் Security Advisor read-only ஆய்வு.  
**மாற்றங்கள்:** Database schema, data, grants, policies, secrets அல்லது functions எதுவும் மாற்றப்படவில்லை.

## முடிவு

- public schema-வில் 29 SECURITY DEFINER functions உள்ளன.
- அவற்றில் 15 functions-ஐ authenticated role அழைக்க முடியும்; Security Advisor இதையே எச்சரிக்கையாகக் காட்டுகிறது.
- இந்த 15 functions-க்கும் SET search_path TO '' உள்ளது; function source-ல் ஒவ்வொன்றுக்கும் auth.uid() அடிப்படையிலான user/ownership check அல்லது Super Admin authorization check உள்ளது.
- இந்த 15 RPC-களுக்கு anon EXECUTE அனுமதி இல்லை.
- Active candidate/employer workflows பாதிக்கப்படாமல் இருக்க blanket REVOKE செய்யப்படவில்லை.

## Authenticated role-க்கு கிடைக்கும் 15 RPC-கள்

1. tc_admin_publish_job — Super Admin + MFA helper.
2. tc_candidate_withdraw_application — candidate ownership.
3. tc_company_manage_published_job — verified company Owner/HR Manager.
4. tc_company_resubmit_verification — request/company permission.
5. tc_company_update_application_status — company membership/ownership.
6. tc_mark_all_notifications_read — caller notifications only.
7. tc_mark_notification_read — notification ownership.
8. tc_respond_interview_invitation — invitation recipient ownership.
9. tc_review_company_verification — Super Admin + MFA helper.
10. tc_review_external_job_candidate — Super Admin + conditional AAL2.
11. tc_review_job_report — Super Admin + MFA helper.
12. tc_send_interview_invitation — active company role.
13. tc_submit_company_job_draft_for_review — draft owner, active role and verified company.
14. tc_submit_company_verification — authenticated company submission.
15. tc_submit_job_report — authenticated reporter and published job check.

> இது catalog/source-level review மட்டுமே; ஒவ்வொரு RPC-க்கும் live browser integration test முடிந்தது என்று பொருளல்ல.

## MFA ஆய்வு

- Job publish, company verification review, job report review மற்றும் company verification status trigger ஆகியவை private.require_super_admin_mfa() பயன்படுத்துகின்றன.
- tc_review_external_job_candidate அதே policy-ஐ நேரடியாகச் செயல்படுத்துகிறது: verified MFA factor உள்ள account-க்கு JWT aal2 அவசியம்; MFA enroll செய்யாத account-க்கு தற்போதைய rollout compatibility தொடர்கிறது.
- ஆகவே external candidate review-இன் conditional MFA நடைமுறை helper policy-யுடன் ஒத்துள்ளது; இதை தனி vulnerability என வகைப்படுத்தவில்லை.
- Owner-ன் உண்மையான AAL1/AAL2 browser test இன்னும் தேவை.

## மற்ற SECURITY DEFINER functions

- accept_company_invitation-க்கு explicit execute grantees postgres மற்றும் service_role மட்டுமே; இது authenticated/anon public RPC அல்ல. Server-side token, user ID மற்றும் email binding தொடர்ந்து பாதுகாக்கப்பட வேண்டும்.
- rls_auto_enable என்பது event-trigger function; dynamic SQL இருப்பதால் migration/event-trigger scope-இல் மட்டுமே பயன்படுத்தப்படுகிறதா என future review-இல் கவனிக்க வேண்டும்.
- Trigger/internal maintenance functions browser RPC போல நடத்தப்படக்கூடாது.

## Security Advisor-இன் மீதமுள்ள findings

1. 15 authenticated-callable SECURITY DEFINER warnings: இவை தானாக vulnerability என்று பொருளல்ல; ஒவ்வொரு workflow-க்கும் positive/negative integration tests தேவை. https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable
2. RLS enabled/no policy: public.company_invitations மற்றும் public.job_sources. இவை default-deny நிலையில் தொடரட்டும்; job_sources-ஐ AI retrieval-க்கு திறக்கக்கூடாது. https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy
3. Leaked Password Protection disabled: Supabase Auth dashboard-இல் owner enable செய்ய வேண்டிய அமைப்பு. https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

## அடுத்த நடவடிக்கைகள்

- Candidate, employer மற்றும் admin RPC-களுக்கு positive + negative ownership tests.
- Admin MFA AAL1/AAL2 end-to-end tests.
- Owner Leaked Password Protection enable செய்த பின் Security Advisor மீண்டும் இயக்குதல்.
- Default-deny tables-க்கு தேவையற்ற public policies சேர்க்காமல் இருப்பது.
- AI retrieval endpoint-ஐ feature OFF-ஆகவே வைத்தல்; rate limit மற்றும் runtime tests முடியும் வரை deploy/enable செய்யாதிருத்தல்.

**இந்த audit read-only; live database-ல் எந்த மாற்றமும் செய்யப்படவில்லை.**