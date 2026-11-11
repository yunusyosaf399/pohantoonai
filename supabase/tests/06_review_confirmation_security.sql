-- Step 4 confirmation security test. ALL writes rolled back.
-- Uses an existing development test applicant, but does not mutate their
-- school draft, selected plan, payments or any school record.
BEGIN;

SELECT set_config(
  'request.jwt.claim.sub',
  (SELECT d.user_id::text FROM public.school_setup_drafts d
   WHERE d.draft_status='ready_for_review'
   ORDER BY d.user_id LIMIT 1),
  true
);
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  user_id_now uuid := auth.uid();
  selected_plan uuid;
  draft_timestamp timestamptz;
  accepted_count integer;
BEGIN
  IF user_id_now IS NULL THEN
    RAISE EXCEPTION 'TEST SETUP: no ready review test user';
  END IF;

  SELECT s.selected_plan_id, d.updated_at
    INTO selected_plan, draft_timestamp
    FROM public.school_setup_drafts d
    JOIN public.onboarding_plan_selections s
      ON s.user_id = d.user_id
    WHERE d.user_id = user_id_now
      AND d.draft_status = 'ready_for_review';

  IF selected_plan IS NULL THEN
    RAISE EXCEPTION 'TEST SETUP: missing selected plan';
  END IF;

  -- The real applicant can confirm the current ready draft.
  INSERT INTO public.onboarding_review_confirmations (
    user_id, selected_plan_id, reviewed_draft_updated_at
  ) VALUES (
    user_id_now, selected_plan, draft_timestamp
  )
  ON CONFLICT (user_id) DO UPDATE
    SET selected_plan_id=EXCLUDED.selected_plan_id,
        reviewed_draft_updated_at=EXCLUDED.reviewed_draft_updated_at;

  SELECT count(*) INTO accepted_count
    FROM public.onboarding_review_confirmations
   WHERE user_id=user_id_now;
  IF accepted_count <> 1 THEN
    RAISE EXCEPTION 'TEST FAILURE: owner cannot confirm review';
  END IF;

  -- Stale information must be rejected before a future payment intent.
  BEGIN
    UPDATE public.onboarding_review_confirmations
       SET reviewed_draft_updated_at =
         draft_timestamp - interval '1 second'
     WHERE user_id = user_id_now;
    RAISE EXCEPTION 'SECURITY FAILURE: stale draft confirmation accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  -- A different selected plan must never be confirmed for this draft.
  BEGIN
    UPDATE public.onboarding_review_confirmations
       SET selected_plan_id = gen_random_uuid()
     WHERE user_id = user_id_now;
    RAISE EXCEPTION 'SECURITY FAILURE: mismatched plan accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  -- Authenticated callers cannot create confirmations for other accounts.
  BEGIN
    INSERT INTO public.onboarding_review_confirmations(
      user_id,selected_plan_id,reviewed_draft_updated_at
    ) VALUES (
      gen_random_uuid(),selected_plan,draft_timestamp
    );
    RAISE EXCEPTION 'SECURITY FAILURE: forged user confirmed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

END;
$$;

ROLLBACK;

-- The run must leave the table exactly as it was before the test.
