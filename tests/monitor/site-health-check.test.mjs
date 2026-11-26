import test from "node:test";
import assert from "node:assert/strict";
import { runChecks, TARGETS } from "../../scripts/site-health-check.mjs";

function response(status = 200, contentType = "text/html; charset=utf-8") {
  return new Response("<!doctype html><title>Test</title>", {
    status,
    headers: { "content-type": contentType },
  });
}

test("monitor checks every configured critical public endpoint", async () => {
  const requested = [];
  const report = await runChecks({
    baseUrl: "https://example.test",
    fetchImpl: async (url) => {
      requested.push(url);
      const path = new URL(url).pathname;
      return response(
        200,
        path.endsWith(".xml") ? "application/xml" :
          path.endsWith(".txt") ? "text/plain" : "text/html",
      );
    },
  });
  assert.equal(report.status, "healthy");
  assert.equal(report.checks.length, TARGETS.length);
  assert.equal(requested.length, TARGETS.length);
  assert.ok(report.checks.every((item) => item.ok));
});

test("monitor reports an HTTP failure without hiding other results", async () => {
  const report = await runChecks({
    baseUrl: "https://example.test",
    fetchImpl: async (url) => new URL(url).pathname === "/private-jobs.html"
      ? response(503)
      : response(
        200,
        new URL(url).pathname.endsWith(".xml") ? "application/xml" :
          new URL(url).pathname.endsWith(".txt") ? "text/plain" : "text/html",
      ),
  });
  assert.equal(report.status, "failed");
  assert.equal(report.checks.filter((item) => !item.ok).length, 1);
  assert.match(report.checks.find((item) => !item.ok).error, /HTTP 503/);
});

test("monitor records network failures as failed checks", async () => {
  const report = await runChecks({
    baseUrl: "https://example.test",
    fetchImpl: async () => { throw new Error("connection refused"); },
  });
  assert.equal(report.status, "failed");
  assert.ok(report.checks.every((item) => item.error === "connection refused"));
});
