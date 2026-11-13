-- Module 03.4 — Trusted school activation: submit, review and provision.
-- One Supabase database; no onboarding demo step or payment skip grants a school.
-- Reuses platform.school_onboarding_requests and platform.school_onboarding_reviews.
BEGIN;

-- A frozen, service-owned copy of the fields the applicant reviewed.
-- Never provision from mutable school_setup_drafts after submission.
CREATE TABLE platform.school_activation_snapshots (
  onboarding_request_id uuid PRIMARY KEY
    REFERENCES platform.school_onboarding_requests(id) ON DELETE RESTRICT,
  owner_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  selected_plan_id uuid NOT NULL REFERENCES public.onboarding_plan_offers(id) ON DELETE RESTRICT,
  draft_updated_at timestamptz NOT NULL,
  country_code text,
  timezone text NOT NULL,
  currency_code text NOT NULL,
  logo_storage_path text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT activation_snapshot_country_check CHECK
    (country_code IS NULL OR country_code ~ '^[A-Z]{2}$')
);

-- Durable audit linkage. A platform operator must approve every real tenant.
CREATE TABLE platform.school_provisioning_links (
  onboarding_request_id uuid PRIMARY KEY
    REFERENCES platform.school_onboarding_requests(id) ON DELETE RESTRICT,
  school_id uuid NOT NULL UNIQUE REFERENCES public.schools(id) ON DELETE RESTRICT,
  owner_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  approved_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  activation_basis text NOT NULL CHECK
    (activation_basis IN ('approved_pilot','verified_subscription')),
  approval_evidence text NOT NULL CHECK
    (char_length(btrim(approval_evidence)) BETWEEN 20 AND 2000),
  provisioned_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX school_activation_snapshot_owner_idx
  ON platform.school_activation_snapshots(owner_user_id);
CREATE INDEX school_provisioning_links_owner_idx
  ON platform.school_provisioning_links(owner_user_id);

CREATE UNIQUE INDEX school_one_activation_request_per_owner_org_idx
  ON platform.school_onboarding_requests(organization_id,requester_user_id)
  WHERE requester_user_id IS NOT NULL;

ALTER TABLE platform.school_activation_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform.school_provisioning_links ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON platform.school_activation_snapshots
  FROM PUBLIC,anon,authenticated;
REVOKE ALL ON platform.school_provisioning_links
  FROM PUBLIC,anon,authenticated;
-- platform schema is not exposed through the Flutter Data API.
-- Do not grant it to authenticated or anon.

-- Only audited platform owner/admin roles of an ACTIVE organization can review.
-- Operators must have Supabase AAL2, even if their personal MFA is optional.
CREATE FUNCTION security_private.can_review_school_activation(p_org uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $fn$
  SELECT
    (SELECT auth.uid()) IS NOT NULL
    AND (SELECT auth.jwt()->>'aal')='aal2'
    AND EXISTS (
      SELECT 1
      FROM platform.organization_memberships m
      JOIN platform.organizations o ON o.id=m.organization_id
      WHERE m.organization_id=p_org
        AND m.auth_user_id=(SELECT auth.uid())
        AND m.operator_role IN ('owner','admin')
        AND m.status='active'
        AND o.status='active'
    );
$fn$;
REVOKE ALL ON FUNCTION security_private.can_review_school_activation(uuid)
  FROM PUBLIC,anon,authenticated;

-- Role lookup only reveals whether the signed-in account is itself an operator.
CREATE FUNCTION public.my_school_provisioning_role()
RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $fn$
BEGIN
  IF (SELECT auth.uid()) IS NULL THEN RETURN 'none'; END IF;
  IF EXISTS (
    SELECT 1 FROM platform.organization_memberships m
    JOIN platform.organizations o ON o.id=m.organization_id
    WHERE m.auth_user_id=(SELECT auth.uid())
      AND m.operator_role IN ('owner','admin')
      AND m.status='active'
      AND o.status='active'
  ) THEN
    IF (SELECT auth.jwt()->>'aal')='aal2' THEN RETURN 'authorized'; END IF;
    RETURN 'mfa_required';
  END IF;
  RETURN 'none';
END;
$fn$;

-- School owner requests activation. This is NEVER an approval.
-- Source snapshot is a verified, unchanged Step-4 review of their own draft.
CREATE FUNCTION public.request_school_activation()
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $fn$
DECLARE
  v_user uuid := (SELECT auth.uid());
  v_account auth.users%ROWTYPE;
  v_d public.school_setup_drafts%ROWTYPE;
  v_offer public.onboarding_plan_offers%ROWTYPE;
  v_request uuid;
  v_existing record;
  v_kind text;
BEGIN
  IF v_user IS NULL OR NOT (SELECT security_private.account_mfa_satisfied()) THEN
    RAISE EXCEPTION 'Valid signed-in account and required MFA needed'
      USING ERRCODE='42501';
  END IF;

  SELECT * INTO v_account FROM auth.users
  WHERE id=v_user AND email IS NOT NULL
    AND (email_confirmed_at IS NOT NULL OR confirmed_at IS NOT NULL);
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Verify your email before requesting activation'
      USING ERRCODE='42501';
  END IF;

  SELECT d.* INTO v_d
  FROM public.school_setup_drafts d
  JOIN public.onboarding_plan_selections s ON s.user_id=d.user_id
  JOIN public.onboarding_review_confirmations c
    ON c.user_id=d.user_id
      AND c.selected_plan_id=s.selected_plan_id
      AND c.reviewed_draft_updated_at=d.updated_at
  JOIN public.onboarding_plan_offers o ON o.id=s.selected_plan_id
  JOIN platform.organizations org ON org.id=o.organization_id
  WHERE d.user_id=v_user
    AND d.draft_status='ready_for_review'
    AND d.school_name IS NOT NULL
    AND char_length(btrim(d.school_name)) BETWEEN 2 AND 220
    AND o.is_active AND org.status='active'
  FOR SHARE OF d;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Complete and confirm the current school review first'
      USING ERRCODE='23514';
  END IF;

  SELECT o.* INTO v_offer FROM public.onboarding_plan_selections s
  JOIN public.onboarding_plan_offers o ON o.id=s.selected_plan_id
  WHERE s.user_id=v_user;

  IF EXISTS(
    SELECT 1 FROM public.school_memberships m
    WHERE m.user_id=v_user AND m.role='school_owner'
      AND m.membership_status='active'
  ) THEN
    RAISE EXCEPTION 'An existing school owner cannot resubmit this onboarding form'
      USING ERRCODE='23514';
  END IF;

  SELECT r.id,r.status INTO v_existing
  FROM platform.school_onboarding_requests r
  WHERE r.requester_user_id=v_user
    AND r.organization_id=v_offer.organization_id
  ORDER BY r.created_at DESC LIMIT 1 FOR UPDATE;
  IF FOUND THEN
    IF v_existing.status IN ('submitted','in_review','more_information') AND
      EXISTS(SELECT 1 FROM platform.school_activation_snapshots snap
        WHERE snap.onboarding_request_id=v_existing.id) THEN
      RETURN v_existing.id;
    END IF;
    RAISE EXCEPTION 'An existing activation request needs platform review'
      USING ERRCODE='23514';
  END IF;

  v_kind:=lower(coalesce(v_d.school_type,''));
  IF v_kind NOT IN ('public','private','nonprofit','international','other') THEN
    v_kind:='other';
  END IF;

  INSERT INTO platform.school_onboarding_requests (
    organization_id, requester_user_id, selected_plan_id,
    school_display_name,school_legal_name,registration_number,
    school_type,primary_email,primary_phone,website_url,year_established,
    preferred_timezone,preferred_currency,status,submitted_at
  ) VALUES (
    v_offer.organization_id,v_user,v_offer.id,
    btrim(v_d.school_name),nullif(btrim(v_d.legal_school_name),''),
    nullif(btrim(v_d.registration_license_number),''),
    v_kind,v_account.email,nullif(btrim(v_d.contact_phone),''),
    nullif(btrim(v_d.website_url),''),
    v_d.established_year,v_d.timezone,v_d.currency_code,
    'submitted',now()
  ) RETURNING id INTO v_request;

  INSERT INTO platform.school_activation_snapshots (
    onboarding_request_id,owner_user_id,selected_plan_id,
    draft_updated_at,country_code,timezone,currency_code,logo_storage_path
  ) VALUES (
    v_request,v_user,v_offer.id,v_d.updated_at,
    nullif(upper(btrim(v_d.country_code)),''),
    v_d.timezone,v_d.currency_code,v_d.logo_storage_path
  );
  RETURN v_request;
END;
$fn$;

-- Owner can see the state of their own request, never an operator-only queue.
CREATE FUNCTION public.my_school_activation_status()
RETURNS TABLE (
  request_id uuid,school_display_name text,status text,
  submitted_at timestamptz,school_id uuid,activation_basis text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $fn$
BEGIN
  IF (SELECT auth.uid()) IS NULL OR
     NOT (SELECT security_private.account_mfa_satisfied()) THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
  SELECT r.id,r.school_display_name,r.status,r.submitted_at,
    pl.school_id,pl.activation_basis
  FROM platform.school_onboarding_requests r
  JOIN platform.school_activation_snapshots snap
    ON snap.onboarding_request_id=r.id
  LEFT JOIN platform.school_provisioning_links pl
    ON pl.onboarding_request_id=r.id
  WHERE r.requester_user_id=(SELECT auth.uid())
    AND snap.owner_user_id=(SELECT auth.uid())
  ORDER BY r.created_at DESC
  LIMIT 1;
END;
$fn$;

-- Operator queue is checked BOTH for role and tenant organization.
CREATE FUNCTION public.list_school_activation_reviews()
RETURNS TABLE (
  request_id uuid,organization_id uuid,
  school_display_name text,school_legal_name text,
  requester_email text,plan_code text,plan_is_demo boolean,
  submitted_at timestamptz,status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $fn$
BEGIN
  IF (SELECT auth.uid()) IS NULL OR (SELECT auth.jwt()->>'aal') <> 'aal2' THEN
    RAISE EXCEPTION 'Platform review requires two-factor authentication'
      USING ERRCODE='42501';
  END IF;
  RETURN QUERY
  SELECT r.id,r.organization_id,r.school_display_name,
    r.school_legal_name,r.primary_email,o.code,o.is_demo,
    r.submitted_at,r.status
  FROM platform.school_onboarding_requests r
  JOIN platform.school_activation_snapshots snap
    ON snap.onboarding_request_id=r.id
  JOIN public.onboarding_plan_offers o ON o.id=snap.selected_plan_id
  WHERE (SELECT security_private.can_review_school_activation(r.organization_id))
  ORDER BY r.submitted_at DESC LIMIT 100;
END;
$fn$;

-- Requires independent, MFA-verified platform operator review.
-- Demo plan can become an explicitly approved PILOT only, never by payment skip.
-- Paid path requires a NON-DEMO plan AND an independently VERIFIED subscription.
CREATE FUNCTION public.approve_school_activation(
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
  IF v_actor IS NULL OR (SELECT auth.jwt()->>'aal') <> 'aal2' THEN
    RAISE EXCEPTION 'Operator must complete two-factor authentication'
      USING ERRCODE='42501';
  END IF;
  IF p_evidence IS NULL OR char_length(btrim(p_evidence)) NOT BETWEEN 20 AND 2000
     OR p_identity_verified IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'Record verified identity and detailed approval evidence'
      USING ERRCODE='23514';
  END IF;
  IF p_basis NOT IN ('approved_pilot','verified_subscription') THEN
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
      WHERE sub.onboarding_request_id=v_r.id
        AND sub.organization_id=v_r.organization_id
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

CREATE FUNCTION public.reject_school_activation(
  p_request_id uuid,
  p_reason text
) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $fn$
DECLARE
  v_actor uuid := (SELECT auth.uid());
  v_request platform.school_onboarding_requests%ROWTYPE;
BEGIN
  IF v_actor IS NULL OR (SELECT auth.jwt()->>'aal') <> 'aal2' THEN
    RAISE EXCEPTION 'Operator must complete two-factor authentication'
      USING ERRCODE='42501';
  END IF;
  IF p_reason IS NULL OR char_length(btrim(p_reason)) NOT BETWEEN 15 AND 2000 THEN
    RAISE EXCEPTION 'Explain the rejection reason' USING ERRCODE='23514';
  END IF;
  SELECT * INTO v_request FROM platform.school_onboarding_requests
    WHERE id=p_request_id FOR UPDATE;
  IF NOT FOUND OR NOT (SELECT security_private.can_review_school_activation(v_request.organization_id)) THEN
    RAISE EXCEPTION 'Not permitted to review this request' USING ERRCODE='42501';
  END IF;
  IF v_actor=v_request.requester_user_id THEN
    RAISE EXCEPTION 'Self-review is not permitted' USING ERRCODE='42501';
  END IF;
  IF v_request.status NOT IN ('submitted','in_review') OR NOT EXISTS (
      SELECT 1 FROM platform.school_activation_snapshots
        WHERE onboarding_request_id=p_request_id) THEN
    RAISE EXCEPTION 'Not a pending activation request' USING ERRCODE='23514';
  END IF;
  INSERT INTO platform.school_onboarding_reviews
    (organization_id,onboarding_request_id,reviewer_user_id,decision,rationale)
  VALUES (v_request.organization_id,v_request.id,v_actor,'reject',btrim(p_reason));
  UPDATE platform.school_onboarding_requests
  SET status='rejected',reviewed_at=now(),updated_at=now()
  WHERE id=p_request_id;
  RETURN true;
END;
$fn$;

-- Definer RPCs are explicitly limited to Auth users, and every method
-- derives identities from signed JWT claims plus DB-owned operator grants.
REVOKE ALL ON FUNCTION public.my_school_provisioning_role() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.request_school_activation() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.my_school_activation_status() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.list_school_activation_reviews() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.approve_school_activation(uuid,text,text,boolean) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.reject_school_activation(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.my_school_provisioning_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_school_activation() TO authenticated;
GRANT EXECUTE ON FUNCTION public.my_school_activation_status() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_school_activation_reviews() TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_school_activation(uuid,text,text,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_school_activation(uuid,text) TO authenticated;
COMMIT;
