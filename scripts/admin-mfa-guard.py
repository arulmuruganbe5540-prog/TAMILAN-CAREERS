from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

ROLE_PAGES = [
    "admin-control.html",
    "admin-community-posts.html",
    "admin-company-verification.html",
    "admin-design-studio.html",
    "admin-global-control.html",
    "admin-job-post.html",
    "admin-job-reports.html",
    "admin-exam-resources.html",
]

failures = []
for name in ROLE_PAGES:
    path = ROOT / name
    if not path.is_file():
        failures.append(f"{name}: file missing")
        continue
    source = path.read_text(encoding="utf-8")
    for token in ("user_roles", "super_admin", "mfa.getAuthenticatorAssuranceLevel"):
        if token not in source:
            failures.append(f"{name}: missing required access-control check: {token}")

login = (ROOT / "admin-login.html").read_text(encoding="utf-8")
for token in ("mfa.getAuthenticatorAssuranceLevel", "mfa.challenge", "mfa.verify"):
    if token not in login:
        failures.append(f"admin-login.html: missing MFA sign-in step: {token}")

security = (ROOT / "admin-security.html").read_text(encoding="utf-8")
for token in ('mfa.enroll({factorType:"totp"', "mfa.challenge", "mfa.verify", "user_roles", "super_admin"):
    if token not in security:
        failures.append(f"admin-security.html: missing MFA enrollment/role check: {token}")

exam = (ROOT / "admin-exam-resources.html").read_text(encoding="utf-8")
if 'id="form" style="display:none"' not in exam:
    failures.append("admin-exam-resources.html: publish form must remain hidden until authorization")
if "allowed=true" not in exam:
    failures.append("admin-exam-resources.html: submit authorization state missing")

if failures:
    print("\n".join(failures))
    sys.exit(1)

print(f"Admin MFA guard passed: {len(ROLE_PAGES)} protected pages, login challenge, enrollment, and exam publishing gate.")
