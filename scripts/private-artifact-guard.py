#!/usr/bin/env python3
"""Prevent private government candidate queues from being committed to the public repository."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
FORBIDDEN = {
    "government-job-review-queue.json",
    "government-source-discovery-candidates.json",
}

tracked_result = subprocess.run(
    ["git", "ls-files"], cwd=ROOT, check=True, capture_output=True, text=True
)
tracked = [line.strip() for line in tracked_result.stdout.splitlines() if line.strip()]
exposed = [path for path in tracked if Path(path).name in FORBIDDEN]

errors = []
if exposed:
    errors.append("Private government candidate files are tracked: " + ", ".join(exposed))

ignore_path = ROOT / ".gitignore"
ignore_text = ignore_path.read_text(encoding="utf-8") if ignore_path.exists() else ""
for filename in sorted(FORBIDDEN):
    if filename not in ignore_text:
        errors.append(f".gitignore must exclude {filename}")

workflow_path = ROOT / ".github" / "workflows" / "government-job-monitor.yml"
workflow = workflow_path.read_text(encoding="utf-8")
if "git add government-job-monitor-report.json" not in workflow:
    errors.append("Government monitor must commit the aggregate report explicitly")
if any(f"git add {filename}" in workflow for filename in FORBIDDEN):
    errors.append("Government monitor must never stage private candidate queues")

if errors:
    print("Private artifact guard failed:")
    for error in errors:
        print(" - " + error)
    sys.exit(1)

print("Private artifact guard passed: candidate queues are ignored and not tracked.")
