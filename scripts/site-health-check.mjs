import { writeFileSync, appendFileSync } from "node:fs";

const BASE_URL = (process.env.SITE_BASE_URL || "https://tamilancareers.in").replace(/\/$/, "");
const TIMEOUT_MS = 12000;

export const TARGETS = [
  { path: "/", kind: "html", label: "Homepage" },
  { path: "/government-jobs.html", kind: "html", label: "Government jobs" },
  { path: "/private-jobs.html", kind: "html", label: "Private jobs" },
  { path: "/international-jobs.html", kind: "html", label: "International jobs" },
  { path: "/sitemap.xml", kind: "xml", label: "Sitemap index" },
  { path: "/robots.txt", kind: "text", label: "Robots policy" },
];

export async function runChecks({ baseUrl = BASE_URL, fetchImpl = fetch } = {}) {
  const checks = await Promise.all(TARGETS.map(async (target) => {
    const url = new URL(target.path, baseUrl).toString();
    const started = Date.now();
    try {
      const response = await fetchImpl(url, {
        method: "GET",
        redirect: "follow",
        headers: { "user-agent": "TAMILAN-CAREERS-Health-Monitor/1.0" },
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
      const body = await response.text();
      const contentType = response.headers.get("content-type") || "";
      const contentTypeOk = target.kind === "html"
        ? /text\/html/i.test(contentType)
        : target.kind === "xml"
        ? /(xml|text\/plain)/i.test(contentType)
        : /(text\/plain|text\/)/i.test(contentType);
      const bodyOk = body.trim().length > 0;
      const ok = response.status === 200 && contentTypeOk && bodyOk;
      return {
        label: target.label,
        url,
        status: response.status,
        contentType,
        elapsedMs: Date.now() - started,
        ok,
        error: !ok
          ? `Expected HTTP 200, non-empty body and ${target.kind} content; received HTTP ${response.status} (${contentType || "no content-type"}).`
          : null,
      };
    } catch (error) {
      return {
        label: target.label,
        url,
        status: null,
        contentType: "",
        elapsedMs: Date.now() - started,
        ok: false,
        error: error instanceof Error ? error.message : String(error),
      };
    }
  }));
  return {
    checkedAt: new Date().toISOString(),
    baseUrl,
    status: checks.every((item) => item.ok) ? "healthy" : "failed",
    checks,
  };
}

function renderMarkdown(report) {
  const lines = [
    "# TAMILAN CAREERS automated website health check",
    "",
    `- Checked at: ${report.checkedAt}`,
    `- Base URL: ${report.baseUrl}`,
    `- Overall status: **${report.status.toUpperCase()}**`,
    "",
    "| Target | Result | HTTP | Time | Details |",
    "|---|---|---:|---:|---|",
  ];
  for (const item of report.checks) {
    lines.push(
      `| ${item.label} | ${item.ok ? "PASS" : "FAIL"} | ${item.status ?? "—"} | ${item.elapsedMs} ms | ${item.error || item.contentType} |`,
    );
  }
  lines.push(
    "",
    "This monitor checks public page availability and response types only. It does not prove login, form submission, database writes, RLS, external links, or Google indexing.",
  );
  return lines.join("\n");
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const report = await runChecks();
  const markdown = renderMarkdown(report);
  writeFileSync("monitor-report.json", JSON.stringify(report, null, 2));
  writeFileSync("monitor-report.md", markdown + "\n");
  if (process.env.GITHUB_STEP_SUMMARY) {
    appendFileSync(process.env.GITHUB_STEP_SUMMARY, markdown + "\n");
  }
  if (process.env.GITHUB_OUTPUT) {
    appendFileSync(process.env.GITHUB_OUTPUT, `status=${report.status}\n`);
  }
  console.log(markdown);
  if (report.status !== "healthy") process.exitCode = 1;
}
