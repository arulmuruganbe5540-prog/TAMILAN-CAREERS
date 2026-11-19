#!/usr/bin/env python3
"""Static regression checks for the disabled TAMILAN AI public-job retrieval contract."""
from pathlib import Path
import re
ROOT = Path(__file__).resolve().parents[1]
FUNCTION = ROOT / 'supabase/functions/tamilan-ai-job-context/index.ts'
LOGIC = ROOT / 'supabase/functions/tamilan-ai-job-context/logic.ts'
HANDLER = ROOT / 'supabase/functions/tamilan-ai-job-context/handler.ts'
CONFIG = ROOT / 'supabase/config.toml'
MIGRATION = ROOT / 'supabase/migrations/20261119065045_tamilan_ai_job_context_rate_limit.sql'
errors = []
if not FUNCTION.is_file() or not LOGIC.is_file() or not HANDLER.is_file():
    errors.append('Missing TAMILAN AI retrieval function or pure logic module')
else:
    source = FUNCTION.read_text(encoding='utf-8')
    logic = LOGIC.read_text(encoding='utf-8')
    combined = source + "\n" + logic
    required = {
        'default-off feature flag': 'env("TAMILAN_AI_RETRIEVAL_ENABLED") !== "true"',
        'JWT bearer requirement': 'authorization?.startsWith("Bearer ")',
        'anon key only': 'SUPABASE_ANON_KEY',
        'published-only query': '.eq("status", "published")',
        'bounded result count': '.limit(MAX_RESULTS)',
        'request body size cap': 'rawBody.length > 2048',
        'source identifier': 'source_id: id',
        'citation URL': 'citation_url: sourceUrl',
        'untrusted job marker': 'content_is_untrusted: true',
        'durable quota RPC': 'rpc("tamilan_ai_consume_job_context_quota")',
        'centralized request parser': 'parseRetrievalInput(body)',
        '429 response': 'RATE_LIMITED',
        'Retry-After header': 'headers.set("Retry-After", String(retryAfter))',
        'fail-closed quota failure': 'RATE_LIMIT_CHECK_FAILED',
        'safe whitespace normalization': 'replace(/\\s+/g, " ")',
    }
    for label, token in required.items():
        if token not in combined:
            errors.append('Function/logic missing ' + label)
    for forbidden in ('SUPABASE_SERVICE_ROLE_KEY', 'TAMILAN_AI_MODEL_TOKEN', 'TAMILAN_AI_MODEL_URL', 'fetch(row.', '.from("job_sources")'):
        if forbidden.lower() in combined.lower():
            errors.append('Forbidden privileged/model/source access: ' + forbidden)
    if 'application_url' in combined:
        errors.append('Application URLs must not be citations')
    if 'MAX_RESULTS = 5' not in logic or 'MAX_DESCRIPTION_LENGTH = 6000' not in logic:
        errors.append('Retrieval bounds changed unexpectedly')
if not MIGRATION.is_file():
    errors.append('Missing durable AI rate-limit migration source')
