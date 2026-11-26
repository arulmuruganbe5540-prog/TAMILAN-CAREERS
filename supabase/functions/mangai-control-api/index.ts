import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "https://tamilancareers.in",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-request-id",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Vary": "Origin",
};

const allowedOrigins = new Set([
  "https://tamilancareers.in",
  "https://www.tamilancareers.in",
  "https://arulmuruganbe5540-prog.github.io",
]);

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const origin = req.headers.get("origin");
  if (origin && !allowedOrigins.has(origin)) return json({ error: "Origin not allowed" }, 403);
  if (!["GET", "POST"].includes(req.method)) return json({ error: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return json({ error: "Server configuration is incomplete" }, 503);
  }

  const authorization = req.headers.get("authorization") || "";
  if (!authorization.startsWith("Bearer ")) return json({ error: "Login required" }, 401);

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  const user = userData?.user;
  if (userError || !user) return json({ error: "Session is invalid or expired" }, 401);

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // The automation agent is never an identity. Only the existing, single Owner is accepted.
  const [{ data: roleRow, error: roleError }, { data: ownerRow, error: ownerError }] = await Promise.all([
    admin.from("user_roles").select("user_id").eq("user_id", user.id).eq("role", "super_admin").maybeSingle(),
    admin.from("mangai_owner_config").select("owner_user_id").eq("singleton", true).maybeSingle(),
  ]);
  if (roleError || ownerError) {
    return json({ error: "Control registry is not installed or could not be checked" }, 503);
  }
  if (!roleRow || !ownerRow || ownerRow.owner_user_id !== user.id) {
    return json({ error: "Master Owner permission required" }, 403);
  }

  const requestId = req.headers.get("x-request-id") || crypto.randomUUID();

  async function writeAudit(eventType: string, targetType: string | null, targetId: string | null, details: Record<string, unknown>, outcome = "succeeded") {
    const { error } = await admin.from("mangai_audit_events").insert({
      actor_type: "owner",
      actor_id: user.id,
      event_type: eventType,
      target_type: targetType,
      target_id: targetId,
      request_id: requestId,
      outcome,
      details,
    });
    if (error) throw new Error("Audit write failed");
  }

  if (req.method === "GET") {
    const action = new URL(req.url).searchParams.get("action") || "overview";
    if (action === "modules") {
      const { data, error } = await admin.from("mangai_control_modules").select("*").order("category").order("module_key");
      if (error) return json({ error: "Unable to load modules" }, 500);
      return json({ modules: data || [] });
    }
    if (action === "proposals") {
      const { data, error } = await admin.from("mangai_change_proposals")
        .select("id,module_key,title,description,risk_level,status,expected_impact,created_at,updated_at")
        .order("created_at", { ascending: false }).limit(100);
      if (error) return json({ error: "Unable to load proposals" }, 500);
      return json({ proposals: data || [] });
    }
    if (action === "alerts") {
      const { data, error } = await admin.from("mangai_control_alerts")
        .select("id,module_key,severity,title,message,status,created_at")
        .order("created_at", { ascending: false }).limit(100);
      if (error) return json({ error: "Unable to load alerts" }, 500);
      return json({ alerts: data || [] });
    }
    if (action !== "overview") return json({ error: "Unknown read action" }, 400);

    const [modules, openProposals, openAlerts, recentRuns, recentChecks] = await Promise.all([
      admin.from("mangai_control_modules").select("module_key", { count: "exact", head: true }),
      admin.from("mangai_change_proposals").select("id", { count: "exact", head: true }).in("status", ["proposed", "allowed_for_testing", "testing", "ready_to_deploy"]),
      admin.from("mangai_control_alerts").select("id", { count: "exact", head: true }).eq("status", "open"),
      admin.from("mangai_automation_runs").select("id,module_key,run_type,status,started_at,finished_at").order("created_at", { ascending: false }).limit(10),
      admin.from("mangai_monitoring_checks").select("id,module_key,check_type,target,status,checked_at").order("checked_at", { ascending: false }).limit(12),
    ]);
    if ([modules, openProposals, openAlerts, recentRuns, recentChecks].some(x => x.error)) {
      return json({ error: "Unable to load control overview" }, 500);
    }
    return json({
      owner: { id: user.id, email: user.email },
      counts: {
        modules: modules.count || 0,
        pendingProposals: openProposals.count || 0,
        openAlerts: openAlerts.count || 0,
      },
      recentRuns: recentRuns.data || [],
      recentChecks: recentChecks.data || [],
      productionDeploymentEnabled: false,
    });
  }

  let body: unknown;
  try { body = await req.json(); } catch { return json({ error: "Invalid JSON body" }, 400); }
  if (!isObject(body) || typeof body.action !== "string") return json({ error: "Action is required" }, 400);

  try {
    if (body.action === "pause_module" || body.action === "resume_module") {
      if (typeof body.module_key !== "string" || !/^[a-z0-9_]{2,60}$/.test(body.module_key)) {
        return json({ error: "Valid module_key is required" }, 400);
      }
      if (body.module_key === "security_governance") {
        return json({ error: "Security governance cannot be paused from automation controls" }, 403);
      }
      const enabled = body.action === "resume_module";
      const { data, error } = await admin.from("mangai_control_modules")
        .update({ enabled, updated_at: new Date().toISOString() })
        .eq("module_key", body.module_key)
        .select("module_key,enabled")
        .maybeSingle();
      if (error || !data) return json({ error: "Module not found or update failed" }, 404);
      await writeAudit(body.action, "module", body.module_key, { enabled });
      return json({ ok: true, module: data });
    }

    if (body.action === "create_proposal") {
      if (typeof body.title !== "string" || body.title.trim().length < 4 || body.title.length > 180) {
        return json({ error: "Proposal title must be 4–180 characters" }, 400);
      }
      const risk = ["low", "medium", "high", "critical"].includes(String(body.risk_level)) ? String(body.risk_level) : "medium";
      const { data, error } = await admin.from("mangai_change_proposals").insert({
        module_key: typeof body.module_key === "string" ? body.module_key : null,
        title: body.title.trim(),
        description: typeof body.description === "string" ? body.description.slice(0, 5000) : "",
        risk_level: risk,
        status: "proposed",
        change_payload: isObject(body.change_payload) ? body.change_payload : {},
        test_plan: Array.isArray(body.test_plan) ? body.test_plan : [],
        rollback_plan: isObject(body.rollback_plan) ? body.rollback_plan : {},
        expected_impact: typeof body.expected_impact === "string" ? body.expected_impact.slice(0, 2000) : "",
        created_by: user.id,
      }).select("id,title,status,risk_level").single();
      if (error || !data) return json({ error: "Unable to create proposal" }, 500);
      await writeAudit("proposal_created", "proposal", data.id, { title: data.title, risk_level: risk });
      return json({ ok: true, proposal: data }, 201);
    }

    if (["allow_testing", "reject_proposal", "keep_existing"].includes(body.action)) {
      if (typeof body.proposal_id !== "string" || !/^[0-9a-f-]{36}$/i.test(body.proposal_id)) {
        return json({ error: "Valid proposal_id is required" }, 400);
      }
      const mapping = {
        allow_testing: { status: "allowed_for_testing", decision: "allow_testing" },
        reject_proposal: { status: "rejected", decision: "reject" },
        keep_existing: { status: "kept_existing", decision: "keep_existing" },
      } as const;
      const choice = mapping[body.action as keyof typeof mapping];
      const { data: proposal, error: proposalError } = await admin.from("mangai_change_proposals")
        .select("id,status,risk_level").eq("id", body.proposal_id).maybeSingle();
      if (proposalError || !proposal) return json({ error: "Proposal not found" }, 404);
      if (proposal.status !== "proposed") return json({ error: "Only proposed changes can receive this decision" }, 409);
      const { data: updated, error: updateError } = await admin.from("mangai_change_proposals")
        .update({ status: choice.status, updated_at: new Date().toISOString() })
        .eq("id", body.proposal_id).eq("status", "proposed")
        .select("id,status").maybeSingle();
      if (updateError || !updated) return json({ error: "Proposal decision could not be saved" }, 409);
      const { error: approvalError } = await admin.from("mangai_owner_approvals").insert({
        proposal_id: body.proposal_id,
        decision: choice.decision,
        owner_user_id: user.id,
        rationale: typeof body.rationale === "string" ? body.rationale.slice(0, 2000) : "",
      });
      if (approvalError) return json({ error: "Decision saved but approval history write failed; contact administrator" }, 500);
      await writeAudit("proposal_" + choice.decision, "proposal", body.proposal_id, { previous_status: proposal.status, new_status: choice.status, risk_level: proposal.risk_level });
      return json({ ok: true, proposal: updated });
    }

    if (body.action === "approve_production" || body.action === "deploy") {
      return json({ error: "Production deployment is deliberately disabled in this foundation phase. It requires staging tests, backup verification and a separate release approval workflow." }, 409);
    }

    return json({ error: "Action is not allow-listed" }, 400);
  } catch (_error) {
    return json({ error: "Action failed safely. Check the server-side audit and function logs." }, 500);
  }
});
