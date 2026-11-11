# Module 01.5 — Subscription Payment UI and Test-Only Skip (Step 5 of 6)

Date: 2026-11-11. Project: Pohantoon AI, one Supabase development project, ref umlzqlbakfwzgadafhyy. Database deployed as migration 20261111122224, secure_payment_preferences_and_test_skip. Flutter code committed, runtime compilation and real device validation still pending because GitHub Actions has an account billing/spending limit blocker.

## Business scope and design

The user supplied six light/dark responsive designs for desktop, tablet and mobile, requesting a Skip for Now action rather than active payment processing.

This iteration builds the actual Flutter screen: top branding and five-of-six progress, selected plan and order summary, monthly/annual cycle choice, Card/Bank Transfer/Wallet tabs, billing details, coupon placeholder, security/payment disclaimer, Back, Save Details, disabled Pay Now & Activate, and active Skip for Now.

Desktop has the six-step sidebar and Payment Method/Billing Details on the left with Order Summary on the right. Tablet shows vertically stacked sections with two-column billing fields when space permits. Mobile places plan summary first, then method and details. All use the existing System/Light/Dark settings.

The real selected plan comes from Step 2. Example SAR prices in the design images are NOT authorized prices and must not be displayed as real totals. Plan price, setup fee, tax and total are marked not configured. No sample PAN, card expiry, CVV or stored card UI exists. Card details can only be collected later through a processor-hosted PCI-compliant component, not custom Flutter TextFields.

Save Details persists non-sensitive billing preferences without navigating. Skip for Now persists a server-reviewed skipped_for_testing marker and goes to a Step 6 school-dashboard TEST PREVIEW. No school created, no tenant ID granted, no subscription activated, no payment charged or confirmed.

The coupon input and Pay Now button are disabled until prices, taxes, valid terms and a real provider are available. The UI explicitly states that recurring terms and payment authorization have not yet been accepted. No unsupported 256-bit-security claim is made.

## Supabase database schema

Portable source: [08_onboarding_payment_preferences.sql](../../supabase/schema/08_onboarding_payment_preferences.sql).

The new public.onboarding_payment_preferences table contains these columns:

| Column | Meaning |
|---|---|
| user_id | UUID PK/FK to own Step 4 review confirmation; no school tenant |
| billing_cycle | monthly or annual; choice only, not a billing contract |
| preferred_method | card, bank_transfer or wallet; preference only |
| billing_email | optional, up to 254 chars, validated |
| billing_school_name | optional, 220 characters |
| billing_address | optional, 500 characters |
| billing_city | optional, 120 characters |
| billing_country_code | optional ISO uppercase two-letter country |
| billing_postal_code | optional, 32 characters |
| tax_identifier | optional, 64 characters |
| test_flow_state | preferences_only or skipped_for_testing only |
| skipped_at | database-generated test skip timestamp |
| updated_at | database-generated revision timestamp |

There are NO payment tokens, real transactions, card numbers, CVVs, subscriptions, prices, coupons, captured agreement versions, or paid/active states.

### Security

RLS is enabled, with exactly three owner-only policies (authenticated SELECT/INSERT/UPDATE). There are no anon grants and no client DELETE. A SECURITY INVOKER trigger with a fixed empty search_path checks auth.uid ownership and verifies that the current Step 3 draft remains review-ready, the selected plan still matches the Step 4 review confirmation, and the saved draft timestamp is unchanged. It sets skipped_at and updated_at on the server. Any stale review blocks Skip and Save; Flutter displays an error and stays on Step 5.

The database test uses BEGIN/ROLLBACK and verified own writes, server-owned skip time, rejection of cross-user writes, invalid payment methods, malformed billing emails, and attempts to set paid. It left zero test billing preference records.

The Supabase security advisor reported no new concerns for this table. Existing notices remain for policy-free deliberately private platform tables and leaked-password protection disabled. Remediation: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

### Runtime verification

- Database migration: DEPLOYED and verified in existing pohantoonai test project.
- SQL test: PASSED; zero persisted test records.
- Flutter source: COMMITTED.
- Widget/integration test source: COMMITTED.
- Flutter analyze, compile, desktop/mobile/Web visual tests: NOT EXECUTED due remote GitHub Actions billing restriction. Verify locally before production use.

## Source navigation

- [Flutter Step 5](../../lib/features/onboarding/presentation/school_payment_preview.dart)
- [Step 6 safe preview](../../lib/features/onboarding/presentation/school_dashboard_setup_preview.dart)
- [Billing preferences model](../../lib/features/onboarding/domain/onboarding_payment_preferences.dart)
- [RLS-backed repository](../../lib/features/onboarding/data/onboarding_payment_preferences_repository.dart)
- [App navigation](../../lib/main.dart)
- [Widget tests](../../test/onboarding/school_payment_screen_test.dart)
- [Full flow tests](../../test/onboarding/plan_app_navigation_test.dart)
- [SQL security tests](../../supabase/tests/08_payment_preferences_security.sql)

## Next implementation gate

Before enabling Pay Now & Activate: approve operator school-review sequencing, add trusted plan pricing and tax jurisdiction logic, choose payment processor, use hosted card collection, create authenticated private checkout intents and idempotency keys, verify gateway webhooks and reconciliation, record refunds/disputes, and separately authorize school provisioning. Test-skip is NOT evidence of any payment or entitlement. PCI security reference: https://www.pcisecuritystandards.org/standards/pci-dss/
