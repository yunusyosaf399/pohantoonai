-- Module 02.3 — Optional MFA with server-enforced AAL2 for enrolled owners.
-- Does NOT create/store passwords, OTPs, TOTP secrets or challenges.
-- Those are managed exclusively by Supabase Auth.
--
-- Internal Auth metadata MUST NOT be granted to authenticated/anon users.
-- This tightly scoped function reveals only whether the current JWT
-- satisfies the signed-in account's own verified MFA enrollment.
BEGIN;

CREATE SCHEMA IF NOT EXISTS security_private;
REVOKE ALL ON SCHEMA security_private FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA security_private TO authenticated;

CREATE OR REPLACE FUNCTION security_private.account_mfa_satisfied()
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER SET search_path = ''
AS $function$
  SELECT
    (SELECT auth.uid()) IS NOT NULL
    AND (
      (SELECT auth.jwt()->>'aal') = 'aal2'
      OR NOT EXISTS (
        SELECT 1 FROM auth.mfa_factors f
        WHERE f.user_id = (SELECT auth.uid())
          AND f.status::text = 'verified'
      )
    );
$function$;

REVOKE ALL ON FUNCTION security_private.account_mfa_satisfied()
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION security_private.account_mfa_satisfied()
  TO authenticated;

-- Restrictive policies are ANDed with the existing owner-only policies.
-- Non-enrolled users continue normal AAL1 access. As soon as an owner
-- verifies a TOTP factor, ALL school/applicant/profile reads and writes
-- require a freshly verified AAL2 JWT, even from a direct REST client.
DO $mfa$
DECLARE target text;
BEGIN
  FOREACH target IN ARRAY ARRAY[
    'user_profiles','user_preferences',
    'school_setup_drafts','onboarding_plan_selections',
    'onboarding_review_confirmations','onboarding_payment_preferences',
    'onboarding_demo_dashboard_preferences','onboarding_dev_workspaces',
    'schools','school_memberships','school_academic_years',
    'school_dashboard_snapshots','school_dashboard_trends',
    'school_dashboard_activity'
  ] LOOP
    EXECUTE format(
      'CREATE POLICY account_2fa_guard_on_enrollment ' ||
      'ON public.%I AS RESTRICTIVE FOR ALL TO authenticated ' ||
      'USING ((SELECT security_private.account_mfa_satisfied())) ' ||
      'WITH CHECK ((SELECT security_private.account_mfa_satisfied()))',
      target);
  END LOOP;
END;
$mfa$;

-- Private school logo objects also require AAL2 after MFA enrollment,
-- without changing access to other buckets or granting table privileges.
CREATE POLICY school_logo_2fa_guard_on_enrollment
ON storage.objects AS RESTRICTIVE FOR ALL TO authenticated
USING (
  bucket_id <> 'school-logos'
  OR (SELECT security_private.account_mfa_satisfied())
)
WITH CHECK (
  bucket_id <> 'school-logos'
  OR (SELECT security_private.account_mfa_satisfied())
);

NOTIFY pgrst,'reload schema';
COMMIT;
