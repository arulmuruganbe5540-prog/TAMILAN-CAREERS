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

await check("Homepage loads, career categories navigate and job search works", async () => {
  await open("index.html");
  if (!(await page.title()).includes("TAMILAN CAREERS")) throw new Error("Unexpected homepage title");
  const structuredData = await page.evaluate(() => ({
    website: JSON.parse(document.querySelector("#tc-website-jsonld")?.textContent || "null"),
    organization: JSON.parse(document.querySelector("#tc-organization-jsonld")?.textContent || "null")
  }));
  if (structuredData.website?.["@type"] !== "WebSite" || structuredData.organization?.["@type"] !== "Organization" ||
      structuredData.organization?.email !== "arulmuruganbe5540@gmail.com" || structuredData.organization?.url !== location.origin + "/") {
    throw new Error("Homepage structured data is missing or inconsistent: " + JSON.stringify(structuredData));
  }
  const categoryCard = page.locator('.category-card[href*="category=IT"]').first();
  await categoryCard.click();
  await page.waitForURL(/jobs\.html\?/);
  if (new URL(page.url()).searchParams.get("category") !== "IT & Software") {
    throw new Error("Career category link did not pass the selected category");
  }
  await open("index.html");
  await page.locator("#keyword").fill("accountant");
  await page.locator("#location").fill("Salem");
  await page.locator("#category").selectOption("Accounting");
  await page.locator(".search-submit").click();
  await page.waitForURL(/jobs\.html\?/);
  const url = new URL(page.url());
  if (url.searchParams.get("q") !== "accountant" || url.searchParams.get("location") !== "Salem" || url.searchParams.get("category") !== "Accounting") {
    throw new Error("Search filters were not transferred to the jobs URL");
  }
});

await check("Redesigned homepage is mobile-friendly and hides country-detection notices", async () => {
  await page.setViewportSize({ width: 360, height: 800 });
  await open("index.html");
  await page.locator(".site-header").waitFor({ state: "visible" });
  await page.locator("#keyword").waitFor({ state: "visible" });
  const layout = await page.evaluate(() => ({
    viewport: document.documentElement.clientWidth,
    document: document.documentElement.scrollWidth,
    search: document.querySelector(".search-panel")?.getBoundingClientRect().width || 0,
    nav: !!document.querySelector(".main-nav"),
    overflowElements: [...document.querySelectorAll("body *")].map(el=>({tag:el.tagName,cls:typeof el.className==="string"?el.className:"",id:el.id,left:Math.round(el.getBoundingClientRect().left),right:Math.round(el.getBoundingClientRect().right),width:Math.round(el.getBoundingClientRect().width)})).filter(x=>x.right>document.documentElement.clientWidth+1||x.left< -1).slice(0,20),
    visibleText: (document.body.innerText || "").toLowerCase()
  }));
  if (layout.document > layout.viewport + 1) throw new Error("Homepage has horizontal page overflow on mobile: " + JSON.stringify(layout));
  if (!layout.nav || layout.search <= 0) throw new Error("Mobile navigation or job search panel is missing");
  if (layout.visibleText.includes("your country detected") || layout.visibleText.includes("உங்கள் நாடு கண்டறியப்பட்டது")) {
    throw new Error("Country detection notice should remain hidden");
  }
  await page.setViewportSize({ width: 390, height: 844 });
});

