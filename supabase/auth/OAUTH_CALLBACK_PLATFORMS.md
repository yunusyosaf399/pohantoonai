# OAuth and email callback — Flutter Web, Android, iOS, macOS, Windows

> **2026-11-11 — CODE FIX COMMITTED / END-TO-END TEST PENDING.**
> This run cannot edit the hosted Supabase Auth **URL Configuration** settings; the connected Supabase management plugin exposes database/Edge Function operations but not GoTrue provider redirect allowlists.
> Do not report "OAuth working" until a real device/browser has returned and `auth.currentSession` exists.

## What was broken and what changed

| Runtime | Root issue / previously missing component | Code fix |
|---|---|---|
| Flutter Web / Chrome / Edge | Return URL was reduced to `Uri.base.origin`, discarding any deployment base path and relying on Supabase's allowlist to accept the exact URL | `oauthRedirectForApp(isWeb:true)` returns origin + current path, including dev port, **without existing query/fragment** |
| Android | Flutter's default deep-link routing (enabled in recent Flutter) can intercept links intended for `supabase_flutter`'s `app_links` handler | `android/app/src/main/AndroidManifest.xml` sets `flutter_deeplinking_enabled=false`; existing `singleTop` and callback host/scheme remain |
| iOS | Same competing Flutter router | `ios/Runner/Info.plist` disables Flutter router; retains `pohantoonai` URI scheme |
| macOS | No registered app callback scheme | `macos/Runner/Info.plist` registers `pohantoonai` and disables competing router |
| Windows (unpackaged Flutter executable) | `pohantoonai://` was not registered with the OS; second instance could not reliably pass callback to first | `windows/runner/main.cpp` registers protocol in current-user registry and calls `SendAppLinkToInstance()` before creating another window |
| All | OAuth URL launch alone is not sign-in success; auth stream errors had no handler, potentially surfacing as uncaught errors | Google auth opens in **system browser**, main auth-state listener captures errors, welcome screen offers retry feedback |

The system-browser choice intentionally avoids embedded-webview Google login, which can be rejected by Google's user-agent restrictions. Unlike a browser tab, the native application remains logged in after the deeplink returns; the system browser tab may remain open and can be closed by the user.

### Unified native callback

```text
pohantoonai://auth-callback
```

On native Google login:
```text
Flutter signInWithOAuth(google, redirectTo=pohantoonai://auth-callback)
 → Google OAuth
 → https://umlzqlbakfwzgadafhyy.supabase.co/auth/v1/callback
 → OS opens pohantoonai://auth-callback?code=...
 → Supabase Flutter app_links listener exchanges code for session
 → App onAuthStateChange emits signedIn
 → Step 2 Choose Your Plan
```

**Never paste, bookmark, log or reuse** an actual code- or token-bearing callback URL. The one-time code/PKCE state must be used in its originating session. In Windows, the registered callback is passed to a running instance through the `app_links` plugin; the app does not manually parse or print it.

For installed desktop apps, changing the Windows exe path after registration requires starting the app from its new location once to refresh the per-user handler. An MSIX packaged release should declare the `pohantoonai` protocol in its package manifest (this native registry registration covers **unpackaged** `flutter run -d windows` / copied executable builds). When uninstalling an unpackaged app manually, remove `HKCU\Software\Classes\pohantoonai` only after confirming no other Pohantoon AI installation needs that handler.

## Required Supabase Auth URL Configuration

