-- Step 5 payment preference security assertions. All writes are rolled back.
-- No transaction, card, payment, subscription or school records are created.
BEGIN;

SELECT set_config(
  'request.jwt.claim.sub',
  (SELECT d.user_id::text
   FROM public.school_setup_drafts d
   JOIN public.onboarding_plan_selections s ON s.user_id = d.user_id
   JOIN public.onboarding_plan_offers p ON p.id = s.selected_plan_id
   WHERE d.draft_status = 'ready_for_review' AND p.is_active
   ORDER BY d.user_id LIMIT 1),
  true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  actor uuid := auth.uid();
  plan uuid;
  revision timestamptz;
  stored text;
  skip_time timestamptz;
BEGIN
  IF actor IS NULL THEN
    RAISE EXCEPTION 'TEST PRECONDITION: requires ready-for-review test applicant';
  END IF;
  SELECT s.selected_plan_id, d.updated_at
    INTO plan, revision
    FROM public.school_setup_drafts d
    JOIN public.onboarding_plan_selections s ON s.user_id = d.user_id
   WHERE d.user_id = actor;

  -- Review acknowledgement is required before payment preferences.
  INSERT INTO public.onboarding_review_confirmations(
      user_id,selected_plan_id,reviewed_draft_updated_at)
  VALUES (actor,plan,revision)
  ON CONFLICT (user_id) DO UPDATE
      SET selected_plan_id=EXCLUDED.selected_plan_id,
          reviewed_draft_updated_at=EXCLUDED.reviewed_draft_updated_at;

  INSERT INTO public.onboarding_payment_preferences(
      user_id,billing_cycle,preferred_method,billing_email,
      billing_country_code,test_flow_state)
  VALUES(actor,'monthly','card','example@example.invalid','AF','preferences_only')
  ON CONFLICT (user_id) DO UPDATE SET
      billing_cycle=EXCLUDED.billing_cycle,
      preferred_method=EXCLUDED.preferred_method,
      billing_email=EXCLUDED.billing_email,
      billing_country_code=EXCLUDED.billing_country_code,
      test_flow_state=EXCLUDED.test_flow_state;

  SELECT test_flow_state INTO stored
    FROM public.onboarding_payment_preferences WHERE user_id=actor;
  IF stored <> 'preferences_only' THEN
    RAISE EXCEPTION 'TEST FAILURE: preference save did not succeed';
  END IF;

  -- A test skip is explicitly unpaid, with a server-owned timestamp.
  UPDATE public.onboarding_payment_preferences
     SET test_flow_state='skipped_for_testing', skipped_at='1999-01-01'
   WHERE user_id=actor;
  SELECT skipped_at INTO skip_time
    FROM public.onboarding_payment_preferences WHERE user_id=actor;
  IF skip_time < now() - interval '2 minutes' THEN
    RAISE EXCEPTION 'SECURITY FAILURE: caller forged test skip timestamp';
  END IF;

  -- No forged user may insert or read another applicant's settings.
  BEGIN
    INSERT INTO public.onboarding_payment_preferences(
      user_id,billing_cycle)
    VALUES (gen_random_uuid(),'monthly');
    RAISE EXCEPTION 'SECURITY FAILURE: forged account accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    UPDATE public.onboarding_payment_preferences
       SET preferred_method='stolen_card'
     WHERE user_id=actor;
    RAISE EXCEPTION 'SECURITY FAILURE: invalid method accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    UPDATE public.onboarding_payment_preferences
       SET billing_email='not an email'
     WHERE user_id=actor;
    RAISE EXCEPTION 'VALIDATION FAILURE: invalid billing email accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  -- Unrecognized state is impossible: neither 'paid' nor 'activated'
  -- can be written by client code.
  BEGIN
    UPDATE public.onboarding_payment_preferences
       SET test_flow_state='paid'
     WHERE user_id=actor;
    RAISE EXCEPTION 'SECURITY FAILURE: unsupported paid status accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
END;
$$;
ROLLBACK;

-- No test write should persist.
