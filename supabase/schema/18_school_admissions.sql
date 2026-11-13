-- Module 03.1 — School-scoped real Admissions.
-- Global Supabase project, school_id is the ONLY tenant boundary.
-- Authenticated school owners/admins of ACTIVE schools can manage applications.
-- No demo/onboarding account grants itself a school ID or membership.
BEGIN;

CREATE TABLE public.school_admissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE RESTRICT,
  academic_year_id uuid,
  student_first_name text NOT NULL CHECK (char_length(btrim(student_first_name)) BETWEEN 2 AND 100),
  student_last_name text NOT NULL CHECK (char_length(btrim(student_last_name)) BETWEEN 1 AND 100),
  date_of_birth date,
  grade_applied text NOT NULL CHECK (char_length(btrim(grade_applied)) BETWEEN 1 AND 40),
  guardian_full_name text NOT NULL CHECK (char_length(btrim(guardian_full_name)) BETWEEN 2 AND 150),
  guardian_phone text NOT NULL CHECK (
    char_length(btrim(guardian_phone)) BETWEEN 7 AND 30
    AND guardian_phone ~ '^[+0-9 ()-]+$'
  ),
  guardian_email text CHECK (guardian_email IS NULL OR
    (char_length(guardian_email) <= 254
      AND guardian_email ~* '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$')),
  notes text CHECK (notes IS NULL OR char_length(notes) <= 1000),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'admitted', 'rejected')),
  created_by uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE RESTRICT,
  updated_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT admissions_year_in_same_school FOREIGN KEY (school_id, academic_year_id)
    REFERENCES public.school_academic_years(school_id, id) ON DELETE RESTRICT
);

CREATE INDEX school_admissions_school_status_created_idx
  ON public.school_admissions(school_id, status, created_at DESC);
CREATE INDEX school_admissions_school_created_idx
  ON public.school_admissions(school_id, created_at DESC);

-- Permanent server-generated, immutable ownership. Never accept client
-- attempts to move students between schools or change the author.
CREATE FUNCTION public.school_admission_before_write()
RETURNS trigger LANGUAGE plpgsql
SET search_path = ''
AS $fn$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.id IS DISTINCT FROM OLD.id OR
       NEW.school_id IS DISTINCT FROM OLD.school_id OR
       NEW.created_by IS DISTINCT FROM OLD.created_by OR
       NEW.created_at IS DISTINCT FROM OLD.created_at THEN
      RAISE EXCEPTION 'Admission identity and school cannot be changed'
        USING ERRCODE = '42501';
    END IF;
    -- Final decisions cannot be silently reversed or overwritten.
    IF OLD.status <> 'pending' THEN
      RAISE EXCEPTION 'Final admission decisions cannot be modified'
        USING ERRCODE = '23514';
    END IF;
    NEW.updated_by := auth.uid();
    NEW.updated_at := now();
  ELSE
    -- Initial entry is always pending, never admitted by bypassing review.
    IF NEW.status <> 'pending' THEN
      RAISE EXCEPTION 'New admissions must be pending' USING ERRCODE = '23514';
    END IF;
    IF NEW.created_by IS DISTINCT FROM auth.uid() THEN
      RAISE EXCEPTION 'Admission author must be the signed-in user'
        USING ERRCODE = '42501';
    END IF;
    NEW.updated_by := auth.uid();
    NEW.created_at := now();
    NEW.updated_at := now();
  END IF;
  IF NEW.date_of_birth IS NOT NULL AND
     NEW.date_of_birth > (now() AT TIME ZONE 'UTC')::date THEN
    RAISE EXCEPTION 'Date of birth cannot be in the future'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$fn$;
CREATE TRIGGER school_admission_validate_write
  BEFORE INSERT OR UPDATE ON public.school_admissions
  FOR EACH ROW EXECUTE FUNCTION public.school_admission_before_write();