[Open this exact project's Auth URL Configuration](https://supabase.com/dashboard/project/umlzqlbakfwzgadafhyy/auth/url-configuration) and set:

1. **Additional Redirect URLs**: `pohantoonai://auth-callback` (required by Android, iOS, Windows and macOS).
2. **Flutter Web development (fixed port):** `http://localhost:3000/` and `http://localhost:3000/**`.
3. **If testing against 127.0.0.1:** `http://127.0.0.1:3000/` and `http://127.0.0.1:3000/**`. Do not confuse it with localhost.
4. **Deployed Flutter Web:** your **actual** HTTPS app URL and base path, e.g. `https://your-controlled-domain.example/pohantoonai/` (illustration only; do NOT copy the placeholder). Use exact URLs for production; do not allow `https://**`.
5. **Site URL:** your controlled real production Web app origin, when available. The app supplies `redirectTo` explicitly; fallback Site URL is not a substitute for an allowlisted URL.

Google Cloud Console should continue to contain **only the hosted Supabase callback** as the authorized redirect:
```text
https://umlzqlbakfwzgadafhyy.supabase.co/auth/v1/callback
```
Do not replace this Google redirect with Flutter Web localhost, a custom mobile scheme, or a Windows path. **Client secrets belong only in the provider dashboard**, not source code or database tables.

### Important for email magic links

The email login request now also uses the same per-platform return URL. If email templates have a hard-coded destination URL, they can override the expected behavior. Prefer the Supabase `{{ .ConfirmationURL }}` token in Auth email templates and ensure email delivery is configured.

## Local developer verification

Use a new login attempt from the app. Do not replay an old `/auth/v1/callback` URL or reuse a prior OAuth state.

**Web:**
```bash
flutter run -d chrome --web-port 3000
```
1. Visit `http://localhost:3000/`.
2. Click Continue with Google; complete consent.
3. Browser should land on `http://localhost:3000/` (with a short-lived code initially), then Step 2, with a non-null `Supabase.instance.client.auth.currentSession`.
4. If hosted under a subdirectory, first verify the host serves the Flutter entry point there and that this exact path is in the redirect list.

**Android:** Rebuild after the Android manifest change. Click Continue with Google or open a *new* magic link, choose Pohantoon AI if Android asks which app, verify the installed application resumes and shows Step 2. The Android scheme/host must remain `pohantoonai` / `auth-callback`. Manual harmless handler check:
```bash
adb shell am start -a android.intent.action.VIEW -d "pohantoonai://auth-callback"
```
This only checks whether the OS opens the app; it **will not** create a session.

**iOS/macOS:** Rebuild after Info.plist changes, verify the `pohantoonai` scheme opens the app through a harmless `pohantoonai://auth-callback` test, then do real Google login.

**Windows:** Rebuild with the newly updated C++ runner. Launch `flutter run -d windows` / start the exe once so it writes the callback handler under the current user. Verify the handler in PowerShell:
```powershell
Get-Item 'Registry::HKEY_CURRENT_USER\Software\Classes\pohantoonai'
(Get-ItemProperty 'Registry::HKEY_CURRENT_USER\Software\Classes\pohantoonai\shell\open\command').'(default)'
Start-Process 'pohantoonai://auth-callback'
```
The harmless URL should activate the running app, not create a session. Then click Continue with Google **in the Windows Flutter app** and finish Google consent in the system browser. The app should receive the callback in the **existing window** and advance to Step 2. No admin rights are required for HKCU registration. For an MSIX installer, explicitly declare protocol activation in its manifest.

**Email warning:** Email login only returns to the device that has an installed registered app when opened on the **same platform**. Sending a link on a Windows browser and opening it on an unrelated phone can fail the OAuth/PKCE state check; finish login on the initiating device.

## Tests and acceptance

- [x] Cross-platform registration code and unit tests committed.
- [x] Web redirect helper strips query/fragment and retains host/port/path.
- [x] Flutter auth stream now handles errors without logging tokens.
- [ ] Host Auth redirect allowlist configured in Supabase dashboard (must be done by project owner).
- [ ] Run `flutter pub get && flutter test test/auth/oauth_redirect_test.dart test/auth/native_callback_contract_test.dart && flutter analyze`.
- [ ] Windows compilation and per-user protocol registration tested on actual PC.
- [ ] Google and email return-to-app verified on Android, iOS, Windows and Web; macOS when available.
- [ ] Account initialization, own-row profile and Step 2 plan fetch verified after callback.

**GitHub CI limitation:** The last GitHub-hosted runner failed **before starting any steps** because of repository account billing/spending limits. The source was committed directly, but no device runtime test was performed here.

References: [Supabase redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls), [Supabase Dart OAuth](https://supabase.com/docs/reference/dart/auth-signinwithoauth), [Flutter app_links Windows](https://github.com/llfbandit/app_links/blob/main/doc/README_windows.md), [Flutter deep-link flag migration](https://docs.flutter.dev/release/breaking-changes/deep-links-flag-change), [Flutter Auth stream errors](https://supabase.com/docs/reference/dart/auth-onauthstatechange).
