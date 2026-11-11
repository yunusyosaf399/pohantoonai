-- Auth continuity: Google + password + saved demo workspace share auth.users.id.
-- Zero changes are retained. Login sessions are simulated only for RLS,
-- not for SMTP delivery or real browser authentication.
BEGIN;

-- Select an account with both sign-in methods and a saved workspace.
DO $$
DECLARE account_id uuid;
BEGIN
  SELECT u.id INTO account_id
  FROM auth.users u
  JOIN public.onboarding_dev_workspaces w ON w.user_id = u.id
  WHERE length(coalesce(u.encrypted_password,'')) > 0
    AND u.email_confirmed_at IS NOT NULL
    AND EXISTS(
      SELECT 1 FROM auth.identities i
      WHERE i.user_id=u.id AND i.provider='google'
    )
  LIMIT 1;

  IF account_id IS NULL THEN
    RAISE EXCEPTION 'No confirmed Google+password account with workspace exists';
  END IF;
  PERFORM set_config('request.jwt.claim.sub',account_id::text,true);
END;
$$;

SET LOCAL ROLE authenticated;
DO $$
BEGIN
  IF (SELECT count(*) FROM public.onboarding_dev_workspaces) <> 1 THEN
    RAISE EXCEPTION 'Same-account development workspace is not RLS-visible';
  END IF;
  IF NOT EXISTS(
    SELECT 1 FROM public.onboarding_dev_workspaces w
    JOIN public.onboarding_plan_selections s ON s.user_id=w.user_id
    JOIN public.school_setup_drafts d ON d.user_id=w.user_id
    WHERE w.user_id = auth.uid()
      AND w.selected_plan_id = s.selected_plan_id
      AND d.draft_status='ready_for_review'
      AND w.access_kind='development_preview'
  ) THEN
    RAISE EXCEPTION 'Owned plan/draft/workspace relationship broken';
  END IF;
END;
$$;

RESET ROLE;

-- A distinct confirmed account cannot read the first user's workspace.
DO $$
DECLARE alternate_id uuid;
BEGIN
  SELECT u.id INTO alternate_id
  FROM auth.users u
  WHERE u.email_confirmed_at IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM public.onboarding_dev_workspaces w
      WHERE w.user_id=u.id
    )
  ORDER BY u.created_at LIMIT 1;
  IF alternate_id IS NULL THEN
    RAISE EXCEPTION 'No separate account available for RLS negative test';
  END IF;
  PERFORM set_config('request.jwt.claim.sub',alternate_id::text,true);
END;
$$;

SET LOCAL ROLE authenticated;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.onboarding_dev_workspaces) THEN
    RAISE EXCEPTION 'SECURITY FAILURE: other account can read saved workspace';
  END IF;
END;
$$;

ROLLBACK;
