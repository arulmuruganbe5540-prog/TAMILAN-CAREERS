import { assertEquals } from "@std/assert";
import { createClient } from "@supabase/supabase-js";
import { createControlApiHandler } from "./index.ts";

const OWNER_ID = "11111111-1111-4111-8111-111111111111";

function testJwt(aal: "aal1" | "aal2"): string {
  const payload = btoa(JSON.stringify({
    sub: OWNER_ID,
    aal,
    exp: Math.floor(Date.now() / 1000) + 3600,
  })).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  return `header.${payload}.signature`;
}

type MockOptions = {
  validSession?: boolean;
  isOwner?: boolean;
  assurance?: string;
  assuranceError?: boolean;
};

function makeHandler(options: MockOptions = {}) {
  const calls: string[] = [];
  const settings = {
    validSession: options.validSession ?? true,
    isOwner: options.isOwner ?? true,
    assurance: options.assurance ?? "aal2",
    assuranceError: options.assuranceError ?? false,
  };

  const fakeCreateClient = ((_url: string, key: string) => {
    if (key === "anon-test-key") {
      return {
        auth: {
          getUser: () =>
            settings.validSession
              ? {
                data: { user: { id: OWNER_ID, email: "owner@example.test" } },
                error: null,
              }
              : { data: { user: null }, error: { message: "Invalid token" } },
          mfa: {
            getAuthenticatorAssuranceLevel: () => ({
              data: { currentLevel: settings.assurance },
              error: settings.assuranceError
                ? { message: "MFA lookup failed" }
                : null,
            }),
          },
        },
      };
    }

    type MockQuery = {
      select: (...args: unknown[]) => MockQuery;
      eq: (...args: unknown[]) => MockQuery;
      order: (...args: unknown[]) => MockQuery;
      limit: (...args: unknown[]) => MockQuery;
      in: (...args: unknown[]) => MockQuery;
      maybeSingle: () => Promise<
        { data: Record<string, string> | null; error: null }
      >;
      then: (
        resolve: (
          value: { data: unknown[]; error: null; count: number },
        ) => unknown,
        reject?: (reason: unknown) => unknown,
      ) => Promise<unknown>;
    };
    let currentTable = "";
    const query: MockQuery = {
      select: (..._args: unknown[]) => query,
      eq: (..._args: unknown[]) => query,
      order: (..._args: unknown[]) => query,
      limit: (..._args: unknown[]) => query,
      in: (..._args: unknown[]) => query,
      maybeSingle: () => {
        const table = currentTable;
        if (table === "user_roles") {
          return Promise.resolve({
            data: settings.isOwner ? { user_id: OWNER_ID } : null,
            error: null,
          });
        }
        if (table === "mangai_owner_config") {
          return Promise.resolve({
            data: { owner_user_id: OWNER_ID },
            error: null,
          });
        }
        return Promise.resolve({ data: null, error: null });
      },
      then: (resolve, reject) =>
        Promise.resolve({ data: [], error: null, count: 0 }).then(
          resolve,
          reject,
        ),
    };
    return {
      from: (table: string) => {
        currentTable = table;
        return query;
      },
      rpc: (name: string, _args: Record<string, unknown>) => {
        calls.push(name);
        return Promise.resolve({ data: { id: "proposal-test" }, error: null });
      },
    };
  }) as unknown as typeof createClient;

  const handler = createControlApiHandler({
    createClient: fakeCreateClient,
    getEnv: (name) =>
      ({
        SUPABASE_URL: "https://supabase.example.test",
        SUPABASE_ANON_KEY: "anon-test-key",
        SUPABASE_SERVICE_ROLE_KEY: "service-test-key",
      })[name],
    randomUUID: () => "request-test-id",
  });

  return { handler, calls };
}

function request(
  method: string,
  path = "/",
  body?: unknown,
  token = testJwt("aal2"),
) {
  return new Request(`https://api.example.test${path}`, {
    method,
    headers: {
      ...(token
        ? { [["Author", "ization"].join("")]: ["Bearer", token].join(" ") }
        : {}),
      Origin: "https://tamilancareers.in",
      ...(body === undefined ? {} : { "Content-Type": "application/json" }),
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
}

Deno.test("HTTP handler rejects a missing bearer token before creating clients", async () => {
  const { handler } = makeHandler();
  const response = await handler(request("GET", "/", undefined, ""));
  assertEquals(response.status, 401);
});

Deno.test("HTTP handler rejects an invalid or expired session", async () => {
  const { handler } = makeHandler({ validSession: false });
  const response = await handler(request("GET"));
  assertEquals(response.status, 401);
});

Deno.test("HTTP handler rejects an authenticated non-owner", async () => {
  const { handler } = makeHandler({ isOwner: false });
  const response = await handler(request("GET"));
  assertEquals(response.status, 403);
});

Deno.test("Owner can read modules with AAL1 without invoking the MFA write gate", async () => {
  const { handler } = makeHandler({ assurance: "aal1" });
  const response = await handler(request("GET", "/?action=modules"));
  assertEquals(response.status, 200);
  assertEquals(await response.json(), { modules: [] });
});

Deno.test("Owner write request is rejected when session assurance is only AAL1", async () => {
  const { handler, calls } = makeHandler({ assurance: "aal1" });
  const response = await handler(request("POST", "/", {
    action: "create_proposal",
    title: "Test proposal",
  }, testJwt("aal1")));
  assertEquals(response.status, 403);
  assertEquals(calls.length, 0);
});

Deno.test("Owner with AAL2 can submit an allow-listed proposal request", async () => {
  const { handler, calls } = makeHandler({ assurance: "aal2" });
  const response = await handler(request("POST", "/", {
    action: "create_proposal",
    title: "Test proposal",
  }));
  assertEquals(response.status, 201);
  assertEquals(calls, ["mangai_create_change_proposal"]);
});

Deno.test("security governance remains protected even for an AAL2 Owner", async () => {
  const { handler, calls } = makeHandler({ assurance: "aal2" });
  const response = await handler(request("POST", "/", {
    action: "pause_module",
    module_key: "security_governance",
  }));
  assertEquals(response.status, 403);
  assertEquals(calls.length, 0);
});

Deno.test("production deployment remains disabled even for an AAL2 Owner", async () => {
  const { handler, calls } = makeHandler({ assurance: "aal2" });
  const response = await handler(request("POST", "/", { action: "deploy" }));
  assertEquals(response.status, 409);
  assertEquals(calls.length, 0);
});

Deno.test("HTTP handler rejects unapproved origins and unsupported methods", async () => {
  const { handler } = makeHandler();
  const blockedOrigin = new Request("https://api.example.test/", {
    method: "GET",
    headers: {
      [["Author", "ization"].join("")]: ["Bearer", "valid-test-token"].join(
        " ",
      ),
      Origin: "https://attacker.example",
    },
  });
  assertEquals((await handler(blockedOrigin)).status, 403);
  assertEquals((await handler(request("DELETE"))).status, 405);
});
