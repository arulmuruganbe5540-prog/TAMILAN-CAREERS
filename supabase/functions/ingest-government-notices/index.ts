import { createClient } from "npm:@supabase/supabase-js@2";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });

const MAX_HTML_BYTES = 1_500_000;
const TIMEOUT_MS = 12_000;
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
function category(text: string) {
  if (/admit.?card|hall.?ticket|call.?letter/i.test(text)) return "admit_card";
  if (/result|merit.?list|selection.?list|short.?list/i.test(text)) return "result";
  if (/answer.?key|final.?key/i.test(text)) return "answer_key";
  if (/exam.?date|exam.?schedule|city.?intimation|timetable/i.test(text)) return "exam_update";
  if (/recruit|vacanc|advertisement|notification|apply|application/i.test(text)) return "recruitment";
  return "other";
}
function extractLinks(html: string, pageUrl: string, baseUrl: string) {
  const out = new Map<string, { title: string; url: string; category: string }>();
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
    const text = title + " " + url;
    if (!KEYWORDS.test(text) || GENERIC.test(title) || title.length < 5) continue;
    if (!out.has(url)) out.set(url, { title: title.slice(0, 240), url, category: category(text) });
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
    .eq("enabled", true);
  if (sourceError) return json({ error: "Could not load registered sources", detail: sourceError.message }, 500);

  const summary: Array<Record<string, unknown>> = [];
  let discovered = 0, inserted = 0, failed = 0;
  for (const source of sources || []) {
    try {
      const response = await fetch(source.base_url, {
        headers: { "user-agent": "TAMILAN-CAREERS-GovernmentNoticeMonitor/1.0" },
        signal: AbortSignal.timeout(TIMEOUT_MS),
        redirect: "follow",
      });
      if (!response.ok) throw new Error("HTTP " + response.status);
      const finalUrl = response.url || source.base_url;
      if (!hostAllowed(finalUrl, source.base_url)) throw new Error("Redirected outside registered host");
      const html = (await response.text()).slice(0, MAX_HTML_BYTES);
      const links = extractLinks(html, finalUrl, source.base_url);
      discovered += links.length;

      if (links.length) {
        const rows = links.map((item) => ({
          source_id: source.id,
          title: item.title,
          official_url: item.url,
          category: item.category,
          details: { authority: source.authority, state: source.state, scope: source.scope },
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
        }));
        const { data, error } = await admin.from("government_notice_reviews")
          .upsert(rows, { onConflict: "official_url", ignoreDuplicates: true })
          .select("id");
        if (error) throw new Error("Review queue insert failed: " + error.message);
        inserted += data?.length || 0;
      }
      await admin.from("government_notice_sources")
        .update({ last_checked_at: new Date().toISOString(), updated_at: new Date().toISOString() })
        .eq("id", source.id);
      summary.push({ source_id: source.id, status: response.status, candidates: links.length });
    } catch (error) {
      failed++;
      summary.push({ source_id: source.id, error: String(error).slice(0, 220) });
    }
  }

  return json({
    ok: true,
    registered_sources: sources?.length || 0,
    candidates_found: discovered,
    new_review_records: inserted,
    failed_sources: failed,
    published: 0,
    note: "Discovery only. This function never verifies notice facts or publishes. Every candidate remains private and pending until a trusted verification/publishing workflow is implemented.",
    sources: summary,
  });
});
