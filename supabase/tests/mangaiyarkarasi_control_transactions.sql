-- Transactional RPC integration checks for the Mangaiyarkarasi foundation.
-- Run after the foundation migration and smoke assertions in an isolated PostgreSQL database.

\set ON_ERROR_STOP on

SELECT owner_user_id AS owner_id
FROM public.mangai_owner_config
WHERE singleton = true
\gset

-- Exercise the restricted service_role execution path.
SET ROLE service_role;
SELECT public.mangai_set_module_enabled(
  'website_monitoring', false, :'owner_id'::uuid, 'ci-module-baseline'
);
SELECT public.mangai_create_change_proposal(
  NULL,
  'CI transactional rollback proposal',
  'Temporary test proposal',
  'low',
  '{}'::jsonb,
  '[]'::jsonb,
  '{}'::jsonb,
  'No production impact',
  :'owner_id'::uuid,
  'ci-proposal-create'
) ->> 'id' AS proposal_id
\gset
RESET ROLE;

SELECT set_config('mangai.ci_proposal_id', :'proposal_id', false);

-- Inject an audit failure. Each RPC must roll back its business write.
CREATE OR REPLACE FUNCTION public.ci_fail_mangai_audit_insert()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF current_setting('mangai.ci_fail_audit', true) = 'on' THEN
    RAISE EXCEPTION 'CI_INJECTED_AUDIT_FAILURE';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER ci_fail_mangai_audit_insert
BEFORE INSERT ON public.mangai_audit_events
FOR EACH ROW EXECUTE FUNCTION public.ci_fail_mangai_audit_insert();

DO $$
DECLARE
  v_owner_id uuid;
  v_proposal_id uuid;
  v_enabled boolean;
  v_before_count integer;
  v_after_count integer;
  v_status text;
  v_approval_count integer;
  v_audit_count integer;
BEGIN
  SELECT owner_user_id INTO v_owner_id
  FROM public.mangai_owner_config
  WHERE singleton = true;

  v_proposal_id := current_setting('mangai.ci_proposal_id')::uuid;
  PERFORM set_config('mangai.ci_fail_audit', 'on', true);

  BEGIN
    PERFORM public.mangai_set_module_enabled(
      'website_monitoring', true, v_owner_id, 'ci-fail-module'
    );
    RAISE EXCEPTION 'CI_EXPECTED_MODULE_ROLLBACK';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'CI_EXPECTED_MODULE_ROLLBACK' THEN
      RAISE;
    END IF;
  END;

  SELECT enabled INTO v_enabled
  FROM public.mangai_control_modules
  WHERE module_key = 'website_monitoring';
  IF v_enabled IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'Module state changed despite injected audit failure';
  END IF;

  SELECT count(*) INTO v_before_count
  FROM public.mangai_change_proposals;

  BEGIN
    PERFORM public.mangai_create_change_proposal(
      NULL, 'CI audit rollback proposal', '', 'low',
      '{}'::jsonb, '[]'::jsonb, '{}'::jsonb, '',
      v_owner_id, 'ci-fail-create'
    );
    RAISE EXCEPTION 'CI_EXPECTED_CREATE_ROLLBACK';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'CI_EXPECTED_CREATE_ROLLBACK' THEN
      RAISE;
    END IF;
  END;

  SELECT count(*) INTO v_after_count
  FROM public.mangai_change_proposals;
  IF v_after_count <> v_before_count THEN
    RAISE EXCEPTION 'Proposal row persisted despite injected audit failure';
  END IF;

  BEGIN
    PERFORM public.mangai_record_proposal_decision(
      v_proposal_id, 'allow_testing', v_owner_id,
      'CI rollback test', 'ci-fail-decision'
    );
    RAISE EXCEPTION 'CI_EXPECTED_DECISION_ROLLBACK';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'CI_EXPECTED_DECISION_ROLLBACK' THEN
      RAISE;
    END IF;
  END;

  SELECT status INTO v_status
  FROM public.mangai_change_proposals
  WHERE id = v_proposal_id;
  IF v_status IS DISTINCT FROM 'proposed' THEN
    RAISE EXCEPTION 'Proposal decision persisted despite injected audit failure';
  END IF;

  SELECT count(*) INTO v_approval_count
  FROM public.mangai_owner_approvals
  WHERE proposal_id = v_proposal_id;
  IF v_approval_count <> 0 THEN
    RAISE EXCEPTION 'Owner approval persisted despite injected audit failure';
  END IF;

  SELECT count(*) INTO v_audit_count
  FROM public.mangai_audit_events
  WHERE request_id IN ('ci-fail-module', 'ci-fail-create', 'ci-fail-decision');
  IF v_audit_count <> 0 THEN
    RAISE EXCEPTION 'Audit rows persisted despite injected audit failure';
  END IF;
END;
$$;

DROP TRIGGER ci_fail_mangai_audit_insert ON public.mangai_audit_events;
DROP FUNCTION public.ci_fail_mangai_audit_insert();

-- Confirm the same proposal decision succeeds when audit writes are healthy.
SET ROLE service_role;
SELECT public.mangai_record_proposal_decision(
  :'proposal_id'::uuid,
  'allow_testing',
  :'owner_id'::uuid,
  'CI successful decision',
  'ci-decision-success'
);
RESET ROLE;

DO $$
DECLARE
  v_proposal_id uuid := current_setting('mangai.ci_proposal_id')::uuid;
  v_status text;
  v_approval_count integer;
BEGIN
  SELECT status INTO v_status
  FROM public.mangai_change_proposals
  WHERE id = v_proposal_id;
  SELECT count(*) INTO v_approval_count
  FROM public.mangai_owner_approvals
  WHERE proposal_id = v_proposal_id;
  IF v_status <> 'allowed_for_testing' OR v_approval_count <> 1 THEN
    RAISE EXCEPTION 'Successful proposal decision did not commit all related records';
  END IF;
END;
$$;

SELECT 'transactional RPC checks passed' AS result;
