-- Development seed patch for the screenshot-matched Step 2 descriptions.
-- Operates ONLY on the synthetic pohantoonai_demo organization.
-- Not needed for real production subscription catalog.
BEGIN;
UPDATE platform.subscription_plans AS plans
SET summary = CASE plans.code
  WHEN 'starter_demo' THEN 'Essential tools for a single-campus school.'
  WHEN 'growth_demo' THEN 'For growing schools and multiple campuses.'
  WHEN 'enterprise_demo' THEN 'For larger institutions with extensive operational needs.'
  ELSE plans.summary
END
FROM platform.organizations AS org
WHERE org.id = plans.organization_id
  AND org.slug = 'pohantoonai_demo'
  AND plans.code IN ('starter_demo', 'growth_demo', 'enterprise_demo')
  AND plans.is_test_only = true;
-- Automatically mirrored to public.onboarding_plan_offers by the secure
-- source-of-truth triggers from schema/04_onboarding_plan_selection.sql.
COMMIT;
