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
