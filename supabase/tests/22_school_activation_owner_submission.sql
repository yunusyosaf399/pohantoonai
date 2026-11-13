-- Owner submission checks using the existing confirmed, reviewed account.
-- We temporarily re-confirm the current draft, then roll back everything.
BEGIN;
DO $test$
DECLARE
  v_user uuid;
  v_id uuid;
  v_repeat uuid;
  v_n integer;
  v_denied boolean;
BEGIN
  SELECT c.user_id INTO v_user
  FROM public.onboarding_review_confirmations c
  JOIN public.school_setup_drafts d ON d.user_id=c.user_id
  JOIN public.onboarding_plan_selections s ON s.user_id=c.user_id
  WHERE d.draft_status='ready_for_review'
    AND c.selected_plan_id=s.selected_plan_id
  LIMIT 1;
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'No confirmed development owner available for test';
  END IF;
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub',v_user,'role','authenticated','aal','aal2')::text,true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  UPDATE public.onboarding_review_confirmations c
  SET reviewed_draft_updated_at=d.updated_at
  FROM public.school_setup_drafts d
  WHERE c.user_id=v_user AND d.user_id=v_user;

  SELECT public.request_school_activation() INTO v_id;
  IF v_id IS NULL THEN RAISE EXCEPTION 'No request returned'; END IF;
  SELECT count(*) INTO v_n FROM public.my_school_activation_status()
  WHERE request_id=v_id AND status='submitted';
  IF v_n<>1 THEN RAISE EXCEPTION 'Owner cannot see own pending review'; END IF;
  SELECT public.request_school_activation() INTO v_repeat;
  IF v_repeat IS DISTINCT FROM v_id THEN RAISE EXCEPTION 'Not idempotent'; END IF;

  v_denied:=false;
  BEGIN
    PERFORM public.approve_school_activation(
      v_id,'approved_pilot',
      'No platform operator is allowed to self-approve.',true);
  EXCEPTION WHEN insufficient_privilege THEN v_denied:=true;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'Owner illegally approved own application'; END IF;
  EXECUTE 'RESET ROLE';

  SELECT count(*) INTO v_n FROM platform.school_activation_snapshots
    WHERE onboarding_request_id=v_id AND owner_user_id=v_user;
  IF v_n<>1 THEN RAISE EXCEPTION 'Submitted request lost original owner snapshot'; END IF;
END;
$test$;
ROLLBACK;