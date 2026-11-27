(function(global){
'use strict';
const tamilNaduPlaces=['tamil nadu','chennai','salem','namakkal','coimbatore','madurai','erode','vellore','tiruppur','thanjavur','tirunelveli','kanchipuram','cuddalore','dindigul','karur','krishnagiri','dharmapuri','villupuram','kallakurichi','perambalur','ariyalur','sivaganga','virudhunagar','thoothukudi','tenkasi','nilgiris','ooty','ranipet','chengalpattu','tiruvallur','mayiladuthurai','nagapattinam','pudukkottai','ramanathapuram','tiruchirappalli','trichy'];
const labels={
'All Government Jobs in India':'இந்தியாவின் அனைத்து அரசு வேலைவாய்ப்புகள்',
'Government Jobs':'அரசு வேலைவாய்ப்புகள்','Private Jobs':'தனியார் வேலைவாய்ப்புகள்',
'Job Details':'வேலைவாய்ப்பு விவரங்கள்','Department':'துறை','Recruitment Authority':'ஆட்சேர்ப்பு நிறுவனம்',
'Government Category':'அரசுப் பிரிவு','State / Union Territory':'மாநிலம் / யூனியன் பிரதேசம்',
'Job Post':'பணியின் பெயர்','Job Type':'பணி வகை','Notification Number':'அறிவிப்பு எண்',
'Qualification':'கல்வித் தகுதி','Vacancies':'காலிப்பணியிடங்கள்','Age Limit':'வயது வரம்பு',
'Age Relaxation':'வயது தளர்வு','Experience':'அனுபவம்','Application Fee':'விண்ணப்பக் கட்டணம்',
'Location':'பணியிடம்','Salary':'சம்பளம்','Notification Date':'அறிவிப்பு தேதி',
'Application Start Date':'விண்ணப்பம் தொடங்கும் தேதி','Last Date to Apply':'விண்ணப்பிக்க கடைசி தேதி',
'Exam Date':'தேர்வு தேதி','Selection Process':'தேர்வு முறை','How to Apply':'விண்ணப்பிக்கும் முறை',
'Additional Information':'கூடுதல் தகவல்கள்','Job Description':'பணி விவரம்',
'Government Recruitment · Official Details':'அரசு வேலைவாய்ப்பு · அதிகாரப்பூர்வ விவரங்கள்',
'Job Overview':'வேலைவாய்ப்பு சுருக்கம்','Syllabus & Exam Pattern':'பாடத்திட்டம் மற்றும் தேர்வு முறை',
'Model Exam Question Papers':'மாதிரி தேர்வுக் கேள்வித்தாள்கள்','Previous Year Question Papers':'முந்தைய ஆண்டு வினாத்தாள்கள்',
'Answer Keys':'விடைக்குறிப்புகள்','Detailed Solutions / Explanations':'விரிவான தீர்வுகள் / விளக்கங்கள்',
'Mock Tests':'மாதிரித் தேர்வுகள்','Official Website ↗':'அதிகாரப்பூர்வ இணையதளம் ↗',
'Share This Job':'இந்த வேலைவாய்ப்பைப் பகிரவும்','Application Form':'விண்ணப்பப் படிவம்',
'Apply Now':'இப்போது விண்ணப்பிக்கவும்','Apply through TAMILAN CAREERS':'TAMILAN CAREERS மூலம் விண்ணப்பிக்கவும்',
'Continue to the employer application page':'நிறுவனத்தின் விண்ணப்பப் பக்கத்திற்குத் தொடரவும்',
'View Job Notification PDF':'வேலைவாய்ப்பு அறிவிப்பு PDF-ஐப் பார்க்கவும்',
'Open the available recruitment document':'கிடைக்கும் ஆட்சேர்ப்பு ஆவணத்தைத் திறக்கவும்',
'Employer website ↗':'நிறுவனத்தின் இணையதளம் ↗','Deadline:':'கடைசி தேதி:',
'Verify the employer, job conditions and application link on the official source before sharing personal information or paying any fee. TAMILAN CAREERS does not guarantee recruitment.':'தனிப்பட்ட தகவல்களைப் பகிர்வதற்கு அல்லது கட்டணம் செலுத்துவதற்கு முன், அதிகாரப்பூர்வ மூலத்தில் நிறுவனம், வேலை நிபந்தனைகள் மற்றும் விண்ணப்ப இணைப்பைச் சரிபார்க்கவும். வேலை நியமனத்திற்கு TAMILAN CAREERS உத்தரவாதம் அளிக்காது.',
'No comments yet.':'இன்னும் கருத்துகள் இல்லை.','Post Comment':'கருத்தைப் பதிவிடவும்',
'Facebook':'Facebook','WhatsApp':'WhatsApp','Instagram':'Instagram','Copy Link':'இணைப்பை நகலெடுக்கவும்',
'Employer':'நிறுவனம்','Employment type':'பணி வகை','Workplace':'பணிமுறை','Salary':'சம்பளம்',
'Vacancies':'காலிப்பணியிடங்கள்','Education':'கல்வி','Qualification / Subjects':'கல்வித் தகுதி / பாடங்கள்',
'Application deadline':'விண்ணப்பிக்க கடைசி தேதி','Not specified':'குறிப்பிடப்படவில்லை','Not provided':'வழங்கப்படவில்லை',
'Application link unavailable':'விண்ணப்ப இணைப்பு கிடைக்கவில்லை','PDF not provided':'PDF வழங்கப்படவில்லை',
'Contact the employer through its official website':'அதிகாரப்பூர்வ இணையதளம் மூலம் நிறுவனத்தைத் தொடர்புகொள்ளவும்',
'Check the employer website for documents':'ஆவணங்களுக்கு நிறுவனத்தின் இணையதளத்தைப் பார்க்கவும்',
'Back to Home':'முகப்புக்குத் திரும்பு',
'TAMILAN CAREERS — Indian Private Job Application':'TAMILAN CAREERS — இந்தியத் தனியார் வேலைவாய்ப்பு விண்ணப்பம்',
'India-based private sector application':'இந்தியத் தனியார் துறை வேலைவாய்ப்பு விண்ணப்பம்',
'Dashboard':'டாஷ்போர்டு','Sign in required':'உள்நுழைவு அவசியம்',
'Job Seeker Sign in / Register':'வேலைதேடுபவர் உள்நுழைவு / பதிவு',
'Applicant Information':'விண்ணப்பதாரர் தகவல்கள்',
'Your saved Job Seeker profile will be attached to this application. Update your profile if any information is incorrect.':'உங்கள் வேலைதேடுபவர் சுயவிவரத் தகவல்கள் இந்த விண்ணப்பத்துடன் இணைக்கப்படும். தகவல்களில் தவறு இருந்தால் சுயவிவரத்தைப் புதுப்பிக்கவும்.',
'Edit My Profile':'எனது சுயவிவரத்தைத் திருத்தவும்',
'Indian Private Job Application Form':'தனியார் வேலைவாய்ப்பு விண்ணப்பப் படிவம்',
'Resume *':'சுயவிவரக் கோப்பு *','Select your uploaded resume':'பதிவேற்றிய சுயவிவரக் கோப்பைத் தேர்ந்தெடுக்கவும்',
'Notice period':'முன்னறிவிப்பு காலம்','Use profile value':'சுயவிவரத்தில் உள்ள மதிப்பைப் பயன்படுத்தவும்',
'Immediate':'உடனடியாக','15 days':'15 நாட்கள்','30 days':'30 நாட்கள்','60 days':'60 நாட்கள்','90 days':'90 நாட்கள்',
'Current city':'தற்போதைய நகரம்','Expected salary (INR)':'எதிர்பார்க்கும் சம்பளம் (ரூபாய்)',
'Willing to relocate within India?':'இந்தியாவிற்குள் வேறு இடத்திற்குச் செல்லத் தயாரா?',
'Yes':'ஆம்','No':'இல்லை','Depends on offer':'வேலை நிபந்தனையைப் பொறுத்தது',
'Employment availability':'பணியில் சேரும் காலம்','Within 15 days':'15 நாட்களுக்குள்','Within 30 days':'30 நாட்களுக்குள்','Within 60 days':'60 நாட்களுக்குள்','Other':'மற்றவை',
'Cover letter / Why are you suitable? *':'அறிமுகக் கடிதம் / இந்தப் பணிக்கு நீங்கள் ஏன் பொருத்தமானவர்? *',
'I confirm that the information provided is accurate and I consent to share this application with the employer for recruitment purposes.':'நான் வழங்கிய தகவல்கள் சரியானவை என்றும், ஆட்சேர்ப்பு நோக்கத்திற்காக இந்த விண்ணப்பத்தை நிறுவனத்துடன் பகிர ஒப்புக்கொள்கிறேன் என்றும் உறுதிப்படுத்துகிறேன்.',
'Submit Application':'விண்ணப்பத்தைச் சமர்ப்பிக்கவும்','Cancel':'ரத்துசெய்',
'Complete your Job Seeker profile before applying.':'விண்ணப்பிக்கும் முன் உங்கள் வேலைதேடுபவர் சுயவிவரத்தை முழுமைப்படுத்தவும்.',
'Please sign in with a Job Seeker account.':'வேலைதேடுபவர் கணக்கில் உள்நுழையவும்.',
'Job reference is missing.':'வேலைவாய்ப்பு குறிப்பு எண் கிடைக்கவில்லை.',
'This job is unavailable or no longer accepting applications.':'இந்த வேலைவாய்ப்பு கிடைக்கவில்லை அல்லது விண்ணப்பங்கள் ஏற்கப்படவில்லை.',
'Application submitted successfully. You can track its status in your Job Seeker Dashboard.':'விண்ணப்பம் வெற்றிகரமாகச் சமர்ப்பிக்கப்பட்டது. வேலைதேடுபவர் டாஷ்போர்டில் அதன் நிலையைப் பார்க்கலாம்.',
'You have already applied for this job.':'இந்த வேலைக்கு ஏற்கெனவே விண்ணப்பித்துள்ளீர்கள்.',
'Please sign in or register':'உள்நுழையவும் அல்லது பதிவு செய்யவும்',
'Apply Online':'இணையவழியில் விண்ணப்பிக்கவும்','Open the official application portal':'அதிகாரப்பூர்வ விண்ணப்ப இணையதளத்தைத் திறக்கவும்',
'View Official Notification PDF':'அதிகாரப்பூர்வ அறிவிப்பு PDF-ஐப் பார்க்கவும்',
'Official Website':'அதிகாரப்பூர்வ இணையதளம்','Previous':'முந்தையது','Next':'அடுத்தது',
'Expand':'விரிவாகப் பார்க்க','Collapse':'சுருக்கவும்','Page':'பக்கம்',
'No published jobs match the selected filters.':'தேர்ந்தெடுத்த வடிகட்டலுக்கு பொருந்தும் வேலைகள் இல்லை.',
'Not specified':'குறிப்பிடப்படவில்லை','Not provided':'வழங்கப்படவில்லை',
'Application link unavailable':'விண்ணப்ப இணைப்பு கிடைக்கவில்லை',
'Check the official recruitment website':'அதிகாரப்பூர்வ ஆட்சேர்ப்பு இணையதளத்தைப் பார்க்கவும்',
'Important: Read the official notification carefully and confirm eligibility, dates and application instructions on the recruiting authority website before applying.':'முக்கியம்: விண்ணப்பிக்கும் முன் அதிகாரப்பூர்வ அறிவிப்பைப் படித்து, தகுதி, தேதிகள் மற்றும் விண்ணப்ப வழிமுறைகளை ஆட்சேர்ப்பு நிறுவனத்தின் இணையதளத்தில் உறுதிப்படுத்தவும்.'
};
function isTamilNaduGovernment(job){const state=String(job?.state_name||'').trim().toLowerCase();const scope=String(job?.government_scope||'').trim().toLowerCase();return ['tamil nadu','tamilnadu','tn'].includes(state)&&(!scope||scope.includes('state'))}
function isTamilNaduPrivate(job){const value=String(job?.location||'').toLowerCase();return tamilNaduPlaces.some(p=>value.includes(p))}
async function loadApprovedTranslations(client,table,ids){
 const unique=[...new Set((ids||[]).filter(Boolean))];if(!unique.length)return {};
 const {data,error}=await client.from(table).select('job_id,translated_content').eq('translation_status','approved').in('job_id',unique);
 if(error){console.warn('Tamil translations unavailable:',error.message);return {}}
 return Object.fromEntries((data||[]).map(row=>[row.job_id,row.translated_content||{}]));
}
function value(translations,id,key,fallback){const v=translations?.[id]?.[key];return typeof v==='string'&&v.trim()?v:fallback}
function localizeStatic(root){
 if(!root)return;
 const walker=document.createTreeWalker(root,NodeFilter.SHOW_TEXT);
 const nodes=[];while(walker.nextNode())nodes.push(walker.currentNode);
 nodes.forEach(node=>{const key=node.nodeValue.trim();if(labels[key])node.nodeValue=node.nodeValue.replace(key,labels[key])});
 root.querySelectorAll('input[placeholder],button[aria-label],a[aria-label]').forEach(el=>{
  const attr=el.hasAttribute('placeholder')?'placeholder':'aria-label',v=el.getAttribute(attr);if(labels[v])el.setAttribute(attr,labels[v]);
 });
}
global.TCTamil={isTamilNaduGovernment,isTamilNaduPrivate,loadApprovedTranslations,value,localizeStatic,labels};
})(window);