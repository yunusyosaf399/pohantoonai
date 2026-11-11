# Supabase — Pohantoon AI

This folder is the **portable database source of truth**. It is intended to be reused later with a different Supabase organization or project. The immediate target is **one** dedicated development project named `pohantoonai` (deployed in `YouPro School`, project ref `umlzqlbakfwzgadafhyy`); no school-per-project architecture.

## Folder organization

| Path | Role |
|---|---|
| schema/08_onboarding_payment_preferences.sql | **Deployed Module 01.5** own-account billing preferences and unpaid test-only skip state, no card data |
| tests/08_payment_preferences_security.sql | **Executed** transactional ownership, invalid status/format/method, server-generated skip time checks |
| schema/09_school_logo_storage.sql | **Deployed** optional applicant logo path, private 2-MiB school-logos bucket with owner-only Storage policies |
| schema/10_demo_dashboard_preferences.sql | **Deployed** Step 6 applicant-owned preview preferences, requires unpaid test skip |
| schema/11_school_dashboard_foundation.sql | **Deployed** six empty read-only school tenant/analytics tables with membership isolation |
| tests/10_demo_dashboard_preferences_security.sql | **Passed** rolled-back owner + skip + status tests |
| tests/11_dashboard_foundation_security.sql | **Passed** rolled-back RLS, unauthorized school read, private bucket tests |
| `schema/07_school_setup_postal_code.sql` | **Deployed** optional postal/ZIP code support for the School Setup and Application Review cards |
| `schema/06_onboarding_review_confirmation.sql` | **Deployed Module 01.4** own-account review acknowledgement with draft revision/plan concurrency checks |
| `tests/06_review_confirmation_security.sql` | Executed rollback-only tests: stale revision, forged user, plan mismatch rejected |
| `schema/05_school_setup_drafts.sql` | **Deployed Module 01.3** owner-scoped school draft fields, required-field/capacity constraints and reset-on-plan-change logic |
| `tests/05_school_setup_security.sql` | Executed transactionally: partial draft, readiness checks, ID spoofing rejection, plan limit checks and plan-change reset |
| `schema/04_onboarding_plan_selection.sql` | **Deployed Module 01.2** secure published offer snapshots, owner-only draft choices, source synchronization |
| `seed/02_demo_plan_descriptions.sql` | Development-only descriptions matching Step 2 references, verified synchronized |
| `tests/04_onboarding_plan_security.sql` | Executed RLS negative test inside ROLLBACK transactions |
| `schema/01_platform_onboarding.sql` | Deployed Module 01 private SaaS organization, plans, school onboarding, subscription request and review records |
| `schema/02_secure_existing_rls_trigger.sql` | Deployed hardening of an existing public event-trigger function's execute privileges |
| `seed/01_demo_platform.sql` | Idempotent **fake/demo-only** seed with plans and a sample application |
| `tests/01_platform_smoke.sql` | Read-only smoke checks after deployment |
| `migrations/` | Official timestamped migrations created with `supabase migration new ...` once Supabase CLI is available |

**Never store keys, passwords, connection strings, privileged tokens or real student data in Git.** `platform` is intentionally not a client-exposed schema. All its tables have RLS enabled and no `anon`/`authenticated` table grants; Flutter's applicant-facing Steps 2 and 3 use authenticated, RLS-protected repositories; the operator dashboard remains in a separate preview path.

## Deployment workflow

1. **Done:** Use the user-created project `pohantoonai` (`umlzqlbakfwzgadafhyy`) in the `YouPro School` organization.
2. **Done:** Apply `schema/01_platform_onboarding.sql` in a tracked Supabase migration (`platform_onboarding_foundation`).
3. **Done:** Apply `seed/01_demo_platform.sql` on this disposable test database; it creates synthetic `example.invalid` records, not real payments.
4. **Done:** Verify 12/12 RLS, zero public client data access, 3 plans, and sample request; apply `schema/02_secure_existing_rls_trigger.sql` as a second tracked migration (`secure_existing_rls_trigger_permissions`).
5. **Next:** Add operator authentication and protected APIs before wiring Flutter to live records.
6. When Supabase CLI is available, use `supabase migration new platform_onboarding` and put the reviewed SQL into the generated timestamped file under `migrations/`; reconcile the test project's existing migration history before pushing elsewhere. The same SQL must never be applied twice with competing migration names.
7. Add authenticated read/write API endpoints **only after** implementing current membership, reviewed RLS, tenant isolation, transactional onboarding and verified subscription/payment status. No direct client access to these private tables.

