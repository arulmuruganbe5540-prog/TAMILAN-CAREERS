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

# Audit exact-match coverage of the curated UI translation dictionaries.
# This is a source-text estimate; it cannot certify dynamic API content or complete sentences.
class TranslationParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.texts = []
        self.attributes = []
        self.ignored = []
        self.script_sources = []
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag in ("script", "style", "noscript", "code", "pre", "textarea"):
            self.ignored.append(tag)
        if tag == "script" and attrs.get("src"):
            self.script_sources.append(attrs["src"])
        for key in ("placeholder", "aria-label", "title", "alt", "value"):
            value = attrs.get(key)
            if value:
                self.attributes.append(value.strip())
    def handle_endtag(self, tag):
        if tag in self.ignored:
            for index in range(len(self.ignored) - 1, -1, -1):
                if self.ignored[index] == tag:
                    del self.ignored[index]
                    break
    def handle_data(self, data):
        if not self.ignored and data.strip():
            self.texts.append(data.strip())

translation_source = (ROOT / "assets" / "auto-translate.js").read_text(encoding="utf-8")
decoder = json.JSONDecoder()
translation_rows = []
base_marker = "var rows="
base_start = translation_source.index(base_marker) + len(base_marker)
base_rows, _ = decoder.raw_decode(translation_source[base_start:].lstrip())
translation_rows.extend(base_rows)
push_marker = "rows.push.apply(rows,"
push_pos = 0
while True:
    push_pos = translation_source.find(push_marker, push_pos)
    if push_pos < 0:
        break
    array_start = push_pos + len(push_marker)
    extra_rows, consumed = decoder.raw_decode(translation_source[array_start:].lstrip())
    translation_rows.extend(extra_rows)
    push_pos = array_start + consumed

translation_maps = {
    "en": {row[0] for row in translation_rows if len(row) > 0 and row[0]},
    "ta": {row[0] for row in translation_rows if len(row) > 1 and row[0] and row[1]},
    "hi": {row[0] for row in translation_rows if len(row) > 2 and row[0] and row[2]},
    "ml": {row[0] for row in translation_rows if len(row) > 3 and row[0] and row[3]},
}
extra_marker = "var extraLanguageRows="
extra_start = translation_source.index(extra_marker) + len(extra_marker)
extra_end = translation_source.index("};\nif(cols", extra_start) + 1
extra_source = translation_source[extra_start:extra_end]
extra_source = re.sub(r"(^|\n)([a-z]{2}):", r'\1"\2":', extra_source)
extra_source = re.sub(r",\s*}", "}", extra_source)
extra_maps = json.loads(extra_source)
for language, pairs in extra_maps.items():
    translation_maps[language] = {pair[0] for pair in pairs if len(pair) > 1 and pair[0] and pair[1]}

translation_page_results = []
all_candidates = set()
for page in HTML_FILES:
    parser = TranslationParser()
    try:
        parser.feed(page.read_text(encoding="utf-8", errors="replace"))
    except OSError:
        continue
    candidates = {
        re.sub(r"\s+", " ", value).strip()
        for value in parser.texts + parser.attributes
        if 2 <= len(value.strip()) <= 160
        and re.search(r"[A-Za-z]", value)
        and not re.fullmatch(r"[\d\s.,:;|/()[\]{}\-+%#@!]+", value.strip())
        and not value.strip().startswith(("http://", "https://", "www."))
    }
    all_candidates.update(candidates)
    english_only = sorted(value for value in candidates if value not in translation_maps["en"])
    script_ready = any("site-protection.js" in src or "global-experience.js" in src for src in parser.script_sources)
    translation_page_results.append({
        "file": str(page.relative_to(ROOT)),
        "candidate_strings": len(candidates),
        "dictionary_matched": len(candidates) - len(english_only),
        "missing_dictionary_entries": len(english_only),
        "locale_loader_present": script_ready,
        "examples_missing": english_only[:12],
    })

translation_coverage = {}
for language, keys in translation_maps.items():
    matched = sum(1 for value in all_candidates if value in keys)
    translation_coverage[language] = {
        "mapped_strings": matched,
        "total_candidate_strings": len(all_candidates),
        "exact_match_percent": round(matched * 100 / len(all_candidates), 1) if all_candidates else 100.0,
    }
translation_audit = {
    "html_pages_scanned": len(translation_page_results),
    "unique_static_candidate_strings": len(all_candidates),
    "pages_missing_locale_loader": [
        item["file"] for item in translation_page_results if not item["locale_loader_present"]
    ],
    "coverage_by_language": translation_coverage,
    "lowest_coverage_pages": sorted(
        translation_page_results,
        key=lambda item: item["dictionary_matched"] / max(1, item["candidate_strings"])
    )[:15],
    "note": "Exact dictionary-key coverage estimate for static HTML text and selected attributes only. It excludes dynamic JavaScript/API content and does not certify translation quality.",
}

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
