import { readFile, writeFile } from "node:fs/promises";

const SITE_ORIGIN = "https://tamilancareers.in";
const SUPABASE_URL = "https://qkmljuuusfjowexvybvy.supabase.co";
const PUBLISHABLE_KEY = "sb_publishable_Wi6gltM_xFm1m4Dlgq727Q_83Rn58y2";
const SITEMAP_PATH = "sitemap.xml";
const PAGE_SIZE = 1000;

function xmlEscape(value) {
  return String(value).replace(/[&<>"']/g, (char) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&apos;"
  })[char]);
}

function validDate(value) {
  if (!value) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

async function fetchPublishedJobs() {
  const jobs = [];
  let offset = 0;
  const now = new Date().toISOString();

  while (true) {
    const url = new URL("/rest/v1/jobs", SUPABASE_URL);
    url.searchParams.set("select", "id,updated_at,published_at,application_deadline");
    url.searchParams.set("status", "eq.published");
    url.searchParams.set("or", `(application_deadline.is.null,application_deadline.gt.${now})`);
    url.searchParams.set("order", "updated_at.desc");

    const response = await fetch(url, {
      headers: {
        apikey: PUBLISHABLE_KEY,
        Accept: "application/json",
        Range: `${offset}-${offset + PAGE_SIZE - 1}`,
        "Range-Unit": "items"
      }
    });

    if (!response.ok) {
      throw new Error(`Supabase jobs query failed: HTTP ${response.status} ${(await response.text()).slice(0, 500)}`);
    }

    const batch = await response.json();
    if (!Array.isArray(batch)) throw new Error("Supabase returned an unexpected jobs response.");
    jobs.push(...batch);
    if (batch.length < PAGE_SIZE) break;
    offset += PAGE_SIZE;
  }

  return jobs;
}

function existingStaticEntries(xml) {
  const entries = xml.match(/<url>\\s*[\\s\\S]*?<\\/url>/g) || [];
  return entries.filter((entry) => !entry.includes("/job-details.html?id="));
}

async function main() {
  const original = await readFile(SITEMAP_PATH, "utf8");
  const staticEntries = existingStaticEntries(original);
  const jobs = await fetchPublishedJobs();
  const seen = new Set();
  const jobEntries = [];

  for (const job of jobs) {
    if (!job || typeof job.id !== "string" || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(job.id)) continue;
    if (seen.has(job.id)) continue;
    seen.add(job.id);

    const url = `${SITE_ORIGIN}/job-details.html?id=${encodeURIComponent(job.id)}`;
    const lastmod = validDate(job.updated_at) || validDate(job.published_at);
    jobEntries.push(
      `  <url>\\n    <loc>${xmlEscape(url)}</loc>${lastmod ? `\\n    <lastmod>${lastmod}</lastmod>` : ""}\\n  </url>`
    );
  }

  const output = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    ...staticEntries,
    ...jobEntries,
    '</urlset>',
    ''
  ].join("\\n");

  if (output !== original) {
    await writeFile(SITEMAP_PATH, output, "utf8");
    console.log(`Updated sitemap.xml: ${staticEntries.length} static URLs + ${jobEntries.length} active published job URLs.`);
  } else {
    console.log(`sitemap.xml already current: ${staticEntries.length} static URLs + ${jobEntries.length} active published job URLs.`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
