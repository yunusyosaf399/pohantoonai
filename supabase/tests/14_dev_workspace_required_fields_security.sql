-- Test server-side required fields for development workspace.
-- All changes are rolled back; no real school or payment is created.
BEGIN;
SELECT set_config('request.jwt.claim.sub',
  (SELECT d.user_id::text FROM public.school_setup_drafts d
   JOIN public.onboarding_plan_selections s ON s.user_id=d.user_id
   JOIN public.onboarding_plan_offers o ON o.id=s.selected_plan_id
   WHERE d.draft_status='ready_for_review' AND o.is_active AND o.is_demo
     AND nullif(btrim(d.school_name),'') IS NOT NULL LIMIT 1),true);
SET LOCAL ROLE authenticated;
DO $$
DECLARE
 actor uuid:=auth.uid();
 pid uuid;
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'No test applicant exists'; END IF;
 SELECT selected_plan_id INTO pid FROM public.onboarding_plan_selections
  WHERE user_id=actor;
 UPDATE public.school_setup_drafts
   SET school_name=NULL WHERE user_id=actor;
 BEGIN
   INSERT INTO public.onboarding_dev_workspaces(user_id,selected_plan_id)
   VALUES(actor,pid) ON CONFLICT(user_id) DO NOTHING;
   RAISE EXCEPTION 'SECURITY FAILURE: blank school got demo workspace';
 EXCEPTION WHEN insufficient_privilege OR check_violation THEN NULL;
 END;
 UPDATE public.school_setup_drafts
   SET school_name='Valid Example Academy',contact_email='not-an-email'
   WHERE user_id=actor;
 BEGIN
   INSERT INTO public.onboarding_dev_workspaces(user_id,selected_plan_id)
   VALUES(actor,pid) ON CONFLICT(user_id) DO NOTHING;
   RAISE EXCEPTION 'SECURITY FAILURE: invalid email got demo workspace';
 EXCEPTION WHEN insufficient_privilege OR check_violation THEN NULL;
 END;
END;
$$;
ROLLBACK;
