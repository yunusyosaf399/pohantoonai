-- Module 01.6B: preferences for an UNPAID Step 6 developer/demo preview.
-- This does not authorize entry to any real school tenant.
BEGIN;
CREATE TABLE public.onboarding_demo_dashboard_preferences (
  user_id uuid PRIMARY KEY
    REFERENCES public.onboarding_payment_preferences(user_id)
    ON DELETE CASCADE,
  academic_year_label text NOT NULL DEFAULT '2026–27'
    CHECK (char_length(academic_year_label) BETWEEN 4 AND 30),
  selected_chart text NOT NULL DEFAULT 'enrollment'
    CHECK (selected_chart IN (
      'enrollment','attendance','admissions','fees','staff','capacity'
    )),
  quick_actions text[] NOT NULL DEFAULT
    ARRAY['add_student','new_admission','mark_attendance',
          'record_payment','add_staff','send_notice']::text[],
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT dashboard_quick_actions_allowed CHECK (
    quick_actions <@ ARRAY[
      'add_student','new_admission','mark_attendance',
      'record_payment','add_staff','send_notice','reports','settings'
    ]::text[] AND cardinality(quick_actions) <= 8
  )
);
ALTER TABLE public.onboarding_demo_dashboard_preferences ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.onboarding_demo_dashboard_preferences
  FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.onboarding_demo_dashboard_preferences
  TO authenticated;

CREATE POLICY demo_dashboard_read_own
  ON public.onboarding_demo_dashboard_preferences
  FOR SELECT TO authenticated USING (user_id = (SELECT auth.uid()));

CREATE POLICY demo_dashboard_insert_own
  ON public.onboarding_demo_dashboard_preferences
  FOR INSERT TO authenticated WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY demo_dashboard_update_own
  ON public.onboarding_demo_dashboard_preferences
  FOR UPDATE TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

CREATE FUNCTION public.onboarding_demo_dashboard_validate()
RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path = ''
AS $$
BEGIN
  IF (SELECT auth.uid()) IS NULL
     OR NEW.user_id IS DISTINCT FROM (SELECT auth.uid())
     OR NOT EXISTS (
       SELECT 1 FROM public.onboarding_payment_preferences p
        WHERE p.user_id = NEW.user_id
          AND p.test_flow_state = 'skipped_for_testing'
     ) THEN
    RAISE EXCEPTION USING ERRCODE='42501',
      MESSAGE='Developer dashboard preferences require your own test skip.';
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.onboarding_demo_dashboard_validate()
  FROM PUBLIC, anon, authenticated;
CREATE TRIGGER demo_dashboard_preferences_validate
BEFORE INSERT OR UPDATE ON public.onboarding_demo_dashboard_preferences
FOR EACH ROW EXECUTE FUNCTION public.onboarding_demo_dashboard_validate();

NOTIFY pgrst, 'reload schema';
COMMIT;
