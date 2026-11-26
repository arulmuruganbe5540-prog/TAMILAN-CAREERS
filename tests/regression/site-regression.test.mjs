import test from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = process.cwd();
const read = (file) => {
  const path = resolve(root, file);
  assert.ok(existsSync(path), `Required page/file is missing: ${file}`);
  return readFileSync(path, "utf8");
};
const includes = (source, pattern, message) => assert.match(source, pattern, message);

test("core public and account pages exist and use English mobile document settings", () => {
  const pages = [
    "index.html",
    "auth.html",
    "job-seeker-auth.html",
    "employer-auth.html",
    "private-jobs.html",
    "international-jobs.html",
    "apply-private-job.html",
    "apply-international-job.html",
    "company-job-portal.html",
    "super-admin-login.html",
    "mangai-control-center.html",
  ];
  for (const file of pages) {
    const html = read(file);
    includes(html, /<!doctype html>/i, `${file}: HTML doctype missing`);
    includes(html, /<html[^>]*lang=["']en["']/i, `${file}: visible UI document language must be English`);
    includes(html, /<meta[^>]*name=["']viewport["'][^>]*content=["'][^"']*width=device-width/i, `${file}: mobile viewport missing`);
  }
});

test("student and employer authentication keep separate login and registration forms", () => {
  const student = read("job-seeker-auth.html");
  const employer = read("employer-auth.html");
  for (const [name, html] of [["student", student], ["employer", employer]]) {
    includes(html, /id=["']loginForm["']/, `${name}: login form missing`);
    includes(html, /id=["']registerForm["']/, `${name}: registration form missing`);
    includes(html, /id=["']loginPassword["']/, `${name}: login password input missing`);
    includes(html, /id=["']registerPassword["']/, `${name}: registration password input missing`);
    includes(html, /id=["']confirmPassword["']/, `${name}: password confirmation missing`);
  }
  includes(student, /employer-auth\.html/, "Student authentication should link to employer authentication");
  includes(employer, /job-seeker-auth\.html/, "Employer authentication should link to student authentication");
});

test("private and international job listings use distinct market modes and database tables", () => {
  const privatePage = read("private-jobs.html");
  const internationalPage = read("international-jobs.html");
  includes(privatePage, /const\s+kind\s*=\s*['"]private['"]\s*,\s*intl\s*=\s*false/, "Private listing must explicitly use private mode");
  includes(internationalPage, /const\s+kind\s*=\s*['"]international['"]\s*,\s*intl\s*=\s*true/, "International listing must explicitly use international mode");
  for (const html of [privatePage, internationalPage]) {
    includes(html, /db\.from\(intl\s*\?\s*['"]international_jobs['"]\s*:\s*['"]private_jobs['"]\)/, "Listing must select the table for its explicit market mode");
    includes(html, /PAGE_SIZE\s*=\s*10/, "Listing page size should remain 10");
  }
});

test("job applications remain separated by market and application table", () => {
  const privateApply = read("apply-private-job.html");
  const internationalApply = read("apply-international-job.html");
  includes(privateApply, /private_jobs/, "Private application must load a private job");
  includes(privateApply, /private_job_applications/, "Private application must write to its own application table");
  assert.doesNotMatch(privateApply, /international_job_applications/, "Private application must not write to international applications");
  includes(internationalApply, /international_jobs/, "International application must load an international job");
  includes(internationalApply, /international_job_applications/, "International application must write to its own application table");
  assert.doesNotMatch(internationalApply, /private_job_applications/, "International application must not write to private applications");
  includes(privateApply, /id=["']applyForm["']/, "Private application form missing");
  includes(internationalApply, /id=["']applyForm["']/, "International application form missing");
});

test("company verification and posting gates are separate for Indian private and international markets", () => {
  const portal = read("company-job-portal.html");
  for (const id of ["companyProfileForm", "verificationForm", "privateForm", "internationalForm"]) {
    includes(portal, new RegExp(`id=["']${id}["']`), `Company portal form missing: ${id}`);
  }
  includes(portal, /private_jobs_verification_status\s*!==\s*['"]verified['"]/, "Private posting must require private-market verification");
  includes(portal, /international_jobs_verification_status\s*!==\s*['"]verified['"]/, "International posting must require international-market verification");
  includes(portal, /sb\.from\(['"]private_jobs['"]\)\.insert/, "Private posting must use private_jobs");
  includes(portal, /sb\.from\(['"]international_jobs['"]\)\.insert/, "International posting must use international_jobs");
  includes(portal, /company_verification_requests/, "Company verification history must be checked");
});

test("Master Control preview stays read-only and keeps privileged keys out of browser code", () => {
  const page = read("mangai-control-center.html");
  includes(page, /auth\.getUser\(\)/, "Owner session check missing");
  includes(page, /user_roles/, "Existing Super Admin role check missing");
  includes(page, /mangai-control-api/, "Control API connection path missing");
  assert.doesNotMatch(page, /SUPABASE_SERVICE_ROLE_KEY|service_role/i, "Privileged service-role credential/reference must not be in browser page");
  assert.doesNotMatch(page, /method\s*:\s*["']POST["']|\.insert\(|\.update\(|\.delete\(/i, "Read-only preview must not expose database write handlers");
  includes(page, /productionDeploymentEnabled/, "Production deployment state should be displayed");
});

test("public homepage does not expose the private Mangai control workspace or API", () => {
  const home = read("index.html");
  assert.doesNotMatch(home, /mangai-control-center\.html|mangai-control-api/, "Private control internals must not be linked from the public homepage");
});

test("static local links in core workflows resolve to repository files", () => {
  const pages = [
    "index.html", "job-seeker-auth.html", "employer-auth.html",
    "private-jobs.html", "international-jobs.html",
    "apply-private-job.html", "apply-international-job.html",
    "company-job-portal.html", "mangai-control-center.html",
  ];
  const missing = [];
  for (const page of pages) {
    const html = read(page);
    const attrs = /\b(?:href|src)=["']([^"']+)["']/gi;
    for (const match of html.matchAll(attrs)) {
      const value = match[1].trim();
      if (!value || value.startsWith("#") || value.startsWith("?") ||
          /^(?:https?:|mailto:|tel:|javascript:|data:|\/\/)/i.test(value)) continue;
      const target = value.split(/[?#]/, 1)[0];
      if (!target) continue;
      const resolved = resolve(root, page.includes("/") ? page.slice(0, page.lastIndexOf("/") + 1) + target : target);
      if (!existsSync(resolved)) missing.push(`${page} -> ${value}`);
    }
  }
  assert.deepEqual(missing, [], `Broken local links: ${missing.join("; ")}`);
});
