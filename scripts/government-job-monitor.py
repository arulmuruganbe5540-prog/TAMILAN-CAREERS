#!/usr/bin/env python3
"""Scan registered official recruitment websites and build an admin-only review queue.

This is a discovery tool, not an AI fact checker and never publishes vacancies.
Every candidate requires an administrator to open the official notice and verify it.
"""
import hashlib, html, json, re, time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urljoin, urlparse, urldefrag
from urllib.request import HTTPRedirectHandler, Request, build_opener
from urllib.robotparser import RobotFileParser

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "data" / "government-official-sources.json"
QUEUE = ROOT / "government-job-review-queue.json"
REPORT = ROOT / "government-job-monitor-report.json"
# Match recruitment-specific notice language, not generic navigation such as Apply/Login.
KEYWORDS = re.compile(r"recruitment|vacanc|advertisement|notification|career.?notice|"
                      r"result|merit.?list|answer.?key|admit.?card|hall.?ticket|exam.?date|"
                      r"selection.?list|provisional.?list|short.?list|appointment.?order|"
                      r"application.?form|online.?application", re.I)
# Drop generic navigation labels even when their destination URL contains a keyword.
GENERIC_TITLE = re.compile(r"^(home|more|more \.{2,}|view all|read more|click here|here|results?|notifications?|recruitment|careers?|apply|login|menu|latest news|what.s new|download|know more)$", re.I)
CATEGORY = [
    ("admit_card", re.compile(r"admit.?card|hall.?ticket|call.?letter|e.?call.?letter", re.I)),
    ("result", re.compile(r"result|merit.?list|selection.?list|short.?list", re.I)),
    ("answer_key", re.compile(r"answer.?key|final.?key", re.I)),
    ("exam_update", re.compile(r"exam.?date|exam.?schedule|city.?intimation|timetable", re.I)),
    ("recruitment", re.compile(r"recruit|vacanc|advertisement|notification|apply|application", re.I)),
]
MAX_BYTES = 2_000_000
TIMEOUT = 20
MAX_WORKERS = 4
SLEEP_SECONDS = 0.35

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
    req = Request(robots_url, headers={"User-Agent": user_agent})
    opener = build_opener(SameHostRedirectHandler(source_url))
    try:
        with opener.open(req, timeout=TIMEOUT) as response:
            raw = response.read(256_000)
        parser = RobotFileParser()
        parser.set_url(robots_url)
        parser.parse(raw.decode("utf-8", errors="replace").splitlines())
        return parser.can_fetch(user_agent, source_url)
    except HTTPError as exc:
        if exc.code in (404, 410):
            return True
        return False
    except (URLError, TimeoutError, OSError, ValueError):
        return False

def fetch_source(source):
    user_agent = "TAMILAN-CAREERS-OfficialRecruitmentMonitor/1.0 (+official-source monitoring)"
    if not robots_allowed(source["url"], user_agent):
        raise ValueError("robots.txt disallows this page or could not be checked safely")
    req = Request(source["url"], headers={"User-Agent":user_agent})
    opener = build_opener(SameHostRedirectHandler(source["url"]))
    with opener.open(req, timeout=TIMEOUT) as response:
        content_type = response.headers.get_content_type().lower()
        if content_type not in ("text/html", "application/xhtml+xml"):
            raise ValueError("Source did not return an HTML content type")
        raw = response.read(MAX_BYTES)
        status, final_url = response.status, response.geturl()
        charset = response.headers.get_content_charset() or "utf-8"
    if not host_allowed(final_url, source["url"]):
        raise ValueError("Redirected outside the registered HTTPS domain")
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
        if len(title) < 5 or GENERIC_TITLE.fullmatch(title) or not KEYWORDS.search(combined):
            continue
        if not host_allowed(absolute, source["url"]):
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

def scan_one(source):
    time.sleep(SLEEP_SECONDS)
    try:
        result, found = fetch_source(source)
        return source, result, found, None
    except (HTTPError, URLError, TimeoutError, OSError, ValueError) as exc:
        return source, None, [], str(exc)[:250]

# A small worker pool prevents slow official sites from being scanned serially.
with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
    futures = [pool.submit(scan_one, source) for source in config.get("sources", [])]
    for future in as_completed(futures):
        source, result, found, error = future.result()
        if error:
            errors.append({"source_id":source["id"], "url":source["url"], "error":error})
            print(source["id"] + ": ERROR " + error[:160])
            continue
        source_results.append(result)
        for item in found:
            old = previous_by_id.get(item["id"])
            if old:
                item.update(old)
                item["last_seen_utc"] = datetime.now(timezone.utc).isoformat()
            all_candidates[item["id"]] = item
        print(source["id"] + ": HTTP " + str(result["http_status"]) + ", candidates=" + str(len(found)))

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
    "monitor_version":2, "checked_at_utc":datetime.now(timezone.utc).isoformat(),
    "check_interval_hours":config.get("check_interval_hours",6),
    "registered_sources":len(config.get("sources",[])),
    "successful_sources":len(source_results), "failed_sources":errors,
    "candidate_links_discovered_this_run":sum(x["links_found"] for x in source_results),
    "pending_admin_review":queue["pending_review"],
    "note":"Official-source link discovery only. It does not validate vacancy facts, does not use AI to certify truth, and never publishes.",
    "scan_workers":MAX_WORKERS, "request_timeout_seconds":TIMEOUT
}
QUEUE.write_text(json.dumps(queue,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
REPORT.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print("Finished: " + str(len(source_results)) + "/" + str(len(config.get("sources",[]))) +
      " sources reachable; " + str(queue["pending_review"]) + " candidates await admin review.")
