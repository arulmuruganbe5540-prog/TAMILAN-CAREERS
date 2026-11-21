#!/usr/bin/env python3
"""Static regression guard for the independent Private Jobs review -> publish flow."""
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
private_admin = read("admin-private-jobs.html")
listing = read("private-jobs.html")
details = read("job-details.html")
setup = read("supabase-setup-pending.sql")
submission = read("supabase-admin-job-publish-setup.sql")
publisher = read("supabase-private-job-review-publish.sql")

checks = {
    "company UI submits through the protected review RPC":
        "tc_submit_company_job_draft_for_review" in company,
    "company UI captures salary period":
        'id="salaryPeriod"' in company and '"salaryPeriod"' in company,
    "company draft status remains explicit":
        "draft_status" in company,
    "Admin UI reads the private review queue":
        'from("admin_job_post_reviews")' in admin and "published_private_job_id" in admin,
    "Admin UI invokes the private-only publisher":
        'db.rpc("tc_admin_publish_private_job"' in admin,
    "Admin UI restricts access using the signed-in Super Admin role":
        'from("user_roles")' in admin and '"super_admin"' in admin and 'db.auth.getUser()' in admin,
    "Admin review enforces MFA assurance before showing controls":
        'getAuthenticatorAssuranceLevel()' in admin and 'currentLevel!=="aal2"' in admin,
    "Admin queue offers explicit approve and reject decisions":
        'data-action="approve"' in admin and 'data-action="reject"' in admin,
    "Approval is a separate step and does not publish immediately":
        'status==="pending_review"' in admin and 'status==="approved"' in admin and 'update.reviewed_by=user.id' in admin,
    "Publishing requires a separate confirmation and protected RPC":
        'confirm("Publish this approved Private Job into the separate private_jobs table?' in admin and 'db.rpc("tc_admin_publish_private_job"' in admin,
    "Company jobs cannot be published until the company is verified":
        "verification_status='verified'" in publisher and "source_draft_id" in publisher,
    "Admin rejects require a non-empty reason":
        'if(!reason.trim())' in admin and 'update.review_note=reason.trim()' in admin,
    "Private admin form validates required fields and salary bounds":
        '!title||!description||!country||!category' in private_admin and 'Number(min)>Number(max)' in private_admin,
    "Admin queue errors are shown instead of silently ignored":
        'if(error){$("queue").innerHTML' in admin,
    "Private admin form captures salary period":
        'id="salary_period"' in private_admin and 'salary_period' in private_admin,
    "Private public listing labels salary period":
        "salary_period" in listing and 'Salary period: ' in listing,
    "job detail labels salary period":
        "salary_period" in details and "salarySuffix" in details,
    "company drafts are protected by RLS":
        "job_posting_drafts" in setup and "enable row level security" in setup.lower(),
    "submission RPC verifies active company membership":
        "cm.member_status = 'active'" in submission and "cm.member_role in ('owner','hr_manager','recruiter')" in submission,
    "submission RPC preserves exact company ID":
        "'company_id', v_company_id" in submission,
    "submission rejects past dates using India timezone":
        "(now() at time zone 'Asia/Kolkata')::date" in submission,
    "publisher requires verified company":
        "c.verification_status='verified'" in publisher,
    "publisher is idempotent for already-published review":
        "if v_review.published_private_job_id is not null then" in publisher,
    "publisher only accepts approved review":
        "v_review.status<>'approved'" in publisher,
    "publisher writes only to the independent private_jobs table":
        "insert into public.private_jobs" in publisher and "insert into public.jobs" not in publisher,
    "salary period is validated before insert":
        "v_salary_period not in ('monthly','daily')" in publisher and "v_salary_currency,v_salary_period" in publisher,
}

failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(("PASS" if ok else "FAIL") + ": " + name)
print(f"\n{len(checks)-len(failed)}/{len(checks)} workflow checks passed")
if failed:
    sys.exit(1)
