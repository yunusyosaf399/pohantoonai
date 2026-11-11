-- DEV/TEST ONLY: synthetic control-panel data. Never run against a production Supabase account.
-- Requires supabase/schema/01_platform_onboarding.sql.
BEGIN;

INSERT INTO platform.organizations
  (slug,legal_name,display_name,support_email,headquarters_country_code)
VALUES
  ('pohantoonai_demo','Pohantoon AI Demo Organization','Pohantoon AI (Development)','support@example.invalid','SA')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO platform.subscription_plans
  (organization_id,code,name,summary,is_public,is_test_only,status,trial_days,sort_order)
SELECT o.id, p.code, p.name, p.summary, true, true, 'active', p.trial_days, p.sort_order
FROM platform.organizations o
CROSS JOIN (VALUES
 ('starter_demo','Starter Demo','Essential tools for a single-campus school.',14,10),
 ('growth_demo','Growth Demo','For growing schools and multiple campuses.',14,20),
 ('enterprise_demo','Enterprise Demo','For larger institutions with extensive operational needs.',30,30)
) AS p(code,name,summary,trial_days,sort_order)
WHERE o.slug='pohantoonai_demo'
ON CONFLICT (organization_id,code) DO NOTHING;

INSERT INTO platform.plan_prices
  (organization_id,plan_id,currency_code,billing_period,amount_minor,status)
SELECT o.id,p.id,'USD','monthly',0,'active'
FROM platform.organizations o
JOIN platform.subscription_plans p ON p.organization_id=o.id
WHERE o.slug='pohantoonai_demo'
  AND NOT EXISTS (
    SELECT 1 FROM platform.plan_prices pp
    WHERE pp.organization_id=o.id AND pp.plan_id=p.id
      AND pp.currency_code='USD' AND pp.billing_period='monthly'
  );

INSERT INTO platform.subscription_plan_features
  (organization_id,plan_id,feature_code,enabled,limit_value)
SELECT p.organization_id,p.id,f.feature_code,true,f.limit_value
FROM platform.subscription_plans p
JOIN platform.organizations o ON o.id=p.organization_id
JOIN LATERAL (
  VALUES ('students',CASE p.code WHEN 'starter_demo' THEN 250 WHEN 'growth_demo' THEN 1500 ELSE NULL END::bigint),
         ('campuses',CASE p.code WHEN 'starter_demo' THEN 1 WHEN 'growth_demo' THEN 5 ELSE NULL END::bigint),
         ('staff',CASE p.code WHEN 'starter_demo' THEN 30 WHEN 'growth_demo' THEN 150 ELSE NULL END::bigint)
) AS f(feature_code,limit_value) ON true
WHERE o.slug='pohantoonai_demo'
ON CONFLICT (organization_id,plan_id,feature_code) DO NOTHING;

INSERT INTO platform.school_onboarding_requests
  (organization_id,selected_plan_id,school_display_name,school_legal_name,school_type,
   primary_email,primary_phone,preferred_timezone,preferred_currency,
   requested_school_code,status,submitted_at)
SELECT o.id,p.id,'Sample Learning Academy','Sample Learning Academy (Fictional)',
       'private','school@example.invalid','+000000000000','Asia/Riyadh','SAR',
       'SAMPLE01','submitted',now()
FROM platform.organizations o
JOIN platform.subscription_plans p
  ON p.organization_id=o.id AND p.code='starter_demo'
WHERE o.slug='pohantoonai_demo'
  AND NOT EXISTS (
    SELECT 1 FROM platform.school_onboarding_requests r
    WHERE r.organization_id=o.id AND r.requested_school_code='SAMPLE01'
  );

INSERT INTO platform.school_onboarding_contacts
  (organization_id,onboarding_request_id,contact_kind,full_name,job_title,email,is_primary)
SELECT r.organization_id,r.id,'owner','Sample School Owner','School Owner',
       'owner@example.invalid',true
FROM platform.school_onboarding_requests r
WHERE r.requested_school_code='SAMPLE01'
  AND NOT EXISTS (
    SELECT 1 FROM platform.school_onboarding_contacts c
    WHERE c.onboarding_request_id=r.id AND c.contact_kind='owner'
  );

INSERT INTO platform.school_onboarding_locations
  (organization_id,onboarding_request_id,location_kind,label,country_code,region,city,estimated_campus_count)
SELECT r.organization_id,r.id,'main','Sample Campus','SA','Eastern Province','Sample City',1
FROM platform.school_onboarding_requests r
WHERE r.requested_school_code='SAMPLE01'
  AND NOT EXISTS (
    SELECT 1 FROM platform.school_onboarding_locations l
    WHERE l.onboarding_request_id=r.id AND l.location_kind='main'
  );

INSERT INTO platform.school_onboarding_education_profiles
  (organization_id,onboarding_request_id,curriculum_summary,minimum_grade_label,maximum_grade_label,
   teaching_languages,approximate_students,approximate_teachers,approximate_non_teaching_staff,daily_shifts)
SELECT r.organization_id,r.id,'General curriculum','KG','Grade 12',
       ARRAY['English'],180,15,6,1
FROM platform.school_onboarding_requests r
WHERE r.requested_school_code='SAMPLE01'
ON CONFLICT (organization_id,onboarding_request_id) DO NOTHING;

INSERT INTO platform.school_onboarding_operational_profiles
  (organization_id,onboarding_request_id,uses_existing_software,wants_data_migration,
   offers_transport,offers_hostel,has_library,has_medical_facilities,wants_payroll)
SELECT r.organization_id,r.id,false,false,true,false,true,true,true
FROM platform.school_onboarding_requests r
WHERE r.requested_school_code='SAMPLE01'
ON CONFLICT (organization_id,onboarding_request_id) DO NOTHING;

INSERT INTO platform.school_subscription_requests
  (organization_id,onboarding_request_id,plan_price_id,status)
SELECT r.organization_id,r.id,pp.id,'requested'
FROM platform.school_onboarding_requests r
JOIN platform.subscription_plans p
  ON p.organization_id=r.organization_id AND p.id=r.selected_plan_id
JOIN platform.plan_prices pp
  ON pp.organization_id=p.organization_id AND pp.plan_id=p.id AND pp.billing_period='monthly'
WHERE r.requested_school_code='SAMPLE01'
  AND NOT EXISTS (
    SELECT 1 FROM platform.school_subscription_requests sr
    WHERE sr.organization_id=r.organization_id AND sr.onboarding_request_id=r.id
  );

COMMIT;
