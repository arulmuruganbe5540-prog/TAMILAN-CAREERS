// Pure, side-effect-free helpers for TAMILAN AI job retrieval.
export const MAX_QUERY_LENGTH = 80;
export const MAX_RESULTS = 5;
export const MAX_DESCRIPTION_LENGTH = 6000;

export function normalizeSearchQuery(value: unknown): string | null {
  if (value === undefined || value === null || value === "") return "";
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (trimmed.length > MAX_QUERY_LENGTH) return null;
  return trimmed.replace(/[%,_()]/g, " ").replace(/\s+/g, " ").trim();
}
export function normalizeCountry(value: unknown): string | null {
  if (value === undefined || value === null || value === "") return "";
  if (typeof value !== "string" || value.trim().length > 100) return null;
  return value.trim().replace(/[%,_()]/g, " ").replace(/\s+/g, " ").trim();
}
export function safeHttpsUrl(value: unknown): string | null {
  if (typeof value !== "string" || value.length > 2048) return null;
  try {
    const url = new URL(value);
    return url.protocol === "https:" ? url.toString() : null;
  } catch {
    return null;
  }
}
export function rateLimitDecision(value: unknown): { allowed: boolean; retryAfterSeconds: number } | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const result = value as Record<string, unknown>;
  if (typeof result.allowed !== "boolean") return null;
  if (result.allowed) return { allowed: true, retryAfterSeconds: 0 };
  const retry = result.retry_after_seconds;
  if (typeof retry !== "number" || !Number.isInteger(retry) || retry < 1 || retry > 86400) return null;
  return { allowed: false, retryAfterSeconds: retry };
}
export function publicJobSource(row: Record<string, unknown>) {
  const id = typeof row.id === "string" ? row.id : "";
  if (!id) return null;
  const canonical = "https://tamilancareers.in/job-details.html?id=" + encodeURIComponent(id);
  const sourceUrl = safeHttpsUrl(row.official_notification_url) ??
    safeHttpsUrl(row.official_website_url) ?? canonical;
  return {
    source_id: id,
    title: String(row.job_title ?? "").slice(0, 300),
    description: String(row.description ?? "").slice(0, MAX_DESCRIPTION_LENGTH),
    location: typeof row.location === "string" ? row.location.slice(0, 300) : null,
    country: typeof row.country_name === "string" ? row.country_name.slice(0, 100) : null,
    employment_type: typeof row.employment_type === "string" ? row.employment_type.slice(0, 100) : null,
    workplace_type: typeof row.workplace_type === "string" ? row.workplace_type.slice(0, 100) : null,
    education_level: typeof row.education_level === "string" ? row.education_level.slice(0, 300) : null,
    required_skills: typeof row.required_skills === "string" ? row.required_skills.slice(0, 1000) : null,
    experience_min: typeof row.experience_min === "number" ? row.experience_min : null,
    experience_max: typeof row.experience_max === "number" ? row.experience_max : null,
    salary_min: typeof row.salary_min === "number" ? row.salary_min : null,
    salary_max: typeof row.salary_max === "number" ? row.salary_max : null,
    salary_currency: typeof row.salary_currency === "string" ? row.salary_currency.trim() : null,
    salary_period: typeof row.salary_period === "string" ? row.salary_period.slice(0, 50) : null,
    application_deadline: typeof row.application_deadline === "string" ? row.application_deadline : null,
    published_at: typeof row.published_at === "string" ? row.published_at : null,
    citation_url: sourceUrl,
    content_is_untrusted: true,
  };
}