await check("Employer registration page fits mobile widths without horizontal scrolling", async () => {
  const employerPage = await browser.newPage({ viewport: { width: 320, height: 800 } });
  try {
    await employerPage.route("**/auth/v1/user**", route => route.fulfill({
      status: 200, contentType: "application/json",
      body: JSON.stringify({ id: "employer-layout-smoke", aud: "authenticated", role: "authenticated", email: "employer@example.test", app_metadata: {}, user_metadata: {} })
    }));
    await employerPage.route("**/rest/v1/countries**", route => route.fulfill({
      status: 200, contentType: "application/json",
      body: JSON.stringify([{ country_code: "IN", country_name: "India" }, { country_code: "AE", country_name: "United Arab Emirates" }])
    }));
    await employerPage.route("**/rest/v1/company_profile_drafts**", route => route.fulfill({
      status: 200, contentType: "application/json", body: "[]"
    }));
    await employerPage.addInitScript(() => {
      localStorage.setItem("sb-qkmljuuusfjowexvybvy-auth-token", JSON.stringify({
        access_token: "test-access-token",
        refresh_token: "test-refresh-token",
        token_type: "bearer",
        expires_in: 3600,
        expires_at: Math.floor(Date.now() / 1000) + 3600,
        user: { id: "employer-layout-smoke", aud: "authenticated", role: "authenticated", email: "employer@example.test" }
      }));
    });
    const response = await employerPage.goto(base + "/company-profile.html", { waitUntil: "domcontentloaded" });
    if (!response || !response.ok()) throw new Error("Employer registration page failed to load");
    await employerPage.locator("#docRegistration").waitFor({ state: "visible", timeout: 10000 });
    for (const width of [320, 360, 390, 430]) {
      await employerPage.setViewportSize({ width, height: 800 });
      const layout = await employerPage.evaluate(() => ({
        viewport: document.documentElement.clientWidth,
        document: document.documentElement.scrollWidth,
        overflow: [...document.querySelectorAll("body *")].map(el => {
          const r = el.getBoundingClientRect();
          return { tag: el.tagName, id: el.id, cls: typeof el.className === "string" ? el.className : "", left: Math.round(r.left), right: Math.round(r.right) };
        }).filter(x => x.right > document.documentElement.clientWidth + 1 || x.left < -1).slice(0, 12)
      }));
      if (layout.document > layout.viewport + 1) {
        throw new Error("Horizontal overflow at " + width + "px: " + JSON.stringify(layout));
      }
    }
    await employerPage.setViewportSize({ width: 768, height: 900 });
    const desktopColumns = await employerPage.locator("#companyForm").evaluate(el => getComputedStyle(el).gridTemplateColumns);
    if (desktopColumns.split(" ").length < 2) throw new Error("Desktop form should retain its two-column layout");
  } finally {
    await employerPage.close();
  }
});

await check("Login page role, mode and password controls work", async () => {
  await open("login.html");
  await page.locator("#company").click();
  if (!(await page.locator("#company").getAttribute("class")).includes("active")) throw new Error("Company role did not become active");
  await page.locator("#switchLink").click();
  if (!(await page.locator("#heading").innerText()).includes("Create a new account")) throw new Error("Register mode did not open");
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


await check("English-only registration validates and submits employer signup", async () => {
  const registrationPage = await browser.newPage({ viewport: { width: 390, height: 844 } });
  let signupBody = null;
  try {
    await registrationPage.route("**/auth/v1/signup*", async route => {
      signupBody = route.request().postDataJSON();
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          id: "smoke-employer-user",
          aud: "authenticated",
          role: "authenticated",
          email: "employer@example.test",
          app_metadata: { provider: "email", providers: ["email"] },
          user_metadata: signupBody?.data || {},
          identities: [{ id: "smoke-employer-user", user_id: "smoke-employer-user", identity_data: { email: "employer@example.test" }, provider: "email" }],
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        })
      });
    });
    await registrationPage.goto(base + "/login.html", { waitUntil: "domcontentloaded" });
    await registrationPage.locator("#company").click();
    if (!(await registrationPage.locator("#company").getAttribute("class")).includes("active")) throw new Error("Company role did not become active");
    await registrationPage.locator("#switchLink").click();
    if (!(await registrationPage.locator("#heading").innerText()).includes("Create a new account")) throw new Error("Registration mode did not open");
    for (const selector of ["#fullName", "#email", "#password", "#confirmPassword", "#termsAgree"]) {
      if (!(await registrationPage.locator(selector).isVisible())) throw new Error("Registration field is missing: " + selector);
    }
    await registrationPage.locator("#fullName").fill("Test Employer");
    await registrationPage.locator("#email").fill("employer@example.test");
    await registrationPage.locator("#password").fill("Employer123");
    await registrationPage.locator("#confirmPassword").fill("Different123");
    await registrationPage.locator("#authForm").evaluate(form => form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true })));
    if (!(await registrationPage.locator("#message").innerText()).includes("Both passwords must match")) throw new Error("Password mismatch validation failed");
    await registrationPage.locator("#confirmPassword").fill("Employer123");
    await registrationPage.locator("#password").fill("employer123");
    await registrationPage.locator("#confirmPassword").fill("employer123");
    await registrationPage.locator("#authForm").evaluate(form => form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true })));
    if (!(await registrationPage.locator("#message").innerText()).includes("uppercase letter")) throw new Error("Password complexity validation failed");
    await registrationPage.locator("#password").fill("Employer123");
    await registrationPage.locator("#confirmPassword").fill("Employer123");
    await registrationPage.locator("#authForm").evaluate(form => form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true })));
    if (!(await registrationPage.locator("#message").innerText()).includes("Terms of Use and Privacy Policy")) throw new Error("Terms and privacy acceptance validation failed");
    await registrationPage.locator("#termsAgree").check();
    await registrationPage.locator("#authForm").evaluate(form => form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true })));
    await registrationPage.waitForFunction(() => document.querySelector("#message")?.textContent.includes("Registration submitted successfully"), { timeout: 10000 });
    if (signupBody?.data?.requested_account_type !== "company") throw new Error("Employer account type was not sent correctly: " + JSON.stringify(signupBody));
    if (signupBody?.data?.full_name !== "Test Employer") throw new Error("Full name was not sent correctly");
    const visible = await registrationPage.locator("body").innerText();
    if (/[\u0B80-\u0BFF]/.test(visible)) throw new Error("Registration page displayed Tamil text");
    await registrationPage.setViewportSize({ width: 320, height: 800 });
    const size = await registrationPage.evaluate(() => ({ viewport: document.documentElement.clientWidth, page: document.documentElement.scrollWidth }));
    if (size.page > size.viewport + 1) throw new Error("Registration page overflows at 320px: " + JSON.stringify(size));
  } finally {
    await registrationPage.close();
  }
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

