#!/usr/bin/env python3
"""Static regression checks for the disabled TAMILAN AI public-job retrieval contract."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
FUNCTION = ROOT / 'supabase/functions/tamilan-ai-job-context/index.ts'
CONFIG = ROOT / 'supabase/config.toml'
errors = []

if not FUNCTION.is_file():
    errors.append('Missing TAMILAN AI job-context Edge Function source')
else:
    source = FUNCTION.read_text(encoding='utf-8')
    required = {
        'default-off feature flag': 'Deno.env.get("TAMILAN_AI_RETRIEVAL_ENABLED") !== "true"',
        'JWT bearer requirement': 'authorization?.startsWith("Bearer ")',
        'anon/publishable key only': 'SUPABASE_ANON_KEY',
        'published-only query': '.eq("status", "published")',
        'bounded result count': '.limit(MAX_RESULTS)',
        'source identifier': 'source_id: id',
        'citation URL': 'citation_url: sourceUrl',
        'untrusted job content marker': 'content_is_untrusted: true',
        'no-private candidate data claim': 'private_candidate_data_used: false',
        'no-vacancy fabrication guard': 'Do not invent vacancies, counts, salaries or employers.',
    }
    for label, token in required.items():
        if token not in source:
            errors.append(f'Function missing {label}')
    for forbidden in ('SUPABASE_SERVICE_ROLE_KEY', 'TAMILAN_AI_MODEL_TOKEN', 'TAMILAN_AI_MODEL_URL', 'fetch(row.', '.from("job_sources")'):
        if forbidden.lower() in source.lower():
            errors.append(f'Forbidden privileged/model/source-registry access: {forbidden}')
    if 'MAX_RESULTS = 5' not in source:
        errors.append('Result cap must remain five or fewer')
    if 'MAX_DESCRIPTION_LENGTH = 6000' not in source:
        errors.append('Description context cap must remain bounded')

if not CONFIG.is_file():
    errors.append('Missing Supabase config.toml')
else:
    config = CONFIG.read_text(encoding='utf-8')
    section = re.search(r'(?ms)^\[functions\.tamilan-ai-job-context\]\s*\n([^\[]*)', config)
    if not section or not re.search(r'(?m)^verify_jwt\s*=\s*true\s*$', section.group(1)):
        errors.append('Edge Function must retain verify_jwt = true')

if errors:
    for error in errors:
        print(f'FAIL: {error}')
    raise SystemExit(1)

print('PASS: TAMILAN AI retrieval remains JWT-protected, feature-flagged OFF, read-only, RLS-respecting and source-grounded.')
print('NOTE: static checks only; this does not prove deployed runtime security or replace authenticated integration tests.')
