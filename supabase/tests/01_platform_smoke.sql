-- Safe, read-only smoke checks for the private development schema.
-- Expected after test seed: 12 platform tables; 3 demo plans; 1 example school request.
SELECT COUNT(*) AS platform_table_count
FROM information_schema.tables
WHERE table_schema='platform' AND table_type='BASE TABLE';

SELECT relname AS table_name, relrowsecurity AS rls_enabled, relforcerowsecurity AS forced_rls
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='platform' AND c.relkind='r'
ORDER BY relname;

SELECT table_name,grantee,privilege_type
FROM information_schema.table_privileges
WHERE table_schema='platform' AND grantee IN ('anon','authenticated','PUBLIC')
ORDER BY table_name,grantee,privilege_type;

SELECT p.code,p.name,p.is_test_only,COUNT(pp.id) AS prices
FROM platform.subscription_plans p
LEFT JOIN platform.plan_prices pp ON pp.plan_id=p.id
GROUP BY p.id,p.code,p.name,p.is_test_only
ORDER BY p.code;

SELECT r.school_display_name,r.status,r.requested_school_code,
       COUNT(DISTINCT c.id) AS contacts,
       COUNT(DISTINCT l.id) AS locations
FROM platform.school_onboarding_requests r
LEFT JOIN platform.school_onboarding_contacts c ON c.onboarding_request_id=r.id
LEFT JOIN platform.school_onboarding_locations l ON l.onboarding_request_id=r.id
GROUP BY r.id,r.school_display_name,r.status,r.requested_school_code;
