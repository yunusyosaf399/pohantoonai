# Module 01.1 — Account sign-in and appearance settings

> **Database:** Deployed and security-checked 2026-11-10. **Edge:** `account-bootstrap` deployed active with `verify_jwt=true`. **Flutter:** Code committed; local and CI build still unverified.  
> **Development project:** `pohantoonai`, YouPro School, `umlzqlbakfwzgadafhyy` (single Supabase project).

## What each component does

| Component | Responsibility | Security |
|---|---|---|
| `auth.users` (Supabase managed) | Google identity, email magic-link, confirmed sessions | Supabase Auth; app never stores passwords/OTP |
| `public.user_profiles` | Profile information for one signed-in user | `user_id = auth.uid()`; own read/create/update only |
| `public.user_preferences` | `theme_mode`: `system`, `light` or `dark` | `user_id = auth.uid()`; own read/create/update only |
| `account-bootstrap` Edge Function | Validate bearer JWT; initialize own missing rows; return own theme/state | `verify_jwt=true`, Auth `GET /user`, caller-scoped RLS, no service role |
| `AccountWelcomeScreen` | Responsive desktop/mobile first screen, Google/email, Step 1/6, settings | No direct platform grants; no mock success |
| `ThemeController` | Guest local preference, then account-synced preference after login | Only non-secret preference reaches client |

**No organization permission is created at sign-in.** Authentication proves identity; it does not make a user a platform operator or school owner. Existing `platform` data stays private/closed. There are no application-owned credential/OTP tables.

## User flow

```text
Open app
  -> Step 1 of 6: Create Your School Account
    -> Continue with Google  => browser OAuth; wait for signed-in callback
    -> Continue with email   => magic-link email; wait for callback
    -> Settings              => Light / Dark / System, works before login
  -> Supabase Auth confirms session
  -> account-bootstrap validates JWT and initializes own profile/prefs
  -> UI confirms signed-in account (no organization-admin access)
  -> Step 2 (later): choose plan, then complete school registration
```

## Dashboard actions still required for real sign-in

These settings **cannot be deployed with the current connected Supabase management tools**, which do not expose provider/SMTP configuration. Avoid putting provider secrets in Flutter or SQL.

1. **Google provider:** create Google OAuth credentials and configure Supabase Dashboard → Authentication → Sign In / Providers → Google with the Google Client ID and **Client Secret** (dashboard only). Configure Google Cloud authorized redirect URI to exactly `https://umlzqlbakfwzgadafhyy.supabase.co/auth/v1/callback`. Google consent screen may need publishing/test-user access.
2. **Email:** ensure the Email provider is enabled, and configure custom SMTP for delivery to arbitrary school email addresses. Supabase default email delivery is restricted and rate-limited. The Flutter action uses `signInWithOtp` to send a **magic link**, not a stored password.
3. **App callback allowlist:** Supabase Dashboard → Authentication → URL Configuration → Additional Redirect URLs: add `pohantoonai://auth-callback`. For web, allow the actual Flutter app origin(s) and configure the Site URL to the deployed web origin. Do not use a production wildcard redirect.
4. **Android/iOS:** callback handlers are committed in `AndroidManifest.xml` and `Info.plist`. For Windows desktop, configure URI protocol registration/installer association before expecting browser callbacks; on web the Site URL/redirect policy must match the deployed host.
5. **Legal links:** Terms of Service and Privacy Policy are presently explanatory text only; real legal URLs must be created and wired before public launch.
6. **Email rate limits/captcha:** review Supabase Auth rate-limit and CAPTCHA settings and enable abuse protection as appropriate before opening public registration.

## Deployment source files

- [SQL](../../supabase/schema/03_account_identity_preferences.sql): deployed migration name `account_profiles_theme_preferences_rls` (version `20261110174324`).
- [Edge](../../supabase/functions/account-bootstrap/index.ts): deployed active version 1.
- [SQL checks](../../supabase/tests/03_account_auth_smoke.sql): policy/privilege and theme CHECK verification.
- [Flutter gateway](../../lib/features/auth/data/account_auth_gateway.dart): Google and email magic-link actions.
- [First-screen UI](../../lib/features/auth/presentation/account_welcome_screen.dart): adaptive light/dark design based on supplied references.
- [Theme controller](../../lib/core/settings/theme_controller.dart): local and authenticated preference syncing.
- [Widget tests](../../test/auth/account_welcome_test.dart): responsive layout, validation, Google/email callbacks and theme selector.

## Verification status

- [x] Migration applied to development database.
- [x] Two tables verified RLS enabled and three policies each.
- [x] Anonymous grants denied; authenticated grants require own-row policies.
- [x] Edge Function deployed with JWT verification enabled.
- [ ] Signed-in Edge happy path tested with an actual valid test account.
- [ ] Google OAuth completed end-to-end (provider credentials pending).
- [ ] Email magic-link received and confirmed end-to-end (email provider/SMTP pending).
- [ ] Flutter analyzer and widget tests passed (GitHub Actions runners currently fail before any steps; no local Flutter SDK in execution environment).
- [ ] App login verified across Android, Windows, Web; callback setups per platform.
- [ ] SDK-generated `pubspec.lock` committed after `flutter pub get` on an available Flutter machine/runner.

## Implementation decisions

- Email is **passwordless** in Step 1. The same user can later link a Google identity through Supabase Auth policies.
- Do not use email or Google metadata to assign school/org roles.
- User-controlled theme is allowed; it is not authorization data.
- Capturing a login is not a paid subscription or a provisioned school.
- Account bootstrap avoids a signup trigger on `auth.users`, so failing profile storage does not break the Auth service signup itself.
