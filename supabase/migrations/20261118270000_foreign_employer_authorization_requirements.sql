-- Require authorization details for every overseas registration, not only the foreign_company entity label.
CREATE OR REPLACE FUNCTION public.tc_submit_company_verification(
 p_company_name text,p_industry text,p_company_size text,p_description text,p_website_url text,
 p_legal_entity_type text,p_country_code text,p_legal_name text,p_registration_number text,
 p_registered_address text,p_official_email text,p_contact_person text,p_contact_phone text,
 p_recruitment_authorization text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
declare v_user uuid := (select auth.uid()); v_company_id uuid; v_request_id uuid; v_slug text;
begin
 if v_user is null then raise exception 'Login required'; end if;
 if length(btrim(coalesce(p_company_name,''))) not between 2 and 160 then raise exception 'Valid company name is required'; end if;
 if length(btrim(coalesce(p_legal_name,''))) not between 2 and 180 then raise exception 'Valid legal entity name is required'; end if;
 if length(btrim(coalesce(p_registration_number,''))) not between 2 and 120 then raise exception 'Valid registration number is required'; end if;
 if length(btrim(coalesce(p_registered_address,''))) not between 8 and 1200 then raise exception 'Full registered address is required'; end if;
 if p_legal_entity_type not in ('sole_proprietorship','partnership','llp','private_limited','public_limited','government','nonprofit','foreign_company','other') then raise exception 'Invalid legal entity type'; end if;
 if p_country_code !~ '^[A-Z]{2}$' or not exists(select 1 from public.countries c where c.country_code=p_country_code and c.is_active) then raise exception 'Select an active country'; end if;
 if length(btrim(coalesce(p_official_email,'')))<5 or p_official_email !~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+[.][A-Z]{2,}$' then raise exception 'Valid official email is required'; end if;
 if length(btrim(coalesce(p_contact_person,''))) not between 2 and 120 then raise exception 'Contact person is required'; end if;
 if length(btrim(coalesce(p_contact_phone,''))) not between 7 and 30 then raise exception 'Valid contact phone is required'; end if;
 if (p_country_code <> 'IN' or p_legal_entity_type='foreign_company') and length(btrim(coalesce(p_recruitment_authorization,''))) < 5 then
  raise exception 'Overseas employer authorization details are required. State the applicable recruitment licence, sponsor/work authorization, issuing authority, or why a licence is not applicable.';
 end if;
 select id into v_company_id from public.companies where owner_user_id=v_user and lower(coalesce(registration_number,''))=lower(btrim(p_registration_number)) order by created_at desc limit 1;
 if v_company_id is null then
  v_slug := lower(regexp_replace(btrim(p_company_name),'[^a-zA-Z0-9]+','-','g'))||'-'||substr(replace(gen_random_uuid()::text,'-',''),1,8);
  insert into public.companies(owner_user_id,company_name,company_slug,description,website_url,industry,company_size,registration_number,verification_status)
  values(v_user,btrim(p_company_name),v_slug,nullif(btrim(coalesce(p_description,'')),''),nullif(btrim(coalesce(p_website_url,'')),''),nullif(btrim(coalesce(p_industry,'')),''),nullif(btrim(coalesce(p_company_size,'')),''),btrim(p_registration_number),'pending') returning id into v_company_id;
  insert into public.company_members(company_id,user_id,member_role,member_status) values(v_company_id,v_user,'owner','active') on conflict do nothing;
 else
  update public.companies set company_name=btrim(p_company_name),description=nullif(btrim(coalesce(p_description,'')),''),website_url=nullif(btrim(coalesce(p_website_url,'')),''),industry=nullif(btrim(coalesce(p_industry,'')),''),company_size=nullif(btrim(coalesce(p_company_size,'')),''),verification_status='pending',updated_at=now() where id=v_company_id and owner_user_id=v_user;
 end if;
 if exists(select 1 from public.company_verification_requests where company_id=v_company_id and status in ('pending','under_review','more_information')) then raise exception 'An open verification request already exists for this registration. Check its status before submitting again.'; end if;
 insert into public.company_verification_requests(company_id,submitted_by,legal_entity_type,country_code,legal_name,registration_number,registered_address,official_website,official_email,contact_person,contact_phone,recruitment_authorization,status)
 values(v_company_id,v_user,p_legal_entity_type,p_country_code,btrim(p_legal_name),btrim(p_registration_number),btrim(p_registered_address),nullif(btrim(coalesce(p_website_url,'')),''),lower(btrim(p_official_email)),btrim(p_contact_person),btrim(p_contact_phone),nullif(btrim(coalesce(p_recruitment_authorization,'')),''),'pending') returning id into v_request_id;
 return jsonb_build_object('success',true,'company_id',v_company_id,'request_id',v_request_id,'status','pending');
end;$function$;
REVOKE ALL ON FUNCTION public.tc_submit_company_verification(text,text,text,text,text,text,text,text,text,text,text,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tc_submit_company_verification(text,text,text,text,text,text,text,text,text,text,text,text,text,text) TO authenticated;