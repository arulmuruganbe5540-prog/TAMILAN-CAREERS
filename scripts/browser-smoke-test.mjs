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

await check("Job seeker and employer registration validate account details before submission", async () => {
  await open("login.html");
  await page.locator("#seeker").click();
  if (!(await page.locator("#seeker").getAttribute("class")).includes("active")) throw new Error("Job seeker role did not become active");
  await page.locator("#switchLink").click();
  await page.locator("#fullName").fill("Test Candidate");
  await page.locator("#email").fill("candidate@example.test");
  await page.locator("#password").fill("Candidate123");
  await page.locator("#confirmPassword").fill("Different123");
  const submitAndReadMessage = async () => {
    await page.locator("#authForm").evaluate(form => form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true })));
    return (await page.locator("#message").innerText()).trim();
  };
  const mismatchMessage = await submitAndReadMessage();
  if (!mismatchMessage.includes("ஒன்றாக இருக்க")) throw new Error("Password mismatch validation failed: " + mismatchMessage);
  await page.locator("#password").fill("candidate123");
  await page.locator("#confirmPassword").fill("candidate123");
  const weakPasswordMessage = await submitAndReadMessage();
  if (!weakPasswordMessage.includes("பெரிய எழுத்து")) throw new Error("Password strength validation failed: " + weakPasswordMessage);
  await page.locator("#password").fill("Candidate123");
  await page.locator("#confirmPassword").fill("Candidate123");
  const termsMessage = await submitAndReadMessage();
  if (!termsMessage.includes("விதிமுறைகள்")) throw new Error("Terms acceptance validation failed: " + termsMessage);
  await page.locator("#company").click();
  if (!(await page.locator("#company").getAttribute("class")).includes("active")) throw new Error("Employer role did not become active");
  await page.setViewportSize({ width: 320, height: 800 });
  const width = await page.evaluate(() => ({ viewport: document.documentElement.clientWidth, page: document.documentElement.scrollWidth }));
  if (width.page > width.viewport + 1) throw new Error("Login/register page overflows at 320px: " + JSON.stringify(width));
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


