import { chromium } from "playwright";

const base = process.env.SMOKE_BASE_URL || "http://127.0.0.1:4173";
const browser = await chromium.launch({ headless: true });
const failures = [];
const results = [];
const pageErrors = [];
const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
page.on("pageerror", error => pageErrors.push(error.message));

async function check(name, fn) {
  try {
    await fn();
    results.push({ name, status: "passed" });
  } catch (error) {
    failures.push({ name, error: String(error.message || error) });
    results.push({ name, status: "failed" });
  }
}

async function open(path) {
  const response = await page.goto(base + "/" + path, { waitUntil: "domcontentloaded" });
  if (!response || !response.ok()) throw new Error("Page returned " + (response?.status() ?? "no response"));
}

await check("Homepage loads and category interaction works", async () => {
  await open("index.html");
  if (!(await page.title()).includes("TAMILAN CAREERS")) throw new Error("Unexpected homepage title");
  await page.locator(".category").first().click();
  if (await page.locator("#category").inputValue() !== "IT & Software") throw new Error("Category did not update search filter");
  await page.locator("#keyword").fill("accountant");
  await page.locator("#location").fill("Salem");
  await page.locator(".searchbtn").click();
  await page.waitForURL(/jobs\.html\?/);
  const url = new URL(page.url());
  if (url.searchParams.get("q") !== "accountant" || url.searchParams.get("location") !== "Salem") {
    throw new Error("Search filters were not transferred to the jobs URL");
  }
});

await check("Login page role, mode and password controls work", async () => {
  await open("login.html");
  await page.locator("#company").click();
  if (!(await page.locator("#company").getAttribute("class")).includes("active")) throw new Error("Company role did not become active");
  await page.locator("#switchLink").click();
  if (!(await page.locator("#heading").innerText()).includes("புதிய கணக்கு")) throw new Error("Register mode did not open");
  if (!(await page.locator("#nameField").isVisible())) throw new Error("Registration name field did not appear");
  await page.locator("#password").fill("TestPass123");
  await page.locator("#passwordToggle").click();
  if (await page.locator("#password").getAttribute("type") !== "text") throw new Error("Password reveal control failed");
  await page.locator("#passwordToggle").click();
  if (await page.locator("#password").getAttribute("type") !== "password") throw new Error("Password hide control failed");
  const redirectChecks = await page.evaluate(() => ({
    relative: getPostLoginTarget("job-posting.html", "https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/login.html").href,
    nested: getPostLoginTarget("company-members.html?tab=team", "https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/login.html").href,
    external: getPostLoginTarget("https://example.com/steal", "https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/login.html").href,
    duplicated: getPostLoginTarget("/TAMILAN-CAREERS/TAMILAN-CAREERS/job-posting.html", "https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/login.html").href
  }));
  if (redirectChecks.relative !== "https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/job-posting.html") throw new Error("Relative post-login return path is incorrect: " + redirectChecks.relative);
  if (redirectChecks.nested !== "https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/company-members.html?tab=team") throw new Error("Post-login query string was not preserved: " + redirectChecks.nested);
  if (redirectChecks.external !== "https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/dashboard.html") throw new Error("External redirect was not rejected: " + redirectChecks.external);
  if (redirectChecks.duplicated !== "https://arulmuruganbe5540-prog.github.io/TAMILAN-CAREERS/dashboard.html") throw new Error("Duplicated repository path was not rejected: " + redirectChecks.duplicated);
});

await check("State government jobs render and filter", async () => {
  await open("state-government-jobs.html");
  const initial = await page.locator("#stateList article").count();
  if (initial < 20) throw new Error("Expected state directory cards, got " + initial);
  await page.locator("#search").fill("Tamil Nadu");
  const filtered = await page.locator("#stateList article").count();
  if (filtered < 1 || filtered >= initial) throw new Error("State search filter did not narrow results");
  await page.locator("#jobSearch").fill("Gujarat");
  if (await page.locator("#vacancyList article").count() < 1) throw new Error("Job search did not return the Gujarat listing");
});

await check("Government exam practice starts and checks an answer", async () => {
  await open("exam-preparation.html");
  await page.locator("#start").click();
  if (!(await page.locator("#quiz").isVisible())) throw new Error("Quiz did not start");
  await page.locator('input[name="answer"]').first().check();
  await page.locator("#next").click();
  if (!(await page.locator("#feedback").isVisible())) throw new Error("Answer feedback did not appear");
  await page.locator("#quit").click();
  if (!(await page.locator("#result").isVisible())) throw new Error("Quiz result did not appear");
});

await check("Bilingual AI job search control is available", async () => {
  await open("jobs.html");
  const button = page.locator("#aiSearch");
  if (!(await button.isVisible())) throw new Error("Bilingual AI search button is missing");
  const label = await button.innerText();
  if (!label.includes("தமிழ்") || !label.includes("English")) throw new Error("Search button does not promise Tamil and English results");
  if (!(await page.locator("#q").getAttribute("placeholder")).includes("எந்த மொழியிலும்")) throw new Error("Any-language search hint is missing");
});

await check("External job source review requires login", async () => {
  await open("external-job-review.html");
  await page.waitForFunction(() => location.pathname.endsWith("/admin-login.html"), { timeout: 8000 });
});

