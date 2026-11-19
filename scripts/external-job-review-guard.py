from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
page = ROOT / "external-job-review.html"
migration = ROOT / "supabase/migrations/20261119050000_secure_external_job_candidate_review.sql"
failures = []

if not page.is_file():
    failures.append("external-job-review.html: file missing")
else:
    source = page.read_text(encoding="utf-8")
    for token in ("user_roles", "super_admin", "mfa.getAuthenticatorAssuranceLevel",
                  "tc_review_external_job_candidate", "source_domain_matched",
                  "original_notice_opened", "dates_verified", "eligibility_verified",
                  "application_link_verified", "duplicate_checked"):
        if token not in source:
            failures.append(f"external-job-review.html: missing {token}")
    for forbidden in ('from("jobs").insert', "from('jobs').insert",
                      'from("jobs").upsert', "from('jobs').upsert"):
        if forbidden in source:
            failures.append("external-job-review.html: candidate review must never publish or insert jobs")

if not migration.is_file():
    failures.append("external candidate review migration: file missing")
else:
    sql = migration.read_text(encoding="utf-8")
    for token in ("security definer", "set search_path = ''", "private.is_super_admin()",
                  "revoke all on function", "from anon", "grant execute",
                  "original_notice_opened", "dates_verified", "eligibility_verified",
                  "application_link_verified", "duplicate_checked"):
        if token.lower() not in sql.lower():
            failures.append(f"external candidate review migration: missing {token}")

if failures:
    print("\n".join(failures))
    sys.exit(1)

print("External job review guard passed: Super Admin/MFA page checks, six-step verification, and non-publishing RPC.")