await check("Super Admin approves and publishes a mocked job review", async () => {
  const p = await createMockSignedInPage("super_admin");
  let reviewStatus = "pending_review", publishedJobId = null, publishCalls = 0;
  await p.addInitScript(() => {
    const key = "sb-qkmljuuusfjowexvybvy-auth-token";
    const session = JSON.parse(localStorage.getItem(key) || "{}");
    const payload = { sub: session.user?.id || "tc-flow-smoke-user", aal: "aal1", exp: Math.floor(Date.now() / 1000) + 3600 };
    session.access_token = "eyJhbGciOiJub25lIn0." + btoa(JSON.stringify(payload)) + ".mock";
    localStorage.setItem(key, JSON.stringify(session));
  });
  await p.route("**/auth/v1/factors**", route => route.fulfill({
    status: 200, contentType: "application/json", body: JSON.stringify({ all: [], totp: [] })
  }));
  await p.route("**/rest/v1/user_roles**", route => route.fulfill({
    status: 200, contentType: "application/json", body: JSON.stringify([{ role: "super_admin" }])
  }));
  await p.route("**/rest/v1/admin_job_post_reviews**", route => {
    if (route.request().method() === "GET") {
      return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify([{
        id: "review-smoke", title: "Mock Accountant Vacancy", company_name: "Smoke Test Ltd",
        status: reviewStatus, payload: { job_kind: "private" }, review_note: null,
        published_job_id: publishedJobId, created_at: "2026-11-18T10:00:00Z", updated_at: "2026-11-18T10:00:00Z"
      }]) });
    }
    if (route.request().method() === "PATCH") {
      const body = route.request().postDataJSON();
      reviewStatus = body.status || reviewStatus;
      return route.fulfill({ status: 204, body: "" });
    }
    return route.fulfill({ status: 204, body: "" });
  });
  await p.route("**/rest/v1/rpc/tc_admin_publish_job", route => {
    publishCalls++;
    reviewStatus = "approved";
    publishedJobId = "public-job-smoke";
    return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(publishedJobId) });
  });
  await p.route("**/functions/v1/google-indexing-notify**", route => route.fulfill({
    status: 200, contentType: "application/json", body: JSON.stringify({ ok: true })
  }));
  try {
    await p.goto(base + "/admin-job-post.html", { waitUntil: "domcontentloaded" });
    await p.locator("#app").waitFor({ state: "visible", timeout: 10000 });
    await p.locator('[data-action="approve"][data-id="review-smoke"]').click();
    await p.waitForFunction(() => document.getElementById("status")?.textContent.includes("Approved"));
    await p.locator('[data-action="publish"][data-id="review-smoke"]').click();
    await p.waitForFunction(() => document.getElementById("status")?.textContent.includes("வெற்றிகரமாக வெளியிடப்பட்டது"));
    if (publishCalls !== 1) throw new Error("Admin publish RPC called " + publishCalls + " times");
    if (!(await p.locator("#queue").innerText()).includes("public-job-smoke")) throw new Error("Published job ID was not shown in the Admin queue");
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


await check("Automatic Kerala language detection and dynamic Malayalam translation work", async () => {
  await page.route("https://ipapi.co/json/", route => route.fulfill({
    status: 200,
    contentType: "application/json",
    body: JSON.stringify({ country_code: "IN", region: "Kerala", timezone: "Asia/Kolkata" })
  }));
  await open("index.html");
  await page.waitForFunction(() => window.TC_LOCALE?.language === "ml", null, { timeout: 10000 });
  await page.waitForFunction(() => window.TC_TRANSLATE?.language === "ml", null, { timeout: 10000 });
  if (await page.evaluate(() => window.TC_TRANSLATE.translatedTerms) < 300) throw new Error("Active Malayalam dictionary size was reported incorrectly");
  if (!(await page.getByText("ഹോം", { exact: true }).count())) throw new Error("Homepage navigation was not translated to Malayalam");
  await page.evaluate(() => {
    const el = document.createElement("span");
    el.id = "tc-translation-dynamic-test";
    el.textContent = "Find Jobs";
    document.body.appendChild(el);
  });
  await page.waitForFunction(() => document.getElementById("tc-translation-dynamic-test")?.textContent === "ജോലി കണ്ടെത്തുക", null, { timeout: 5000 }).catch(async () => {
    const actual = await page.locator("#tc-translation-dynamic-test").textContent();
    throw new Error("Dynamic Malayalam text was not translated; actual=" + actual);
  });
  await page.evaluate(() => {
    const input = document.createElement("input");
    input.id = "tc-translation-attribute-test";
    input.placeholder = "Search Jobs";
    document.body.appendChild(input);
    input.placeholder = "Login";
    const button = document.createElement("button");
    button.id = "tc-translation-title-test";
    button.title = "Home";
    button.setAttribute("aria-label", "Find Jobs");
    document.body.appendChild(button);
  });
  await page.waitForFunction(() =>
    document.getElementById("tc-translation-attribute-test")?.placeholder === "ലോഗിൻ" &&
    document.getElementById("tc-translation-title-test")?.title === "ഹോം" &&
    document.getElementById("tc-translation-title-test")?.getAttribute("aria-label") === "ജോലി കണ്ടെത്തുക", null, { timeout: 5000 }).catch(async () => {
    const actual = await page.evaluate(() => ({
      placeholder: document.getElementById("tc-translation-attribute-test")?.placeholder,
      title: document.getElementById("tc-translation-title-test")?.title,
      ariaLabel: document.getElementById("tc-translation-title-test")?.getAttribute("aria-label"),
      language: window.TC_TRANSLATE?.language
    }));
    throw new Error("Dynamic Malayalam attributes were not translated: " + JSON.stringify(actual));
  });
  await page.evaluate(() => {
    const el = document.createElement("span");
    el.id = "tc-translation-education-test";
    el.textContent = "Degree";
    document.body.appendChild(el);
  });
  await page.waitForFunction(() => document.getElementById("tc-translation-education-test")?.textContent === "ബിരുദം", null, { timeout: 5000 });
  await page.evaluate(() => {
    const el = document.createElement("span");
    el.id = "tc-translation-admin-test";
    el.textContent = "Admin Control Center";
    document.body.appendChild(el);
  });
  await page.waitForFunction(() => document.getElementById("tc-translation-admin-test")?.textContent === "അഡ്മിൻ നിയന്ത്രണ കേന്ദ്രം", null, { timeout: 5000 });
  const clock = await page.locator("#tc-world-clock").innerText();
  if (!clock.includes("Asia/Kolkata")) throw new Error("Detected country timezone was not applied to the clock: " + clock);
  await page.unroute("https://ipapi.co/json/");
});


await check("Automatic Karnataka language detection and Kannada navigation work", async () => {
  const kannadaPage = await browser.newPage({ viewport: { width: 390, height: 844 } });
  try {
    await kannadaPage.route("https://ipapi.co/json/", route => route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ country_code: "IN", region: "Karnataka", timezone: "Asia/Kolkata" })
    }));
    const response = await kannadaPage.goto(base + "/index.html", { waitUntil: "domcontentloaded" });
    if (!response || !response.ok()) throw new Error("Karnataka homepage failed to load");
    await kannadaPage.waitForFunction(() => window.TC_LOCALE?.language === "kn" && window.TC_TRANSLATE?.language === "kn", { timeout: 10000 });
    if (!(await kannadaPage.getByText("ಮುಖಪುಟ", { exact: true }).count())) throw new Error("Homepage navigation was not translated to Kannada");
    await kannadaPage.evaluate(() => { const e=document.createElement("span"); e.id="tc-kn-job-title"; e.textContent="Job Title"; document.body.appendChild(e); });
    await kannadaPage.waitForFunction(() => document.getElementById("tc-kn-job-title")?.textContent === "ಹುದ್ದೆಯ ಹೆಸರು", { timeout: 5000 });
  } finally {
    await kannadaPage.close();
  }
});

