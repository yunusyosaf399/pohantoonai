-- Module 01.3 — Step 3 school-setup draft (development project)
-- Portable schema. Applicants may save incomplete drafts; "ready_for_review"
-- requires required fields and selected-plan capacity checks.
-- No school, subscription, payment or organization membership is created.
BEGIN;

CREATE TABLE public.school_setup_drafts (
  user_id uuid PRIMARY KEY
    REFERENCES public.onboarding_plan_selections(user_id) ON DELETE CASCADE,

  school_name text,
  legal_school_name text,
  school_type text,
  registration_license_number text,
  established_year integer,
  website_url text,

  contact_name text,
  contact_position text,
  contact_email text,
  contact_phone text,

  country_code text,
  region text,
  city text,
  street_address text,
  timezone text NOT NULL DEFAULT 'UTC',
  currency_code text NOT NULL DEFAULT 'USD',

  estimated_students integer,
  campus_count integer,
  estimated_teachers integer,
  estimated_non_teaching_staff integer,
  education_board text,
  curriculum text,
  lowest_grade text,
  highest_grade text,
  teaching_languages text[] NOT NULL DEFAULT ARRAY[]::text[],

  draft_status text NOT NULL DEFAULT 'draft',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT school_setup_status_check
    CHECK (draft_status IN ('draft', 'ready_for_review')),
  CONSTRAINT school_setup_school_type_check
    CHECK (school_type IS NULL OR school_type IN
      ('public','private','nonprofit','international','other')),
  CONSTRAINT school_setup_country_code_check
    CHECK (country_code IS NULL OR country_code ~ '^[A-Z]{2}$'),
  CONSTRAINT school_setup_currency_check
    CHECK (currency_code ~ '^[A-Z]{3}$'),
  CONSTRAINT school_setup_year_check
    CHECK (established_year IS NULL OR established_year BETWEEN 1700 AND 2200),
  CONSTRAINT school_setup_student_count_check
    CHECK (estimated_students IS NULL OR estimated_students > 0),
  CONSTRAINT school_setup_campus_count_check
    CHECK (campus_count IS NULL OR campus_count >= 1),
  CONSTRAINT school_setup_teacher_count_check
    CHECK (estimated_teachers IS NULL OR estimated_teachers >= 0),
  CONSTRAINT school_setup_staff_count_check
    CHECK (estimated_non_teaching_staff IS NULL OR estimated_non_teaching_staff >= 0),
  CONSTRAINT school_setup_email_check
    CHECK (contact_email IS NULL OR
      (length(contact_email) <= 254 AND
       contact_email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$')),
  CONSTRAINT school_setup_url_check
    CHECK (website_url IS NULL OR
      (length(website_url) <= 500 AND website_url ~* '^https://[^[:space:]]+$')),
  CONSTRAINT school_setup_languages_check
    CHECK (cardinality(teaching_languages) <= 15 AND
      length(array_to_string(teaching_languages,',')) <= 750),
  CONSTRAINT school_setup_field_lengths_check
    CHECK (
      length(coalesce(school_name,'')) <= 180 AND
      length(coalesce(legal_school_name,'')) <= 220 AND
      length(coalesce(registration_license_number,'')) <= 120 AND
      length(coalesce(contact_name,'')) <= 140 AND
      length(coalesce(contact_position,'')) <= 100 AND
      length(coalesce(contact_phone,'')) <= 40 AND
      length(coalesce(region,'')) <= 120 AND
      length(coalesce(city,'')) <= 120 AND
      length(coalesce(street_address,'')) <= 500 AND
      length(coalesce(education_board,'')) <= 160 AND
      length(coalesce(curriculum,'')) <= 160 AND
      length(coalesce(lowest_grade,'')) <= 50 AND
      length(coalesce(highest_grade,'')) <= 50 AND
      length(timezone) <= 100
    ),
  CONSTRAINT school_setup_required_for_review_check
    CHECK (draft_status <> 'ready_for_review' OR
      (nullif(btrim(coalesce(school_name,'')),'') IS NOT NULL
        AND school_type IS NOT NULL
        AND nullif(btrim(coalesce(contact_name,'')),'') IS NOT NULL
        AND nullif(btrim(coalesce(contact_email,'')),'') IS NOT NULL
        AND country_code IS NOT NULL
        AND nullif(btrim(coalesce(city,'')),'') IS NOT NULL
        AND estimated_students IS NOT NULL
        AND campus_count IS NOT NULL))
);

CREATE INDEX school_setup_review_status_idx
  ON public.school_setup_drafts(draft_status, updated_at DESC);

-- Trigger runs with the requesting user's privileges, never SECURITY DEFINER.
-- Validates the selected plan using only the RLS-visible catalog and choice.
CREATE FUNCTION public.school_setup_draft_validate()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  offer record;
BEGIN
  NEW.updated_at := now();
  IF TG_OP = 'INSERT' THEN
    NEW.created_at := now();
  ELSE
    NEW.created_at := OLD.created_at;
  END IF;

  IF NEW.draft_status = 'ready_for_review' THEN
    SELECT o.student_limit, o.campus_limit, o.staff_limit
      INTO offer
      FROM public.onboarding_plan_selections s
      JOIN public.onboarding_plan_offers o ON o.id = s.selected_plan_id
      WHERE s.user_id = NEW.user_id AND o.is_active = true;

    IF NOT FOUND THEN
      RAISE EXCEPTION USING ERRCODE = '23514',
        MESSAGE = 'Selected plan is unavailable. Please choose a plan again.';
    END IF;
    IF offer.student_limit IS NOT NULL
      AND NEW.estimated_students > offer.student_limit THEN
      RAISE EXCEPTION USING ERRCODE = '23514',
        MESSAGE = 'Student estimate exceeds your selected plan.';
    END IF;
    IF offer.campus_limit IS NOT NULL
      AND NEW.campus_count > offer.campus_limit THEN
      RAISE EXCEPTION USING ERRCODE = '23514',
        MESSAGE = 'Campus estimate exceeds your selected plan.';
    END IF;
    IF offer.staff_limit IS NOT NULL AND
       (coalesce(NEW.estimated_teachers,0)
        + coalesce(NEW.estimated_non_teaching_staff,0)) >
       offer.staff_limit THEN
      RAISE EXCEPTION USING ERRCODE = '23514',
        MESSAGE = 'Total staff estimate exceeds your selected plan.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.school_setup_draft_validate()
  FROM PUBLIC, anon, authenticated;

CREATE TRIGGER school_setup_draft_validate_before_write
  BEFORE INSERT OR UPDATE ON public.school_setup_drafts
  FOR EACH ROW EXECUTE FUNCTION public.school_setup_draft_validate();

-- When the applicant switches plans, reset the review-ready marker.
-- Their saved identity/contact information is retained; later review must
-- be re-validated against the new plan.
CREATE FUNCTION public.school_setup_draft_reset_on_plan_change()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path = ''
AS $$
BEGIN
  IF NEW.selected_plan_id IS DISTINCT FROM OLD.selected_plan_id THEN
    UPDATE public.school_setup_drafts
       SET draft_status = 'draft'
     WHERE user_id = NEW.user_id
       AND draft_status = 'ready_for_review';
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.school_setup_draft_reset_on_plan_change()
  FROM PUBLIC, anon, authenticated;

CREATE TRIGGER school_setup_reset_after_plan_change
  AFTER UPDATE OF selected_plan_id ON public.onboarding_plan_selections
  FOR EACH ROW EXECUTE FUNCTION
    public.school_setup_draft_reset_on_plan_change();

ALTER TABLE public.school_setup_drafts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.school_setup_drafts FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.school_setup_drafts TO authenticated;

CREATE POLICY school_setup_read_own ON public.school_setup_drafts
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

CREATE POLICY school_setup_insert_own ON public.school_setup_drafts
  FOR INSERT TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY school_setup_update_own ON public.school_setup_drafts
  FOR UPDATE TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

NOTIFY pgrst, 'reload schema';
COMMIT;
