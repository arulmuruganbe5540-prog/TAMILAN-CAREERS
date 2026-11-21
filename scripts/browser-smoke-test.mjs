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
    organization: JSON.parse(document.querySelector("#tc-organization-jsonld")?.textContent || "null"),
    canonicalUrl: document.querySelector('link[rel="canonical"]')?.href || ""
  }));
  if (structuredData.website?.["@type"] !== "WebSite" || structuredData.organization?.["@type"] !== "Organization" ||
      structuredData.organization?.email !== "arulmuruganbe5540@gmail.com" || structuredData.organization?.url !== (structuredData.canonicalUrl || new URL(base).origin + "/")) {
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
  if (layout.visibleText.includes("your country detected") || false) {
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

await check("Private job search filters have accessible names", async () => {
  await open("private-jobs.html");
  const missing = await page.evaluate(() => ["#q", "#type", "#place", "#workplace", "#education", "#skillMatch"]
    .filter(selector => {
      const el = document.querySelector(selector);
      return !el || !(el.getAttribute("aria-label") || el.labels?.length || el.getAttribute("title"));
    }));
  if (missing.length) throw new Error("Job search controls are missing accessible labels: " + missing.join(", "));
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


await check("Login defaults to Login, Register stays on the same page, and the domain wordmark is text-only", async () => {
  await open("login.html");
  await page.locator(".tc-login-wordmark").waitFor({ state: "visible", timeout: 10000 });
  if (!(await page.locator("#heading").innerText()).includes("Login")) throw new Error("Login is not the default mode");
  if (await page.locator("#nameField").isVisible()) throw new Error("Registration fields should be hidden until Register is selected");
  if ((await page.locator("#switchLink").innerText()).trim() !== "Register") throw new Error("Register switch is not visible on the login page");
  if (await page.locator(".card img, .tc-premium-login-brand img").count()) throw new Error("Login page still contains a photo/banner logo");
  if ((await page.locator(".tc-login-wordmark").innerText()).trim() !== "WWW.TAMILANCAREERS.IN") throw new Error("Login wordmark text is incorrect");
  if (await page.locator("#tc-globalbar, body > footer.tc-footer").count()) throw new Error("Authentication page should not show the global information bar or full site footer");
  await open("login.html?mode=register");
  if (!(await page.locator("#heading").innerText()).includes("Create a new account")) throw new Error("Homepage Register link does not open the in-page registration mode");
  if (!(await page.locator("#nameField").isVisible())) throw new Error("Register mode did not reveal the name field");
  await open("index.html");
  await page.locator(".site-header .tc-premium-wordmark").waitFor({ state: "visible", timeout: 10000 });
  if ((await page.locator(".site-header .tc-premium-wordmark").innerText()).trim() !== "WWW.TAMILANCAREERS.IN") throw new Error("Homepage header wordmark is incorrect");
  if (await page.locator(".site-header .tc-premium-header-brand img").count()) throw new Error("Homepage logo still uses an image");
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
await check("Login rejects invalid credentials and opens the Job Seeker dashboard on success", async () => {
  const authPage = await browser.newPage({ viewport: { width: 390, height: 844 } });
  const testUser = {
    id: "smoke-job-seeker-user", aud: "authenticated", role: "authenticated",
    email: "candidate@example.test",
    app_metadata: { provider: "email", providers: ["email"] },
    user_metadata: { full_name: "Test Candidate" }, identities: [],
    created_at: new Date().toISOString(), updated_at: new Date().toISOString()
  };
  try {
    await authPage.route("**/auth/v1/token*", async route => {
      const body = route.request().postDataJSON();
      if (body.password !== "Candidate123") {
        await route.fulfill({ status: 400, contentType: "application/json", body: JSON.stringify({ code: "invalid_credentials", msg: "Invalid login credentials" }) });
        return;
      }
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({
        access_token: "smoke-access-token", token_type: "bearer", expires_in: 3600,
        expires_at: Math.floor(Date.now() / 1000) + 3600, refresh_token: "smoke-refresh-token", user: testUser
      })});
    });
    await authPage.route("**/rest/v1/user_roles*", route => route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ role: "job_seeker" }) }));
    await authPage.route("**/rest/v1/company_members*", route => route.fulfill({ status: 200, contentType: "application/json", body: "[]" }));
    await authPage.route("**/rest/v1/tc_notifications*", route => route.fulfill({ status: 200, headers: { "content-range": "0-0/0" }, body: "" }));
    await authPage.goto(base + "/login.html", { waitUntil: "domcontentloaded" });
    await authPage.locator("#email").fill("candidate@example.test");
    await authPage.locator("#password").fill("WrongPass123");
    await authPage.locator("#authForm").evaluate(form => form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true })));
    await authPage.waitForFunction(() => document.querySelector("#message")?.textContent.includes("Invalid login credentials"), { timeout: 8000 });
    await authPage.locator("#password").fill("Candidate123");
    await authPage.locator("#authForm").evaluate(form => form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true })));
    await authPage.waitForURL(/dashboard\.html$/, { timeout: 10000 });
    await authPage.locator("#seekerArea:not(.hidden)").waitFor({ state: "visible", timeout: 8000 });
    if (!(await authPage.locator("#welcomeText").innerText()).includes("Job Seeker")) throw new Error("Job Seeker account type is not shown on the dashboard");
    if (await authPage.locator("#companyArea").isVisible()) throw new Error("Job Seeker was incorrectly shown the Company workspace");
    if (/[\u0B80-\u0BFF]/.test(await authPage.locator("body").innerText())) throw new Error("Login or dashboard displayed Tamil text");
  } finally { await authPage.close(); }
});

