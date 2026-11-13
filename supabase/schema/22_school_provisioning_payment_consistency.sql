-- Module 03.5 — Paid entitlement must match reviewed plan and active price.
-- Applies after Module 03.4; accepted SECURITY DEFINER RPC is deliberately
-- callable only by signed-in users and checks AAL2 + audited operator role.
BEGIN;
CREATE OR REPLACE FUNCTION public.approve_school_activation(
  p_request_id uuid,
  p_basis text,
  p_evidence text,
  p_identity_verified boolean DEFAULT false
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $fn$
DECLARE
  v_actor uuid := (SELECT auth.uid());
  v_r platform.school_onboarding_requests%ROWTYPE;
  v_snap platform.school_activation_snapshots%ROWTYPE;
  v_offer public.onboarding_plan_offers%ROWTYPE;
  v_existing uuid;
  v_school uuid;
  v_slug text;
BEGIN
  IF v_actor IS NULL OR (SELECT auth.jwt()->>'aal') IS DISTINCT FROM 'aal2' THEN
    RAISE EXCEPTION 'Operator must complete two-factor authentication'
      USING ERRCODE='42501';
  END IF;
  IF p_evidence IS NULL OR char_length(btrim(p_evidence)) NOT BETWEEN 20 AND 2000
     OR p_identity_verified IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'Record verified identity and detailed approval evidence'
      USING ERRCODE='23514';
  END IF;
  IF p_basis IS NULL OR p_basis NOT IN ('approved_pilot','verified_subscription') THEN
    RAISE EXCEPTION 'Unknown approval basis' USING ERRCODE='23514';
  END IF;

  SELECT * INTO v_r FROM platform.school_onboarding_requests
    WHERE id=p_request_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'School request not found' USING ERRCODE='42501'; END IF;
  IF NOT (SELECT security_private.can_review_school_activation(v_r.organization_id)) THEN
    RAISE EXCEPTION 'Not permitted to approve this organization'
      USING ERRCODE='42501';
  END IF;
  IF v_actor=v_r.requester_user_id THEN
    RAISE EXCEPTION 'Review requires a different authorized operator'
      USING ERRCODE='42501';
  END IF;

  SELECT * INTO v_snap FROM platform.school_activation_snapshots
    WHERE onboarding_request_id=p_request_id;
  IF NOT FOUND OR v_snap.owner_user_id IS DISTINCT FROM v_r.requester_user_id
    OR v_snap.selected_plan_id IS DISTINCT FROM v_r.selected_plan_id THEN
    RAISE EXCEPTION 'Request has no verified applicant snapshot'
      USING ERRCODE='23514';
  END IF;

  SELECT pl.school_id INTO v_existing FROM platform.school_provisioning_links pl
    WHERE pl.onboarding_request_id=p_request_id;
  IF FOUND THEN RETURN v_existing; END IF;
  IF v_r.status NOT IN ('submitted','in_review') THEN
    RAISE EXCEPTION 'Only submitted or in-review applications can be approved'
      USING ERRCODE='23514';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id=v_r.requester_user_id
      AND u.email IS NOT NULL
      AND (u.email_confirmed_at IS NOT NULL OR u.confirmed_at IS NOT NULL)
  ) THEN
    RAISE EXCEPTION 'Applicant email is not verified' USING ERRCODE='23514';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.school_memberships m
    WHERE m.user_id=v_r.requester_user_id AND m.role='school_owner'
      AND m.membership_status='active'
  ) THEN
    RAISE EXCEPTION 'Applicant already owns an active school'
      USING ERRCODE='23514';
  END IF;

  SELECT * INTO v_offer FROM public.onboarding_plan_offers
    WHERE id=v_snap.selected_plan_id AND organization_id=v_r.organization_id;
  IF NOT FOUND OR NOT v_offer.is_active THEN
    RAISE EXCEPTION 'Selected subscription plan is unavailable'
      USING ERRCODE='23514';
  END IF;

  IF p_basis='approved_pilot' THEN
    IF NOT v_offer.is_demo THEN
      RAISE EXCEPTION 'Pilot approvals require a test-only plan'
        USING ERRCODE='23514';
    END IF;
  ELSE
    IF v_offer.is_demo OR NOT EXISTS (
      SELECT 1 FROM platform.school_subscription_requests sub
      JOIN platform.plan_prices price
        ON price.id=sub.plan_price_id
        AND price.organization_id=sub.organization_id
      WHERE sub.onboarding_request_id=v_r.id
        AND sub.organization_id=v_r.organization_id
        AND price.plan_id=v_snap.selected_plan_id
        AND price.status='active'
        AND sub.status='verified' AND sub.verified_at IS NOT NULL
    ) THEN
      RAISE EXCEPTION 'A verified, non-demo subscription is required'
        USING ERRCODE='23514';
    END IF;
  END IF;

  v_school:=gen_random_uuid();
  v_slug:='school-'||left(replace(v_school::text,'-',''),24);
  INSERT INTO public.schools (
    id,slug,name,legal_name,country_code,timezone,currency_code,
    lifecycle_status
  ) VALUES (
    v_school,v_slug,v_r.school_display_name,
    v_r.school_legal_name,v_snap.country_code,
    v_snap.timezone,v_snap.currency_code,'active'
  );

  INSERT INTO public.school_memberships
    (school_id,user_id,role,membership_status)
  VALUES (v_school,v_r.requester_user_id,'school_owner','active');

  INSERT INTO platform.school_provisioning_links (
    onboarding_request_id,school_id,owner_user_id,approved_by,
    activation_basis,approval_evidence
  ) VALUES (
    v_r.id,v_school,v_r.requester_user_id,v_actor,p_basis,btrim(p_evidence)
  );

  INSERT INTO platform.school_onboarding_reviews
    (organization_id,onboarding_request_id,reviewer_user_id,decision,rationale)
  VALUES (v_r.organization_id,v_r.id,v_actor,'approve',btrim(p_evidence));

  UPDATE platform.school_onboarding_requests
  SET status='provisioned',reviewed_at=now(),updated_at=now()
  WHERE id=v_r.id;
  RETURN v_school;
END;
$fn$;


CREATE INDEX school_activation_snapshots_plan_fk_idx
  ON platform.school_activation_snapshots(selected_plan_id);
CREATE INDEX school_provisioning_links_reviewer_fk_idx
  ON platform.school_provisioning_links(approved_by);
COMMIT;