-- MANGAIYARKARASI Control Foundation
-- Safe additive migration. Apply ONLY to an isolated Supabase development branch first.
-- Never run this file against production without Owner approval and a verified backup.

create table if not exists public.mangai_owner_config (
  singleton boolean primary key default true check (singleton),
  owner_user_id uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
declare
  v_owner_ids uuid[];
begin
  select array_agg(user_id order by created_at)
    into v_owner_ids
  from public.user_roles
  where role = 'super_admin';

  if coalesce(array_length(v_owner_ids, 1), 0) <> 1 then
    raise exception 'Mangaiyarkarasi setup requires exactly one existing Super Admin. Found %.',
      coalesce(array_length(v_owner_ids, 1), 0);
  end if;

  insert into public.mangai_owner_config(singleton, owner_user_id)
  values (true, v_owner_ids[1])
  on conflict (singleton) do nothing;
end $$;

create table if not exists public.mangai_control_modules (
  module_key text primary key,
  display_name text not null,
  category text not null,
  description text not null default '',
  enabled boolean not null default true,
  execution_mode text not null default 'assisted'
    check (execution_mode in ('manual', 'assisted', 'automatic_safe')),
  permission_tier text not null default 'read_only'
    check (permission_tier in ('read_only', 'reversible', 'owner_approval', 'blocked')),
  approval_required boolean not null default true,
  health_state text not null default 'not_configured'
    check (health_state in ('healthy', 'warning', 'critical', 'not_configured', 'unknown')),
  config jsonb not null default '{}'::jsonb,
  last_check_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.mangai_automation_runs (
  id uuid primary key default gen_random_uuid(),
  module_key text not null references public.mangai_control_modules(module_key),
  run_type text not null,
  status text not null default 'queued'
    check (status in ('queued', 'running', 'succeeded', 'failed', 'cancelled', 'needs_owner')),
  actor_type text not null default 'system'
    check (actor_type in ('owner', 'system', 'automation')),
  actor_id uuid,
  request_id text,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  summary jsonb not null default '{}'::jsonb,
  error_code text,
  error_message text,
  created_at timestamptz not null default now(),
  unique (module_key, request_id)
);

create table if not exists public.mangai_change_proposals (
  id uuid primary key default gen_random_uuid(),
  module_key text references public.mangai_control_modules(module_key),
  title text not null,
  description text not null default '',
  risk_level text not null default 'medium'
    check (risk_level in ('low', 'medium', 'high', 'critical')),
  status text not null default 'proposed'
    check (status in ('proposed', 'allowed_for_testing', 'testing', 'ready_to_deploy', 'owner_approved', 'deployed', 'rejected', 'kept_existing', 'rolled_back')),
  change_payload jsonb not null default '{}'::jsonb,
  test_plan jsonb not null default '[]'::jsonb,
  rollback_plan jsonb not null default '{}'::jsonb,
  expected_impact text not null default '',
  estimated_cost text,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deployed_at timestamptz,
  deployment_ref text
);

create table if not exists public.mangai_owner_approvals (
  id uuid primary key default gen_random_uuid(),
  proposal_id uuid not null references public.mangai_change_proposals(id),
  decision text not null check (decision in ('allow_testing', 'approve_production', 'reject', 'keep_existing')),
  owner_user_id uuid not null,
  rationale text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.mangai_monitoring_checks (
  id uuid primary key default gen_random_uuid(),
  module_key text references public.mangai_control_modules(module_key),
  check_type text not null,
  target text not null,
  status text not null check (status in ('ok', 'warning', 'critical', 'failed', 'skipped')),
  latency_ms integer check (latency_ms is null or latency_ms >= 0),
  http_status integer,
  details jsonb not null default '{}'::jsonb,
  checked_at timestamptz not null default now()
);

create table if not exists public.mangai_control_alerts (
  id uuid primary key default gen_random_uuid(),
  module_key text references public.mangai_control_modules(module_key),
  severity text not null check (severity in ('info', 'warning', 'critical')),
  title text not null,
  message text not null,
  status text not null default 'open' check (status in ('open', 'acknowledged', 'resolved')),
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  acknowledged_at timestamptz,
  resolved_at timestamptz
);

create table if not exists public.mangai_search_console_metrics (
  id uuid primary key default gen_random_uuid(),
  data_date date not null,
  query text not null default '',
  page text not null default '',
  country text not null default '',
  device text not null default '',
  clicks bigint not null default 0 check (clicks >= 0),
  impressions bigint not null default 0 check (impressions >= 0),
  ctr numeric(8,6) not null default 0 check (ctr >= 0 and ctr <= 1),
  average_position numeric(10,3),
  property_uri text not null,
  imported_at timestamptz not null default now(),
  source_payload jsonb not null default '{}'::jsonb,
  unique (data_date, query, page, country, device, property_uri)
);

create table if not exists public.mangai_audit_events (
  id bigint generated always as identity primary key,
  actor_type text not null check (actor_type in ('owner', 'system', 'automation', 'integration')),
  actor_id uuid,
  event_type text not null,
  module_key text,
  target_type text,
  target_id text,
  request_id text,
  outcome text not null default 'recorded' check (outcome in ('recorded', 'succeeded', 'failed', 'denied')),
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.mangai_reject_audit_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'Mangaiyarkarasi audit events are append-only';
end;
$$;

drop trigger if exists mangai_audit_events_no_mutation on public.mangai_audit_events;
create trigger mangai_audit_events_no_mutation
before update or delete on public.mangai_audit_events
for each row execute function public.mangai_reject_audit_mutation();

revoke all on function public.mangai_reject_audit_mutation() from public, anon, authenticated;

create index if not exists mangai_runs_module_created_idx
  on public.mangai_automation_runs(module_key, created_at desc);
create index if not exists mangai_runs_status_created_idx
  on public.mangai_automation_runs(status, created_at desc);
create index if not exists mangai_proposals_status_created_idx
  on public.mangai_change_proposals(status, created_at desc);
create index if not exists mangai_approvals_proposal_created_idx
  on public.mangai_owner_approvals(proposal_id, created_at desc);
create index if not exists mangai_checks_target_checked_idx
  on public.mangai_monitoring_checks(target, checked_at desc);
create index if not exists mangai_alerts_status_created_idx
  on public.mangai_control_alerts(status, severity, created_at desc);
create index if not exists mangai_gsc_date_query_idx
  on public.mangai_search_console_metrics(data_date desc, query);
create index if not exists mangai_audit_created_idx
  on public.mangai_audit_events(created_at desc);
create index if not exists mangai_audit_module_created_idx
  on public.mangai_audit_events(module_key, created_at desc);

insert into public.mangai_control_modules
  (module_key, display_name, category, description, execution_mode, permission_tier, approval_required)
values
  ('command_centre', 'Voice and Text Command Centre', 'orchestration', 'Tamil voice input, text fallback and bounded command routing.', 'assisted', 'owner_approval', true),
  ('government_jobs', 'Government Job Intelligence', 'jobs', 'Official-source discovery, verification and duplicate review.', 'automatic_safe', 'reversible', true),
  ('private_jobs', 'Indian Private Job Intelligence', 'jobs', 'Separate private job source and employer verification pipeline.', 'automatic_safe', 'reversible', true),
  ('international_jobs', 'International Job Intelligence', 'jobs', 'Separate international job discovery and verification pipeline.', 'automatic_safe', 'reversible', true),
  ('search_intelligence', 'Google Search Intelligence and Auto SEO', 'seo', 'Search Console ingestion, relevant keyword scoring and SEO proposals.', 'assisted', 'owner_approval', true),
  ('website_monitoring', '24/7 Website Monitoring', 'operations', 'Uptime, page, form, database and function health checks.', 'automatic_safe', 'reversible', false),
  ('visitor_analytics', 'Visitor Intelligence', 'analytics', 'Privacy-respecting aggregate traffic and search reports.', 'automatic_safe', 'read_only', false),
  ('evolution_audit', '20-Day Evolution Audit', 'governance', 'Periodic security, SEO, performance and feature review.', 'assisted', 'owner_approval', true),
  ('release_management', 'Testing and Deployment Controller', 'delivery', 'Staging, regression tests, owner approval and rollback.', 'assisted', 'owner_approval', true),
  ('security_governance', 'Security and Access Governance', 'security', 'Least privilege, MFA, RLS review and immutable policy boundaries.', 'manual', 'blocked', true),
  ('backup_recovery', 'Backup and Disaster Recovery', 'resilience', 'Backup inventory, restore drills and recovery playbooks.', 'assisted', 'owner_approval', true),
  ('performance_cost', 'Performance and Cost Controller', 'operations', 'Performance, provider usage and budget threshold monitoring.', 'automatic_safe', 'read_only', false)
on conflict (module_key) do nothing;


-- Atomically record a proposal decision, owner approval and audit event.
-- Callable only by the trusted Edge Function service role after JWT verification.
create or replace function public.mangai_record_proposal_decision(
  p_proposal_id uuid,
  p_decision text,
  p_owner_user_id uuid,
  p_rationale text default '',
  p_request_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
  v_new_status text;
  v_risk text;
begin
  if p_decision is null or p_decision not in ('allow_testing', 'reject', 'keep_existing') then
    raise exception 'Decision is not allowed';
  end if;

  if not exists (
    select 1 from public.mangai_owner_config
    where singleton = true and owner_user_id = p_owner_user_id
  ) or not exists (
    select 1 from public.user_roles
    where user_id = p_owner_user_id and role = 'super_admin'
  ) then
    raise exception 'Master Owner permission required';
  end if;

  v_new_status := case p_decision
    when 'allow_testing' then 'allowed_for_testing'
    when 'reject' then 'rejected'
    when 'keep_existing' then 'kept_existing'
  end;

  update public.mangai_change_proposals
     set status = v_new_status, updated_at = now()
   where id = p_proposal_id and status = 'proposed'
   returning risk_level into v_risk;

  if not found then
    raise exception 'Proposal not found or already decided';
  end if;

  insert into public.mangai_owner_approvals
    (proposal_id, decision, owner_user_id, rationale)
  values
    (p_proposal_id, p_decision, p_owner_user_id, left(coalesce(p_rationale, ''), 2000));

  insert into public.mangai_audit_events
    (actor_type, actor_id, event_type, target_type, target_id, request_id, outcome, details)
  values
    ('owner', p_owner_user_id, 'proposal_' || p_decision, 'proposal',
     p_proposal_id::text, p_request_id, 'succeeded',
     jsonb_build_object('previous_status', 'proposed', 'new_status', v_new_status, 'risk_level', v_risk));

  return jsonb_build_object('id', p_proposal_id, 'status', v_new_status);
end;
$$;

revoke all on function public.mangai_record_proposal_decision(uuid, text, uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.mangai_record_proposal_decision(uuid, text, uuid, text, text)
  to service_role;

-- These control records are private to trusted server-side code.
-- No anon/authenticated API access; Edge Functions use server-side service credentials only.
alter table public.mangai_owner_config enable row level security;
alter table public.mangai_control_modules enable row level security;
alter table public.mangai_automation_runs enable row level security;
alter table public.mangai_change_proposals enable row level security;
alter table public.mangai_owner_approvals enable row level security;
alter table public.mangai_monitoring_checks enable row level security;
alter table public.mangai_control_alerts enable row level security;
alter table public.mangai_search_console_metrics enable row level security;
alter table public.mangai_audit_events enable row level security;

revoke all on public.mangai_owner_config from anon, authenticated;
revoke all on public.mangai_control_modules from anon, authenticated;
revoke all on public.mangai_automation_runs from anon, authenticated;
revoke all on public.mangai_change_proposals from anon, authenticated;
revoke all on public.mangai_owner_approvals from anon, authenticated;
revoke all on public.mangai_monitoring_checks from anon, authenticated;
revoke all on public.mangai_control_alerts from anon, authenticated;
revoke all on public.mangai_search_console_metrics from anon, authenticated;
revoke all on public.mangai_audit_events from anon, authenticated;

grant select on public.mangai_owner_config to service_role;
grant all on public.mangai_control_modules to service_role;
grant all on public.mangai_automation_runs to service_role;
grant all on public.mangai_change_proposals to service_role;
grant all on public.mangai_owner_approvals to service_role;
grant all on public.mangai_monitoring_checks to service_role;
grant all on public.mangai_control_alerts to service_role;
grant all on public.mangai_search_console_metrics to service_role;
grant select, insert on public.mangai_audit_events to service_role;
grant usage, select on sequence public.mangai_audit_events_id_seq to service_role;

comment on table public.mangai_owner_config is 'Single Master Owner binding for Mangaiyarkarasi; accessible only to trusted server-side service code.';
comment on table public.mangai_control_modules is 'Central registry for existing and future website modules and their permission tiers.';
comment on table public.mangai_automation_runs is 'Execution history for all bounded automation runs.';
comment on table public.mangai_change_proposals is 'Versioned change proposals; testing permission is not production deployment approval.';
comment on table public.mangai_owner_approvals is 'Owner decisions for testing, production release, rejection or retaining existing state.';
comment on table public.mangai_monitoring_checks is 'Evidence-backed health-check history.';
comment on table public.mangai_control_alerts is 'Operational alert queue.';
comment on table public.mangai_search_console_metrics is 'Imported Google Search Console query/page metrics; not fabricated search-volume estimates.';
comment on table public.mangai_audit_events is 'Append-only audit stream for Owner, automation and integrations.';


-- Atomically pause or resume a module and append its audit event.
create or replace function public.mangai_set_module_enabled(
  p_module_key text, p_enabled boolean, p_owner_user_id uuid, p_request_id text default null
)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare v_enabled boolean;
begin
  if p_module_key is null or p_module_key !~ '^[a-z0-9_]{2,60}$' or p_enabled is null then raise exception 'Invalid module control request'; end if;
  if p_module_key = 'security_governance' then raise exception 'Security governance cannot be paused or resumed by automation'; end if;
  if not exists (select 1 from public.mangai_owner_config where singleton = true and owner_user_id = p_owner_user_id)
     or not exists (select 1 from public.user_roles where user_id = p_owner_user_id and role = 'super_admin') then raise exception 'Master Owner permission required'; end if;
  update public.mangai_control_modules set enabled = p_enabled, updated_at = now()
   where module_key = p_module_key returning enabled into v_enabled;
  if not found then raise exception 'Module not found'; end if;
  insert into public.mangai_audit_events(actor_type, actor_id, event_type, module_key, target_type, target_id, request_id, outcome, details)
  values ('owner', p_owner_user_id, case when p_enabled then 'resume_module' else 'pause_module' end,
    p_module_key, 'module', p_module_key, p_request_id, 'succeeded', jsonb_build_object('enabled', v_enabled));
  return jsonb_build_object('module_key', p_module_key, 'enabled', v_enabled);
end;
$$;
revoke all on function public.mangai_set_module_enabled(text, boolean, uuid, text) from public, anon, authenticated;
grant execute on function public.mangai_set_module_enabled(text, boolean, uuid, text) to service_role;

-- Atomically create a proposal and its audit event.
create or replace function public.mangai_create_change_proposal(
  p_module_key text, p_title text, p_description text, p_risk_level text,
  p_change_payload jsonb, p_test_plan jsonb, p_rollback_plan jsonb,
  p_expected_impact text, p_owner_user_id uuid, p_request_id text default null
)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare v_proposal public.mangai_change_proposals%rowtype;
begin
  if p_title is null or length(btrim(p_title)) < 4 or length(p_title) > 180 then raise exception 'Proposal title must be 4–180 characters'; end if;
  if p_risk_level is null or p_risk_level not in ('low', 'medium', 'high', 'critical') then raise exception 'Invalid proposal risk level'; end if;
  if p_module_key is not null and not exists (select 1 from public.mangai_control_modules where module_key = p_module_key) then raise exception 'Unknown module key'; end if;
  if not exists (select 1 from public.mangai_owner_config where singleton = true and owner_user_id = p_owner_user_id)
     or not exists (select 1 from public.user_roles where user_id = p_owner_user_id and role = 'super_admin') then raise exception 'Master Owner permission required'; end if;
  insert into public.mangai_change_proposals(module_key, title, description, risk_level, status, change_payload, test_plan, rollback_plan, expected_impact, created_by)
  values (p_module_key, btrim(p_title), left(coalesce(p_description, ''), 5000), p_risk_level, 'proposed',
    coalesce(p_change_payload, '{}'::jsonb),
    case when jsonb_typeof(p_test_plan) = 'array' then p_test_plan else '[]'::jsonb end,
    coalesce(p_rollback_plan, '{}'::jsonb), left(coalesce(p_expected_impact, ''), 2000), p_owner_user_id)
  returning * into v_proposal;
  insert into public.mangai_audit_events(actor_type, actor_id, event_type, target_type, target_id, request_id, outcome, details)
  values ('owner', p_owner_user_id, 'proposal_created', 'proposal', v_proposal.id::text, p_request_id, 'succeeded',
    jsonb_build_object('title', v_proposal.title, 'risk_level', v_proposal.risk_level, 'module_key', v_proposal.module_key));
  return jsonb_build_object('id', v_proposal.id, 'title', v_proposal.title, 'status', v_proposal.status, 'risk_level', v_proposal.risk_level);
end;
$$;
revoke all on function public.mangai_create_change_proposal(text, text, text, text, jsonb, jsonb, jsonb, text, uuid, text) from public, anon, authenticated;
grant execute on function public.mangai_create_change_proposal(text, text, text, text, jsonb, jsonb, jsonb, text, uuid, text) to service_role;
