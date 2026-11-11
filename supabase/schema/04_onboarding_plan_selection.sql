-- Module 01.2 / Step 2 of 6: Safe public plan offers + user's unbilled choice.
-- Database of record remains platform.subscription_plans and its feature limits.
-- THIS IS NOT A PAID SUBSCRIPTION OR AN APPROVED SCHOOL.
-- Apply once to the single pohantoonai development Supabase project.
BEGIN;

CREATE TABLE public.onboarding_plan_offers (
  id uuid PRIMARY KEY REFERENCES platform.subscription_plans(id) ON DELETE RESTRICT,
  organization_id uuid NOT NULL REFERENCES platform.organizations(id) ON DELETE RESTRICT,
  code text NOT NULL,
  name text NOT NULL,
  summary text,
  student_limit bigint CHECK (student_limit IS NULL OR student_limit >= 0),
  campus_limit bigint CHECK (campus_limit IS NULL OR campus_limit >= 0),
  staff_limit bigint CHECK (staff_limit IS NULL OR staff_limit >= 0),
  trial_days integer NOT NULL CHECK (trial_days BETWEEN 0 AND 365),
  is_demo boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT false,
  sort_order integer NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, code)
);

CREATE TABLE public.onboarding_plan_selections (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  selected_plan_id uuid NOT NULL
    REFERENCES public.onboarding_plan_offers(id) ON DELETE RESTRICT,
  selected_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX onboarding_plan_offers_visible_order
  ON public.onboarding_plan_offers(is_active, sort_order, id);
CREATE INDEX onboarding_plan_selections_plan
  ON public.onboarding_plan_selections(selected_plan_id);

-- Defense in depth: the client can READ only active published offers.
-- The authenticated caller can READ/INSERT/UPDATE only their own draft choice.
-- There is no DELETE permission or school/operator/billing grant here.
ALTER TABLE public.onboarding_plan_offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.onboarding_plan_selections ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.onboarding_plan_offers FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.onboarding_plan_selections FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.onboarding_plan_offers TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.onboarding_plan_selections TO authenticated;

CREATE POLICY onboarding_offers_read_active
  ON public.onboarding_plan_offers FOR SELECT TO authenticated
  USING (is_active = true);

CREATE POLICY onboarding_selection_read_own
  ON public.onboarding_plan_selections FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

CREATE POLICY onboarding_selection_create_own_active
  ON public.onboarding_plan_selections FOR INSERT TO authenticated
  WITH CHECK (
    user_id = (SELECT auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.onboarding_plan_offers offers
      WHERE offers.id = selected_plan_id AND offers.is_active
    )
  );

CREATE POLICY onboarding_selection_update_own_active
  ON public.onboarding_plan_selections FOR UPDATE TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (
    user_id = (SELECT auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.onboarding_plan_offers offers
      WHERE offers.id = selected_plan_id AND offers.is_active
    )
  );

-- Server timestamps cannot be spoofed by client-supplied values.
CREATE FUNCTION public.onboarding_plan_selection_stamp()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at := now();
  NEW.selected_at := now();
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.onboarding_plan_selection_stamp()
  FROM PUBLIC, anon, authenticated;

CREATE TRIGGER onboarding_plan_selection_timestamp
  BEFORE INSERT OR UPDATE ON public.onboarding_plan_selections
  FOR EACH ROW EXECUTE FUNCTION public.onboarding_plan_selection_stamp();

-- A privileged, non-exposed synchronizer copies ONLY safe published plan fields.
-- It has no client EXECUTE privileges, uses a fixed search_path and reads the
-- private SaaS source-of-truth rather than trusting a client-supplied plan price.
CREATE FUNCTION platform.refresh_onboarding_offer(p_plan_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.onboarding_plan_offers (
    id, organization_id, code, name, summary,
    student_limit, campus_limit, staff_limit, trial_days,
    is_demo, is_active, sort_order, updated_at
  )
  SELECT p.id, p.organization_id, p.code, p.name, p.summary,
    CASE WHEN EXISTS (
      SELECT 1 FROM platform.subscription_plan_features f
      WHERE f.plan_id = p.id AND f.feature_code = 'students' AND f.enabled
    ) THEN (
      SELECT f.limit_value FROM platform.subscription_plan_features f
      WHERE f.plan_id = p.id AND f.feature_code = 'students' AND f.enabled
      LIMIT 1
    ) ELSE 0 END,
    CASE WHEN EXISTS (
      SELECT 1 FROM platform.subscription_plan_features f
      WHERE f.plan_id = p.id AND f.feature_code = 'campuses' AND f.enabled
    ) THEN (
      SELECT f.limit_value FROM platform.subscription_plan_features f
      WHERE f.plan_id = p.id AND f.feature_code = 'campuses' AND f.enabled
      LIMIT 1
    ) ELSE 0 END,
    CASE WHEN EXISTS (
      SELECT 1 FROM platform.subscription_plan_features f
      WHERE f.plan_id = p.id AND f.feature_code = 'staff' AND f.enabled
    ) THEN (
      SELECT f.limit_value FROM platform.subscription_plan_features f
      WHERE f.plan_id = p.id AND f.feature_code = 'staff' AND f.enabled
      LIMIT 1
    ) ELSE 0 END,
    p.trial_days, p.is_test_only,
    (p.is_public AND p.status = 'active'),
    p.sort_order, now()
  FROM platform.subscription_plans p
  WHERE p.id = p_plan_id
  ON CONFLICT (id) DO UPDATE SET
    organization_id = EXCLUDED.organization_id,
    code = EXCLUDED.code,
    name = EXCLUDED.name,
    summary = EXCLUDED.summary,
    student_limit = EXCLUDED.student_limit,
    campus_limit = EXCLUDED.campus_limit,
    staff_limit = EXCLUDED.staff_limit,
    trial_days = EXCLUDED.trial_days,
    is_demo = EXCLUDED.is_demo,
    is_active = EXCLUDED.is_active,
    sort_order = EXCLUDED.sort_order,
    updated_at = now();
END;
$$;
REVOKE ALL ON FUNCTION platform.refresh_onboarding_offer(uuid)
  FROM PUBLIC, anon, authenticated;

CREATE FUNCTION platform.onboarding_offer_plan_changed()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path = ''
AS $$
BEGIN
  PERFORM platform.refresh_onboarding_offer(NEW.id);
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION platform.onboarding_offer_plan_changed()
  FROM PUBLIC, anon, authenticated;

CREATE FUNCTION platform.onboarding_offer_feature_changed()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM platform.refresh_onboarding_offer(OLD.plan_id);
    RETURN OLD;
  END IF;
  IF TG_OP = 'UPDATE' AND NEW.plan_id IS DISTINCT FROM OLD.plan_id THEN
    PERFORM platform.refresh_onboarding_offer(OLD.plan_id);
  END IF;
  PERFORM platform.refresh_onboarding_offer(NEW.plan_id);
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION platform.onboarding_offer_feature_changed()
  FROM PUBLIC, anon, authenticated;

CREATE TRIGGER platform_plan_offer_refresh
  AFTER INSERT OR UPDATE OF
    code, name, summary, status, is_public, is_test_only, trial_days, sort_order
  ON platform.subscription_plans
  FOR EACH ROW EXECUTE FUNCTION platform.onboarding_offer_plan_changed();

CREATE TRIGGER platform_plan_offer_feature_refresh
  AFTER INSERT OR UPDATE OR DELETE
  ON platform.subscription_plan_features
  FOR EACH ROW EXECUTE FUNCTION platform.onboarding_offer_feature_changed();

-- Initial publication of the already seeded/demo source records.
SELECT platform.refresh_onboarding_offer(id)
  FROM platform.subscription_plans;

NOTIFY pgrst, 'reload schema';
COMMIT;