-- Log status transitions in existing school dashboard activity.
-- Only server-side trigger may populate that table; clients cannot forge events.
CREATE FUNCTION public.school_admission_activity()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $fn$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.school_dashboard_activity
      (school_id,event_type,subject_display_name,event_summary,workflow_status,resource_type,resource_id)
    VALUES
      (NEW.school_id,'admission',
        NEW.student_first_name || ' ' || NEW.student_last_name,
        'Admission application received', 'pending', 'school_admission', NEW.id);
  ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
    INSERT INTO public.school_dashboard_activity
      (school_id,event_type,subject_display_name,event_summary,workflow_status,resource_type,resource_id)
    VALUES
      (NEW.school_id,
        CASE WHEN NEW.status='admitted' THEN 'application_approved' ELSE 'application_rejected' END,
        NEW.student_first_name || ' ' || NEW.student_last_name,
        CASE WHEN NEW.status='admitted' THEN 'Admission approved' ELSE 'Admission rejected' END,
        CASE WHEN NEW.status='admitted' THEN 'approved' ELSE 'rejected' END,
        'school_admission',NEW.id);
  END IF;
  RETURN NEW;
END;
$fn$;
CREATE TRIGGER school_admission_create_activity
  AFTER INSERT OR UPDATE OF status ON public.school_admissions
  FOR EACH ROW EXECUTE FUNCTION public.school_admission_activity();

REVOKE ALL ON FUNCTION public.school_admission_before_write() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.school_admission_activity() FROM PUBLIC,anon,authenticated;

ALTER TABLE public.school_admissions ENABLE ROW LEVEL SECURITY;
-- The MFA guard MUST be restrictive: a permissive policy would OR with
-- ownership policies and accidentally bypass enrolled 2FA.
CREATE POLICY admission_mfa_required ON public.school_admissions
  AS RESTRICTIVE FOR ALL TO authenticated
  USING ((SELECT security_private.account_mfa_satisfied()))
  WITH CHECK ((SELECT security_private.account_mfa_satisfied()));

-- Membership is granted by trusted provisioning only; no client may create
-- schools, memberships, or transfer a row to an arbitrary school_id.
CREATE POLICY admission_admin_read ON public.school_admissions
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.school_memberships m
    JOIN public.schools s ON s.id = m.school_id
    WHERE m.school_id = school_admissions.school_id
      AND m.user_id = (SELECT auth.uid())
      AND m.membership_status='active'
      AND m.role IN ('school_owner','school_admin')
      AND s.lifecycle_status='active'
  ));

CREATE POLICY admission_admin_insert ON public.school_admissions
  FOR INSERT TO authenticated
  WITH CHECK (
    created_by = (SELECT auth.uid())
    AND status='pending'
    AND EXISTS (
      SELECT 1 FROM public.school_memberships m
      JOIN public.schools s ON s.id = m.school_id
      WHERE m.school_id = school_admissions.school_id
        AND m.user_id=(SELECT auth.uid())
        AND m.membership_status='active'
        AND m.role IN ('school_owner','school_admin')
        AND s.lifecycle_status='active'
    )
  );

CREATE POLICY admission_admin_update ON public.school_admissions
  FOR UPDATE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.school_memberships m
    JOIN public.schools s ON s.id=m.school_id
    WHERE m.school_id=school_admissions.school_id
      AND m.user_id=(SELECT auth.uid())
      AND m.membership_status='active'
      AND m.role IN ('school_owner','school_admin')
      AND s.lifecycle_status='active'
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.school_memberships m
    JOIN public.schools s ON s.id=m.school_id
    WHERE m.school_id=school_admissions.school_id
      AND m.user_id=(SELECT auth.uid())
      AND m.membership_status='active'
      AND m.role IN ('school_owner','school_admin')
      AND s.lifecycle_status='active'
  ));

REVOKE ALL ON public.school_admissions FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE ON public.school_admissions TO authenticated;
GRANT ALL ON public.school_admissions TO service_role;
-- No DELETE grant or DELETE policy: student/admission data is retained for audit.
COMMENT ON TABLE public.school_admissions IS
  'Real school-scoped admission records. Student/guardian PII, active owner/admin only, mandatory enrolled MFA, no demo access, no client DELETE.';

COMMIT;