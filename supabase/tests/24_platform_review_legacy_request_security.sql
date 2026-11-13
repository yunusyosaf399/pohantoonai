-- Module 03.7 — review legacy requests, never approve unverified ownership.
-- All operator roles, status changes and review audit entries roll back.
BEGIN;
DO $test$
DECLARE
  v_org uuid;
  v_user uuid;
  v_request uuid;
  v_eligible boolean;
  v_status text;
  v_denied boolean;
  v_n integer;
BEGIN
  IF has_function_privilege('anon',
    'public.platform_control_review_queue(integer,integer)','EXECUTE')
     OR has_function_privilege('anon',
    'public.request_school_activation_information(uuid,text)','EXECUTE') THEN
    RAISE EXCEPTION 'Anonymous legacy request access was granted';
  END IF;
  SELECT r.id,r.organization_id INTO v_request,v_org
  FROM platform.school_onboarding_requests r
  WHERE r.status='submitted'
    AND NOT EXISTS (
      SELECT 1 FROM platform.school_activation_snapshots snap
      WHERE snap.onboarding_request_id=r.id)
  ORDER BY r.created_at DESC LIMIT 1;
  IF v_request IS NULL THEN
    RAISE EXCEPTION 'No existing legacy submitted request available for test';
  END IF;
  SELECT id INTO v_user FROM auth.users ORDER BY created_at LIMIT 1;
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub',v_user,'role','authenticated','aal','aal2')::text,true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_denied:=false;
  BEGIN
    PERFORM public.platform_control_review_queue();
  EXCEPTION WHEN insufficient_privilege THEN v_denied:=true; END;
  IF NOT v_denied THEN RAISE EXCEPTION 'Unassigned user viewed requests'; END IF;

  EXECUTE 'RESET ROLE';
  INSERT INTO platform.organization_memberships(
    organization_id,auth_user_id,operator_role,status
  ) VALUES(v_org,v_user,'admin','active');
  EXECUTE 'SET LOCAL ROLE authenticated';
  SELECT activation_ready,status INTO v_eligible,v_status
  FROM public.platform_control_review_queue(100,0)
  WHERE request_id=v_request;
  IF v_eligible IS DISTINCT FROM false OR v_status<>'submitted' THEN
    RAISE EXCEPTION 'Legacy request missing or incorrectly marked verified';
  END IF;

  v_denied:=false;
  BEGIN
    PERFORM public.approve_school_activation(v_request,'approved_pilot',
      'Approval must not occur without a verified snapshot.',true);
  EXCEPTION WHEN check_violation THEN v_denied:=true;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'Legacy approval unexpectedly succeeded'; END IF;

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub',v_user,'role','authenticated','aal','aal1')::text,true);
  v_denied:=false;
  BEGIN
    PERFORM public.request_school_activation_information(
      v_request,'Ask for a verified school owner and current reviewed details.');
  EXCEPTION WHEN insufficient_privilege THEN v_denied:=true;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'AAL1 reviewer changed request'; END IF;
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub',v_user,'role','authenticated','aal','aal2')::text,true);
  IF NOT public.request_school_activation_information(v_request,
      'Ask for a verified school owner and currently confirmed school details.') THEN
    RAISE EXCEPTION 'Information request failed';
  END IF;
  EXECUTE 'RESET ROLE';
  SELECT status INTO v_status
    FROM platform.school_onboarding_requests WHERE id=v_request;
  IF v_status<>'more_information' THEN RAISE EXCEPTION 'Status was not updated'; END IF;
  SELECT count(*) INTO v_n FROM platform.school_onboarding_reviews
  WHERE onboarding_request_id=v_request AND decision='request_information';
  IF v_n<>1 THEN RAISE EXCEPTION 'Information request not audited'; END IF;
  IF EXISTS(SELECT 1 FROM platform.school_provisioning_links
            WHERE onboarding_request_id=v_request) THEN
    RAISE EXCEPTION 'Legacy request provisioned without verification';
  END IF;
END;
$test$;
ROLLBACK;