#!/usr/bin/env python3
"""Regression guard for the shared site header and language preference workflow."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
global_js = (ROOT / "assets/global-experience.js").read_text(encoding="utf-8")
translator = (ROOT / "assets/auto-translate.js").read_text(encoding="utf-8")
protection = (ROOT / "assets/site-protection.js").read_text(encoding="utf-8")
footer_script = (ROOT / "assets/professional-footer.js").read_text(encoding="utf-8")
homepage = (ROOT / "index.html").read_text(encoding="utf-8")
pages = sorted(ROOT.glob("*.html"))

checks = {
    "header shows one canonical www domain label":
        global_js.lower().count('tc-site-domain">www.tamilancareers.in</span>') == 1
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
        and "qualification_pathways:\"qualification-pathways\"" in homepage
        and "career_tools:\"career-tools\"" in homepage
        and homepage.index('data-home-section="country-government"') < homepage.index('data-home-section="qualification_pathways"')
        and homepage.index('data-home-section="qualification_pathways"') < homepage.index('data-home-section="career_tools"')
        and "configured.concat(defaults.filter(key=>!configured.includes(key)))" in homepage,
}
for page in pages:
    content = page.read_text(encoding="utf-8")
    checks[f"{page.name} loads the shared site experience"] = 'assets/site-protection.js' in content

failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(("PASS" if ok else "FAIL") + ": " + name)
print(f"\\n{len(checks)-len(failed)}/{len(checks)} global header/language checks passed")
if failed:
    sys.exit(1)
