import { createClient } from "npm:@supabase/supabase-js@2";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });

const MAX_HTML_BYTES = 1_500_000;
const TIMEOUT_MS = 12_000;
const MAX_WORKERS = 8;
const MAX_REVIEW_RECORDS_PER_RUN = 15;
const KEYWORDS = /recruit|vacanc|advertisement|notification|career|apply|application|result|merit.?list|answer.?key|admit.?card|hall.?ticket|exam.?date|exam.?schedule|selection.?list|short.?list|call.?letter/i;
const GENERIC = /^(home|careers?|career opportunities|recruitment|recruitment exams?|view all|read more|click here|results?|notifications?|what's new|latest news|menu|more)$/i;

function decode(value: string) {
  return value.replace(/&amp;/gi, "&").replace(/&quot;/gi, '"')
    .replace(/&#39;|&apos;/gi, "'").replace(/&lt;/gi, "<").replace(/&gt;/gi, ">");
}
function hostAllowed(candidate: string, base: string) {
  try {
    const a = new URL(candidate), b = new URL(base);
    return a.protocol === "https:" && (a.hostname === b.hostname || a.hostname.endsWith("." + b.hostname));
  } catch { return false; }
}

async function fetchRegisteredPage(baseUrl: string) {
  let current = baseUrl;
  for (let hop = 0; hop <= 5; hop++) {
    if (!hostAllowed(current, baseUrl)) throw new Error("Redirect outside registered HTTPS domain");
    const response = await fetch(current, {
      headers: { "user-agent": "TAMILAN-CAREERS-GovernmentNoticeMonitor/1.0" },
      signal: AbortSignal.timeout(TIMEOUT_MS),
      redirect: "manual",
    });
    if ([301, 302, 303, 307, 308].includes(response.status)) {
      const location = response.headers.get("location");
      await response.body?.cancel().catch(() => {});
      if (!location) throw new Error("Redirect response missing Location");
      if (hop === 5) throw new Error("Too many redirects");
      current = new URL(location, current).toString();
      continue;
    }
    return response;
  }
  throw new Error("Too many redirects");
}

async function readLimitedText(response: Response, limit: number) {
  const reader = response.body?.getReader();
  if (!reader) return "";
  const decoder = new TextDecoder();
  let total = 0;
  let output = "";
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      const remaining = limit - total;
      if (value.byteLength > remaining) {
        output += decoder.decode(value.subarray(0, remaining), { stream: true });
        total = limit;
        await reader.cancel().catch(() => {});
        break;
      }
      output += decoder.decode(value, { stream: true });
      total += value.byteLength;
      if (total >= limit) {
        await reader.cancel().catch(() => {});
        break;
      }
    }
  } finally {
    output += decoder.decode();
    reader.releaseLock();
  }
  return output;
}
function robotsAllows(text:string,pageUrl:string,userAgent:string){
 const groups:{agents:string[];rules:{allow:boolean;path:string}[]}[]=[];
 let agents:string[]=[],rules:{allow:boolean;path:string}[]=[];
 for(const raw of text.split("\n")){
  const line=raw.split("#",1)[0].trim();if(!line)continue;
  const lower=line.toLowerCase();
  if(lower.startsWith("user-agent:")){
   if(rules.length){groups.push({agents,rules});agents=[];rules=[];}
   agents.push(line.slice(line.indexOf(":")+1).trim().toLowerCase());continue;
  }
  const colon=line.indexOf(":");if(colon<0||!agents.length)continue;
  const directive=line.slice(0,colon).trim().toLowerCase();
  if(directive!=="allow"&&directive!=="disallow")continue;
  const path=line.slice(colon+1).trim();if(path)rules.push({allow:directive==="allow",path});
 }
 if(agents.length)groups.push({agents,rules});
 const token=userAgent.split(" ")[0].toLowerCase();
 const specific=groups.filter(g=>g.agents.some(a=>a!=="*"&&token.includes(a)));
 const applicable=specific.length?specific:groups.filter(g=>g.agents.includes("*"));
 const allRules=applicable.flatMap(g=>g.rules);
 const parsed=new URL(pageUrl),requestPath=parsed.pathname+parsed.search;
 const matches=allRules.filter(r=>{
  const prefix=r.path.split("*")[0];
  return prefix.length>0&&requestPath.startsWith(prefix);
 }).sort((a,b)=>b.path.length-a.path.length);
 return !matches.length||matches[0].allow;
}
async function robotsPermits(pageUrl: string, userAgent: string) {
  try {
    const robotsUrl = new URL("/robots.txt", pageUrl).toString();
    const response = await fetchRegisteredPage(robotsUrl);
    if (response.status === 404 || response.status === 410) return true;
    if (!response.ok) return false;
    const contentType = (response.headers.get("content-type") || "").toLowerCase();
    if (contentType && !/(text\/plain|application\/octet-stream)/i.test(contentType)) return false;
    const body = await readLimitedText(response, 256_000);
    return robotsAllows(body, pageUrl, userAgent);
  } catch {
    return false;
  }
}
function category(text: string) {
  if (/admit.?card|hall.?ticket|call.?letter/i.test(text)) return "admit_card";
  if (/result|merit.?list|selection.?list|short.?list/i.test(text)) return "result";
  if (/answer.?key|final.?key/i.test(text)) return "answer_key";
  if (/exam.?date|exam.?schedule|city.?intimation|timetable/i.test(text)) return "exam_update";
  if (/recruit|vacanc|advertisement|notification|apply|application/i.test(text)) return "recruitment";
  return "other";
}
function extractLinks(html: string, pageUrl: string, baseUrl: string) {
  const out = new Map<string, { title: string; url: string; category: string; noticeDateHint: string | null; context: string }>();
  const anchor = /<a\b([^>]*?)>([\s\S]*?)<\/a\s*>/gi;
  for (const match of html.matchAll(anchor)) {
    const attrs = match[1];
    const hrefMatch = attrs.match(/\bhref\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/i);
    if (!hrefMatch) continue;
    const href = decode(hrefMatch[1] || hrefMatch[2] || hrefMatch[3] || "").trim();
    if (!href || /^(#|javascript:|mailto:|tel:)/i.test(href)) continue;
    let url: string;
    try {
      const parsed = new URL(href, pageUrl);
      parsed.hash = "";
      url = parsed.toString();
    } catch { continue; }
    if (!hostAllowed(url, baseUrl)) continue;
    const rawTitle = match[2].replace(/<script[\s\S]*?<\/script>/gi, " ")
      .replace(/<style[\s\S]*?<\/style>/gi, " ").replace(/<[^>]+>/g, " ");
    const title = decode(rawTitle).replace(/\s+/g, " ").trim();
    const index = match.index ?? 0;
    const rowStart = html.lastIndexOf("<tr", index);
    const rowEnd = html.indexOf("</tr>", index);
    const listStart = html.lastIndexOf("<li", index);
    const listEnd = html.indexOf("</li>", index);
    let contextHtml = "";
    if (rowStart >= 0 && rowEnd >= index) contextHtml = html.slice(rowStart, rowEnd + 5);
    else if (listStart >= 0 && listEnd >= index) contextHtml = html.slice(listStart, listEnd + 5);
    const context = decode(contextHtml.replace(/<script[\s\S]*?<\/script>/gi, " ")
      .replace(/<style[\s\S]*?<\/style>/gi, " ").replace(/<[^>]+>/g, " "))
      .replace(/\s+/g, " ").trim().slice(0, 1200);
    const displayTitle = title.length >= 5 && !GENERIC.test(title) ? title : context.slice(0, 240);
    const text = displayTitle + " " + context + " " + url;
    if (!KEYWORDS.test(text) || displayTitle.length < 5) continue;
    const dateMatch = context.match(/\b(0?[1-9]|[12]\d|3[01])[/. -](0?[1-9]|1[0-2])[/. -](20\d{2})\b/);
    const noticeDateHint = dateMatch ? dateMatch[3] + "-" + dateMatch[2].padStart(2,"0") + "-" + dateMatch[1].padStart(2,"0") : null;
    if (!out.has(url)) out.set(url, { title: displayTitle.slice(0, 240), url, category: category(text), noticeDateHint, context });
  }
  return [...out.values()];
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  const expected = Deno.env.get("GOVERNMENT_MONITOR_SECRET");
  const supplied = req.headers.get("x-monitor-secret") || "";
  if (!expected || supplied.length < 24 || supplied !== expected) {
    return json({ error: "Unauthorized monitor request" }, 401);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return json({ error: "Missing Supabase server configuration" }, 500);

  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: sources, error: sourceError } = await admin
    .from("government_notice_sources")
    .select("id,authority,scope,state,base_url")
    .eq("enabled", true)
    .order("id");
  if (sourceError) return json({ error: "Could not load registered sources", detail: sourceError.message }, 500);

  const sourceList = sources || [];
  const successful: Array<{ source: typeof sourceList[number]; status: number }> = [];
  const failedSources: Array<{ source_id: string; error: string }> = [];
  const candidateRows: Array<Record<string, unknown>> = [];
  let discovered = 0;

  // Scan in parallel batches to stay within Edge Function execution limits.
  for (let offset = 0; offset < sourceList.length; offset += MAX_WORKERS) {
    const batch = sourceList.slice(offset, offset + MAX_WORKERS);
    const results = await Promise.all(batch.map(async (source) => {
      try {
        const userAgent = "TAMILAN-CAREERS-GovernmentNoticeMonitor/1.0";
        if (!(await robotsPermits(source.base_url, userAgent))) throw new Error("robots.txt disallows this page or could not be checked safely");
        const response = await fetchRegisteredPage(source.base_url);
        if (!response.ok) throw new Error("HTTP " + response.status);
        const contentType = (response.headers.get("content-type") || "").toLowerCase();
        if (!/(text\/html|application\/xhtml\+xml)/i.test(contentType)) {
          throw new Error("Source did not return an HTML content type");
        }
        const finalUrl = response.url || source.base_url;
        if (!hostAllowed(finalUrl, source.base_url)) throw new Error("Redirected outside registered HTTPS domain");
        if (!(await robotsPermits(finalUrl, userAgent))) throw new Error("robots.txt disallows the redirected page or could not be checked safely");
        const html = await readLimitedText(response, MAX_HTML_BYTES);
        const links = extractLinks(html, finalUrl, source.base_url);
        return { source, status: response.status, links, error: null as string | null };
      } catch (error) {
        return { source, status: 0, links: [], error: String(error).slice(0, 220) };
      }
    }));

    for (const result of results) {
      if (result.error) {
        failedSources.push({ source_id: result.source.id, error: result.error });
        continue;
      }
      successful.push({ source: result.source, status: result.status });
      discovered += result.links.length;
      for (const item of result.links) {
        // Recruitment, admit cards, results, answer keys and exam updates enter Admin Review.
        // The category is only a discovery hint; the Admin must verify the official document and date.
        candidateRows.push({
          source_id: result.source.id,
          title: item.title,
          official_url: item.url,
          category: item.category,
          notice_date: item.noticeDateHint,
          details: {
            authority: result.source.authority,
            state: result.source.state,
            scope: result.source.scope,
            discovery_context: item.context,
            notice_date_hint: item.noticeDateHint,
          },
          verification: {
            registered_source_host: true,
            notice_document_opened: false,
            dates_verified: false,
            vacancies_verified: false,
            eligibility_verified: false,
            application_link_verified: false,
            duplicate_checked: false,
          },
          status: "pending",
        });
      }
    }
  }

  // Deduplicate across source pages and cap the complete run at 15 review candidates.
  const uniqueRows = new Map<string, Record<string, unknown>>();
  for (const row of candidateRows) {
    const key = String(row.official_url);
    if (!uniqueRows.has(key)) uniqueRows.set(key, row);
  }
  const selectedRows = [...uniqueRows.values()].slice(0, MAX_REVIEW_RECORDS_PER_RUN);

  let inserted = 0;
  if (selectedRows.length) {
    const { data, error } = await admin.from("government_notice_reviews")
      .upsert(selectedRows, { onConflict: "official_url", ignoreDuplicates: true })
      .select("id");
    if (error) return json({ error: "Review queue insert failed", detail: error.message }, 500);
    inserted = data?.length || 0;
  }

  await Promise.all(successful.map(({ source }) =>
    admin.from("government_notice_sources")
      .update({ last_checked_at: new Date().toISOString(), updated_at: new Date().toISOString() })
      .eq("id", source.id)
  ));

  return json({
    ok: true,
    registered_sources: sourceList.length,
    successful_sources: successful.length,
    failed_sources: failedSources.length,
    failed_source_details: failedSources,
    candidates_found: discovered,
    recruitment_candidates_eligible: uniqueRows.size,
    review_limit_per_run: MAX_REVIEW_RECORDS_PER_RUN,
    new_review_records: inserted,
    published: 0,
    note: "Discovery only. At most 15 government notice candidates across recruitment, admit cards, results, answer keys and exam updates are queued per run. Category is an unverified hint; no facts are certified and no notice is auto-published.",
  });
});
