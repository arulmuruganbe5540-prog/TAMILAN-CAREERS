import { createClient } from "@supabase/supabase-js";
import {
  authorizeMasterOwner,
  hasWriteAssurance,
  isProductionReleaseAction,
  isProtectedModuleControl,
} from "./policy.ts";

const allowedOrigins = new Set([
  "https://tamilancareers.in",
  "https://www.tamilancareers.in",
  "https://arulmuruganbe5540-prog.github.io",
]);

function corsHeaders(origin: string | null) {
  return {
    "Access-Control-Allow-Origin": origin && allowedOrigins.has(origin)
      ? origin
      : "https://tamilancareers.in",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type, x-request-id",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Vary": "Origin",
  };
}

function json(data: unknown, status = 200, origin: string | null = null) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders(origin),
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export type ControlApiDependencies = {
  createClient: typeof createClient;
  getEnv: (name: string) => string | undefined;
  randomUUID: () => string;
};

/** Build the HTTP handler with injectable dependencies for isolated request-flow tests. */
export function createControlApiHandler(deps: ControlApiDependencies) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") {
      const preflightOrigin = req.headers.get("origin");
      if (preflightOrigin && !allowedOrigins.has(preflightOrigin)) {
        return new Response("Origin not allowed", { status: 403 });
      }
      return new Response("ok", { headers: corsHeaders(preflightOrigin) });
    }

    const origin = req.headers.get("origin");
    if (origin && !allowedOrigins.has(origin)) {
      return json({ error: "Origin not allowed" }, 403, origin);
    }
    if (!["GET", "POST"].includes(req.method)) {
      return json({ error: "Method not allowed" }, 405, origin);
    }

    const supabaseUrl = deps.getEnv("SUPABASE_URL");
    const anonKey = deps.getEnv("SUPABASE_ANON_KEY");
    const serviceRoleKey = deps.getEnv("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return json({ error: "Server configuration is incomplete" }, 503, origin);
    }

    const authorization = req.headers.get("authorization") || "";
    if (!authorization.startsWith("Bearer ")) {
      return json({ error: "Login required" }, 401, origin);
    }

    const userClient = deps.createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: userData, error: userError } = await userClient.auth
      .getUser();
    const user = userData?.user;
    if (userError || !user) {
      return json({ error: "Session is invalid or expired" }, 401, origin);
    }
    const admin = deps.createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // The automation agent is never an identity. Only the existing, single Owner is accepted.
    const [
      { data: roleRow, error: roleError },
      { data: ownerRow, error: ownerError },
    ] = await Promise.all([
      admin.from("user_roles").select("user_id").eq("user_id", user.id).eq(
        "role",
        "super_admin",
      ).maybeSingle(),
      admin.from("mangai_owner_config").select("owner_user_id").eq(
        "singleton",
        true,
      ).maybeSingle(),
    ]);
    const ownerGate = authorizeMasterOwner({
      userId: user?.id ?? null,
      hasValidUser: !userError && Boolean(user),
      roleLookupFailed: Boolean(roleError),
      ownerLookupFailed: Boolean(ownerError),
      hasSuperAdminRole: Boolean(roleRow),
      ownerUserId: ownerRow?.owner_user_id ?? null,
    });
    if (!ownerGate.allowed) {
      return json({ error: ownerGate.error }, ownerGate.status, origin);
    }

    const requestId = req.headers.get("x-request-id") || deps.randomUUID();

    if (req.method === "GET") {
      const action = new URL(req.url).searchParams.get("action") || "overview";
      if (action === "modules") {
        const { data, error } = await admin.from("mangai_control_modules")
          .select(
            "*",
          ).order("category").order("module_key");
        if (error) {
          return json({ error: "Unable to load modules" }, 500, origin);
        }
        return json({ modules: data || [] }, 200, origin);
      }
      if (action === "proposals") {
        const { data, error } = await admin.from("mangai_change_proposals")
          .select(
            "id,module_key,title,description,risk_level,status,expected_impact,created_at,updated_at",
          )
          .order("created_at", { ascending: false }).limit(100);
        if (error) {
          return json({ error: "Unable to load proposals" }, 500, origin);
        }
        return json({ proposals: data || [] }, 200, origin);
      }
      if (action === "alerts") {
        const { data, error } = await admin.from("mangai_control_alerts")
          .select("id,module_key,severity,title,message,status,created_at")
          .order("created_at", { ascending: false }).limit(100);
        if (error) return json({ error: "Unable to load alerts" }, 500, origin);
        return json({ alerts: data || [] }, 200, origin);
      }
      if (action !== "overview") {
        return json({ error: "Unknown read action" }, 400, origin);
      }

      const [modules, openProposals, openAlerts, recentRuns, recentChecks] =
        await Promise.all([
          admin.from("mangai_control_modules").select("module_key", {
            count: "exact",
            head: true,
          }),
          admin.from("mangai_change_proposals").select("id", {
            count: "exact",
            head: true,
          }).in("status", [
            "proposed",
            "allowed_for_testing",
            "testing",
            "ready_to_deploy",
          ]),
          admin.from("mangai_control_alerts").select("id", {
            count: "exact",
            head: true,
          }).eq("status", "open"),
          admin.from("mangai_automation_runs").select(
            "id,module_key,run_type,status,started_at,finished_at",
          ).order("created_at", { ascending: false }).limit(10),
          admin.from("mangai_monitoring_checks").select(
            "id,module_key,check_type,target,status,checked_at",
          ).order("checked_at", { ascending: false }).limit(12),
        ]);
      if (
        [modules, openProposals, openAlerts, recentRuns, recentChecks].some((
          x,
        ) => x.error)
      ) {
        return json({ error: "Unable to load control overview" }, 500, origin);
      }
      return json(
        {
          owner: { id: user.id, email: user.email },
          counts: {
            modules: modules.count || 0,
            pendingProposals: openProposals.count || 0,
            openAlerts: openAlerts.count || 0,
          },
          recentRuns: recentRuns.data || [],
          recentChecks: recentChecks.data || [],
          productionDeploymentEnabled: false,
        },
        200,
        origin,
      );
    }

    let body: unknown;
    try {
      body = await req.json();
    } catch {
      return json({ error: "Invalid JSON body" }, 400, origin);
    }
    if (!isObject(body) || typeof body.action !== "string") {
      return json({ error: "Action is required" }, 400, origin);
    }

    // All write actions require an active MFA-protected session (AAL2).
    // Read-only GET requests remain available to the authenticated Owner.
    // Verify the exact bearer JWT cryptographically, then read its signed AAL claim.
    // getAuthenticatorAssuranceLevel() relies on client session storage, which is
    // intentionally disabled for this stateless per-request Edge Function client.
    const accessToken = authorization.slice("Bearer ".length);
    const { data: claimsData, error: claimsError } = await userClient.auth
      .getClaims(accessToken);
    const tokenClaims = claimsData?.claims;
    const verifiedAal2 = !claimsError &&
      tokenClaims?.sub === user.id &&
      tokenClaims?.aal === "aal2";
    if (
      !hasWriteAssurance(
        verifiedAal2 ? "aal2" : "aal1",
        Boolean(claimsError) || !tokenClaims || tokenClaims.sub !== user.id,
      )
    ) {
      return json(
        {
          error:
            "Multi-factor authentication is required for control changes. Complete MFA verification and try again.",
        },
        403,
        origin,
      );
    }

    try {
      if (body.action === "pause_module" || body.action === "resume_module") {
        if (
          typeof body.module_key !== "string" ||
          !/^[a-z0-9_]{2,60}$/.test(body.module_key)
        ) return json({ error: "Valid module_key is required" }, 400, origin);
        if (isProtectedModuleControl(body.action, body.module_key)) {
          return json(
            {
              error:
                "Security governance cannot be paused or resumed from automation controls",
            },
            403,
            origin,
          );
        }
        const { data, error } = await admin.rpc("mangai_set_module_enabled", {
          p_module_key: body.module_key,
          p_enabled: body.action === "resume_module",
          p_owner_user_id: user.id,
          p_request_id: requestId,
        });
        if (error || !data) {
          return json(
            { error: "Module change and audit were not committed." },
            409,
            origin,
          );
        }
        return json({ ok: true, module: data }, 200, origin);
      }

      if (body.action === "create_proposal") {
        if (
          typeof body.title !== "string" || body.title.trim().length < 4 ||
          body.title.length > 180
        ) {
          return json(
            { error: "Proposal title must be 4–180 characters" },
            400,
            origin,
          );
        }
        const risk = ["low", "medium", "high", "critical"].includes(
            String(body.risk_level),
          )
          ? String(body.risk_level)
          : "medium";
        const { data, error } = await admin.rpc(
          "mangai_create_change_proposal",
          {
            p_module_key: typeof body.module_key === "string"
              ? body.module_key
              : null,
            p_title: body.title.trim(),
            p_description: typeof body.description === "string"
              ? body.description.slice(0, 5000)
              : "",
            p_risk_level: risk,
            p_change_payload: isObject(body.change_payload)
              ? body.change_payload
              : {},
            p_test_plan: Array.isArray(body.test_plan) ? body.test_plan : [],
            p_rollback_plan: isObject(body.rollback_plan)
              ? body.rollback_plan
              : {},
            p_expected_impact: typeof body.expected_impact === "string"
              ? body.expected_impact.slice(0, 2000)
              : "",
            p_owner_user_id: user.id,
            p_request_id: requestId,
          },
        );
        if (error || !data) {
          return json(
            { error: "Proposal creation and audit were not committed." },
            409,
            origin,
          );
        }
        return json({ ok: true, proposal: data }, 201, origin);
      }

      if (
        ["allow_testing", "reject_proposal", "keep_existing"].includes(
          body.action,
        )
      ) {
        if (
          typeof body.proposal_id !== "string" ||
          !/^[0-9a-f-]{36}$/i.test(body.proposal_id)
        ) {
          return json({ error: "Valid proposal_id is required" }, 400, origin);
        }
        const decision = body.action === "allow_testing"
          ? "allow_testing"
          : body.action === "reject_proposal"
          ? "reject"
          : "keep_existing";
        const { data: updated, error: decisionError } = await admin.rpc(
          "mangai_record_proposal_decision",
          {
            p_proposal_id: body.proposal_id,
            p_decision: decision,
            p_owner_user_id: user.id,
            p_rationale: typeof body.rationale === "string"
              ? body.rationale.slice(0, 2000)
              : "",
            p_request_id: requestId,
          },
        );
        if (decisionError || !updated) {
          return json(
            {
              error:
                "Proposal decision was not recorded. It may already have a decision or the database migration is not installed.",
            },
            409,
            origin,
          );
        }
        return json({ ok: true, proposal: updated }, 200, origin);
      }

      if (isProductionReleaseAction(body.action)) {
        return json(
          {
            error:
              "Production deployment is deliberately disabled in this foundation phase. It requires staging tests, backup verification and a separate release approval workflow.",
          },
          409,
          origin,
        );
      }

      return json({ error: "Action is not allow-listed" }, 400, origin);
    } catch (_error) {
      return json(
        {
          error:
            "Action failed safely. Check the server-side audit and function logs.",
        },
        500,
        origin,
      );
    }
  };
}

if (import.meta.main) {
  Deno.serve(createControlApiHandler({
    createClient,
    getEnv: (name) => Deno.env.get(name),
    randomUUID: () => crypto.randomUUID(),
  }));
}