await check("Government admin pages require Admin Login", async () => {
  await open("government-notice-review.html");
  await page.waitForFunction(() => location.pathname.endsWith("/admin-login.html"), { timeout: 8000 });
  if (new URL(page.url()).searchParams.get("next") !== "government-notice-review.html") throw new Error("Government review return path was not preserved");
  await open("government-notice-publish.html?id=smoke-test");
  await page.waitForFunction(() => location.pathname.endsWith("/admin-login.html"), { timeout: 8000 });
  if (new URL(page.url()).searchParams.get("next") !== "government-notice-publish.html?id=smoke-test") throw new Error("Government publish return query was not preserved");
});

await check("Private admin controls require authentication", async () => {
  await open("admin-control.html");
  await page.waitForSelector("#gate:not(.hidden)", { timeout: 8000 });
  if (!(await page.locator('#gate a[href*="login.html"]').count())) {
    throw new Error("Admin login link is missing");
  }
  await open("admin-job-post.html");
  await page.waitForSelector("#gate:not(.hidden)", { timeout: 8000 });
  if (!(await page.locator('#gate a[href*="login.html"]').count())) {
    throw new Error("Admin job-post login link is missing");
  }
});

await check("Job Seeker profile requires login", async () => {
  await open("job-seeker-profile.html");
  await page.waitForFunction(() => location.pathname.endsWith("/login.html"), { timeout: 8000 });
  if (new URL(page.url()).searchParams.get("next") !== "job-seeker-profile.html") throw new Error("Candidate profile return path was not preserved");
});

await check("Resume documents page requires login", async () => {
  await open("resume-documents.html");
  await page.waitForFunction(() => location.pathname.endsWith("/login.html"), { timeout: 8000 });
});

await check("Job application page requires login", async () => {
  await open("apply.html?job=smoke-test");
  await page.waitForFunction(() => location.pathname.endsWith("/login.html"), { timeout: 8000 });
  if (new URL(page.url()).searchParams.get("next") !== "apply.html?job=smoke-test") throw new Error("Application return query was not preserved");
});

await check("Company applicant page requires login", async () => {
  await open("company-applicants.html");
  await page.waitForFunction(() => location.pathname.endsWith("/login.html"), { timeout: 8000 });
});

await check("Company profile draft page requires login", async () => {
  await open("company-profile.html");
  await page.waitForFunction(() => location.pathname.endsWith("/login.html"), { timeout: 8000 });
});

await check("Company team management page requires login", async () => {
  await open("company-members.html");
  await page.waitForFunction(() => location.pathname.endsWith("/login.html"), { timeout: 8000 });
});

await check("Invitation acceptance page rejects a missing token safely", async () => {
  await open("accept-invitation.html");
  await page.waitForFunction(() => document.getElementById("status")?.textContent.includes("Token"), { timeout: 8000 });
  if (!(await page.locator("#acceptBtn").isDisabled())) throw new Error("Invitation button should be disabled without a token");
});

await check("Company job draft page requires login", async () => {
  await open("job-posting.html");
  await page.waitForFunction(() => location.pathname.endsWith("/login.html"), { timeout: 8000 });
  if (new URL(page.url()).searchParams.get("next") !== "job-posting.html") throw new Error("Company job posting return path was not preserved");
});

await check("Notification center requires login", async () => {
  await open("notifications.html");
  await page.waitForFunction(() => location.pathname.endsWith("/login.html"), { timeout: 8000 });
});

await check("Candidate application history requires login", async () => {
  await open("my-applications.html");
  await page.waitForFunction(() => location.pathname.endsWith("/login.html"), { timeout: 8000 });
});

await check("Expired published vacancies cannot be opened for application", async () => {
  await page.route("**/rest/v1/jobs**", route => route.fulfill({
    status: 200,
    contentType: "application/json",
    body: JSON.stringify({
      id: "expired-smoke",
      status: "published",
      job_title: "Expired smoke-test vacancy",
      application_deadline: "2020-01-01"
    })
  }));
  try {
    await open("job-details.html?id=expired-smoke");
    await page.waitForFunction(
      () => document.getElementById("content")?.textContent.includes("விண்ணப்பக் காலம் முடிந்துவிட்டது"),
      { timeout: 8000 }
    );
    if (await page.locator('#content a[href*="apply.html"]').count()) {
      throw new Error("Expired vacancy still exposes an apply link");
    }
  } finally {
    await page.unroute("**/rest/v1/jobs**");
  }
});

await check("AI resume matching page requires login", async () => {
  await open("ai-job-matches.html");
  await page.waitForFunction(() => location.pathname.endsWith("/login.html"), { timeout: 8000 });
});

await check("Dashboard requires login", async () => {
  await open("dashboard.html");
  await page.waitForFunction(() => location.pathname.endsWith("/login.html"), { timeout: 8000 });
  if (new URL(page.url()).searchParams.get("next") !== "dashboard.html") throw new Error("Dashboard return path was not preserved");
});

await check("Tamil Nadu government jobs page loads and filters", async () => {
  await open("tamil-nadu-government-jobs.html");
  if (await page.locator("#departments .card").count() < 5) throw new Error("Department cards are missing");
  await page.locator("#q").fill("TNPSC");
  if (await page.locator("#departments .card:visible").count() < 1) throw new Error("TNPSC search returned no departments");
});

if (pageErrors.length) failures.push({ name: "Uncaught browser JavaScript errors", error: pageErrors.join(" | ") });
await browser.close();
console.log(JSON.stringify({ status: failures.length ? "failed" : "passed", checks: results, browser_errors: pageErrors, failures }, null, 2));
if (failures.length) process.exit(1);