await check("All 16 government exam categories have a dedicated practice track", async () => {
  await open("exam-preparation.html");
  const coverage = await page.evaluate(() => {
    const tracks = {
      tn: "TNPSC VAO",
      police: "TNUSRB Police Constable",
      teacher: "TNTET Paper I",
      power: "TANGEDCO Field Assistant",
      forest: "TN Forest Watcher",
      health: "Medical Officer",
      upsc: "UPSC Civil Services",
      ssc: "SSC CGL",
      rail: "RRB NTPC",
      bank: "IBPS PO",
      defence: "Indian Army Agniveer",
      postal: "India Post GDS",
      insurance: "LIC AAO",
      court: "Court Assistant",
      psu: "ONGC Recruitment",
      state: "Kerala PSC"
    };
    const bank = window.TC_EXAM_BANK || [];
    return {
      categories: document.querySelectorAll("#category option").length,
      total: bank.filter(q => q.exam).length,
      missing: Object.entries(tracks).filter(([key, exam]) =>
        ![...document.querySelectorAll("#category option")].some(option => option.value === key) ||
        !bank.some(q => q.exam === exam)
      ).map(([, exam]) => exam)
    };
  });
  if (coverage.categories !== 16) throw new Error("Expected 16 exam categories; found " + coverage.categories);
  if (coverage.total < 80) throw new Error("Expected at least 80 exam-specific questions; found " + coverage.total);
  if (coverage.missing.length) throw new Error("Missing category question tracks: " + coverage.missing.join(", "));
});

await check("Rule-based job search filters work without AI controls", async () => {
  await open("jobs.html");
  if (!(await page.locator("#q").isVisible())) throw new Error("Job keyword search is missing");
  if (!(await page.locator("#kind").isVisible())) throw new Error("Job category filter is missing");
  if (!(await page.locator("#place").isVisible())) throw new Error("Job location filter is missing");
  if (await page.locator("#aiSearch").count()) throw new Error("An AI search control must not be shown");
  await page.locator("#q").fill("accountant");
  await page.locator("#place").fill("Salem");
  await page.locator("#kind").selectOption("private");
  if (!(await page.locator("#count").innerText()).includes("வேலைகள் கிடைத்துள்ளன")) throw new Error("Rule-based filters did not refresh the result count");
});

await check("Multi-word job search matches every entered keyword", async () => {
  await page.route("**/rest/v1/jobs**", route => route.fulfill({
    status: 200,
    contentType: "application/json",
    body: JSON.stringify([{
      id: "multiword-smoke",
      status: "published",
      job_title: "Accountant",
      description: "Maintain daily accounts",
      required_skills: "Excel Tally",
      location: "Salem",
      employment_type: "full_time",
      job_kind: "private"
    }])
  }));
  try {
    await open("jobs.html");
    await page.waitForFunction(() => document.getElementById("count")?.textContent.includes("1 வேலைகள்"));
    await page.locator("#q").fill("accountant excel");
    if (!(await page.locator("#count").innerText()).includes("1 வேலைகள்")) {
      throw new Error("A job matching both keywords was not found");
    }
    await page.locator("#q").fill("accountant missingword");
    if (!(await page.locator("#count").innerText()).includes("0 வேலைகள்")) {
      throw new Error("Search should require every entered keyword to match");
    }
  } finally {
    await page.unroute("**/rest/v1/jobs**");
  }
});

