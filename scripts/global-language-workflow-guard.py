#!/usr/bin/env python3
"""Regression guard for the English-only site experience and shared navigation."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
global_js = (ROOT / "assets/global-experience.js").read_text(encoding="utf-8")
translator = (ROOT / "assets/auto-translate.js").read_text(encoding="utf-8")
seo = (ROOT / "assets/seo.js").read_text(encoding="utf-8")
protection = (ROOT / "assets/site-protection.js").read_text(encoding="utf-8")
footer_script = (ROOT / "assets/professional-footer.js").read_text(encoding="utf-8")
homepage = (ROOT / "index.html").read_text(encoding="utf-8")
pages = sorted(p for p in ROOT.glob("*.html"))

checks = {
    "header shows one canonical www domain label":
        global_js.lower().count('tc-site-domain">www.tamilancareers.in</span>') == 1
        and 'querySelectorAll(".brand,.footer-brand")' not in global_js,
    "language selectors and language preference storage are absent":
        "tc-language-select" not in global_js
        and "LANG_STORAGE" not in global_js
        and "tc-guide-demo-language" not in global_js
        and "languageSelect" not in global_js,
    "country detection does not choose or switch the website language":
        "navigator.language" not in global_js
        and "primary:" not in global_js
        and "langs:[" not in global_js
        and 'setAttribute("lang","en")' in global_js,
    "automatic translation is explicitly disabled":
        "English-only" in translator
        and "MutationObserver" not in translator
        and "tc:locale-ready" not in translator,
    "all public HTML pages declare English":
        all(re.search(r"<html[^>]*lang=.en.", p.read_text(encoding="utf-8"), re.I) for p in pages),
    "all public HTML pages contain no Tamil-script interface text":
        all(not re.search(r"[\u0B80-\u0BFF]", p.read_text(encoding="utf-8")) for p in pages),
    "shared site script loads global experience":
        "assets/global-experience.js" in protection,
    "premium banner replaces the logo in place instead of creating a second header row":
        "brand.replaceWith(link)" in global_js
        and "header.insertBefore(link,header.firstChild)" not in global_js
        and ".tc-premium-header-shell .tc-premium-header-brand" in global_js,
    "shared footer does not duplicate an existing page footer":
        'if(document.querySelector("body footer"))return;' in footer_script,
    "homepage latest jobs excludes jobs already featured above":
        "const featuredSections=[" in homepage
        and "const alreadyShownIds=new Set()" in homepage
        and "return !id||!alreadyShownIds.has(id)" in homepage
        and "const overseasJobs=foreignError?[]:(foreignData||[])" in homepage,
    "homepage prioritizes live jobs before career discovery and keeps education/tools later":
        "const sections={country_government_jobs:" in homepage
        and 'qualification_pathways:"qualification-pathways"' in homepage
        and 'career_tools:"career-tools"' in homepage
        and homepage.split("const sections={",1)[1].split("};",1)[0].index("country_government_jobs:") < homepage.split("const sections={",1)[1].split("};",1)[0].index("qualification_pathways:")
        and homepage.split("const sections={",1)[1].split("};",1)[0].index("qualification_pathways:") < homepage.split("const sections={",1)[1].split("};",1)[0].index("career_tools:")
        and "const order=defaults;" in homepage,
    "main navigation links directly to private jobs and career tools":
        '<a href="jobs.html?job_kind=private">Private Jobs</a>' in homepage
        and '<a href="#career-tools">Career Tools</a>' in homepage
        and '<a href="indian-government-jobs.html">Government Jobs</a>' in homepage,
    "homepage publishes accurate website and organization structured data":
        '"@type": "WebSite"' in seo
        and '"@type": "Organization"' in seo
        and '"email": "arulmuruganbe5540@gmail.com"' in seo
        and '"contactType": "customer support"' in seo,
}
for page in pages:
    content = page.read_text(encoding="utf-8")
    checks[f"{page.name} loads the shared site experience"] = "assets/site-protection.js" in content

failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(("PASS" if ok else "FAIL") + ": " + name)
print(f"\n{len(checks)-len(failed)}/{len(checks)} global English-only checks passed")
if failed:
    sys.exit(1)
