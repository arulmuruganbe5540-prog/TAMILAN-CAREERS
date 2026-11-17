import { createClient } from "npm:@supabase/supabase-js@2";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });

const MAX_REVIEW_RECORDS_PER_RUN = 15;
const MAX_INPUT_CANDIDATES = 2000;
const LOOKUP_BATCH_SIZE = 100;
const ALLOWED_CATEGORIES = new Set([
  "recruitment", "result", "admit_card", "answer_key", "exam_update", "other",
]);

function hostAllowed(candidate: string, base: string) {
  try {
    const a = new URL(candidate);
    const b = new URL(base);
    return a.protocol === "https:" &&
      (a.hostname === b.hostname || a.hostname.endsWith("." + b.hostname));
  } catch {
    return false;
  }
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
  if (!url || !serviceKey) {
    return json({ error: "Missing Supabase server configuration" }, 500);
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }
  if (!body || typeof body !== "object" || !Array.isArray((body as Record<string, unknown>).candidates)) {
    return json({ error: "Expected a candidates array from the official-source monitor" }, 400);
  }

  const input = (body as { candidates: unknown[] }).candidates;
  if (input.length > MAX_INPUT_CANDIDATES) {
    return json({ error: `Too many candidates; maximum is ${MAX_INPUT_CANDIDATES}` }, 413);
  }

  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: sources, error: sourceError } = await admin
    .from("government_notice_sources")
    .select("id,authority,scope,state,base_url")
    .eq("enabled", true);
  if (sourceError) {
    return json({ error: "Could not load registered sources", detail: sourceError.message }, 500);
  }

  const sourceMap = new Map((sources || []).map((source) => [source.id, source]));
  const uniqueRows = new Map<string, Record<string, unknown>>();
  const rejected: Array<{ index: number; reason: string }> = [];

  for (let index = 0; index < input.length; index++) {
    const candidate = input[index];
    if (!candidate || typeof candidate !== "object") {
      rejected.push({ index, reason: "Candidate must be an object" });
      continue;
    }
    const item = candidate as Record<string, unknown>;
    const sourceId = typeof item.source_id === "string" ? item.source_id : "";
    const source = sourceMap.get(sourceId);
    if (!source) {
      rejected.push({ index, reason: "Source is not in the enabled official-source registry" });
      continue;
    }
    const officialUrl = typeof item.official_url === "string" ? item.official_url.trim() : "";
    if (!officialUrl || !hostAllowed(officialUrl, source.base_url)) {
      rejected.push({ index, reason: "URL is not HTTPS on the registered official domain" });
      continue;
    }
    const title = typeof item.title === "string" ? item.title.replace(/\s+/g, " ").trim().slice(0, 240) : "";
    if (title.length < 5) {
      rejected.push({ index, reason: "Candidate title is missing or too short" });
      continue;
    }
    const hintedCategory = typeof item.category_hint === "string" ? item.category_hint : "other";
    const category = ALLOWED_CATEGORIES.has(hintedCategory) ? hintedCategory : "other";

    if (!uniqueRows.has(officialUrl)) {
      uniqueRows.set(officialUrl, {
        source_id: source.id,
        title,
        official_url: officialUrl,
        category,
        notice_date: null,
        details: {
          authority: source.authority,
          state: source.state,
          scope: source.scope,
          discovery_source: "github_official_source_monitor",
          discovered_at_utc: typeof item.discovered_at_utc === "string" ? item.discovered_at_utc : null,
          warning: "Discovery candidate only. Open the official notice and verify every fact before publication.",
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

  const candidates = [...uniqueRows.values()];
  const existingUrls = new Set<string>();
  const urls = candidates.map((row) => String(row.official_url));
  for (let offset = 0; offset < urls.length; offset += LOOKUP_BATCH_SIZE) {
    const batch = urls.slice(offset, offset + LOOKUP_BATCH_SIZE);
    const { data, error } = await admin
      .from("government_notice_reviews")
      .select("official_url")
      .in("official_url", batch);
    if (error) {
      return json({ error: "Could not check duplicate review candidates", detail: error.message }, 500);
    }
    for (const row of data || []) existingUrls.add(row.official_url);
  }

  const selectedRows = candidates
    .filter((row) => !existingUrls.has(String(row.official_url)))
    .slice(0, MAX_REVIEW_RECORDS_PER_RUN);

  let inserted = 0;
  if (selectedRows.length) {
    const { data, error } = await admin
      .from("government_notice_reviews")
      .upsert(selectedRows, { onConflict: "official_url", ignoreDuplicates: true })
      .select("id");
    if (error) {
      return json({ error: "Review queue insert failed", detail: error.message }, 500);
    }
    inserted = data?.length || 0;
  }

  const usedSourceIds = [...new Set(selectedRows.map((row) => String(row.source_id)))];
  if (usedSourceIds.length) {
    const { error } = await admin
      .from("government_notice_sources")
      .update({ last_checked_at: new Date().toISOString(), updated_at: new Date().toISOString() })
      .in("id", usedSourceIds);
    if (error) {
      return json({ error: "Review queue synced but source timestamps could not be updated", detail: error.message }, 500);
    }
  }

  return json({
    ok: true,
    registered_sources: sources?.length || 0,
    received_candidates: input.length,
    valid_unique_candidates: candidates.length,
    already_in_review_queue: existingUrls.size,
    selected_for_review: selectedRows.length,
    new_review_records: inserted,
    rejected_candidates: rejected.length,
    rejected_details: rejected.slice(0, 25),
    published: 0,
    note: "Candidates are discovery hints only. No vacancy facts are certified and nothing is auto-published. Admin verification is required.",
  });
});
