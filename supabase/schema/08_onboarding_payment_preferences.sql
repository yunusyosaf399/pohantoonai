-- Module 01.5 — Payment screen preference/skip record only.
-- This is NOT a payments, card vault, invoice, receipt, transaction,
-- subscription entitlement or school provisioning table.
BEGIN;

CREATE TABLE public.onboarding_payment_preferences (
  user_id uuid PRIMARY KEY
    REFERENCES public.onboarding_review_confirmations(user_id)
    ON DELETE CASCADE,
  billing_cycle text NOT NULL DEFAULT 'monthly'
    CHECK (billing_cycle IN ('monthly', 'annual')),
  preferred_method text NOT NULL DEFAULT 'card'
    CHECK (preferred_method IN ('card', 'bank_transfer', 'wallet')),
  billing_email text
    CHECK (billing_email IS NULL OR
           (length(billing_email) <= 254 AND
            billing_email ~* '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$')),
  billing_school_name text CHECK (billing_school_name IS NULL OR length(billing_school_name) <= 220),
  billing_address text CHECK (billing_address IS NULL OR length(billing_address) <= 500),
  billing_city text CHECK (billing_city IS NULL OR length(billing_city) <= 120),
  billing_country_code text CHECK (
    billing_country_code IS NULL OR
    billing_country_code ~ '^[A-Z]{2}$'),
  billing_postal_code text CHECK (billing_postal_code IS NULL OR length(billing_postal_code) <= 32),
  tax_identifier text CHECK (tax_identifier IS NULL OR length(tax_identifier) <= 64),
  -- Records a tester choosing to skip. Absolutely no payment status:
  -- no 'paid', 'active', 'approved', 'completed', or price fields.
  test_flow_state text NOT NULL DEFAULT 'preferences_only'
    CHECK (test_flow_state IN ('preferences_only', 'skipped_for_testing')),
  skipped_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT payment_test_skip_stamp_consistent CHECK (
    (test_flow_state = 'preferences_only' AND skipped_at IS NULL) OR
    (test_flow_state = 'skipped_for_testing' AND skipped_at IS NOT NULL)
  )
);

ALTER TABLE public.onboarding_payment_preferences ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.onboarding_payment_preferences
  FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE
  ON public.onboarding_payment_preferences TO authenticated;

CREATE POLICY payment_preferences_read_own
  ON public.onboarding_payment_preferences
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

CREATE POLICY payment_preferences_insert_own
  ON public.onboarding_payment_preferences
  FOR INSERT TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY payment_preferences_update_own
  ON public.onboarding_payment_preferences
  FOR UPDATE TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

-- Server enforces review hasn't become stale, including plan changes.
-- Invoker-only function, no publicly executable RPC endpoint.
CREATE FUNCTION public.onboarding_payment_preferences_validate()
RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  current_review record;
BEGIN
  IF (SELECT auth.uid()) IS NULL OR
      NEW.user_id IS DISTINCT FROM (SELECT auth.uid()) THEN
    RAISE EXCEPTION USING ERRCODE = '42501',
      MESSAGE = 'Billing preferences must belong to the signed-in applicant.';
  END IF;

  SELECT d.updated_at AS draft_updated_at,
         d.draft_status,
         s.selected_plan_id AS current_plan_id,
         c.selected_plan_id AS reviewed_plan_id,
         c.reviewed_draft_updated_at
    INTO current_review
    FROM public.onboarding_review_confirmations c
    JOIN public.school_setup_drafts d ON d.user_id = c.user_id
    JOIN public.onboarding_plan_selections s ON s.user_id = c.user_id
    JOIN public.onboarding_plan_offers p ON p.id = s.selected_plan_id
   WHERE c.user_id = NEW.user_id AND p.is_active
   FOR UPDATE OF d;

  IF NOT FOUND OR
      current_review.draft_status <> 'ready_for_review' OR
      current_review.current_plan_id IS DISTINCT FROM current_review.reviewed_plan_id OR
      current_review.draft_updated_at IS DISTINCT FROM current_review.reviewed_draft_updated_at
  THEN
    RAISE EXCEPTION USING ERRCODE = '23514',
      MESSAGE = 'Review current school information and selected plan first.';
  END IF;

  NEW.updated_at := now();
  NEW.skipped_at := CASE
    WHEN NEW.test_flow_state = 'skipped_for_testing' THEN now()
    ELSE NULL
  END;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.onboarding_payment_preferences_validate()
  FROM PUBLIC, anon, authenticated;

CREATE TRIGGER onboarding_payment_preferences_before_write
  BEFORE INSERT OR UPDATE ON public.onboarding_payment_preferences
  FOR EACH ROW
  EXECUTE FUNCTION public.onboarding_payment_preferences_validate();

NOTIFY pgrst, 'reload schema';
COMMIT;
