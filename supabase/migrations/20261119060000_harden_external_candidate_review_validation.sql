-- Reject null decisions and non-object checklist payloads on external candidate review.
create or replace function public.tc_review_external_job_candidate(
  p_candidate_id uuid,
  p_decision text,
  p_reason text default '',
  p_verification jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_row public.external_job_candidates%rowtype;
  v_verification jsonb;
  v_user uuid := (select auth.uid());
begin
  if v_user is null or not coalesce(private.is_super_admin(), false) then
    raise exception 'Super Admin permission required';
  end if;
  if p_decision is null or p_decision not in ('verified','rejected') then
    raise exception 'Only verify or reject decisions are allowed';
  end if;
  if p_verification is not null and jsonb_typeof(p_verification) <> 'object' then
    raise exception 'Verification checklist must be a JSON object';
  end if;
  select * into v_row from public.external_job_candidates where id=p_candidate_id for update;
  if not found then raise exception 'External job candidate not found'; end if;
  if v_row.status <> 'pending' then raise exception 'Only pending candidates can be reviewed'; end if;
  if p_decision='rejected' then
    if length(btrim(coalesce(p_reason,''))) < 10 then
      raise exception 'Please provide a rejection reason (at least 10 characters)';
    end if;
    update public.external_job_candidates set status='rejected',
      rejection_reason=left(btrim(p_reason),1000),reviewed_at=now(),
      reviewed_by=v_user,updated_at=now() where id=p_candidate_id;
  else
    v_verification := coalesce(v_row.verification,'{}'::jsonb) || coalesce(p_verification,'{}'::jsonb);
    if not (
      coalesce((v_verification->>'source_domain_matched')::boolean,false)
      and coalesce((v_verification->>'original_notice_opened')::boolean,false)
      and coalesce((v_verification->>'dates_verified')::boolean,false)
      and coalesce((v_verification->>'eligibility_verified')::boolean,false)
      and coalesce((v_verification->>'application_link_verified')::boolean,false)
      and coalesce((v_verification->>'duplicate_checked')::boolean,false)
    ) then
      raise exception 'Complete all six verification checks before marking this candidate verified';
    end if;
    update public.external_job_candidates set status='verified',
      verification=v_verification,rejection_reason=null,reviewed_at=now(),
      reviewed_by=v_user,updated_at=now() where id=p_candidate_id;
  end if;
  return jsonb_build_object('success',true,'candidate_id',p_candidate_id,'status',p_decision);
end;
$function$;
revoke all on function public.tc_review_external_job_candidate(uuid,text,text,jsonb) from public;
revoke all on function public.tc_review_external_job_candidate(uuid,text,text,jsonb) from anon;
grant execute on function public.tc_review_external_job_candidate(uuid,text,text,jsonb) to authenticated;
