-- Module 03.2 — Accurate live Admissions KPIs scoped by admission RLS.
-- PostgreSQL 15+ security_invoker prevents owner-bypass of school isolation.
BEGIN;
CREATE VIEW public.school_admission_counts
  WITH (security_invoker = true)
AS
  SELECT
    school_id,
    count(*)::bigint AS total_applications,
    count(*) FILTER (WHERE status='pending')::bigint AS pending_applications,
    count(*) FILTER (WHERE status='admitted')::bigint AS admitted_students,
    count(*) FILTER (WHERE status='rejected')::bigint AS rejected_applications
  FROM public.school_admissions
  GROUP BY school_id;
REVOKE ALL ON public.school_admission_counts FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.school_admission_counts TO authenticated;
COMMENT ON VIEW public.school_admission_counts IS
  'Live per-school admissions counts. SECURITY INVOKER means underlying school_admissions RLS and enrolled MFA are enforced.';
COMMIT;