await check("Automatic Saudi Arabia Arabic translation enables right-to-left layout", async () => {
  const arabicPage = await browser.newPage({ viewport: { width: 390, height: 844 } });
  try {
    await arabicPage.route("https://ipapi.co/json/", route => route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ country_code: "SA", region: "Riyadh", timezone: "Asia/Riyadh" })
    }));
    const response = await arabicPage.goto(base + "/index.html", { waitUntil: "domcontentloaded" });
    if (!response || !response.ok()) throw new Error("Arabic homepage failed to load");
    await arabicPage.waitForFunction(() => window.TC_LOCALE?.language === "ar" && window.TC_TRANSLATE?.language === "ar", { timeout: 10000 });
    if (await arabicPage.locator("html").getAttribute("dir") !== "rtl") throw new Error("Arabic page direction is not right-to-left");
    if (!(await arabicPage.getByText("الرئيسية", { exact: true }).count())) throw new Error("Homepage navigation was not translated to Arabic");
    await arabicPage.evaluate(() => { const e=document.createElement("span"); e.id="tc-ar-job-title"; e.textContent="Job Title"; document.body.appendChild(e); });
    await arabicPage.waitForFunction(() => document.getElementById("tc-ar-job-title")?.textContent === "المسمى الوظيفي", { timeout: 5000 });
  } finally {
    await arabicPage.close();
  }
});


await check("Saved language preference overrides automatic country language and persists", async () => {
  const preferencePage = await browser.newPage({ viewport: { width: 390, height: 844 } });
  try {
    await preferencePage.addInitScript(() => localStorage.setItem("tc_language_preference_v1", "ta"));
    await preferencePage.route("https://ipapi.co/json/", route => route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ country_code: "SA", region: "Riyadh", timezone: "Asia/Riyadh" })
    }));
    const response = await preferencePage.goto(base + "/index.html", { waitUntil: "domcontentloaded" });
    if (!response || !response.ok()) throw new Error("Language preference homepage failed to load");
    await preferencePage.waitForFunction(() => window.TC_LOCALE?.language === "ta" && window.TC_TRANSLATE?.language === "ta", { timeout: 10000 });
    if (await preferencePage.locator("#tc-language-select").inputValue() !== "ta") throw new Error("Saved language is not selected in the language menu");
    if (!(await preferencePage.getByText("முகப்பு", { exact: true }).count())) throw new Error("Saved Tamil preference was not applied to navigation");
  } finally {
    await preferencePage.close();
  }
});