## Development order

**Module 01:** SaaS Organization Control Panel (current) → **Module 02:** approved school provisioning, school profile/campuses/years → **Module 03:** identity/roles and student admissions → **Module 04:** enrollment and finance; continue domain by domain.

A school onboarding request is **not yet a school**. The request captures institution details, contact, location, academics, operations and a selected plan. It must later pass verified subscription or explicit authorized trial approval before a protected school-provisioning command creates `app.schools`. No test checkout here counts as real payment.

## Local developer commands (after CLI setup)

- Run `supabase --help` and `supabase migration --help` to confirm CLI syntax.
- Generate official migration files with `supabase migration new <name>`.
- The SQLite or browser mock UI is **not** a substitute for PostgreSQL constraint/RLS tests.
- Never run the demo seed on production; migrations and seeds are separate.

## Current evidence

- SQL and seed files committed to GitHub; Module 01 and privilege-hardening migrations applied successfully to the test Supabase project.
- Verified 12 platform tables with RLS and no client read/write grants. Sample school application and 3 plans exist.
- Supabase security linter reports 12 INFO policy-free private tables (intentional). No remaining exposed privileged helper warnings after privilege revocation.
- Flutter code/tests have not passed a confirmed CI run; live API integration is still pending.


## Module 01.1 — First-screen Auth and appearance (2026-11-10)

- [Source SQL](schema/03_account_identity_preferences.sql) deployed as version `20261110174324`, `account_profiles_theme_preferences_rls`.
- `public.user_profiles` and `public.user_preferences` are RLS-protected, self-service authenticated records, **not** platform or school roles. `auth.users` remains managed by Supabase.
- [Edge function](functions/account-bootstrap/index.ts) `account-bootstrap` deployed ACTIVE v1, `verify_jwt=true`. Caller token revalidated with Auth; no service-role use or privileged memberships granted.
- [Smoke test](tests/03_account_auth_smoke.sql) checks ownership-policy inventory, anonymized grants and theme-mode constraint.
- [Provider configuration](../docs/database/module_01_account_auth.md) requires Google OAuth client ID/secret, email delivery settings and callback allowlist via Dashboard; cannot be performed by currently available Supabase connector calls.
- `supabase_flutter: 2.18.3` and `shared_preferences: 2.5.5` pinned in pubspec; **lockfile regeneration and Flutter CI are outstanding**. Do not claim successful auth end-to-end without provider configuration.
- When moving to another Supabase organization, replay the reviewed schema scripts in recorded dependency order and create matching official timestamped CLI migrations; reconcile existing live migration history. **Do not blindly replay the same SQL under new migration names in the existing test project.**

## Module 01.2 — Step 2 (2026-11-11)

- [Schema](schema/04_onboarding_plan_selection.sql) deployed as migration `20261111050513` (`secure_onboarding_plan_offers_and_user_selections`). No new Supabase project created.
- `public.onboarding_plan_offers`: three active/read-only demo plan records. Not a client-editable pricing table.
- `public.onboarding_plan_selections`: one account-owned draft row, own-row `SELECT/INSERT/UPDATE` policies, no anonymous access.
- Private plan/feature updates refresh only safe public catalog fields; `platform` remains unexposed.
- [Security tests](tests/04_onboarding_plan_security.sql) executed and rolled back; confirmed zero persisted test selections after rollback.
- Security advisor found an independent Auth setting: **leaked password protection disabled**; see https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection . Other 12 private `platform` tables still emit intentional INFO policy-free notices.
- For another Supabase organization, apply source schemas in dependency order and maintain the recorded migration history. Keep test seeds separate from real school data.

## Module 01.3 — Step 3 School Setup (2026-11-11)

- [Schema](schema/05_school_setup_drafts.sql) deployed in migration `20261111064830` (`secure_school_setup_drafts_and_plan_capacity`) to the existing `pohantoonai` project.
- `public.school_setup_drafts`: one draft per signed-in applicant; plan selection user ID foreign key; no new tenant created.
- Both partial `draft` and validated `ready_for_review` statuses exist; neither is an approved application.
- Owner-only `SELECT/INSERT/UPDATE` RLS; no anonymous access or client DELETE.
- No payment, operator review or school provisioned. [Transactional security test](tests/05_school_setup_security.sql) passed and rolled back.
- [Step 3 UX and schema mapping](../docs/database/module_01_school_setup.md). Test on actual Flutter devices before production use.