await check("Education and workplace filters narrow jobs correctly", async () => {
  await page.addInitScript(() => localStorage.setItem("tc_language_preference_v1", "en"));
  await page.route("**/rest/v1/jobs**", route => route.fulfill({
    status: 200,
    contentType: "application/json",
    body: JSON.stringify([{
      id: "filter-smoke",
      status: "published",
      job_title: "Junior Technician",
      description: "Technical support",
      location: "Salem",
      employment_type: "full_time",
      job_kind: "private",
      education_level: "ITI,Diploma",
      workplace_type: "Remote"
    }])
  }));
  try {
    await open("jobs.html");
    await page.waitForFunction(() => window.TC_TRANSLATE?.language === "en");
    await page.waitForFunction(() => document.getElementById("count")?.textContent.includes("1 வேலைகள்"));
    await page.locator("#education").selectOption("ITI");
    if (!(await page.locator("#count").innerText()).includes("1 வேலைகள்")) throw new Error("ITI qualification filter did not match");
    await page.locator("#workplace").selectOption("remote");
    if (!(await page.locator("#count").innerText()).includes("1 வேலைகள்")) throw new Error("Remote workplace filter did not match");
    await page.locator("#education").selectOption("Degree");
    if (!(await page.locator("#count").innerText()).includes("0 வேலைகள்")) throw new Error("Non-matching education should return no results");
  } finally {
    await page.unroute("**/rest/v1/jobs**");
  }
});

await check("Candidate skills match relevant jobs and filter the results", async () => {
  const skillPage = await browser.newPage({ viewport: { width: 390, height: 844 } });
  await skillPage.route("**/auth/v1/user**", route => route.fulfill({
    status: 200, contentType: "application/json",
    body: JSON.stringify({ id: "candidate-smoke", aud: "authenticated", role: "authenticated", email: "candidate@example.test", app_metadata: {}, user_metadata: {} })
  }));
  await skillPage.route("**/rest/v1/candidate_skills**", route => route.fulfill({
    status: 200, contentType: "application/json",
    body: JSON.stringify([{ skill_name: "MS Excel" }])
  }));
  await skillPage.route("**/rest/v1/jobs**", route => route.fulfill({
    status: 200, contentType: "application/json",
    body: JSON.stringify([
      { id: "skill-match", status: "published", job_title: "Accounts Assistant", description: "Accounts work", required_skills: "MS Excel, Tally", location: "Salem", employment_type: "full_time", job_kind: "private" },
      { id: "skill-no-match", status: "published", job_title: "Delivery Driver", description: "Delivery work", required_skills: "Driving, Route Planning", location: "Salem", employment_type: "full_time", job_kind: "private" }
    ])
  }));
  try {
    await skillPage.goto(base + "/index.html", { waitUntil: "domcontentloaded" });
    await skillPage.evaluate(() => localStorage.setItem("sb-qkmljuuusfjowexvybvy-auth-token", JSON.stringify({
      access_token: "test-access-token",
      refresh_token: "test-refresh-token",
      token_type: "bearer",
      expires_in: 3600,
      expires_at: Math.floor(Date.now() / 1000) + 3600,
      user: { id: "candidate-smoke", aud: "authenticated", role: "authenticated" }
    })));
    const response = await skillPage.goto(base + "/jobs.html", { waitUntil: "domcontentloaded" });
    if (!response || !response.ok()) throw new Error("Jobs page failed to load");
    await skillPage.waitForFunction(() => document.getElementById("count")?.textContent.includes("2 வேலைகள்"));
    await skillPage.locator("#skillMatch").selectOption("matched");
    await skillPage.waitForFunction(() => document.getElementById("count")?.textContent.includes("1 வேலைகள்"));
    if (!(await skillPage.locator(".job").innerText()).includes("உங்கள் திறன்கள்: 1/2 பொருத்தம்")) {
      throw new Error("Matched job did not show the candidate skill match score");
    }
  } finally {
    await skillPage.close();
  }
});

await check("External job source review requires login", async () => {
  await open("external-job-review.html");
  await page.waitForFunction(() => location.pathname.endsWith("/admin-login.html"), { timeout: 8000 });
});

await check("Government admin pages require Admin Login", async () => {
  await open("government-notice-review.html");
  await page.waitForFunction(() => location.pathname.endsWith("/admin-login.html"), { timeout: 8000 });
  await open("government-notice-publish.html?id=smoke-test");
  await page.waitForFunction(() => location.pathname.endsWith("/admin-login.html"), { timeout: 8000 });
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
  await open("admin-company-verification.html");
  await page.waitForSelector("#gate:not(.hidden)", { timeout: 8000 });
  if (!(await page.locator('#gate a[href="admin-login.html"]').count())) {
    throw new Error("Company verification Admin Login link is missing");
  }
  await open("company-verification-status.html");
  await page.waitForFunction(() => location.pathname.endsWith("/login.html"), { timeout: 8000 });
});


