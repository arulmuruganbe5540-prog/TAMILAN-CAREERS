#!/usr/bin/env python3
"""Read-only local website health audit for TAMILAN CAREERS.

Checks internal links/assets, duplicate HTML IDs, missing image alt text and
basic page metadata. It reports problems; it never edits website pages.
"""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlparse, unquote
from datetime import datetime, timezone
import json
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / "website-health-report.json"
IGNORE = {".git", ".github", "node_modules", ".venv", "__pycache__"}
HTML_FILES = sorted(p for p in ROOT.rglob("*.html") if not any(x in IGNORE for x in p.parts))

class AuditParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []
        self.ids = []
        self.images_without_alt = 0
        self.has_title = False
        self.has_viewport = False
        self.title_open = False
        self.title_text = ""
        self.inline_scripts = []
        self.script_open = False
        self.current_script = []
    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag in ("a", "link", "script", "img", "source"):
            for key in ("href", "src"):
                if a.get(key):
                    self.links.append(a[key])
        if tag == "img" and "alt" not in a:
            self.images_without_alt += 1
        if a.get("id"):
            self.ids.append(a["id"])
        if tag == "script" and not a.get("src"):
            self.script_open = True
            self.current_script = []
        if tag == "title":
            self.title_open = True
        if tag == "meta" and a.get("name", "").lower() == "viewport":
            self.has_viewport = True
    def handle_endtag(self, tag):
        if tag == "title":
            self.title_open = False
            self.has_title = bool(self.title_text.strip())
        if tag == "script" and self.script_open:
            self.inline_scripts.append("".join(self.current_script))
            self.script_open = False
            self.current_script = []
    def handle_data(self, data):
        if self.title_open:
            self.title_text += data
        if self.script_open:
            self.current_script.append(data)

def local_target(page, raw):
    raw = raw.strip()
    if not raw or raw.startswith(("data:", "javascript:", "mailto:", "tel:")):
        return None
    parsed = urlparse(raw)
    if parsed.scheme or parsed.netloc:
        return None
    path = parsed.path
    if not path:
        return page
    target = (page.parent / path).resolve()
    try:
        target.relative_to(ROOT.resolve())
    except ValueError:
        return ("outside", raw)
    if target.is_dir():
        target = target / "index.html"
    return target

issues = []
warnings = []
checked_links = 0
for page in HTML_FILES:
    try:
        parser = AuditParser()
        parser.feed(page.read_text(encoding="utf-8", errors="replace"))
    except OSError as exc:
        issues.append({"file": str(page.relative_to(ROOT)), "type": "read_error", "detail": str(exc)})
        continue
    seen = set()
    for item in parser.ids:
        if item in seen:
            warnings.append({"file": str(page.relative_to(ROOT)), "type": "duplicate_id", "detail": item})
        seen.add(item)
    if not parser.has_title:
        warnings.append({"file": str(page.relative_to(ROOT)), "type": "missing_title"})
    if not parser.has_viewport:
        warnings.append({"file": str(page.relative_to(ROOT)), "type": "missing_mobile_viewport"})
    if parser.images_without_alt:
        warnings.append({"file": str(page.relative_to(ROOT)), "type": "images_missing_alt", "count": parser.images_without_alt})
    for raw in parser.links:
        target = local_target(page, raw)
        if target is None:
            continue
        checked_links += 1
        if isinstance(target, tuple):
            warnings.append({"file": str(page.relative_to(ROOT)), "type": "path_outside_site", "detail": raw})
            continue
        if not target.exists():
            issues.append({"file": str(page.relative_to(ROOT)), "type": "broken_internal_link_or_asset", "detail": raw})
            continue
        fragment = unquote(urlparse(raw).fragment)
        if fragment:
            if target == page:
                target_ids = set(parser.ids)
            else:
                target_parser = AuditParser()
                try:
                    target_parser.feed(target.read_text(encoding="utf-8", errors="replace"))
                    target_ids = set(target_parser.ids)
                except OSError:
                    target_ids = set()
            if fragment not in target_ids:
                issues.append({
                    "file": str(page.relative_to(ROOT)),
                    "type": "broken_internal_fragment",
                    "detail": raw,
                    "target_file": str(target.relative_to(ROOT))
                })

