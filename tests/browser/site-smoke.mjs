import assert from "node:assert/strict";
import { createServer } from "node:http";
import { readFile, readdir } from "node:fs/promises";
import { extname, resolve, sep } from "node:path";
import { pathToFileURL } from "node:url";
import { chromium } from "playwright";

const root = process.cwd();
const mime = { ".html": "text/html; charset=utf-8", ".css": "text/css", ".js": "text/javascript", ".svg": "image/svg+xml" };
const server = createServer(async (req, res) => {
  try {
    const pathname = decodeURIComponent(new URL(req.url, "http://127.0.0.1").pathname);
    const relative = pathname === "/" ? "index.html" : pathname.replace(/^\/+/, "");
    const file = resolve(root, relative);
    if (file !== root && !file.startsWith(root + sep)) throw new Error("Path traversal blocked");
    const body = await readFile(file);
    res.writeHead(200, { "content-type": mime[extname(file)] || "application/octet-stream" });
    res.end(body);
  } catch {
    res.writeHead(404);
    res.end("Not found");
  }
});

const adminPages = (await readdir(root)).filter((name) => name.startsWith("super-admin") && name.endsWith(".html"));
assert.ok(adminPages.length >= 20, "Super Admin page inventory should be present");
for (const name of adminPages) {
  const html = await readFile(resolve(root, name), "utf8");
  if (name === "super-admin-tamil-translations.html") {
    assert.match(html, /<html lang="en">/i, name + " should declare the English-only admin interface");
    assert.doesNotMatch(html, /admin-language[.]js|data-lang-choice|data-ui-lang|language-toggle/, name + " must not expose a language switch");
  } else {
    assert.match(html, /admin-language[.]js/, name + " should load the shared English-only admin language normalizer");
  }
}

const supabaseStub = `
window.supabase = {
  createClient: () => {
    const query = new Proxy({}, {
      get(_target, key) {
        if (key === "then") return (resolve, reject) => Promise.resolve({ data: [], error: null }).then(resolve, reject);
        if (key === "single" || key === "maybeSingle") return async () => ({ data: null, error: null });
        return () => query;
      }
    });
    return {
      auth: {
        getSession: async () => ({ data: { session: null }, error: null }),
        getUser: async () => ({ data: { user: null }, error: null }),
        onAuthStateChange: () => ({ data: { subscription: { unsubscribe() {} } } }),
        signOut: async () => ({ error: null })
      },
      from: () => query,
      rpc: async () => ({ data: null, error: null })
    };
  }
};
`;

let browser;
try {
  await new Promise((resolve) => server.listen(4173, "127.0.0.1", resolve));
  browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, deviceScaleFactor: 1 });
  await context.route("**/*", async (route) => {
    const url = route.request().url();
    if (url.startsWith("http://127.0.0.1:4173/")) return route.continue();
    if (url.includes("@supabase/supabase-js")) {
      return route.fulfill({ status: 200, contentType: "application/javascript", body: supabaseStub });
    }
    if (/\.(?:js)(?:\?|$)/i.test(url)) {
      return route.fulfill({ status: 200, contentType: "application/javascript", body: "" });
    }
    return route.abort();
  });

  const page = await context.newPage();
  const load = async (path) => {
    const response = await page.goto("http://127.0.0.1:4173/" + path, { waitUntil: "domcontentloaded" });
    assert.equal(response.status(), 200, path + " should load successfully");
    await page.locator("body").waitFor();
  };

  for (const path of [
    "index.html", "government-jobs.html", "private-jobs.html", "international-jobs.html",
    "job-seeker-auth.html", "employer-auth.html", "company-job-portal.html",
    "apply-private-job.html", "apply-international-job.html", "mangai-control-center.html"
  ]) {
    await load(path);
    const title = await page.title();
    assert.ok(title.length > 0, path + " should have a page title");
    const viewport = await page.locator('meta[name="viewport"]').getAttribute("content");
    assert.match(viewport || "", /width=device-width/i, path + " should declare a mobile viewport");
  }

  for (const [path, portalName] of [
    ["job-seeker-auth.html", "Job Seeker"],
    ["employer-auth.html", "Employer"]
  ]) {
    await load(path);
    await page.locator("#loginForm").waitFor({ state: "visible" });
    await page.locator("#registerTab").click();
    await page.locator("#registerForm").waitFor({ state: "visible" });
    await page.locator("#loginForm").waitFor({ state: "hidden" });
    await page.locator("#fullName").fill("Regression Test");
    await page.locator("#registerEmail").fill("regression@example.test");
    await page.locator("#registerPassword").fill("StrongPass123");
    await page.locator("#confirmPassword").fill("DifferentPass123");
    await page.locator("#registerBtn").click();
    await page.locator("#notice").waitFor({ state: "visible" });
    assert.match(await page.locator("#notice").innerText(), /Passwords do not match/i, portalName + " password mismatch validation should run before any network submission");
    await page.locator('[data-toggle="registerPassword"]').click();
    assert.equal(await page.locator("#registerPassword").getAttribute("type"), "text", portalName + " password visibility control should work");
    await page.locator("#loginTab").click();
    await page.locator("#loginForm").waitFor({ state: "visible" });
  }

  for (const [path, guardId] of [
    ["company-job-portal.html", "#authGuard"],
    ["apply-private-job.html", "#guard"],
    ["apply-international-job.html", "#guard"]
  ]) {
    await load(path);
    await page.locator(guardId).waitFor({ state: "visible" });
  }

  for (const [path, expected] of [
    ["government-jobs.html", /Government Jobs/i],
    ["private-jobs.html", /Private Jobs/i],
    ["international-jobs.html", /International Jobs/i]
  ]) {
    await load(path);
    assert.match(await page.locator("body").innerText(), expected, path + " should identify its market");
  }

  await load("tests/browser/admin-language-fixture.html");
  await page.waitForFunction(() => document.documentElement.lang === "en" && document.querySelector("h1")?.innerText === "Activity Logs");
  assert.equal(await page.locator(".tc-admin-language, .language-toggle, [data-lang-choice], [data-ui-lang]").count(), 0, "all legacy Tamil/English language controls must be removed");
  assert.equal(await page.locator("html").getAttribute("lang"), "en", "admin interface must default to English");
  assert.equal(await page.locator("h1").innerText(), "Activity Logs", "Tamil source labels should be normalized to English");
  assert.equal(await page.locator("input").getAttribute("placeholder"), "Search", "input placeholders should be normalized to English");
  assert.match(await page.locator("main p").innerText(), /Audit events are automatically captured/, "mixed-language help text should be normalized to English");

  await load("super-admin-tamil-translations.html");
  assert.equal(await page.locator("html").getAttribute("lang"), "en", "Tamil translation workspace admin controls must remain English");
  assert.equal(await page.locator(".language-toggle, [data-lang-choice], [data-ui-lang], .tc-admin-language").count(), 0, "Tamil translation workspace must not expose a language switch");

  await context.close();
  console.log("Browser smoke checks passed: 10 page loads, mobile viewport declarations, student/employer auth tabs, password mismatch validation, password visibility, protected account/application guards, market labels, and English-only Super Admin UI with legacy language controls removed.");
} finally {
  if (browser) await browser.close();
  await new Promise((resolve) => server.close(resolve));
}
