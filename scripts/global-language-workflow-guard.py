#!/usr/bin/env python3
"""Regression guard for the shared site header and language preference workflow."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
global_js = (ROOT / "assets/global-experience.js").read_text(encoding="utf-8")
translator = (ROOT / "assets/auto-translate.js").read_text(encoding="utf-8")
protection = (ROOT / "assets/site-protection.js").read_text(encoding="utf-8")
pages = ["index.html", "jobs.html", "job-posting.html", "company-profile.html",
         "dashboard.html", "login.html", "admin-job-post.html",
         "company-verification-status.html"]

checks = {
    "header shows one canonical www domain label":
        'tc-site-domain">www.tamilancareers.in</span>' in global_js
        and 'querySelectorAll(".brand,.footer-brand")' not in global_js,
    "duplicate static language list is removed":
        'class="tc-langs"' not in global_js and 'மொழிகள் / Languages:' not in global_js,
    "one interactive language selector remains":
        'id="tc-language-select"' in global_js and 'addEventListener("change"' in global_js,
    "selected language is persisted across reloads":
        'localStorage.setItem(LANG_STORAGE,this.value)' in global_js
        and 'localStorage.getItem(LANG_STORAGE)' in global_js,
    "India defaults to English unless a preference is selected":
        '"IN":{name:"India",langs:["ta","en","hi"],primary:"en"' in global_js
        and 'countryCode!=="IN"' in global_js,
    "translator reads the active locale":
        'window.TC_LOCALE&&window.TC_LOCALE.language' in translator,
    "translator covers dynamically inserted content":
        'new MutationObserver' in translator and 'r.addedNodes' in translator,
    "shared site script loads global language experience":
        "assets/global-experience.js" in protection,
}
for name in pages:
    content = (ROOT / name).read_text(encoding="utf-8")
    checks[f"{name} loads the shared site experience"] = 'assets/site-protection.js' in content

failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(("PASS" if ok else "FAIL") + ": " + name)
print(f"\\n{len(checks)-len(failed)}/{len(checks)} global header/language checks passed")
if failed:
    sys.exit(1)
