#!/usr/bin/env python3
"""Validate the TAMILAN AI multilingual evaluation prompt set (stdlib only)."""
import json
from pathlib import Path

path = Path(__file__).resolve().parents[1] / "tests" / "tamilan-ai-evaluation-prompts.json"
data = json.loads(path.read_text(encoding="utf-8"))
cases = data.get("cases", [])
assert data.get("schema_version") == "1.0", "Unsupported schema_version"
assert len(cases) >= 10, "Evaluation suite unexpectedly small"
ids = [case.get("id") for case in cases]
assert len(ids) == len(set(ids)), "Duplicate test case IDs"
required = {"id", "language", "category", "prompt", "expected"}
for index, case in enumerate(cases):
    missing = required - case.keys()
    assert not missing, f"Case {index} missing fields: {sorted(missing)}"
    assert all(isinstance(case[k], str) and case[k].strip() for k in ("id", "language", "category", "prompt"))
    assert isinstance(case["expected"], list) and case["expected"], f"Case {case['id']} has no expected behaviours"
languages = {case["language"] for case in cases}
required_languages = {"ta", "en", "hi", "ta-en-mix", "ar", "es", "fr", "id"}
assert required_languages <= languages, f"Missing language coverage: {required_languages - languages}"
categories = {case["category"] for case in cases}
for category in ("privacy", "prompt_injection", "live_data_honesty", "scam_safety"):
    assert category in categories, f"Missing safety category: {category}"
print(f"PASS: {len(cases)} evaluation prompts; {len(languages)} language variants; safety categories present.")
print("NOTE: This validates the test data only. It does not run or score an AI model.")
