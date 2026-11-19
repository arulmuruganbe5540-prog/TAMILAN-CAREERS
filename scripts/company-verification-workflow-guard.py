#!/usr/bin/env python3
"""Static regression guard for the Super Admin company verification workflow."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
page = (ROOT / "admin-company-verification.html").read_text(encoding="utf-8")
status_page = (ROOT / "company-verification-status.html").read_text(encoding="utf-8")

checks = {
    "verification review page requires a signed-in user":
        'db.auth.getUser()' in page,
    "verification review page checks the super_admin role":
        'from("user_roles")' in page and '"super_admin"' in page,
    "verification review page enforces MFA assurance":
        'getAuthenticatorAssuranceLevel()' in page and 'nextLevel==="aal2"' in page,
    "review queue reads verification requests":
        'from("company_verification_requests")' in page,
    "uploaded documents are accessed through short-lived signed URLs":
        'createSignedUrl(d.storage_path,300)' in page,
    "review decisions go through the protected database RPC":
        'db.rpc("tc_review_company_verification"' in page,
    "verification requires a meaningful admin audit note":
        'note.length<20' in page,
    "rejection requires a reason":
        'decision==="rejected"&&note.length<10' in page,
    "review UI exposes only the supported review decisions":
        all('data-decision="'+s+'"' in page for s in ("under_review", "more_information", "rejected", "verified")),
    "company status page restricts requests to the signed-in submitter":
        'eq("submitted_by",user.id)' in status_page,
    "company resubmission uses the protected RPC":
        'db.rpc("tc_company_resubmit_verification"' in status_page,
    "verification render errors are caught and shown to the admin":
        'await render()' in page and 'Could not load or display verification requests:' in page,
}

failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(("PASS" if ok else "FAIL") + ": " + name)
print(f"\\n{len(checks)-len(failed)}/{len(checks)} company verification checks passed")
if failed:
    sys.exit(1)
