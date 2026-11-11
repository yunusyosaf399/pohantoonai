-- Step 6 demo settings: owner-only and explicit test-skip required.
-- This script performs NO permanent writes and makes NO real school.
BEGIN;
SELECT set_config('request.jwt.claim.sub',
  (SELECT d.user_id::text
  FROM public.school_setup_drafts d
  JOIN public.onboarding_plan_selections s ON s.user_id=d.user_id
  JOIN public.onboarding_plan_offers p ON p.id=s.selected_plan_id
  WHERE d.draft_status='ready_for_review' AND p.is_active
  ORDER BY d.user_id LIMIT 1),true);
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  actor uuid:=auth.uid();
  plan uuid;
  revision timestamptz;
  selected text;
BEGIN
  IF actor IS NULL THEN
    RAISE EXCEPTION 'TEST PRECONDITION: missing ready-for-review demo applicant';
  END IF;
  SELECT s.selected_plan_id,d.updated_at
    INTO plan,revision FROM public.school_setup_drafts d
    JOIN public.onboarding_plan_selections s ON s.user_id=d.user_id
    WHERE d.user_id=actor;
  INSERT INTO public.onboarding_review_confirmations(
    user_id,selected_plan_id,reviewed_draft_updated_at
  ) VALUES(actor,plan,revision)
  ON CONFLICT(user_id) DO UPDATE SET
    selected_plan_id=EXCLUDED.selected_plan_id,
    reviewed_draft_updated_at=EXCLUDED.reviewed_draft_updated_at;

  INSERT INTO public.onboarding_payment_preferences(
    user_id,test_flow_state,skipped_at
  ) VALUES(actor,'skipped_for_testing',now())
  ON CONFLICT(user_id) DO UPDATE SET
    test_flow_state='skipped_for_testing',skipped_at=now();

  INSERT INTO public.onboarding_demo_dashboard_preferences(
    user_id,selected_chart,academic_year_label
  ) VALUES(actor,'enrollment','2026–27')
  ON CONFLICT(user_id) DO UPDATE SET
    selected_chart='enrollment',
    academic_year_label='2026–27';

  UPDATE public.onboarding_demo_dashboard_preferences
     SET selected_chart='fees' WHERE user_id=actor;
  SELECT selected_chart INTO selected
    FROM public.onboarding_demo_dashboard_preferences WHERE user_id=actor;
  IF selected <> 'fees' THEN
    RAISE EXCEPTION 'TEST FAILURE: owner cannot customize dashboard';
  END IF;

  BEGIN
    INSERT INTO public.onboarding_demo_dashboard_preferences(
      user_id,selected_chart
    ) VALUES(gen_random_uuid(),'fees');
    RAISE EXCEPTION 'SECURITY FAILURE: forged preferences accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    UPDATE public.onboarding_demo_dashboard_preferences
      SET selected_chart='forbidden' WHERE user_id=actor;
    RAISE EXCEPTION 'SECURITY FAILURE: illegal chart allowed';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    UPDATE public.onboarding_demo_dashboard_preferences
      SET quick_actions=ARRAY['root_access']::text[] WHERE user_id=actor;
    RAISE EXCEPTION 'SECURITY FAILURE: unauthorized quick action allowed';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  -- Test-only row may be revoked, but all results are rolled back.
  UPDATE public.onboarding_payment_preferences
     SET test_flow_state='preferences_only',skipped_at=NULL
   WHERE user_id=actor;
  BEGIN
    UPDATE public.onboarding_demo_dashboard_preferences
       SET selected_chart='admissions' WHERE user_id=actor;
    RAISE EXCEPTION 'SECURITY FAILURE: dashboard settings allowed without skip';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END;
$$;
ROLLBACK;