# Check standalone JavaScript files and inline scripts with Node.js syntax validation.
js_files = sorted(p for p in ROOT.rglob("*.js") if not any(x in IGNORE for x in p.parts))
js_checked = 0
for js_file in js_files:
    js_checked += 1
    check = subprocess.run(["node", "--check", str(js_file)], capture_output=True, text=True)
    if check.returncode:
        issues.append({
            "file": str(js_file.relative_to(ROOT)),
            "type": "javascript_syntax_error",
            "detail": (check.stderr or check.stdout).strip()[:2000]
        })

for page in HTML_FILES:
    try:
        parser = AuditParser()
        parser.feed(page.read_text(encoding="utf-8", errors="replace"))
    except OSError:
        continue
    for index, script_text in enumerate(parser.inline_scripts, start=1):
        if not script_text.strip():
            continue
        js_checked += 1
        with tempfile.NamedTemporaryFile(mode="w", suffix=".js", encoding="utf-8") as temp:
            temp.write(script_text)
            temp.flush()
            check = subprocess.run(["node", "--check", temp.name], capture_output=True, text=True)
        if check.returncode:
            issues.append({
                "file": str(page.relative_to(ROOT)),
                "type": "inline_javascript_syntax_error",
                "script_index": index,
                "detail": (check.stderr or check.stdout).strip()[:2000]
            })

# Enforce the English-only public interface and ensure language switching stays disabled.
translation_audit = {
    "html_pages_scanned": len(HTML_FILES),
    "pages_without_english_lang": [],
    "pages_with_tamil_script": [],
    "language_selector_detected": False,
    "automatic_translation_disabled": False,
    "country_based_language_switching_disabled": False,
}
for page in HTML_FILES:
    content = page.read_text(encoding="utf-8", errors="replace")
    if not re.search(r'<html\\b[^>]*\\blang=["\\']en["\\']', content, re.I):
        translation_audit["pages_without_english_lang"].append(str(page.relative_to(ROOT)))
    if re.search(r"[\\u0B80-\\u0BFF]", content):
        translation_audit["pages_with_tamil_script"].append(str(page.relative_to(ROOT)))

translator_source = (ROOT / "assets" / "auto-translate.js").read_text(encoding="utf-8")
global_source = (ROOT / "assets" / "global-experience.js").read_text(encoding="utf-8")
translation_audit["language_selector_detected"] = any(
    token in global_source for token in ("tc-language-select", "languageSelect", "LANG_STORAGE")
)
translation_audit["automatic_translation_disabled"] = (
    "English-only" in translator_source
    and "MutationObserver" not in translator_source
)
translation_audit["country_based_language_switching_disabled"] = (
    "navigator.language" not in global_source
    and "primary:" not in global_source
    and "langs:[" not in global_source
)
translation_audit["status"] = "healthy" if (
    not translation_audit["pages_without_english_lang"]
    and not translation_audit["pages_with_tamil_script"]
    and not translation_audit["language_selector_detected"]
    and translation_audit["automatic_translation_disabled"]
    and translation_audit["country_based_language_switching_disabled"]
) else "needs_attention"
translation_audit["note"] = (
    "Checks public HTML language declarations, Tamil-script content, language selectors, "
    "automatic translation and country-based language switching. User-generated content "
    "and runtime text returned by external services are outside this static audit."
)

result = {
    "checked_at_utc": datetime.now(timezone.utc).isoformat(),
    "html_pages_checked": len(HTML_FILES),
    "internal_links_and_assets_checked": checked_links,
    "javascript_blocks_checked": js_checked,
    "errors": len(issues),
    "warnings": len(warnings),
    "status": "needs_attention" if issues else ("warnings" if warnings else "healthy"),
    "errors_detail": issues[:500],
    "warnings_detail": warnings[:500],
    "translation_audit": translation_audit,
    "scope_note": "Read-only structural and JavaScript syntax check. It does not prove browser runtime behavior, authenticated Supabase flows, live external government sites, email delivery, payment, or complete real-user journeys.",
}
REPORT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({k: result[k] for k in ("status", "html_pages_checked", "internal_links_and_assets_checked", "errors", "warnings")}))
if issues:
    raise SystemExit(1)
