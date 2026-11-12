-- Optional 2FA RLS regression. Strictly rollback-only.
-- A temporary synthetic factor exists inside this transaction ONLY.
-- No real OTP secret, code or factor is committed.
BEGIN;

SELECT set_config('request.jwt.claim.sub',
  (SELECT p.user_id::text
   FROM public.user_profiles p
   JOIN auth.users u ON u.id=p.user_id
   WHERE u.email_confirmed_at IS NOT NULL
   ORDER BY p.user_id LIMIT 1),true);
SELECT set_config('request.jwt.claims',
  json_build_object('sub',current_setting('request.jwt.claim.sub'),
                    'role','authenticated','aal','aal1')::text,true);

SET LOCAL ROLE authenticated;
DO $$
DECLARE n integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Test setup missing verified profile account';
  END IF;
  IF NOT security_private.account_mfa_satisfied() THEN
    RAISE EXCEPTION 'Regular AAL1 account with no MFA was unexpectedly blocked';
  END IF;
  SELECT count(*) INTO n FROM public.user_profiles
    WHERE user_id=auth.uid();
  IF n<>1 THEN
    RAISE EXCEPTION 'Baseline own profile should be visible without MFA';
  END IF;
END $$;

RESET ROLE;

-- Supabase stores actual TOTP factors internally. We create a synthetic
-- factor only inside ROLLBACK to prove both the SQL helper and RLS policies.
INSERT INTO auth.mfa_factors(
  id,user_id,factor_type,status,created_at,updated_at,friendly_name
) VALUES (
  gen_random_uuid(),
  current_setting('request.jwt.claim.sub')::uuid,
  'totp','verified',now(),now(),'ROLLBACK ONLY - no secret'
);

SET LOCAL ROLE authenticated;
DO $$
DECLARE n integer;
BEGIN
  IF security_private.account_mfa_satisfied() THEN
    RAISE EXCEPTION 'SECURITY FAILURE: enrolled account accepted AAL1';
  END IF;
  SELECT count(*) INTO n FROM public.user_profiles
    WHERE user_id=auth.uid();
  IF n<>0 THEN
    RAISE EXCEPTION 'SECURITY FAILURE: unverified AAL1 could read profile';
  END IF;
  SELECT count(*) INTO n FROM public.school_setup_drafts
    WHERE user_id=auth.uid();
  IF n<>0 THEN
    RAISE EXCEPTION 'SECURITY FAILURE: unverified AAL1 could read school';
  END IF;
END $$;

RESET ROLE;

-- This is a test-local JWT claim; no real JWT is minted.
SELECT set_config('request.jwt.claims',
  json_build_object('sub',current_setting('request.jwt.claim.sub'),
                    'role','authenticated','aal','aal2')::text,true);

SET LOCAL ROLE authenticated;
DO $$
DECLARE n integer;
BEGIN
  IF NOT security_private.account_mfa_satisfied() THEN
    RAISE EXCEPTION 'AAL2 owner should have access';
  END IF;
  SELECT count(*) INTO n FROM public.user_profiles
    WHERE user_id=auth.uid();
  IF n<>1 THEN
    RAISE EXCEPTION 'Verified AAL2 owner could not read own profile';
  END IF;
END $$;

ROLLBACK;

-- The test must not leave an enrolled authenticator.
