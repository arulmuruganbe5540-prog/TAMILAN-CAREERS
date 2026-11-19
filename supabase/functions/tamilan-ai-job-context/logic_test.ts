import { MAX_DESCRIPTION_LENGTH, normalizeCountry, normalizeSearchQuery, parseRetrievalInput, publicJobSource, rateLimitDecision, safeHttpsUrl } from "./logic.ts";
function equal(actual: unknown, expected: unknown, label: string) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) throw new Error(label + ": expected " + JSON.stringify(expected) + ", got " + JSON.stringify(actual));
}
Deno.test("search query normalizes whitespace and filter characters", () => {
  equal(normalizeSearchQuery("  software   engineer "), "software engineer", "whitespace");
  equal(normalizeSearchQuery("a%b_c(d)"), "a b c d", "filter characters");
});
Deno.test("search query rejects non-string and overlong values", () => {
  equal(normalizeSearchQuery(42), null, "non-string");
  equal(normalizeSearchQuery("x".repeat(81)), null, "overlong");
});
Deno.test("country normalization collapses whitespace and rejects unsafe values", () => {
  equal(normalizeCountry("  India   "), "India", "country whitespace");
  equal(normalizeCountry(7), null, "country type");
  equal(normalizeCountry("x".repeat(101)), null, "country length");
});
Deno.test("citation URLs allow HTTPS only", () => {
  equal(safeHttpsUrl("https://example.gov.in/notice"), "https://example.gov.in/notice", "https URL");
  equal(safeHttpsUrl("javascript:alert(1)"), null, "javascript URL");
  equal(safeHttpsUrl("http://example.com"), null, "http URL");
  equal(safeHttpsUrl("x".repeat(2049)), null, "oversized URL");
});
Deno.test("rate limit parser accepts only explicit bounded decisions", () => {
  equal(rateLimitDecision({ allowed: true, minute_remaining: 9 }), { allowed: true, retryAfterSeconds: 0 }, "allow");
  equal(rateLimitDecision({ allowed: false, retry_after_seconds: 30 }), { allowed: false, retryAfterSeconds: 30 }, "deny");
  equal(rateLimitDecision({ allowed: false, retry_after_seconds: 0 }), null, "zero retry");
  equal(rateLimitDecision({ allowed: false, retry_after_seconds: 90000 }), null, "oversized retry");
  equal(rateLimitDecision({ allowed: "true" }), null, "non-boolean");
  equal(rateLimitDecision(null), null, "null result");
});
Deno.test("job source requires a real ID and uses canonical citation fallback", () => {
  equal(publicJobSource({ job_title: "No ID" }), null, "missing source ID");
  const source = publicJobSource({ id: "job/123", job_title: "Engineer", official_notification_url: "javascript:bad" });
  equal(source?.source_id, "job/123", "source ID");
  equal(source?.citation_url, "https://tamilancareers.in/job-details.html?id=job%2F123", "fallback citation");
  equal(source?.content_is_untrusted, true, "untrusted marker");
});
Deno.test("job source prefers official HTTPS notice and bounds description", () => {
  const source = publicJobSource({
    id: "abc", official_notification_url: "https://example.gov.in/notice",
    official_website_url: "https://example.gov.in", description: "x".repeat(MAX_DESCRIPTION_LENGTH + 10),
    application_url: "https://apply.example.com",
  });
  equal(source?.citation_url, "https://example.gov.in/notice", "official citation");
  equal(source?.description.length, MAX_DESCRIPTION_LENGTH, "description bound");
  if (source?.citation_url === "https://apply.example.com") throw new Error("application URL must not become citation");
});

Deno.test("request body parser rejects non-object JSON and arrays", () => {
  equal(parseRetrievalInput(null).ok, false, "null body");
  equal(parseRetrievalInput([]).ok, false, "array body");
  equal(parseRetrievalInput("query").ok, false, "string body");
});
Deno.test("request body parser rejects unexpected keys", () => {
  const result = parseRetrievalInput({ query: "engineer", admin: true });
  equal(result.ok, false, "extra key");
  if (!result.ok) equal(result.error, "Unsupported request field", "extra key message");
});
Deno.test("request body parser returns normalized query and country", () => {
  const result = parseRetrievalInput({ query: "  data   analyst ", country: "  India " });
  equal(result.ok, true, "valid body");
  if (result.ok) {
    equal(result.value.query, "data analyst", "normalized query");
    equal(result.value.country, "India", "normalized country");
  }
});
Deno.test("request body parser defaults missing fields and rejects invalid field values", () => {
  const empty = parseRetrievalInput({});
  equal(empty.ok, true, "empty object");
  if (empty.ok) {
    equal(empty.value.query, "", "missing query default");
    equal(empty.value.country, "", "missing country default");
  }
  equal(parseRetrievalInput({ query: 123 }).ok, false, "query type");
  equal(parseRetrievalInput({ country: "x".repeat(101) }).ok, false, "country length");
});
