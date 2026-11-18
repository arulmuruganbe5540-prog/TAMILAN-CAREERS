#!/usr/bin/env python3
"""Static regression guard for the company draft -> Admin review -> public job flow."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

def read(path):
    p = ROOT / path
    if not p.is_file():
        raise SystemExit(f"FAIL: required file missing: {path}")
    return p.read_text(encoding="utf-8")

company = read("job-posting.html")
admin = read("admin-job-post.html")
listing = read("jobs.html")
details = read("job-details.html")
setup = read("supabase-setup-pending.sql")
migration = read("supabase-admin-job-publish-setup.sql")

checks = {
    "company UI submits through the protected review RPC":
        "tc_submit_company_job_draft_for_review" in company,
    "company UI captures salary period":
        'id="salaryPeriod"' in company and '"salaryPeriod"' in company,
    "company draft status remains explicit":
        "draft_status" in company,
    "Admin UI reads the private review queue":
        "admin_job_post_reviews" in admin,
    "Admin UI invokes the protected publisher":
        "tc_admin_publish_job" in admin,
    "Admin UI restricts access using the signed-in user role row under RLS":
        'from("user_roles")' in admin and '"super_admin"' in admin,
    "Admin UI captures salary period":
        'id="salaryPeriod"' in admin and '"salaryPeriod"' in admin,
    "public listing labels salary period":
        "salary_period" in listing and "salarySuffix" in listing,
    "job detail labels salary period":
        "salary_period" in details and "salarySuffix" in details,
    "company drafts are protected by RLS":
        "job_posting_drafts" in setup and "enable row level security" in setup.lower(),
    "submission RPC verifies active company membership":
        "cm.member_status = 'active'" in migration and "cm.member_role in ('owner','hr_manager','recruiter')" in migration,
    "submission RPC preserves exact company ID":
        "'company_id', v_company_id" in migration,
    "submission rejects past dates using India timezone":
        "(now() at time zone 'Asia/Kolkata')::date" in migration,
    "publisher requires verified company":
        "c.verification_status='verified'" in migration,
    "publisher is idempotent for already-published review":
        "if v_review.published_job_id is not null then" in migration,
    "publisher only accepts approved review":
        "v_review.status <> 'approved'" in migration,
    "salary period is validated before insert":
        "v_salary_period not in ('monthly','daily')" in migration and "v_salary_currency,v_salary_period,v_vacancies" in migration,
}

failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(("PASS" if ok else "FAIL") + ": " + name)
print(f"\n{len(checks)-len(failed)}/{len(checks)} workflow checks passed")
if failed:
    sys.exit(1)
