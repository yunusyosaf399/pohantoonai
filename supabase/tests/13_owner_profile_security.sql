BEGIN;
SELECT set_config('request.jwt.claim.sub',
  (SELECT user_id::text FROM public.school_setup_drafts LIMIT 1),true);
SET LOCAL ROLE authenticated;
DO $$
DECLARE actor uuid:=auth.uid();
BEGIN
  IF actor IS NULL THEN RAISE EXCEPTION 'Missing test account'; END IF;
  INSERT INTO public.user_profiles(user_id,display_name,phone,position)
  VALUES(actor,'Test Owner','+93 700000000','Director')
  ON CONFLICT(user_id) DO UPDATE SET
    display_name=EXCLUDED.display_name,phone=EXCLUDED.phone,
    position=EXCLUDED.position;
  IF NOT EXISTS(
    SELECT 1 FROM public.user_profiles
    WHERE user_id=actor AND position='Director'
      AND phone='+93 700000000'
  ) THEN RAISE EXCEPTION 'Owner profile update failed'; END IF;
  BEGIN
    UPDATE public.user_profiles SET phone=repeat('a',33)
      WHERE user_id=actor;
    RAISE EXCEPTION 'SECURITY FAILURE: overlong phone accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    UPDATE public.user_profiles SET position=repeat('a',121)
      WHERE user_id=actor;
    RAISE EXCEPTION 'SECURITY FAILURE: overlong position accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO public.user_profiles(user_id,display_name)
    VALUES(gen_random_uuid(),'Forged owner');
    RAISE EXCEPTION 'SECURITY FAILURE: owner row spoofing allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END;
$$;
ROLLBACK;
