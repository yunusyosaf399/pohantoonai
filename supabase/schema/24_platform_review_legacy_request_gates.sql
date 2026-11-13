-- Module 03.7 — Include pre-verification requests in the platform review
-- queue, but never silently provision one without a server-owned snapshot.
BEGIN;
CREATE FUNCTION public.platform_control_review_queue(
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
    ORDER BY r.submitted_at DESC NULLS LAST,r.created_at DESC,r.id DESC
    LIMIT p_limit OFFSET p_offset;
END;
$fn$;

-- Reviewer may request information on older/unverified applications.
-- The applicant must submit a newly reviewed snapshot afterwards.
CREATE FUNCTION public.request_school_activation_information(
  p_request_id uuid,p_reason text
)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $fn$
DECLARE
 v_actor uuid := (SELECT auth.uid());
 v_request platform.school_onboarding_requests%ROWTYPE;
BEGIN
  PERFORM security_private.assert_platform_control_access();
  IF p_reason IS NULL OR
     char_length(btrim(p_reason)) NOT BETWEEN 20 AND 2000 THEN
    RAISE EXCEPTION 'Explain the information required (20–2000 characters)'
      USING ERRCODE='22023';
  END IF;

  SELECT * INTO v_request
  FROM platform.school_onboarding_requests
  WHERE id=p_request_id FOR UPDATE;
  IF NOT FOUND OR NOT (SELECT security_private.can_review_school_activation(v_request.organization_id)) THEN
    RAISE EXCEPTION 'Request is outside your authorized organization'
      USING ERRCODE='42501';
  END IF;
  IF v_actor=v_request.requester_user_id THEN
    RAISE EXCEPTION 'An applicant cannot review their own request'
      USING ERRCODE='42501';
  END IF;
  IF v_request.status NOT IN ('submitted','in_review') THEN
    RAISE EXCEPTION 'Only pending applications can request additional information'
      USING ERRCODE='23514';
  END IF;

  INSERT INTO platform.school_onboarding_reviews(
    organization_id,onboarding_request_id,reviewer_user_id,
    decision,rationale
  ) VALUES (
    v_request.organization_id,p_request_id,v_actor,
    'request_information',btrim(p_reason)
  );
  UPDATE platform.school_onboarding_requests
    SET status='more_information',updated_at=now(),reviewed_at=now()
    WHERE id=p_request_id;
  RETURN true;
END;
$fn$;
REVOKE ALL ON FUNCTION public.platform_control_review_queue(integer,integer)
FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.request_school_activation_information(uuid,text)
FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.platform_control_review_queue(integer,integer)
TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_school_activation_information(uuid,text)
TO authenticated;
COMMIT;