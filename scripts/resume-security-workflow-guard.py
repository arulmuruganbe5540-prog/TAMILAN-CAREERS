#!/usr/bin/env python3
"""Static regression guard for private candidate Resume storage and employer access."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]

def read(path):
    target = ROOT / path
    if not target.is_file():
        raise SystemExit(f"FAIL: required file missing: {path}")
    return target.read_text(encoding="utf-8")

page = read("resume-documents.html")
function = read("supabase/functions/company-resume-access/index.ts")
setup = read("supabase-setup-pending.sql")
focused = read("supabase-resume-storage.sql")
docs = read("RESUME-SECURITY-SETUP.md")
application = read("apply.html")
employer = read("company-applicants.html")

checks = {}

def check(name, condition):
    checks[name] = bool(condition)

page_bucket = re.search(r'const\s+BUCKET\s*=\s*"([^"]+)"', page)
function_bucket = re.search(r'\.storage\s*\.from\("([^"]+)"\)', function)
def migration_bucket(source):
    match = re.search(
        r"insert\s+into\s+storage\.buckets[\s\S]{0,250}?values\s*\(\s*'([^']+)'",
        source, re.IGNORECASE
    )
    return match.group(1) if match else None

setup_bucket = migration_bucket(setup)
focused_bucket = migration_bucket(focused)
doc_bucket = re.search(r"Storage bucket \`([^\`]+)\`", docs, re.IGNORECASE)

bucket_values = [
    page_bucket.group(1) if page_bucket else None,
    function_bucket.group(1) if function_bucket else None,
    setup_bucket,
    focused_bucket,
    doc_bucket.group(1) if doc_bucket else None,
]
check("Resume bucket name is explicit in every layer", all(bucket_values))
check("Website, Edge Function, both migrations and security guide use one bucket", len(set(bucket_values)) == 1)
check("Resume bucket migrations always configure a private bucket", setup_bucket is not None and focused_bucket is not None and
      re.search(r"insert\s+into\s+storage\.buckets[\s\S]{0,350}?false", setup, re.IGNORECASE) and
      re.search(r"insert\s+into\s+storage\.buckets[\s\S]{0,350}?false", focused, re.IGNORECASE))
check("Storage policies restrict all four operations to the owner's folder", all(
    re.search(pattern, setup, re.IGNORECASE) and "bucket_id = 'resumes'" in setup
    for pattern in [
        r"on\s+storage\.objects\s+for\s+select",
        r"on\s+storage\.objects\s+for\s+insert",
        r"on\s+storage\.objects\s+for\s+update",
        r"on\s+storage\.objects\s+for\s+delete",
    ]
) and "(select auth.uid()::text)" in setup and "storage.foldername(name)" in setup)
check("Candidate metadata is protected by owner-only RLS", "alter table public.candidate_resumes enable row level security" in setup.lower()
      and "using (user_id = (select auth.uid()))" in setup)
check("Resume page never creates a public URL", "getPublicUrl" not in page and "createSignedUrl" in page)
check("Resume page uses the signed-in user's folder", "currentUser.id+\"/\"+name" in page)
check("Application form stores the selected Resume ID", "resume_id:selectedResume" in application)
check("Employer UI invokes the server-side access Function", 'functions.invoke("company-resume-access"' in employer)
check("Function validates the caller's Supabase session", "auth.getUser(token)" in function)
check("Function only permits active application states", '["applied", "under_review", "shortlisted"]' in function)
check("Function verifies active company role or company owner", "company.owner_user_id === userId" in function
      and '["owner", "hr_manager", "recruiter"]' in function and 'membership?.member_status === "active"' in function)
check("Function verifies Resume ownership and folder path", '.eq("user_id", application.candidate_id)' in function
      and 'resume.file_path.startsWith(application.candidate_id + "/")' in function)
check("Employer receives only a 60-second signed URL", "createSignedUrl(resume.file_path, 60" in function
      and "expires_in_seconds: 60" in function)
check("Service-role key is used only in the server Function source", "SUPABASE_SERVICE_ROLE_KEY" in function
      and "SUPABASE_SERVICE_ROLE_KEY" not in page)

for name, passed in checks.items():
    print(("PASS" if passed else "FAIL") + ": " + name)
failed = [name for name, passed in checks.items() if not passed]
print(f"\n{len(checks)-len(failed)}/{len(checks)} Resume security checks passed")
if failed:
    print("Bucket values found:", bucket_values)
    sys.exit(1)