async function createMockSignedInPage(role = "job_seeker", viewport = { width: 390, height: 844 }) {
  const p = await browser.newPage({ viewport });
  const user = { id: "tc-flow-smoke-user", aud: "authenticated", role: "authenticated", email: "flow-smoke@example.test", app_metadata: {}, user_metadata: {} };
  await p.addInitScript(({ user }) => {
    localStorage.setItem("sb-qkmljuuusfjowexvybvy-auth-token", JSON.stringify({
      access_token: "mock-access-token", refresh_token: "mock-refresh-token", token_type: "bearer",
      expires_in: 3600, expires_at: Math.floor(Date.now() / 1000) + 3600, user
    }));
    window.confirm = () => true;
  }, { user });
  await p.route("**/auth/v1/user**", route => route.fulfill({
    status: 200, contentType: "application/json",
    body: JSON.stringify({ ...user, user_metadata: {} })
  }));
  await p.route("**/rest/v1/**", async route => {
    const url = new URL(route.request().url());
    const table = url.pathname.split("/").pop();
    const method = route.request().method();
    if (table === "user_roles") return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ role }) });
    if (table === "profiles") return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ id: user.id, full_name: "Test Candidate", email: user.email, phone: "" }) });
    if (table === "job_seeker_profiles") return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ user_id: user.id, headline: "Test Profile", bio: "", current_city: "Salem", total_experience_months: 0 }) });
    if (table === "candidate_preferences") return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ user_id: user.id, preferred_city: "Salem", preferred_employment_type: "Full Time" }) });
    if (table === "candidate_skills" || table === "candidate_languages" || table === "candidate_education" || table === "candidate_experience" || table === "candidate_certifications" || table === "candidate_resumes") {
      return route.fulfill({ status: 200, contentType: "application/json", body: "[]" });
    }
    if (table === "countries") return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify([{ country_name: "India", is_active: true }]) });
    if (table === "company_members") return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify([{ company_id: "smoke-company", member_role: "owner", member_status: "active", companies: { company_name: "Smoke Test Ltd", verification_status: "verified" } }]) });
    if (table === "job_posting_drafts" && method === "GET") return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ draft: null }) });
    if (table === "job_posting_drafts" && method !== "GET") return route.fulfill({ status: 201, contentType: "application/json", body: JSON.stringify({ id: "smoke-draft" }) });
    if (method === "GET") return route.fulfill({ status: 200, contentType: "application/json", body: "[]" });
    return route.fulfill({ status: 204, body: "" });
  });
  await p.route("**/auth/v1/user", route => route.fulfill({
    status: 200, contentType: "application/json",
    body: JSON.stringify({ ...user, user_metadata: route.request().method() === "PATCH" ? { full_name: "Smoke Candidate" } : {} })
  }));
  await p.route("**/storage/v1/object/list/**", route => route.fulfill({ status: 200, contentType: "application/json", body: "[]" }));
  await p.route("**/storage/v1/object/candidate-resumes/**", route => route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ Key: "mock-upload" }) }));
  await p.route("**/rest/v1/rpc/**", route => route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ ok: true, id: "smoke-rpc" }) }));
  return p;
}

await check("Job Seeker profile loads and saves through mocked authenticated data", async () => {
  const p = await createMockSignedInPage();
  const mutations = [];
  p.on("request", request => {
    if (request.url().includes("/rest/v1/") && !["GET", "HEAD"].includes(request.method())) mutations.push({ path: new URL(request.url()).pathname, method: request.method() });
  });
  try {
    await p.goto(base + "/job-seeker-profile.html", { waitUntil: "domcontentloaded" });
    await p.locator("#profileForm").waitFor({ state: "visible" });
    await p.locator("#fullName").fill("Smoke Candidate");
    await p.locator("#skills").fill("MS Excel, Tally");
    await p.locator("#languages").fill("Tamil, English");
    await p.locator("#saveBtn").click();
    await p.waitForFunction(() => document.getElementById("notice")?.textContent.includes("Database-ல் சேமிக்கப்பட்டது"));
    for (const table of ["profiles", "job_seeker_profiles", "candidate_skills", "candidate_languages", "candidate_preferences"]) {
      if (!mutations.some(x => x.path.endsWith("/" + table))) throw new Error("Profile save did not write expected table: " + table);
    }
  } finally { await p.close(); }
});

