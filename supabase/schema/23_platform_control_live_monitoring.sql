-- Module 03.6: real PohantoonAI platform control dashboard.
-- All data comes from existing records, never from mock repositories.
-- The operator may only monitor schools whose provisioning request belongs
-- to an ACTIVE organization with the operator's ACTIVE owner/admin membership.
-- AAL2 is mandatory for every read. No school student or guardian PII exposed.
BEGIN;

CREATE FUNCTION security_private.assert_platform_control_access()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $fn$
BEGIN
  IF (SELECT auth.uid()) IS NULL
    OR (SELECT auth.jwt()->>'aal') IS DISTINCT FROM 'aal2'
    OR NOT EXISTS (
      SELECT 1 FROM platform.organization_memberships m
      JOIN platform.organizations org ON org.id=m.organization_id
      WHERE m.auth_user_id=(SELECT auth.uid())
        AND m.operator_role IN ('owner','admin')
        AND m.status='active'
        AND org.status='active'
    )
  THEN
    RAISE EXCEPTION 'Active platform operator with completed MFA required'
      USING ERRCODE='42501';
  END IF;
END;
$fn$;
REVOKE ALL ON FUNCTION security_private.assert_platform_control_access()
FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.platform_control_overview()
RETURNS TABLE(
  total_schools bigint,active_schools bigint,suspended_schools bigint,
  pending_requests bigint,provisioned_requests bigint,rejected_requests bigint,
  school_accounts bigint,mfa_protected_accounts bigint,
  unverified_email_accounts bigint,suspended_memberships bigint,
  banned_accounts bigint,admitted_students bigint,
  submitted_requests_30d bigint,recently_signed_in_accounts_30d bigint,
  failed_security_emails_30d bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $fn$
BEGIN
  PERFORM security_private.assert_platform_control_access();
  RETURN QUERY
  WITH authorized_orgs AS (
    SELECT DISTINCT m.organization_id
    FROM platform.organization_memberships m
    JOIN platform.organizations org ON org.id=m.organization_id
    WHERE m.auth_user_id=(SELECT auth.uid())
      AND m.operator_role IN ('owner','admin')
      AND m.status='active'
      AND org.status='active'
  ),
  owned_requests AS (
    SELECT r.id,r.status,r.submitted_at
    FROM platform.school_onboarding_requests r
    JOIN authorized_orgs a ON a.organization_id=r.organization_id
  ),
  school_ids AS (
    SELECT DISTINCT l.school_id
    FROM platform.school_provisioning_links l
    JOIN owned_requests r ON r.id=l.onboarding_request_id
  ),
  scoped_schools AS (
    SELECT s.id,s.lifecycle_status
    FROM public.schools s JOIN school_ids ids ON ids.school_id=s.id
  ),
  memberships AS (
    SELECT m.school_id,m.user_id,m.membership_status
    FROM public.school_memberships m
    JOIN school_ids ids ON ids.school_id=m.school_id
  ),
  account_ids AS (
    SELECT DISTINCT user_id FROM memberships
  ),
  accounts AS (
    SELECT u.id,u.email_confirmed_at,u.confirmed_at,
      u.banned_until,u.last_sign_in_at
    FROM auth.users u JOIN account_ids a ON a.user_id=u.id
  )
  SELECT
    (SELECT count(*) FROM scoped_schools),
    (SELECT count(*) FROM scoped_schools WHERE lifecycle_status='active'),
    (SELECT count(*) FROM scoped_schools WHERE lifecycle_status='suspended'),
    (SELECT count(*) FROM owned_requests WHERE status IN ('submitted','in_review','more_information')),
    (SELECT count(*) FROM owned_requests WHERE status='provisioned'),
    (SELECT count(*) FROM owned_requests WHERE status='rejected'),
    (SELECT count(*) FROM accounts),
    (SELECT count(*) FROM accounts a WHERE EXISTS (
      SELECT 1 FROM auth.mfa_factors f
      WHERE f.user_id=a.id AND f.status='verified'
    )),
    (SELECT count(*) FROM accounts a WHERE
      a.email_confirmed_at IS NULL AND a.confirmed_at IS NULL),
    (SELECT count(*) FROM memberships WHERE membership_status IN ('suspended','revoked')),
    (SELECT count(*) FROM accounts WHERE banned_until>now()),
    (SELECT count(*) FROM public.school_admissions ad
      JOIN school_ids ids ON ids.school_id=ad.school_id
      WHERE ad.status='admitted'),
    (SELECT count(*) FROM owned_requests WHERE
      submitted_at>=now()-interval '30 days'),
    (SELECT count(*) FROM accounts WHERE
      last_sign_in_at>=now()-interval '30 days'),
    (SELECT count(*) FROM public.account_auth_email_notifications n
      JOIN account_ids ids ON ids.user_id=n.user_id
      WHERE n.created_at>=now()-interval '30 days'
        AND n.status='failed');
END;
$fn$;

CREATE FUNCTION public.platform_control_school_directory(
  p_limit integer DEFAULT 50,p_offset integer DEFAULT 0
)
RETURNS TABLE(
  school_id uuid,school_name text,organization_name text,
  lifecycle_status text,activation_basis text,created_at timestamptz,
  owner_email text,member_count bigint,admitted_count bigint,
  pending_admissions bigint
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
    SELECT s.id,s.name,org.display_name,s.lifecycle_status,
      link.activation_basis,s.created_at,owner.email::text,
      (SELECT count(*) FROM public.school_memberships m WHERE m.school_id=s.id),
      (SELECT count(*) FROM public.school_admissions ad
        WHERE ad.school_id=s.id AND ad.status='admitted'),
      (SELECT count(*) FROM public.school_admissions ad
        WHERE ad.school_id=s.id AND ad.status='pending')
    FROM platform.school_provisioning_links link
    JOIN platform.school_onboarding_requests request
      ON request.id=link.onboarding_request_id
    JOIN platform.organizations org ON org.id=request.organization_id
    JOIN public.schools s ON s.id=link.school_id
    LEFT JOIN auth.users owner ON owner.id=link.owner_user_id
    WHERE (SELECT security_private.can_review_school_activation(request.organization_id))
    ORDER BY s.created_at DESC,s.id DESC
    LIMIT p_limit OFFSET p_offset;
END;
$fn$;

CREATE FUNCTION public.platform_control_school_accounts(
  p_limit integer DEFAULT 50,p_offset integer DEFAULT 0
)
RETURNS TABLE(
  school_id uuid,school_name text,user_id uuid,account_email text,
  school_role text,membership_status text,email_verified boolean,
  mfa_enrolled boolean,account_banned boolean,last_sign_in_at timestamptz
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
    SELECT s.id,s.name,m.user_id,u.email::text,
      m.role,m.membership_status,
      (u.email_confirmed_at IS NOT NULL OR u.confirmed_at IS NOT NULL),
      EXISTS (SELECT 1 FROM auth.mfa_factors f
        WHERE f.user_id=m.user_id AND f.status='verified'),
      (u.banned_until > now()),u.last_sign_in_at
    FROM platform.school_provisioning_links link
    JOIN platform.school_onboarding_requests request
      ON request.id=link.onboarding_request_id
    JOIN public.schools s ON s.id=link.school_id
    JOIN public.school_memberships m ON m.school_id=s.id
    JOIN auth.users u ON u.id=m.user_id
    WHERE (SELECT security_private.can_review_school_activation(request.organization_id))
    ORDER BY s.name,m.created_at DESC,m.user_id
    LIMIT p_limit OFFSET p_offset;
END;
$fn$;

CREATE FUNCTION public.platform_control_monthly_trends()
RETURNS TABLE(month_start date,submitted_requests bigint,schools_provisioned bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $fn$
BEGIN
  PERFORM security_private.assert_platform_control_access();
  RETURN QUERY
    WITH months AS (
      SELECT generate_series(
        date_trunc('month',now())-interval '5 months',
        date_trunc('month',now()),interval '1 month'
      )::date AS start_month
    ),
    requests AS (
      SELECT r.id,r.submitted_at
      FROM platform.school_onboarding_requests r
      WHERE (SELECT security_private.can_review_school_activation(r.organization_id))
    ),
    links AS (
      SELECT link.provisioned_at
      FROM platform.school_provisioning_links link
      JOIN platform.school_onboarding_requests r
        ON r.id=link.onboarding_request_id
      WHERE (SELECT security_private.can_review_school_activation(r.organization_id))
    )
    SELECT months.start_month,
      (SELECT count(*) FROM requests r
        WHERE r.submitted_at>=months.start_month::timestamptz
          AND r.submitted_at<(months.start_month+interval '1 month')::timestamptz),
      (SELECT count(*) FROM links l
        WHERE l.provisioned_at>=months.start_month::timestamptz
          AND l.provisioned_at<(months.start_month+interval '1 month')::timestamptz)
    FROM months ORDER BY months.start_month;
END;
$fn$;

CREATE FUNCTION public.platform_control_review_history(p_limit integer DEFAULT 30)
RETURNS TABLE(
  review_id uuid,school_name text,decision text,
  reviewer_email text,reviewed_at timestamptz,reason text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $fn$
BEGIN
  PERFORM security_private.assert_platform_control_access();
  IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN
    RAISE EXCEPTION 'Invalid history limit' USING ERRCODE='22023';
  END IF;
  RETURN QUERY
    SELECT rv.id,req.school_display_name,rv.decision,
      reviewer.email::text,rv.created_at,rv.rationale
    FROM platform.school_onboarding_reviews rv
    JOIN platform.school_onboarding_requests req
      ON req.id=rv.onboarding_request_id
      AND req.organization_id=rv.organization_id
    LEFT JOIN auth.users reviewer ON reviewer.id=rv.reviewer_user_id
    WHERE (SELECT security_private.can_review_school_activation(rv.organization_id))
    ORDER BY rv.created_at DESC,rv.id DESC
    LIMIT p_limit;
END;
$fn$;

-- Read-only RPCs. No raw Auth secrets, session locations, or student/guardian
-- personal information leave the database.
REVOKE ALL ON FUNCTION public.platform_control_overview()
  FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.platform_control_school_directory(integer,integer)
  FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.platform_control_school_accounts(integer,integer)
  FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.platform_control_monthly_trends()
  FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.platform_control_review_history(integer)
  FROM PUBLIC,anon;

GRANT EXECUTE ON FUNCTION public.platform_control_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION public.platform_control_school_directory(integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.platform_control_school_accounts(integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.platform_control_monthly_trends() TO authenticated;
GRANT EXECUTE ON FUNCTION public.platform_control_review_history(integer) TO authenticated;
COMMIT;