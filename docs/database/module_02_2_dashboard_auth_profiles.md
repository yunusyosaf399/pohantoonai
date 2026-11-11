# Module 02.2 — Compact Plans, Persistent Demo Dashboard and Email Authentication

2026-11-11 · Repo: yunusyosaf399/pohantoonai · Development Supabase: umlzqlbakfwzgadafhyy.

## Flutter implementation

- Step 2 plan cards use content-based height instead of 360px and no large Spacer. All plans and limits remain backend-driven.
- New applicant flow: Google or verified email signup -> choose demo plan -> complete Step 3 school details -> server-authorized development workspace -> demo dashboard. No application review or payment UI is required for the current development workflow.
- Returning login: on any authenticated session, load own selected active demo plan, completed school draft and owner-only development-workspace row. If eligible, open the same demo dashboard directly. Existing legitimate test-skip users are lazily migrated through their own session; no service role credentials.
- Dashboard owner icon opens an in-dashboard settings sheet, not onboarding or checkout. School tab edits display name, website, contacts, location, board/curriculum, grade range and private logo through the existing SchoolSetupRepository. Legal name, school type, registration/license and selected plan are locked. Owner tab updates own user_profiles.display_name and allows setting/changing a password for their verified Auth account. Sign-in email stays locked.
- Email option on Step 1: create account with email/password, repeat password, enter verification OTP, resend code, sign in with email/password, request password reset link. Google OAuth remains available. Supabase handles passwords, OTPs and sessions, not application tables.
- Dashboard analytics, admissions, fees, approvals and shortcuts continue to show DEMO DATA only; no school membership or real payment entitlement is created.

## Deployed migration 12

Source: [12_dev_workspace_persistent_access.sql](../../supabase/schema/12_dev_workspace_persistent_access.sql). Supabase migration history: version 20261111140501, name persistent_development_workspace_without_payment.

New table public.onboarding_dev_workspaces:

| Field | Type | Server rule |
|---|---|---|
| user_id | UUID primary key, FK to school_setup_drafts | Only current auth.uid |
| selected_plan_id | UUID FK to onboarding_plan_offers | Matches selected active demo plan |
| access_kind | restricted text | Only development_preview, NEVER paid |
| created_at | timestamp | Server-owned |

RLS: authenticated SELECT and INSERT only; no client UPDATE/DELETE and no anonymous grant. Security-invoker trigger and owner INSERT policy verify a ready-for-review school draft and matching selected active demo plan.

Existing dashboard preference rows are preserved by moving their FK to the applicant-owned school_setup_drafts table. The preferences trigger accepts a valid current development workspace or legacy verified test skip. Both require the user's own completed school setup and active demo plan. No data were deleted.

[SQL security test](../../supabase/tests/12_dev_workspace_security.sql) executed in a transaction with rollback: own workspace creation passes, cross-account insertion and bogus payment approval are rejected, and client cannot provision public.schools. Actual schools and memberships remain at zero.

This is deliberately NOT marked payment approved. Development access must never authorize financial transactions, real subscriptions, approved school permissions or tenant provisioning.

## Native Supabase Auth; no custom OTP Edge Function needed

Supabase Auth already generates single-use codes, checks expiry and rate limits, verifies email ownership, issues sessions and securely hashes passwords. A separate public email-code Edge Function would add an unnecessary spoofing/email-abuse surface and a second identity system. Passwords and OTPs are never saved to custom tables.

Source:
- [Auth gateway](../../lib/features/auth/data/account_auth_gateway.dart)
- [Email signup, verification and password login](../../lib/features/auth/presentation/email_credentials_panel.dart)
- [Password recovery dialog](../../lib/features/auth/presentation/password_recovery_dialog.dart)
- [Welcome screen](../../lib/features/auth/presentation/account_welcome_screen.dart)
- [Dashboard school/owner settings](../../lib/features/dashboard/presentation/dashboard_profile_settings.dart)
- [Auth widget tests](../../test/auth/email_credentials_panel_test.dart)
- [App startup routing](../../lib/main.dart)

## Required hosted Auth configuration

The following settings cannot be applied by SQL migration and have not been modified through a hosted Auth management API:

1. Open https://supabase.com/dashboard/project/umlzqlbakfwzgadafhyy/auth/providers . Enable Email provider, password sign-in and Confirm email. Do NOT disable confirmation to bypass verification.
2. Under Authentication -> Email Templates, install [confirm_signup.html](../../supabase/auth/templates/confirm_signup.html) in Confirm Signup, and [magic_link_otp.html](../../supabase/auth/templates/magic_link_otp.html) in Magic Link/OTP. Both contain the built-in Supabase Go-template token expression, which must be kept intact.
3. Configure SMTP with a verified sender for reliable delivery. Default Supabase email has strict limits and can restrict recipients.
4. Ensure redirect URLs are allowlisted for Flutter Web, Windows and mobile OAuth/email recovery callbacks; keep Google's OAuth callback distinct from the Flutter app callback.
5. Set expiration and resend limits, CAPTCHA/bot protection, and enable leaked-password protection: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection .

No OTP emails were sent during this implementation. Deliverability and real phone/desktop/web flow must be tested with an actual verified mailbox.

## Next testing gate

- Run flutter pub get and commit regenerated pubspec.lock, flutter analyze, flutter test, and flutter run -d windows (remote GitHub Actions runner is blocked by account billing).
- Manual test: Google login -> complete school setup -> dashboard -> sign out -> Google login -> same dashboard.
- Manual test: Google user -> owner profile -> add password -> sign out -> email/password login -> same dashboard.
- Manual test: email/password signup -> receive code -> verify -> complete setup -> sign out -> email/password login -> same dashboard.
- Manual test: in-dashboard school logo/details and owner display name update without any return to onboarding.
- Real school provisioning, subscriptions/payment provider and teacher/student modules are separate, future milestones.