else:
    sql = MIGRATION.read_text(encoding='utf-8').lower()
    checks = {
        'private quota table': 'private.tamilan_ai_job_context_rate_limits',
        'private quota RLS enabled': 'enable row level security',
        'private quota direct grants revoked': 'revoke all on table private.tamilan_ai_job_context_rate_limits from public, anon, authenticated',
        'registered-user check': 'u.is_anonymous',
        'atomic per-user upsert': 'on conflict (user_id) do update',
        'empty search_path': "set search_path = ''",
        'anonymous execute denied': 'from public, anon',
        'authenticated-only private helper': 'grant execute on function private.tamilan_ai_consume_job_context_quota() to authenticated',
        'public invoker wrapper': 'security invoker',
        'private definer helper': 'security definer',
        'private helper implementation': 'create or replace function private.tamilan_ai_consume_job_context_quota()',
        'public API wrapper': 'create or replace function public.tamilan_ai_consume_job_context_quota()',
        'authenticated-only RPC': 'to authenticated',
        'minute quota': 'v_minute_limit constant smallint := 10',
        'daily quota': 'v_day_limit constant smallint := 100',
    }
    for label, token in checks.items():
        if token not in sql:
            errors.append('Rate-limit migration missing ' + label)
    public_fn = re.search(r'create\s+or\s+replace\s+function\s+public\.tamilan_ai_consume_job_context_quota\s*\(\s*\)([\s\S]*?)\$function\$', sql, re.I)
    private_fn = re.search(r'create\s+or\s+replace\s+function\s+private\.tamilan_ai_consume_job_context_quota\s*\(\s*\)([\s\S]*?)\$function\$', sql, re.I)
    if not public_fn or not re.search(r'\bsecurity\s+invoker\b', public_fn.group(1), re.I) or re.search(r'\bsecurity\s+definer\b', public_fn.group(1), re.I):
        errors.append('Public Data API wrapper must be SECURITY INVOKER, never DEFINER')
    if not private_fn or not re.search(r'\bsecurity\s+definer\b', private_fn.group(1), re.I) or not re.search(r"set\s+search_path\s*=\s*''", private_fn.group(1), re.I):
        errors.append('Private quota helper must be SECURITY DEFINER with empty search_path')
    if re.search(r'grant\s+.*on\s+table\s+private\.tamilan_ai_job_context_rate_limits', sql, re.I):
        errors.append('Private quota table must not be granted directly')

    # Keep the quota scoped to the authenticated, registered caller and UTC buckets.
    ownership_checks = {
        'caller identity from auth.uid()': r'v_user\s+uuid\s*:=\s*\(select\s+auth\.uid\(\)\)',
        'user row bound to caller ID': r'where\s+u\.id\s*=\s*v_user',
        'anonymous account rejected': r'coalesce\(v_is_anonymous,\s*true\)',
        'minute bucket fixed to UTC epoch': r'extract\(epoch\s+from\s+v_now\)\s*/\s*60',
        'daily bucket fixed to UTC epoch': r'extract\(epoch\s+from\s+v_now\)\s*/\s*86400',
        'minute counter saturates at limit plus one': r'v_minute_limit\s*\+\s*1',
        'daily counter saturates at limit plus one': r'v_day_limit\s*\+\s*1',
        'quota decision checks both limits': r'v_minute_count\s*<=\s*v_minute_limit\s+and\s+v_day_count\s*<=\s*v_day_limit',
    }
    for label, pattern in ownership_checks.items():
        if not re.search(pattern, sql, re.I):
            errors.append('Rate-limit migration missing ' + label)
    if re.search(r'create\s+policy[\s\S]*?on\s+private\.tamilan_ai_job_context_rate_limits', sql, re.I):
        errors.append('Private quota table must not expose direct RLS policies')
    if not re.search(r'revoke\s+all\s+on\s+function\s+public\.tamilan_ai_consume_job_context_quota\(\)\s+from\s+public,\s*anon', sql, re.I):
        errors.append('Public quota RPC must deny PUBLIC and anon execution')
    if not re.search(r'revoke\s+all\s+on\s+function\s+private\.tamilan_ai_consume_job_context_quota\(\)\s+from\s+public,\s*anon', sql, re.I):
        errors.append('Private quota helper must deny PUBLIC and anon execution')
if not CONFIG.is_file():
    errors.append('Missing Supabase config.toml')
else:
    config = CONFIG.read_text(encoding='utf-8')
    section = re.search(r'(?ms)^\[functions\.tamilan-ai-job-context\]\s*\n([^\[]*)', config)
    if not section or not re.search(r'(?m)^verify_jwt\s*=\s*true\s*$', section.group(1)):
        errors.append('Edge Function must retain verify_jwt = true')
if errors:
    for error in errors:
        print('FAIL: ' + error)
    raise SystemExit(1)
print('PASS: TAMILAN AI retrieval is JWT-protected, default-OFF, RLS-respecting, source-grounded and guarded by durable per-user quotas.')
print('NOTE: static checks and Deno unit tests do not replace authenticated live integration tests.')
