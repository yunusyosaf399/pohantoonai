# Pohantoon AI — Multi-Tenant School Management SaaS

One Flutter application across Android, iOS, Windows, macOS, Linux and Web, backed by **one Supabase project** serving multiple independent schools.

## Current app entry: Step 1 of 6 — Create Account

The first screen now matches the supplied mobile and desktop design references: teal/navy branding, school illustration, six-step progress indicator, and separate Google and **Continue with email** actions. The UI adapts to portrait mobile and wide desktop. Appearance settings provide **System / Light / Dark** modes, persisted locally and for signed-in users in Supabase.

- [Flutter sign-in screen](lib/features/auth/presentation/account_welcome_screen.dart)
- [Supabase Auth gateway](lib/features/auth/data/account_auth_gateway.dart)
- [Theme settings](lib/core/settings/theme_controller.dart)
- [New widget tests](test/auth/account_welcome_test.dart)
- [Back-end schema](supabase/schema/03_account_identity_preferences.sql)
- [Auth onboarding contract](docs/database/module_01_account_auth.md)

**Security:** Authentication never grants organization or school administrator status. The existing Organization Control Panel feature is still in [`lib/features/organization/`](lib/features/organization/) for future role-protected integration; it's only accessible through an explicit test/development preview flag today.

## Cross-platform Google OAuth and email return-to-app callback

**Updated 2026-11-11:** Flutter Web now returns to the active URL including its deployment path; Android/iOS/macOS let Supabase's `app_links` consume callbacks instead of Flutter's competing router. The Windows runner registers `pohantoonai://` under the current user and forwards second-instance callbacks to the existing app. OAuth launches in the system browser, and authentication-stream failures show recoverable sign-in feedback.

- [Complete platform callback setup, Supabase allowlist and testing instructions](supabase/auth/OAUTH_CALLBACK_PLATFORMS.md)
- [Web redirect unit tests](test/auth/oauth_redirect_test.dart)
- [Native Android/iOS/macOS/Windows callback contract tests](test/auth/native_callback_contract_test.dart)

**Action still required in Supabase Dashboard:** Add `pohantoonai://auth-callback` plus the **exact** active Flutter Web origin (for example `http://localhost:3000/`) under Authentication → URL Configuration → Additional Redirect URLs. Client source code cannot override a blocked server redirect. **These source changes are committed, not runtime-verified**; Flutter runners remain blocked by account billing/spending restrictions.

## Step 2 of 6 — Choose Your Subscription Plan

After a valid Google/email account session, Flutter now opens a **responsive plan-selection screen** with desktop sidebar and mobile cards, active plans from Supabase, two-way Light/Dark/System appearance settings, and saved choices scoped to the signed-in user.

- [Flutter plan selection screen](lib/features/onboarding/presentation/plan_selection_screen.dart)
- [RLS-backed data repository](lib/features/onboarding/data/onboarding_plan_repository.dart)
- [Portable deployed SQL](supabase/schema/04_onboarding_plan_selection.sql)
- [Supabase security smoke tests](supabase/tests/04_onboarding_plan_security.sql)
- [Detailed design and status](docs/database/module_01_plan_selection.md)

**Database deployed and security smoke-tested.** Source now has 3 published demo plans and only the account owner can save their draft choice; no subscription, payment, school or permission is created. Step 3 now provides the real school-information form and saves an applicant-owned draft. Flutter widget tests are written but **not yet run**: GitHub Actions jobs fail before starting because of account billing/spending restrictions.

## Step 3 of 6 — Tell Us About Your School

The real School Setup form now follows the saved Step 2 plan. It matches the supplied dark/light desktop, tablet and mobile designs with four cards: **School Identity**, **Primary Contact**, **Location & Preferences**, and **Academics & Capacity**. It uses the same System/Light/Dark appearance settings.

**Save Draft** stores partial information; **Continue to Review** enforces required fields and plan student/campus/staff limits in Flutter **and independently in PostgreSQL**, then shows a read-only Step 4 review preview. No school, payment or subscription is created.

- [Step 3 Flutter UI](lib/features/onboarding/presentation/school_setup_screen.dart)
- [Draft model and validation](lib/features/onboarding/domain/school_setup_draft.dart)
- [Authenticated draft repository](lib/features/onboarding/data/school_setup_repository.dart)
- [Step 4 read-only review preview](lib/features/onboarding/presentation/school_review_preview.dart)
- [Deployed database schema](supabase/schema/05_school_setup_drafts.sql)
- [Executed RLS/plan-capacity tests](supabase/tests/05_school_setup_security.sql)
- [Design, security and acceptance report](docs/database/module_01_school_setup.md)

**Database tested and deployed. Flutter runtime tests are still pending** because GitHub Actions has an owner-account billing/spending-limit restriction preventing runner startup.

## Run Flutter

```bash
flutter pub get
flutter run
flutter analyze
flutter test
```

The development Supabase URL and **publishable** key are configured in `lib/core/config/supabase_configuration.dart` (safe for clients). No service key, OAuth client secret or database password is shipped in Flutter. For a different organization later, override public settings at build time:

```bash
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_YOUR_KEY
```

**Important:** The package lockfile must be regenerated and committed by running `flutter pub get` with a working Flutter SDK (not available in this execution environment). Current GitHub Actions runs fail before job steps; build/test success is not yet verified.

## Android APK for mobile testers

An automated GitHub Actions workflow now builds a **debug test APK** from `main` and, on success, uploads it as an Actions artifact and attempts a prerelease for direct installation.

**Current blocker:** [first APK build](https://github.com/yunusyosaf399/pohantoonai/actions/runs/42956828072) failed **before any steps ran**, leaving **no APK**. Previous Flutter CI runs showed the same runner-start problem. Check GitHub Actions / repository permissions / account billing and budget (exact root cause has not been confirmed).

- [Build Android Test APK workflow](.github/workflows/android-apk.yml)
- [Mobile download and installation instructions](docs/flutter/android_apk_build.md)
- [Latest test releases](https://github.com/yunusyosaf399/pohantoonai/releases) (only after a successful build)

## Authentication provider setup

Flutter uses Supabase-managed Google OAuth and passwordless email magic links. Google provider credentials, email sender/SMTP and callback URL allowlists **must** be configured in the project's Supabase dashboard before end-to-end login will work. See [exact provider and redirect setup](docs/database/module_01_account_auth.md).

## Database source code and progress

Every database-owned artifact is stored under [`supabase/`](supabase/README.md). The single live development database is `pohantoonai` in the connected YouPro School organization. Database authentication tables and Edge Function are deployed with RLS:

- [Module 01 organization onboarding SQL](supabase/schema/01_platform_onboarding.sql)
- [Module 01.1 accounts and theme SQL](supabase/schema/03_account_identity_preferences.sql)
- [JWT-verified account bootstrap Edge Function](supabase/functions/account-bootstrap/index.ts)
- [Source and test-data verification](supabase/tests/03_account_auth_smoke.sql)

Project planning: [table catalog](docs/architecture/table_catalog.md), [roadmap](docs/tracking/master_roadmap.md), [sprint](docs/tracking/current_sprint.md), [session tasks](docs/tracking/independent_tasks.md).

## Delivery order

Account creation → choose subscription plan → collect legal and operational school details → operator review → verified payment or approved trial → protected school provisioning → student admissions → fees, teachers, attendance and later modules.

**Do not use real student data until the corresponding school-scoped RLS, workflows and cross-tenant denial tests have been implemented.**
