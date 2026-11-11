-- Module 02.1: Development-enabled dashboard persistence (NOT payment approval).
-- Requires the signed-in user to have completed a valid school setup draft.
-- Do not use these records as subscriptions, payments, or school permissions.
BEGIN;

CREATE TABLE public.onboarding_dev_workspaces (
  user_id uuid PRIMARY KEY
    REFERENCES public.school_setup_drafts(user_id) ON DELETE CASCADE,
  selected_plan_id uuid NOT NULL
    REFERENCES public.onboarding_plan_offers(id),
  access_kind text NOT NULL DEFAULT 'development_preview'
    CHECK (access_kind = 'development_preview'),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT dev_workspace_user_plan UNIQUE (user_id, selected_plan_id)
);
ALTER TABLE public.onboarding_dev_workspaces ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.onboarding_dev_workspaces FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT ON public.onboarding_dev_workspaces TO authenticated;

CREATE POLICY dev_workspace_owner_select
  ON public.onboarding_dev_workspaces FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

CREATE POLICY dev_workspace_owner_insert_complete
  ON public.onboarding_dev_workspaces FOR INSERT TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid()) AND
    EXISTS (
      SELECT 1 FROM public.school_setup_drafts d
      JOIN public.onboarding_plan_selections p ON p.user_id=d.user_id
      JOIN public.onboarding_plan_offers o ON o.id=p.selected_plan_id
      WHERE d.user_id=onboarding_dev_workspaces.user_id
        AND d.draft_status='ready_for_review'
        AND p.selected_plan_id=onboarding_dev_workspaces.selected_plan_id
        AND o.is_active AND o.is_demo
    )
  );

-- Recheck the plan/draft on the server, not from user-editable JWT metadata.
CREATE FUNCTION public.onboarding_dev_workspace_guard()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path = ''
AS $$
BEGIN
  IF NEW.user_id IS DISTINCT FROM (SELECT auth.uid())
    OR NEW.access_kind <> 'development_preview'
    OR NOT EXISTS (
      SELECT 1 FROM public.school_setup_drafts d
      JOIN public.onboarding_plan_selections p ON p.user_id=d.user_id
      JOIN public.onboarding_plan_offers o ON o.id=p.selected_plan_id
      WHERE d.user_id=NEW.user_id
        AND d.draft_status='ready_for_review'
        AND p.selected_plan_id=NEW.selected_plan_id
        AND o.is_active AND o.is_demo
    ) THEN
    RAISE EXCEPTION USING ERRCODE='42501',
      MESSAGE='Complete your own school setup and select an active demo plan.';
  END IF;
  NEW.created_at=now();
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.onboarding_dev_workspace_guard()
  FROM PUBLIC,anon,authenticated;
CREATE TRIGGER dev_workspace_guard_before_insert
BEFORE INSERT ON public.onboarding_dev_workspaces
FOR EACH ROW EXECUTE FUNCTION public.onboarding_dev_workspace_guard();

-- Earlier test-skip applicants are upgraded lazily by the authenticated
-- Flutter client after it revalidates their plan and school draft.
-- No privileged migration impersonation or raw SQL auth bypass is used.

-- Dashboard customization no longer requires a payment-preferences row:
-- a dev workspace is now the correct (unpaid) parent record.
ALTER TABLE public.onboarding_demo_dashboard_preferences
  DROP CONSTRAINT onboarding_demo_dashboard_preferences_user_id_fkey;
ALTER TABLE public.onboarding_demo_dashboard_preferences
  ADD CONSTRAINT onboarding_demo_dashboard_preferences_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES public.onboarding_dev_workspaces(user_id) ON DELETE CASCADE;

CREATE OR REPLACE FUNCTION public.onboarding_demo_dashboard_validate()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path = ''
AS $$
BEGIN
  IF (SELECT auth.uid()) IS NULL
     OR NEW.user_id IS DISTINCT FROM (SELECT auth.uid())
     OR NOT EXISTS (
       SELECT 1 FROM public.onboarding_dev_workspaces w
       JOIN public.school_setup_drafts d ON d.user_id=w.user_id
       JOIN public.onboarding_plan_selections s ON s.user_id=w.user_id
       JOIN public.onboarding_plan_offers o ON o.id=s.selected_plan_id
       WHERE w.user_id=NEW.user_id
         AND w.access_kind='development_preview'
         AND w.selected_plan_id=s.selected_plan_id
         AND d.draft_status='ready_for_review'
         AND o.is_active AND o.is_demo
     ) THEN
    RAISE EXCEPTION USING ERRCODE='42501',
      MESSAGE='Dashboard customization requires your completed demo school.';
  END IF;
  NEW.updated_at=now();
  RETURN NEW;
END;
$$;

NOTIFY pgrst,'reload schema';
COMMIT;
