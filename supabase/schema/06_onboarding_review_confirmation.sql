-- Step 4 of 6: applicant acknowledgement before a future payment workflow.
-- An acknowledgement is neither a submitted application nor a payment.
-- No existing school setup draft or subscription record is modified.
BEGIN;

CREATE TABLE public.onboarding_review_confirmations (
  user_id uuid PRIMARY KEY
    REFERENCES public.school_setup_drafts(user_id) ON DELETE CASCADE,
  selected_plan_id uuid NOT NULL
    REFERENCES public.onboarding_plan_offers(id) ON DELETE RESTRICT,
  reviewed_draft_updated_at timestamptz NOT NULL,
  confirmed_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.onboarding_review_confirmations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.onboarding_review_confirmations
  FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE
  ON public.onboarding_review_confirmations TO authenticated;

CREATE POLICY review_confirmation_read_own
  ON public.onboarding_review_confirmations
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

CREATE POLICY review_confirmation_insert_own
  ON public.onboarding_review_confirmations
  FOR INSERT TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY review_confirmation_update_own
  ON public.onboarding_review_confirmations
  FOR UPDATE TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

-- Validate the applicant's optimistic concurrency token *at the server*,
-- not merely in Flutter. A changed draft or selected plan invalidates the
-- previously reviewed snapshot. This trigger is SECURITY INVOKER and
-- uses existing RLS-protected draft, selection and offer tables.
CREATE FUNCTION public.onboarding_review_confirmation_validate()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  current_state record;
BEGIN
  IF (SELECT auth.uid()) IS NULL
     OR NEW.user_id IS DISTINCT FROM (SELECT auth.uid()) THEN
    RAISE EXCEPTION USING ERRCODE = '42501',
      MESSAGE = 'Review confirmation requires your signed-in account.';
  END IF;

  SELECT
      d.draft_status,
      d.updated_at AS draft_updated_at,
      s.selected_plan_id AS current_plan_id
    INTO current_state
    FROM public.school_setup_drafts AS d
    JOIN public.onboarding_plan_selections AS s ON s.user_id = d.user_id
    JOIN public.onboarding_plan_offers AS p
      ON p.id = s.selected_plan_id AND p.is_active = true
   WHERE d.user_id = NEW.user_id
   FOR UPDATE OF d;

  IF NOT FOUND OR current_state.draft_status <> 'ready_for_review' THEN
    RAISE EXCEPTION USING ERRCODE = '23514',
      MESSAGE = 'School information must be ready for review.';
  END IF;

  IF NEW.selected_plan_id IS DISTINCT FROM current_state.current_plan_id THEN
    RAISE EXCEPTION USING ERRCODE = '23514',
      MESSAGE = 'Selected plan has changed. Review it again.';
  END IF;

  IF NEW.reviewed_draft_updated_at IS DISTINCT FROM
     current_state.draft_updated_at THEN
    RAISE EXCEPTION USING ERRCODE = '23514',
      MESSAGE = 'School information has changed. Review it again.';
  END IF;

  -- The server owns the confirmation timestamp, even if the client sends one.
  NEW.confirmed_at := now();
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.onboarding_review_confirmation_validate()
  FROM PUBLIC, anon, authenticated;

CREATE TRIGGER onboarding_review_confirmation_before_write
  BEFORE INSERT OR UPDATE ON public.onboarding_review_confirmations
  FOR EACH ROW
  EXECUTE FUNCTION public.onboarding_review_confirmation_validate();

NOTIFY pgrst, 'reload schema';
COMMIT;
