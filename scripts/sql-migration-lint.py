#!/usr/bin/env python3
"""Basic SQL migration guard for PostgreSQL delimiters, index clauses and SECURITY DEFINER search paths."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SQL_FILES = sorted(ROOT.rglob("*.sql"))
TAG = re.compile(r"\$(?:[A-Za-z_][A-Za-z0-9_]*)?\$")
INVALID_SINGLE_DOLLAR = re.compile(r"^\s*as\s+\$(?!\$)\s*$", re.MULTILINE)

errors = []
for path in SQL_FILES:
    content = path.read_text(encoding="utf-8", errors="replace")
    relative = path.relative_to(ROOT)
    if INVALID_SINGLE_DOLLAR.search(content):
        errors.append(f"{relative}: invalid single-dollar PL/pgSQL delimiter; use $$ or a named dollar tag")

    for match in re.finditer(r"\bcreate\s+(?:unique\s+)?index\b(.*?);", content, re.IGNORECASE | re.DOTALL):
        if not re.search(r"\bon\s+(?:public\.)?[a-z_][a-z0-9_]*", match.group(1), re.IGNORECASE):
            errors.append(f"{relative}: CREATE INDEX statement is missing a valid ON table clause")

    counts = {}
    for match in TAG.finditer(content):
        counts[match.group(0)] = counts.get(match.group(0), 0) + 1
    for tag, count in sorted(counts.items()):
        if count % 2:
            errors.append(f"{relative}: unpaired {tag} delimiter ({count} occurrences)")

    lines = content.splitlines()
    for index, line in enumerate(lines):
        if re.search(r"\bsecurity\s+definer\b", line, re.IGNORECASE):
            context = "\n".join(lines[index:index + 10])
            if not re.search(r"set\s+search_path\s*=\s*''", context, re.IGNORECASE):
                errors.append(f"{relative}:{index + 1}: SECURITY DEFINER function must set search_path = ''")

if errors:
    print("SQL migration lint failed:")
    for error in errors:
        print(f" - {error}")
    sys.exit(1)

print(f"SQL migration lint passed: {len(SQL_FILES)} files checked.")
