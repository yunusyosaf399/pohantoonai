-- Module 01.6: only RLS/metadata verification; no real school is created.
-- Every attempted test write rolls back.
BEGIN;

-- Demo dashboard preferences require the user's persisted test-only skip.
SELECT set_config('request.jwt.claim.sub',
  (SELECT p.user_id::text
     FROM public.onboarding_payment_preferences p
    WHERE p.test_flow_state='skipped_for_testing'
    LIMIT 1),true);

-- The test project may have no test skip records. Skip behavioral insert
-- test in that case and still verify database isolation/privileges below.
DO $$
DECLARE
  can_write boolean;
  n bigint;
BEGIN
  SELECT count(*) INTO n FROM public.schools;
  IF n <> 0 THEN
    RAISE NOTICE 'Existing school records preserved: %', n;
  END IF;
  SELECT count(*) INTO n FROM public.school_memberships;
  IF n <> 0 THEN
    RAISE NOTICE 'Existing membership rows preserved: %', n;
  END IF;

  IF (SELECT count(*) FROM pg_policies
      WHERE schemaname='public'
      AND tablename='onboarding_demo_dashboard_preferences') <> 3 THEN
    RAISE EXCEPTION 'Incorrect demo dashboard policy count';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.role_table_grants
    WHERE table_schema='public'
    AND table_name IN ('schools','school_memberships',
      'school_dashboard_snapshots','school_dashboard_trends',
      'school_dashboard_activity','school_academic_years')
    AND grantee IN ('anon','authenticated')
    AND privilege_type IN ('INSERT','UPDATE','DELETE','TRUNCATE')
  ) THEN
    RAISE EXCEPTION 'SECURITY FAILURE: client can modify tenant data';
  END IF;

  SELECT (count(*) = 6) INTO can_write
   FROM pg_class c
   JOIN pg_namespace nsp ON nsp.oid=c.relnamespace
   WHERE nsp.nspname='public'
     AND c.relname IN ('schools','school_memberships',
       'school_dashboard_snapshots','school_dashboard_trends',
       'school_dashboard_activity','school_academic_years')
     AND c.relrowsecurity=true;
  IF NOT can_write THEN
    RAISE EXCEPTION 'SECURITY FAILURE: tenant table missing RLS';
  END IF;

  IF (SELECT public FROM storage.buckets
       WHERE id='school-logos') IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'SECURITY FAILURE: logo bucket is public/missing';
  END IF;
  IF (SELECT file_size_limit FROM storage.buckets
       WHERE id='school-logos') <> 2097152 THEN
    RAISE EXCEPTION 'Logo size limit changed unexpectedly';
  END IF;
  IF (SELECT count(*) FROM pg_policies
       WHERE schemaname='storage'
       AND tablename='objects'
       AND policyname LIKE 'school_logo_%') <> 4 THEN
    RAISE EXCEPTION 'Logo RLS policies missing';
  END IF;
END;
$$;

SET LOCAL ROLE authenticated;
DO $$
DECLARE
  other_school uuid;
  rows_visible bigint;
BEGIN
  SELECT count(*) INTO rows_visible FROM public.schools;
  -- No real school membership has been granted for this test session,
  -- so it must not be able to read even private owner dashboard reports.
  IF rows_visible <> 0 THEN
    RAISE EXCEPTION 'SECURITY FAILURE: unauthorized school visible';
  END IF;
  SELECT count(*) INTO rows_visible FROM public.school_dashboard_activity;
  IF rows_visible <> 0 THEN
    RAISE EXCEPTION 'SECURITY FAILURE: unauthorized activity visible';
  END IF;
  SELECT count(*) INTO rows_visible FROM public.school_dashboard_snapshots;
  IF rows_visible <> 0 THEN
    RAISE EXCEPTION 'SECURITY FAILURE: unauthorized metrics visible';
  END IF;
  BEGIN
    INSERT INTO public.schools(slug,name)
    VALUES ('forbidden-school','Unauthorized School');
    RAISE EXCEPTION 'SECURITY FAILURE: client can create schools';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END;
$$;
ROLLBACK;
