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