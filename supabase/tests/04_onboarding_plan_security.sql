-- Module 01.2: PostgreSQL SECURITY SMOKE TEST.
-- Run against disposable development project only. Requires one real Auth test
-- account. All authenticated selection writes are ROLLED BACK at the end.
-- Do not run on production while user sessions are active.
--
-- Expected: anonymous SELECT is denied; authenticated published offers visible;
-- self plan selection insert/update allowed; forged user and invalid plan denied.

BEGIN;
SET LOCAL ROLE anon;
DO $$
BEGIN
  BEGIN
    PERFORM count(*) FROM public.onboarding_plan_offers;
    RAISE EXCEPTION 'SECURITY FAILURE: anon read published offers';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL; -- expected: no anon table grant
  END;
END;
$$;
ROLLBACK;

BEGIN;
SELECT set_config(
  'request.jwt.claim.sub',
  (SELECT id::text FROM auth.users ORDER BY created_at LIMIT 1),
  true
);
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_plan uuid;
  v_user uuid := auth.uid();
  v_changed uuid;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'TEST SETUP: no auth.users test account';
  END IF;
  IF (SELECT count(*) FROM public.onboarding_plan_offers) <> 3 THEN
    RAISE EXCEPTION 'EXPECTATION FAILURE: 3 published demo offers required';
  END IF;
  SELECT id INTO v_plan FROM public.onboarding_plan_offers
    WHERE code = 'growth_demo';
  IF v_plan IS NULL THEN RAISE EXCEPTION 'TEST SETUP: growth plan missing'; END IF;

  INSERT INTO public.onboarding_plan_selections(user_id, selected_plan_id)
    VALUES(v_user,v_plan)
    ON CONFLICT(user_id) DO UPDATE SET selected_plan_id=EXCLUDED.selected_plan_id
    RETURNING selected_plan_id INTO v_changed;
  IF v_changed IS DISTINCT FROM v_plan THEN
    RAISE EXCEPTION 'EXPECTED own selection write to return selected plan';
  END IF;

  BEGIN
    INSERT INTO public.onboarding_plan_selections(user_id,selected_plan_id)
      VALUES (gen_random_uuid(),v_plan);
    RAISE EXCEPTION 'SECURITY FAILURE: forged account selection accepted';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL; -- expected: WITH CHECK requires auth.uid() equal user_id
  END;

  BEGIN
    UPDATE public.onboarding_plan_selections
      SET selected_plan_id = gen_random_uuid() WHERE user_id=v_user;
    RAISE EXCEPTION 'SECURITY FAILURE: invalid plan accepted';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL; -- expected: WITH CHECK rejects unpublished/missing plan
  END;

  BEGIN
    PERFORM count(*) FROM platform.subscription_plans;
    RAISE EXCEPTION 'SECURITY FAILURE: applicant reads private platform data';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
END;
$$;
ROLLBACK;
