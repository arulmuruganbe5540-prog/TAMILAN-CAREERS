#!/usr/bin/env python3
"""Discover *possible new* official recruitment portals linked by already trusted sources.

This never trusts a new domain automatically. It writes a separate source-candidate
queue for verification before any domain can enter the active source registry.
Python standard library only.
"""
import hashlib
import html
import json
import re
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urljoin, urlparse, urldefrag
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "data" / "government-official-sources.json"
OUTPUT = ROOT / "government-source-discovery-candidates.json"
TIMEOUT = 10
MAX_BYTES = 1_200_000
MAX_WORKERS = 5
OFFICIAL_SUFFIXES = (".gov.in", ".nic.in", ".gov", ".mil.in")
RECRUITMENT = re.compile(
    r"recruit|vacanc|career|job|employment|notification|advertisement|"
    r"application|apply|selection|exam|commission|board|department|"
    r"police|teacher|university|railway|staff", re.I
)
GENERIC = re.compile(r"^(home|about|contact|privacy|terms|facebook|twitter|youtube|instagram|login|sign in)$", re.I)

class AnchorParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []
        self.current = None
    def handle_starttag(self, tag, attrs):
        if tag.lower() == "a":
            self.current = {"href": dict(attrs).get("href", ""), "text": ""}
    def handle_data(self, data):
        if self.current is not None:
            self.current["text"] += " " + data
    def handle_endtag(self, tag):
        if tag.lower() == "a" and self.current is not None:
            self.links.append(self.current)
            self.current = None

def load(path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return default

def host(url):
    try:
        return (urlparse(url).hostname or "").lower().rstrip(".")
    except ValueError:
        return ""

def trusted_domain_hint(hostname):
    return any(hostname == suffix.lstrip(".") or hostname.endswith(suffix) for suffix in OFFICIAL_SUFFIXES)

def fetch(source):
    req = Request(source["url"], headers={"User-Agent": "TAMILAN-CAREERS-SourceDiscovery/1.0"})
    with urlopen(req, timeout=TIMEOUT) as response:
        raw = response.read(MAX_BYTES)
        final_url = response.geturl()
        charset = response.headers.get_content_charset() or "utf-8"
    parser = AnchorParser()
    parser.feed(raw.decode(charset, errors="replace"))
    found = []
    parent_host = host(source["url"])
    for link in parser.links:
        href = html.unescape((link.get("href") or "").strip())
        title = re.sub(r"\s+", " ", html.unescape(link.get("text", ""))).strip()
        if not href or href.startswith(("#", "javascript:", "mailto:", "tel:")):
            continue
        try:
            target = urldefrag(urljoin(final_url, href))[0]
            parsed = urlparse(target)
        except ValueError:
            continue
        target_host = host(target)
        if parsed.scheme != "https" or not target_host or target_host == parent_host:
            continue
        # Only create suggestions for official-looking domains, never arbitrary outbound links.
        if not trusted_domain_hint(target_host):
            continue
        if GENERIC.fullmatch(title) and not RECRUITMENT.search(target):
            continue
        if not RECRUITMENT.search(title + " " + target):
            continue
        found.append({
            "candidate_url": target,
            "candidate_domain": target_host,
            "link_title": title[:200],
            "discovered_via_source_id": source["id"],
            "discovered_via_authority": source["name"],
            "evidence_page": final_url,
        })
    return found

config = load(CONFIG, {"sources": []})
known = {host(x.get("url", "")) for x in config.get("sources", [])}
old_doc = load(OUTPUT, {"items": []})
old = {x.get("id"): x for x in old_doc.get("items", []) if x.get("id")}
candidates = {}
errors = []
sources = config.get("sources", [])

def scan(source):
    try:
        return source, fetch(source), None
    except (HTTPError, URLError, TimeoutError, OSError, ValueError) as exc:
        return source, [], str(exc)[:220]

with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
    futures = [pool.submit(scan, s) for s in sources]
    for future in as_completed(futures):
        source, links, error = future.result()
        if error:
            errors.append({"source_id": source["id"], "error": error})
            continue
        for item in links:
            if item["candidate_domain"] in known:
                continue
            key = item["candidate_domain"] + "|" + item["candidate_url"]
            item_id = hashlib.sha256(key.encode()).hexdigest()[:20]
            previous = old.get(item_id, {})
            item.update({
                "id": item_id,
                "status": previous.get("status", "needs_official_source_verification"),
                "first_discovered_utc": previous.get("first_discovered_utc", datetime.now(timezone.utc).isoformat()),
                "last_seen_utc": datetime.now(timezone.utc).isoformat(),
                "verification": previous.get("verification", {
                    "government_entity_confirmed": False,
                    "official_parent_directory_link_confirmed": False,
                    "domain_ownership_confirmed": False,
                    "recruitment_function_confirmed": False,
                }),
                "warning": "Suggestion only. A .gov.in/.nic.in suffix or an inbound link is not sufficient proof. Verify the authority and domain before adding it to the trusted source registry.",
            })
            candidates[item_id] = item\n            new_seen += 1

# Retain prior decisions and review history, including candidates not seen in this scan.
for item_id, item in old.items():
    candidates.setdefault(item_id, item)

items = sorted(candidates.values(), key=lambda x: (x.get("status") != "needs_official_source_verification", x.get("candidate_domain", "")))
OUTPUT.write_text(json.dumps({
    "schema_version": 1,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "trusted_sources_scanned": len(sources),
    "new_source_candidates_seen_this_run": new_seen,
    "total_source_candidates": len(items),
    "policy": "No candidate is added to the trusted source registry automatically. Admin verification is required.",
    "items": items,
    "scan_errors": errors,
}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"Source discovery complete: {len(sources)} trusted sources scanned; {len(items)} suggestions retained; {len(errors)} scan errors.")