await check("Resume upload rejects unsupported files and accepts a mocked PDF upload", async () => {
  const p = await createMockSignedInPage();
  const uploads = [];
  p.on("request", request => { if (request.url().includes("/storage/v1/object/candidate-resumes/") && request.method() === "POST") uploads.push(request.url()); });
  try {
    await p.goto(base + "/resume-documents.html", { waitUntil: "domcontentloaded" });
    await p.locator("#uploadBtn").waitFor({ state: "visible" });
    await p.locator("#document").setInputFiles({ name: "not-a-resume.txt", mimeType: "text/plain", buffer: Buffer.from("test") });
    await p.locator("#uploadBtn").click();
    if (!(await p.locator("#notice").innerText()).includes("PDF, DOC")) throw new Error("Unsupported file type was not rejected");
    if (uploads.length) throw new Error("Unsupported file unexpectedly reached Storage");
    await p.locator("#document").setInputFiles({ name: "candidate-resume.pdf", mimeType: "application/pdf", buffer: Buffer.from("%PDF-1.4 mock resume") });
    await p.locator("#uploadBtn").click();
    await p.waitForFunction(() => document.getElementById("notice")?.textContent.includes("பாதுகாப்பாகப் பதிவேற்றப்பட்டு"));
    if (uploads.length !== 1) throw new Error("Valid PDF was not uploaded exactly once");
  } finally { await p.close(); }
});

await check("Employer job draft validates salary range, saves and submits for admin review", async () => {
  const p = await createMockSignedInPage("employer");
  const calls = [];
  p.on("request", request => { if (request.url().includes("/rest/v1/rpc/")) calls.push(new URL(request.url()).pathname.split("/").pop()); });
  try {
    await p.goto(base + "/job-posting.html", { waitUntil: "domcontentloaded" });
    await p.locator("#editor").waitFor({ state: "visible" });
    await p.locator("#companyChoice").selectOption("smoke-company");
    await p.locator("#jobTitle").fill("Smoke Test Accountant");
    await p.locator("#category").selectOption({ label: "Accounts / Finance" });
    await p.locator("#employmentType").selectOption({ label: "Full Time" });
    await p.locator("#location").fill("Salem");
    await p.locator("#countryName").selectOption("India");
    await p.locator("#description").fill("Mocked test vacancy; no real job is created.");
    await p.locator("#salaryMin").fill("20000");
    await p.locator("#salaryMax").fill("10000");
    const formState = await p.evaluate(() => ({
      valid: document.getElementById("jobForm").checkValidity(),
      invalid: [...document.querySelectorAll("#jobForm :invalid")].map(x => ({ id: x.id, value: x.value, required: x.required })),
      countryOptions: [...document.getElementById("countryName").options].map(x => ({ value: x.value, text: x.textContent }))
    }));
    if (!formState.valid) throw new Error("Mock job form is incomplete before salary validation: " + JSON.stringify(formState));
    await p.locator("#saveBtn").click();
    const salaryMessage = await p.locator("#status").innerText();
    if (!salaryMessage.includes("அதிகபட்ச சம்பளம்")) throw new Error("Invalid salary range was not rejected; status=" + salaryMessage + "; form=" + JSON.stringify(formState));
    await p.locator("#salaryMin").fill("10000");
    await p.locator("#salaryMax").fill("20000");
    await p.locator("#saveBtn").click();
    await p.waitForFunction(() => document.getElementById("status")?.textContent.includes("தனிப்பட்ட Draft அட்டவணையில் சேமிக்கப்பட்டது"));
    await p.locator("#submitReviewBtn").click();
    await p.waitForFunction(() => document.getElementById("status")?.textContent.includes("Admin Review-க்கு அனுப்பப்பட்டது"));
    if (!calls.includes("tc_submit_company_job_draft_for_review")) throw new Error("Job draft was not sent to the review RPC");
  } finally { await p.close(); }
});


