-- Production permission and empty-state checks, with temporary operator grant rolled back.
BEGIN;
DO $test$
DECLARE
 v_user uuid;
 v_org uuid;
 v_count integer;
 v_pending bigint;
 v_denied boolean;
 v_overview record;
BEGIN
 IF has_function_privilege('anon','public.platform_control_overview()','EXECUTE')
   OR has_function_privilege('anon','public.platform_control_school_accounts(integer,integer)','EXECUTE')
   OR has_function_privilege('anon','public.platform_control_school_directory(integer,integer)','EXECUTE')
   OR has_function_privilege('anon','public.platform_control_monthly_trends()','EXECUTE')
   OR has_function_privilege('anon','public.platform_control_review_history(integer)','EXECUTE')
 THEN RAISE EXCEPTION 'Anonymous dashboard access exposed'; END IF;
 SELECT u.id INTO v_user FROM auth.users u ORDER BY u.created_at LIMIT 1;
 SELECT org.id INTO v_org FROM platform.organizations org
   WHERE org.status='active' ORDER BY org.created_at LIMIT 1;
 IF v_user IS NULL OR v_org IS NULL THEN
   RAISE EXCEPTION 'No development user/active organization for test';
 END IF;

 PERFORM set_config('request.jwt.claims',
   json_build_object('sub',v_user,'role','authenticated','aal','aal2')::text,true);
 EXECUTE 'SET LOCAL ROLE authenticated';

 v_denied:=false;
 BEGIN PERFORM public.platform_control_overview();
 EXCEPTION WHEN insufficient_privilege THEN v_denied:=true; END;
 IF NOT v_denied THEN RAISE EXCEPTION 'Non-operator accessed overview'; END IF;
 v_denied:=false;
 BEGIN PERFORM public.platform_control_school_accounts();
 EXCEPTION WHEN insufficient_privilege THEN v_denied:=true; END;
 IF NOT v_denied THEN RAISE EXCEPTION 'Non-operator accessed accounts'; END IF;

 EXECUTE 'RESET ROLE';
 INSERT INTO platform.organization_memberships
  (organization_id,auth_user_id,operator_role,status)
 VALUES (v_org,v_user,'admin','active');
 EXECUTE 'SET LOCAL ROLE authenticated';
 PERFORM set_config('request.jwt.claims',
   json_build_object('sub',v_user,'role','authenticated','aal','aal1')::text,true);
 v_denied:=false;
 BEGIN PERFORM public.platform_control_overview();
 EXCEPTION WHEN insufficient_privilege THEN v_denied:=true; END;
 IF NOT v_denied THEN RAISE EXCEPTION 'AAL1 operator accessed monitoring'; END IF;

 PERFORM set_config('request.jwt.claims',
   json_build_object('sub',v_user,'role','authenticated','aal','aal2')::text,true);
 SELECT * INTO v_overview FROM public.platform_control_overview();
 IF v_overview.total_schools IS NULL OR
    v_overview.pending_requests IS NULL OR
    v_overview.school_accounts IS NULL
 THEN RAISE EXCEPTION 'Overview returned invalid null counts'; END IF;

 SELECT count(*) INTO v_count FROM public.platform_control_school_directory();
 IF v_count<>0 THEN RAISE EXCEPTION 'Unexpected real schools leaked'; END IF;
 SELECT count(*) INTO v_count FROM public.platform_control_school_accounts();
 IF v_count<>0 THEN RAISE EXCEPTION 'Unexpected accounts leaked'; END IF;
 SELECT count(*) INTO v_count FROM public.platform_control_monthly_trends();
 IF v_count<>6 THEN RAISE EXCEPTION 'Expected 6 real trend months'; END IF;
 SELECT count(*) INTO v_count FROM public.platform_control_review_history();
 IF v_count<>0 THEN RAISE EXCEPTION 'Unexpected reviews present'; END IF;
 v_denied:=false;
 BEGIN PERFORM public.platform_control_school_accounts(101,0);
 EXCEPTION WHEN invalid_parameter_value THEN v_denied:=true; END;
 IF NOT v_denied THEN RAISE EXCEPTION 'Unbounded account list permitted'; END IF;

 EXECUTE 'RESET ROLE';
 UPDATE platform.organization_memberships SET status='revoked'
  WHERE organization_id=v_org AND auth_user_id=v_user;
 EXECUTE 'SET LOCAL ROLE authenticated';
 v_denied:=false;
 BEGIN PERFORM public.platform_control_overview();
 EXCEPTION WHEN insufficient_privilege THEN v_denied:=true; END;
 IF NOT v_denied THEN RAISE EXCEPTION 'Revoked operator retained access'; END IF;
 EXECUTE 'RESET ROLE';
END;
$test$;
ROLLBACK;