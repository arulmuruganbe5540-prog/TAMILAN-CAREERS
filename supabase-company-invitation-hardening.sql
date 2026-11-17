-- Harden the privileged invitation-acceptance function.
-- The Edge Function validates the caller's Supabase session and only service_role
-- may execute this RPC. An empty search_path prevents object shadowing.
begin;

create or replace function public.accept_company_invitation(
  p_token_hash text,
  p_user_id uuid,
  p_user_email text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_invitation public.company_invitations%rowtype;
begin
  select *
  into v_invitation
  from public.company_invitations
  where invite_token_hash = p_token_hash
    and invitation_status = 'invited'
    and expires_at > pg_catalog.now()
    and pg_catalog.lower(pg_catalog.trim(invited_email)) = pg_catalog.lower(pg_catalog.trim(p_user_email))
  for update;

  if not found then
    return pg_catalog.jsonb_build_object('success', false, 'message', 'Invitation invalid or expired');
  end if;

  insert into public.company_members
    (company_id, user_id, member_role, member_status)
  values
    (v_invitation.company_id, p_user_id, v_invitation.member_role, 'active');

  update public.company_invitations
  set invitation_status = 'accepted',
      accepted_user_id = p_user_id,
      accepted_at = pg_catalog.now()
  where id = v_invitation.id;

  return pg_catalog.jsonb_build_object('success', true);
end;
$function$;

revoke all on function public.accept_company_invitation(text, uuid, text) from public, anon, authenticated;
grant execute on function public.accept_company_invitation(text, uuid, text) to service_role;

commit;
