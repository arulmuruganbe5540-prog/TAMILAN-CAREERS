#!/usr/bin/env python3
"""Regression guard for the staged TAMILAN AI rollout.

This is a static safety check. It does not call a model or prove runtime security.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
legacy = {
    "supabase/functions/ai-resume-match/index.ts": "AI resume matching",
    "supabase/functions/bilingual-job-search/index.ts": "AI multilingual job search",
}
errors = []

for relative, feature in legacy.items():
    path = ROOT / relative
    if not path.is_file():
        errors.append(f"Missing legacy endpoint: {relative}")
        continue
    source = path.read_text(encoding="utf-8")
    if "status:410" not in source.replace(" ", ""):
        errors.append(f"{relative}: expected HTTP 410 disabled response")
    if "feature has been disabled" not in source.lower():
        errors.append(f"{relative}: disabled notice missing")
    if feature.lower() not in source.lower():
        errors.append(f"{relative}: feature identity missing")

plan = ROOT / "TAMILAN-AI-INTEGRATION-PLAN-TA.md"
if not plan.is_file():
    errors.append("Missing TAMILAN-AI-INTEGRATION-PLAN-TA.md")
else:
    text = plan.read_text(encoding="utf-8").lower()
    for phrase in ("default off", "service-role key", "read-only retrieval",
                   "prompt injection", "owner-ன் வெளிப்படையான ஒப்புதல்"):
        if phrase not in text:
            errors.append(f"Integration plan missing safety requirement: {phrase}")

# Browser-delivered code must not contain server-side model credentials or
# the Supabase service-role key. Secret names in server-side documentation are OK.
browser_files = [ROOT / "index.html"]
assets = ROOT / "assets"
if assets.is_dir():
    browser_files.extend(assets.rglob("*.js"))
for path in browser_files:
    if not path.is_file():
        continue
    source = path.read_text(encoding="utf-8", errors="replace").lower()
    for forbidden in ("supabase_service_role_key", "service_role_key",
                      "tamilan_ai_model_token", "tamilan_ai_model_url"):
        if forbidden in source:
            errors.append(f"Possible server secret reference in browser file: {path.relative_to(ROOT)} ({forbidden})")

if errors:
    for error in errors:
        print(f"FAIL: {error}")
    raise SystemExit(1)

print("PASS: legacy AI endpoints remain disabled; integration safety plan exists; no known server-secret names in homepage/browser assets.")
print("NOTE: static regression guard only; it does not validate deployed Edge Functions, secrets, or live model security.")
