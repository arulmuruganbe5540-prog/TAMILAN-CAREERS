import { createClient } from "npm:@supabase/supabase-js@2";
const reply=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{"content-type":"application/json","cache-control":"no-store"}});
const KEYWORDS=/job|career|vacanc|recruit|position|opening|apply|employment|hiring/i;
const MAX_BYTES=1200000;
function clean(s:string){return s.replace(/<script[\s\S]*?<\/script>/gi," ").replace(/<style[\s\S]*?<\/style>/gi," ").replace(/<[^>]+>/g," ").replace(/&amp;/g,"&").replace(/&nbsp;/g," ").replace(/\s+/g," ").trim();}
async function readLimitedText(response:Response,limit:number){
 const reader=response.body?.getReader();if(!reader)return "";
 const decoder=new TextDecoder();let total=0,output="";
 try{
  while(true){
   const {done,value}=await reader.read();if(done)break;
   const remaining=limit-total;
   if(value.byteLength>remaining){output+=decoder.decode(value.subarray(0,remaining),{stream:true});total=limit;await reader.cancel().catch(()=>{});break;}
   output+=decoder.decode(value,{stream:true});total+=value.byteLength;
   if(total>=limit){await reader.cancel().catch(()=>{});break;}
  }
 }finally{output+=decoder.decode();reader.releaseLock();}
 return output;
}
function allowed(candidate:string,base:string){try{const a=new URL(candidate),b=new URL(base);return a.protocol==="https:"&&(a.hostname===b.hostname||a.hostname.endsWith("."+b.hostname));}catch{return false;}}
Deno.serve(async(req)=>{
 if(req.method!=="POST")return reply({error:"POST only"},405);
 const secret=Deno.env.get("GOVERNMENT_MONITOR_SECRET")||"";
 if(secret.length<24||req.headers.get("x-monitor-secret")!==secret)return reply({error:"Unauthorized"},401);
 const url=Deno.env.get("SUPABASE_URL"),key=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
 if(!url||!key)return reply({error:"Server configuration missing"},500);
 const db=createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});
 const {data:sources,error}=await db.from("external_job_sources").select("id,source_name,source_type,country,region,base_url,monitor_mode").eq("enabled",true).limit(100);
 if(error)return reply({error:error.message},500);
 const eligible=(sources||[]).filter(s=>s.monitor_mode==="public_page");
 let scanned=0,failed=0,discovered=0;const failures:string[]=[];const candidates:Record<string,unknown>[]=[];const sourceStatuses:{id:string;status:string}[]=[];
 for(let i=0;i<eligible.length;i+=5){
  const batch=eligible.slice(i,i+5);
  const results=await Promise.all(batch.map(async s=>{
   try{
    const r=await fetch(s.base_url,{headers:{"user-agent":"TAMILAN-CAREERS official job source monitor/1.0"},signal:AbortSignal.timeout(10000),redirect:"follow"});
    if(!r.ok)throw new Error("HTTP "+r.status);
    const contentType=(r.headers.get("content-type")||"").toLowerCase();if(contentType&&!/(text\/html|application\/xhtml\+xml)/i.test(contentType))throw new Error("Source did not return HTML");
    const final=r.url||s.base_url;if(!allowed(final,s.base_url))throw new Error("Redirect outside registered domain");
    const html=await readLimitedText(r,MAX_BYTES);const rows:Record<string,unknown>[]=[];
    const re=/<a\b([^>]*?)>([\s\S]*?)<\/a\s*>/gi;
    for(const m of html.matchAll(re)){
     const h=m[1].match(/\bhref\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/i);if(!h)continue;
     const label=clean(m[2]);if(!label||label.length<5||label.length>220||!KEYWORDS.test(label))continue;
     let target:URL;try{target=new URL(h[1]||h[2]||h[3],final);}catch{continue;}
     if(!allowed(target.toString(),s.base_url))continue;
     rows.push({source_id:s.id,title:label,official_url:target.toString(),country:s.country,region:s.region,source_type:s.source_type,discovery_context:"Link title discovered on "+final,verification:{source_domain_matched:true,original_notice_opened:false,dates_verified:false,eligibility_verified:false,application_link_verified:false,duplicate_checked:false},status:"pending"});
    }
    return {s,rows,error:null as string|null};
   }catch(e){return {s,rows:[],error:String(e).slice(0,180)};}
  }));
  for(const x of results){scanned++;sourceStatuses.push({id:x.s.id,status:x.error?"failed":"scanned"});if(x.error){failed++;failures.push(x.s.id+": "+x.error);continue;}discovered+=x.rows.length;candidates.push(...x.rows);}
 }
 const unique=new Map<string,Record<string,unknown>>();for(const c of candidates){const u=String(c.official_url);if(!unique.has(u))unique.set(u,c);}
 const selected=[...unique.values()].slice(0,100);
 let inserted=0;
 if(selected.length){const {data,error:e}=await db.from("external_job_candidates").upsert(selected,{onConflict:"official_url",ignoreDuplicates:true}).select("id");if(e)return reply({error:"Queue insert failed",detail:e.message},500);inserted=data?.length||0;}
 await Promise.all(sourceStatuses.map(s=>db.from("external_job_sources").update({last_checked_at:new Date().toISOString(),last_status:s.status}).eq("id",s.id)));
 return reply({ok:true,scanned_sources:scanned,failed_sources:failed,discovered_links:discovered,queued_new_candidates:inserted,manual_sources_skipped:(sources||[]).length-eligible.length,failures,published:0,note:"Discovery only; candidates are private and not published."});
});
