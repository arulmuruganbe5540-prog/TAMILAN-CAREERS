-- TAMILAN CAREERS: Candidate self-withdrawal for a job application
-- Run once in the Supabase SQL Editor after reviewing the live schema.

create or replace function public.tc_candidate_withdraw_application(
  p_application_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_updated_id uuid;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Login required';
  end if;

  update public.job_applications
     set status = 'withdrawn',
         updated_at = now()
   where id = p_application_id
     and candidate_id = v_user_id
     and status in ('applied', 'under_review', 'shortlisted')
  returning id into v_updated_id;

  if v_updated_id is null then
    raise exception 'Application not found or it can no longer be withdrawn';
  end if;

  return jsonb_build_object(
    'success', true,
    'application_id', v_updated_id,
    'status', 'withdrawn'
  );
end;
$$;

revoke all on function public.tc_candidate_withdraw_application(uuid) from public, anon;
grant execute on function public.tc_candidate_withdraw_application(uuid) to authenticated;
