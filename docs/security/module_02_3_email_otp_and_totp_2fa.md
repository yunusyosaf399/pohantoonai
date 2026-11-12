# Module 02.3 — Email recovery OTP and optional authenticator 2FA

Date: 2026-11-12. Repository: yunusyosaf399/pohantoonai. Existing single Supabase development project: umlzqlbakfwzgadafhyy.

Status: Flutter source/UI/tests committed. Database migration deployed and tested. Actual Flutter compilation, Android verification and Resend email delivery remain pending.

## A. Email code password recovery — Android, Windows, Web, iOS

Workflow:

1. Signed-out owner selects Continue with Email -> Sign in -> Forgot password and enters an email.
2. Supabase Auth resetPasswordForEmail sends a recovery OTP using the linked project's Resend SMTP.
3. Flutter navigates to the EXCLUSIVE password recovery screen showing the email-code field, without opening the browser and with no school dashboard behind it.
4. The user enters the emailed code. Supabase Auth verifyOTP(type: recovery, email, token) checks the code and issues a temporary recovery session.
5. Only after verification does Flutter display New Password and Confirm Password. updateUser(password) changes the password. The temporary session is signed out whether the user finishes or cancels.
6. Wrong/expired codes do not unlock the password fields; resend uses Supabase recovery email rate limits.

IMPORTANT: A hosted Supabase project has one Reset Password email template shared by Android and Web, rather than per-device templates. Therefore this change adopts the same secure code-only recovery email for all clients. The HTML template file is at supabase/auth/templates/recovery_otp.html. It includes the Supabase template placeholder for the token, and deliberately contains NO reset browser link. Its content must be manually installed in hosted Supabase Auth -> Email Templates -> Reset Password (https://supabase.com/dashboard/project/umlzqlbakfwzgadafhyy/auth/templates). Email subject recommendation: "Reset your Pohantoon AI password — verification code".

Do not put SMTP keys, OTPs, passwords, email recovery tokens or Auth refresh tokens in SQL tables, Edge Functions, logs or GitHub. The existing valid Resend SMTP setup is reused.

Historical deep-link reset emails are still accepted by the app via the separate recovery-only screen, but NEW recovery emails are code-only after the hosted template is installed.

## B. Authenticator 2FA (TOTP)

In Dashboard -> avatar -> Owner & Security -> Two-factor authentication, the owner can select Enable 2FA. Supabase Auth mfa.enroll issues an unverified factor, a QR provisioning URI and a private setup secret. Flutter renders the QR locally with the pinned qr_flutter package, and shows a manual setup key for users who run the authenticator app on the same phone.

The user adds the key to Google Authenticator, Microsoft Authenticator or another TOTP client. They enter the six-digit code. Supabase Auth mfa.challengeAndVerify verifies the code, marks the factor verified, and upgrades that session to AAL2. The transient key/QR is discarded from Flutter state. Cancel discards the unverified enrollment. A verified AAL2 user may enroll an additional backup authenticator or remove a factor after an explicit confirmation dialog.

On later sign-in (Google or email password), the Flutter application checks getAuthenticatorAssuranceLevel() and listFactors() BEFORE it ever restores the dashboard. Enrolled accounts at AAL1 must complete the exclusive full-screen authenticator challenge. A wrong code or offline failure NEVER unlocks the dashboard. A valid code upgrades to AAL2 and allows the normal saved school workspace.

Supabase's current TOTP flow in this app does not include downloadable backup recovery codes; owners should add a second authenticator. Losing all devices requires a separate verified operator recovery process, never a button that bypasses 2FA.

## C. Database schema and RLS

NO custom OTP/password/TOTP-secret table was created. Supabase Auth is the authoritative owner of:

- auth.users — verified email and password hash
- auth.mfa_factors — TOTP secret and verified factor ownership, inaccessible directly to the Flutter client
- auth.mfa_challenges — MFA code challenges
- auth.sessions and JWT aal claim — authenticated session levels AAL1 and AAL2

Deployed migration: supabase/schema/15_optional_mfa_aal2_enforcement.sql, migration name optional_mfa_aal2_school_security.

It creates a narrowly scoped helper in the non-Data-API schema security_private. The function security_private.account_mfa_satisfied() is SECURITY DEFINER with fixed empty search_path, takes no arguments, checks only auth.uid() and verified factors, returns one boolean, and grants execution only to authenticated. It never returns secret material. No SELECT on auth.mfa_factors is granted to client roles.

The helper returns TRUE when the real JWT has AAL2, OR the account has not enrolled any verified MFA factor. Therefore un-enrolled existing users continue normal AAL1 login. Once enrolled, the account is protected by restrictive RLS policies requiring AAL2 on 14 applicant/profile/school/dashboard tables AND on private school-logo Storage objects. Existing owner/tenant policies remain in place.

Verification: supabase/tests/15_optional_mfa_aal2_security.sql PASSED in one transaction with rollback. AAL1 owner without MFA could read their own profile; the same owner with a temporary synthetic verified factor could NOT read school/profile at AAL1; a simulated AAL2 claim restored own-row SELECT. The test factor was rolled back, with no persistent account changes.

## D. Relevant files

- lib/features/auth/data/account_auth_gateway.dart — Supabase recovery OTP verification
- lib/features/auth/presentation/email_credentials_panel.dart — Forgot Password requests email code
- lib/features/auth/presentation/password_recovery_dialog.dart — exclusive OTP/password reset UI
- lib/features/auth/data/account_mfa_repository.dart — native Supabase Auth MFA API
- lib/features/auth/presentation/account_mfa_challenge_screen.dart — exclusive AAL2 login screen
- lib/features/auth/presentation/account_mfa_settings_card.dart — QR enrollment/verification, backups and removal
- lib/features/dashboard/presentation/dashboard_profile_settings.dart — Owner & Security 2FA UI
- lib/main.dart — authentication gate, recovery isolation and dashboard restoration
- supabase/auth/templates/recovery_otp.html — code-only Reset Password email
- supabase/schema/15_optional_mfa_aal2_enforcement.sql — privacy-preserving optional AAL2 RLS
- supabase/tests/15_optional_mfa_aal2_security.sql — rollback-only SQL assertion
- test/auth/account_mfa_ui_test.dart — widget tests for QR, verification, removal
- test/auth/auth_return_to_dashboard_flow_test.dart — OTP reset and mandatory MFA login tests

## E. Manual acceptance on physical Android

Run in project directory:

    git pull --rebase origin main
    flutter pub get
    flutter analyze
    flutter test test/auth
    flutter run -d <android-device-id>

After installing the hosted Reset Password template, request a recovery code on Android. The Resend email must contain a code and NO password-reset link. Try an invalid code: the new-password form must remain locked. Try a valid code: set a strong new password and the app must sign out to the Welcome screen. The dashboard must never appear behind the reset screen.

Sign in normally. Under Owner & Security, enroll an authenticator by QR or manual key and confirm its current code. Sign out and sign in again. The 2FA verification screen must appear before dashboard restoration. Incorrect codes must remain blocked. Correct code permits the same school dashboard. Test a second backup factor and a deliberate removal with a verified AAL2 session.

The project's TOTP provider is enabled by default in current Supabase Auth, but verify actual project factor settings if enrollment is rejected. No custom Edge Function is necessary for either operation.

Pending: actual Flutter SDK compile/widget-test execution and Resend SMTP delivery on device have NOT been verified from this tool environment.
