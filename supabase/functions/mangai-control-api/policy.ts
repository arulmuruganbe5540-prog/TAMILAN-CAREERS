export type OwnerGateInput = {
  userId: string | null;
  hasValidUser: boolean;
  roleLookupFailed: boolean;
  ownerLookupFailed: boolean;
  hasSuperAdminRole: boolean;
  ownerUserId: string | null;
};

export type OwnerGateResult = {
  allowed: boolean;
  status: 200 | 401 | 403 | 503;
  error: string;
};

/** Pure authorization decision shared by the Edge Function and Deno unit tests. */
export function authorizeMasterOwner(input: OwnerGateInput): OwnerGateResult {
  if (!input.hasValidUser || !input.userId) {
    return {
      allowed: false,
      status: 401,
      error: "Session is invalid or expired",
    };
  }
  if (input.roleLookupFailed || input.ownerLookupFailed) {
    return {
      allowed: false,
      status: 503,
      error: "Control registry is not installed or could not be checked",
    };
  }
  if (
    !input.hasSuperAdminRole || !input.ownerUserId ||
    input.ownerUserId !== input.userId
  ) {
    return {
      allowed: false,
      status: 403,
      error: "Master Owner permission required",
    };
  }
  return { allowed: true, status: 200, error: "" };
}

/** Writes require a verified AAL2 session; read-only requests do not call this gate. */
export function hasWriteAssurance(
  currentLevel: string | null | undefined,
  assuranceLookupFailed: boolean,
): boolean {
  return !assuranceLookupFailed && currentLevel === "aal2";
}

export function isProtectedModuleControl(
  action: string,
  moduleKey: string,
): boolean {
  return (action === "pause_module" || action === "resume_module") &&
    moduleKey === "security_governance";
}

export function isProductionReleaseAction(action: string): boolean {
  return action === "approve_production" || action === "deploy";
}
