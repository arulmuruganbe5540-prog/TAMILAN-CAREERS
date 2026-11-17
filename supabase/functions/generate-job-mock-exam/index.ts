import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS","Content-Type":"application/json"};
const reply=(status:number,body:Record<string,unknown>)=>new Response(JSON.stringify(body),{status,headers:cors});
Deno.serve(async(req:Request)=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
 if(req.method!=="POST")return reply(405,{error:"POST only"});
 try{
  const url=Deno.env.get("SUPABASE_URL")!,anon=Deno.env.get("SUPABASE_ANON_KEY")!,serviceKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const token=req.headers.get("Authorization")||"";if(!token.startsWith("Bearer "))return reply(401,{error:"Login required"});
  const userClient=createClient(url,anon,{global:{headers:{Authorization:token}}});
  const {data:{user},error:userError}=await userClient.auth.getUser();if(userError||!user)return reply(401,{error:"Please sign in"});
  const {job_id,question_count=15,difficulty="mixed",language="ta"}=await req.json();
  if(!job_id||!Number.isInteger(question_count)||question_count<5||question_count>50)return reply(400,{error:"Valid job_id and 5–50 questions required"});
  if(!["easy","medium","hard","mixed"].includes(difficulty))return reply(400,{error:"Invalid difficulty"});
  const admin=createClient(url,serviceKey);
  const {data:job,error:jobError}=await admin.from("jobs").select("id,job_title,description,education_level,required_skills,job_kind,recruitment_authority,selection_process,notification_number,status").eq("id",job_id).eq("status","published").maybeSingle();
  if(jobError||!job)return reply(404,{error:"Published job not found"});
  if(job.job_kind!=="government")return reply(400,{error:"Exam practice is currently enabled for government jobs"});
  const {data:resources}=await admin.from("job_exam_resources").select("resource_type,title,description,resource_year,exam_stage").eq("job_id",job_id).eq("status","published").in("resource_type",["syllabus","previous_paper","mock_test"]).limit(30);
  const apiKey=Deno.env.get("OPENAI_API_KEY");if(!apiKey)return reply(503,{error:"AI question generation is not configured yet. Super Admin must add OPENAI_API_KEY in Supabase Edge Function secrets. You do not need to share the key in chat."});
  const context=(resources||[]).map((r:any)=>({type:r.resource_type,title:r.title,description:r.description,year:r.resource_year,stage:r.exam_stage}));
  const prompt=`Create an original practice mock exam for this government recruitment post. This is NOT an official paper. Do not claim questions are from previous official papers. Use the supplied post details and syllabus/resource context. If no exact syllabus is supplied, create a general aptitude practice paper suitable for the post and clearly avoid asserting exact official exam pattern. Return exactly ${question_count} multiple-choice questions. Language: ${language==="ta"?"Tamil (retain standard English technical terms in brackets where useful)":"English"}. Difficulty: ${difficulty}. Job: ${JSON.stringify(job)} Syllabus/resources: ${JSON.stringify(context)} Return JSON object: {"questions":[{"question":"...","options":["A","B","C","D"],"correct_index":0,"explanation":"...","topic":"...","difficulty":"easy|medium|hard"}]}. correct_index is 0-based. Exactly four options per question. Do not include markdown.`;
  const ai=await fetch("https://api.openai.com/v1/chat/completions",{method:"POST",headers:{"Authorization":`Bearer ${apiKey}`,"Content-Type":"application/json"},body:JSON.stringify({model:"gpt-4o-mini",temperature:0.35,response_format:{type:"json_object"},messages:[{role:"system",content:"You create accurate educational mock questions. Never represent generated content as official."},{role:"user",content:prompt}]})});
  if(!ai.ok){const t=await ai.text();return reply(ai.status===429?503:502,{error:ai.status===429?"AI API quota or billing limit reached. Add API credits and try again.":"AI generation failed",detail:t.slice(0,500)});}
  const payload=await ai.json(),parsed=JSON.parse(payload.choices?.[0]?.message?.content||"{}"),questions=Array.isArray(parsed.questions)?parsed.questions.slice(0,question_count):[];
  if(questions.length!==question_count||questions.some((q:any)=>!q.question||!Array.isArray(q.options)||q.options.length!==4||!Number.isInteger(q.correct_index)||q.correct_index<0||q.correct_index>3))return reply(502,{error:"AI returned an invalid question set. Please retry."});
  const {data:row,error:saveError}=await admin.from("job_exam_question_sets").insert({job_id,created_by:user.id,title:job.job_title+" — AI மாதிரித் தேர்வு",language,difficulty,question_count:questions.length,questions,generation_model:"gpt-4o-mini"}).select("id,title,question_count,questions,disclaimer,created_at").single();
  if(saveError)return reply(500,{error:"Could not save generated practice test"});
  return reply(200,{question_set:row});
 }catch(e){return reply(500,{error:"Unexpected exam generation error",detail:String(e).slice(0,300)});}
});