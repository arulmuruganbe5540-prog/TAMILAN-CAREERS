#!/usr/bin/env python3
"""Lightweight daily monitor for official State PSC recruitment pages.

This only detects source-page changes. It does NOT extract or certify vacancies.
Every detected change must be reviewed against the official notification PDF.
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
from urllib.parse import urljoin, urlparse
from urllib.request import HTTPRedirectHandler, Request, build_opener
from urllib.robotparser import RobotFileParser

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / "state-job-monitor-report.json"
SOURCES = [
    ("Andhra Pradesh", "https://psc.ap.gov.in/"),
    ("Arunachal Pradesh", "https://www.appsc.gov.in/"),
    ("Assam", "https://apsc.nic.in/"),
    ("Bihar", "https://bpsc.bihar.gov.in/"),
    ("Chhattisgarh", "https://psc.cg.gov.in/"),
    ("Goa", "https://gpsc.goa.gov.in/"),
    ("Gujarat", "https://gpsc.gujarat.gov.in/"),
    ("Haryana", "https://hpsc.gov.in/"),
    ("Himachal Pradesh", "https://hppsc.hp.gov.in/"),
    ("Jharkhand", "https://www.jpsc.gov.in/"),
    ("Karnataka", "https://kpsc.kar.nic.in/"),
    ("Kerala", "https://www.keralapsc.gov.in/"),
    ("Madhya Pradesh", "https://mppsc.mp.gov.in/"),
    ("Maharashtra", "https://mpsc.gov.in/home"),
    ("Manipur", "https://mpscmanipur.gov.in/"),
    ("Meghalaya", "https://mpsc.meghalaya.gov.in/"),
    ("Mizoram", "https://mpsc.mizoram.gov.in/"),
    ("Nagaland", "https://npsc.nagaland.gov.in/"),
    ("Odisha", "https://www.opsc.gov.in/"),
    ("Punjab", "https://www.ppsc.gov.in/"),
    ("Rajasthan", "https://rpsc.rajasthan.gov.in/"),
    ("Sikkim", "https://spsc.sikkim.gov.in/"),
    ("Tamil Nadu", "https://www.tnpsc.gov.in/"),
    ("Telangana", "https://www.tgpsc.gov.in/"),
    ("Tripura", "https://tpsc.tripura.gov.in/"),
    ("Uttar Pradesh", "https://uppsc.up.nic.in/CandidatePages/Notifications.aspx"),
    ("Uttarakhand", "https://psc.uk.gov.in/"),
    ("West Bengal", "https://psc.wb.gov.in/"),
]
TIMEOUT = 12
MAX_WORKERS = 4

class TextExtractor(HTMLParser):
    def __init__(self):
        super().__init__()
        self.parts = []
        self.skip = 0
    def handle_starttag(self, tag, attrs):
        if tag in ("script", "style", "noscript", "svg"):
            self.skip += 1
    def handle_endtag(self, tag):
        if tag in ("script", "style", "noscript", "svg") and self.skip:
            self.skip -= 1
    def handle_data(self, data):
        if not self.skip:
            value = re.sub(r"\s+", " ", html.unescape(data)).strip()
            if value:
                self.parts.append(value)

def host_allowed(candidate_url, source_url):
    a, b = urlparse(candidate_url), urlparse(source_url)
    if a.scheme != "https" or not a.hostname or not b.hostname:
        return False
    ah, bh = a.hostname.lower(), b.hostname.lower()
    return ah == bh or ah.endswith("." + bh)

class SameHostRedirectHandler(HTTPRedirectHandler):
    def __init__(self, source_url):
        super().__init__()
        self.source_url = source_url
        self.redirect_count = 0

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        self.redirect_count += 1
        if self.redirect_count > 5:
            raise ValueError("Too many redirects")
        if not host_allowed(newurl, self.source_url):
            raise ValueError("Redirect outside registered HTTPS domain")
        return super().redirect_request(req, fp, code, msg, headers, newurl)

def robots_allowed(source_url, user_agent):
    robots_url = urljoin(source_url, "/robots.txt")
    opener = build_opener(SameHostRedirectHandler(source_url))
    req = Request(robots_url, headers={"User-Agent": user_agent})
    try:
        with opener.open(req, timeout=TIMEOUT) as response:
            raw = response.read(256_000)
        parser = RobotFileParser()
        parser.set_url(robots_url)
        parser.parse(raw.decode("utf-8", errors="replace").splitlines())
        return parser.can_fetch(user_agent, source_url)
    except HTTPError as exc:
        return exc.code in (404, 410)
    except (URLError, TimeoutError, OSError, ValueError):
        return False

def fetch(state, url, previous):
    result = {"state": state, "url": url, "checked_at": datetime.now(timezone.utc).isoformat()}
    user_agent = "TAMILAN-CAREERS-StatePSC-Monitor/1.0"
    try:
        if not host_allowed(url, url):
            raise ValueError("Only HTTPS sources are allowed")
        if not robots_allowed(url, user_agent):
            raise ValueError("robots.txt disallows this page or could not be checked safely")
        req = Request(url, headers={"User-Agent": user_agent})
        opener = build_opener(SameHostRedirectHandler(url))
        with opener.open(req, timeout=22) as response:
            content_type = response.headers.get_content_type().lower()
            if content_type not in ("text/html", "application/xhtml+xml"):
                raise ValueError("Source did not return an HTML content type")
            raw = response.read(1_500_000)
            status = response.status
            final_url = response.geturl()
            charset = response.headers.get_content_charset() or "utf-8"
        if not host_allowed(final_url, url):
            raise ValueError("Redirected outside registered HTTPS domain")
        if final_url != url and not robots_allowed(final_url, user_agent):
            raise ValueError("robots.txt disallows the redirected page or could not be checked safely")
        parser = TextExtractor()
        parser.feed(raw.decode(charset, errors="replace"))
        text = re.sub(r"\s+", " ", " ".join(parser.parts)).strip()
        digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
        old = previous.get(state, {})
        result.update({
            "http_status": status,
            "final_url": final_url,
            "content_sha256": digest,
            "changed_since_previous_check": bool(old.get("content_sha256") and old.get("content_sha256") != digest),
            "review_required": True,
        })
    except (HTTPError, URLError, TimeoutError, OSError, ValueError) as exc:
        result.update({"http_status": None, "error": str(exc)[:300], "changed_since_previous_check": False, "review_required": True})
    return result

old = {}
if REPORT.exists():
    try:
        previous_report = json.loads(REPORT.read_text(encoding="utf-8"))
        old = {item["state"]: item for item in previous_report.get("sources", [])}
    except Exception:
        old = {}

results = []
with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
    futures = [pool.submit(fetch, state, url, old) for state, url in SOURCES]
    for future in as_completed(futures):
        item = future.result()
        results.append(item)
        print(f'{item["state"]}: HTTP {item.get("http_status")} changed={item.get("changed_since_previous_check", False)}')
order = {state: index for index, (state, _) in enumerate(SOURCES)}
results.sort(key=lambda item: order.get(item["state"], len(order)))

changed = [x["state"] for x in results if x.get("changed_since_previous_check")]
errors = [x["state"] for x in results if x.get("http_status") is None or (x.get("http_status") and x["http_status"] >= 400)]
summary = {
    "monitor_version": 2,
    "last_updated_utc": datetime.now(timezone.utc).isoformat(),
    "purpose": "Official PSC page change detection only; not a verified vacancy feed.",
    "states_monitored": len(results),
    "changed_pages": changed,
    "unreachable_pages": errors,
    "manual_review_required": True,
    "sources": results,
}
new_content = json.dumps(summary, ensure_ascii=False, indent=2) + "\n"
old_content = REPORT.read_text(encoding="utf-8") if REPORT.exists() else ""
if new_content != old_content:
    REPORT.write_text(new_content, encoding="utf-8")
print(f"Checked {len(results)} state PSC sources; {len(changed)} changed; {len(errors)} unreachable.")
