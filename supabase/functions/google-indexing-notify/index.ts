import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "https://tamilancareers.in",
  "Access-Control-Allow-Headers": "authorization, apikey, x-client-info, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin"
};
const reply = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json", "Cache-Control": "no-store" }
  });

function base64url(value: Uint8Array | string) {
  const bytes = typeof value === "string" ? new TextEncoder().encode(value) : value;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}
function pemBytes(pem: string) {
  const body = pem.replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "").replace(/\s/g, "");
  return Uint8Array.from(atob(body), c => c.charCodeAt(0));
}
async function googleAccessToken(service: { client_email: string; private_key: string }) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = base64url(JSON.stringify({
    iss: service.client_email,
    scope: "https://www.googleapis.com/auth/indexing",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600
  }));
  const unsigned = header + "." + claim;
  const key = await crypto.subtle.importKey(
    "pkcs8", pemBytes(service.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]
  );
  const signature = new Uint8Array(await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned)
  ));
  const assertion = unsigned + "." + base64url(signature);
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion
    })
  });
  const tokenBody = await tokenResponse.json().catch(() => ({}));
  if (!tokenResponse.ok || !tokenBody.access_token) {
    throw new Error("Google OAuth token request failed (" + tokenResponse.status + ")");
  }
  return String(tokenBody.access_token);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply({ error: "POST only" }, 405);
  if (req.headers.get("origin") && req.headers.get("origin") !== "https://tamilancareers.in") {
    return reply({ error: "Origin not allowed" }, 403);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
    const publicKeys = JSON.parse(Deno.env.get("SUPABASE_PUBLISHABLE_KEYS") || "{}");
    const secretKeys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") || "{}");
    const publicKey = publicKeys.default || Deno.env.get("SUPABASE_ANON_KEY") || "";
    const secretKey = secretKeys.default || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
    if (!supabaseUrl || !publicKey || !secretKey) {
      return reply({ error: "Supabase server configuration is missing" }, 500);
    }

    const authorization = req.headers.get("Authorization") || "";
    if (!authorization.startsWith("Bearer ")) return reply({ error: "Login required" }, 401);
    const userClient = createClient(supabaseUrl, publicKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false }
    });
    const { data: authData, error: authError } = await userClient.auth.getUser();
    if (authError || !authData.user) return reply({ error: "Invalid login" }, 401);

    const admin = createClient(supabaseUrl, secretKey, {
      auth: { persistSession: false, autoRefreshToken: false }
    });
    const { data: roleRows, error: roleError } = await admin.from("user_roles")
      .select("role").eq("user_id", authData.user.id);
    if (roleError) return reply({ error: "Could not verify administrator role" }, 500);
    const isSuperAdmin = (roleRows || []).some((row: { role: string }) => row.role === "super_admin");

    // Super Admin actions must use a verified MFA session (AAL2).
    // Company Owner / HR Manager permissions continue to be checked separately below.
    if (isSuperAdmin) {
      const { data: assurance, error: assuranceError } =
        await userClient.auth.mfa.getAuthenticatorAssuranceLevel();
      if (assuranceError || assurance?.currentLevel !== "aal2") {
        return reply({ error: "Super Admin MFA verification required (AAL2)" }, 403);
      }
    }

    const body = await req.json().catch(() => ({}));
    const jobId = String(body.job_id || "");
    const action = String(body.action || "");
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(jobId)) {
      return reply({ error: "Valid job_id is required" }, 400);
    }
    if (action !== "URL_UPDATED" && action !== "URL_DELETED") {
      return reply({ error: "Unsupported notification action" }, 400);
    }

    const { data: job, error: jobError } = await admin.from("jobs")
      .select("id,job_title,description,employer_name,company_id,status,published_at,application_deadline,location,workplace_type,country_name,required_skills")
      .eq("id", jobId).maybeSingle();
    if (jobError || !job) return reply({ error: "Job not found" }, 404);

    if (!isSuperAdmin) {
      if (!job.company_id) return reply({ error: "Super Admin access required for this job" }, 403);
      const { data: memberships, error: membershipError } = await admin.from("company_members")
        .select("member_role,member_status").eq("company_id", job.company_id)
        .eq("user_id", authData.user.id).eq("member_status", "active")
        .in("member_role", ["owner", "hr_manager"]);
      if (membershipError) return reply({ error: "Could not verify company permission" }, 500);
      if (!(memberships || []).length) return reply({ error: "Company Owner or HR Manager access required" }, 403);
    }

    const pageUrl = "https://tamilancareers.in/job-details.html?id=" + encodeURIComponent(jobId);
    if (action === "URL_UPDATED") {
      let employer = String(job.employer_name || "").trim();
      if (job.company_id) {
        const { data: company } = await admin.from("companies")
          .select("company_name,verification_status").eq("id", job.company_id).maybeSingle();
        employer = company?.verification_status === "verified"
          ? String(company.company_name || "").trim() : "";
      }
      const remote = job.workplace_type === "remote";
      const deadline = job.application_deadline
        ? new Date(/^\d{4}-\d{2}-\d{2}$/.test(String(job.application_deadline))
          ? String(job.application_deadline) + "T23:59:59Z" : String(job.application_deadline))
        : null;
      const expired = Boolean(deadline && deadline.getTime() < Date.now());
      const eligible = job.status === "published" && !expired &&
        Boolean(String(job.job_title || "").trim()) &&
        String(job.description || "").trim().length >= 120 &&
        Boolean(String(job.required_skills || "").trim()) &&
        Boolean(employer) && Boolean(job.published_at) &&
        Boolean(job.country_name) &&
        (remote || Boolean(job.location));
      if (!eligible) {
        return reply({
          ok: false,
          skipped: true,
          error: "Job is not currently eligible for Google JobPosting notification. Check published status, full description, employer, published date, country and location/remote details."
        }, 422);
      }
    } else {
      const deadline = job.application_deadline
        ? new Date(/^\d{4}-\d{2}-\d{2}$/.test(String(job.application_deadline))
          ? String(job.application_deadline) + "T23:59:59Z" : String(job.application_deadline))
        : null;
      if (job.status === "published" && !(deadline && deadline.getTime() < Date.now())) {
        return reply({ error: "Only closed, expired, or unpublished jobs can be removed from Google indexing" }, 409);
      }
    }

    const rawService = Deno.env.get("GOOGLE_INDEXING_SERVICE_ACCOUNT_JSON") || "";
    if (!rawService) {
      return reply({
        error: "Google Indexing API is not configured yet. Add GOOGLE_INDEXING_SERVICE_ACCOUNT_JSON as a Supabase Edge Function secret after Search Console ownership is verified."
      }, 503);
    }
    let service: { client_email: string; private_key: string };
    try { service = JSON.parse(rawService); }
    catch { return reply({ error: "Google service-account secret is not valid JSON" }, 500); }
    if (!service.client_email || !service.private_key) {
      return reply({ error: "Google service-account secret is missing client_email or private_key" }, 500);
    }

    const accessToken = await googleAccessToken(service);
    const response = await fetch("https://indexing.googleapis.com/v3/urlNotifications:publish", {
      method: "POST",
      headers: { Authorization: "Bearer " + accessToken, "Content-Type": "application/json" },
      body: JSON.stringify({ url: pageUrl, type: action })
    });
    const result = await response.json().catch(() => ({}));
    if (!response.ok) {
      return reply({ error: "Google Indexing API rejected the request", google_status: response.status }, 502);
    }
    return reply({ ok: true, action, url: pageUrl, notification: result });
  } catch (error) {
    return reply({ error: "Indexing notification failed", detail: String(error).slice(0, 300) }, 500);
  }
});
