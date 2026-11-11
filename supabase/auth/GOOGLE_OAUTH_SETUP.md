# Google OAuth Setup — Pohantoon AI

> **Status:** [Google flow has previously reached Supabase; return-to-app still requires dashboard redirect allowlist and device testing] · **Last reviewed:** 2026-11-11  
> **Supabase project:** `pohantoonai`, organization `YouPro School`, project ref `umlzqlbakfwzgadafhyy`.  
> **Do not commit OAuth client secrets, Google credential JSON, management API tokens, or screenshots containing secrets.**

## Hosted provider configuration (one project, all schools)

Google OAuth is **project-wide authentication** for the one `pohantoonai` Supabase project, not one Google client per school. Authentication alone must **not** grant school ownership or SaaS operator access.

### 1. Create Google client

1. Open [Google Auth Platform](https://console.cloud.google.com/auth/overview), create or select the Google Cloud project for Pohantoon AI.
2. Configure **Branding**: application name `Pohantoon AI`, support email and developer contact. Provide a verified domain and approved home/privacy/terms pages before publishing an external production app. Use testing mode initially if Google offers it.
3. Configure **Audience**: choose **External** for schools signing in from independent Google accounts. During Testing, add specific Google accounts as test users. An Internal app would restrict sign-in to a single Google Workspace organization.
4. Open **Clients → Create client** and choose **Web application**, name `Pohantoon AI — Supabase Auth (development)`.
5. Add **Authorized redirect URI** (exact, no extra slash):

   ```text
   https://umlzqlbakfwzgadafhyy.supabase.co/auth/v1/callback
   ```

6. Under **Authorized JavaScript origins**, add actual Flutter Web origin(s) only when a concrete hosted or local web URL is known. For native mobile/desktop browser OAuth via Supabase, the Google callback above is the critical setting. Never add a custom URI scheme as a *Google* authorized redirect URI.
7. Create the client and keep the generated **Client ID** and **Client Secret** in Google Cloud / Supabase provider settings only. Don't send the secret in chat or commit to the repository.

### 2. Enable provider in Supabase

1. Open [pohantoonai Authentication Providers](https://supabase.com/dashboard/project/umlzqlbakfwzgadafhyy/auth/providers) and select **Google**.
2. Enable Google provider.
3. Paste the **Client ID** and **Client Secret** from Google Cloud into their respective provider fields, then **Save**.
4. If you create additional platform-specific OAuth clients later, follow Supabase's provider documentation. Keep the **Web application** client ID first when entering multiple IDs.

### 3. Allow Flutter callbacks in Supabase

**Updated platform contract:** [Cross-platform OAuth callback remediation](OAUTH_CALLBACK_PLATFORMS.md). The app now uses an explicit Web URL with a preserved base path, and native `pohantoonai://auth-callback`; Windows automatically registers the scheme for unpackaged executables, while mobile uses the `app_links` plugin. This must be accompanied by the Dashboard allowlist entries. Use an exact Web URL (including `/` for root) in addition to the development wildcard.

Open [pohantoonai URL Configuration](https://supabase.com/dashboard/project/umlzqlbakfwzgadafhyy/auth/url-configuration):

- **Additional Redirect URL:** `pohantoonai://auth-callback` (matches `SupabaseConfiguration.mobileRedirect` and the app's configured native deep-link handlers).
- **Site URL:** configure an actual, controlled Flutter Web URL before testing web auth (do not assume the default localhost points to a deployed app).
- **Additional Redirect URLs for Web:** use the exact origin/route(s) for the browser builds you actually test. No broad production wildcards.
- **Google's redirect URI is different:** Google always returns to Supabase first at `https://umlzqlbakfwzgadafhyy.supabase.co/auth/v1/callback`; Supabase then redirects back to the app's allowlisted URL.

### 4. Flutter and database implementation already present

- Flutter: `lib/features/auth/data/account_auth_gateway.dart` uses `supabase.auth.signInWithOAuth(OAuthProvider.google, redirectTo: oauthRedirectForApp(isWeb: kIsWeb, currentUri: Uri.base))`, with system-browser launch on native platforms.
- Flutter: `lib/features/auth/presentation/account_welcome_screen.dart` shows Google/email and light/dark theme switch on mobile and desktop.
- Database: `public.user_profiles` and `public.user_preferences` own-row RLS; no Google OAuth credentials stored in app tables.
- Edge Function: `supabase/functions/account-bootstrap/index.ts` validates user JWT and initializes own profile/preferences. It does not grant school permissions.
- No source-code change is required merely to paste the Google Client ID/Secret into Supabase's hosted provider setting.

## Test and acceptance

- [ ] Google Cloud consent branding/audience configured and the test user's Google address allowlisted.
- [ ] Web application OAuth client created with exact Supabase callback.
- [ ] Supabase Google provider enabled and credentials saved **in dashboard**.
- [ ] App callback allowlist configured (`pohantoonai://auth-callback` for native).
- [ ] Sign in from a real Flutter Android app using a Google test account.
- [ ] Supabase Auth user/session created; `account-bootstrap` succeeds with that user's JWT.
- [ ] `user_profiles` / `user_preferences` created for **only** the signed-in user.
- [ ] Second user's tokens cannot read first user's profile/preferences; anonymous session denied.
- [ ] Sign out, sign back in and confirm local/account theme synchronization.
- [ ] Verify Web with a real hosted origin; verify Windows URL protocol registration before declaring desktop OAuth working.
- [ ] Update tracker with date, environment, test method and sanitized output. **Never log or commit the OAuth Client Secret or full tokens**.

**Known blocker:** ChatGPT's currently connected Supabase management tools do not offer an Auth provider-settings write operation, and no Google Cloud OAuth credential-management connection is available. The owner must complete the two dashboard credential steps or use Work mode to navigate them interactively. Do **not** run a SQL migration or deploy an Edge Function to store Google OAuth credentials—Supabase Auth provider configuration is separate from PostgreSQL.

## References

- [Supabase — Google OAuth](https://supabase.com/docs/guides/auth/social-sign-in/auth-google)
- [Supabase — Redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls)
- [Google — OAuth 2.0 for web server applications](https://developers.google.com/identity/protocols/oauth2/web-server)
- [Existing Pohantoon AI Auth implementation](../../docs/database/module_01_account_auth.md)
