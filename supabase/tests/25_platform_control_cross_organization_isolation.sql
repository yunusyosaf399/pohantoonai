-- Platform control cross-organization isolation, including a fake school/member.
-- All fixtures are ROLLED BACK and do not create live schools.
BEGIN;
DO $test$
DECLARE
 v_operator uuid;
 v_owner uuid;
 v_org_a uuid;
 v_org_b uuid;
 v_request_b uuid;
 v_school_b uuid;
 v_count integer;
BEGIN
 SELECT id INTO v_operator FROM auth.users ORDER BY created_at LIMIT 1;
 SELECT id INTO v_owner FROM auth.users
   WHERE id<>v_operator ORDER BY created_at LIMIT 1;
 SELECT id INTO v_org_a FROM platform.organizations
   WHERE status='active' ORDER BY created_at LIMIT 1;
 IF v_operator IS NULL OR v_owner IS NULL OR v_org_a IS NULL THEN
   RAISE EXCEPTION 'Two Auth users and one organization required';
 END IF;

 INSERT INTO platform.organizations(
   slug,legal_name,display_name,status
 ) VALUES (
   'isolation-test-'||substr(replace(gen_random_uuid()::text,'-',''),1,18),
   'Temporary Other Organization','Temporary Other Organization','active'
 ) RETURNING id INTO v_org_b;

 INSERT INTO platform.school_onboarding_requests(
   organization_id,requester_user_id,school_display_name,
   primary_email,status,submitted_at
 ) VALUES (
   v_org_b,v_owner,'Other Org School Application',
   'other-school@example.invalid','submitted',now()
 ) RETURNING id INTO v_request_b;

 INSERT INTO public.schools(slug,name,lifecycle_status)
 VALUES(
   'isolation-test-'||substr(replace(gen_random_uuid()::text,'-',''),1,20),
   'Other Organization Provisioned School','active'
 ) RETURNING id INTO v_school_b;

 INSERT INTO public.school_memberships(
   school_id,user_id,role,membership_status
 ) VALUES(v_school_b,v_owner,'school_owner','active');

 INSERT INTO platform.school_provisioning_links(
   onboarding_request_id,school_id,owner_user_id,approved_by,
   activation_basis,approval_evidence
 ) VALUES (
   v_request_b,v_school_b,v_owner,v_operator,
   'approved_pilot','Test-only independent review of isolated organization fixture.'
 );

 INSERT INTO platform.organization_memberships(
   organization_id,auth_user_id,operator_role,status
 ) VALUES(v_org_a,v_operator,'admin','active');

 PERFORM set_config('request.jwt.claims',
  json_build_object('sub',v_operator,'role','authenticated','aal','aal2')::text,true);
 EXECUTE 'SET LOCAL ROLE authenticated';

 SELECT count(*) INTO v_count
 FROM public.platform_control_review_queue()
 WHERE request_id=v_request_b;
 IF v_count<>0 THEN RAISE EXCEPTION 'Leaked another org request'; END IF;

 SELECT count(*) INTO v_count
 FROM public.platform_control_school_directory()
 WHERE school_id=v_school_b;
 IF v_count<>0 THEN RAISE EXCEPTION 'Leaked another org school'; END IF;

 SELECT count(*) INTO v_count
 FROM public.platform_control_school_accounts()
 WHERE school_id=v_school_b OR user_id=v_owner;
 IF v_count<>0 THEN RAISE EXCEPTION 'Leaked another org school account'; END IF;

 IF (SELECT total_schools FROM public.platform_control_overview())<>0 THEN
   RAISE EXCEPTION 'Overview counted unauthorized school';
 END IF;

 EXECUTE 'RESET ROLE';
 INSERT INTO platform.organization_memberships(
  organization_id,auth_user_id,operator_role,status
 ) VALUES(v_org_b,v_operator,'admin','active');
 EXECUTE 'SET LOCAL ROLE authenticated';

 SELECT count(*) INTO v_count
 FROM public.platform_control_school_directory()
 WHERE school_id=v_school_b;
 IF v_count<>1 THEN RAISE EXCEPTION 'Permitted school missing'; END IF;
 SELECT count(*) INTO v_count
 FROM public.platform_control_school_accounts()
 WHERE school_id=v_school_b AND user_id=v_owner;
 IF v_count<>1 THEN RAISE EXCEPTION 'Permitted school owner missing'; END IF;
 IF (SELECT total_schools FROM public.platform_control_overview())<>1 THEN
   RAISE EXCEPTION 'Overview count incorrect after granting org';
 END IF;

 EXECUTE 'RESET ROLE';
END;
$test$;
ROLLBACK;