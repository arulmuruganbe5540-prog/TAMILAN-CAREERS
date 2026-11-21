import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

const safeText = (value: unknown, max = 300): string =>
  typeof value === "string" ? value.slice(0, max) : "";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);

  try {
    const authorization = req.headers.get("Authorization") || "";
    const token = authorization.replace(/^Bearer\s+/i, "").trim();
    if (!token) return json({ error: "Login required" }, 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return json({ error: "Resume access service is not configured" }, 503);
    }

    const authClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: `Bearer ${token}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: authData, error: authError } = await authClient.auth.getUser(token);
    if (authError || !authData.user) return json({ error: "Invalid or expired login session" }, 401);
    const userId = authData.user.id;

    const body = await req.json().catch(() => ({}));
    const applicationId = safeText(body?.application_id, 80).trim();
    const system = safeText(body?.system || "legacy", 24).trim().toLowerCase();
    const appTable = system === "private" ? "private_job_applications"
      : system === "international" ? "international_job_applications"
      : system === "legacy" ? "job_applications" : "";
    const jobTable = system === "private" ? "private_jobs"
      : system === "international" ? "international_jobs"
      : system === "legacy" ? "jobs" : "";
    if (!appTable || !jobTable) return json({ error: "This job system does not provide employer resume access" }, 403);
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(applicationId)) {
      return json({ error: "A valid application_id is required" }, 400);
    }

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: application, error: applicationError } = await admin
      .from(appTable)
      .select("id,job_id,candidate_id,resume_id,status")
      .eq("id", applicationId)
      .maybeSingle();
    if (applicationError) return json({ error: "Could not verify the application" }, 500);
    if (!application || !application.resume_id) return json({ error: "No resume is attached to this application" }, 404);
    if (!["applied", "under_review", "shortlisted"].includes(String(application.status || "").toLowerCase())) {
      return json({ error: "Resume access is unavailable for this application status" }, 403);
    }

    const { data: job, error: jobError } = await admin
      .from(jobTable)
      .select("company_id")
      .eq("id", application.job_id)
      .maybeSingle();
    if (jobError || !job?.company_id) return json({ error: "Could not verify the hiring company" }, 500);

    const { data: company, error: companyError } = await admin
      .from("companies")
      .select("owner_user_id")
      .eq("id", job.company_id)
      .maybeSingle();
    if (companyError || !company) return json({ error: "Could not verify the hiring company" }, 500);

    let authorized = company.owner_user_id === userId;
    if (!authorized) {
      const { data: membership, error: membershipError } = await admin
        .from("company_members")
        .select("member_role,member_status")
        .eq("company_id", job.company_id)
        .eq("user_id", userId)
        .maybeSingle();
      if (membershipError) return json({ error: "Could not verify company membership" }, 500);
      authorized = membership?.member_status === "active"
        && ["owner", "hr_manager", "recruiter"].includes(String(membership.member_role || ""));
    }
    if (!authorized) return json({ error: "You are not authorized to view this applicant's resume" }, 403);

    const { data: resume, error: resumeError } = await admin
      .from("candidate_resumes")
      .select("file_path,original_file_name,file_type")
      .eq("id", application.resume_id)
      .eq("user_id", application.candidate_id)
      .maybeSingle();
    if (resumeError) return json({ error: "Could not verify the candidate resume" }, 500);
    if (!resume || !resume.file_path.startsWith(application.candidate_id + "/")) {
      return json({ error: "The attached resume could not be found" }, 404);
    }

    const { data: signed, error: signedError } = await admin.storage
      .from("candidate-resumes")
      .createSignedUrl(resume.file_path, 60, { download: false });
    if (signedError || !signed?.signedUrl) {
      return json({ error: "Could not create a secure resume link" }, 500);
    }

    return json({
      signed_url: signed.signedUrl,
      expires_in_seconds: 60,
      file_name: safeText(resume.original_file_name, 255),
      file_type: safeText(resume.file_type, 100),
    });
  } catch (error) {
    return json({
      error: "Unexpected resume access error",
      detail: safeText(error instanceof Error ? error.message : error, 300),
    }, 500);
  }
});