await check("Homepage Tamil and English preferences, removed hero block and AdSense script", async () => {
  const tamilPage = await browser.newPage({ viewport: { width: 390, height: 844 } });
  try {
    await tamilPage.addInitScript(() => localStorage.setItem("tc_language_preference_v1", "ta"));
    await tamilPage.route("https://ipapi.co/json/", route => route.fulfill({
      status: 200, contentType: "application/json",
      body: JSON.stringify({ country_code: "IN", region: "Tamil Nadu", timezone: "Asia/Kolkata" })
    }));
    const response = await tamilPage.goto(base + "/index.html", { waitUntil: "domcontentloaded" });
    if (!response || !response.ok()) throw new Error("Tamil homepage failed to load");
    await tamilPage.waitForFunction(() => window.TC_TRANSLATE?.language === "ta", { timeout: 10000 });
    if (await tamilPage.locator(".hero-wrap").count()) throw new Error("Removed homepage hero block has returned");
    if (!(await tamilPage.getByText("வேலைவாய்ப்புகளை ஆராயுங்கள்", { exact: true }).count())) throw new Error("Homepage section heading did not translate to Tamil");
    if (!(await tamilPage.locator('script[src*="pagead2.googlesyndication.com"]').count())) throw new Error("AdSense script is missing from homepage");
  } finally { await tamilPage.close(); }
  const englishPage = await browser.newPage({ viewport: { width: 390, height: 844 } });
  try {
    await englishPage.addInitScript(() => localStorage.setItem("tc_language_preference_v1", "en"));
    await englishPage.route("https://ipapi.co/json/", route => route.fulfill({
      status: 200, contentType: "application/json",
      body: JSON.stringify({ country_code: "IN", region: "Tamil Nadu", timezone: "Asia/Kolkata" })
    }));
    const response = await englishPage.goto(base + "/index.html", { waitUntil: "domcontentloaded" });
    if (!response || !response.ok()) throw new Error("English homepage failed to load");
    await englishPage.waitForFunction(() => window.TC_TRANSLATE?.language === "en", { timeout: 10000 });
    if (!(await englishPage.getByText("Explore opportunities by country", { exact: true }).count())) throw new Error("English homepage copy is missing");
    if (!(await englishPage.getByText("Build your team with the right talent.", { exact: true }).count())) {
      throw new Error("Homepage employer heading did not return to English");
    }
  } finally { await englishPage.close(); }
});

await check("Automatic Spain locale translates newly expanded Spanish job vocabulary", async () => {
  const spanishPage = await browser.newPage({ viewport: { width: 390, height: 844 } });
  try {
    await spanishPage.route("https://ipapi.co/json/", route => route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ country_code: "ES", region: "Madrid", timezone: "Europe/Madrid" })
    }));
    const response = await spanishPage.goto(base + "/index.html", { waitUntil: "domcontentloaded" });
    if (!response || !response.ok()) throw new Error("Spain homepage failed to load");
    await spanishPage.waitForFunction(() => window.TC_LOCALE?.language === "es" && window.TC_TRANSLATE?.language === "es", { timeout: 10000 });
    await spanishPage.evaluate(() => { const e=document.createElement("span"); e.id="tc-es-job-title"; e.textContent="Job Title"; document.body.appendChild(e); });
    await spanishPage.waitForFunction(() => document.getElementById("tc-es-job-title")?.textContent === "Puesto de trabajo", { timeout: 5000 });
    await spanishPage.evaluate(() => { const e=document.createElement("span"); e.id="tc-es-employer"; e.textContent="Employer"; document.body.appendChild(e); });
    await spanishPage.waitForFunction(() => document.getElementById("tc-es-employer")?.textContent === "Empleador", { timeout: 5000 });
    await spanishPage.evaluate(() => { const e=document.createElement("span"); e.id="tc-es-tamil-source"; e.textContent="வேலை தேடுபவர்"; document.body.appendChild(e); });
    await spanishPage.waitForFunction(() => document.getElementById("tc-es-tamil-source")?.textContent === "Persona que busca empleo", { timeout: 5000 });
    await spanishPage.evaluate(() => { const e=document.createElement("span"); e.id="tc-es-tamil-profile"; e.textContent="உங்கள் பெயர்"; document.body.appendChild(e); });
    await spanishPage.waitForFunction(() => document.getElementById("tc-es-tamil-profile")?.textContent === "Tu nombre", { timeout: 5000 });
    await spanishPage.evaluate(() => { const e=document.createElement("span"); e.id="tc-es-tamil-admin"; e.textContent="அனைத்து வகைகளும்"; document.body.appendChild(e); });
    await spanishPage.waitForFunction(() => document.getElementById("tc-es-tamil-admin")?.textContent === "Todas las categorías", { timeout: 5000 });
    await spanishPage.evaluate(() => { const e=document.createElement("span"); e.id="tc-es-tamil-company"; e.textContent="குழு உறுப்பினர்கள்"; document.body.appendChild(e); });
    await spanishPage.waitForFunction(() => document.getElementById("tc-es-tamil-company")?.textContent === "Miembros del equipo", { timeout: 5000 });
  } finally {
    await spanishPage.close();
  }
});

