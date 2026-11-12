# Password-reset session isolation — November 12, 2026

Project: `yunusyosaf399/pohantoonai`. Applies to Flutter Web and mobile/desktop deep links using the existing Supabase Auth project. No SQL schema or Edge Function is required.

## Incident

**Reported:** Clicking the password-reset email opens the Pohantoon AI password-reset dialog, but the app also renders the school/student dashboard behind it.

**Cause:** Supabase password-recovery links exchange a short-lived recovery credential for an authenticated session. The previous `main.dart` implementation listened to `AuthChangeEvent.passwordRecovery` and called `showDialog` over the normal signed-in app. At the same time, the generic `sessionIdentityChanges` stream restored school dashboard data for any authenticated session. The result was an incorrectly visible dashboard behind the modal.

A valid recovery link must never be handled as ordinary dashboard sign-in.

## Security fix implemented in Flutter

1. The password recovery intent is now captured from `Uri.base` **before** `Supabase.initialize` consumes the Web URL. The production auth listener also recognizes the actual `passwordRecovery` event for native and in-app callbacks.
2. `resetPasswordForEmail` includes a non-secret `auth_flow=password_recovery` marker in its redirect URL. This marker is **not an authentication credential**; Supabase Auth must still validate the signed link. Legacy Supabase `type=recovery` callback URLs remain recognized.
3. The root `MaterialApp.home` switches to **`PasswordRecoveryScreen`**, not a dialog. A distinct Navigator key discards any dashboard bottom sheet, popup or route. No dashboard widget tree remains under the recovery form.
4. Entering recovery invalidates any in-progress `_restoreWorkspace()` request and clears all in-memory selected school, draft and dashboard state. The session stream skips dashboard restoration while recovery is active. This holds even if the user has already completed school registration or a new `userUpdated` event arrives after `updateUser(password: ...)`.
5. On successful password update, the app signs out the temporary recovery session and returns to the normal Welcome page. **No automatic dashboard login**; the owner must sign in again with their new password.
6. Cancel also signs out. If password change or sign-out fails, the dedicated recovery screen remains visible. A successful change is not repeated on a sign-out retry. Recovery errors never print link tokens, OTPs, passwords or callback query strings.
7. Light and dark styling uses the existing Flutter theme. No new database tables, payment permissions or school-membership grants are created.

### Code changed

- [Flutter app routing and recovery-only state](../../lib/main.dart)
- [Supabase Auth recovery callback recognition](../../lib/features/auth/data/account_auth_gateway.dart)
- [Full-screen secure password recovery UI](../../lib/features/auth/presentation/password_recovery_dialog.dart)
- [End-to-end-style widget tests with simulated Auth](../../test/auth/auth_return_to_dashboard_flow_test.dart)
- [Callback URL parsing tests](../../test/auth/password_recovery_redirect_test.dart)

## Existing domain / Supabase redirect configuration

The user now owns `pohantoonai.com`; **domain registration alone does not mean Flutter Web is hosted there**. Use the actual HTTPS app URL for Web redirects.

In the current Supabase project:

**Authentication → URL Configuration → Redirect URLs**
- Native (new recovery callback): `pohantoonai://auth-callback?auth_flow=password_recovery`
- Native (existing Google callback): `pohantoonai://auth-callback`
- Web, **only if the Flutter app really runs at the domain root**: `https://pohantoonai.com/?auth_flow=password_recovery`
- If Web is hosted at `www.pohantoonai.com` or a subpath, instead allow the exact corresponding path and host.

Avoid broad wildcard redirect allowlists when exact app URLs work. Don't replace the Google Cloud OAuth provider callback: it remains Supabase's `/auth/v1/callback`. The app callback URLs are separate.

**Authentication → Email Templates → Reset Password** must use Supabase's `{{ .ConfirmationURL }}` for the button, which carries the verified reset link and its requested redirect. Do not send a generic `{{ .SiteURL }}` button or a plaintext callback URL stripped of Auth recovery parameters. Resend is the SMTP delivery service; the reset session is still verified by Supabase Auth.

**Important:** Hosted Supabase Auth redirect allowlist/email template settings cannot be changed through the currently connected SQL-only deployment tools. This document records the exact values an authorized operator must verify in the dashboard; it does not falsely claim those settings are already updated.

## Tests and verification

### Source regression tests committed

- Recovery event while the dashboard is visible replaces it entirely and discards an open profile-menu route.
- Neither dashboard KPI values nor school dashboard scaffold exist in the recovery widget tree.
- Cold-start Web recovery intent blocks workspace load despite an already-existing Auth session.
- Saving a strong matching password signs out; Welcome appears without any automatic dashboard activation.
- Cancelling recovery signs out without exposing school data.
- If sign-out fails after a successful password change, recovery remains isolated; the user can retry sign-out without repeating the password update.
- URL classification: password recovery on Web/native vs normal Google/OAuth login, plus legacy Supabase fragment callback.

**Execution status:** Flutter source tests are committed but **not yet run**. The GitHub Actions runner account/billing restriction still prevents execution; the connected environment has no Flutter SDK. Do not mark code compiled or Android/Windows tested until a real run succeeds.

### Local acceptance test

Run from the project root:

```powershell
git pull origin main
flutter pub get
flutter analyze
flutter test test/auth/password_recovery_redirect_test.dart
flutter test test/auth/auth_return_to_dashboard_flow_test.dart
flutter test
flutter run -d windows
```

Then verify a real emailed reset link on Android and Windows:
1. Sign in normally and confirm the school dashboard works.
2. Sign out, request Reset Password for the same account and open Resend email link.
3. The **only** screen shown must be “Reset your password.” There must be no navigation, student dashboard, attendance card, analytics or school data behind it.
4. Save a new password. The reset session must sign out, returning to the Welcome screen.
5. Use email/password login with the new credentials; now the same school dashboard may open as an ordinary signed-in user.
6. Repeat on a cold-started Android app and Web (where callback URL query is processed before runApp).
7. Test Cancel, expired link and network sign-out failure: none may open the dashboard.

## Important boundary

Supabase's password recovery flow intentionally issues a temporary authenticated session after verifying the signed reset link. This fix prevents **the Flutter application UI and normal workspace restoration** from using that session as a regular dashboard login. It is **not** a general replacement for Supabase RLS, MFA or backend privilege checks: like any valid Auth session, a recovery session may carry an access token. Protect real student records with per-school RLS, short JWT/session lifetimes, and step-up authentication for high-risk operations. Do not claim that all REST API reads are blocked solely by the Flutter screen.