await check("Company signup accounts can reach company registration before membership approval", async () => {
  const companyPage = await browser.newPage({ viewport: { width: 390, height: 844 } });
  const user = {
    id: "smoke-company-user", aud: "authenticated", role: "authenticated",
    email: "company@example.test", app_metadata: { provider: "email", providers: ["email"] },
    user_metadata: { full_name: "Test Company" }, identities: [],
    created_at: new Date().toISOString(), updated_at: new Date().toISOString()
  };
  try {
    await companyPage.addInitScript(sessionUser => {
      localStorage.setItem("sb-qkmljuuusfjowexvybvy-auth-token", JSON.stringify({
        access_token: "smoke-company-access-token", token_type: "bearer", expires_in: 3600,
        expires_at: Math.floor(Date.now() / 1000) + 3600, refresh_token: "smoke-company-refresh-token", user: sessionUser
      }));
    }, user);
    await companyPage.route("**/rest/v1/user_roles*", route => route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ role: "company_member" }) }));
    await companyPage.route("**/rest/v1/company_members*", route => route.fulfill({ status: 200, contentType: "application/json", body: "[]" }));
    await companyPage.route("**/rest/v1/tc_notifications*", route => route.fulfill({ status: 200, headers: { "content-range": "0-0/0" }, body: "" }));
    await companyPage.goto(base + "/dashboard.html", { waitUntil: "domcontentloaded" });
    await companyPage.locator("#companyArea:not(.hidden)").waitFor({ state: "visible", timeout: 8000 });
    if (!(await companyPage.locator("#companyDetailsCard a[href='company-profile.html']").isVisible())) throw new Error("Company registration link is not available to a new company account");
    if (!(await companyPage.locator("#companyNames").innerText()).includes("Register your company")) throw new Error("Company setup instructions are missing");
    for (const id of ["companyPostJobCard","companyManageJobsCard","companyTeamCard","companyApplicantsCard"]) {
      if (await companyPage.locator("#" + id).isVisible()) throw new Error("Unapproved company account can access a member-only card: " + id);
    }
  } finally { await companyPage.close(); }
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

await check("Empty job board clearly explains that no verified vacancies are published yet", async () => {
  const emptyPage = await browser.newPage({ viewport: { width: 390, height: 844 } });
  try {
    await emptyPage.route("**/rest/v1/private_jobs**", route => route.fulfill({status:200,contentType:"application/json",body:"[]"}));
    await emptyPage.goto(base + "/private-jobs.html", {waitUntil:"domcontentloaded"});
    await emptyPage.locator("#results .empty").waitFor({state:"visible",timeout:10000});
    const message=await emptyPage.locator("#results .empty").innerText();
    if(!message.includes("No verified job vacancies have been published yet")) throw new Error("Empty job board message is unclear: "+message);
  } finally { await emptyPage.close(); }
});

await check("Private job search filters work without AI controls", async () => {
  await open("private-jobs.html");
  for (const selector of ["#q", "#type", "#place", "#workplace", "#education"]) {
    if (!(await page.locator(selector).isVisible())) throw new Error("Private job search control is missing: " + selector);
  }
  if (await page.locator("#aiSearch").count()) throw new Error("An AI search control must not be shown");
  await page.locator("#q").fill("accountant");
  await page.locator("#place").fill("Salem");
  await page.locator("#type").selectOption("Full Time");
  if (!(await page.locator("#count").innerText()).includes("job")) throw new Error("Rule-based filters did not refresh the result count");
});

