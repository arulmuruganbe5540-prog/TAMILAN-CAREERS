// Dependency-injected HTTP handler for TAMILAN AI read-only job context.
// Kept separate from Deno.serve so request behavior can be tested without deployment.
import { MAX_RESULTS, parseRetrievalInput, publicJobSource, rateLimitDecision } from "./logic.ts";

const ALLOWED_ORIGINS = new Set(["https://tamilancareers.in", "https://www.tamilancareers.in"]);

type QueryResult = { data: Array<Record<string, unknown>> | null; error: unknown };
export interface JobQuery extends PromiseLike<QueryResult> {
  eq(column: string, value: string): JobQuery;
  order(column: string, options: { ascending: boolean; nullsFirst: boolean }): JobQuery;
  limit(count: number): JobQuery;
  ilike(column: string, pattern: string): JobQuery;
}
export interface RetrievalClient {
  rpc(name: string): PromiseLike<{ data: unknown; error: unknown }>;
  from(table: string): { select(columns: string): JobQuery };
}
export type ClientFactory = (url: string, anonKey: string, authorization: string) => RetrievalClient;
export type EnvironmentReader = (name: string) => string | undefined;

function responseHeaders(origin: string | null, retryAfter?: number): Headers {
  const headers = new Headers({ "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store", "Vary": "Origin" });
  if (origin && ALLOWED_ORIGINS.has(origin)) {
    headers.set("Access-Control-Allow-Origin", origin);
    headers.set("Access-Control-Allow-Headers", "authorization, apikey, x-client-info, content-type");
    headers.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  }
  if (retryAfter !== undefined) headers.set("Retry-After", String(retryAfter));
  return headers;
}
function json(data: unknown, status: number, origin: string | null, retryAfter?: number): Response {
  return new Response(JSON.stringify(data), { status, headers: responseHeaders(origin, retryAfter) });
}

export function createJobContextHandler(env: EnvironmentReader, makeClient: ClientFactory) {
  return async (request: Request): Promise<Response> => {
    const origin = request.headers.get("origin");
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: responseHeaders(origin) });
    if (request.method !== "POST") return json({ error: "POST only" }, 405, origin);
    if (origin && !ALLOWED_ORIGINS.has(origin)) return json({ error: "Origin not allowed" }, 403, origin);
    if (env("TAMILAN_AI_RETRIEVAL_ENABLED") !== "true") {
      return json({ error: "TAMILAN AI job context is not enabled", code: "FEATURE_DISABLED" }, 503, origin);
    }
    const authorization = request.headers.get("authorization");
    if (!authorization?.startsWith("Bearer ")) return json({ error: "Login required" }, 401, origin);
    const declaredLength = Number(request.headers.get("content-length") ?? "0");
    if (declaredLength > 2048) return json({ error: "Request body too large" }, 413, origin);
    let body: unknown;
    try {
      const rawBody = await request.text();
      if (rawBody.length > 2048) return json({ error: "Request body too large" }, 413, origin);
      body = JSON.parse(rawBody);
    } catch {
      return json({ error: "Invalid JSON body" }, 400, origin);
    }
    const parsedInput = parseRetrievalInput(body);
    if (!parsedInput.ok) return json({ error: parsedInput.error }, 400, origin);
    const { query, country } = parsedInput.value;

    const supabaseUrl = env("SUPABASE_URL");
    const anonKey = env("SUPABASE_ANON_KEY");
    if (!supabaseUrl || !anonKey) return json({ error: "Public Supabase configuration is missing" }, 503, origin);

    // Caller JWT + anon key only. No service-role key is accepted by this boundary.
    const supabase = makeClient(supabaseUrl, anonKey, authorization);
    const { data: quotaData, error: quotaError } = await supabase.rpc("tamilan_ai_consume_job_context_quota");
    const quota = rateLimitDecision(quotaData);
    if (quotaError || !quota) {
      return json({ error: "Usage control is temporarily unavailable", code: "RATE_LIMIT_CHECK_FAILED" }, 503, origin);
    }
    if (!quota.allowed) {
      return json({ error: "AI job search limit reached. Please try again later.", code: "RATE_LIMITED" },
        429, origin, quota.retryAfterSeconds);
    }

    let builder = supabase.from("jobs").select([
      "id", "job_title", "description", "location", "country_name",
      "employment_type", "workplace_type", "education_level", "required_skills",
      "experience_min", "experience_max", "salary_min", "salary_max",
      "salary_currency", "salary_period", "application_deadline", "published_at",
      "official_website_url", "official_notification_url",
    ].join(",")).eq("status", "published")
      .order("published_at", { ascending: false, nullsFirst: false }).limit(MAX_RESULTS);
    if (query) builder = builder.ilike("job_title", "%" + query + "%");
    if (country) builder = builder.ilike("country_name", country);
    const { data, error } = await builder;
    if (error) return json({ error: "Verified public job retrieval failed" }, 502, origin);

    const rows = data ?? [];
    const sources = rows.map((row) => publicJobSource(row))
      .filter((row): row is NonNullable<typeof row> => row !== null);
    return json({
      status: sources.length ? "sources_found" : "no_verified_public_jobs",
      count: sources.length,
      sources,
      safety: {
        generated_job_facts: false,
        private_candidate_data_used: false,
        source_ids_required_for_job_claims: true,
        job_text_is_untrusted_input: true,
        note: sources.length
          ? "Only these returned published job records may support vacancy-specific answers."
          : "No matching published public job records were returned. Do not invent vacancies, counts, salaries or employers.",
      },
    }, 200, origin);
  };
}
