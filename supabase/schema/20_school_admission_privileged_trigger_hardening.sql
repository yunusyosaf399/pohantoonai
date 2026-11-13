-- Module 03.3 — Admission audit trigger isolation and foreign-key indexes.
-- Move elevated trigger outside public Data API namespace.
BEGIN;
ALTER FUNCTION public.school_admission_activity()
  SET SCHEMA security_private;
REVOKE ALL ON FUNCTION security_private.school_admission_activity()
  FROM PUBLIC,anon,authenticated;
CREATE INDEX school_admissions_year_fk_idx
  ON public.school_admissions(school_id,academic_year_id);
CREATE INDEX school_admissions_created_by_fk_idx
  ON public.school_admissions(created_by);
CREATE INDEX school_admissions_updated_by_fk_idx
  ON public.school_admissions(updated_by);
COMMIT;