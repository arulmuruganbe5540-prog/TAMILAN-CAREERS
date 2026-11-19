// TAMILAN AI read-only job context endpoint.
// This is intentionally fail-closed and is NOT deployed or enabled by this commit.
// Supabase platform JWT verification must remain enabled for this function.
import { createClient } from "npm:@supabase/supabase-js@2";
import {
  MAX_RESULTS,
  normalizeCountry,
  normalizeSearchQuery,
  publicJobSource,
} from "./logic.ts";

const ALLOWED_ORIGINS = new Set([
  "https://tamilancareers.in",
  "https://www.tamilancareers.in",
]);

function responseHeaders(origin: string | null): Headers {
  const headers = new Headers({
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
    "Vary": "Origin",
  });
  if (origin && ALLOWED_ORIGINS.has(origin)) {
    headers.set("Access-Control-Allow-Origin", origin);
    headers.set("Access-Control-Allow-Headers", "authorization, apikey, x-client-info, content-type");
    headers.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  }
  return headers;
}

function json(data: unknown, status: number, origin: string | null): Response {
  return new Response(JSON.stringify(data), { status, headers: responseHeaders(origin) });
}

Deno.serve(async (request: Request) => {
  const origin = request.headers.get("origin");
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: responseHeaders(origin) });
  }
  if (request.method !== "POST") {
    return json({ error: "POST only" }, 405, origin);
  }
  if (origin && !ALLOWED_ORIGINS.has(origin)) {
    return json({ error: "Origin not allowed" }, 403, origin);
  }

  // Default OFF. Do not set this until authentication, rate limiting, privacy,
  // model adapter and runtime tests have been reviewed and approved.
  if (Deno.env.get("TAMILAN_AI_RETRIEVAL_ENABLED") !== "true") {
    return json({ error: "TAMILAN AI job context is not enabled", code: "FEATURE_DISABLED" }, 503, origin);
  }

  const authorization = request.headers.get("authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return json({ error: "Login required" }, 401, origin);
  }

  const declaredLength = Number(request.headers.get("content-length") ?? "0");
  if (declaredLength > 2048) {
    return json({ error: "Request body too large" }, 413, origin);
  }
  let body: unknown;
  try {
    const rawBody = await request.text();
    if (rawBody.length > 2048) {
      return json({ error: "Request body too large" }, 413, origin);
    }
    body = JSON.parse(rawBody);
  } catch {
    return json({ error: "Invalid JSON body" }, 400, origin);
  }
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return json({ error: "JSON object required" }, 400, origin);
  }
  const input = body as Record<string, unknown>;
  const query = normalizeSearchQuery(input.query);
  if (query === null) {
    return json({ error: "query must be plain text up to 80 characters" }, 400, origin);
  }
  const country = normalizeCountry(input.country);
  if (country === null) {
    return json({ error: "country must be plain text up to 100 characters" }, 400, origin);
  }
  const allowedKeys = new Set(["query", "country"]);
  if (Object.keys(input).some((key) => !allowedKeys.has(key))) {
    return json({ error: "Unsupported request field" }, 400, origin);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !anonKey) {
    return json({ error: "Public Supabase configuration is missing" }, 503, origin);
  }

  // Use the publishable/anon key plus the caller's JWT. Never use service_role.
  // This keeps the existing jobs SELECT RLS policy in force.
  const supabase = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });

  let builder = supabase
    .from("jobs")
    .select([
      "id", "job_title", "description", "location", "country_name",
      "employment_type", "workplace_type", "education_level", "required_skills",
      "experience_min", "experience_max", "salary_min", "salary_max",
      "salary_currency", "salary_period", "application_deadline", "published_at",
      "official_website_url", "official_notification_url",
    ].join(","))
    .eq("status", "published")
    .order("published_at", { ascending: false, nullsFirst: false })
    .limit(MAX_RESULTS);

  if (query) builder = builder.ilike("job_title", `%${query}%`);
  if (country) builder = builder.ilike("country_name", country);

  const { data, error } = await builder;
  if (error) {
    return json({ error: "Verified public job retrieval failed" }, 502, origin);
  }

  const rows = (data ?? []) as unknown as Array<Record<string, unknown>>;
  const sources = rows
    .map((row) => publicJobSource(row))
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
});
