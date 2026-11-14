-- Module 03.8 — Only submitted/onboarding-review records appear in
-- the platform request queue, never incomplete private drafts.
BEGIN;
CREATE OR REPLACE FUNCTION public.platform_control_review_queue(
  p_limit integer DEFAULT 100,p_offset integer DEFAULT 0
)
RETURNS TABLE(
  request_id uuid,organization_id uuid,school_display_name text,
  school_legal_name text,requester_email text,plan_code text,
  plan_is_demo boolean,submitted_at timestamptz,status text,
  activation_ready boolean
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $fn$
BEGIN
  PERFORM security_private.assert_platform_control_access();
  IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100
     OR p_offset IS NULL OR p_offset NOT BETWEEN 0 AND 100000 THEN
    RAISE EXCEPTION 'Invalid pagination' USING ERRCODE='22023';
  END IF;
  RETURN QUERY
    SELECT r.id,r.organization_id,r.school_display_name,
      r.school_legal_name,r.primary_email,
      coalesce(o.code,plan.code,'Unassigned')::text,
      coalesce(o.is_demo,plan.is_test_only,false),
      r.submitted_at,r.status,
      (snap.onboarding_request_id IS NOT NULL
       AND snap.owner_user_id=r.requester_user_id
       AND snap.selected_plan_id=r.selected_plan_id
       AND o.is_active IS TRUE)
    FROM platform.school_onboarding_requests r
    LEFT JOIN platform.school_activation_snapshots snap
      ON snap.onboarding_request_id=r.id
    LEFT JOIN public.onboarding_plan_offers o
      ON o.id=snap.selected_plan_id
        AND o.organization_id=r.organization_id
    LEFT JOIN platform.subscription_plans plan
      ON plan.id=r.selected_plan_id
        AND plan.organization_id=r.organization_id
    WHERE (SELECT security_private.can_review_school_activation(r.organization_id))
      AND r.status IN (
        'submitted','in_review','more_information',
        'approved','rejected','provisioned')
      AND r.submitted_at IS NOT NULL
    ORDER BY r.submitted_at DESC,r.created_at DESC,r.id DESC
    LIMIT p_limit OFFSET p_offset;
END;
$fn$;

-- Reviewer may request information on older/unverified applications.
-- The applicant must submit a newly reviewed snapshot afterwards.

COMMIT;