await check("Multi-word job search matches every entered keyword", async () => {
  await page.route("**/rest/v1/private_jobs**", route => route.fulfill({
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
    await open("private-jobs.html");
    await page.waitForFunction(() => document.getElementById("count")?.textContent.includes("1 job found"));
    await page.locator("#q").fill("accountant excel");
    if (!(await page.locator("#count").innerText()).includes("1 job found")) {
      throw new Error("A job matching both keywords was not found");
    }
    await page.locator("#q").fill("accountant missingword");
    if (!(await page.locator("#count").innerText()).includes("0 jobs found")) {
      throw new Error("Search should require every entered keyword to match");
    }
  } finally {
    await page.unroute("**/rest/v1/jobs**");
  }
});

await check("Education and workplace filters narrow jobs correctly", async () => {
  await page.route("**/rest/v1/private_jobs**", route => route.fulfill({
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
    await open("private-jobs.html");
    await page.waitForFunction(() => document.documentElement.lang === "en");
    await page.waitForFunction(() => document.getElementById("count")?.textContent.includes("1 job found"));
    await page.locator("#education").selectOption("ITI");
    if (!(await page.locator("#count").innerText()).includes("1 job found")) throw new Error("ITI qualification filter did not match");
    await page.locator("#workplace").selectOption("remote");
    if (!(await page.locator("#count").innerText()).includes("1 job found")) throw new Error("Remote workplace filter did not match");
    await page.locator("#education").selectOption("Degree");
    if (!(await page.locator("#count").innerText()).includes("0 jobs found")) throw new Error("Non-matching education should return no results");
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
  await skillPage.route("**/rest/v1/private_jobs**", route => route.fulfill({
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
    const response = await skillPage.goto(base + "/private-jobs.html", { waitUntil: "domcontentloaded" });
    if (!response || !response.ok()) throw new Error("Jobs page failed to load");
    await skillPage.waitForFunction(() => document.getElementById("count")?.textContent.includes("2 jobs found"));
    await skillPage.locator("#skillMatch").selectOption("matched");
    await skillPage.waitForFunction(() => document.getElementById("count")?.textContent.includes("1 job found"));
    if (!(await skillPage.locator(".job").innerText()).includes("Your skills: 1/2 match")) {
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
    await p.waitForFunction(() => document.getElementById("notice")?.textContent.includes("saved to the database"));
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
    await p.waitForFunction(() => document.getElementById("notice")?.textContent.includes("securely uploaded"));
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
    if (!salaryMessage.includes("Maximum salary cannot be lower")) throw new Error("Invalid salary range was not rejected; status=" + salaryMessage + "; form=" + JSON.stringify(formState));
    await p.locator("#salaryMin").fill("10000");
    await p.locator("#salaryMax").fill("20000");
    await p.locator("#saveBtn").click();
    await p.waitForFunction(() => document.getElementById("status")?.textContent.includes("saved securely as a private draft"));
    await p.locator("#submitReviewBtn").click();
    await p.waitForFunction(() => document.getElementById("status")?.textContent.includes("sent for Admin Review"));
    if (!calls.includes("tc_submit_company_job_draft_for_review")) throw new Error("Job draft was not sent to the review RPC");
  } finally { await p.close(); }
});


await check("Saved jobs sync with the signed-in Job Seeker account", async () => {
  const savedPage = await browser.newPage({ viewport: { width: 390, height: 844 } });
  const user = { id: "smoke-saved-jobs-user", aud: "authenticated", role: "authenticated", email: "candidate@example.test", app_metadata: {}, user_metadata: {} };
  let deleteCalled = false;
  try {
    await savedPage.addInitScript(sessionUser => {
      localStorage.setItem("sb-qkmljuuusfjowexvybvy-auth-token", JSON.stringify({
        access_token: "smoke-saved-access", refresh_token: "smoke-saved-refresh",
        token_type: "bearer", expires_in: 3600, expires_at: Math.floor(Date.now()/1000)+3600, user: sessionUser
      }));
      localStorage.setItem("tc_saved_jobs_v1", JSON.stringify([{id:"123e4567-e89b-12d3-a456-426614174000",title:"Guest Saved Role"}]));
    }, user);
    await savedPage.route("**/rest/v1/user_roles**", route => route.fulfill({status:200,contentType:"application/json",body:JSON.stringify({role:"job_seeker"})}));
    await savedPage.route("**/rest/v1/job_seeker_profiles**", route => route.fulfill({status:200,contentType:"application/json",body:JSON.stringify({user_id:user.id})}));
    let upsertCalled=false;
    await savedPage.route("**/rest/v1/candidate_saved_jobs**", route => {
      if(route.request().method()==="POST"){upsertCalled=true;return route.fulfill({status:201,contentType:"application/json",body:"[]"});}
      if(route.request().method()==="DELETE"){deleteCalled=true;return route.fulfill({status:204,body:""});}
      return route.fulfill({status:200,contentType:"application/json",body:JSON.stringify([{job_id:"123e4567-e89b-12d3-a456-426614174000",saved_at:new Date().toISOString()}])});
    });
    await savedPage.route("**/rest/v1/private_jobs**", route => route.fulfill({status:200,contentType:"application/json",body:JSON.stringify([{id:"123e4567-e89b-12d3-a456-426614174000",job_title:"Frontend Developer",location:"Remote",employment_type:"Full Time",status:"published",application_deadline:"2099-12-31",company_id:"saved-company-1"}])}));
    await savedPage.route("**/rest/v1/government_jobs**", route => route.fulfill({status:200,contentType:"application/json",body:"[]"}));
    await savedPage.route("**/rest/v1/international_jobs**", route => route.fulfill({status:200,contentType:"application/json",body:"[]"}));
    await savedPage.route("**/rest/v1/jobs**", route => route.fulfill({status:200,contentType:"application/json",body:"[]"}));
    await savedPage.route("**/rest/v1/companies**", route => route.fulfill({status:200,contentType:"application/json",body:JSON.stringify([{id:"saved-company-1",company_name:"Example Company"}])}));
    await savedPage.goto(base + "/saved-jobs.html", {waitUntil:"domcontentloaded"});
    await savedPage.locator(".job h2").waitFor({state:"visible",timeout:10000});
    const visible=await savedPage.locator("main").innerText();
    if(!visible.includes("Frontend Developer")||!visible.includes("Example Company")||!visible.includes("Apply / Official Link")) throw new Error("Account-saved job details or direct application link did not render");
    await savedPage.locator("[data-remove]").click();
    await savedPage.locator(".empty").waitFor({state:"visible",timeout:10000});
    if(!upsertCalled) throw new Error("Guest saved jobs were not migrated into the account");
    if(!deleteCalled) throw new Error("Removing a saved job did not call the account storage delete endpoint");
  } finally { await savedPage.close(); }
});

await check("Legacy Tamil notification content is presented in English", async () => {
  const notificationPage = await browser.newPage({ viewport: { width: 390, height: 844 } });
  const user = { id: "smoke-notification-user", aud: "authenticated", role: "authenticated", email: "candidate@example.test", app_metadata: {}, user_metadata: {} };
  try {
    await notificationPage.addInitScript(sessionUser => {
      localStorage.setItem("sb-qkmljuuusfjowexvybvy-auth-token", JSON.stringify({
        access_token: "smoke-notification-access", refresh_token: "smoke-notification-refresh",
        token_type: "bearer", expires_in: 3600, expires_at: Math.floor(Date.now()/1000)+3600, user: sessionUser
      }));
    }, user);
    await notificationPage.route("**/rest/v1/tc_notifications**", route => route.fulfill({
      status: 200, contentType: "application/json",
      body: JSON.stringify([{ id:"legacy-notice-1", notification_type:"application_status",
        title:"\u0baa\u0bc1\u0ba4\u0bbf\u0baf \u0bb5\u0bc7\u0bb2\u0bc8 \u0bb5\u0bbf\u0ba3\u0bcd\u0ba3\u0baa\u0bcd\u0baa\u0bae\u0bcd \u0bb5\u0ba8\u0bcd\u0ba4\u0bc1\u0bb3\u0bcd\u0bb3\u0ba4\u0bc1", body:"Example Company \u2014 Software Engineer \u0baa\u0ba3\u0bbf\u0b95\u0bcd\u0b95\u0bc1 \u0baa\u0bc1\u0ba4\u0bbf\u0baf \u0bb5\u0bbf\u0ba3\u0bcd\u0ba3\u0baa\u0bcd\u0baa\u0bae\u0bcd \u0bb5\u0ba8\u0bcd\u0ba4\u0bc1\u0bb3\u0bcd\u0bb3\u0ba4\u0bc1.", is_read:false, created_at:new Date().toISOString() }])
    }));
    await notificationPage.route("**/rest/v1/tc_interview_invitations**", route => route.fulfill({status:200,contentType:"application/json",body:"[]"}));
    await notificationPage.route("**/rest/v1/private_job_interview_invitations**", route => route.fulfill({status:200,contentType:"application/json",body:"[]"}));
    await notificationPage.route("**/rest/v1/international_job_interview_invitations**", route => route.fulfill({status:200,contentType:"application/json",body:"[]"}));
    await notificationPage.route("**/rest/v1/user_roles**", route => route.fulfill({status:200,contentType:"application/json",body:JSON.stringify({role:"job_seeker"})}));
    await notificationPage.goto(base + "/notifications.html", { waitUntil:"domcontentloaded" });
    await notificationPage.locator("#notifications .item h3").waitFor({state:"visible",timeout:10000});
    const visible = await notificationPage.locator("#notifications").innerText();
    if (/[\u0B80-\u0BFF]/.test(visible)) throw new Error("Tamil text is visible in the notification center");
    if (!visible.includes("New job application received") || !visible.includes("Example Company")) {
      throw new Error("Legacy notification was not translated correctly: " + visible);
    }
  } finally { await notificationPage.close(); }
});

await check("Notifications mark-read, mark-all and interview responses call each RPC once", async () => {
  const p = await createMockSignedInPage();
  let isRead = false, markAllCalls = 0, interviewResponses = 0, interviewAccepted = false;
  await p.route("**/rest/v1/tc_notifications**", route => route.fulfill({
    status: 200, contentType: "application/json",
    body: JSON.stringify([{ id: "notification-smoke", notification_type: "application_status", title: "Application update", body: "Your application is under review", related_application_id: "application-smoke", related_interview_id: null, is_read: isRead, created_at: "2026-11-18T10:00:00Z" }])
  }));
  await p.route("**/rest/v1/private_job_interview_invitations**", route => route.fulfill({status:200,contentType:"application/json",body:"[]"}));
  await p.route("**/rest/v1/international_job_interview_invitations**", route => route.fulfill({status:200,contentType:"application/json",body:"[]"}));
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
    await p.waitForFunction(() => document.getElementById("summary")?.textContent.includes("Unread: 0"));
    await p.locator("#markAll").click();
    await p.waitForTimeout(100);
    if (markAllCalls !== 1) throw new Error("Mark-all action called " + markAllCalls + " times; expected exactly once");
    await p.locator("[data-response='accepted']").click();
    await p.waitForFunction(() => document.getElementById("interviews")?.textContent.includes("Accepted"));
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
    await p.waitForFunction(() => document.getElementById("message")?.textContent.includes("submitted successfully"));
    if (!submitted || submitted.job_id !== "job-smoke" || submitted.candidate_id !== "tc-flow-smoke-user" || submitted.resume_id !== "resume-smoke") {
      throw new Error("Application payload did not preserve the job, candidate and selected resume: " + JSON.stringify(submitted));
    }
  } finally { await p.close(); }
});

await check("Employer applicant management updates independent Private application status", async () => {
  const p = await createMockSignedInPage("employer");
  let statusUpdates = 0;
  await p.route("**/rest/v1/private_jobs**", route => route.fulfill({
    status: 200, contentType: "application/json",
    body: JSON.stringify([{ id: "job-smoke", job_title: "Mock Accountant", company_id: "smoke-company", status: "published" }])
  }));
  await p.route("**/rest/v1/private_job_interview_invitations**", route => route.fulfill({status:200,contentType:"application/json",body:"[]"}));
  await p.route("**/rest/v1/private_job_applications**", route => route.fulfill({
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
  await p.route("**/rest/v1/rpc/tc_company_update_private_application_status", route => {
    statusUpdates++;
    return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ ok: true }) });
  });
  try {
    await p.goto(base + "/company-applicants.html", { waitUntil: "domcontentloaded" });
    await p.locator(".app-status").waitFor({ state: "visible" });
    await p.locator(".app-status").selectOption("shortlisted");
    await p.locator(".save-app-status").click();
    await p.waitForFunction(() => document.getElementById("message")?.textContent.includes("updated successfully"));
    if (statusUpdates !== 1) throw new Error("Independent Private application status RPC called " + statusUpdates + " times");
    if (await p.locator(".send-interview").count()) throw new Error("Legacy interview workflow must not be attached to independent Private applications");
    await p.locator(".app details summary").first().click();
    await p.locator(".send-independent-interview").waitFor({state:"visible"});
    if (!(await p.locator(".send-independent-interview").count())) throw new Error("Independent Private interview invitation form did not render");
    if (await p.locator(".ind-int-zone").inputValue() !== "Asia/Kolkata") throw new Error("Private interview default time zone is incorrect");
  } finally { await p.close(); }
});



await check("Employer can propose a new Private interview time and make a final selection", async () => {
  const p = await createMockSignedInPage("employer");
  let rescheduleCalls = 0, finaliseCalls = 0;
  p.on("dialog", dialog => dialog.accept());
  await p.route("**/rest/v1/private_jobs**", route => route.fulfill({status:200,contentType:"application/json",body:JSON.stringify([{id:"private-job-smoke",job_title:"Private Analyst",company_id:"smoke-company",status:"published"}])}));
  await p.route("**/rest/v1/private_job_applications**", route => route.fulfill({status:200,contentType:"application/json",body:JSON.stringify([{id:"private-app-smoke",job_id:"private-job-smoke",candidate_id:"candidate-smoke",resume_id:null,status:"shortlisted",applied_at:"2026-11-20T10:00:00Z"}])}));
  await p.route("**/rest/v1/private_job_interview_invitations**", route => route.fulfill({status:200,contentType:"application/json",body:JSON.stringify([{id:"private-interview-smoke",application_id:"private-app-smoke",interview_title:"Technical Interview",scheduled_at:"2030-01-01T10:00:00Z",timezone:"Asia/Kolkata",duration_minutes:45,interview_mode:"online",meeting_url:"https://meet.example.test/current",status:"accepted"}])}));
  await p.route("**/rest/v1/private_job_interview_reschedule_proposals**", route => route.fulfill({status:200,contentType:"application/json",body:"[]"}));
  await p.route("**/rest/v1/private_job_interview_history**", route => route.fulfill({status:200,contentType:"application/json",body:"[]"}));
  await p.route("**/rest/v1/rpc/tc_company_propose_private_interview_reschedule", route => {rescheduleCalls++;return route.fulfill({status:200,contentType:"application/json",body:JSON.stringify("proposal-smoke")});});
  await p.route("**/rest/v1/rpc/tc_company_finalise_private_application", route => {finaliseCalls++;return route.fulfill({status:200,contentType:"application/json",body:JSON.stringify("selected")});});
  try {
    await p.goto(base+"/company-applicants.html",{waitUntil:"domcontentloaded"});
    await p.locator(".app details summary").first().click();
    await p.locator("details details summary").first().click();
    await p.locator(".reschedule-date").fill("2030-01-02T11:00");
    await p.locator(".reschedule-zone").fill("Asia/Kolkata");
    await p.locator(".reschedule-mode").selectOption("online");
    await p.locator(".reschedule-url").fill("https://meet.example.test/new");
    await p.locator(".propose-interview-reschedule").click();
    await p.waitForFunction(()=>document.getElementById("message")?.textContent.includes("current schedule remains unchanged"));
    if(rescheduleCalls!==1)throw new Error("Private interview reschedule RPC was not called exactly once");
    await p.locator('.finalise-app[data-final-status="selected"]').click();
    await p.waitForFunction(()=>document.getElementById("message")?.textContent.includes("candidate notified"));
    if(finaliseCalls!==1)throw new Error("Private final-selection RPC was not called exactly once");
  } finally { await p.close(); }
});

await check("Candidate can propose an alternative date for an accepted Private interview", async () => {
  const p=await createMockSignedInPage();
  let proposalCalls=0,proposalPayload=null;
  await p.route("**/rest/v1/tc_notifications**",route=>route.fulfill({status:200,contentType:"application/json",body:"[]"}));
  await p.route("**/rest/v1/tc_interview_invitations**",route=>route.fulfill({status:200,contentType:"application/json",body:"[]"}));
  await p.route("**/rest/v1/private_job_interview_invitations**",route=>route.fulfill({status:200,contentType:"application/json",body:JSON.stringify([{id:"candidate-private-interview",application_id:"candidate-app",candidate_id:"tc-flow-smoke-user",interview_title:"Private Interview",scheduled_at:"2030-01-01T10:00:00Z",timezone:"Asia/Kolkata",duration_minutes:45,interview_mode:"online",meeting_url:"https://meet.example.test/current",status:"accepted",job:{job_title:"Private Analyst"},company:{company_name:"Private Co"}}])}));
  await p.route("**/rest/v1/international_job_interview_invitations**",route=>route.fulfill({status:200,contentType:"application/json",body:"[]"}));
  await p.route("**/rest/v1/private_job_interview_reschedule_proposals**",route=>route.fulfill({status:200,contentType:"application/json",body:"[]"}));
  await p.route("**/rest/v1/international_job_interview_reschedule_proposals**",route=>route.fulfill({status:200,contentType:"application/json",body:"[]"}));
  await p.route("**/rest/v1/rpc/tc_candidate_propose_private_interview_date",route=>{proposalCalls++;proposalPayload=route.request().postDataJSON();return route.fulfill({status:200,contentType:"application/json",body:JSON.stringify("candidate-proposal")});});
  try{
    await p.goto(base+"/notifications.html",{waitUntil:"domcontentloaded"});
    await p.getByText("Private Interview",{exact:true}).waitFor({state:"visible"});
    await p.locator("details summary").filter({hasText:"Propose Another Interview Date"}).click();
    await p.locator('[data-alt-date="candidate-private-interview"]').fill("2030-01-03T11:00");
    await p.locator('[data-alt-zone="candidate-private-interview"]').fill("Asia/Kolkata");
    const proposalResponse=p.waitForResponse(response=>response.url().includes("/rpc/tc_candidate_propose_private_interview_date"));
    await p.locator('[data-propose-alt="candidate-private-interview"]').click();
    await proposalResponse;
    if(proposalCalls!==1||proposalPayload?.p_interview_id!=="candidate-private-interview"||proposalPayload?.p_interview_mode!=="online")throw new Error("Candidate alternative-date proposal did not preserve the interview details");
  }finally{await p.close()}
});

await check("Private and International interview invitations display and candidate responses use separate RPCs", async () => {
  const p = await createMockSignedInPage();
  let privateStatus="pending", internationalStatus="pending", privateCalls=0, internationalCalls=0;
  await p.route("**/rest/v1/tc_notifications**", route => route.fulfill({status:200,contentType:"application/json",body:"[]"}));
  await p.route("**/rest/v1/tc_interview_invitations**", route => route.fulfill({status:200,contentType:"application/json",body:"[]"}));
  await p.route("**/rest/v1/user_roles**", route => route.fulfill({status:200,contentType:"application/json",body:JSON.stringify({role:"job_seeker"})}));
  await p.route("**/rest/v1/private_job_interview_invitations**", route => route.fulfill({
    status:200,contentType:"application/json",
    body:JSON.stringify([{id:"private-interview",application_id:"private-app",job_id:"private-job",candidate_id:"candidate-smoke",interview_title:"Private Interview",scheduled_at:"2030-01-01T10:00:00Z",timezone:"Asia/Kolkata",duration_minutes:45,interview_mode:"online",meeting_url:"https://meet.example.test/p",invitation_message:"Private invitation",status:privateStatus,job:{job_title:"Private Accountant"},company:{company_name:"Private Co"}}])
  }));
  await p.route("**/rest/v1/international_job_interview_invitations**", route => route.fulfill({
    status:200,contentType:"application/json",
    body:JSON.stringify([{id:"international-interview",application_id:"international-app",job_id:"international-job",candidate_id:"candidate-smoke",interview_title:"International Interview",scheduled_at:"2030-02-01T10:00:00Z",timezone:"Europe/London",duration_minutes:60,interview_mode:"online",meeting_url:"https://meet.example.test/i",invitation_message:"International invitation",status:internationalStatus,job:{job_title:"International Analyst"},company:{company_name:"Global Co"}}])
  }));
  await p.route("**/rest/v1/rpc/tc_candidate_respond_private_interview", route => {
    privateCalls++;privateStatus="accepted";
    return route.fulfill({status:200,contentType:"application/json",body:JSON.stringify("accepted")});
  });
  await p.route("**/rest/v1/rpc/tc_candidate_respond_international_interview", route => {
    internationalCalls++;internationalStatus="declined";
    return route.fulfill({status:200,contentType:"application/json",body:JSON.stringify("declined")});
  });
  try{
    await p.goto(base+"/notifications.html",{waitUntil:"domcontentloaded"});
    await p.getByText("Private Interview",{exact:true}).waitFor({state:"visible"});
    await p.getByText("International Interview",{exact:true}).waitFor({state:"visible"});
    await p.locator('[data-response="accepted"][data-system="private"]').click();
    await p.waitForFunction(()=>document.getElementById("interviews")?.innerText.includes("Accepted"));
    await p.locator('[data-response="declined"][data-system="international"]').click();
    await p.waitForFunction(()=>document.getElementById("interviews")?.innerText.includes("declined"));
    if(privateCalls!==1||internationalCalls!==1)throw new Error("Private/International candidate response RPCs were not called exactly once each");
  }finally{await p.close()}
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
  await page.waitForFunction(() => document.getElementById("status")?.textContent.toLowerCase().includes("token"), { timeout: 8000 });
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
      () => document.getElementById("content")?.textContent.includes("application period for this job has ended"),
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
  auditPage.setDefaultNavigationTimeout(10000);
  await auditPage.route("**/*", route => {
    const requestUrl = new URL(route.request().url());
    return requestUrl.origin === new URL(base).origin ? route.continue() : route.abort();
  });
  try {
    const pageFailures = [];
    for (const path of paths) {
      try {
        const response = await auditPage.goto(base + "/" + path, { waitUntil: "domcontentloaded" });
        if (!response || !response.ok()) throw new Error(path + " returned " + (response?.status() ?? "no response"));
        const state = await auditPage.evaluate(() => ({
          title: document.title,
          lang: document.documentElement.getAttribute("lang"),
          visibleText: document.body?.innerText || "",
          width: document.documentElement.clientWidth,
          scrollWidth: document.documentElement.scrollWidth,
          overflowElements: [...document.querySelectorAll("body *")].map(el => { const rect = el.getBoundingClientRect(); return {tag:el.tagName,id:el.id,className:typeof el.className==="string"?el.className:"",left:Math.round(rect.left),right:Math.round(rect.right),width:Math.round(rect.width)}; }).filter(el => el.right > document.documentElement.clientWidth + 1 || el.left < -1).slice(0,15),
          languageControls: document.querySelectorAll("#tc-language-select,[data-language-selector]").length,
          clippedControls: [...document.querySelectorAll("a,button,input,select,textarea,h1,h2")].filter(el => {
            const style = getComputedStyle(el);
            const rect = el.getBoundingClientRect();
            if (style.display === "none" || style.visibility === "hidden" || rect.width <= 0) return false;
            for (let parent = el.parentElement; parent && parent !== document.body; parent = parent.parentElement) {
              const ps = getComputedStyle(parent);
              // A horizontal auto/scroll container is intentionally navigable (for example, a responsive data table).
              // Do not treat its scrollable content as clipped by an outer decorative overflow-hidden card.
              if (/(auto|scroll)/.test(ps.overflowX)) break;
              if (/(hidden|clip)/.test(ps.overflowX) && (rect.left < parent.getBoundingClientRect().left - 1 || rect.right > parent.getBoundingClientRect().right + 1)) return true;
            }
            return false;
          }).slice(0, 8).map(el => ({ tag: el.tagName, id: el.id, text: (el.innerText || el.getAttribute("aria-label") || "").trim().slice(0, 60) }))
        }));
        if (!state.title.trim()) throw new Error(path + " has no page title");
        if (state.lang !== "en") throw new Error(path + " does not declare lang=en");
        if (/[\u0B80-\u0BFF]/.test(state.visibleText)) throw new Error(path + " displays Tamil text");
        if (state.scrollWidth > state.width + 1) throw new Error(path + " overflows at 360px (" + state.scrollWidth + " > " + state.width + "): " + JSON.stringify(state.overflowElements));
        if (state.languageControls) throw new Error(path + " still displays a language selector");
        if (state.clippedControls.length) throw new Error(path + " has clipped controls or headings: " + JSON.stringify(state.clippedControls));
        await auditPage.setViewportSize({ width: 1280, height: 900 });
        const desktop = await auditPage.evaluate(() => ({
          width: document.documentElement.clientWidth,
          scrollWidth: document.documentElement.scrollWidth,
          clipped: [...document.querySelectorAll("a,button,input,select,textarea,h1,h2")].filter(el => {
            const style = getComputedStyle(el);
            const rect = el.getBoundingClientRect();
            return style.display !== "none" && style.visibility !== "hidden" && rect.width > 0 &&
              (rect.left < -1 || rect.right > document.documentElement.clientWidth + 1);
          }).slice(0, 8).map(el => ({ tag: el.tagName, id: el.id, text: (el.innerText || el.getAttribute("aria-label") || "").trim().slice(0, 60) }))
        }));
        if (desktop.scrollWidth > desktop.width + 1) throw new Error(path + " overflows at 1280px");
        if (desktop.clipped.length) throw new Error(path + " has clipped desktop controls or headings: " + JSON.stringify(desktop.clipped));
        await auditPage.setViewportSize({ width: 360, height: 800 });
      } catch (error) {
        pageFailures.push(path + ": " + String(error.message || error));
      }
    }
    if (pageFailures.length) throw new Error("Page audit found " + pageFailures.length + " issue(s):\n" + pageFailures.join("\n"));

  } finally {
    await auditPage.close();
  }
});



await check("Login, forgot-password and reset-password flows show clear English feedback", async () => {
  const authPage = await browser.newPage({ viewport: { width: 390, height: 844 } });
  let forgotRequested = false;
  let loginBody = null;
  try {
    await authPage.route("**/auth/v1/token*", async route => {
      loginBody = route.request().postDataJSON();
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({
        access_token: "smoke-access-token", token_type: "bearer", expires_in: 3600, refresh_token: "smoke-refresh-token",
        user: { id: "smoke-login-user", aud: "authenticated", role: "authenticated", email: "candidate@example.test",
          app_metadata: { provider: "email", providers: ["email"] }, user_metadata: {}, identities: [],
          created_at: new Date().toISOString(), updated_at: new Date().toISOString() }
      }) });
    });
    await authPage.route("**/auth/v1/recover*", async route => {
      forgotRequested = true;
      await route.fulfill({ status: 200, contentType: "application/json", body: "{}" });
    });
    await authPage.goto(base + "/login.html?next=jobs.html", { waitUntil: "domcontentloaded" });
    await authPage.locator("#email").fill("candidate@example.test");
    await authPage.locator("#forgotLink").click();
    await authPage.waitForFunction(() => document.querySelector("#message")?.textContent.includes("password reset link has been sent"));
    if (!forgotRequested) throw new Error("Forgot-password request was not sent");
    await authPage.locator("#password").fill("Candidate123");
    await authPage.locator("#submitBtn").click();
    await authPage.waitForURL(/jobs\.html$/, { timeout: 10000 });
    if (loginBody?.email !== "candidate@example.test" || loginBody?.password !== "Candidate123") {
      throw new Error("Login request did not send the entered credentials");
    }
    await authPage.evaluate(() => localStorage.clear());
    await authPage.goto(base + "/reset-password.html", { waitUntil: "domcontentloaded" });
    if (!(await authPage.locator("#newPassword").isVisible()) || !(await authPage.locator("#confirmPassword").isVisible())) {
      throw new Error("Reset-password form fields are missing");
    }
    await authPage.locator("#newPassword").fill("Candidate123");
    await authPage.locator("#confirmPassword").fill("Candidate123");
    await authPage.locator("#resetForm").evaluate(form => form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true })));
    await authPage.waitForFunction(() => document.querySelector("#msg")?.textContent.includes("invalid or has expired"));
    const visible = await authPage.locator("body").innerText();
    if (/[\u0B80-\u0BFF]/.test(visible)) throw new Error("Authentication page displayed Tamil text");
  } finally {
    await authPage.close();
  }
});

if (pageErrors.length) failures.push({ name: "Uncaught browser JavaScript errors", error: pageErrors.join(" | ") });
await browser.close();
console.log(JSON.stringify({ status: failures.length ? "failed" : "passed", checks: results, browser_errors: pageErrors, failures }, null, 2));
if (failures.length) process.exit(1);
