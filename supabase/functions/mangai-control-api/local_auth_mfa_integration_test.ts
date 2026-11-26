import { assertEquals } from "@std/assert";
import { createClient } from "@supabase/supabase-js";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const functionUrl = Deno.env.get("MANGAI_FUNCTION_URL")!;
const ownerEmail = "mangai-owner@example.test";
const ownerPassword = "LocalOnly-Owner-Password-2026!";

const publicClient = createClient(supabaseUrl, anonKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const adminClient = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

function decodeBase32(input: string): Uint8Array {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
  let bits = "";
  for (const char of input.toUpperCase().replace(/=+$/g, "")) {
    const value = alphabet.indexOf(char);
    if (value < 0) throw new Error("Invalid TOTP base32 secret");
    bits += value.toString(2).padStart(5, "0");
  }
  const bytes: number[] = [];
  for (let i = 0; i + 8 <= bits.length; i += 8) {
    bytes.push(Number.parseInt(bits.slice(i, i + 8), 2));
  }
  return new Uint8Array(bytes);
}

async function totp(secret: string): Promise<string> {
  const decodedSecret = decodeBase32(secret);
  const keyBuffer = new ArrayBuffer(decodedSecret.byteLength);
  new Uint8Array(keyBuffer).set(decodedSecret);
  const key = await crypto.subtle.importKey(
    "raw",
    keyBuffer,
    { name: "HMAC", hash: "SHA-1" },
    false,
    ["sign"],
  );
  const counter = BigInt(Math.floor(Date.now() / 30_000));
  const message = new Uint8Array(8);
  new DataView(message.buffer).setBigUint64(0, counter);
  const signature = new Uint8Array(
    await crypto.subtle.sign("HMAC", key, message),
  );
  const offset = signature[signature.length - 1] & 0x0f;
  const binary = ((signature[offset] & 0x7f) << 24) |
    ((signature[offset + 1] & 0xff) << 16) |
    ((signature[offset + 2] & 0xff) << 8) |
    (signature[offset + 3] & 0xff);
  return String(binary % 1_000_000).padStart(6, "0");
}

async function invoke(
  accessToken: string,
  method: "GET" | "POST",
  body?: unknown,
) {
  return await fetch(
    method === "GET" ? `${functionUrl}?action=modules` : functionUrl,
    {
      method,
      headers: {
        apikey: anonKey,
        Authorization: `Bearer ${accessToken}`,
        Origin: "https://tamilancareers.in",
        ...(body === undefined ? {} : { "Content-Type": "application/json" }),
      },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    },
  );
}

Deno.test("real local Supabase Auth + Edge Function enforces Owner and AAL2", async () => {
  // Create the disposable Owner through GoTrue itself. Direct SQL inserts into
  // auth.users are not guaranteed to be visible to the Auth admin API.
  const { data: ownerCreated, error: ownerCreateError } = await adminClient.auth
    .admin.createUser({
      email: ownerEmail,
      password: ownerPassword,
      email_confirm: true,
    });
  if (ownerCreateError || !ownerCreated.user) {
    throw new Error(
      `Owner fixture creation failed: ${
        ownerCreateError?.message ?? "no user"
      }`,
    );
  }

  // Rebind only this disposable local test database to the Auth-created user.
  const fixtureId = "11111111-1111-4111-8111-111111111111";
  const { error: roleUpdateError } = await adminClient.from("user_roles")
    .update({ user_id: ownerCreated.user.id })
    .eq("user_id", fixtureId)
    .eq("role", "super_admin");
  if (roleUpdateError) {
    throw new Error(
      `Owner role fixture update failed: ${roleUpdateError.message}`,
    );
  }
  const { error: ownerUpdateError } = await adminClient
    .from("mangai_owner_config")
    .update({ owner_user_id: ownerCreated.user.id })
    .eq("singleton", true);
  if (ownerUpdateError) {
    throw new Error(
      `Owner binding fixture update failed: ${ownerUpdateError.message}`,
    );
  }

  const { data: signedIn, error: signInError } = await publicClient.auth
    .signInWithPassword({ email: ownerEmail, password: ownerPassword });
  if (signInError || !signedIn.session) {
    throw new Error(
      `Owner sign-in failed: ${signInError?.message ?? "no session"}`,
    );
  }

  const ownerAal1Token = signedIn.session.access_token;
  const aal1 = await publicClient.auth.mfa.getAuthenticatorAssuranceLevel();
  if (aal1.error || !aal1.data) {
    throw new Error(
      `AAL1 lookup failed: ${aal1.error?.message ?? "missing data"}`,
    );
  }
  assertEquals(aal1.data.currentLevel, "aal1");

  const readResponse = await invoke(ownerAal1Token, "GET");
  assertEquals(readResponse.status, 200);

  const deniedWrite = await invoke(ownerAal1Token, "POST", {
    action: "create_proposal",
    title: "AAL1 must not write",
  });
  assertEquals(deniedWrite.status, 403);

  const { data: enrolled, error: enrollError } = await publicClient.auth.mfa
    .enroll({ factorType: "totp", friendlyName: "CI local test factor" });
  if (enrollError || !enrolled?.totp?.secret) {
    throw new Error(
      `TOTP enrollment failed: ${enrollError?.message ?? "missing secret"}`,
    );
  }

  const { data: challenge, error: challengeError } = await publicClient.auth
    .mfa.challenge({ factorId: enrolled.id });
  if (challengeError || !challenge?.id) {
    throw new Error(
      `TOTP challenge failed: ${
        challengeError?.message ?? "missing challenge"
      }`,
    );
  }

  const code = await totp(enrolled.totp.secret);
  const { error: verifyError } = await publicClient.auth.mfa.verify({
    factorId: enrolled.id,
    challengeId: challenge.id,
    code,
  });
  if (verifyError) {
    throw new Error(`TOTP verify failed: ${verifyError.message}`);
  }

  const { data: aal2, error: aal2Error } = await publicClient.auth.mfa
    .getAuthenticatorAssuranceLevel();
  if (aal2Error) throw new Error(`AAL2 lookup failed: ${aal2Error.message}`);
  assertEquals(aal2.currentLevel, "aal2");
  const { data: verifiedSession } = await publicClient.auth.getSession();
  if (!verifiedSession.session) {
    throw new Error("AAL2 session was not retained");
  }

  const allowedWrite = await invoke(
    verifiedSession.session.access_token,
    "POST",
    {
      action: "create_proposal",
      title: "Local AAL2 integration test proposal",
      description: "Disposable CI-only proposal.",
      risk_level: "low",
    },
  );
  assertEquals(allowedWrite.status, 201);
  const created = await allowedWrite.json();
  if (!created?.proposal?.id) throw new Error("AAL2 proposal was not created");

  const protectedWrite = await invoke(
    verifiedSession.session.access_token,
    "POST",
    { action: "pause_module", module_key: "security_governance" },
  );
  assertEquals(protectedWrite.status, 403);

  const deployWrite = await invoke(
    (await publicClient.auth.getSession()).data.session!.access_token,
    "POST",
    { action: "deploy" },
  );
  assertEquals(deployWrite.status, 409);

  const invalidToken = await invoke("invalid-expired-token", "GET");
  assertEquals(invalidToken.status, 401);

  const { data: nonOwner, error: createError } = await adminClient.auth.admin
    .createUser({
      email: "non-owner@example.test",
      password: "LocalOnly-NonOwner-Password-2026!",
      email_confirm: true,
    });
  if (createError || !nonOwner.user) {
    throw new Error(
      `Non-owner fixture creation failed: ${createError?.message ?? "no user"}`,
    );
  }
  const nonOwnerClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: nonOwnerSession, error: nonOwnerSignInError } =
    await nonOwnerClient.auth.signInWithPassword({
      email: "non-owner@example.test",
      password: "LocalOnly-NonOwner-Password-2026!",
    });
  if (nonOwnerSignInError || !nonOwnerSession.session) {
    throw new Error(
      `Non-owner sign-in failed: ${
        nonOwnerSignInError?.message ?? "no session"
      }`,
    );
  }
  const nonOwnerResponse = await invoke(
    nonOwnerSession.session.access_token,
    "GET",
  );
  assertEquals(nonOwnerResponse.status, 403);

  await adminClient.auth.admin.deleteUser(nonOwner.user.id);
  await adminClient.from("mangai_change_proposals").delete().eq(
    "id",
    created.proposal.id,
  );
  await publicClient.auth.mfa.unenroll({ factorId: enrolled.id });
});
