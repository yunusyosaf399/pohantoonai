-- Private logo tests; all writes are rolled back.
BEGIN;
SELECT set_config('request.jwt.claim.sub',
  (SELECT user_id::text
   FROM public.school_setup_drafts ORDER BY user_id LIMIT 1),true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  actor uuid:=auth.uid();
  valid_path text;
  foreign_path text;
BEGIN
  IF actor IS NULL THEN
    RAISE EXCEPTION 'TEST SETUP: no test applicant available';
  END IF;
  valid_path:=actor::text||'/logos/logo-12345.png';
  foreign_path:=gen_random_uuid()::text||'/logos/logo-12345.png';

  -- The account may reference only its own Storage folder.
  UPDATE public.school_setup_drafts
    SET logo_storage_path=valid_path WHERE user_id=actor;

  IF NOT EXISTS (SELECT 1 FROM public.school_setup_drafts
       WHERE user_id=actor AND logo_storage_path=valid_path) THEN
    RAISE EXCEPTION 'TEST FAILURE: owner cannot set own logo path';
  END IF;

  BEGIN
    UPDATE public.school_setup_drafts SET logo_storage_path=foreign_path
      WHERE user_id=actor;
    RAISE EXCEPTION 'SECURITY FAILURE: cross-account logo path accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    UPDATE public.school_setup_drafts
      SET logo_storage_path=actor::text||'/other/logo.jpg'
      WHERE user_id=actor;
    RAISE EXCEPTION 'SECURITY FAILURE: wrong object folder accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    UPDATE public.school_setup_drafts
      SET logo_storage_path=actor::text||'/logos/script.svg'
      WHERE user_id=actor;
    RAISE EXCEPTION 'SECURITY FAILURE: SVG logo path accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
END;
$$;
ROLLBACK;
