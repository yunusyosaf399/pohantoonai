-- Module 02.2C: independent server-side completion checks.
-- A modified Flutter client must not activate a blank "ready" draft.
BEGIN;
ALTER POLICY dev_workspace_owner_insert_complete
  ON public.onboarding_dev_workspaces
  WITH CHECK (
    user_id = (SELECT auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.school_setup_drafts d
      JOIN public.onboarding_plan_selections s ON s.user_id=d.user_id
      JOIN public.onboarding_plan_offers o ON o.id=s.selected_plan_id
      WHERE d.user_id=onboarding_dev_workspaces.user_id
        AND d.draft_status='ready_for_review'
        AND s.selected_plan_id=onboarding_dev_workspaces.selected_plan_id
        AND o.is_active AND o.is_demo
        AND length(btrim(coalesce(d.school_name,''))) BETWEEN 2 AND 180
        AND length(btrim(coalesce(d.contact_name,''))) BETWEEN 2 AND 120
        AND d.school_type IN ('public','private','international','nonprofit','other')
        AND d.contact_email ~*
          '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$'
        AND d.country_code ~ '^[A-Z]{2}$'
        AND length(btrim(coalesce(d.city,''))) BETWEEN 1 AND 120
        AND d.estimated_students > 0 AND d.campus_count > 0
        AND (o.student_limit IS NULL OR
             d.estimated_students<=o.student_limit)
        AND (o.campus_limit IS NULL OR
             d.campus_count<=o.campus_limit)
        AND (o.staff_limit IS NULL OR
          coalesce(d.estimated_teachers,0)+
            coalesce(d.estimated_non_teaching_staff,0)<=o.staff_limit)
    )
  );

CREATE OR REPLACE FUNCTION public.onboarding_dev_workspace_guard()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path = ''
AS $$
BEGIN
  IF NEW.user_id IS DISTINCT FROM (SELECT auth.uid())
    OR NEW.access_kind <> 'development_preview'
    OR NOT EXISTS (
      SELECT 1 FROM public.school_setup_drafts d
      JOIN public.onboarding_plan_selections s ON s.user_id=d.user_id
      JOIN public.onboarding_plan_offers o ON o.id=s.selected_plan_id
      WHERE d.user_id=NEW.user_id
        AND d.draft_status='ready_for_review'
        AND s.selected_plan_id=NEW.selected_plan_id
        AND o.is_active AND o.is_demo
        AND length(btrim(coalesce(d.school_name,''))) BETWEEN 2 AND 180
        AND length(btrim(coalesce(d.contact_name,''))) BETWEEN 2 AND 120
        AND d.school_type IN ('public','private','international','nonprofit','other')
        AND d.contact_email ~*
          '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$'
        AND d.country_code ~ '^[A-Z]{2}$'
        AND length(btrim(coalesce(d.city,''))) BETWEEN 1 AND 120
        AND d.estimated_students > 0 AND d.campus_count > 0
        AND (o.student_limit IS NULL OR
             d.estimated_students<=o.student_limit)
        AND (o.campus_limit IS NULL OR
             d.campus_count<=o.campus_limit)
        AND (o.staff_limit IS NULL OR
          coalesce(d.estimated_teachers,0)+
            coalesce(d.estimated_non_teaching_staff,0)<=o.staff_limit)
    ) THEN
    RAISE EXCEPTION USING ERRCODE='42501',
      MESSAGE='Enter all required school details and meet your demo plan limits.';
  END IF;
  NEW.created_at=now();
  RETURN NEW;
END;
$$;

NOTIFY pgrst,'reload schema';
COMMIT;
