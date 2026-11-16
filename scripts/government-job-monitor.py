#!/usr/bin/env python3
"""Scan registered official recruitment websites and build an admin-only review queue.

This is a discovery tool, not an AI fact checker and never publishes vacancies.
Every candidate requires an administrator to open the official notice and verify it.
"""
import hashlib, html, json, re, time
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urljoin, urlparse, urldefrag
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "data" / "government-official-sources.json"
QUEUE = ROOT / "government-job-review-queue.json"
REPORT = ROOT / "government-job-monitor-report.json"
KEYWORDS = re.compile(r"recruit|vacanc|advertisement|notification|career|apply|application|"
                      r"result|merit list|answer key|admit card|hall ticket|exam date|"
                      r"selection list|provisional list|shortlist|appointment", re.I)
CATEGORY = [
    ("admit_card", re.compile(r"admit.?card|hall.?ticket|call.?letter|e.?call.?letter", re.I)),
    ("result", re.compile(r"result|merit.?list|selection.?list|short.?list", re.I)),
    ("answer_key", re.compile(r"answer.?key|final.?key", re.I)),
    ("exam_update", re.compile(r"exam.?date|exam.?schedule|city.?intimation|timetable", re.I)),
    ("recruitment", re.compile(r"recruit|vacanc|advertisement|notification|apply|application", re.I)),
]
MAX_BYTES = 2_000_000
TIMEOUT = 20
SLEEP_SECONDS = 0.45

class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.items, self.current = [], None
    def handle_starttag(self, tag, attrs):
        if tag.lower() == "a":
            self.current = {"href": dict(attrs).get("href", ""), "text": ""}
    def handle_data(self, data):
        if self.current is not None:
            self.current["text"] += " " + data
    def handle_endtag(self, tag):
        if tag.lower() == "a" and self.current is not None:
            self.items.append(self.current)
            self.current = None

def host_allowed(candidate_url, source_url):
    a, b = urlparse(candidate_url), urlparse(source_url)
    if a.scheme != "https" or not a.hostname or not b.hostname:
        return False
    ah, bh = a.hostname.lower(), b.hostname.lower()
    return ah == bh or ah.endswith("." + bh)

def classify(text):
    for label, pattern in CATEGORY:
        if pattern.search(text):
            return label
    return "review"

def fetch_source(source):
    req = Request(source["url"], headers={"User-Agent":"TAMILAN-CAREERS-OfficialRecruitmentMonitor/1.0 (+official-source monitoring)"})
    with urlopen(req, timeout=TIMEOUT) as response:
        raw = response.read(MAX_BYTES)
        status, final_url = response.status, response.geturl()
        charset = response.headers.get_content_charset() or "utf-8"
    if not host_allowed(final_url, source["url"]):
        raise ValueError("Redirected outside the registered official host")
    parser = Links()
    parser.feed(raw.decode(charset, errors="replace"))
    plain = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", raw.decode(charset, errors="replace")))
    digest = hashlib.sha256(plain.encode("utf-8")).hexdigest()
    candidates = []
    seen = set()
    for item in parser.items:
        title = re.sub(r"\s+", " ", html.unescape(item["text"])).strip()
        href = html.unescape(item["href"]).strip()
        if not href or href.startswith(("#", "javascript:", "mailto:", "tel:")):
            continue
        absolute = urldefrag(urljoin(final_url, href))[0]
        combined = title + " " + absolute
        if not KEYWORDS.search(combined) or not host_allowed(absolute, source["url"]):
            continue
        if absolute in seen:
            continue
        seen.add(absolute)
        candidates.append({
            "id": hashlib.sha256((source["id"] + "|" + absolute).encode()).hexdigest()[:20],
            "source_id": source["id"], "authority": source["name"],
            "state": source.get("state", "All India"),
            "scope": source["scope"], "title": title[:220] or "Official page link — title needs review",
            "official_url": absolute, "category_hint": classify(combined),
            "discovered_at_utc": datetime.now(timezone.utc).isoformat(),
            "status": "pending_admin_verification",
            "verification": {
                "official_domain_checked": True,
                "notice_pdf_opened": False,
                "dates_verified": False,
                "vacancy_count_verified": False,
                "eligibility_verified": False,
                "application_link_verified": False,
                "duplicate_checked": False
            },
            "publish_allowed": False,
            "warning": "Discovery candidate only. Do not publish until the official notice and all material details are manually verified."
        })
    return {"source_id":source["id"], "authority":source["name"], "url":source["url"],
            "http_status":status, "final_url":final_url, "content_sha256":digest,
            "links_found":len(candidates)}, candidates

def load_json(path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return default

config = load_json(CONFIG, {"sources":[]})
previous_queue = load_json(QUEUE, {"items":[]})
previous_by_id = {x.get("id"):x for x in previous_queue.get("items",[]) if x.get("id")}
all_candidates, source_results, errors = {}, [], []
for source in config.get("sources", []):
    try:
        result, found = fetch_source(source)
        source_results.append(result)
        for item in found:
            # Preserve an administrator's existing status/checklist when the same link is rediscovered.
            old = previous_by_id.get(item["id"])
            if old:
                item.update(old)
                item["last_seen_utc"] = datetime.now(timezone.utc).isoformat()
            all_candidates[item["id"]] = item
        print(source["id"] + ": HTTP " + str(result["http_status"]) + ", candidates=" + str(len(found)))
    except (HTTPError, URLError, TimeoutError, OSError, ValueError) as exc:
        errors.append({"source_id":source["id"], "url":source["url"], "error":str(exc)[:250]})
        print(source["id"] + ": ERROR " + str(exc)[:160])
    time.sleep(SLEEP_SECONDS)

# Keep previously queued items so that admin review history is not silently discarded.
for item_id, old in previous_by_id.items():
    all_candidates.setdefault(item_id, old)

items = sorted(all_candidates.values(), key=lambda x:(x.get("status") != "pending_admin_verification", x.get("discovered_at_utc","")), reverse=False)
queue = {
    "schema_version":1,
    "generated_at_utc":datetime.now(timezone.utc).isoformat(),
    "policy":"No item is public or approved automatically. Admin must verify the official notice and explicitly approve publication.",
    "total_candidates":len(items),
    "pending_review":sum(1 for x in items if x.get("status")=="pending_admin_verification"),
    "items":items
}
report = {
    "monitor_version":1, "checked_at_utc":datetime.now(timezone.utc).isoformat(),
    "check_interval_hours":config.get("check_interval_hours",6),
    "registered_sources":len(config.get("sources",[])),
    "successful_sources":len(source_results), "failed_sources":errors,
    "candidate_links_discovered_this_run":sum(x["links_found"] for x in source_results),
    "pending_admin_review":queue["pending_review"],
    "note":"Official-source link discovery only. It does not validate vacancy facts, does not use AI to certify truth, and never publishes."
}
QUEUE.write_text(json.dumps(queue,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
REPORT.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print("Finished: " + str(len(source_results)) + "/" + str(len(config.get("sources",[]))) +
      " sources reachable; " + str(queue["pending_review"]) + " candidates await admin review.")
