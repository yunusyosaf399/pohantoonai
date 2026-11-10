# Module 01 — Organization Control Panel, subscriptions and school onboarding

> **State:** [Module 01 database deployed and seeded; Flutter API still mock-only] · **Date:** 2026-11-10 · **Phase:** iterative test implementation  
> **Database:** [SQL](../../supabase/schema/01_platform_onboarding.sql), [demo seed](../../supabase/seed/01_demo_platform.sql), [smoke checks](../../supabase/tests/01_platform_smoke.sql)  
> **Flutter:** [screen](../../lib/features/organization/presentation/organization_control_panel.dart), [models](../../lib/features/organization/domain/organization_models.dart), [mock repository](../../lib/features/organization/data/mock_organization_repository.dart).

## User journey

```text
Visitor explores plans (public read API later)
  → submits school onboarding information
  → chooses plan/requests subscription
  → platform operator reviews legal/academic/operational/contact details
  → payment/trial verification via trusted server (not yet implemented)
  → approved provisioning creates School tenant in Module 02
  → School Owner invited/bound to the new school
  → campus, academic year and staff onboarding
```

School submission is NOT equivalent to successful subscription and never automatically creates a school. Real payment verification and Auth are separate protected steps. For Module 01, the UI is a **mock** that previews this workflow with synthetic data only.

## First database schema: 12 private tables

| # | Physical table in `platform` schema | Responsibility |
|---|---|---|
| 01 | `organizations` | SaaS operator legal/display identity |
| 02 | `organization_memberships` | Auth-linked operators, ownership and billing staff |
| 03 | `subscription_plans` | Versioned SaaS plan descriptors, demo-only flags |
| 04 | `plan_prices` | Currency + interval + minor-unit plan pricing |
| 05 | `subscription_plan_features` | Allowed capabilities and limits |
| 06 | `school_onboarding_requests` | School application, registration and selected plan |
| 07 | `school_onboarding_contacts` | Responsible people and communication channels |
| 08 | `school_onboarding_locations` | Country, region, city and prospective campus footprint |
| 09 | `school_onboarding_education_profiles` | Board, curriculum, languages, grades, approximate size |
| 10 | `school_onboarding_operational_profiles` | Existing systems, migration request, transport/hostel/medical/HR needs |
| 11 | `school_subscription_requests` | Pending plan requests; **no payment confirmation without verified server flow** |
| 12 | `school_onboarding_reviews` | Platform operator application decisions/history |

**Status:** Module 01 successfully deployed to the single test project `umlzqlbakfwzgadafhyy` (`pohantoonai`, YouPro School), seeded with synthetic records, and verified 12/12 RLS and zero public client table read/write privileges. Stored migrations: `platform_onboarding_foundation` and `secure_existing_rls_trigger_permissions`. Some table names expand the initial 383-table candidate catalog; reconcile names during the next catalog revision rather than silently claiming the original list is final.

## School information coverage

The first request form is intentionally short (school name, owner, email, country, city, student/campus estimates, plan). Database structure additionally supports legal name, registration number, licensing authority, school category/ownership, school phone/website, preferred timezone/currency, campuses, education board, curriculum, grades, languages, staffing and operational features. Detailed document uploads, verified owner identity, fees and bank details belong to subsequent protected steps, not a single enormous public form. Collect personal documents only when there is a legitimate requirement.

## What was deliberately implemented immediately

- Schema is private and denied to `anon` and `authenticated`, with RLS enabled and no allow policies.
- Core SQL includes unique/primary keys, school-application/plan consistency constraints and composite organization FKs; additional domain rules will come incrementally.
- Demo SQL adds one entirely fictional school, three `is_test_only` plans and `requested` (not verified) subscription state; never run on production.
- Flutter screens use no Supabase secret or local hard-coded live API credential; models and mock repository have a clean future replacement point.
- The new widget tests check default screen content and validation dialog; they have **not yet run** (Flutter SDK not present in execution environment).

## Development contracts for next module

1. **Done:** Select one Supabase development project: `pohantoonai` in YouPro School.
2. **Done:** Deploy Module 01, seed sample records and verify RLS/ACL. Also hardened existing `public.rls_auto_enable()` client function grants (documented in `supabase/schema/02_secure_existing_rls_trigger.sql`).
3. Add operator authentication and server-only plan/config provisioning access.
4. Add authenticated school application submission and view with ownership checks, audits, rate limits and input validation.
5. Implement verified subscription/authorized trial status changes before school creation.
6. Module 02 creates `app.schools` / school profile / first campus / academic year and a School Owner membership transactionally.
7. Flutter connects to these APIs **only after** the required access checks pass; leave non-integrated screens clearly marked as mock.

## Portability to another organization

The reviewed SQL and its synthetic seed remain in `supabase/`. Generate official CLI migration files from the reviewed script when CLI is configured, and keep deployment migrations identical across environments. Do not copy project-specific Auth IDs, API keys, credentials or school operational records into Git. The test project is disposable; the version-controlled SQL is the transferable artifact.

## Deployment evidence — 2026-11-10

- Target: `umlzqlbakfwzgadafhyy`, project `pohantoonai`, organization `YouPro School`, Tokyo.
- SQL migrations applied successfully: `platform_onboarding_foundation` and `secure_existing_rls_trigger_permissions`.
- Live catalog: 12 `platform` tables; all 12 RLS-enabled; no anon/authenticated table read/write privileges.
- Synthetic seed: 1 organization, 3 plans, 3 prices, 9 plan features, 1 onboarding request, 1 subscription request, and linked educational/contact/location records.
- Existing `public.rls_auto_enable()` was a `SECURITY DEFINER` DDL event-trigger function executable by clients; client grants were revoked without deleting the function. Follow-up privilege SQL is source-controlled.
- Supabase security advisor now lists only 12 INFO `rls_enabled_no_policy` notices (expected for private tables without client policies); no privileged function execute warnings after hardening.
- Flutter screen remains mock-backed; no authenticated live API exists yet.