await check("Notifications mark-read, mark-all and interview responses call each RPC once", async () => {
  const p = await createMockSignedInPage();
  let isRead = false, markAllCalls = 0, interviewResponses = 0, interviewAccepted = false;
  await p.route("**/rest/v1/tc_notifications**", route => route.fulfill({
    status: 200, contentType: "application/json",
    body: JSON.stringify([{ id: "notification-smoke", notification_type: "application_status", title: "Application update", body: "Your application is under review", related_application_id: "application-smoke", related_interview_id: null, is_read: isRead, created_at: "2026-11-18T10:00:00Z" }])
  }));
  await p.route("**/rest/v1/tc_interview_invitations**", route => route.fulfill({
    status: 200, contentType: "application/json",
    body: JSON.stringify([{ id: "interview-smoke", application_id: "application-smoke", scheduled_at: "2030-01-01T10:00:00Z", interview_mode: "online", location_or_link: "https://example.test/meeting", letter_text: "Mock interview invitation", status: interviewAccepted ? "accepted" : "pending", jobs: { job_id: "job-smoke", jobs: { job_title: "Accountant" } }, companies: { company_name: "Smoke Test Ltd" } }])
  }));
  await p.route("**/rest/v1/rpc/tc_mark_notification_read", route => {
    isRead = true;
    return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ ok: true }) });
  });
  await p.route("**/rest/v1/rpc/tc_mark_all_notifications_read", route => {
    markAllCalls++;
    isRead = true;
    return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ ok: true }) });
  });
  await p.route("**/rest/v1/rpc/tc_respond_interview_invitation", route => {
    interviewResponses++;
    interviewAccepted = true;
    return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ ok: true }) });
  });
  try {
    await p.goto(base + "/notifications.html", { waitUntil: "domcontentloaded" });
    await p.locator("[data-read='notification-smoke']").waitFor({ state: "visible" });
    await p.locator("[data-read='notification-smoke']").click();
    await p.waitForFunction(() => document.getElementById("summary")?.textContent.includes("படிக்காதவை: 0"));
    await p.locator("#markAll").click();
    await p.waitForTimeout(100);
    if (markAllCalls !== 1) throw new Error("Mark-all action called " + markAllCalls + " times; expected exactly once");
    await p.locator("[data-response='accepted']").click();
    await p.waitForFunction(() => document.getElementById("interviews")?.textContent.includes("ஏற்றுக்கொள்ளப்பட்டது"));
    if (interviewResponses !== 1) throw new Error("Interview response RPC called " + interviewResponses + " times; expected exactly once");
  } finally { await p.close(); }
});


await check("Job application submits a published vacancy with the selected resume", async () => {
  const p = await createMockSignedInPage();
  let submitted = null;
  await p.route("**/rest/v1/jobs**", route => route.fulfill({
    status: 200, contentType: "application/json",
    body: JSON.stringify({ id: "job-smoke", status: "published", job_title: "Mock Accountant", application_deadline: "2030-12-31" })
  }));
  await p.route("**/rest/v1/candidate_resumes**", route => route.fulfill({
    status: 200, contentType: "application/json",
    body: JSON.stringify([{ id: "resume-smoke", resume_title: "Candidate CV", original_file_name: "candidate.pdf", file_type: "application/pdf", file_size_bytes: 1000, created_at: "2026-11-18T10:00:00Z" }])
  }));
  await p.route("**/rest/v1/job_applications**", route => {
    if (route.request().method() === "POST") submitted = route.request().postDataJSON();
    return route.fulfill({ status: 201, contentType: "application/json", body: JSON.stringify({ id: "application-smoke" }) });
  });
  try {
    await p.goto(base + "/apply.html?job=job-smoke", { waitUntil: "domcontentloaded" });
    await p.locator("#application").waitFor({ state: "visible" });
    await p.locator("#resume").selectOption("resume-smoke");
    await p.locator("#cover").fill("I am interested in this mock vacancy.");
    await p.locator("#submit").click();
    await p.waitForFunction(() => document.getElementById("message")?.textContent.includes("வெற்றிகரமாகப் பெறப்பட்டது"));
    if (!submitted || submitted.job_id !== "job-smoke" || submitted.candidate_id !== "tc-flow-smoke-user" || submitted.resume_id !== "resume-smoke") {
      throw new Error("Application payload did not preserve the job, candidate and selected resume: " + JSON.stringify(submitted));
    }
  } finally { await p.close(); }
});

await check("Employer applicant management updates status and sends an interview invitation", async () => {
  const p = await createMockSignedInPage("employer");
  let statusUpdates = 0, interviewInvites = 0;
  await p.route("**/rest/v1/jobs**", route => route.fulfill({
    status: 200, contentType: "application/json",
    body: JSON.stringify([{ id: "job-smoke", job_title: "Mock Accountant", company_id: "smoke-company", status: "published" }])
  }));
  await p.route("**/rest/v1/job_applications**", route => route.fulfill({
    status: 200, contentType: "application/json",
    body: JSON.stringify([{ id: "application-smoke", job_id: "job-smoke", candidate_id: "candidate-smoke", resume_id: null, cover_letter: "Mock application", status: "applied", applied_at: "2026-11-18T10:00:00Z" }])
  }));
  await p.route("**/rest/v1/profiles**", route => route.fulfill({
    status: 200, contentType: "application/json",
    body: JSON.stringify({ id: "candidate-smoke", full_name: "Mock Candidate", email: "candidate@example.test", phone: "9000000000" })
  }));
  await p.route("**/rest/v1/job_seeker_profiles**", route => route.fulfill({
    status: 200, contentType: "application/json",
    body: JSON.stringify({ user_id: "candidate-smoke", headline: "Accounts Assistant", current_city: "Salem", total_experience_months: 12 })
  }));
  await p.route("**/rest/v1/rpc/tc_company_update_application_status", route => {
    statusUpdates++;
    return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ ok: true }) });
  });
  await p.route("**/rest/v1/rpc/tc_send_interview_invitation", route => {
    interviewInvites++;
    return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ ok: true }) });
  });
  try {
    await p.goto(base + "/company-applicants.html", { waitUntil: "domcontentloaded" });
    await p.locator(".app-status").waitFor({ state: "visible" });
    await p.locator(".app-status").selectOption("shortlisted");
    await p.locator(".save-app-status").click();
    await p.waitForFunction(() => document.getElementById("message")?.textContent.includes("வெற்றிகரமாகப் புதுப்பிக்கப்பட்டது"));
    if (statusUpdates !== 1) throw new Error("Application status RPC called " + statusUpdates + " times");
    const details = p.locator("#applications details").first();
    await details.locator("summary").click();
    await details.locator(".interview-date").fill("2030-01-01T10:00");
    await details.locator(".interview-mode").selectOption("online");
    await details.locator(".interview-location").fill("https://example.test/interview");
    await details.locator(".send-interview").click();
    await p.waitForFunction(() => document.querySelector(".interview-msg")?.textContent.includes("அறிவிப்பாக அனுப்பப்பட்டது"));
    if (interviewInvites !== 1) throw new Error("Interview invitation RPC called " + interviewInvites + " times");
  } finally { await p.close(); }
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

