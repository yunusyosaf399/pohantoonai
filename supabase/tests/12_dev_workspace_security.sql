-- Persistent development workspace: owner-only, no billing or school access.
-- Run on existing test project. Every attempted mutation is rolled back.
BEGIN;
SELECT set_config('request.jwt.claim.sub',
  (SELECT d.user_id::text FROM public.school_setup_drafts d
   JOIN public.onboarding_plan_selections s ON s.user_id=d.user_id
   JOIN public.onboarding_plan_offers p ON p.id=s.selected_plan_id
   WHERE d.draft_status='ready_for_review' AND p.is_active AND p.is_demo
   LIMIT 1),true);
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  actor uuid:=auth.uid();
  plan_id uuid;
  forged uuid:=gen_random_uuid();
  n integer;
BEGIN
  IF actor IS NULL THEN RAISE EXCEPTION 'Missing test-ready applicant'; END IF;
  SELECT s.selected_plan_id INTO plan_id
  FROM public.onboarding_plan_selections s WHERE s.user_id=actor;

  INSERT INTO public.onboarding_dev_workspaces(user_id,selected_plan_id)
  VALUES(actor,plan_id) ON CONFLICT (user_id) DO NOTHING;
  IF NOT EXISTS(SELECT 1 FROM public.onboarding_dev_workspaces
    WHERE user_id=actor AND selected_plan_id=plan_id
       AND access_kind='development_preview') THEN
    RAISE EXCEPTION 'Could not restore own dev workspace';
  END IF;

  INSERT INTO public.onboarding_demo_dashboard_preferences(
    user_id,selected_chart)
  VALUES(actor,'enrollment') ON CONFLICT(user_id)
    DO UPDATE SET selected_chart='enrollment';

  BEGIN
    INSERT INTO public.onboarding_dev_workspaces(
      user_id,selected_plan_id) VALUES(forged,plan_id);
    RAISE EXCEPTION 'SECURITY FAILURE: forged workspace inserted';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    UPDATE public.onboarding_dev_workspaces SET access_kind='paid'
      WHERE user_id=actor;
    RAISE EXCEPTION 'SECURITY FAILURE: user can approve payment';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    INSERT INTO public.schools(slug,name)
    VALUES ('dev-bypass','Forged School');
    RAISE EXCEPTION 'SECURITY FAILURE: dev preview provisions school';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  SELECT count(*) INTO n FROM public.school_memberships
    WHERE user_id=actor;
  IF n>0 THEN
    RAISE EXCEPTION 'Unexpected real-school membership'; END IF;
END;
$$;
ROLLBACK;
