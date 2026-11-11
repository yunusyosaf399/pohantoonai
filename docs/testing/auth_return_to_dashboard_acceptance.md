# Authentication and Returning Dashboard Acceptance Tests

Date: 2026-11-11. Related module: [Module 02.2](../database/module_02_2_dashboard_auth_profiles.md).
Target: Supabase project `umlzqlbakfwzgadafhyy`, Flutter Web, Windows, Android, iOS (same codebase).
No production school tenant, payment charge, or service-role key is involved.

## Automated tests: source committed, execution pending

`test/auth/auth_return_to_dashboard_flow_test.dart`

- Scenario A: a Google-authenticated school owner with a completed school draft and `development_preview` workspace opens the dashboard. Owner & Security adds an Auth password. Sign-out displays the welcome screen. Email/password sign-in with the same email returns to the same dashboard without the payment step.
- Scenario A negative: switching to another Auth user ID without a sign-out event clears the previous in-memory dashboard before displaying the other user's plan selection.
- Scenario B: email/password signup does **not** immediately create an authenticated user session in the test. A matching confirmation OTP is required. The new verified user selects a demo plan, completes Step 3, obtains the matching development workspace, and opens the dashboard directly.
- Additional files: `test/auth/email_credentials_panel_test.dart`, `test/dashboard/dashboard_profile_settings_test.dart`, `test/onboarding/plan_app_navigation_test.dart`.
- These are Flutter widget tests using **simulated** Auth; they do not claim actual Supabase email deliverability, Google browser OAuth or checkout integration.

Run in the project root when Flutter SDK and GitHub runner are available:

```powershell
git pull origin main
flutter pub get
flutter analyze
flutter test test/auth/
flutter test test/dashboard/
flutter test test/onboarding/plan_app_navigation_test.dart
flutter test
flutter run -d windows
```

GitHub workflow [Flutter Analyze and Widget Tests](../../.github/workflows/flutter.yml) already runs `flutter pub get`, `flutter analyze` and `flutter test` on pushes. **Current execution is blocked before any steps run** by the GitHub Actions account/billing issue. Do not mark tests green until a real run finishes successfully.

## Hosted Supabase configuration — operator action required

Supabase's connected tooling for this project can apply SQL and Edge Functions but **does not expose the hosted Auth configuration or SMTP secret management**. Do not try to write SMTP secrets into GitHub, Flutter `--dart-define`, SQL migrations or an Edge Function.

1. Visit [Supabase Email provider](https://supabase.com/dashboard/project/umlzqlbakfwzgadafhyy/auth/providers). Enable Email provider and **Confirm email**; leave password-based sign-in available.
2. Open [Supabase Email Templates](https://supabase.com/dashboard/project/umlzqlbakfwzgadafhyy/auth/templates): install [Confirm signup](../../supabase/auth/templates/confirm_signup.html) and [Magic Link/OTP](../../supabase/auth/templates/magic_link_otp.html). Ensure `{{ .Token }}` is kept exactly as the Supabase template placeholder.
3. Configure your verified sender, SMTP host, port, username and password under the **project Authentication SMTP settings**, not in the repo. Supabase's built-in sender generally delivers only to pre-authorized project-team addresses; arbitrary school mailboxes require SMTP.
4. Confirm [redirect allowlist](https://supabase.com/dashboard/project/umlzqlbakfwzgadafhyy/auth/url-configuration) includes your actual Web origin(s) and `pohantoonai://auth-callback` for native targets, consistent with registered OS deep links. Windows/desktop registered callback must work before testing OAuth/password reset.
5. Review rate limits, OTP expiry and CAPTCHA/abuse protection. Enable [leaked password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection) (currently flagged by the Auth security advisor). Never disable confirmation simply to pass a test.

## Real-device acceptance journeys (NOT YET EXECUTED)

### A. Existing Google user becomes an email/password user

1. Log in with an existing verified Google account whose school setup is complete. Confirm the School Dashboard is displayed directly.
2. Open avatar → **Owner & security settings**. Verify the read-only login email matches the existing Google user. Enter a 12+-character unique password twice; select Save password.
3. Sign out. On Welcome choose Continue with email → Sign in; enter the **same account email**, plus the newly created password.
4. Confirm Supabase returned to the **same `auth.users.id`**, the same account-owned `onboarding_dev_workspaces.user_id` and the same school name. No registration wizard, payment page, or new school/account duplication should occur.
5. Open School profile settings, update a permitted contact field, save; reload the app. The change must persist without leaving the dashboard.

### B. New email account signs up and verifies OTP

1. Enter a NEW email that can receive mail through the configured SMTP; create/confirm a 12+-character password.
2. Retrieve the real code from the Supabase confirmation email, enter it in the app. An incorrect/expired code must not sign in; resend must be rate-limited.
3. Choose Growth Demo, complete required school fields, then select Open Demo Dashboard.
4. Sign out, then use email/password login. The saved school dashboard must load directly with the same Auth user ID and selected plan.
5. Attempt a second account: no access to the first account's school draft, demo workspace or owner profile.

### C. Password recovery

1. From email Sign in, select Forgot password; use the recovery link on the target device.
2. Confirm the app opens the password-change dialog. Set matching 12+-character credentials and confirm that a normal password login works.
3. Verify expired links cannot change credentials and reset/recovery messages do not expose tokens in logs.

## Verified non-sensitive server evidence (2026-11-11)

The live Postgres database was checked **without reading or exposing passwords or emails**:
- Three email-confirmed accounts; two have an Auth password configured.
- One account has both a Google identity and a password under the **same** `auth.users.id`.
- One account has both a password and an `onboarding_dev_workspaces` row under the **same** user ID.
- This proves the required data linkage exists, **not** that browser sign-in, SMTP delivery, deep linking, or a Windows build was tested.

## Gate status

- [x] Two Auth paths and cross-account state-clearing widget tests committed
- [x] Flutter Auth code and stable account-ID routing committed
- [x] Live database identity/password/workspace relationship queried without credentials
- [x] Existing RLS and required-school-data security tests executed in rollback-only SQL
- [ ] Hosted Confirm Signup/Magic Link OTP templates installed
- [ ] Custom SMTP configured and real verification email delivered
- [ ] Google→password→same dashboard manually tested on Web/Windows/mobile
- [ ] New email→OTP→new dashboard manually tested on Web/Windows/mobile
- [ ] Flutter analyze/tests succeed on a usable runner or local SDK
- [ ] Leaked password protection and authentication abuse controls enabled

**Do not mark this module end-to-end complete while any of the last six boxes are unchecked.**

## Live account-linkage RLS proof (2026-11-11)

[Auth provider/workspace test SQL](../../supabase/tests/15_auth_provider_same_account_rls.sql) **passed** against the linked Supabase project under simulated authenticated Postgres roles with ROLLBACK. A verified account that already has both a Google identity and password can SELECT its own matched plan, ready draft and development workspace; another confirmed account cannot SELECT that workspace. This is stronger than a raw database join, but is **not** a real end-user Google/password sign-in or SMTP delivery test.

External deployment blockers are tracked separately in [Auth SMTP/templates issue](https://github.com/yunusyosaf399/pohantoonai/issues/1) and [Flutter test/CI issue](https://github.com/yunusyosaf399/pohantoonai/issues/2).