await check("Rule-based Resume job search requires login", async () => {
  await open("resume-job-search.html");
  await page.waitForFunction(() => location.pathname.endsWith("/login.html"), { timeout: 8000 });
  if (new URL(page.url()).searchParams.get("next") !== "resume-job-search.html") throw new Error("Resume search return path was not preserved");
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



await check("Every public page loads in English without visible Tamil or mobile horizontal overflow", async () => {
  const paths = [
    "about.html",
    "accept-invitation.html",
    "admin-community-posts.html",
    "admin-company-verification.html",
    "admin-control.html",
    "admin-design-studio.html",
    "admin-exam-resources.html",
    "admin-global-control.html",
    "admin-job-post.html",
    "admin-job-reports.html",
    "admin-login.html",
    "admin-security.html",
    "apply.html",
    "career-updates.html",
    "community.html",
    "company-applicants.html",
    "company-jobs.html",
    "company-members.html",
    "company-profile.html",
    "company-verification-status.html",
    "cookie-policy.html",
    "dashboard.html",
    "department-jobs.html",
    "education-government-jobs.html",
    "exam-preparation.html",
    "external-job-review.html",
    "government-exam-category.html",
    "government-exam-resource.html",
    "government-job-application-guide.html",
    "government-notice-details.html",
    "government-notice-publish.html",
    "government-notice-review.html",
    "guide-demo.html",
    "guide-style-demo.html",
    "help.html",
    "home-page-demo.html",
    "index.html",
    "indian-government-jobs.html",
    "job-details.html",
    "job-exam-center.html",
    "job-posting.html",
    "job-search-guide.html",
    "job-seeker-profile.html",
    "jobs.html",
    "login.html",
    "my-applications.html",
    "notifications.html",
    "privacy.html",
    "reset-password.html",
    "resume-documents.html",
    "resume-job-search.html",
    "saved-jobs.html",
    "state-government-jobs.html",
    "tamil-nadu-government-jobs.html",
    "terms.html"
  ];
  const auditPage = await browser.newPage({ viewport: { width: 360, height: 800 } });
  try {
    for (const path of paths) {
      const response = await auditPage.goto(base + "/" + path, { waitUntil: "domcontentloaded" });
      if (!response || !response.ok()) throw new Error(path + " returned " + (response?.status() ?? "no response"));
      const state = await auditPage.evaluate(() => ({
        title: document.title,
        lang: document.documentElement.getAttribute("lang"),
        visibleText: document.body?.innerText || "",
        width: document.documentElement.clientWidth,
        scrollWidth: document.documentElement.scrollWidth
      }));
      if (!state.title.trim()) throw new Error(path + " has no page title");
      if (state.lang !== "en") throw new Error(path + " does not declare lang=en");
      if (/[\u0B80-\u0BFF]/.test(state.visibleText)) throw new Error(path + " displays Tamil text");
      if (state.scrollWidth > state.width + 1) throw new Error(path + " overflows at 360px (" + state.scrollWidth + " > " + state.width + ")");
    }
  } finally {
    await auditPage.close();
  }
});

if (pageErrors.length) failures.push({ name: "Uncaught browser JavaScript errors", error: pageErrors.join(" | ") });
await browser.close();
console.log(JSON.stringify({ status: failures.length ? "failed" : "passed", checks: results, browser_errors: pageErrors, failures }, null, 2));
if (failures.length) process.exit(1);
