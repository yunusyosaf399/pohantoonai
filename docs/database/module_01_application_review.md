# Module 01.4 — Application Review and Go to Payment (Step 4 of 6)

> **Implemented on GitHub:** 2026-11-11. **Database deployed** to the existing `pohantoonai` Supabase development project (`umlzqlbakfwzgadafhyy`), migration `20261111115622` (`secure_review_confirmation_for_payment_handoff`).  
> **Runtime UI verification:** pending Windows/Android/iOS/Web Flutter build and widget tests; GitHub Actions runner is blocked by the account billing/spending restriction.  
> **Billing state:** no payment provider, charge, verified trial activation or school tenant creation exists at this stage.

## Requirement and actual flow

The user supplied six reference layouts for Step 4 in light/dark desktop/tablet/mobile sizes. The requested change is **replace “Submit Application” with “Go to Payment”**. This is implemented in the real sign-in flow, not a disconnected mock screen.

```text
Step 1: Authenticate → Step 2: choose plan
 → Step 3: school setup and Save Draft / Continue to Review
 → Step 4: review four saved sections + selected plan
      → Edit section: reopen Step 3 at requested card, preserve draft
      → Check "information is accurate" acknowledgement
      → Go to Payment: validate current plan and draft snapshot in DB
 → Step 5: Payment stage preview (no card input/charge)
```

**Important business decision:** Going to payment is *not* the same as submitting an application for operator approval. A review acknowledgement is not a financial authorization or legal contract. Do not provision a school or mark a subscription paid merely because the user reaches Step 5.

## Responsive Flutter screen

[Screen](../../lib/features/onboarding/presentation/school_review_preview.dart) uses the app's existing Light/Dark/System theme (no separate theme controller). It is responsive rather than hardcoding devices:

- **Desktop (>=1024 px):** left Pohantoon AI registration sidebar with steps 1–6; main review area with progress 4/6, header, banner and info cards; wider workspaces show the selected-plan card to the right.
- **Tablet/intermediate:** no forced full-width desktop sidebar, two-column school cards where space permits.
- **Phone:** one-column school cards, account/theme header, progress, confirmation and adaptive Back / Go to Payment actions. 320px-wide footer stacks actions.
- **Review cards:** School Identity, Owner & Contact Information, School Location (including optional postal code), Academic & Capacity. Values come from the actual Step 3 saved draft and signed-in account, never sample Horizon International School data. Missing optional values show an em dash.
- **Edit controls:** all four cards provide distinct, working Edit callbacks that reopen Step 3 and scroll to the corresponding form section. Unsaved or changed values require a fresh save and review.
- **Selected Plan:** sourced from the actual Step 2 offer model, including student/campus/staff caps, trial length and demo status.
- **Accuracy checkbox:** initially unchecked; disables Go to Payment until explicitly checked.
- **Error behavior:** database errors or stale review revision keep the user on Step 4 and show an actionable error without printing tokens or private SQL details.
- **Step 5 handoff:** [Payment preview](../../lib/features/onboarding/presentation/school_payment_preview.dart) clearly states that pricing/provider and transaction execution are not yet configured. Back returns to review. **No credit card fields, charge, or financial transaction are implemented**.

## Database schema

[Portable SQL](../../supabase/schema/06_onboarding_review_confirmation.sql) creates **one new table**:

| Column | Type | Purpose |
|---|---|---|
| `user_id` | UUID PK/FK to `school_setup_drafts.user_id` | Applicant owner; no school tenant yet |
| `selected_plan_id` | UUID FK to `onboarding_plan_offers.id` | Plan the applicant reviewed |
| `reviewed_draft_updated_at` | TIMESTAMPTZ | Revision token from the currently saved Step 3 form |
| `confirmed_at` | TIMESTAMPTZ | Database-generated timestamp when applicant acknowledges accuracy |

`public.onboarding_review_confirmations` has RLS enabled and **three own-row policies** for authenticated `SELECT/INSERT/UPDATE`; `anon` has no table grants and neither role gets `DELETE`.

A `SECURITY INVOKER` trigger with empty `search_path` and revoked direct EXECUTE enforces all of the following in the same transaction:

1. The active Auth identity matches `NEW.user_id`.
2. The user's `school_setup_drafts` record is `ready_for_review`.
3. The current saved plan is still published/active and matches the plan acknowledged.
4. The exact draft revision token matches the current database `updated_at`; stale screenshots cannot be acknowledged.
5. The server overwrites `confirmed_at` with its own timestamp.

These checks are performed **in PostgreSQL**, independent of Flutter. Future payment intent creation must additionally verify that the confirmation still matches the current draft, current plan and subscription price; this confirmation table alone must never authorize a charge.

## Testing and operational evidence

- [x] Database migration applied to existing one-project development environment.
- [x] `onboarding_review_confirmations` RLS enabled, 3 owner-only policies, authenticated-only table grants verified.
- [x] [Transactional SQL security test](../../supabase/tests/06_review_confirmation_security.sql) passed: own confirmation accepted, stale draft timestamp rejected, mismatched plan rejected, forged user rejected.
- [x] All SQL test writes rolled back: zero review confirmations remained; existing two user school drafts untouched.
- [x] Supabase Security Advisor: no new exposed-table security findings; earlier notices remain for 12 deliberately private `platform` tables and disabled leaked-password protection. [Password protection remediation](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).
- [x] [Step 4 widget tests](../../test/onboarding/school_review_test.dart) and [full onboarding flow test](../../test/onboarding/plan_app_navigation_test.dart) committed, including mobile/desktop/dark mode and blocked payment without checkbox.
- [ ] Flutter compile, static analyze and widget tests **have not been executed** due repository GitHub Actions billing/spending runner restrictions.
- [ ] Test on actual Android, iOS, Windows and browser sizes; fix any discovered layout defects.
- [ ] Integrate trusted payment processor in the *next* Step 5 module; use server-issued checkout/payment intents, idempotency, webhook signature verification and private server-side subscription transitions. Never store card numbers or payment secrets in Flutter or client-accessible tables.
- [ ] Explicitly decide application review/approval sequencing before production: user requested Go to Payment immediately after personal review, whereas earlier drafts stated operator approval precedes payment. This is a product flow decision, not something the current UI silently authorizes.

## Related files

- [Review screen](../../lib/features/onboarding/presentation/school_review_preview.dart)
- [Review confirmation repository](../../lib/features/onboarding/data/review_confirmation_repository.dart)
- [School setup draft model with server revision token](../../lib/features/onboarding/domain/school_setup_draft.dart)
- [School setup Edit target scroll integration](../../lib/features/onboarding/presentation/school_setup_screen.dart)
- [Step 5 payment preview](../../lib/features/onboarding/presentation/school_payment_preview.dart)
- [Live SQL](../../supabase/schema/06_onboarding_review_confirmation.sql)
- [SQL negative tests](../../supabase/tests/06_review_confirmation_security.sql)

## Postal code completeness (Step 3 + Step 4)

The supplied reference shows a postal/ZIP code field in the Location review card, but the earlier Step 3 schema had no such field. [Migration `20261111120829`](../../supabase/schema/07_school_setup_postal_code.sql) adds nullable `postal_code` to `public.school_setup_drafts` (maximum 32 characters), without changing existing rows. The Step 3 form, typed draft model and Step 4 review now read/write and display it. No placeholder address values are fabricated.
