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
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / "state-job-monitor-report.json"
SOURCES = [
    ("Andhra Pradesh", "https://psc.ap.gov.in/"),
    ("Arunachal Pradesh", "http://www.appsc.gov.in/"),
    ("Assam", "http://apsc.nic.in/"),
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
KEYWORDS = re.compile(r"recruit|advertis|notification|vacanc|application|apply online|"
                      r"last date|employment|selection|direct recruitment|career", re.I)

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

def fetch(state, url, previous):
    result = {"state": state, "url": url, "checked_at": datetime.now(timezone.utc).isoformat()}
    try:
        req = Request(url, headers={"User-Agent": "TAMILAN-CAREERS-StatePSC-Monitor/1.0 (daily official link check)"})
        with urlopen(req, timeout=22) as response:
            raw = response.read(1_500_000)
            status = response.status
            final_url = response.geturl()
            charset = response.headers.get_content_charset() or "utf-8"
        parser = TextExtractor()
        parser.feed(raw.decode(charset, errors="replace"))
        text = re.sub(r"\s+", " ", " ".join(parser.parts)).strip()
        digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
        snippets = []
        for sentence in re.split(r"(?<=[.!?])\s+|\\s{2,}", text):
            sentence = sentence.strip()
            if sentence and KEYWORDS.search(sentence):
                snippets.append(sentence[:260])
            if len(snippets) >= 12:
                break
        old = previous.get(state, {})
        result.update({
            "http_status": status,
            "final_url": final_url,
            "content_sha256": digest,
            "changed_since_previous_check": bool(old.get("content_sha256") and old.get("content_sha256") != digest),
            "recruitment_keyword_snippets": snippets,
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
for state, url in SOURCES:
    item = fetch(state, url, old)
    results.append(item)
    print(f'{state}: HTTP {item.get("http_status")} changed={item.get("changed_since_previous_check", False)}')
    time.sleep(0.6)

changed = [x["state"] for x in results if x.get("changed_since_previous_check")]
errors = [x["state"] for x in results if x.get("http_status") is None or (x.get("http_status") and x["http_status"] >= 400)]
summary = {
    "monitor_version": 1,
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