## Module 01.4 — Step 4 Review + Go to Payment (2026-11-11)

- [Schema](schema/06_onboarding_review_confirmation.sql) deployed as migration `20261111115622` (`secure_review_confirmation_for_payment_handoff`). No second Supabase project was created.
- `public.onboarding_review_confirmations` records the applicant's acknowledgement of the **exact current Step 3 revision** and current selected plan. RLS: own-account SELECT/INSERT/UPDATE only; no anon grants.
- [Transactional negative tests](tests/06_review_confirmation_security.sql) verified own confirmation, rejection of stale/mismatched plan/user; zero test confirmations persisted.
- **No application is submitted or approved and no payment is performed** by recording this acknowledgement. Future payment backend must perform its own authoritative verification.
- See [Step 4 UI and schema contract](../docs/database/module_01_application_review.md).

### Optional postal code extension (2026-11-11)

[Migration `20261111120829`](schema/07_school_setup_postal_code.sql) added nullable `school_setup_drafts.postal_code` with a length check. Verified via live `information_schema.columns`. It is compatible with previously saved school drafts and requires no new school tenant.


## Module 01.5 — Payment preview with unpaid skip

On 2026-11-11, deployed migration 20261111122224 (secure_payment_preferences_and_test_skip) to the same one-project development database, source: [schema/08_onboarding_payment_preferences.sql](schema/08_onboarding_payment_preferences.sql). The newly created public.onboarding_payment_preferences table has authenticated owner-only SELECT/INSERT/UPDATE RLS, no anon grant and no DELETE. A non-privileged trigger ensures the current Step 3 details and Step 4 confirmation have not gone stale. The only state values are preferences_only and skipped_for_testing; no paid/active/charge fields exist.

Executed [transactional SQL security test](tests/08_payment_preferences_security.sql) successfully, leaving zero test billing records. Flutter UI design and safety contract: [module_01_subscription_payment.md](../docs/database/module_01_subscription_payment.md).


## Step 6 dashboard and school-logo changes (2026-11-11)

- Private school logo with per-user folder policies and 2-MiB MIME limit: [schema/09_school_logo_storage.sql](schema/09_school_logo_storage.sql), migration 20261111125611.
- RLS-protected, unpaid test-preview preferences: [schema/10_demo_dashboard_preferences.sql](schema/10_demo_dashboard_preferences.sql), migration 20261111125713; signed-in user must have an actual skipped_for_testing record.
- Future real school and dashboard records: [schema/11_school_dashboard_foundation.sql](schema/11_school_dashboard_foundation.sql), migration 20261111125810. All six real tenant tables are **empty and read-only to clients**. School dashboard report SELECT policies require a real active owner/admin membership and an active school.
- [All schema/UI/permission design decisions](../docs/database/module_02_school_dashboard.md).


### Additional dashboard tests

[09_school_logo_security.sql](tests/09_school_logo_security.sql): executed ROLLBACK-only tests; own logo path accepted and cross-account, wrong folder and SVG references rejected. The RLS-only test fixtures create no real Storage objects. The Storage byte upload and signed-read paths must still be verified on a signed-in device.


## Module 02.2 — Development workspaces (2026-11-11)

- [schema/12_dev_workspace_persistent_access.sql](schema/12_dev_workspace_persistent_access.sql): DEPLOYED migration 20261111140501, own-account development_preview status created only after valid school setup and selected active demo plan. No paid state, school membership or real tenant authorization.
- [tests/12_dev_workspace_security.sql](tests/12_dev_workspace_security.sql): executed transaction-only test. Forged access and payment/school writes denied; rollback preserved existing users.
- [Auth code email template sources](auth/templates/confirm_signup.html) and [Magic Link/OTP template](auth/templates/magic_link_otp.html): committed to repo but NOT installed in the Supabase hosted Authentication Email Templates settings. The Supabase project also needs SMTP configuration and leaked-password protection.
- [Module 02.2 design](../docs/database/module_02_2_dashboard_auth_profiles.md) describes database, Flutter and Auth setup.
