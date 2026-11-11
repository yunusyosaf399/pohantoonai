-- Step 3: transactional least-privilege smoke test.
-- Uses existing development Auth test user, but rolls back all mutations.
-- This script is NOT a production seed and must not be run against live users.
BEGIN;
SELECT set_config(
  'request.jwt.claim.sub',
  (SELECT id::text FROM auth.users ORDER BY created_at LIMIT 1), true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  v_user uuid := auth.uid();
  v_plan uuid;
  v_count int;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'TEST SETUP: no test account exists in auth.users';
  END IF;
  SELECT id INTO v_plan
    FROM public.onboarding_plan_offers
    WHERE code = 'growth_demo' AND is_active;
  IF v_plan IS NULL THEN
    RAISE EXCEPTION 'TEST SETUP: growth plan is not published';
  END IF;

  INSERT INTO public.onboarding_plan_selections(user_id,selected_plan_id)
    VALUES (v_user,v_plan)
    ON CONFLICT (user_id) DO UPDATE
      SET selected_plan_id=EXCLUDED.selected_plan_id;

  -- A partial draft must be accepted; only status "ready" is strict.
  INSERT INTO public.school_setup_drafts(
      user_id,school_name,draft_status)
    VALUES(v_user,'Test-only School','draft')
    ON CONFLICT (user_id) DO UPDATE
      SET school_name=EXCLUDED.school_name,
          draft_status='draft',
          school_type=NULL,
          contact_name=NULL,
          contact_email=NULL,
          country_code=NULL,
          city=NULL,
          estimated_students=NULL,
          campus_count=NULL;
  SELECT count(*) INTO v_count FROM public.school_setup_drafts
    WHERE user_id=v_user;
  IF v_count<>1 THEN
    RAISE EXCEPTION 'OWNERSHIP FAILURE: own draft not readable';
  END IF;

  -- Attempt to set ready without required details must fail.
  BEGIN
    UPDATE public.school_setup_drafts SET draft_status='ready_for_review'
      WHERE user_id=v_user;
    RAISE EXCEPTION 'VALIDATION FAILURE: incomplete draft accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  -- Cross-user inserts must be denied by RLS even with valid data.
  BEGIN
    INSERT INTO public.school_setup_drafts(user_id,school_name)
      VALUES(gen_random_uuid(),'Forgery');
    RAISE EXCEPTION 'SECURITY FAILURE: forged draft inserted';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  -- Complete estimates above the chosen plan must fail.
  BEGIN
    UPDATE public.school_setup_drafts SET
      school_type='private',contact_name='Test contact',
      contact_email='test@example.invalid',country_code='SA',
      city='Test City',estimated_students=1501,
      campus_count=1,draft_status='ready_for_review'
    WHERE user_id=v_user;
    RAISE EXCEPTION 'CAPACITY FAILURE: over-capacity review accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  -- Under-capacity review now passes.
  UPDATE public.school_setup_drafts SET
    school_type='private', contact_name='Test contact',
    contact_email='test@example.invalid', country_code='SA',
    city='Test City',estimated_students=100,
    campus_count=1,estimated_teachers=5,
    estimated_non_teaching_staff=2,
    draft_status='ready_for_review'
  WHERE user_id=v_user;
  SELECT count(*) INTO v_count FROM public.school_setup_drafts
    WHERE user_id=v_user AND draft_status='ready_for_review';
  IF v_count<>1 THEN
    RAISE EXCEPTION 'VALIDATION FAILURE: valid draft not review-ready';
  END IF;

  -- Plan change reverts review-ready state to an editable draft.
  UPDATE public.onboarding_plan_selections
    SET selected_plan_id=(
      SELECT id FROM public.onboarding_plan_offers
      WHERE code='starter_demo' AND is_active LIMIT 1)
    WHERE user_id=v_user;
  SELECT count(*) INTO v_count FROM public.school_setup_drafts
    WHERE user_id=v_user AND draft_status='draft';
  IF v_count<>1 THEN
    RAISE EXCEPTION 'PLAN SYNC FAILURE: ready status did not reset';
  END IF;
END;
$$;
ROLLBACK;

-- Persistent row count checked separately after executing this test.
