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
    "country detection changes regional context while keeping English":
        "function setRegionalContext(countryCode,region,zone)" in global_js
        and 'document.documentElement.setAttribute("lang","en")' in global_js
        and 'language:"en"' in global_js
        and "country:countryCode" in global_js,
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
    "shared footer reuses an existing page footer":
        'var existingFooter=document.querySelector("body footer");' in footer_script
        and "if(existingFooter){addSuperAdminLink(existingFooter);return;}" in footer_script,
    "homepage keeps recent and government vacancy tables separate":
        'id="just-posted"' in homepage
        and 'id="latest-government"' in homepage
        and "No recent verified vacancies are available." in homepage
        and "No verified government vacancies are published yet." in homepage,
    "homepage presents vacancy updates before career discovery":
        homepage.index('id="just-posted"') < homepage.index('id="latest-government"')
        and homepage.index('id="latest-government"') < homepage.index('id="updates"')
        and homepage.index('id="updates"') < homepage.index("EXPLORE TAMILAN CAREERS"),
    "homepage provides direct access to private jobs and exam preparation":
        'href="private-jobs.html"' in homepage
        and 'href="exam-preparation.html"' in homepage
        and 'href="indian-government-jobs.html"' in homepage,
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
