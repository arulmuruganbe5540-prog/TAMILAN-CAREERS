const headers={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS","Content-Type":"application/json","Cache-Control":"no-store"};
Deno.serve(async(req:Request)=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers});
 if(req.method!=="POST")return new Response(JSON.stringify({error:"POST only"}),{status:405,headers});
 return new Response(JSON.stringify({error:"This feature has been disabled. TAMILAN CAREERS does not use AI.",feature:"AI resume matching"}),{status:410,headers});
});
