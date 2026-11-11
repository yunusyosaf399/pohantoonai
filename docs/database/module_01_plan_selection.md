# Module 01.2 — Choose Your Plan (Step 2 of 6)

> **Deployed:** 2026-11-11 to `pohantoonai`, YouPro School, `umlzqlbakfwzgadafhyy`.  
> **Migration:** `20261111050513`, `secure_onboarding_plan_offers_and_user_selections`.  
> **Status:** Database/SQL negative tests verified; Flutter source and widget tests committed, but Flutter compilation **not verified** because GitHub Actions runner start is blocked by account billing/spending restrictions.

## UX, screenshots and responsive behavior

Four supplied reference images establish one coherent Step 2 rather than four separately maintained screens:

- **Desktop light / dark:** mint or deep-teal left rail, school illustration, six-step timeline; right area shows theme/account controls, 2/6 progress, three selectable plan cards, safe payment notice, selected summary and back/continue controls.
- **Mobile light:** compact logo/back/theme/account header, 2/6 progress, intro, banner and single-column touch-friendly plan cards. On larger tablet space, cards can form two columns; on wide desktop, three.
- **Narrow phones:** footer actions stack rather than overflowing. Selected cards have a clear border, checkmark and semantic selection state; summaries update without network mutation.
- **Theme:** existing `ThemeController` persists Light/Dark/System locally, and user preference in RLS-protected `user_preferences` after login. No second theme system was introduced.

**User flow**: Supabase Auth session (Step 1) → Step 2 fetch active published plans → user chooses (visual only) → taps Continue → selection is saved under their Auth user id → Step 3 placeholder. Step 3 is **not yet a completed school information form**: nothing creates a school, activates a subscription, charges money or assigns user permissions.

## Database schema and role boundaries

| Table / function | Purpose | Permission |
|---|---|---|
| `platform.subscription_plans` | Private organization master plan details | No client grant |
| `platform.subscription_plan_features` | Private source feature limits | No client grant |
| `public.onboarding_plan_offers` | Safe mirrored public metadata: name, description, trial and three caps | Authenticated SELECT when active; client cannot mutate |
| `public.onboarding_plan_selections` | Draft plan choice associated with `auth.users` via user id | Authenticated SELECT/INSERT/UPDATE own row only; no DELETE |
| `platform.refresh_onboarding_offer` | Privileged private sync function with fixed empty search_path | No anon/authenticated execute; invoked from private triggers |
| `platform.onboarding_offer_plan_changed` | Refresh on master plan changes | Trigger only |
| `platform.onboarding_offer_feature_changed` | Refresh on feature creation/update/removal | Trigger only |
| `public.onboarding_plan_selection_stamp` | Server-controlled `selected_at` and `updated_at` | Trigger only |

**SQL source:** [`supabase/schema/04_onboarding_plan_selection.sql`](../../supabase/schema/04_onboarding_plan_selection.sql). There are **2 new tables, 4 RLS policies, 4 trigger/sync functions, 3 triggers and supporting indexes**. There is deliberately no public security-definer RPC or new Edge Function because this step requires only regular owner-row CRUD; privileged subscription and payment operations will need their own trusted server workflow later.

No `school_id` exists in draft selection because the applicant has not created a school yet. User ownership is always `auth.uid() = user_id`. The selected plan references an actual published offer. Updating/selecting a plan never writes to `platform.school_subscription_requests` and never records payment.

## Data source and test seed

All three existing plans originate from the private `pohantoonai_demo` organization:

| Plan | Student cap | Campus cap | Staff cap | Trial |
|---|---:|---:|---:|---:|
| Starter Demo | 250 | 1 | 30 | 14 days |
| Growth Demo | 1,500 | 5 | 150 | 14 days |
| Enterprise Demo | Unlimited | Unlimited | Unlimited | 30 days |

Null limit means unlimited; **0 means unavailable**. Descriptions were aligned to the supplied designs with a test-only patch, [`supabase/seed/02_demo_plan_descriptions.sql`](../../supabase/seed/02_demo_plan_descriptions.sql). The original base seed was also updated for reproducibility. Live checks confirmed private plan descriptions and published offer descriptions match for all three codes after the trigger ran.

## Flutter implementation and errors

- [Plan domain model](../../lib/features/onboarding/domain/onboarding_plan_offer.dart): typed field parsing, limits and presentation strings.
- [Supabase plan repository](../../lib/features/onboarding/data/onboarding_plan_repository.dart): authenticated read, own saved-selection read, owner-scoped upsert with returned id confirmation.
- [Responsive Step 2 screen](../../lib/features/onboarding/presentation/plan_selection_screen.dart): desktop/tablet/mobile presentation, dark/light states, loading, retry, save-failure handling, keyboard and semantic click target via InkWell.
- [Step 3 preview](../../lib/features/onboarding/presentation/school_setup_preview.dart): honest confirmation after saving; full school-information module remains future work.
- [App routing](../../lib/main.dart): a valid Auth session shows Step 2, never the private platform operator dashboard; returning to Step 1 prompts for sign-out.
- [Screen widget tests](../../test/onboarding/plan_selection_test.dart): desktop/mobile/compact, plan switching, dark-mode saved choice, retry and write failure.
- [App navigation test](../../test/onboarding/plan_app_navigation_test.dart): sign-in → plan persistence → Step 3 preview → back to Step 2.

A **draft choice is not a subscription**. The DB is the source for active offers, and the Flutter screen never trusts a client-generated price or feature tier. API failures are shown as usable, non-sensitive UI messages. The Continue action is disabled during save, preventing repeated submissions.

## Verification results

- [x] Live schema migration applied and listed by Supabase.
- [x] Three active demo offers and correct 250/1500/unlimited capacities.
- [x] RLS enabled on both tables; offers have one SELECT policy; selections have three owner-row policies.
- [x] `anon` has **zero table privileges** on either table; published offers have `authenticated SELECT` only.
- [x] Read-only policy/grant catalog queries completed.
- [x] [Transactional RLS test](../../supabase/tests/04_onboarding_plan_security.sql) executed: unauthenticated SELECT blocked, authenticated own INSERT/UPSERT worked, forged user and invalid-plan writes blocked, private platform SELECT blocked; test rolled back.
- [x] Post-rollback verification: zero selection rows remain in development database.
- [x] Source-to-offer sync verified after changing demo descriptions.
- [x] Supabase Security Advisor: no new exposed-table risks; 12 informational `platform` policy-free tables remain intentionally closed.
- [ ] **Account config warning:** Supabase Security Advisor flagged leaked-password protection disabled. [Supabase remediation guide](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection). This is a separate Auth provider setting; not changed by this module.
- [ ] **Flutter tests:** cannot mark as passing. GitHub Actions runner is blocked before steps by billing/spending limit; local Flutter SDK unavailable here.
- [ ] Android, iOS, Web and Windows visual/device tests.
- [ ] Live SDK session test using actual Google/email account, plus session refresh/expired JWT behavior.
- [ ] Real Step 3 school-information fields and transactional application save.

## Portability / next module

The **source of truth for portable SQL is in `supabase/`**. When using a different Supabase account, run reviewed scripts in dependency order: Module 01 private foundation, Module 01.1 Auth, then Module 01.2 published plan offers; keep fake seed separate and reconcile Supabase's recorded live migration versions before importing. Do not replay the current migration on the same project under another name.

Next: design Step 3 school legal/contact/campus/education information, create typed validations and owner-scoped draft onboarding (requires additional school applicant boundaries), implement review workflow, and only then consider verified billing or provisioning. The 383-table planning catalog remains a candidate inventory, not an instruction to create all tables.
