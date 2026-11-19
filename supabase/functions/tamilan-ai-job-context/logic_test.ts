import {
  MAX_DESCRIPTION_LENGTH,
  normalizeCountry,
  normalizeSearchQuery,
  publicJobSource,
  safeHttpsUrl,
} from "../supabase/functions/tamilan-ai-job-context/logic.ts";
import { assertEquals, assertNotEquals } from "jsr:@std/assert@1";

Deno.test("search query accepts plain text and normalizes whitespace", () => {
  assertEquals(normalizeSearchQuery("  software   engineer "), "software engineer");
  assertEquals(normalizeSearchQuery("a%b_c(d)"), "a b c d ");
});
Deno.test("search query rejects non-string and overlong values", () => {
  assertEquals(normalizeSearchQuery(42), null);
  assertEquals(normalizeSearchQuery("x".repeat(81)), null);
});
Deno.test("country normalization collapses whitespace and rejects unsafe types/length", () => {
  assertEquals(normalizeCountry("  India   "), "India");
  assertEquals(normalizeCountry(7), null);
  assertEquals(normalizeCountry("x".repeat(101)), null);
});
Deno.test("citation URLs allow HTTPS only and reject malformed or oversized input", () => {
  assertEquals(safeHttpsUrl("https://example.gov.in/notice"), "https://example.gov.in/notice");
  assertEquals(safeHttpsUrl("javascript:alert(1)"), null);
  assertEquals(safeHttpsUrl("http://example.com"), null);
  assertEquals(safeHttpsUrl("x".repeat(2049)), null);
});
Deno.test("job source requires a real ID and uses canonical internal citation as fallback", () => {
  assertEquals(publicJobSource({ job_title: "No ID" }), null);
  const source = publicJobSource({ id: "job/123", job_title: "Engineer", official_notification_url: "javascript:bad" });
  assertEquals(source?.source_id, "job/123");
  assertEquals(source?.citation_url, "https://tamilancareers.in/job-details.html?id=job%2F123");
  assertEquals(source?.content_is_untrusted, true);
});
Deno.test("job source prefers verified HTTPS notification URL and bounds untrusted description", () => {
  const source = publicJobSource({
    id: "abc",
    official_notification_url: "https://example.gov.in/notice",
    official_website_url: "https://example.gov.in",
    description: "x".repeat(MAX_DESCRIPTION_LENGTH + 10),
    application_url: "https://apply.example.com",
  });
  assertEquals(source?.citation_url, "https://example.gov.in/notice");
  assertEquals(source?.description.length, MAX_DESCRIPTION_LENGTH);
  assertNotEquals(source?.citation_url, "https://apply.example.com");
});
