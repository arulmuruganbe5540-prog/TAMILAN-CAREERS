import { createJobContextHandler, type JobQuery, type RetrievalClient } from "./handler.ts";

function assert(condition: unknown, message: string) {
  if (!condition) throw new Error(message);
}
function equal(actual: unknown, expected: unknown, message: string) {
  if (actual !== expected) throw new Error(message + ": expected " + String(expected) + ", got " + String(actual));
}
type FakeOptions = {
  enabled?: string;
  quota?: unknown;
  quotaError?: unknown;
  rows?: Array<Record<string, unknown>>;
  queryError?: unknown;
  missingConfig?: boolean;
};
function harness(options: FakeOptions = {}) {
  const calls: string[] = [];
  const env = (name: string) => {
    if (name === "TAMILAN_AI_RETRIEVAL_ENABLED") return options.enabled ?? "true";
    if (name === "SUPABASE_URL") return options.missingConfig ? undefined : "https://project.supabase.co";
    if (name === "SUPABASE_ANON_KEY") return options.missingConfig ? undefined : "public-anon-key";
    return undefined;
  };
  const makeClient = (_url: string, _key: string, authorization: string): RetrievalClient => {
    calls.push("client:" + authorization);
    return {
      rpc: async (name: string) => {
        calls.push("rpc:" + name);
        return { data: options.quota ?? { allowed: true }, error: options.quotaError ?? null };
      },
      from: (table: string) => {
        calls.push("from:" + table);
        return {
          select: (columns: string) => {
            calls.push("select:" + columns);
            const query = {
              eq(column: string, value: string) { calls.push("eq:" + column + "=" + value); return query; },
              order(column: string, _opts: { ascending: boolean; nullsFirst: boolean }) { calls.push("order:" + column); return query; },
              limit(count: number) { calls.push("limit:" + count); return query; },
              ilike(column: string, value: string) { calls.push("ilike:" + column + "=" + value); return query; },
              then(resolve: (value: {data: Array<Record<string, unknown>> | null; error: unknown}) => unknown, reject?: (reason: unknown) => unknown) {
                return Promise.resolve({ data: options.rows ?? [], error: options.queryError ?? null }).then(resolve, reject);
              },
            };
            return query as unknown as JobQuery;
          },
        };
      },
    };
  };
  return { handler: createJobContextHandler(env, makeClient), calls };
}
function post(body: string, headers: Record<string, string> = {}) {
  return new Request("https://example.test", {
    method: "POST",
    headers: { authorization: "Bearer test-user-jwt", "content-type": "application/json", ...headers },
    body,
  });
}

Deno.test("HTTP contract: OPTIONS returns only the approved CORS origin", async () => {
  const { handler, calls } = harness();
  const response = await handler(new Request("https://example.test", { method: "OPTIONS", headers: { origin: "https://tamilancareers.in" } }));
  equal(response.status, 204, "preflight status");
  equal(response.headers.get("Access-Control-Allow-Origin"), "https://tamilancareers.in", "CORS allow origin");
  equal(calls.length, 0, "no client before request");
});
Deno.test("HTTP contract: unsupported method and origin are rejected", async () => {
  const { handler } = harness();
  equal((await handler(new Request("https://example.test", { method: "GET" }))).status, 405, "GET");
  equal((await handler(post("{}", { origin: "https://evil.example" }))).status, 403, "unapproved origin");
});
Deno.test("HTTP contract: feature flag defaults closed and requires a bearer token", async () => {
  const disabled = harness({ enabled: "false" });
  const disabledResponse = await disabled.handler(post("{}"));
  equal(disabledResponse.status, 503, "disabled status");
  equal((await disabledResponse.json()).code, "FEATURE_DISABLED", "disabled code");
  equal(disabled.calls.length, 0, "disabled does not create client");
  const enabled = harness();
  equal((await enabled.handler(new Request("https://example.test", { method: "POST", body: "{}" }))).status, 401, "missing bearer");
});
Deno.test("HTTP contract: invalid JSON, extra fields, oversized body and missing public config fail closed", async () => {
  const h = harness();
  equal((await h.handler(post("{"))).status, 400, "invalid JSON");
  equal((await h.handler(post(JSON.stringify({ admin: true })))).status, 400, "extra field");
  equal((await h.handler(post("x".repeat(2049)))).status, 413, "oversized body");
  equal((await harness({ missingConfig: true }).handler(post("{}"))).status, 503, "missing config");
});
Deno.test("HTTP contract: quota errors and malformed quota data fail closed before jobs query", async () => {
  const failed = harness({ quotaError: new Error("rpc unavailable") });
  equal((await failed.handler(post("{}"))).status, 503, "quota RPC error");
  assert(!failed.calls.some((call) => call.startsWith("from:")), "jobs query must not run after RPC error");
  const malformed = harness({ quota: { allowed: "yes" } });
  equal((await malformed.handler(post("{}"))).status, 503, "malformed quota result");
  assert(!malformed.calls.some((call) => call.startsWith("from:")), "jobs query must not run after malformed quota");
});
Deno.test("HTTP contract: quota denial returns 429 and Retry-After without querying jobs", async () => {
  const h = harness({ quota: { allowed: false, retry_after_seconds: 37 } });
  const response = await h.handler(post("{}"));
  equal(response.status, 429, "rate limit status");
  equal(response.headers.get("Retry-After"), "37", "retry header");
  equal((await response.json()).code, "RATE_LIMITED", "rate limit code");
  assert(!h.calls.some((call) => call.startsWith("from:")), "jobs query must not run when quota denied");
});
Deno.test("HTTP contract: successful response is bounded, published-only and source-cited", async () => {
  const h = harness({ rows: [{
    id: "job-1", job_title: "Engineer", description: "Public listing",
    official_notification_url: "https://example.gov.in/notice", application_url: "https://apply.example.com",
  }] });
  const response = await h.handler(post(JSON.stringify({ query: "engineer", country: "India" })));
  equal(response.status, 200, "success status");
  const result = await response.json();
  equal(result.status, "sources_found", "result status");
  equal(result.count, 1, "source count");
  equal(result.sources[0].source_id, "job-1", "source ID");
  equal(result.sources[0].citation_url, "https://example.gov.in/notice", "official citation");
  equal(result.sources[0].content_is_untrusted, true, "untrusted marker");
  assert(!("application_url" in result.sources[0]), "application URL must not be exposed as citation");
  assert(h.calls.includes("eq:status=published"), "published-only filter");
  assert(h.calls.includes("limit:5"), "max five records");
  assert(h.calls.includes("ilike:job_title=%engineer%"), "query filter");
  assert(h.calls.includes("ilike:country_name=India"), "country filter");
});
Deno.test("HTTP contract: query failures never become an empty-success result", async () => {
  const h = harness({ queryError: new Error("db unavailable") });
  equal((await h.handler(post("{}"))).status, 502, "database query failure");
});
