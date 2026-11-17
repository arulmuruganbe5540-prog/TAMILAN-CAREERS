import "jsr:@supabase/functions-js/edge-runtime.d.ts";
const headers={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS","Content-Type":"application/json"};
Deno.serve(async(req:Request)=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers});
 return new Response(JSON.stringify({error:"Paid AI mock-exam generation has been disabled. TAMILAN CAREERS now uses its built-in offline question bank."}),{status:410,headers});
});
