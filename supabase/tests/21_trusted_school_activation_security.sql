-- Module 03.4 — temporary privilege and provisioning regression.
-- All manufactured schools, owners, operator grants and evidence roll back.
BEGIN;
DO $test$
DECLARE
  v_applicant uuid;
  v_reviewer uuid;
  v_org uuid;
  v_offer uuid;
  v_request uuid;
  v_request_2 uuid;
  v_school uuid;
  v_repeat uuid;
  v_count integer;
  v_denied boolean;
BEGIN
  IF has_function_privilege('anon','public.approve_school_activation(uuid,text,text,boolean)','EXECUTE') OR
    has_function_privilege('anon','public.request_school_activation()','EXECUTE') OR
    has_table_privilege('authenticated','public.schools','INSERT') OR
    has_table_privilege('authenticated','public.school_memberships','INSERT') THEN
    RAISE EXCEPTION 'Privilege escalation detected';
  END IF;
  SELECT id INTO v_applicant FROM auth.users
    WHERE email_confirmed_at IS NOT NULL OR confirmed_at IS NOT NULL
    ORDER BY created_at LIMIT 1;
  SELECT id INTO v_reviewer FROM auth.users WHERE id<>v_applicant
    ORDER BY created_at LIMIT 1;
  IF v_applicant IS NULL OR v_reviewer IS NULL THEN
    RAISE EXCEPTION 'Requires two test auth identities in development';
  END IF;
  SELECT o.organization_id,o.id INTO v_org,v_offer
    FROM public.onboarding_plan_offers o
    JOIN platform.organizations org ON org.id=o.organization_id
    WHERE o.is_active AND o.is_demo AND org.status='active'
    ORDER BY o.code LIMIT 1;
  IF v_org IS NULL THEN RAISE EXCEPTION 'No test-only organization plan'; END IF;

  INSERT INTO platform.school_onboarding_requests(
    organization_id,requester_user_id,selected_plan_id,
    school_display_name,school_type,primary_email,
    preferred_timezone,preferred_currency,status,submitted_at
  ) VALUES (
    v_org,v_applicant,v_offer,'Temporary school A','private',
    'test-provisioning@example.invalid','Asia/Riyadh','SAR','submitted',now()
  ) RETURNING id INTO v_request;
  INSERT INTO platform.school_activation_snapshots(
    onboarding_request_id,owner_user_id,selected_plan_id,
    draft_updated_at,country_code,timezone,currency_code
  ) VALUES (v_request,v_applicant,v_offer,now(),'SA','Asia/Riyadh','SAR');

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub',v_applicant,'role','authenticated','aal','aal2')::text,true);
  EXECUTE 'SET LOCAL ROLE authenticated';

  -- Applicant cannot approve their own request without operator access.
  v_denied:=false;
  BEGIN
    PERFORM public.approve_school_activation(
      v_request,'approved_pilot','Verified test pilot with trusted identity.',true);
  EXCEPTION WHEN insufficient_privilege THEN v_denied:=true;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'Applicant self-approved a school'; END IF;

  EXECUTE 'RESET ROLE';
  INSERT INTO platform.organization_memberships(
    organization_id,auth_user_id,operator_role,status
  ) VALUES (v_org,v_reviewer,'admin','active');

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub',v_reviewer,'role','authenticated','aal','aal1')::text,true);
  EXECUTE 'SET LOCAL ROLE authenticated';

  -- Even platform admins are blocked until second factor is verified.
  v_denied:=false;
  BEGIN
    PERFORM public.approve_school_activation(
      v_request,'approved_pilot','Verified identity of pilot applicant manually.',true);
  EXCEPTION WHEN insufficient_privilege THEN v_denied:=true;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'AAL1 operator could provision a school'; END IF;

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub',v_reviewer,'role','authenticated','aal','aal2')::text,true);
  IF public.my_school_provisioning_role()<>'authorized' THEN
    RAISE EXCEPTION 'Verified operator not detected';
  END IF;
  SELECT count(*) INTO v_count
  FROM public.list_school_activation_reviews() WHERE request_id=v_request;
  IF v_count<>1 THEN RAISE EXCEPTION 'Authorized reviewer cannot see queue'; END IF;

  -- A verified payment must not be invented for a demo plan.
  v_denied:=false;
  BEGIN
    PERFORM public.approve_school_activation(
      v_request,'verified_subscription','Payment has supposedly been verified manually.',true);
  EXCEPTION WHEN check_violation THEN v_denied:=true;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'Demo plan promoted to paid subscription'; END IF;

  SELECT public.approve_school_activation(
    v_request,'approved_pilot',
    'Identity and school details independently verified for explicitly approved development pilot.',
    true) INTO v_school;
  IF v_school IS NULL THEN RAISE EXCEPTION 'No school provisioned'; END IF;

  SELECT count(*) INTO v_count FROM public.schools
    WHERE id=v_school AND lifecycle_status='active';
  IF v_count<>1 THEN RAISE EXCEPTION 'Provisioning missed real schools row'; END IF;
  SELECT count(*) INTO v_count FROM public.school_memberships
    WHERE school_id=v_school AND user_id=v_applicant
      AND role='school_owner' AND membership_status='active';
  IF v_count<>1 THEN RAISE EXCEPTION 'Owner membership missing'; END IF;

  SELECT public.approve_school_activation(
    v_request,'approved_pilot',
    'Repeat safe request with previously recorded evidence.',
    true) INTO v_repeat;
  IF v_repeat IS DISTINCT FROM v_school THEN
    RAISE EXCEPTION 'Retry did not return same school';
  END IF;

  SELECT count(*) INTO v_count FROM platform.school_onboarding_reviews
    WHERE onboarding_request_id=v_request AND decision='approve';
  IF v_count<>1 THEN RAISE EXCEPTION 'Duplicate review audit on retry'; END IF;

  -- Even when an operator is active, self-approval stays blocked.
  EXECUTE 'RESET ROLE';
  INSERT INTO platform.organization_memberships(
    organization_id,auth_user_id,operator_role,status
  ) VALUES(v_org,v_applicant,'admin','active');
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub',v_applicant,'role','authenticated','aal','aal2')::text,true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_denied:=false;
  BEGIN
    PERFORM public.approve_school_activation(
      v_request,'approved_pilot','Applicant trying to approve their own school.',true);
  EXCEPTION WHEN insufficient_privilege THEN v_denied:=true;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'Operator self-approved own request'; END IF;

  EXECUTE 'RESET ROLE';
END;
$test$;
ROLLBACK;