await check("Automatic Malaysia locale translates newly expanded Malay job vocabulary", async () => {
  const malayPage = await browser.newPage({ viewport: { width: 390, height: 844 } });
  try {
    await malayPage.route("https://ipapi.co/json/", route => route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ country_code: "MY", region: "Kuala Lumpur", timezone: "Asia/Kuala_Lumpur" })
    }));
    const response = await malayPage.goto(base + "/index.html", { waitUntil: "domcontentloaded" });
    if (!response || !response.ok()) throw new Error("Malaysia homepage failed to load");
    await malayPage.waitForFunction(() => window.TC_LOCALE?.language === "ms" && window.TC_TRANSLATE?.language === "ms", { timeout: 10000 });
    await malayPage.evaluate(() => { const e=document.createElement("span"); e.id="tc-ms-job-title"; e.textContent="Job Title"; document.body.appendChild(e); });
    await malayPage.waitForFunction(() => document.getElementById("tc-ms-job-title")?.textContent === "Jawatan", { timeout: 5000 });
    await malayPage.evaluate(() => { const e=document.createElement("span"); e.id="tc-ms-employer"; e.textContent="Employer"; document.body.appendChild(e); });
    await malayPage.waitForFunction(() => document.getElementById("tc-ms-employer")?.textContent === "Majikan", { timeout: 5000 });
    await malayPage.evaluate(() => { const e=document.createElement("span"); e.id="tc-ms-tamil-source"; e.textContent="வேலை தேடுபவர்"; document.body.appendChild(e); });
    await malayPage.waitForFunction(() => document.getElementById("tc-ms-tamil-source")?.textContent === "Pencari Kerja", { timeout: 5000 });
    await malayPage.evaluate(() => { const e=document.createElement("span"); e.id="tc-ms-tamil-profile"; e.textContent="உங்கள் பெயர்"; document.body.appendChild(e); });
    await malayPage.waitForFunction(() => document.getElementById("tc-ms-tamil-profile")?.textContent === "Nama Anda", { timeout: 5000 });
    await malayPage.evaluate(() => { const e=document.createElement("span"); e.id="tc-ms-tamil-admin"; e.textContent="அனைத்து வகைகளும்"; document.body.appendChild(e); });
    await malayPage.waitForFunction(() => document.getElementById("tc-ms-tamil-admin")?.textContent === "Semua Kategori", { timeout: 5000 });
    await malayPage.evaluate(() => { const e=document.createElement("span"); e.id="tc-ms-tamil-company"; e.textContent="குழு உறுப்பினர்கள்"; document.body.appendChild(e); });
    await malayPage.waitForFunction(() => document.getElementById("tc-ms-tamil-company")?.textContent === "Ahli Pasukan", { timeout: 5000 });
  } finally {
    await malayPage.close();
  }
});

if (pageErrors.length) failures.push({ name: "Uncaught browser JavaScript errors", error: pageErrors.join(" | ") });
await browser.close();
console.log(JSON.stringify({ status: failures.length ? "failed" : "passed", checks: results, browser_errors: pageErrors, failures }, null, 2));
if (failures.length) process.exit(1);
