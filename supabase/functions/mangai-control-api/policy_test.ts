import {
  authorizeMasterOwner,
  hasWriteAssurance,
  isProductionReleaseAction,
  isProtectedModuleControl,
} from "./policy.ts";
import { assertEquals } from "jsr:@std/assert@1";

const owner = {
  userId: "owner-1",
  hasValidUser: true,
  roleLookupFailed: false,
  ownerLookupFailed: false,
  hasSuperAdminRole: true,
  ownerUserId: "owner-1",
};

Deno.test("missing or invalid identity is rejected with 401", () => {
  assertEquals(
    authorizeMasterOwner({ ...owner, userId: null, hasValidUser: false }),
    {
      allowed: false,
      status: 401,
      error: "Session is invalid or expired",
    },
  );
});

Deno.test("non-owner and mismatched owner binding are rejected with 403", () => {
  assertEquals(
    authorizeMasterOwner({ ...owner, hasSuperAdminRole: false }).status,
    403,
  );
  assertEquals(
    authorizeMasterOwner({ ...owner, ownerUserId: "another-user" }).status,
    403,
  );
});

Deno.test("missing or failed control registry fails closed with 503", () => {
  assertEquals(
    authorizeMasterOwner({ ...owner, roleLookupFailed: true }).status,
    503,
  );
  assertEquals(
    authorizeMasterOwner({ ...owner, ownerLookupFailed: true }).status,
    503,
  );
  assertEquals(
    authorizeMasterOwner({ ...owner, ownerUserId: null }).status,
    403,
  );
});

Deno.test("only the exact Master Owner identity and role are allowed", () => {
  assertEquals(authorizeMasterOwner(owner), {
    allowed: true,
    status: 200,
    error: "",
  });
});

Deno.test("write assurance requires AAL2 and a successful assurance lookup", () => {
  assertEquals(hasWriteAssurance("aal1", false), false);
  assertEquals(hasWriteAssurance("aal2", true), false);
  assertEquals(hasWriteAssurance(null, false), false);
  assertEquals(hasWriteAssurance("aal2", false), true);
});

Deno.test("security governance cannot be paused or resumed", () => {
  assertEquals(
    isProtectedModuleControl("pause_module", "security_governance"),
    true,
  );
  assertEquals(
    isProtectedModuleControl("resume_module", "security_governance"),
    true,
  );
  assertEquals(
    isProtectedModuleControl("pause_module", "government_jobs"),
    false,
  );
  assertEquals(
    isProtectedModuleControl("create_proposal", "security_governance"),
    false,
  );
});

Deno.test("production deployment actions remain explicitly disabled", () => {
  assertEquals(isProductionReleaseAction("deploy"), true);
  assertEquals(isProductionReleaseAction("approve_production"), true);
  assertEquals(isProductionReleaseAction("create_proposal"), false);
});
